local class = require "lua.class"
local api = require "eu07.events"

---@class Semaphore
local Semaphore = class:derive("Semaphore")

---Tworzy semafor.
---@param station Station Stacja na której znajduje się ten semafor.
---@param id string Pełna nazwa semafora, np. `"sta1_C"`.
---@param data table Dane semafora, wczytywane z pliku.
function Semaphore:new(station, id, data)
	_Com.initSemaphore(station.name, id, data.type or 0)

	self.station = station
	self.id = id
	self.data = data
	self.type = data.type or 0
	self.prev = nil
	self.next = nil
	self.repeaters = data.repeaters
	self.speed = self:getStopSpeed()
	self.image = _SignalImage(self:getStopSpeed())
	self.w24 = false

	---@type table<Track, true>
	self.reservedTracks = {} -- A list of tracks this Semaphore has reserved for itself.
end

---Inicjalizuje połączenia do innych obiektów. Należy wywołać tą funkcję po utworzeniu wszystkich obiektów.
function Semaphore:init()
	_LogWrite("Creating semaphore: " .. self.id, 1, 3)
	_LogWrite("- Creating event callbacks...", 1, 3)
	if self.type == 0 then
		api.event_create(string.lower(self.id) .. "_s1", 0, 0, api.event_preparefunc(function(event, activator) self:stop() end))
		api.event_create(string.lower(self.id) .. "_sr1", 0, 0, api.event_preparefunc(function(event, activator) self:stop() end))
	end
	if self.type == 1 then
		api.event_create(string.lower(self.id) .. "_ms1", 0, 0, api.event_preparefunc(function(event, activator) self:stop() end))
	end
	api.event_create(string.lower(self.id) .. "_uszk", 0, 0, api.event_preparefunc(function(event, activator) self:stop() end))
	api.event_create(string.lower(self.id) .. "_wyg_sz", 0, 0, api.event_preparefunc(function(event, activator) self:unreserveAllTracks() end))

	_LogWrite("Created semaphore: " .. self.id, 3, 2)
end

function Semaphore:__tostring()
	return string.format("%s : image=%s", self.id, self.image)
end

function Semaphore:tell(text, severity, weight)
	_LogWrite(tostring(self.id) .. ": " .. text, severity, weight)
end

---Ustawia prędkość na semaforze oraz odświeża niezbędne do odświeżenia semafory.
---@param speed integer Nowa prędkość od teraz obowiązująca na semaforze.
---@param next Semaphore|integer? Patrz niżej:
---- Jeżeli Semaphore, jest to następny semafor.
---- Jeżeli liczba, jest to stała prędkość nieprzypisana do żadnego semafora.
---Na przykład `1` oznacza, że przy prędkości maksymalnej zostanie podany sygnał S2, a `2` oznacza, że zostanie podany S4.
---- `nil` jest dopuszczalne tylko przy sygnałach niezależnych od następnego semafora (S1,Ms1,Ms2,Sz).
function Semaphore:setSpeed(speed, next)
	self:tell("Setting speed " .. tostring(speed) .. ", next: " .. tostring(next), 1, 3)
	self.speed = speed
	self:setNext(next)
	-- If this Semaphore has a previous one, refresh it.
	if self.prev and self.prev.next == self then
		self.prev:refreshSim()
	end
	self:refreshSim()
end

---Sets the next semaphore, if any. Affects that semaphore's `prev` field.
---@private
---@param next Semaphore|integer? The next semaphore or speed to be linked with.
function Semaphore:setNext(next)
	if self.next == next then
		return
	end
	if self.next and type(self.next) == "table" then
		self:tell("no longer linked to " .. self.next.id, 1, 3)
		self.next.prev = nil
	end
	if next and type(next) == "table" then
		self:tell("now linked to " .. next.id, 1, 3)
		next.prev = self
	end
	self.next = next
end

---Wyświetla sygnał zabraniający jazdy: S1, Ms1 lub Sr1.
function Semaphore:stop()
	if self.speed == self:getStopSpeed() then
		return
	end
	self.w24 = false
	self:setSpeed(self:getStopSpeed())
end

---Ustawia czy następne wywołanie `Semaphore:setSpeed()` wyświetli wskaźnik W24.
---Wskaźniki są kasowane po wywołaniu `Semaphore:stop()`.
---@param w24 boolean Czy ma być wyświetlony wskaźnik W24.
function Semaphore:setW24(w24)
	self.w24 = w24
end

---Zwraca `5` jeżeli semafor ten jest skonfigurowany jako tarcza manewrowa. W przeciwnym wypadku `0`.
---@private
---@return integer
function Semaphore:getStopSpeed()
	return self.type == 1 and 5 or 0
end

---Zwraca prędkość na następnym semaforze bądź na sztywno ustawioną.
---@return integer?
function Semaphore:getNextSpeed()
	if type(self.next) == "table" then
		return self.next.speed
	end
	return self.next
end

---Reserves a track for this Semaphore. This list is used to easily cancel a dynamic itinerary.
---@param track Track The track to be reserved.
function Semaphore:reserveTrack(track)
	self.reservedTracks[track] = true
end

---Unreserves a track for this Semaphore.
---@param track Track The track to be unreserved.
function Semaphore:unreserveTrack(track)
	self.reservedTracks[track] = nil
end

---Unreserves all tracks for this Semaphore and removes the reservation from Tracks themselves.
function Semaphore:unreserveAllTracks()
	for track, _ in pairs(self.reservedTracks) do
		track:unreserve()
	end
end

---Odświeża obraz semafora do symulatora i loga.
function Semaphore:refreshSim()
	local nextSpeed = self:getNextSpeed()
	self.image = _SignalImage(self.speed, nextSpeed)
	self:tell("Refreshing image. Speeds: this=" .. tostring(self.speed) .. ", next=" .. tostring(nextSpeed) .. ", result: " .. self.image, 1, 3)
	local eventID = string.lower(self.id) .. "_" .. self.image
	if not api.event_exists(eventID) then
		self:tell("WARNING! Image not found! Displaying Sz!", 1, 3)
		-- TODO: This state should be also reflected in the log and everywhere else (next/prev breaks, repeater should stay at Sp1)
		eventID = string.lower(self.id) .. "_sz1"
	end
	api.event_dispatch_n(eventID, nil, 0)
	-- W24
	if self.w24 then
		api.event_dispatch_n(string.lower(self.id) .. "_w24", nil, 0)
	else
		api.event_dispatch_n(string.lower(self.id) .. "_w24off", nil, 0)
	end
	-- refresh repeaters too
	if self.repeaters then
		for i, repeaterN in ipairs(self.repeaters) do
			api.event_dispatch_n(string.lower(repeaterN) .. "_" .. _SignalImageRepeater(self.speed), nil, 0)
		end
	end
	_Com.setSemaphore(self.id, self.speed, nextSpeed, self.image)
end

return Semaphore