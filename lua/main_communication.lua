local Track = require("lua.Track")
local Switch = require("lua.Switch")
local Semaphore = require("lua.Semaphore")

local com = {}

local COM_IMAGES = {
	sz1=0xFF,
	s1=0x01, s2=0x02, s3=0x03, s4=0x04, s5=0x05, s6=0x06, s7=0x07, s8=0x08, s9=0x09, s10=0x0A, s11=0x0B, s12=0x0C, s13=0x0D,
	s1a=0x21, s10a=0x2A, s11a=0x2B, s12a=0x2C, s13a=0x2D,
	sr1=0x41, sr2=0x42, sr3=0x43,
	ms1=0x80, ms2=0x81
}
local COM_SAVE_INTERVAL = 1
local COM_INPUT_FILE = "logs/command.txt"

local com_path = ""
local com_buffer = ""
---Example index: `com_ids.tracks.sta1_iz2.id`
---@type table<string, table<string, {id: integer, sid: integer}>>
local com_ids = {stations = {}, tracks = {}, switches = {}, semaphores = {}}
local com_counters = {}

function com.init()
	com_path = "logs/" .. SCENARIO .. "@" .. os.date("%Y-%m-%d_%H-%M-%S") .. ".dsl"
	_LogWrite("[COMMUNICATION] File Name: " .. com_path, Severity.INFO, 1)
	com.sendBytes({0x70, 0xA0, 0xE0, 0x07})
	com.sendBytes({0x05, 0x00, 0x00, 0xFF}) -- version ID
	-- Clear any residue commands so that they aren't executed right at the start of the next session.
	_SaveFile(COM_INPUT_FILE, "")
	_CreateLoopEvent("tick_com", com.tick, COM_SAVE_INTERVAL)
end

function com.sendBytes(bytes)
	for i, n in ipairs(bytes) do
		com_buffer = com_buffer .. string.char(n)
	end
end

function com.sendText(text)
	com_buffer = com_buffer .. text .. string.char(0x00)
end

function com.tick()
	com.readCommands()
	com.saveBuffer()
end

function com.readCommands()
	local data = _LoadFile(COM_INPUT_FILE)
	if not data or data == "" then
		return
	end
	local lines = _StrSplit(data, "\n")
	for i, line in ipairs(lines) do
		local success, result = pcall(function() com.doCommand(line) end)
		if not success then
			_LogWrite("[COMMUNICATION] Error executing command `" .. line .. "`: " .. result, Severity.ERROR, 1)
		end
	end
	_SaveFile(COM_INPUT_FILE, "")
end

function com.doCommand(command)
	local operands = _StrSplit(command, " ")
	if operands[1] == "s" then
		-- Sets a semaphore. `s <semaphore_id> <speed> [next] ["w24"]`
		_Obj:getSemaphore(operands[2]):setW24(operands[5] == "w24")
		_Obj:getSemaphore(operands[2]):setSpeed(assert(tonumber(operands[3]), "Missing speed parameter"), tonumber(operands[4]) or (operands[4] and _Obj:getSemaphore(operands[4])))
	elseif operands[1] == "su" then
		-- Stops a semaphore and unreserves all claimed tracks. `s <semaphore_id>`
		_Obj:getSemaphore(operands[2]):stop()
		_Obj:getSemaphore(operands[2]):unreserveAllTracks()
	elseif operands[1] == "j" then
		-- Sets a switch. `j <switch_id> <"+"|"-">`
		_Obj:getSwitch(operands[2]):setState(operands[3] == "+")
	elseif operands[1] == "ju" then
		-- Unforces a switch. `ju <switch_id>`
		_Obj:getSwitch(operands[2]):setForced(false)
	elseif operands[1] == "t" then
		-- Sets a track. `t <track_id> <"free"|"busy"|"res">`
		if operands[3] == "free" then
			_Obj:getTrack(operands[2]):free()
		elseif operands[3] == "busy" then
			_Obj:getTrack(operands[2]):busy()
		elseif operands[3] == "res" then
			_Obj:getTrack(operands[2]):reserve()
		end
	elseif operands[1] == "tr" then
		-- Reserves a track with a semaphore. `tr <track_id> [semaphore_id]`
		_Obj:getTrack(operands[2]):reserve(operands[3] and _Obj:getSemaphore(operands[3]))
	elseif operands[1] == "tc" then
		-- Sends a command to the specified train on a track. `tc <track_id> <str> [num1] [num2]`
		_Obj:getTrack(operands[2]):sendCommand(operands[3], tonumber(operands[4]) or 0, tonumber(operands[5]) or 0)
	elseif operands[1] == "nt" then
		-- Registers a new track. `nt <station_or_route_id> <track_id>`
		-- This DOES NOT WORK !!!
		_Obj:addTrack(Track(_Obj:getStationOrRoute(operands[2]), operands[3]))
	end
end

function com.saveBuffer()
	if com_buffer == "" then return end
	local file = io.open(com_path, "ab")
	assert(file, "Could not open file at " .. com_path)
	io.output(file)
	io.write(com_buffer)
	io.close(file)
	com_buffer = ""
end

function com.idToBytes(id)
	return {math.floor(id / 256), id % 256}
end

function com.getObjID(idTable, id)
	if not idTable[id] then
		_LogWrite("[COMMUNICATION] Tried to access a nonexistent ID: " .. tostring(id), Severity.ERROR, 1)
		return {0, 0}
	end
	return com.idToBytes(idTable[id].id)
end

function com.initObject(typeByte, idTable, counter, name, stationID)
	com_counters[counter] = (com_counters[counter] or 0) + 1
	idTable[name] = {id = com_counters[counter], sid = stationID}

	com.sendBytes({typeByte})
	--pcall(function() for k, v in pairs(stationID) do print(k, v) end end)
	if stationID then com.sendBytes(com.idToBytes(stationID)) end
	com.sendText(name)
end

function com.initStation(name)
	com.initObject(0xF0, com_ids.stations, "station", name)
end

function com.initRoute(name)
	com.initObject(0xF1, com_ids.stations, "station", name)
end

function com.initTrack(stationName, name)
	com.initObject(0xF2, com_ids.tracks, "track", name, com_ids.stations[stationName].id)
end

function com.initSwitch(stationName, name)
	com.initObject(0xF3, com_ids.switches, "switch", name, com_ids.stations[stationName].id)
end

function com.initSemaphore(stationName, name, type)
	com.initObject(0xF4, com_ids.semaphores, "semaphore", name, com_ids.stations[stationName].id)
	com.sendBytes({type})
end

function com.setTrack(id, occupied, reserved)
	com.sendBytes({0x12})
	com.sendBytes(com.getObjID(com_ids.tracks, id))
	com.sendBytes({(occupied and 1 or 0) + (reserved and 2 or 0)})
end

function com.setSwitch(id, state, forced)
	com.sendBytes({0x13})
	com.sendBytes(com.getObjID(com_ids.switches, id))
	com.sendBytes({(state and 1 or 0) + (forced and 16 or 0)})
end

function com.setSemaphore(id, speed, nextSpeed, image)
	com.sendBytes({0x14})
	com.sendBytes(com.getObjID(com_ids.semaphores, id))
	com.sendBytes({speed, nextSpeed or 0xFF})
	com.sendBytes({COM_IMAGES[image]})
end

function com.print(message)
	com.sendBytes({0x01})
	com.sendText(message)
end

return com