local Class = require("lua.class")
local TrackFollower = require("lua.pathfinder.TrackFollower")

---@class Dispatcher : Class
---@overload fun(schematic: Schematic): Dispatcher
local Dispatcher = Class:derive("Dispatcher")

---Creates a Dispatcher, which dispatches routes on a schematic during the simulation.
---@param schematic Schematic The schematic which owns this dispatcher.
function Dispatcher:new(schematic)
    self.schematic = schematic

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
        _LogWrite(string.format("WARNING: Exit `%s` not checked - no destination set", tile.warpID or "nil"))
        return
    end
    local dir = tile:getWarpExitDirection()
    if not dir then
        _LogWrite(string.format("WARNING: Exit `%s` not checked - illegal exit tile placement", tile.warpID or "nil"))
        return
    end
    -- Set up an expedition for the train.
    -- The scan stops at the first unreserved switch, as that's the switch the train may go a different direction in
    -- (we're basically not guaranteed the train will go towards our schematic specifically).
    local follower = TrackFollower(tile, _Dir.invertDir(dir))
    follower:stepUntil(function(scanTile) return scanTile:isTrackOccupied() or (scanTile:isSwitch() and not scanTile:isTrackReserved()) end)
    -- The moment of truth. Did we catch the rabbit?
    local foundTile = follower:getTile()
    local track = foundTile.trackID and _Obj:getTrack(foundTile.trackID)
    return track and track:getTimetable()
end

---Ticks the dispatcher logic.
function Dispatcher:tick()
    _LogWrite("======================================================================")
    _LogWrite("   Ticked schematic: " .. self.schematic.name)
    _LogWrite("======================================================================")
    _LogWrite("Stations:")
    for i, station in ipairs(self:getStationList()) do
        _LogWrite(" - " .. station.id)
    end
    _LogWrite("Exits:")
    for i, exitID in ipairs(_Utils.tableGetSortedKeys(self.schematic.index.exits)) do
        local tile = self.schematic.index.exits[exitID]
        local timetableID = self:getApproachingTrainTimetableForExit(tile)
        if timetableID then
            local timetable = _Timetables:getTimetable(timetableID)
            if timetable then
                _LogWrite(string.format(" - %s: %s -> %s", exitID, timetableID, timetable:getFinalStationName()))
            else
                _LogWrite(string.format(" - %s: %s (Could not get timetable data!)", exitID, timetableID))
            end
        else
            _LogWrite(string.format(" - %s: ---", exitID))
        end
    end
    _LogWrite("======================================================================")
end

return Dispatcher