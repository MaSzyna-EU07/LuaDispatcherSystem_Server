local class = require "lua.class"
local Monitoring = require("lua.Monitoring")

---@class Track
local Track = class:derive("Track")

---Tworzy tor.
---@param id string Pełna nazwa toru, np. `"sta1_Iz1"`.
function Track:new(id)
	_Com.initTrack(id)

	self.id = id
	self.occupied = false
	self.reserved = false
	---@type Semaphore?
	self.semaphore = nil
	---@type table<TDynamicObject*, integer>
	self.vehicles = {}
	self.monitoring = Monitoring()

	self:init()
end

---Initializes callbacks which listen for the changes in the simulator.
function Track:init()
	_LogWrite("Creating track: " .. self.id, Severity.INFO, 3)
	_LogWrite("- Creating event callbacks...", Severity.INFO, 3)
	_API:eventCreate(string.lower(self.id) .. ":busy", 0, 0, function() self:busy() end)
	_API:eventCreate(string.lower(self.id) .. ":free", 0, 0, function() self:free() end)
	_API:eventCreate(string.lower(self.id) .. ":inc", 0, 0, function(event, activator) self:addVehicle(activator) end)
	_API:eventCreate(string.lower(self.id) .. ":dec", 0, 0, function(event, activator) self:removeVehicle(activator) end)
	_LogWrite("Created track: " .. self.id, Severity.SUCCESS, 2)
end

function Track:__tostring()
	return string.format("T[%s : occupied=%s reserved=%s]", self.id, self.occupied, self.reserved)
end

---Sends an information about this track to the log.
---@param text string The message.
---@param severity Severity Severity.
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
	self:tell("reserved", Severity.INFO, 3)
	self:refreshSim()
	self:setSemaphore(semaphore)
end

---Anuluje rezerwację toru.
function Track:unreserve()
	self.reserved = false
	self:tell("unreserved", Severity.INFO, 3)
	self:refreshSim()
	self:setSemaphore()
end

---Oznacza ten tor jako zajęty przez pojazd.
function Track:busy()
	self.occupied = true
	self:tell("occupied", Severity.INFO, 3)
	self:refreshSim()
	-- Display a stop signal on the semaphore that depends on this track.
	-- Sz ("Sygnał zastępczy") is exempt, because it times out naturally.
	-- Ms2 is exempt, since it uses a different mechanism of going back to the stop signal.
	if self.semaphore and self.semaphore.speed ~= Speed.SZ and self.semaphore.speed ~= Speed.MS2 then
		self.semaphore:stop()
		self:setSemaphore()
	end
	self:call("busy")
end

---Zwalnia tor razem z rezerwacją.
function Track:free()
	self.reserved = false
	self.occupied = false
	self:tell("freed", Severity.INFO, 3)
	self:refreshSim()
	-- Display a stop signal, if Ms2 is displayed.
	if self.semaphore and self.semaphore.speed == Speed.MS2 then
		self.semaphore:stop()
		self:setSemaphore()
	end
	self:setSemaphore()
	self:call("free")
end

---Assigns or unassigns this Track from a semaphore. Affects the semaphore state.
---@private
---@param semaphore Semaphore? Which Semaphore this Track should belong to right now.
function Track:setSemaphore(semaphore)
	if self.semaphore == semaphore then
		return
	end
	if self.semaphore then
		self:tell("no longer reserved by " .. self.semaphore.id, Severity.INFO, 3)
		self.semaphore:unreserveTrack(self)
	end
	if semaphore then
		self:tell("now reserved by " .. semaphore.id, Severity.INFO, 3)
		semaphore:reserveTrack(self)
	end
	self.semaphore = semaphore
end

---Adds the specified vehicle to this track. Duplicates are ignored.
---@param vehicle TDynamicObject* The vehicle to be added to this track.
function Track:addVehicle(vehicle)
	self.vehicles[vehicle] = (self.vehicles[vehicle] or 0) + 1
end

---Removes the specified vehicle from this track.
---@param vehicle TDynamicObject* The vehicle to be removed from this track.
function Track:removeVehicle(vehicle)
	self.vehicles[vehicle] = self.vehicles[vehicle] > 1 and self.vehicles[vehicle] - 1 or nil
end

---Sends a command to the train which is on the track.
---@param str string The command string.
---@param num1 number The first parameter.
---@param num2 number The second parameter.
function Track:sendCommand(str, num1, num2)
	self:tell(string.format("Sending command: %s %s %s", str, num1, num2), Severity.INFO, 3)
	local sent = 0
	for vehicle, _ in pairs(self.vehicles) do
		_API:dynobjCommand(vehicle, {str = str, num1 = num1, num2 = num2})
		sent = sent + 1
	end
	self:tell("Sent to " .. sent .. " vehicles!", Severity.SUCCESS, 3)
end

---Returns the timetable name of the train on this track, or `nil` if nothing is there.
---If the train does not have any timetable, returns `"none"`.
---@return string?
function Track:getTimetable()
	for vehicle, _ in pairs(self.vehicles) do
		return _API:trainGetName(vehicle)
	end
end

-- Wow, the following two functions would not be here if only Lua was like Java and included interfaces!
-- Oh well...

---Subscribes the track to the specified action. When that action is performed, the specified function will be called.
---@param action "busy"|"free" The action to be listening for.
---@param f function The function to be called when the action happens.
---@param ... any Parameters for the function to be executed with.
function Track:monitor(action, f, ...)
	self.monitoring:monitor(action, f, ...)
end

---Performs the specified action for the listeners to handle. Executes all previously subscribed functions.
---@param action "busy"|"free" The action to be listening for.
function Track:call(action)
	self.monitoring:call(action)
end

---Odświeża obecny stan toru do loga.
function Track:refreshSim()
	_Com.setTrack(self.id, self.occupied, self.reserved)
end

return Track