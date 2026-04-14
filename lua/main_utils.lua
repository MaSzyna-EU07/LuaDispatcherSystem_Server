local verboseValue = 3

---Writes a message to the MaSzyna's log file.
---@param text string The message to be printed.
---@param severity Severity The severity.
---@param weight integer The verbosity. The higher the value, the less important output.
function _LogWrite(text, severity, weight)
	if verboseValue >= weight then
		_API:log("LuaDispatcher -> [" .. severity .. "] " .. text)
	end
end

function _FindLast(text, toFind)
	local a, b = string.find(text:reverse(), toFind:reverse())
	return #text - b + 1, #text - a + 1
end

---@type table<Speed, string|table<Speed, string|string[]>>
local signalImages = {
	[-1]={[0]={"uszk","ciemny"}},
	[0]="s1",
	[1]={[-1]={"s2","os2"},[0]={"s5","os1"},[1]={"s2","os2"},[2]={"s4","os4"},[3]={"s4","os4"},[4]={"s3","os3"}},
	[2]={[-1]="s10",[0]="s13",[1]="s10",[2]="s12",[3]="s12",[4]="s11"},
	[3]={[-1]="s10a",[0]="s13a",[1]="s10a",[2]="s12a",[3]="s12a",[4]="s11a"},
	[4]={[-1]="s6",[0]="s9",[1]="s6",[2]="s8",[3]="s8",[4]="s7"},
	[5]="ms1",
	[6]="ms2",
	[7]={[0]={"sz1","sz"}},
	[8]="s1a"
}

local shapeSignalImages = {
	[-1]="sr1",
	[0]="sr1",
	[1]="sr2",
	[2]="sr3",
	[3]="sr3",
	[4]="sr3",
	[5]="ms1",
	[6]="ms2",
	[7]="sz1",
	[8]="s1a"
}

---Returns the image or a list of possibile images on the semaphore for the specified conditions.
---@param speed Speed The speed on this semaphore.
---@param nextSpeed Speed? The speed on the next semaphore. Can only be omitted in specific cases.
---@param shape boolean? If `true`, the image will be evaluated for a shape signal.
---@return string|string[]
function _SignalImage(speed, nextSpeed, shape)
	local first = shape and shapeSignalImages[speed] or signalImages[speed]
	if type(first) == "string" then return first end
	return first[nextSpeed] or first[0]
end

local signalImagesRepeater = {[0]="sp1",[1]="sp2",[2]="sp4",[3]="sp4",[4]="sp3"}

function _SignalImageRepeater(speed)
	return signalImagesRepeater[speed] or signalImagesRepeater[0]
end

function _IsSpeedStopIsh(speed)
	return speed ~= Speed.VMAX and speed ~= Speed["40"] and speed ~= Speed["60"] and speed ~= Speed["100"]
end

---Turns speed in km/h into speed to be displayed on the semaphore.
---@param speed number? Desired speed.
---@return Speed
function _SpeedToID(speed)
	if not speed or speed == math.huge then
		return Speed.VMAX
	end
	if speed >= 100 then
		return Speed["100"]
	elseif speed >= 60 then
		return Speed["60"]
	end
	-- TODO: What about less than 40 km/h?
	return Speed["40"]
end

---Resolves a potential string semaphore ID to an actual semaphore.
---@param semaphore string|Speed? The semaphore ID or a speed or `nil`.
---@return Semaphore|Speed?
function _ResolveSemaphore(semaphore)
	if type(semaphore) == "string" then
		return _Obj:getSemaphore(semaphore)
	end
	return semaphore
end

_DIRS = {
	{x = 0, y = -1},
	{x = 1, y = -1},
	{x = 1, y = 0},
	{x = 1, y = 1},
	{x = 0, y = 1},
	{x = -1, y = 1},
	{x = -1, y = 0},
	{x = -1, y = -1}
}

---Inverts the provided direction, 1 becomes 5, 2 becomes 6, 7 becomes 3, and so on.
---@param dir integer The direction to invert.
---@return integer
function _InvertDir(dir)
	return (dir + 3) % 8 + 1
end