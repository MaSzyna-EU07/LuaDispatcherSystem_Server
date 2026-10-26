VERSION = "5.0 Edition (2025 Reboot Alpha)"
require("lua.main_enums")
require("lua.main_utils")
_Utils = require("lua.utils")
_API = require("lua.API")
_Com = require("lua.main_communication")

local Time = require("lua.Time")
local Objects = require("lua.Objects")
local Timetables = require("lua.Timetables")
local TileDatabase = require("lua.TileDatabase")

_CurrentTime = Time({hour=11,minute=30})
---@type table<string, function[]>
_Callbacks = {}

---@type Objects
_Obj = Objects()
---@type Timetables
_Timetables = Timetables()
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

	-- Create stations and load schematic data.
	_LoadSchematics()

	_CreateLoopEvent("loop", _TryLoop, 1)
	_API:eventCreate("onstart_lua", 0.1, 0, function() _DoCallback("start") end)
end

---(Re)loads schematics for the specified station or for all stations in the project.
---@param stationID string? If specified, (re)loads the schematic only for the specified station.
function _LoadSchematics(stationID)
	-- Reload the file.
	local projFilename = _Filename:sub(1, _Filename:len() - 5) .. ".json"
	local projData = _Utils.loadJson(projFilename)
	if projData then
		_LogWrite("Project file (re)loaded: " .. projFilename, Severity.SUCCESS, 3)
		if stationID then
			-- Load a single station.
			local stationData = projData.stations[stationID]
			_LoadSchematic(stationData)
			-- Regenerate its blockades.
			-- TODO: Any blockades which include this station should be regenerated.
			_Obj:getStation(stationID).schematic:generateSemaphoreNextDefaults()
			_Obj:getStation(stationID).schematic:generateBlockades()
		else
			-- Load all stations.
			for shortcut, stationData in pairs(projData.stations) do
				_LoadSchematic(stationData)
			end
			-- (Re)assign automatically generated next semaphores.
			for i, name in ipairs(_Obj:getStationList()) do
				_Obj:getStation(name).schematic:generateSemaphoreNextDefaults()
			end
			-- (Re)create blockades.
			-- This is done in a separate pass because we could initialize a blockade without all default semaphores set yet (see multi-schematic blockades).
			for i, name in ipairs(_Obj:getStationList()) do
				_Obj:getStation(name).schematic:generateBlockades()
			end
		end
	else
		_LogWrite("Failed to (re)load project file: " .. projFilename, Severity.ERROR, 3)
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

---Creates a callback. If the specified action is called, the specified function will be called.
---Multiple functions can be bound to the same callback, and they are called in their order of registration.
---@param name string The callback name, `station_X` is the station tick, where `X` is the station shortcut. `start` is launched at the start (after all vehicles are placed).
---@param func function The function to be ran whe the specified callback is called.
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

function _PrintDiagnostics()
	_LogWrite("Semaphore assignments:")
	for i, trackID in ipairs(_Obj:getTrackList()) do
		local track = _Obj:assertGetTrack(trackID)
		if track.semaphore then
			_LogWrite(string.format("%s -> %s", trackID, track.semaphore.id))
		end
	end
end

-- TODO: Find a better way to execute unit tests?
_Test()

-- TODO: Extract API to a separate file
return {
	init = function(config) _TryInit(config.scenario, config.filename) end,
	getTrack = function(name) return _Obj:getTrack(name) end,
	setCallback = function(name, func) _CreateCallback(name, func) end
}

-- TODO: Create unit tests

--    local s = "Pchnąć w tę łódź ośm skrzyń fig"
--    local a = s:len()
--    local b = utf8.len(s)
--    _LogWrite("Length: " .. tostring(a) .. ", " .. tostring(b), Severity.INFO, 1)