local Class = require("lua.class")
local Time = require("lua.Time")
local utf8 = require("lua.utf8")

---@class Timetables : Class
---@overload fun(data): Timetables
local Timetables = Class:derive("Timetables")

---Creates a timetable manager. This will be used to store and generate timetables.
function Timetables:new()
end

---Converts the time from string format to a time object.
---Preceding zeroes are allowed.
---The hours and minutes must be separated with either `:` or `.`.
---Seconds can be specified by `.X` for 6-second intervals or `:XX` for specifying an exact number of seconds.
---@param time string The time in string format.
---@return Time
function Timetables:timeToObj(time)
    _LogWrite(string.format("Generating time from string: `%s`", time))
    local n = "" -- Aggregates a number
    local sep = nil -- Last encountered separator
    local step = 0 -- 0 for hours, 1 for minutes, 2 for seconds
    local data = {hour = 0, minute = 0} -- Data for the time object
    for i = 1, time:len() do
        local c = time:sub(i, i)
        if c ~= "." and c ~= ":" then
            n = n .. c
        end
        if c == "." or c == ":" or i == time:len() then
            if step == 0 then
                data.hour = assert(tonumber(n), string.format("Invalid hour value: `%s`", n))
            elseif step == 1 then
                data.minute = assert(tonumber(n), string.format("Invalid minute value: `%s`", n))
            elseif step == 2 then
                local second = assert(tonumber(n), string.format("Invalid second value: `%s`", n))
                data.second = sep == ":" and second or second * 6
            end
            n = ""
            sep = c
            step = step + 1
        end
    end
    _LogWrite(string.format("Result: hour=%s, minute=%s, second=%s", data.hour, data.minute, data.second))
    return Time(data)
end

---Converts the time from the time object to the string format suitable for parsing inside MaSzyna as a timetable file.
---The resulting format is always `hh.mm.s` with no preceding zeroes and 6-second intervals. The seconds are rounded down if necessary.
---@param time Time The time object to be converted.
---@return string
function Timetables:timeToStr(time)
    return tostring(time.hour) .. (time.minute < 10 and ".0" or ".") .. tostring(time.minute) .. (time.second >= 6 and "." .. math.floor(time.second / 6) or "")
end

---Generates a timetable file.
---@param number string The full train number, e.g. `"ROJ55101"`.
---@param data table The timetable data.
---@param startTime string The starting timetable time, e.g. `"10:30"`. Fractions are allowed, like `"10:30.5"`.
function Timetables:generate(number, data, startTime)
    local station1 = _Utils.strReplace(data.station1 or data.stations[1].name, " ", "_")
    local station2 = _Utils.strReplace(data.station2 or data.stations[#data.stations].name, " ", "_")

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
    local time = self:timeToObj(startTime)
    for i, station in ipairs(data.stations) do
        tracks = station.tracks or tracks
        if i > 1 then
            result = result .. "[       |" .. (station.speed and "_____" or "     ") .. "|----------------------------------" .. tracks .. "-----------|-----]\n"
        end
        time = time + (station.travelTime or 0) * 60
        result = result .. "[ " .. (station.km or "") .. " | " .. (station.speed or "") .. " | " .. _Utils.strReplace(station.name, " ", "_") .. " " .. tracks .. " " .. ((station.stopTime or i == 1 or i == #data.stations) and self:timeToStr(time) or "  |  ") .. " |     ]\n"
        time = time + (station.stopTime or 0) * 60
        result = result .. "[       |     |                              po  " .. tracks .. " " .. (i < #data.stations and self:timeToStr(time) or "") .. " |     ]\n"
    end
    result = result .. "[_______|_____|__________________________________" .. tracks .. "___________|_____]\n"

    _Utils.saveFile("scenery/luascript/rj_tmp.txt", result)
end

return Timetables