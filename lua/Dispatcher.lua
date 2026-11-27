local Class = require("lua.core.class")
local TrackFollower = require("lua.core.Pathfinder.TrackFollower")
local MapPathfinder = require("lua.MapPathfinder.MapPathfinder")
local Severity = require("lua.core.Utils.LogSeverity")
local PathMode = require("lua.core.Enums.PathMode")

---@class Dispatcher : Class
---@overload fun(schematic: Schematic): Dispatcher
local Dispatcher = Class:derive("Dispatcher")

---@alias Train {steps: TrainStep[], step: integer}
---@alias TrainStep {tile: Tile}

---Creates a Dispatcher, which dispatches routes on a schematic during the simulation.
---@param schematic Schematic The schematic which owns this dispatcher.
function Dispatcher:new(schematic)
    self.schematic = schematic
    ---A list of trains to be dispatched, keyed by train name.
    ---Once fully dispatched, it disappears off the list.
    ---`step` - the first step to be done, starts from 1!
    ---@type table<string, Train>
    self.trains = {}

	-- Initialize a station dispatch callback, which will be called once every 5-30 seconds.
	_CreateLoopEvent("s_" .. schematic.shortcut, function() _DoCallback("station_" .. schematic.shortcut, self) end, 5, 25)
    _CreateCallback("station_" .. schematic.shortcut, function() self:tick() end)
end

---Returns the index for this dispatcher's schematic.
---@private
---@return SchematicIndex
function Dispatcher:getSchematicIndex()
    return self.schematic.index
end

---Returns the list of stations this dispatcher should handle.
---@private
---@return Station[]
function Dispatcher:getStationList()
    local stations = {}
    for id, data in pairs(self.schematic.index.stations) do
        table.insert(stations, _Obj:assertGetStation(id))
    end
    return stations
end

