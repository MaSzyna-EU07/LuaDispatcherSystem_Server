local class = require "lua.class"

---@class Semaphore
local Semaphore = class:derive("Semaphore")

---Tworzy semafor.
---@param station Station Stacja na której znajduje się ten semafor.
---@param id string Pełna nazwa semafora, np. `"sta1_C"`.
---@param data table Dane semafora, wczytywane z pliku.
function Semaphore:new(station, id, data)
	_Com.initSemaphore(station.name, id, data.type or SemaphoreType.SEM)

	self.station = station
	self.id = id
	self.type = data.type or SemaphoreType.SEM
	self.shape = data.shape or false
	---@type Semaphore?
	self.prev = nil
	---@type Semaphore|integer?
	self.next = nil
	self.repeaters = data.repeaters
	self.speed = self:getStopSpeed()
	self.image = _SignalImage(self:getStopSpeed(), nil, self.shape)
	---@type boolean
	self.w24 = false

	---@type table<Track, true>
	self.reservedTracks = {} -- A list of tracks this Semaphore has reserved for itself.

	self:init()
end

-- Prepare the functions once for all semaphores.
-- Each `api.event_preparefunc` call creates a new FFI callback, and only so many can be defined.
local stop = _API:eventPrepareFunction(function(event, activator) _Obj:getSemaphoreFromEvent(event):stop() end)
local unreserve = _API:eventPrepareFunction(function(event, activator) _Obj:getSemaphoreFromEvent(event):unreserveAllTracks() end)

---Initializes callbacks which listen for the changes in the simulator.
function Semaphore:init()
	_LogWrite("Creating semaphore: " .. self.id, Severity.INFO, 3)
	_LogWrite("- Creating event callbacks...", Severity.INFO, 3)
	if self.type == SemaphoreType.SEM then
		_API:eventCreate(string.lower(self.id) .. (self.shape and "_sr1" or "_s1"), 0, 0, stop)
	end
	if self.type == SemaphoreType.TM then
		_API:eventCreate(string.lower(self.id) .. "_ms1", 0, 0, stop)
	end
	_API:eventCreate(string.lower(self.id) .. "_uszk", 0, 0, stop)
	_API:eventCreate(string.lower(self.id) .. (self.shape and "_sygsz_wyg90" or "_wyg_sz"), 0, 0, unreserve)

	_LogWrite("Created semaphore: " .. self.id, Severity.SUCCESS, 2)
end

function Semaphore:__tostring()
	return string.format("%s : image=%s", self.id, self.image)
end

---Sends an information about this semaphore to the log.
---@param text string The message.
---@param severity Severity Severity.
---@param weight integer Weight.
function Semaphore:tell(text, severity, weight)
	_LogWrite(tostring(self.id) .. ": " .. text, severity, weight)
end

---Returns whether this semaphore can physically display the specified signal.
---@private
---@param speed Speed Speed on this semaphore.
---@param next Semaphore|Speed? Next speed, or speed on the next semaphore.
---@return boolean
function Semaphore:canSetSpeed(speed, next)
	if type(next) == "table" then
		next = next.speed
	end
	local image = _SignalImage(speed, next, self.shape)
	local eventID = string.lower(self.id) .. "_" .. image
	return _API:eventExists(eventID)
end

---Ustawia prędkość na semaforze oraz odświeża niezbędne do odświeżenia semafory.
---Jeżeli sygnał nie może być wyświetlony (brakuje eventu), wyświetlony zostanie sygnał zastępczy.
---@param speed Speed Nowa prędkość od teraz obowiązująca na semaforze.
---@param next Semaphore|Speed? Patrz niżej:
---- Jeżeli Semaphore, jest to następny semafor.
---- Jeżeli liczba, jest to stała prędkość nieprzypisana do żadnego semafora.
---Na przykład `1` oznacza, że przy prędkości maksymalnej zostanie podany sygnał S2, a `2` oznacza, że zostanie podany S4.
---- `nil` jest dopuszczalne tylko przy sygnałach niezależnych od następnego semafora (S1,Ms1,Ms2,Sz).
function Semaphore:setSpeed(speed, next)
	self:tell("Setting speed " .. tostring(speed) .. ", next: " .. tostring(next), Severity.INFO, 3)
	local available = self:canSetSpeed(speed, next)
	self.speed = available and speed or Speed.SZ
	self:setNext(available and next or nil)
	if not available then
		self:tell("The semaphore cannot display this signal, falling back to Sz!", Severity.FAIL, 3)
	end
	-- If this Semaphore has a previous one, refresh it.
	if self.prev and self.prev.next == self then
		self.prev:refreshSim()
	end
	self:refreshSim()
end

---Sets the next semaphore, if any. Affects that semaphore's `prev` field.
---@private
---@param next Semaphore|Speed? The next semaphore or speed to be linked with.
function Semaphore:setNext(next)
	if self.next == next then
		return
	end
	if self.next and type(self.next) == "table" then
		self:tell("no longer linked to " .. self.next.id, Severity.INFO, 3)
		self.next.prev = nil
	end
	if next and type(next) == "table" then
		self:tell("now linked to " .. next.id, Severity.INFO, 3)
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
---@return Speed
function Semaphore:getStopSpeed()
	return self.type == SemaphoreType.TM and Speed.MS1 or Speed.STOP
end

---Zwraca prędkość na następnym semaforze bądź na sztywno ustawioną.
---@return Speed?
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
	local image = _SignalImage(self.speed, nextSpeed, self.shape)
	-- Avoid changing an image to the same image. Especially important for shape signals, which would play a sound while the signal doesn't change.
	if self.image == image then
		return
	end
	self.image = image
	self:tell(string.format("Refreshing image. Speeds: this=%s, next=%s, result: %s", self.speed, nextSpeed, image), Severity.INFO, 3)
	_API:eventDispatch(string.lower(self.id) .. "_" .. image)
	-- Sz signal events on most semaphores end with `_sz1`, but on some end with `_sz` -_-
	if image == "sz1" then
		_API:eventDispatch(string.lower(self.id) .. "_sz")
	end
	-- W24
	if self.w24 then
		_API:eventDispatch(string.lower(self.id) .. "_w24")
	else
		_API:eventDispatch(string.lower(self.id) .. "_w24off")
	end
	-- refresh repeaters too
	if self.repeaters then
		for i, repeaterN in ipairs(self.repeaters) do
			_API:eventDispatch(string.lower(repeaterN) .. "_" .. _SignalImageRepeater(self.speed))
		end
	end
	_Com.setSemaphore(self.id, self.speed, nextSpeed, self.image)
end

return Semaphore