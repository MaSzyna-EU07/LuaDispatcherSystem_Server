local Class = require("lua.core.class")
local TrackFollower = require("lua.core.Pathfinder.TrackFollower")
local MapPathfinder = require("lua.MapPathfinder.MapPathfinder")
local Severity = require("lua.core.Utils.LogSeverity")
local PathMode = require("lua.core.Enums.PathMode")

---@class Dispatcher : Class
---@overload fun(schematic: Schematic): Dispatcher
local Dispatcher = Class:derive("Dispatcher")

---@alias Train {steps: {tile: Tile}[], step: integer}

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
    _Log.write(string.format("Starting from tile %s", tile:getLocation()))
    local follower = TrackFollower(tile, _Dir.invertDir(dir))
    -- Abort the scan if the switch is switched the other way, so we don't "slide" into another path.
    follower:setSwitchForceStop(true)
    follower:stepUntil(function(scanTile) return scanTile:isTrackOccupied() or (scanTile:isSwitch() and not scanTile:isTrackReserved()) end)
    -- The moment of truth. Did we catch the rabbit?
    local foundTile = follower:getTile()
    _Log.write(string.format("Landed on tile %s", foundTile:getLocation()))
    local track = foundTile.trackID and _Obj:getTrack(foundTile.trackID)
    if not track or track:isClear() then
        -- We might have ended the scan at an unreserved switch. In that case, the search fails.
        _Log.write("Search ended on a dead end or an unoccupied/unreserved tile! Whoops!", Severity.FAIL, 1)
        return
    end
    _Log.write(string.format("Track: %s, %s (%s vehicles)", tostring(foundTile.trackID), tostring(track), tostring(track and _Utils.tableCountKeys(track.vehicles))))
    return track:getTimetable()
end

---Returns a list of timetable entries to be dispatched towards for the given timetable, in the order of their servicing.
---Already serviced stations are omitted.
---@param timetable Timetable The timetable to source the station list from.
---@return TimetableEntry[]
function Dispatcher:getStationListForTimetable(timetable)
    local entries = {}
    for i, entry in ipairs(timetable.stations) do
        if not entry.departureAct and self.schematic.index.stations[entry.name] then
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
    -- TODO: There should be a pool of tiles to pick from in case our track is occupied but the track next to it is free!
    -- TODO: What about passing through the schematic multiple times?
    local entries = self:getStationListForTimetable(timetable)
    for i, entry in ipairs(entries) do
        local stationTile = self.schematic.index.stations[entry.name].tracks[entry.track]
        if stationTile then
            table.insert(train.steps, {tile = stationTile})
        else
            _Log.write(string.format("Skipped missing tile for station %s track %s on schematic %s", entry.name, entry.track, self.schematic.shortcut), Severity.ERROR)
        end
    end
    -- Find out the correct exit tile.
    local destination = timetable:getFinalStationName()
    local targetSchematic = _MapIndex:getSchematicForStation(destination)
    if targetSchematic ~= self.schematic then
        -- If we don't enter this block, this is the final station! We're done!
        if not targetSchematic then
            _Log.write(string.format("Could not find schematic for station %s, aborting", destination))
            return
        end
        local pathfinder = MapPathfinder(self.schematic, targetSchematic)
        -- Make sure to consider only exits that this schematic can physically find the path to.
        pathfinder:setInboundExit(tile.warpID)
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
        table.insert(train.steps, {tile = exitTile})
    end
    self.trains[timetable.id] = train
    _Log.write(string.format("Generated step list for train %s at %s", timetable.id, tile:getLocation()), Severity.INFO)
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
---Returns `true` if the step has been fulfilled, `false` if the train doesn't exist or has been already dispatched.
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
    local success = self.schematic:pathfind(tile1.trackID, tile2.trackID, PathMode.TRAIN)
    -- TODO: Partial step fulfillment could stop the entire thing, because the just reserved path might block itself from advancing further!
    if success then
        train.step = train.step + 1
    end
    return success
end

---Ticks the dispatcher logic.
function Dispatcher:tick()
    _Log.write("======================================================================")
    _Log.write("   Ticked schematic: " .. self.schematic.name)
    _Log.write("======================================================================")
    for timetableID, train in pairs(self.trains) do
        self:dispatchTrain(_Obj:assertGetTimetable(timetableID))
    end
    _Log.write("Stations:")
    for i, station in ipairs(self:getStationList()) do
        _Log.write("- " .. station.id)
    end
    _Log.write("Exits:")
    for i, exitID in ipairs(_Utils.tableGetSortedKeys(self.schematic.index.exits)) do
        local tile = assert(self.schematic.index:getExit(exitID))
        local timetableID = self:getApproachingTrainTimetableForExit(tile)
        if timetableID then
            local timetable = _Obj:getTimetable(timetableID)
            if timetable then
                _Log.write(string.format("- %s: %s -> %s", exitID, timetableID, timetable:getFinalStationName()))
                self:generateStepsForTrain(tile, timetable)
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