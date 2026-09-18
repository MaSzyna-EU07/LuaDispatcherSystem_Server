local Class = require("lua.class")
local Tile = require("lua.Tile")
local SchematicIndex = require("lua.SchematicIndex")
local Pathfinder = require("lua.pathfinder.Pathfinder")

---Represents a station schematic, comprised of tiles.
---@class Schematic : Class
---@overload fun(station, data): Schematic
local Schematic = Class:derive("Schematic")

---Creates a schematic from schematic data.
---@param station Station The station this schematic belongs to.
---@param data table Schematic data.
function Schematic:new(station, data)
    self.station = station

    self.name = ""
    self.shortcut = ""
    self.w, self.h = 25, 10
    ---@type Tile[][]
    self.tiles = {}
    self:deserialize(data)

    self.index = SchematicIndex(self)
	self.index:generateIndex()
end

---Returns a tile from this station based on coordinates, or `nil` if no tile lies at that location.
---@param x integer X coordinate of the tile.
---@param y integer Y coordinate of the tile.
---@return Tile?
function Schematic:getTile(x, y)
	return self.tiles[x] and self.tiles[x][y]
end

---Returns a tile from this station based on coordinates, or throws an error if no tile lies at that location.
---@param x integer X coordinate of the tile.
---@param y integer Y coordinate of the tile.
---@return Tile
function Schematic:assertGetTile(x, y)
	return assert(self:getTile(x, y), string.format("There is no tile at (%s, %s)", x, y))
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
---Returns `true` on success, `false` on failure.
---@param track1 string The ID of the first track to pathfind from. This would usually be a track a train is on.
---@param track2 string The ID of the destination track to pathfind to.
---@param mode PathMode The mode of the dispatching: whether to display a train or a shunting signal.
---@return boolean
function Schematic:pathfind(track1, track2, mode)
	self.station:tell(string.format("Pathfinding from %s to %s...", track1, track2), Severity.INFO, 1)
	local track1Info = self.index:getTrack(track1)
	local track2Info = self.index:getTrack(track2)
	if not track1Info or not track2Info then
		self.station:tell("Failed: Not all tracks exist", Severity.FAIL, 1)
		-- If any of the tracks doesn't exist, we're out.
		return false
	end
	local target = mode == PathMode.TRAIN and track2Info.trainTarget or track2Info.shuntTarget
	if not target then
		self.station:tell("Failed: Target point not found", Severity.FAIL, 1)
		-- We cannot pathfind there.
		return false
	end
	-- Attempt to pathfind from any of the semaphores on the starting track.
	for i, semaphore in ipairs(track1Info.semaphores) do
		local tile = self.index:getSemaphore(semaphore.id)
		self.station:tell(string.format("Attempting with %s...", semaphore.id), Severity.INFO, 1)
		if tile then
			-- Summon a pathfinder and let it find the path...
			local pathfinder = Pathfinder(tile, target)
			pathfinder:setMode(mode)
			local success = pathfinder:calculatePath()
			if success then
				-- We found a route! Dispatch it and we can start a party
				pathfinder:dispatch()
				return true
			end
		end
	end
	self.station:tell("Failed: Pathfinding failed for all semaphores", Severity.FAIL, 1)
	-- Nothing worked... :(
	return false
end

---Attempts to pathfind between two given tiles on this schematic with the given path mode.
---Returns `true` on success, `false` on failure.
---@param tile1 Tile The first tile to pathfind from. Must be a semaphore tile.
---@param tile2 Tile The destination tile to pathfind to.
---@param mode PathMode The mode of the dispatching: whether to display a train or a shunting signal.
---@return boolean
function Schematic:pathfindTiles(tile1, tile2, mode)
	if not tile1:isSemaphore() then
		-- The first tile must be a semaphore.
		return false
	end
	-- Summon a pathfinder and let it find the path...
	local pathfinder = Pathfinder(tile1, tile2)
	pathfinder:setMode(mode)
	local success = pathfinder:calculatePath()
	if success then
		-- We found a route! Dispatch it and we can start a party
		pathfinder:dispatch()
		return true
	end
	-- We didn't find the path...
	return false
end

---Deserializes the Station's data to be restored from a file.
---@param t table The saved data.
function Schematic:deserialize(t)
	self.name = t.name
	self.shortcut = t.shortcut
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