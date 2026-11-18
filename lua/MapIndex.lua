local Class = require("lua.core.class")

---Represents an index of the entire map. Indexes relations between schematics.
---Indexing is done once per reload and allows various elements to directly fetch data about certain states
---without having to recalculate it each time.
---@class MapIndex : Class
---@overload fun(): MapIndex
local MapIndex = Class:derive("MapIndex")

---Creates a new Map Index.
function MapIndex:new()
    -- TODO: Do actual indexing
end

---Returns the schematic which owns the specified station by name.
---If no schematic contains this station, returns `nil`.
---@param station string The station name:
---@return Schematic?
function MapIndex:getSchematicForStation(station)
    -- TODO: Include this in indexing rather than calculating this on the fly.
    for i, shortcut in ipairs(_Obj:getSchematicList()) do
        local schematic = _Obj:assertGetSchematic(shortcut)
        if schematic.index.stations[station] then
            return schematic
        end
    end
end

return MapIndex