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
end

---Inicjalizuje połączenia do innych obiektów. Należy wywołać tą funkcję po utworzeniu wszystkich obiektów.
function Track:init()
	_LogWrite("Creating track: " .. self.id, 1, 3)
	_LogWrite("- Creating event callbacks...", 1, 3)
	api.event_create(string.lower(self.id) .. ":busy", 0, 0, api.event_preparefunc(function(event, activator) self:busy(); self:setTrain(activator) end))
	api.event_create(string.lower(self.id) .. ":free", 0, 0, api.event_preparefunc(function(event, activator) self:free(); self:setTrain() end))
	_LogWrite("Created track: " .. self.id, 3, 2)
end

function Track:__tostring()
	return string.format("%s : occupied=%s reserved=%s", self.id, self.occupied, self.reserved)
end

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

---Gives a new timetable to the train which is on this track.
---@param name string The timetable name.
function Track:giveTimetable(name)
	if not self.trains[1] then
		return
	end
	api.dynobj_putvalues(self.trains[1], {str = "Timetable:luascript/" .. name, num1 = 0, num2 = 0})
end

---Odświeża obecny stan toru do loga.
function Track:refreshSim()
	_Com.setTrack(self.id, self.occupied, self.reserved)
end

return Track