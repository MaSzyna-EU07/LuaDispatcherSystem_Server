local json = require("lua.json")

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

function _LoadFile(filename)
	local file = io.open(filename, "r")
	if not file then
		return
	end
	io.input(file)
	local contents = io.read("*a")
	io.close(file)
	return contents
end

---Loads a file, and if it is there, returns its deserialized JSON contents.
---@param filename string The file name.
---@return table?
function _GetDataFromFile(filename)
	local contents = _LoadFile(filename)
	return contents and json.decode(contents)
end

---Saves a file to the given path with the given contents. Errors out if the file cannot be created.
---@param path string The path to the file.
---@param data string The contents of the file.
function _SaveFile(path, data)
	local file = io.open(path, "w")
	assert(file, string.format("SAVE FILE FAIL: %s", path))
	io.output(file)
	io.write(data)
	io.close(file)
end

---Splits a string `s` with the delimiter being `k` and returns a list of results.
---@param s string A string to be split.
---@param k string A delimiter which determines where to split `s`.
---@return string[]
function _StrSplit(s, k)
	local result = {}
	local l = k:len()
	while true do
		local n = s:find("%" .. k)
		if n then
			table.insert(result, s:sub(1, n - 1))
			s = s:sub(n + l)
		else
			table.insert(result, s)
			return result
		end
	end
end

---Returns `true` if the string `s` ends with the clause `c`.
---@param s string The string to be searched.
---@param c string The expected ending of the string `s`.
---@return boolean
function _StrEndsWith(s, c)
	return s:sub(s:len() - c:len() + 1) == c
end

---Returns a list of all keys in table `t`, sorted alphabetically.
---@param t table The table from which the keys will be sourced.
---@return table
function _TableGetSortedKeys(t)
	local keys = {}
	for k, v in pairs(t) do
		table.insert(keys, k)
	end
	table.sort(keys)
	return keys
end

---Returns `true` if the table does not contain any keys.
---@param t table The potentially empty table.
---@return boolean
function _TableIsEmpty(t)
	for k, v in pairs(t) do
		return false
	end
	return true
end

function _FindLast(text, toFind)
	local a, b = string.find(text:reverse(), toFind:reverse())
	return #text - b + 1, #text - a + 1
end

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

function _SwitchChar(state)
	return state and "-" or "+"
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