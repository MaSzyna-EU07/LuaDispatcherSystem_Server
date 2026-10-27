local utf8 = require "lua.utf8"
local Time = require "lua.Time"

local verboseValue = 3

---Writes a message to the MaSzyna's log file.
---@param text string The message to be printed.
---@param severity Severity? The severity.
---@param weight integer? The verbosity. The higher the value, the less important output.
function _LogWrite(text, severity, weight)
	if verboseValue >= (weight or 1) then
		_API:log("LuaDispatcher -> [" .. (severity or Severity.DEBUG) .. "] " .. text)
	end
end

function _FindLast(text, toFind)
	local a, b = string.find(text:reverse(), toFind:reverse())
	return #text - b + 1, #text - a + 1
end

---Returns the value matching the highest number key of table `t` below or equal to the specified value `n`.
---@param t table The table to be searched.
---@param n number The key value threshold.
---@return any?
function _GetPastValue(t, n)
	local key = -math.huge
	for k, v in pairs(t) do
		if type(k) == "number" and k <= n and k > key then
			key = k
		end
	end
	return t[key]
end

---Returns the value matching the lowest number key of table `t` above or equal to the specified value `n`.
---@param t table The table to be searched.
---@param n number The key value threshold.
---@return any?
function _GetFutureValue(t, n)
	local key = math.huge
	for k, v in pairs(t) do
		if type(k) == "number" and k >= n and k < key then
			key = k
		end
	end
	return t[key]
end

---@type table<integer, string|table<integer, string|string[]>>
local signalImages = {
	[-1] = {[0]={"uszk","ciemny"}},
	[0] = "s1",
	[40] = {[-1]="s10",[0]="s13",[40]="s12",[100]="s11",[math.huge]="s10"},
	[60] = {[-1]="s10a",[0]="s13a",[40]="s12a",[100]="s11a",[math.huge]="s10a"},
	[100] = {[-1]="s6",[0]="s9",[40]="s8",[100]="s7",[math.huge]="s6"},
	[math.huge] = {[-1]={"s2","os2"},[0]={"s5","os1"},[40]={"s4","os4"},[100]={"s3","os3"},[math.huge]={"s2","os2"}},
	[5] = "ms1",
	[6] = "ms2",
	[7] = {[0]={"sz1","sz"}},
	[8] = "s1a"
}

---@type table<integer, string|table<integer, string|string[]>>
local shapeSignalImages = {
	[-1] = "sr1",
	[0] = "sr1",
	[40] = "sr3",
	[math.huge] = "sr2",
	[5] = "ms1",
	[6] = "ms2",
	[7] = "sz1",
	[8] = "s1a"
}

---Returns the image or a list of possibile images on the semaphore for the specified conditions.
---@param speed integer The speed on this semaphore.
---@param nextSpeed integer? The speed on the next semaphore. Can only be omitted in specific cases.
---@param shape boolean? If `true`, the image will be evaluated for a shape signal.
---@return string|string[]
function _SignalImage(speed, nextSpeed, shape)
	local first = _GetPastValue(shape and shapeSignalImages or signalImages, speed)
	if type(first) == "string" then return first end
	return (nextSpeed and nextSpeed > 9) and _GetPastValue(first, nextSpeed) or (first[nextSpeed] or first[0])
end

local signalImagesRepeater = {[0]="sp1",[math.huge]="sp2",[40]="sp4",[100]="sp3"}

function _SignalImageRepeater(speed)
	return (speed and speed > 9) and _GetPastValue(signalImagesRepeater, speed) or signalImagesRepeater[0]
end

function _IsSpeedStopIsh(speed)
	return speed < 10
end

---Returns the next highest speed threshold lower than the specified one.
---If there is no lower speed threshold than the stop(ish) speed, returns `0`.
---@param speed integer The speed to be lowered.
---@return integer
function _StepDownSpeed(speed)
	local speeds = _Utils.tableGetSortedKeys(signalImages)
	for i = #speeds, 1, -1 do
		if speeds[i] < speed then
			return _IsSpeedStopIsh(speeds[i]) and 0 or speeds[i]
		end
	end
	return 0
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

---Returns a string list of track IDs from the given track list.
---If no tracks are in the list, returns `"none"`.
---@param tracks Track[] The list of tracks to fetch IDs from.
---@return string
function _StrTrackList(tracks)
	local str = "none"
	for i, track in ipairs(tracks) do
		str = (i == 1 and "" or (str .. ", ")) .. track.id
	end
	return str
end

---Returns a string list of semaphore IDs from the given semaphore list.
---If no semaphores are in the list, returns `"none"`.
---@param semaphores Semaphore[] The list of semaphores to fetch IDs from.
---@return string
function _StrSemaphoreList(semaphores)
	local str = "none"
	for i, semaphore in ipairs(semaphores) do
		str = (i == 1 and "" or (str .. ", ")) .. semaphore.id
	end
	return str
end

local asciiInput = "ąćęłńóśźżĄĆĘŁŃÓŚŹŻ"
local asciiOutput = "acelnoszzACELNOSZZ"
local asciiTable = {}
for i = 1, utf8.len(asciiInput) do
	local c = asciiInput:sub(assert(utf8.offset(asciiInput, i)), (utf8.offset(asciiInput, i + 1) or #asciiInput + 1) - 1)
	asciiTable[c] = asciiOutput:sub(i, i)
end

---Sanitizes the provided string so that no Polish characters are present.
---@param str string The string to be sanitized.
---@return string
function _SanitizeASCII(str)
	local sanitized = ""
	for i = 1, utf8.len(str) do
		local c = str:sub(assert(utf8.offset(str, i)), (utf8.offset(str, i + 1) or #str + 1) - 1)
		sanitized = sanitized .. (asciiTable[c] or c)
	end
	return sanitized
end

---Tests some of the fundamentals of this program.
function _Test()
	_LogWrite("Performing tests...")
	assert(_SanitizeASCII("Warszawa Wschodnia") == "Warszawa Wschodnia")
	assert(_SanitizeASCII("Sulejówek Miłosna") == "Sulejowek Milosna")
	assert(_SanitizeASCII(asciiInput) == asciiOutput)
	local time1 = _Time.timeToObj("10:30")
	assert(time1.h == 10)
	assert(time1.m == 30)
	assert(time1.s == 0)
	local time2 = _Time.timeToObj("9:14.3")
	assert(time2.h == 9)
	assert(time2.m == 14)
	assert(time2.s == 18)
	local time3 = _Time.timeToObj("23:02:14")
	assert(time3.h == 23)
	assert(time3.m == 2)
	assert(time3.s == 14)
	local time4 = _Time.timeToObj("3.11")
	assert(time4.h == 3)
	assert(time4.m == 11)
	assert(_Time.timeToStr(Time.hm(10, 30)) == "10.30")
	assert(_Time.timeToStr(Time.hms(9, 14, 18)) == "9.14.3")
	assert(_Time.timeToStr(Time.hms(23, 2, 14)) == "23.02.2")
	assert(_Time.timeToStr(Time.dhms(1, 0, 0, 5)) == "0.00")
	_LogWrite("Tests complete!")
end