local class = require "lua.class"

---@class Time
local Time = class:derive("Time")

function Time:new(data)
	self.day = data.day or 0
	self.hour = data.hour
	self.minute = data.minute
	self.second = data.second
	self:fix()
end

function Time.__tostring(o)
	return o:strSeconds()
end

function Time:strDays()
	return "d:" .. tostring(self.day) .. " " .. tostring(self.hour) .. _Ternary(self.minute < 10, ":0", ":") .. tostring(self.minute) .. _Ternary(self.second < 10, ":0", ":") .. tostring(self.second)
end

function Time:strSeconds()
	return tostring(self.hour) .. _Ternary(self.minute < 10, ":0", ":") .. tostring(self.minute) .. _Ternary(self.second < 10, ":0", ":") .. tostring(self.second)
end

function Time:str()
	return tostring(self.hour) .. _Ternary(self.minute < 10, ":0", ":") .. tostring(self.minute)
end

function Time.__eq(o1, o2)
	return o1.day == o2.day and o1.hour == o2.hour and o1.minute == o2.minute and o1.second == o2.second
end

function Time.__add(o1, o2)
	if type(o2) == "number" then
		return Time({day = o1.day, hour = o1.hour, minute = o1.minute, second = o1.second + o2})
	end
	return Time({day = o1.day + o2.day, hour = o1.hour + o2.hour, minute = o1.minute + o2.minute, second = o1.second + o2.second})
end

function Time.__sub(o1, o2)
	if type(o2) == "number" then
		return Time({day = o1.day, hour = o1.hour, minute = o1.minute, second = o1.second - o2})
	end
	return Time({day = o1.day - o2.day, hour = o1.hour - o2.hour, minute = o1.minute - o2.minute, second = o1.second - o2.second})
end

function Time:fix()
	self.minute = self.minute + math.floor(self.second / 60)
	self.second = self.second % 60

	self.hour = self.hour + math.floor(self.minute / 60)
	self.minute = self.minute % 60

	self.day = self.day + math.floor(self.hour / 24)
	self.hour = self.hour % 24
end

function Time:getInt()
	return self.second + (self.minute + (self.hour + self.day * 24) * 60) * 60
end

return Time