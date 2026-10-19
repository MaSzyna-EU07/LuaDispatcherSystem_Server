local class = require "lua.class"

---@class Semaphore
local Semaphore = class:derive("Semaphore")

---Tworzy semafor.
---@param id string Pełna nazwa semafora, np. `"sta1_C"`.
---@param data table Dane semafora, wczytywane z pliku.
function Semaphore:new(id, data)
	_Com.initSemaphore(id, data.type or SemaphoreType.SEM)

	self.id = id
	self:setData(data)

	---@type Semaphore?
	self.prev = nil
	---@type Semaphore|integer
	self.next = Speed.STOP
	self.speed = self:getStopSpeed() -- Target speed on this semaphore. May not represent what is actually displayed.
	self.image = self:getSupportedImage(self:getStopSpeed())
	---@type boolean
	self.w24 = false
	---@type SemaphoreState
	self.state = {speed = self.speed, nextSpeed = Speed.STOP, image = self.image}

	---@type table<Track, true>
	self.reservedTracks = {} -- A list of tracks this Semaphore has reserved for itself.
end

---Sets different data for this Semaphore. Use when reloading the schematic.
---@param data table Data for this Semaphore.
function Semaphore:setData(data)
	self.type = data.type or SemaphoreType.SEM
	self.shape = data.shape or false
	self.fourPhase = data.fourPhase or false
	---@type table<integer, integer>?
	self.shortSpeed = data.shortSpeed
	---@type string|integer
	self.nextDefault = data.next or math.huge
	self.repeaters = data.repeaters

	self:init()
end

---Sets the next default semaphore if `:setSpeed()` is called without the `next` parameter.
---This value gets overridden by `:setData()`.
---@param nextDefault string|integer Next semaphore ID or speed.
function Semaphore:setNextDefault(nextDefault)
	self.nextDefault = nextDefault
end

---Initializes callbacks which listen for the changes in the simulator.
function Semaphore:init()
	_LogWrite("Creating semaphore: " .. self.id, Severity.INFO, 3)
	_LogWrite("- Creating event callbacks...", Severity.INFO, 3)
	if self.type == SemaphoreType.SEM then
		_API:eventCreate(string.lower(self.id) .. (self.shape and "_sr1" or "_s1"), 0, 0, function() self:stop() end)
		_API:eventCreate(string.lower(self.id) .. (self.shape and "_sygsz_wyg90" or "_wyg_sz"), 0, 0, function() self:unreserveAllTracks() end)
		if self.shape then
			-- Shape signals don't explicitly set themselves to Sr1 when the Sz signal expires.
			_API:eventCreate(string.lower(self.id) .. "_sygsz_wyg90", 0, 0, function() self:stop() end)
		end
	end
	if self.type == SemaphoreType.TM then
		_API:eventCreate(string.lower(self.id) .. "_ms1", 0, 0, function() self:stop() end)
	end
	_API:eventCreate(string.lower(self.id) .. "_uszk", 0, 0, function() self:dim() end)

	_LogWrite("Created semaphore: " .. self.id, Severity.SUCCESS, 2)
end

function Semaphore:__tostring()
	return string.format("S[%s : image=%s]", self.id, self.image)
end

---Returns the simplified state of this Semaphore, used for the tile pathfinding.
---TODO: Do this better. Currently, neither the `self.speed` and `self.next` nor `self:getDisplayedSpeed()` and `self:getDisplayedNextSpeed()` are guaranteed to return stable values...
---(Stable as in we can meddle with neighboring semaphores as we like without touching this one and the image stays until we call `:refreshSim()`)
---@return SemaphoreState
function Semaphore:getState()
	return self.state
end

---Sends an information about this semaphore to the log.
---@param text string The message.
---@param severity Severity Severity.
---@param weight integer Weight.
function Semaphore:tell(text, severity, weight)
	_LogWrite(tostring(self.id) .. ": " .. text, severity, weight)
end

---Returns whether this semaphore can physically display the specified image.
---@private
---@param image string Image of this semaphore.
---@return boolean
function Semaphore:canSetImage(image)
	return _API:eventExists(string.lower(self.id) .. "_" .. image)
end

---Returns the first supported image which can be set on this semaphore for the specified speeds, or `nil` if no matching image can be set.
---@private
---@param speed integer Speed on this semaphore.
---@param nextSpeed integer? Speed on the next semaphore.
---@return string?
function Semaphore:getSupportedImage(speed, nextSpeed)
	local images = _SignalImage(speed, nextSpeed, self.shape)
	if type(images) == "string" then
		return self:canSetImage(images) and images or nil
	elseif type(images) == "table" then
		for i, image in ipairs(images) do
			if self:canSetImage(image) then
				return image
			end
		end
	end
end

