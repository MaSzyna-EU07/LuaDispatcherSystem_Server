local class = require "lua.class"
local Track = require("lua.Track")
local Switch = require("lua.Switch")
local Semaphore = require("lua.Semaphore")

---@class Station
local Station = class:derive("Station")

function Station:new(name, data)
	_Com.initStation(name)

	self.name = name

	-- Tracks
	for i, trackN in ipairs(data.tracks) do
		_Obj:addTrack(Track(self, self.name .. "_" .. trackN))
	end
	-- Switches
	for i, switchN in ipairs(data.switches) do
		_Obj:addSwitch(Switch(self, self.name .. "_" .. switchN))
	end
	-- Semaphores
	for semaphoreN, semaphoreData in pairs(data.semaphores) do
		_Obj:addSemaphore(Semaphore(self, self.name .. "_" .. semaphoreN, semaphoreData))
	end
end

function Station:tell(text, severity, weight)
	_LogWrite("station: " .. self.name .. ": " .. text, severity, weight)
end

return Station