local class = require "lua.class"
local api = require "eu07.events"

---@class Track
local Track = class:derive("Track")

---Tworzy tor.
---@param station Station Stacja (lub szlak) na której znajduje się tor.
---@param id string Pełna nazwa toru, np. `"sta1_Iz1"`.
---@param data table Dane toru, wczytywane z pliku.
function Track:new(station, id, data)
	_Com.initTrack(station.name, id)

	self.station = station
	self.id = id
	self.data = data
	self.occupied = false
	self.reserved = false
	self.semaphores = {}
end

---Inicjalizuje połączenia do innych obiektów. Należy wywołać tą funkcję po utworzeniu wszystkich obiektów.
function Track:init()
	_LogWrite("Creating track: " .. self.id, 1, 3)
	_LogWrite("- Extracting semaphore list...", 1, 3)
	for i, semaphoreID in ipairs(self.data.semaphores) do
		self.semaphores[i] = _GetSemaphore(semaphoreID)
		_LogWrite("  - " .. self.semaphores[i].id, 1, 3)
	end

	_LogWrite("- Creating event callbacks...", 1, 3)
	api.event_create(string.lower(self.id) .. ":busy", 0, 0, api.event_preparefunc(function(event, activator) self:busy() end))
	api.event_create(string.lower(self.id) .. ":free", 0, 0, api.event_preparefunc(function(event, activator) self:free() end))

	_LogWrite("Created track: " .. self.id, 3, 2)
end

function Track.__tostring(o)
	return tostring(o.id).." : occupied="..tostring(o.occupied).." reserved="..tostring(o.reserved)
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
function Track:reserve()
	self.reserved = true
	self:tell("reserved", 1, 3)
	self:refreshSim()
end

---Anuluje rezerwację toru.
function Track:unreserve()
	self.reserved = false
	self:tell("unreserved", 1, 3)
	self:refreshSim()
end

---Oznacza ten tor jako zajęty przez pojazd.
function Track:busy()
	self.occupied = true
	self:tell("occupied", 1, 3)
	self:refreshSim()
	-- stop all semaphores that depend on this track
	for i, semaphore in ipairs(self.semaphores) do
		semaphore:stop()
	end
end

---Zwalnia tor razem z rezerwacją.
function Track:free()
	self.reserved = false
	self.occupied = false
	self:tell("freed", 1, 3)
	self:refreshSim()
end

---Odświeża obecny stan toru do loga.
function Track:refreshSim()
	_Com.setTrack(self.id, self.occupied, self.reserved)
end

return Track