---Given an exit tile, attempts to find an approaching train and returns its timetable ID.
---Returns `nil` if no train is found.
---If the train does not have any timetable, returns `"none"`.
---@param tile Tile The exit tile to be checked for.
---@return string?
function Dispatcher:getApproachingTrainTimetableForExit(tile)
    -- Check some preconditions.
    if not tile:getWarpDestination() then
        _Log.write(string.format("WARNING: Exit `%s` not checked - no destination set", tile.warpID or "nil"))
        return
    end
    local dir = tile:getWarpExitDirection()
    if not dir then
        _Log.write(string.format("WARNING: Exit `%s` not checked - illegal exit tile placement", tile.warpID or "nil"))
        return
    end
    -- Set up an expedition for the train.
    -- The scan stops at the first unreserved switch, as that's the switch the train may go a different direction in
    -- (we're basically not guaranteed the train will go towards our schematic specifically).
    --_Log.write(string.format("Starting from tile %s", tile:getLocation()))
    local follower = TrackFollower(tile, _Dir.invertDir(dir))
    -- Abort the scan if the switch is switched the other way, so we don't "slide" into another path.
    follower:setSwitchForceStop(true)
    follower:stepUntil(function(scanTile) return scanTile:isTrackOccupied() or (scanTile:isSwitch() and not scanTile:isTrackReserved()) end)
    -- The moment of truth. Did we catch the rabbit?
    local foundTile = follower:getTile()
    local track = foundTile:getTrack()
    --_Log.write(string.format("Landed on tile %s, track: %s", foundTile:getLocation(), foundTile:getTrack()))
    return track and track:getTimetable()
end

---Returns a list of timetable entries to be dispatched towards for the given timetable, in the order of their servicing.
---Already serviced stations or stations where the train does not stop are omitted.
---@param timetable Timetable The timetable to source the station list from.
---@return TimetableEntry[]
function Dispatcher:getStationListForTimetable(timetable)
    local entries = {}
    for i, entry in ipairs(timetable.stations) do
        if entry.arrival and not entry.departureAct and self.schematic.index.stations[entry.name] then
            table.insert(entries, entry)
        end
    end
    return entries
end

---Generates a list of steps for the train to be successfully dispatched through the station.
---@param tile Tile The tile the train is coming from (or currently at).
---@param timetable Timetable The timetable to source the train data from.
function Dispatcher:generateStepsForTrain(tile, timetable)
    -- Do not generate the step list if it already exists!
    if self.trains[timetable.id] then
        return
    end
    _Log.write(string.format("Generating step list for train %s at %s", timetable.id, tile:getLocation()), Severity.INFO)
    ---@type Train
    local train = {steps = {}, step = 1}
    -- The first step is always at the train.
    table.insert(train.steps, {tile = tile})
    -- Add any stations in between that are there on this schematic.
    -- TODO: What about passing through the schematic multiple times?
    local entries = self:getStationListForTimetable(timetable)
    for i, entry in ipairs(entries) do
        -- TODO: There should be a pool of tiles to pick from in case our track is occupied but the track next to it is free!
        local stationTile = entry.track and self.schematic.index:getTileForStationAndTrack(entry.name, entry.track) or self.schematic.index:getRandomTrackTileForStation(entry.name)
        if stationTile and stationTile ~= train.steps[#train.steps].tile then
            table.insert(train.steps, {tile = stationTile})
        else
            _Log.write(string.format("Skipped missing or duplicate tile for station %s track %s on schematic %s", entry.name, entry.track, self.schematic.shortcut), Severity.ERROR)
            _Log.write(string.format("This tile: %s, last tile: %s", tostring(stationTile and stationTile:getLocation()), tostring(train.steps[#train.steps].tile and train.steps[#train.steps].tile:getLocation())))
        end
    end
    -- Find out the correct exit tile.
    local exitTile = self:getExitTileForTrain(tile, timetable)
    if exitTile then
        table.insert(train.steps, {tile = exitTile})
    end
    self.trains[timetable.id] = train
    _Log.write(string.format("Generated step list for train %s at %s:", timetable.id, tile:getLocation()), Severity.INFO)
    for i, step in ipairs(train.steps) do
        _Log.write(string.format("    %s %s", train.step == i and ">" or " ", step.tile:getLocation()))
    end
end

---Returns the exit tile for the specified train to go towards.
---Returns `nil` if the tile cannot be found or this is the last station.
---@param tile Tile The tile the train is coming from (or currently at).
---@param timetable Timetable The timetable to source the train data from.
---@return Tile?
function Dispatcher:getExitTileForTrain(tile, timetable)
    -- Find out the correct exit tile.
    local destination = timetable:getFinalStationName()
    local targetSchematic = _MapIndex:getSchematicForStation(destination)
    if targetSchematic == self.schematic then
        -- This is the final station! We're done!
        return
    end
    if not targetSchematic then
        _Log.write(string.format("Could not find schematic for station %s, aborting", destination))
        return
    end
    local pathfinder = MapPathfinder(self.schematic, targetSchematic)
    -- Make sure to consider only exits that this schematic can physically find the path to.
    pathfinder:setInboundExit(tile.warpID)
    -- Fetch the target tile on the target schematic.
    -- TODO: Select the penultimate one in case the last one doesn't work?
    -- TODO: Make sure the pathfinder always hits all tiles it should, also on intermediate stations?
    local finalEntry = timetable.stations[#timetable.stations]
    local finalSchematic = _MapIndex:getSchematicForStation(finalEntry.name)
    local finalTile = finalSchematic and finalSchematic.index:getTileForStationAndTrack(finalEntry.name, finalEntry.track)
    if finalTile then
        _Log.write(string.format("Final tile for the Map Pathfinder is: %s", finalTile:getLocation()))
        pathfinder:setTargetTile(finalTile)
    end
    -- TODO: Train properties
    local path = pathfinder:findPath()
    pathfinder:examine()
    if not path then
        _Log.write(string.format("Could not find path from %s to %s, aborting", self.schematic.shortcut, targetSchematic.shortcut))
        return
    end
    local exitOut = assert(path[1].exitOut)
    local exitTile = self.schematic.index:getExit(exitOut)
    if not exitTile then
        _Log.write(string.format("Target tile pertaining to exit %s not found, aborting", exitOut))
        return
    end
    return exitTile
end

---Dispatches the specified train, if it is currently on the list of trains to be dispatched.
---@param timetable Timetable The timetable of the specified train.
function Dispatcher:dispatchTrain(timetable)
    _Log.write(string.format("Dispatching train %s", timetable.id), Severity.INFO)
    local train = self.trains[timetable.id]
    if not train then
        _Log.write(string.format("Train %s is not registered", timetable.id), Severity.ERROR)
        return false
    end
    for i = 1, 10 do
        local result = self:dispatchStep(timetable)
        if not result then
            break
        end
    end
end

---Dispatches the next step for the specified train, if it is currently on the list of trains to be dispatched.
---Returns `true` if the step has been completed, `false` if the train doesn't exist, has been already dispatched, or the step has not been fully completed.
---@param timetable Timetable The timetable of the specified train.
---@return boolean
function Dispatcher:dispatchStep(timetable)
    _Log.write(string.format("Dispatching step for train %s", timetable.id), Severity.INFO)
    local train = self.trains[timetable.id]
    if not train or train.step == #train.steps then
        _Log.write(string.format("Train %s is not registered or has reached its last step", timetable.id), Severity.ERROR)
        return false
    end
    -- TODO: Probably we should secure ourselves in case some tracks don't have an ID assigned?
    local tile1 = train.steps[train.step].tile
    if not tile1.trackID then
        _Log.write(string.format("Tile %s has no track ID", tile1:getLocation()))
        return false
    end
    local tile2 = train.steps[train.step + 1].tile
    if not tile2.trackID then
        _Log.write(string.format("Tile %s has no track ID", tile2:getLocation()))
        return false
    end
    -- TODO: Add `true` as the last argument after we figure out how to finish off half-completed steps.
    local itineraries = self.schematic:pathfind(tile1.trackID, tile2.trackID, PathMode.TRAIN)
    if not itineraries then
        _Log.write("Could not find the path!")
        return false
    end
    local success = self.schematic:dispatchItineraries(itineraries)
    -- TODO: Partial step fulfillment could stop the entire thing, because the just reserved path might block itself from advancing further!
    if success then
        train.step = train.step + 1
    end
    return success
end

---Ticks the dispatcher logic.
function Dispatcher:tick()
    _Log.write("   Ticked schematic: " .. self.schematic.name)
    -- Find out the trains that are coming or on the station and need generating a plan (step list).
    -- Coming trains:
    for i, exitID in ipairs(_Utils.tableGetSortedKeys(self.schematic.index.exits)) do
        local tile = self.schematic.index:assertGetExit(exitID)
        local timetableID = self:getApproachingTrainTimetableForExit(tile)
        if timetableID then
            local timetable = _Obj:getTimetable(timetableID)
            if timetable then
                self:generateStepsForTrain(tile, timetable)
            end
        end
    end
    -- Trains already here (only when starting the scenery or spawning a train because they don't come from nowhere lol)
    for i, station in ipairs(_Utils.tableGetSortedKeys(self.schematic.index.stations)) do
        for j, stationTrack in ipairs(_Utils.tableGetSortedKeys(self.schematic.index.stations[station].tracks)) do
            local tile = self.schematic.index.stations[station].tracks[stationTrack]
            local track = tile:getTrack()
            if track then
                local timetableID = track:getTimetable()
                if timetableID then
                    local timetable = _Obj:getTimetable(timetableID)
                    if timetable then
                        self:generateStepsForTrain(tile, timetable)
                    end
                end
            end
        end
    end
    -- Dispatch trains for which we've got a plan (step list).
    for timetableID, train in pairs(self.trains) do
        self:dispatchTrain(_Obj:assertGetTimetable(timetableID))
    end
end

---Prints the Dispatcher's internal data to the log.
function Dispatcher:examine()
    _Log.write("======================================================================")
    _Log.write("   Data for schematic: " .. self.schematic.name)
    _Log.write("======================================================================")
    _Log.write("Stations:")
    for i, station in ipairs(self:getStationList()) do
        _Log.write("- " .. station.id)
    end
    _Log.write("Exits:")
    for i, exitID in ipairs(_Utils.tableGetSortedKeys(self.schematic.index.exits)) do
        local tile = self.schematic.index:assertGetExit(exitID)
        local timetableID = self:getApproachingTrainTimetableForExit(tile)
        if timetableID then
            local timetable = _Obj:getTimetable(timetableID)
            if timetable then
                _Log.write(string.format("- %s: %s -> %s", exitID, timetableID, timetable:getFinalStationName()))
            else
                _Log.write(string.format("- %s: %s (Could not get timetable data!)", exitID, timetableID))
            end
        else
            _Log.write(string.format("- %s: ---", exitID))
        end
    end
    _Log.write("Trains:")
    for i, timetableID in ipairs(_Utils.tableGetSortedKeys(self.trains)) do
        _Log.write(string.format("- %s:", timetableID))
        local train = self.trains[timetableID]
        _Log.write(string.format("  - Steps:"))
        for j, step in ipairs(train.steps) do
            _Log.write(string.format("    %s %s", train.step == j and ">" or " ", step.tile:getLocation()))
        end
    end
    _Log.write("======================================================================")
end

return Dispatcher