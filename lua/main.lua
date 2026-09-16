VERSION = "5.0 Edition (2025 Reboot Alpha)"
require("lua.main_enums")
require("lua.main_utils")
_Utils = require("lua.utils")
_API = require("lua.API")
_Com = require("lua.main_communication")

local Time = require("lua.Time")
local Objects = require("lua.Objects")
local TileDatabase = require("lua.TileDatabase")

_CurrentTime = Time({hour=11,minute=30})
---@type table<string, function[]>
_Callbacks = {}

---@type Objects
_Obj = Objects()
---@type TileDatabase
_TileDB = TileDatabase()

_Filename = nil

function _TryInit(scenario, filename)
	local success, result = pcall(_Init, scenario, filename)
	if not success then
		_LogWrite("INIT FATAL ERROR: " .. tostring(result), Severity.ERROR, 3)
	end
end

function _Init(scenario, filename)
	_LogWrite("\n     __                   \n    / /  DISPATCHER SYSTEM\n   / /     __  __  ____   \n  / /     / / / / / __ \\  \n / /___  / / / / / /_/ /_ \n/_____/ |_____/  \\______/ \n               for MaSzyna\n\nBrought to you by jakubg1\n\nVERSION: " .. VERSION, Severity.INFO, 1)

	_Com.init(scenario)
	_Filename = filename

	-- decode the contents and store in a table
	local fileData = assert(_Utils.loadJson(filename), "Could not open file at " .. tostring(filename))

	-- Create stations and load schematic data.
	_LoadSchematics()
	-- Create blockades.
	-- TODO: Blockades should be defined by schematic data.
	for blockadeN, blockadeData in pairs(fileData.blockades) do
		_Obj:addBlockade(blockadeN, blockadeData)
	end

	-- Initialize blockades, since only now the last block semaphores can be attached to the entry semaphores on stations.
	for i, name in ipairs(_Obj:getBlockadeList()) do
		_Obj:getBlockade(name):init()
	end

	_CreateLoopEvent("loop", _TryLoop, 1)
end

---(Re)loads schematics for the specified station or for all stations in the project.
---@param stationID string? If specified, (re)loads the schematic only for the specified station.
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

function _CreateCallback(name, func)
	local list = _Callbacks[name] or {}
	table.insert(list, func)
	_Callbacks[name] = list
end

function _DoCallback(name, ...)
	if _Callbacks[name] then
		for i, func in ipairs(_Callbacks[name]) do
			func(...)
		end
	end
end

-- TODO: Extract API to a separate file
return {
	init = function(config) _TryInit(config.scenario, config.filename) end,
	getTrack = function(name) return _Obj:getTrack(name) end,
	setCallback = function(name, func) _CreateCallback(name, func) end
}