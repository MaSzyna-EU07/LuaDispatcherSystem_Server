local Class = require("lua.class")

---@class Timetables : Class
---@overload fun(data): Timetables
local Timetables = Class:derive("Timetables")

---Creates a timetable manager. This will be used to store and generate timetables.
function Timetables:new()
end

---Generates a timetable file.
---@param number string The full train number, e.g. `"ROJ55101"`.
---@param data table The timetable data.
---@param startTime string The starting timetable time, e.g. `"10:30"`. Fractions are allowed, like `"10:30.5"`.
function Timetables:generate(number, data, startTime)
    local station1 = _SanitizeASCII(_Utils.strReplace(data.station1 or data.stations[1].name, " ", "_"))
    local station2 = _SanitizeASCII(_Utils.strReplace(data.station2 or data.stations[#data.stations].name, " ", "_"))

    local result = ""
    -- Header
    result = result .. " __________________________________________________________________ \n"
    result = result .. "[ Rodzaj i numer pociągu                         | " .. number .. " ]\n"
    result = result .. "[________________________________________________|_________________]\n"
    result = result .. "[                                                | " .. station1 .. " ]\n"
    result = result .. "[ Relacja pociągu                                | " .. station2 .. " ]\n"
    result = result .. "[________________________________________________|_________________]\n"
    result = result .. "[ Wymagany % ciężaru hamującego                  | 88%             ]\n"
    result = result .. "[________________________________________________|_________________]\n"
    result = result .. "[ Seria i obciążenie lokomotywy                  | EN57 192        ]\n"
    result = result .. "[________________________________________________|_________________]\n"
    -- Stations
    local tracks = 2
    local time = _Time.timeToObj(startTime)
    for i, station in ipairs(data.stations) do
        tracks = station.tracks or tracks
        if i > 1 then
            result = result .. "[       |" .. (station.speed and "_____" or "     ") .. "|----------------------------------" .. tracks .. "-----------|-----]\n"
        end
        time = time + (station.travelTime or 0) * 60
        local km = station.km or ""
        local speed = station.speed or ""
        local name = _SanitizeASCII(_Utils.strReplace(station.name, " ", "_"))
        local strTime = (station.stopTime or i == 1 or i == #data.stations) and _Time.timeToStr(time) or "  |  "
        result = result .. "[ " .. km .. " | " .. speed .. " | " .. name .. " " .. tracks .. " " .. strTime .. " |     ]\n"
        time = time + (station.stopTime or 0) * 60
        result = result .. "[       |     |                              po  " .. tracks .. " " .. (i < #data.stations and _Time.timeToStr(time) or "") .. " |     ]\n"
    end
    result = result .. "[_______|_____|__________________________________" .. tracks .. "___________|_____]\n"

    _Utils.saveFile("scenery/luascript/rj_tmp.txt", result)
end

return Timetables