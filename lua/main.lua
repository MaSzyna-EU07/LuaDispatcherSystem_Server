VERSION = "5.0 Edition (2025 Reboot Alpha)"
require("lua.main_enums")
require("lua.main_utils")
_Utils = require("lua.utils")
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
local Objects = require("lua.Objects")
local TileDatabase = require("lua.TileDatabase")

_CurrentTime = Time({hour=11,minute=30})

---@type Objects
_Obj = Objects()
---@type TileDatabase
_TileDB = TileDatabase()

_Filename = nil

function _TryInit(filename)
	local success, result = pcall(_Init, filename)
	if not success then
		_LogWrite("INIT FATAL ERROR: " .. tostring(result), Severity.ERROR, 3)
	end
end

function _Init(filename)
	_LogWrite("\n     __                   \n    / /  DISPATCHER SYSTEM\n   / /     __  __  ____   \n  / /     / / / / / __ \\  \n / /___  / / / / / /_/ /_ \n/_____/ |_____/  \\______/ \n               for MaSzyna\n\nBrought to you by jakubg1\n\nVERSION: " .. VERSION, Severity.INFO, 1)

	_Com.init()

	-- decode the contents and store in a table
	local fileData = assert(_Utils.loadJson(filename), "Could not open file at " .. tostring(filename))
	-- Create stations and routes.
	for routeN, routeData in pairs(fileData.routes) do
		_Obj:addRoute(routeN, routeData)
	end

	-- Additional pass for schematic data.
	-- TODO: Make schematics the only way of defining stuff.
	_Filename = filename
	_LoadSchematics()

	-- Initialize route blockades, since only now the last block semaphores can be attached to the entry semaphores on stations.
	for i, name in ipairs(_Obj:getRouteList()) do
		_Obj:getRoute(name):init()
	end

	_CreateLoopEvent("loop", _TryLoop, 1)
end

function _LoadSchematics(stationID)
	-- Reload the file.
	local projFilename = _Filename:sub(1, _Filename:len() - 5) .. "_proj.json"
	local projData = _Utils.loadJson(projFilename)
	if projData then
		_LogWrite("Project file (re)loaded: " .. projFilename, Severity.SUCCESS, 3)
		if stationID then
			-- Load a single station.
			local stationData = projData.stations[projData.stationIndex[stationID]]
			_LoadSchematic(stationData)
		else
			-- Load all stations.
			for i, stationData in ipairs(projData.stations) do
				_LoadSchematic(stationData)
			end
		end
	end
end

function _LoadSchematic(stationData)
	local station = _Obj:getStation(stationData.shortcut)
	if not station then
		_Obj:addStation(stationData.shortcut)
	end
	_Obj:assertGetStation(stationData.shortcut):loadSchematic(stationData)
end

function _TryLoop()
	local success, result = pcall(_Loop)
	if not success then
		_LogWrite("LOOP FATAL ERROR: " .. tostring(result), Severity.ERROR, 3)
	end
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

_TryInit(FILENAME)