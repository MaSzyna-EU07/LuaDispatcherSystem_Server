VERSION = "5.0 Edition (2025 Reboot Alpha)"
require("lua.main_enums")
require("lua.main_utils")
_API = require("lua.API")
_Com = require("lua.main_communication")

-- LOVE2D-specific code:
if _API:isGui() then
	SCENARIO = "td"
	FILENAME = "td.json"
	function love.draw()
		love.graphics.print("This is the server.\nWhile it does provide a way to not need to wait a few minutes until the simulator loads,\nit does not provide any visual features.\nPlease use the client alongside the server to view the traffic.\n\nVersion " .. VERSION .. " by jakubg1", 50, 50)
		love.graphics.print("Tracks:", 50, 150)
		for i, name in ipairs(_Obj:getTrackList()) do
			love.graphics.print(name, 50, 160 + i * 15)
		end
		love.graphics.print("Switches:", 250, 150)
		for i, name in ipairs(_Obj:getSwitchList()) do
			love.graphics.print(name, 250, 160 + i * 15)
		end
		love.graphics.print("Semaphores:", 450, 150)
		for i, name in ipairs(_Obj:getSemaphoreList()) do
			love.graphics.print(name, 450, 160 + i * 15)
		end
	end
	function love.update(dt) _API:update(dt) end
end

local Time = require("lua.Time")
local Station = require("lua.Station")
local Route = require("lua.Route")
local Objects = require("lua.Objects")

_CurrentTime = Time({hour=11,minute=30})

---@type Objects
_Obj = Objects()

function _Init(filename)
	_LogWrite("\n     __                   \n    / /  DISPATCHER SYSTEM\n   / /     __  __  ____   \n  / /     / / / / / __ \\  \n / /___  / / / / / /_/ /_ \n/_____/ |_____/  \\______/ \n               for MaSzyna\n\nBrought to you by jakubg1\n\nVERSION: " .. VERSION, Severity.INFO, 1)

	_Com.init()

	-- decode the contents and store in a table
	local fileData = _GetDataFromFile(filename)
	for stationN, stationData in pairs(fileData.stations) do
		_Obj:addStation(Station(stationN, stationData))
	end
	for routeN, routeData in pairs(fileData.routes) do
		_Obj:addRoute(Route(routeN, routeData))
	end

	_CreateLoopEvent("loop", _Loop, 1)
end

function _Loop()
	_NextTimeTick()
end

function _NextTimeTick()
	_Com.sendBytes({0xFF})
	_CurrentTime = _CurrentTime + 1
	_LogWrite("Time: " .. tostring(_CurrentTime), Severity.INFO, 2)
end

function _CreateLoopEvent(name, func, delay, randomDelay)
	_API:eventCreate(name, delay, randomDelay or 0, function(event, activator) func(); _API:eventDispatch(name) end)
	_API:eventDispatch(name)
end

_Init(FILENAME)