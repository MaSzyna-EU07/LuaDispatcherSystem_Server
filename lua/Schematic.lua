local Class = require("lua.core.class")
local Tile = require("lua.core.Tile")
local SchematicIndex = require("lua.SchematicIndex")
local Dispatcher = require("lua.Dispatcher")
local Pathfinder = require("lua.core.Pathfinder.Pathfinder")
local Severity = require("lua.core.Utils.LogSeverity")
local PathMode = require("lua.core.Enums.PathMode")

---Represents a station schematic, comprised of tiles.
---@class Schematic : Class
---@overload fun(shortcut): Schematic
local Schematic = Class:derive("Schematic")

---Creates a new empty schematic.
---To load data from it, call `:reload()` on the created schematic.
---@param shortcut string The schematic shortcut.
function Schematic:new(shortcut)
	_Com.initSchematic(shortcut)
	self.shortcut = shortcut

    self.name = ""
    self.w, self.h = 25, 10
    ---@type Tile[][]
    self.tiles = {}

    self.index = nil
	self.dispatcher = Dispatcher(self)
end

---Reloads this schematic.
---@param data table New schematic data.
function Schematic:reload(data)
	self:say("Reloading schematic...", Severity.INFO, 3)
	self:deserialize(data)
    self.index = SchematicIndex(self)
	self.index:generateIndex()
	self.index:print()
	self:say("Schematic reloaded!", Severity.SUCCESS, 3)
	_Com.notify(self.shortcut .. ": Schematic reloaded!")
end

---Returns a tile from this schematic based on coordinates, or `nil` if no tile lies at that location.
---@param x integer X coordinate of the tile.
---@param y integer Y coordinate of the tile.
---@return Tile?
function Schematic:getTile(x, y)
	return self.tiles[x] and self.tiles[x][y]
end

---Returns a tile from this schematic based on coordinates, or throws an error if no tile lies at that location.
---@param x integer X coordinate of the tile.
---@param y integer Y coordinate of the tile.
---@return Tile
function Schematic:assertGetTile(x, y)
	return assert(self:getTile(x, y), string.format("There is no tile at %s:%s,%s", self.shortcut, x, y))
end

---Returns another schematic of this project, or `nil` if there is none with that shortcut.
---The shared `Tile` code resolves warps through this function.
---@param shortcut string The schematic shortcut.
---@return Schematic?
function Schematic:findSchematic(shortcut)
	return _Obj:getSchematic(shortcut)
end

---Returns the exit point tile with the given ID on this schematic, or `nil` if there is none.
---The shared `Tile` code resolves warps through this function.
---@param exitID string The exit point ID.
---@return Tile?
function Schematic:getExitTile(exitID)
	return self.index:getExit(exitID)
end

---Fills in default next semaphore pointers based on the schematic layout.
---@see SchematicIndex.generateSemaphoreNextDefaults
function Schematic:generateSemaphoreNextDefaults()
	self.index:generateSemaphoreNextDefaults()
end

---Generates blockades originating on this schematic.
function Schematic:generateBlockades()
	self.index:generateBlockades()
end

