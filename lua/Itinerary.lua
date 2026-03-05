local class = require "lua.class"

---@class Itinerary
local Itinerary = class:derive("Itinerary")

---Creates a new itinerary.
---@param station Station The station this itinerary belongs to.
---@param semaphore Semaphore The semaphore this itinerary belongs to.
---@param data table Data for the itinerary.
---@param name string The name of the itinerary in the semaphore's data.
function Itinerary:new(station, semaphore, data, name)
	_LogWrite("Creating itinerary: " .. semaphore.id .. " -> " .. data.next, 1, 3)
	self.station = station
	self.semaphore = semaphore
	self.name = name
	self.speed = data.speed
	---@type Track[]
	self.tracks = {}
	---@type table<Switch, boolean>
	self.switches = {}
	---@type Semaphore|string|integer?
	self.next = data.next
	self.w24 = data.w24

	-- Initialization: at some point a separate method?
	for i, trackID in ipairs(data.tracks) do
		self.tracks[i] = _GetTrack(trackID)
	end
	for switchID, state in pairs(data.switches) do
		self.switches[_GetSwitch(switchID)] = state
	end
	-- it can be either a semaphore ID or a number
	if type(self.next) == "string" then
		self.next = _GetSemaphore(self.next)
	end

	_LogWrite("Created itinerary: " .. semaphore.id .. " -> " .. data.next, 3, 2)
end

function Itinerary:tell(text, severity, weight)
	_LogWrite(self.semaphore.id .. " -> I:" .. self.name .. ": " .. text, severity, weight)
end

---Returns `true` if this itinerary can be dispatched, or `false` if something is on the way.
---@return boolean
function Itinerary:canDispatch()
	for i, track in ipairs(self.tracks) do
		if not track:isClear() then return false end
	end
	return true
end

---Attempts to dispatch this itinerary: sets switches' states, reserves tracks and displays a signal on the semaphore.
---Nothing happens if this itinerary cannot be dispatched. You cannot force-dispatch an itinerary.
function Itinerary:dispatch()
	self:tell("Attempting to dispatch...", 1, 3)
	if not self:canDispatch() then
		self:tell("Could not dispatch!", 4, 2)
		return
	end
	-- mark all tracks as reserved
	for i, track in ipairs(self.tracks) do
		track:reserve()
	end
	-- switch all switches
	for switch, state in pairs(self.switches) do
		switch:setState(state)
	end
	-- set the semaphore state
	self.semaphore:setW24(self.w24)
	self.semaphore:setSpeed(self.speed, self.next)
	self:tell("Dispatched!", 3, 2)
end

return Itinerary