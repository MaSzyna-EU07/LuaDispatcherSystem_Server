local class = require "lua.class"

---@class Time
---@overload fun(data: {d: integer?, h: integer, m: integer, s: number?}?): Time
---@operator add(Time|number): Time
---@operator sub(Time|number): Time
local Time = class:derive("Time")

function Time:new(data)
	self.d = data and data.d or 0
	self.h = data and data.h or 0
	self.m = data and data.m or 0
	self.s = data and data.s or 0
	self:fix()
end

---Makes a new Time object directly from hours and minutes.
---@param h integer Amount of hours.
---@param m integer Amount of minutes.
---@return Time
function Time.hm(h, m)
	local self = Time()
	self.h, self.m = h, m
	self:fix()
	return self
end

---Makes a new Time object directly from hours, minutes and seconds.
---@param h integer Amount of hours.
---@param m integer Amount of minutes.
---@param s number Amount of seconds.
---@return Time
function Time.hms(h, m, s)
	local self = Time()
	self.h, self.m, self.s = h, m, s
	self:fix()
	return self
end

---Makes a new Time object directly from days, hours, minutes and seconds.
---@param d number Amount of days.
---@param h integer Amount of hours.
---@param m integer Amount of minutes.
---@param s number Amount of seconds.
---@return Time
function Time.dhms(d, h, m, s)
	local self = Time()
	self.d, self.h, self.m, self.s = d, h, m, s
	self:fix()
	return self
end

function Time:__tostring()
	return self:strSeconds()
end

---Returns stringified time in `d:D HH:MM:SS` format.
---@return string
function Time:strDays()
	return string.format("d:%s %02d:%02d:%02d", self.d, self.h, self.m, self.s)
end

---Returns stringified time in `HH:MM:SS` format.
---@return string
function Time:strSeconds()
	return string.format("%02d:%02d:%02d", self.h, self.m, self.s)
end

---Returns stringified time in `HH:MM` format.
---@return string
function Time:str()
	return string.format("%02d:%02d", self.h, self.m)
end

---Checks equality of two time objects.
---@param o1 Time First time object.
---@param o2 Time Second time object.
---@return boolean
function Time.__eq(o1, o2)
	return o1.d == o2.d and o1.h == o2.h and o1.m == o2.m and o1.s == o2.s
end

---Adds two time objects.
---@param o1 Time First time object.
---@param o2 Time|number Second time object or a number of seconds.
---@return Time
function Time.__add(o1, o2)
	if type(o2) == "number" then
		return Time({d = o1.d, h = o1.h, m = o1.m, s = o1.s + o2})
	end
	return Time({d = o1.d + o2.d, h = o1.h + o2.h, m = o1.m + o2.m, s = o1.s + o2.s})
end

---Subtracts two time objects.
---@param o1 Time First time object.
---@param o2 Time|number Second time object or a number of seconds.
---@return Time
function Time.__sub(o1, o2)
	if type(o2) == "number" then
		return Time({d = o1.d, h = o1.h, m = o1.m, s = o1.s - o2})
	end
	return Time({d = o1.d - o2.d, h = o1.h - o2.h, m = o1.m - o2.m, s = o1.s - o2.s})
end

---Makes sure this time object's second, minute and hour values fall within the expected range.
function Time:fix()
	self.m = self.m + math.floor(self.s / 60)
	self.s = self.s % 60

	self.h = self.h + math.floor(self.m / 60)
	self.m = self.m % 60

	self.d = self.d + math.floor(self.h / 24)
	self.h = self.h % 24
end

---Returns the number of seconds from 00:00:00.
---@return number
function Time:getInt()
	return self.s + (self.m + (self.h + self.d * 24) * 60) * 60
end

return Time