VERSION = "5.0 Edition (2025 Reboot Alpha)"
require("lua.main_utils")
_Com = require("lua.main_communication")

local api = require "eu07.events"

-- LOVE2D-specific code:
local isGui = api.gui
if isGui then
	SCENARIO = "td"
	FILENAME = "td.json"
	function love.draw() love.graphics.print("This is the server.\nWhile it does provide a way to not need to wait a few minutes until the simulator loads,\nit does not provide any visual features.\nPlease use the client along with the server to view the traffic.\n\nVersion " .. VERSION .. " by jakubg1", 50, 50) end
	function love.update(dt) api.update(dt) end
else
	-- Real module. Define extra functions.
	-- TODO: Reimplement in the EXE directly!
	function api.event_exists(name)
		return tostring(api.event_find(name)) ~= "cdata<struct TEvent *>: NULL"
	end
end

local Time = require("lua.Time")
local Station = require("lua.Station")
local Route = require("lua.Route")
local Objects = require("lua.Objects")

local tempEventCounters = {loop = 0}

_CurrentTime = Time({hour=11,minute=30})

---@type Objects
_Obj = Objects()

function _Init(filename)
	_LogWrite("\n     __                   \n    / /  DISPATCHER SYSTEM\n   / /     __  __  ____   \n  / /     / / / / / __ \\  \n / /___  / / / / / /_/ /_ \n/_____/ |_____/  \\______/ \n               for MaSzyna\n\nBrought to you by jakubg1\n\nVERSION: " .. VERSION, 1, 1)

	_Com.init()

	-- decode the contents and store in a table
	local fileData = _GetDataFromFile(filename)
	for stationN, stationData in pairs(fileData.stations) do
		_Obj:addStation(Station(stationN, stationData))
	end
	for routeN, routeData in pairs(fileData.routes) do
		_Obj:addRoute(Route(routeN, routeData))
	end

	_CreateLoopEvent(_Loop, 1)
end

function _Loop()
	_NextTimeTick()
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