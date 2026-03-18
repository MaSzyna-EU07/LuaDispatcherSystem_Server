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
		local id = data.prefixDeviceNames and (self.name .. "_" .. trackN) or trackN
		_Obj:addTrack(Track(self, id))
	end
	-- Switches
	for i, switchN in ipairs(data.switches) do
		local id = data.prefixDeviceNames and (self.name .. "_" .. switchN) or switchN
		_Obj:addSwitch(Switch(self, id))
	end
	-- Semaphores
	for semaphoreN, semaphoreData in pairs(data.semaphores) do
		local id = data.prefixDeviceNames and (self.name .. "_" .. semaphoreN) or semaphoreN
		_Obj:addSemaphore(Semaphore(self, id, semaphoreData))
	end
end

function Station:tell(text, severity, weight)
	_LogWrite("station: " .. self.name .. ": " .. text, severity, weight)
end

return Station