local Class = require("lua.class")
local Timetable = require("lua.Timetable")

---@class Timetables : Class
---@overload fun(data): Timetables
local Timetables = Class:derive("Timetables")

---Creates a timetable manager. This will be used to store and generate timetables.
function Timetables:new()
    ---@type table<string, Timetable>
    self.timetables = {}
end

---Generates a timetable file.
---@param number string The full train number, e.g. `"ROJ55101"`.
---@param data table The timetable data.
---@param startTime string The starting timetable time, e.g. `"10:30"`. Fractions are allowed, like `"10:30.5"`.
function Timetables:generate(number, data, startTime)
    local timetable = Timetable(number, data, startTime)
    self.timetables[number] = timetable
    timetable:exportSim()
end

return Timetables