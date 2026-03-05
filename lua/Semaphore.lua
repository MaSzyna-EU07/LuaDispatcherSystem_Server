local class = require "lua.class"
local api = require "eu07.events"
local Itinerary = require("lua.Itinerary")

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
	self.prev = {}
	self.next = nil
	self.repeaters = data.repeaters
	self.speed = self:getStopSpeed()
	self.image = _SignalImage(self:getStopSpeed())
	self.w24 = false

	---@type table<string, Itinerary>
	self.itineraries = {}
end

---Inicjalizuje połączenia do innych obiektów. Należy wywołać tą funkcję po utworzeniu wszystkich obiektów.
function Semaphore:init()
	_LogWrite("Creating semaphore: " .. self.id, 1, 3)
	_LogWrite("- Extracting previous semaphore list...", 1, 3)
	for i, prevID in ipairs(self.data.prev) do
		self.prev[i] = _GetSemaphore(prevID)
		_LogWrite("  - " .. self.prev[i].id, 1, 3)
	end
	_LogWrite("- Creating itineraries...", 1, 3)
	for itineraryN, itineraryData in pairs(self.data.itineraries) do
		self.itineraries[itineraryN] = Itinerary(self.station, self, itineraryData, itineraryN)
	end

	-- in some future, create only one callback depending on the semaphore type
	_LogWrite("- Creating event callbacks...", 1, 3)
	api.event_create(string.lower(self.id) .. "_s1", 0, 0, api.event_preparefunc(function(event, activator) self:stop() end))
	api.event_create(string.lower(self.id) .. "_sr1", 0, 0, api.event_preparefunc(function(event, activator) self:stop() end))
	api.event_create(string.lower(self.id) .. "_ms1", 0, 0, api.event_preparefunc(function(event, activator) self:stop() end))

	_LogWrite("Created semaphore: " .. self.id, 3, 2)
end

function Semaphore.__tostring(o)
	return tostring(o.id).." : image="..tostring(o.image)
end

function Semaphore:tell(text, severity, weight)
	_LogWrite(tostring(self.id) .. ": " .. text, severity, weight)
end

---Zwraca przebieg z semafora szukając po nazwie.
---Jeżeli nie istnieje zwraca `nil` oraz w logu pojawia się błąd.
---@param itineraryN string Nazwa przebiegu.
---@return Itinerary?
function Semaphore:getItinerary(itineraryN)
	if not self.itineraries[itineraryN] then self:tell("Tried to access a nonexistent itinerary: " .. tostring(itineraryN), 2, 1) end
	return self.itineraries[itineraryN]
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
	self.next = next
	for i, prevSemaphore in ipairs(self.prev) do
		if prevSemaphore.next == self then
			prevSemaphore:refreshSim()
		end
	end
	self:refreshSim()
end

---Wyświetla sygnał zabraniający jazdy: S1, Ms1 lub Sr1.
function Semaphore:stop()
	if self.speed == self:getStopSpeed() or self.speed == 7 then
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
	if type(self.next) == "number" then
		return self.next
	end
	return self.next and self.next.speed
end

---Odświeża obraz semafora do symulatora i loga.
function Semaphore:refreshSim()
	local nextSpeed = self:getNextSpeed()
	self.image = _SignalImage(self.speed, nextSpeed)
	self:tell("Refreshing image. Speeds: this=" .. tostring(self.speed) .. ", next=" .. tostring(nextSpeed) .. ", result: " .. self.image, 1, 3)
	api.event_dispatch_n(string.lower(self.id) .. "_" .. self.image, nil, 0)
	-- W24
	if self.w24 then
		api.event_dispatch_n(string.lower(self.id) .. "_w24", nil, 0)
	else
		api.event_dispatch_n(string.lower(self.id) .. "_w24off", nil, 0)
	end
	-- refresh repeaters too
	for i, repeaterN in ipairs(self.repeaters) do
		api.event_dispatch_n(string.lower(repeaterN) .. "_" .. _SignalImageRepeater(self.speed), nil, 0)
	end
	_Com.setSemaphore(self.id, self.image)
end

return Semaphore