---Attempts to pathfind between two given tracks on this schematic with the given path mode.
---Returns the list of itineraries on success, `nil` on failure.
---Resulting itineraries can be passed to `:dispatchItineraries()` to dispatch them.
---@param track1 string The ID of the first track to pathfind from. This would usually be a track a train is on.
---@param track2 string The ID of the destination track to pathfind to.
---@param mode PathMode The mode of the dispatching: whether to display a train or a shunting signal.
---@param ignoreOccupied boolean? Whether track occupancy should be ignored.
---@return Itinerary[]?
function Schematic:pathfind(track1, track2, mode, ignoreOccupied)
	self:say(string.format("Finding path from %s to %s...", track1, track2), Severity.INFO, 1)
	local track1Info = self.index:getTrack(track1)
	local track2Info = self.index:getTrack(track2)
	if not track1Info or not track2Info then
		self:say("Failed: Not all tracks exist", Severity.FAIL, 1)
		-- If any of the tracks doesn't exist, we're out.
		return nil
	end
	local target = mode == PathMode.TRAIN and track2Info.trainTarget or track2Info.shuntTarget
	if not target then
		self:say("Failed: Target point not found", Severity.FAIL, 1)
		-- We cannot pathfind there.
		return nil
	end
	-- Attempt to pathfind from any of the semaphores on the starting track.
	for i, semaphore in ipairs(track1Info.semaphores) do
		self:say(string.format("Attempting with %s...", semaphore.id), Severity.INFO, 1)
		local tile = self.index:getSemaphore(semaphore.id)
		if tile then
			local itineraries = self:pathfindTiles(tile, target, mode, ignoreOccupied)
			if itineraries then
				-- Hooray! The route has been found!
				return itineraries
			end
		end
	end
	self:say("Failed: Pathfinding failed for all semaphores", Severity.FAIL, 1)
	-- Nothing worked... :(
	return nil
end

---Attempts to pathfind between two given tiles on this schematic with the given path mode.
---Returns the list of itineraries on success, `nil` on failure.
---Resulting itineraries can be passed to `:dispatchItineraries()` to dispatch them.
---@param tile1 Tile The first tile to pathfind from. Must be a semaphore tile.
---@param tile2 Tile The destination tile to pathfind to.
---@param mode PathMode The mode of the dispatching: whether to display a train or a shunting signal.
---@param ignoreOccupied boolean? Whether track occupancy should be ignored.
---@return Itinerary[]?
function Schematic:pathfindTiles(tile1, tile2, mode, ignoreOccupied)
	if not tile1:isSemaphore() then
		-- The first tile must be a semaphore.
		return nil
	end
	-- Summon a pathfinder and let it find the path...
	local pathfinder = Pathfinder(tile1, tile2)
	pathfinder:setMode(mode)
	if ignoreOccupied then
		pathfinder:setIgnoreOccupied(true)
	end
	return pathfinder:findPathAndGetItineraries()
end

---Reserves all tracks, sets all switches and displays a clear signal on the semaphore.
---Returns `true` if all itineraries have been successfully dispatched, `false` otherwise.
---@param itineraries Itinerary[] The list of itineraries to be dispatched.
---@return boolean
function Schematic:dispatchItineraries(itineraries)
    local dispatched = 0
    for i, itinerary in ipairs(itineraries) do
        -- Itineraries are dispatched only until the first failing one, so that we aren't left with a partially dispatched route.
        if not itinerary:canBeDispatched() then
            if dispatched == 0 then
                _Com.notify("None of the itineraries could be dispatched... Check log for details.", NotificationColor.RED)
            else
                _Com.notify(string.format("Dispatched only %s out of %s itineraries! Check log for details.", dispatched, #itineraries), NotificationColor.ORANGE)
            end
            return false
        end
        itinerary:dispatch()
        dispatched = dispatched + 1
    end
	return true
end

---Returns `true` if the schematic can find a path between all tiles in this order.
---All provided tiles must be a part of this schematic.
---@param tiles Tile[] A list of tiles to find a path through.
---@param mode PathMode The mode of the dispatching: whether to display a train or a shunting signal.
---@return boolean
function Schematic:doesPathExist(tiles, mode)
	self:say(string.format("Checking whether path exists between the following tiles: %s", _StrTileList(tiles)))
	if #tiles == 2 and tiles[1].warpID and tiles[2].warpID then
		-- Try a more general example by using the index.
		local routingInfo = self.index:getRoutingInfo(tiles[1].warpID, tiles[2].warpID)
		local result = routingInfo and routingInfo.traversable or false
		self:say(string.format("The answer is: %s!", result and "yes" or "no"))
		return result
	end
	-- Custom list of tiles - do it on the fly.
	-- TODO: Caching?
	for i = 1, #tiles - 1 do
		local tile1 = tiles[i]
		local tile2 = tiles[i + 1]
		if not self:pathfind(tile1.trackID, tile2.trackID, mode) then
			self:say(string.format("No path found between %s and %s! The answer is: no!", tile1:getLocation(), tile2:getLocation()))
			return false
		end
	end
	self:say("The answer is: yes!")
	return true
end

---Sends an information about this schematic to the log.
---@param text string The message to be written.
---@param severity LogSeverity? The message severity.
---@param weight integer? The message weight.
function Schematic:say(text, severity, weight)
	_Log.write(string.format("%s: %s", self.shortcut, text), severity, weight)
end

---Deserializes the schematic data loaded from a file.
---@param t table The saved data.
function Schematic:deserialize(t)
	self.name = t.name
	-- The shortcut is deliberately omitted as it could cause desynchronization and other bad things! It's constant anyway lol
	self.w, self.h = t.w, t.h
	self.tiles = {}
	for x = 1, self.w do
		self.tiles[x] = {}
		for y = 1, self.h do
			local tile = Tile(self, x, y)
			tile:deserialize(t.tiles[tostring(x) .. "," .. tostring(y)])
			self.tiles[x][y] = tile
		end
	end
end

return Schematic