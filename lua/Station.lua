local Class = require("lua.core.class")

---@class Station : Class
---@overload fun(id: string): Station
local Station = Class:derive("Station")

---Creates a new Station, not to be confused with Schematics.
---Stations are purely for timetable purposes: timetables contain stations, and stations can be queried for timetables.
---A single schematic (for example, a route) may contain multiple stations.
---@param id string The station ID (its full name).
function Station:new(id)
    self.id = id
end

return Station