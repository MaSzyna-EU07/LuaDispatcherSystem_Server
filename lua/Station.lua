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
	for trackN, trackData in pairs(data.tracks) do
		local track = Track(self, self.name .. "_" .. trackN, trackData)
		self.tracks[trackN] = track
		_Tracks[self.name .. "_" .. trackN] = track
	end
	-- Switches
	for i, switchN in ipairs(data.switches) do
		local switch = Switch(self, self.name .. "_" .. switchN)
		self.switches[switchN] = switch
		_Switches[self.name .. "_" .. switchN] = switch
	end
	-- Semaphores
	for semaphoreN, semaphoreData in pairs(data.semaphores) do
		local semaphore = Semaphore(self, self.name .. "_" .. semaphoreN, semaphoreData)
		self.semaphores[semaphoreN] = semaphore
		_Semaphores[self.name .. "_" .. semaphoreN] = semaphore
	end
end

function Station:init()
	_LogWrite("Creating station: " .. self.name, 1, 3)
	for name, track in pairs(self.tracks) do
		track:init()
	end
	for name, switch in pairs(self.switches) do
		switch:init()
	end
	for name, semaphore in pairs(self.semaphores) do
		semaphore:init()
	end

	_LogWrite("Created station: " .. self.name, 3, 2)
end

function Station:tell(text, severity, weight)
	_LogWrite("station: " .. self.name .. ": " .. text, severity, weight)
end

function Station:getSemaphore(semaphoreN)
	if not self.semaphores[semaphoreN] then self:tell("Tried to access a nonexistent semaphore: " .. tostring(semaphoreN), 2, 1) end
	return self.semaphores[semaphoreN]
end

function Station:getItinerary(semaphoreN, itineraryN)
	return self:getSemaphore(semaphoreN):getItinerary(itineraryN)
end

function Station:getTrack(trackN)
	if not self.tracks[trackN] then self:tell("Tried to access a nonexistent track: " .. tostring(trackN), 2, 1) end
	return self.tracks[trackN]
end

function Station:getSwitch(switchN)
	if not self.switches[switchN] then self:tell("Tried to access a nonexistent switch: " .. tostring(switchN), 2, 1) end
	return self.switches[switchN]
end

function Station:canDispatch(semaphoreN, itineraryN)
	return self:getItinerary(semaphoreN, itineraryN):canDispatch()
end

function Station:dispatch(semaphoreN, itineraryN)
	if self:canDispatch(semaphoreN, itineraryN) then
		self:getItinerary(semaphoreN, itineraryN):dispatch()
	else
		self:tell("Could not dispatch itinerary " .. semaphoreN .. " -> " .. itineraryN, 4, 2)
	end
end

return Station