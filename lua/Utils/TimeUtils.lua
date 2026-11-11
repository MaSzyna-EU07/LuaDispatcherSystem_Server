local Time = require("lua.Time")

---Functions for time conversion.
local TimeUtils = {}

---Converts the time from string format to a time object.
---Preceding zeroes are allowed.
---The hours and minutes must be separated with either `:` or `.`.
---Seconds can be specified by `.X` for 6-second intervals or `:XX` for specifying an exact number of seconds.
---@param time string The time in string format.
---@return Time
function TimeUtils.timeToObj(time)
    local n = "" -- Aggregates a number
    local sep = nil -- Last encountered separator
    local step = 0 -- 0 for hours, 1 for minutes, 2 for seconds
    local data = {h = 0, m = 0} -- Data for the time object
    for i = 1, time:len() do
        local c = time:sub(i, i)
        if c ~= "." and c ~= ":" then
            n = n .. c
        end
        if c == "." or c == ":" or i == time:len() then
            if step == 0 then
                data.h = assert(tonumber(n), string.format("Invalid hour value: `%s`", n))
            elseif step == 1 then
                data.m = assert(tonumber(n), string.format("Invalid minute value: `%s`", n))
            elseif step == 2 then
                local s = assert(tonumber(n), string.format("Invalid second value: `%s`", n))
                data.s = sep == ":" and s or s * 6
            end
            n = ""
            sep = c
            step = step + 1
        end
    end
    return Time(data)
end

---Converts the time from the time object to the string format suitable for parsing inside MaSzyna as a timetable file.
---The resulting format is always `hh.mm.s` with no preceding zeroes and 6-second intervals. The seconds are rounded down if necessary.
---@param time Time The time object to be converted.
---@return string
function TimeUtils.timeToStr(time)
    return tostring(time.h) .. (time.m < 10 and ".0" or ".") .. tostring(time.m) .. (time.s >= 6 and "." .. math.floor(time.s / 6) or "")
end

---Similarly to `timeToStr()`, turns time into the `hh:mm.s` format, but with a preceding zero and with a colon instead of a period.
---@param time Time The time to be converted.
---@return string
function TimeUtils.timeToStrRJ(time)
	return (time.h < 10 and "0" or "") .. time.h .. (time.m < 10 and ":0" or ":") .. time.m .. (time.s >= 6 and "." .. math.floor(time.s / 6) or "")
end

return TimeUtils