local Class = require("lua.class")
local Tile = require("lua.Tile")
local SchematicIndex = require("lua.SchematicIndex")

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