---Ustawia prędkość na semaforze oraz odświeża niezbędne do odświeżenia semafory.
---Jeżeli sygnał nie może być wyświetlony (brakuje eventu), wyświetlony zostanie sygnał zastępczy.
---@param speed integer Speed on this semaphore.
---@param next Semaphore|integer? Speed on the next semaphore, or the semaphore to be specified as the next semaphore. Defaults to `1` unless `nextDefault` field is specified.
function Semaphore:setSpeed(speed, next)
	-- Resolve the default next parameter.
	next = next or _ResolveSemaphore(self.nextDefault) or Speed.STOP -- The last one can occur when loading the scenario. If the semaphore doesn't exist (yet), assume it is displaying S1, since that's what the semaphores are initialized to anyway.
	self:tell("Setting speed " .. tostring(speed) .. ", next: " .. tostring(next), Severity.INFO, 3)
	-- Set the semaphore state and see if we can get away with that.
	self.speed = speed
	self:setNext(next)
	self:refreshImage()
end

---Refreshes this Semaphore's image.
---If the image has changed, forwards it to the simulator and refreshes the previous semaphore to make sure everything is in sync.
---@private
function Semaphore:refreshImage()
	local speed = self:getDisplayedSpeed()
	local nextSpeed = self:getDisplayedNextSpeed()
	-- TODO: Separate flag for Sz. If the image cannot be displayed, set an Sz flag and that's it.
	local image = self:getSupportedImage(speed, nextSpeed)
	while not image do
		-- Each iteration start is basically "we did not find the requested image, what now" case.
		speed = _StepDownSpeed(speed)
		if speed > 0 then
			-- Try again with a lower speed.
			self.speed = speed
			image = self:getSupportedImage(speed, nextSpeed)
		else
			-- Fall back to Sz.
			self.speed = Speed.SZ
			image = self:getSupportedImage(self.speed)
			if not image then
				-- No Sz: fall back to S1/Ms1.
				self.speed = self:getStopSpeed()
				image = self:getSupportedImage(self.speed) or "uszk"
			end
		end
	end
	-- Avoid changing an image to the same image. Especially important for shape signals, which would play a sound while the signal doesn't change.
	if self.image == image then
		return
	end
	self.image = image
	self:tell(string.format("Refreshing image. Speeds: this=%s, next=%s, result: %s", speed, nextSpeed, image), Severity.INFO, 3)
	self:refreshSim()
	-- Check the previous semaphore if it needs a signal change.
	if self.prev and self.prev.next == self then
		self.prev:refreshImage()
	end
end

---Sets the next semaphore, if any. Affects that semaphore's `prev` field.
---@private
---@param next Semaphore|Speed The next semaphore or speed to be linked with.
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

---Dims the semaphore so that no signal is displayed on it at all.
function Semaphore:dim()
	self.w24 = false
	self:setSpeed(Speed.DIM)
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

---Returns whether this semaphore is currently displaying a stop signal.
---@return boolean
function Semaphore:isStop()
	return self.speed == self:getStopSpeed()
end

---Returns the displayed speed on the next semaphore instead of the actual one.
---An example on how this could happen is when the short speed is set.
---@return integer
function Semaphore:getDisplayedSpeed()
	return math.min(self.speed, self.shortSpeed and _GetFutureValue(self.shortSpeed, self:getNextSpeed()) or math.huge)
end

---Zwraca prędkość na następnym semaforze bądź na sztywno ustawioną.
---@return integer
function Semaphore:getNextSpeed()
	if type(self.next) == "table" then
		return self.next:getDisplayedSpeed()
	end
	return self.next
end

---Returns the displayed speed on the next semaphore instead of the actual one.
---An example on how this could happen is an S3 signal on a 4-phase SBL.
---@return integer
function Semaphore:getDisplayedNextSpeed()
	local nextSpeed = self:getNextSpeed()
	local nextNextSpeed = self:getNextNextSpeed()
	if self.fourPhase and nextSpeed == math.huge and nextNextSpeed < 100 and nextNextSpeed ~= Speed.DIM then
		return 100
	end
	return nextSpeed
end

---Returns `true` if the next semaphore is showing that its next semaphore is showing a stop signal.
---@private
---@return boolean
function Semaphore:isNextNextStop()
	return type(self.next) == "table" and self.next:getNextSpeed() == Speed.STOP
end

---Returns the speed 2 semaphores ahead. If it is unknown, returns `nil`.
---@private
---@return integer?
function Semaphore:getNextNextSpeed()
	return type(self.next) == "table" and self.next:getNextSpeed() or self.next
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
	local speed = self:getDisplayedSpeed()
	local nextSpeed = self:getDisplayedNextSpeed()
	_API:eventDispatch(string.lower(self.id) .. "_" .. self.image)
	-- W24
	_API:eventDispatchIfExists(string.lower(self.id) .. (self.w24 and "_w24" or "_w24off"))
	-- W21
	if not _IsSpeedStopIsh(speed) and speed ~= 40 and speed ~= 60 and speed ~= 100 then
		_API:eventDispatchIfExists(string.lower(self.id) .. "_w21_" .. math.floor(speed / 10))
	else
		_API:eventDispatchIfExists(string.lower(self.id) .. "_w21_off")
	end
	-- refresh repeaters too
	if self.repeaters then
		for i, repeaterN in ipairs(self.repeaters) do
			_API:eventDispatch(string.lower(repeaterN) .. "_" .. _SignalImageRepeater(speed))
		end
	end
	_Com.setSemaphore(self.id, speed, nextSpeed, self.image)
	self.state.speed = speed
	self.state.nextSpeed = nextSpeed or Speed.STOP
	self.state.image = self.image
end

return Semaphore