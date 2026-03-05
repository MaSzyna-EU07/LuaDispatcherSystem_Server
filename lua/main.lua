VERSION = "5.0 Edition (2025 Reboot Alpha)"
require("lua.main_utils")
_Com = require("lua.main_communication")

local api = require "eu07.events"
local json = require("lua.json")

-- LOVE2D-specific code:
local isGui = api.gui
if isGui then
	SCENARIO = "td"
	FILENAME = "td.json"
	function love.draw() love.graphics.print("This is the server.\nWhile it does provide a way to not need to wait a few minutes until the simulator loads,\nit does not provide any visual features.\nPlease use the client along with the server to view the traffic.\n\nVersion " .. VERSION .. " by jakubg1", 50, 50) end
	function love.update(dt) api.update(dt) end
end

local Time = require("lua.Time")
local Station = require("lua.Station")
local Route = require("lua.Route")

local tempEventCounters = {loop = 0}

_CurrentTime = Time({hour=11,minute=30,second=0})
_Stations = {}
_Routes = {}

function _Init(filename)
	_LogWrite("\n     __                   \n    / /  DISPATCHER SYSTEM\n   / /     __  __  ____   \n  / /     / / / / / __ \\  \n / /___  / / / / / /_/ /_ \n/_____/ |_____/  \\______/ \n               for MaSzyna\n\nBrought to you by jakubg1\n\nVERSION: " .. VERSION, 1, 1)

	_Com.init()

	-- decode the contents and store in a table
	local fileData = _GetDataFromFile(filename)
	for stationN, stationData in pairs(fileData.stations) do
		_Stations[stationN] = Station(stationN, stationData)
	end
	for routeN, routeData in pairs(fileData.routes) do
		_Routes[routeN] = Route(routeN, routeData)
	end
	-- Actually initialize data when all stations, tracks, switches, etc. are added to the database.
	for name, station in pairs(_Stations) do
		station:init()
	end
	for name, route in pairs(_Routes) do
		route:init()
	end

	_CreateLoopEvent(_NextTimeTick, 1)
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

function _GetDataFromFile(filename)
	local contents = assert(_LoadFile(filename), "Could not open file at " .. tostring(filename))
	return json.decode(contents)
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

function _GetStation(stationN)
	if not _Stations[stationN] then
		_LogWrite("Tried to access a nonexistent station: " .. tostring(stationN), 2, 1)
	end
	return _Stations[stationN]
end

function _GetRoute(routeN)
	if not _Routes[routeN] then
		_LogWrite("Tried to access a nonexistent route: " .. tostring(routeN), 2, 1)
	end
	return _Routes[routeN]
end

function _GetStationOrRoute(name)
	local result = _Stations[name] or _Routes[name]
	if not result then
		_LogWrite("Tried to access a nonexistent station/route: " .. tostring(result), 2, 1)
	end
	return result
end

---Returns a Track based on its simulation name, or `nil` if it is not found.
---@param name string For example: `"Eb_It2"`
---@return Track?
function _GetTrack(name)
	local s = _StrSplit(name, "_")
	local station = _GetStationOrRoute(s[1])
	if not station then
		_LogWrite("Tried to access an invalid track: " .. tostring(name), 2, 1)
	end
	return station and station:getTrack(s[2])
end

---Returns a Switch based on its simulation name, or `nil` if it is not found.
---@param name string For example: `"Eb_39"`
---@return Switch?
function _GetSwitch(name)
	local s = _StrSplit(name, "_")
	local station = _GetStation(s[1])
	if not station then
		_LogWrite("Tried to access an invalid switch: " .. tostring(name), 2, 1)
	end
	return station and station:getSwitch(s[2])
end

---Returns a Semaphore based on its simulation name, or `nil` if it is not found.
---@param name string For example: `"Eb_A"`
---@return Semaphore?
function _GetSemaphore(name)
	local s = _StrSplit(name, "_")
	local station = _GetStation(s[1])
	if not station then
		_LogWrite("Tried to access an invalid semaphore: " .. tostring(name), 2, 1)
	end
	return station and station:getSemaphore(s[2])
end

function _NextTimeTick()
	_Com.sendBytes({0xFF})
	_CurrentTime = _CurrentTime + 1
	_LogWrite("Time: " .. tostring(_CurrentTime), 1, 2)
end







function _ObtainTempEventName(name)
	local n = "lua_temp_" .. name .. tostring(tempEventCounters[name])
	tempEventCounters[name] = tempEventCounters[name] + 1
	_LogWrite("Obtained a new temporary event name: " .. n, 1, 3)
	return n
end

function _CreateLoopEvent(func, delay)
	if isGui then
		api.createLoopEvent(func, delay)
	else
		local name = _ObtainTempEventName("loop")
		local f = function(event, activator)
			func()
			api.event_dispatch_n(name, nil, 0)
		end

		api.event_create(name, delay, 0, f)
		api.event_dispatch_n(name, nil, 0)
	end
end







_Init(FILENAME)

--for i = 1, 40 do
--	local t = Time({hour=14,minute=36,second=32}) - i * 2000
--	print(t:strDays(), t:getInt())
--end