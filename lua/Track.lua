local class = require "lua.class"
local api = require "eu07.events"

---@class Track
local Track = class:derive("Track")

---Tworzy tor.
---@param station Station Stacja (lub szlak) na której znajduje się tor.
---@param id string Pełna nazwa toru, np. `"sta1_Iz1"`.
function Track:new(station, id)
	_Com.initTrack(station.name, id)

	self.station = station
	self.id = id
	self.occupied = false
	self.reserved = false
	self.semaphore = nil
	self.trains = {}
	self.vehicles = {}

	self:init()
end

-- Prepare the functions once for all tracks.
-- Each `api.event_preparefunc` call creates a new FFI callback, and only so many can be defined.
local busy = api.event_preparefunc(function(event, activator)
	local track = _Obj:getTrackFromEvent(event)
	if track then track:busy(); track:setTrain(activator) end
end)
local free = api.event_preparefunc(function(event, activator)
	local track = _Obj:getTrackFromEvent(event)
	if track then track:free(); track:setTrain() end
end)
local inc = api.event_preparefunc(function(event, activator)
	local track = _Obj:getTrackFromEvent(event)
	if track then track:addVehicle(activator) end
end)
local dec = api.event_preparefunc(function(event, activator)
	local track = _Obj:getTrackFromEvent(event)
	if track then track:removeVehicle(activator) end
end)

---Initializes callbacks which listen for the changes in the simulator.
function Track:init()
	_LogWrite("Creating track: " .. self.id, 1, 3)
	_LogWrite("- Creating event callbacks...", 1, 3)
	api.event_create(string.lower(self.id) .. ":busy", 0, 0, busy)
	api.event_create(string.lower(self.id) .. ":free", 0, 0, free)
	api.event_create(string.lower(self.id) .. ":inc", 0, 0, inc)
	api.event_create(string.lower(self.id) .. ":dec", 0, 0, dec)
	_LogWrite("Created track: " .. self.id, 3, 2)
end

function Track:__tostring()
	return string.format("%s : occupied=%s reserved=%s", self.id, self.occupied, self.reserved)
end

---Sends an information about this track to the log.
---@param text string The message.
---@param severity integer Severity.
---@param weight integer Weight.
function Track:tell(text, severity, weight)
	_LogWrite(tostring(self.id) .. ": " .. text, severity, weight)
end

---Zwraca true, jeżeli tor nie jest zarezerwowany ani zajęty.
---@return boolean
function Track:isClear()
	return not (self.occupied or self.reserved)
end

---Rezerwuje tor.
---@param semaphore Semaphore? If specified, this track will assigned to the semaphore. When this track is occupied, that semaphore will display a stop signal.
function Track:reserve(semaphore)
	self.reserved = true
	self:tell("reserved", 1, 3)
	self:refreshSim()
	self:setSemaphore(semaphore)
end

---Anuluje rezerwację toru.
function Track:unreserve()
	self.reserved = false
	self:tell("unreserved", 1, 3)
	self:refreshSim()
	self:setSemaphore()
end

---Oznacza ten tor jako zajęty przez pojazd.
function Track:busy()
	self.occupied = true
	self:tell("occupied", 1, 3)
	self:refreshSim()
	-- Display a stop signal on the semaphore that depends on this track.
	-- Sz ("Sygnał zastępczy") is exempt.
	if self.semaphore and self.semaphore.speed ~= 7 then
		self.semaphore:stop()
	end
	self:setSemaphore()
end

---Zwalnia tor razem z rezerwacją.
function Track:free()
	self.reserved = false
	self.occupied = false
	self:tell("freed", 1, 3)
	self:refreshSim()
	self:setSemaphore()
end

---Assigns or unassigns this Track from a semaphore. Affects the semaphore state.
---@private
---@param semaphore Semaphore? Which Semaphore this Track should belong to right now.
function Track:setSemaphore(semaphore)
	if self.semaphore == semaphore then
		return
	end
	if self.semaphore then
		self:tell("no longer reserved by " .. self.semaphore.id, 1, 3)
		self.semaphore:unreserveTrack(self)
	end
	if semaphore then
		self:tell("now reserved by " .. semaphore.id, 1, 3)
		semaphore:reserveTrack(self)
	end
	self.semaphore = semaphore
end

---Sets a train that is on this track.
---@param train TDynamicObject*? The train which is on this track. Pass `nil` to remove a train from this track.
function Track:setTrain(train)
	self.trains = {train}
end

---Adds the specified vehicle to this track. Duplicates are ignored.
---@param vehicle TDynamicObject* The vehicle to be added to this track.
function Track:addVehicle(vehicle)
	self.vehicles[vehicle] = true
end

---Removes the specified vehicle from this track.
---@param vehicle TDynamicObject* The vehicle to be removed from this track.
function Track:removeVehicle(vehicle)
	self.vehicles[vehicle] = nil
end

---Sends a command to the train which is on the track.
---@param str string The command string.
---@param num1 number The first parameter.
---@param num2 number The second parameter.
function Track:sendCommand(str, num1, num2)
	self:tell(string.format("Sending command: %s %s %s", str, num1, num2), 1, 3)
	local sent = 0
	for vehicle, _ in pairs(self.vehicles) do
		api.dynobj_putvalues(vehicle, {str = str, num1 = num1, num2 = num2})
		sent = sent + 1
	end
	self:tell("Sent to " .. sent .. " vehicles!", 1, 3)
end

---Odświeża obecny stan toru do loga.
function Track:refreshSim()
	_Com.setTrack(self.id, self.occupied, self.reserved)
end

return Track