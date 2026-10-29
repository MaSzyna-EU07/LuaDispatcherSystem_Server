local Class = require("lua.class")
local Time = require("lua.Time")

---@class Timetable : Class
---@overload fun(id: string, data: table, startTime: string): Timetable
local Timetable = Class:derive("Timetable")

---Creates a new Timetable.
---@param id string Timetable ID (train number).
---@param data table Timetable data.
---@param startTime string The starting timetable time, e.g. `"10:30"`. Fractions are allowed, like `"10:30.5"`.
function Timetable:new(id, data, startTime)
    _LogWrite(string.format("Creating timetable for train `%s`, starting at %s...", id, startTime))
    self.id = id
    ---@alias TimetableEntry {name: string, track: string?, arrival: Time?, departure: Time?, speed: integer?, km: number?, tracks: integer?}
    ---@type TimetableEntry[]
    self.stations = {}

    _LogWrite("- Stations:")
    _LogWrite("  -  Station             | Arr   | Dep   | Track | Speed | Km    | Tracks")
    local time = _Time.timeToObj(startTime)
    for i, stationData in ipairs(data.stations) do
        ---@type TimetableEntry
        local station = {}

        -- Copy over simple parameters
        station.name = stationData.name
        station.track = stationData.track
        station.speed = stationData.speed
        station.km = stationData.km
        station.tracks = stationData.tracks

        -- Calculate arrival and departure times
        time = time + (stationData.travelTime or 0) * 60
        -- Arrival time is present if the train is stopping on the station, and also on the first and last stop
        station.arrival = (stationData.stopTime or i == 1 or i == #data.stations) and time or nil
        time = time + (stationData.stopTime or 0) * 60
        -- Departure time is present if this is not the final stop
        station.departure = i < #data.stations and time or nil

        local strStation = _Utils.strPad(station.name, 20)
        local strArr = _Utils.strPad(station.arrival and _Time.timeToStrRJ(station.arrival) or "  |  ", 7)
        local strDep = _Utils.strPad(station.departure and _Time.timeToStrRJ(station.departure) or "", 7)
        local strTrack = _Utils.strPad(station.track or "", 5)
        local strSpeed = _Utils.strPad(station.speed and tostring(station.speed) or "", 5)
        local strKm = _Utils.strPad(station.km and tostring(station.km) or "", 7)
        local strTracks = _Utils.strPad(station.tracks and tostring(station.tracks) or "", 5)
        _LogWrite(string.format("  - %s |%s|%s| %s | %s |%s| %s", strStation, strArr, strDep, strTrack, strSpeed, strKm, strTracks))

        self.stations[i] = station
    end
    _LogWrite(string.format("Created timetable `%s`!", id))
end

---Generates timetable text to be parsed by the simulator.
---@return string
function Timetable:generateSimText()
    local station1 = _SanitizeASCII(_Utils.strReplace(self.stations[1].name, " ", "_"))
    local station2 = _SanitizeASCII(_Utils.strReplace(self.stations[#self.stations].name, " ", "_"))

    local result = ""
    -- Header
    result = result .. " __________________________________________________________________ \n"
    result = result .. "[ Rodzaj i numer pociągu                         | " .. self.id .. " ]\n"
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
    for i, station in ipairs(self.stations) do
        tracks = station.tracks or tracks
        if i > 1 then
            result = result .. "[       |" .. (station.speed and "_____" or "     ") .. "|----------------------------------" .. tracks .. "-----------|-----]\n"
        end
        local km = station.km or ""
        local speed = station.speed or ""
        local name = _SanitizeASCII(_Utils.strReplace(station.name, " ", "_"))
        local strArrival = station.arrival and _Time.timeToStr(station.arrival) or "  |  "
        result = result .. "[ " .. km .. " | " .. speed .. " | " .. name .. " " .. tracks .. " " .. strArrival .. " |     ]\n"
        local strDeparture = station.departure and _Time.timeToStr(station.departure) or ""
        result = result .. "[       |     |                              po  " .. tracks .. " " .. strDeparture .. " |     ]\n"
    end
    result = result .. "[_______|_____|__________________________________" .. tracks .. "___________|_____]\n"
    return result
end

---Saves the timetable text to a temporary file that can be loaded by the simulator.
function Timetable:exportSim()
    _Utils.saveFile("scenery/luascript/rj_tmp.txt", self:generateSimText())
end

return Timetable