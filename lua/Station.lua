local class = require "lua.class"
local Track = require("lua.Track")
local Switch = require("lua.Switch")
local Semaphore = require("lua.Semaphore")

---@class Station
local Station = class:derive("Station")

function Station:new(name, data)
	_Com.initStation(name)

	self.name = name
	---@type table<string, Track>
	self.tracks = {}
	---@type table<string, Switch>
	self.switches = {}
	---@type table<string, Semaphore>
	self.semaphores = {}

	-- Tracks
	for i, trackN in ipairs(data.tracks) do
		local track = Track(self, self.name .. "_" .. trackN)
		self.tracks[trackN] = track
		_Tracks[string.lower(self.name .. "_" .. trackN)] = track
	end
	-- Switches
	for i, switchN in ipairs(data.switches) do
		local switch = Switch(self, self.name .. "_" .. switchN)
		self.switches[switchN] = switch
		_Switches[string.lower(self.name .. "_" .. switchN)] = switch
	end
	-- Semaphores
	for semaphoreN, semaphoreData in pairs(data.semaphores) do
		local semaphore = Semaphore(self, self.name .. "_" .. semaphoreN, semaphoreData)
		self.semaphores[semaphoreN] = semaphore
		_Semaphores[string.lower(self.name .. "_" .. semaphoreN)] = semaphore
	end
end

function Station:tell(text, severity, weight)
	_LogWrite("station: " .. self.name .. ": " .. text, severity, weight)
end

-- TODO: Potentially remove these three functions:

function Station:getSemaphore(semaphoreN)
	if not self.semaphores[semaphoreN] then self:tell("Tried to access a nonexistent semaphore: " .. tostring(semaphoreN), 2, 1) end
	return self.semaphores[semaphoreN]
end

function Station:getTrack(trackN)
	if not self.tracks[trackN] then self:tell("Tried to access a nonexistent track: " .. tostring(trackN), 2, 1) end
	return self.tracks[trackN]
end

function Station:getSwitch(switchN)
	if not self.switches[switchN] then self:tell("Tried to access a nonexistent switch: " .. tostring(switchN), 2, 1) end
	return self.switches[switchN]
end

return Station