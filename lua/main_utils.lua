local api = require("eu07.events")

local verboseValue = 3
local severityTable = {"INFO", "ERROR", "SUCCESS", "FAIL"}

function _LogWrite(text, severity, weight)
	if verboseValue >= weight then
		api.writelog("LuaDispatcher -> [" .. severityTable[severity] .. "] " .. text)
	end
end

function _Clamp(value, min, max)
	return math.min(math.max(value, min), max)
end

function _Ternary(v, a, b)
	if v then return a else return b end
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

function _FindLast(text, toFind)
	local a, b = string.find(text:reverse(), toFind:reverse())
	return #text - b + 1, #text - a + 1
end

local signalImages = {
	[0]="s1",
	[1]={[0]="s5",[1]="s2",[2]="s4",[3]="s4",[4]="s3"},
	[2]={[0]="s13",[1]="s10",[2]="s12",[3]="s12",[4]="s11"},
	[3]={[0]="s13a",[1]="s10a",[2]="s12a",[3]="s12a",[4]="s11a"},
	[4]={[0]="s9",[1]="s6",[2]="s8",[3]="s8",[4]="s7"},
	[5]="ms1",
	[6]="ms2",
	[7]="sz1",
	[8]="s1a"
}

function _SignalImage(speed, nextSpeed)
	local first = signalImages[speed]
	if type(first) == "string" then return first end
	return first[nextSpeed] or first[0]
end

local signalImagesRepeater = {[0]="sp1",[1]="sp2",[2]="sp4",[3]="sp4",[4]="sp3"}

function _SignalImageRepeater(speed)
	return signalImagesRepeater[speed] or signalImagesRepeater[0]
end

function _SwitchChar(state)
	return _Ternary(state, "-", "+")
end