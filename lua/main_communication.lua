local com = {}

local COM_IMAGES = {
	sz=0xFF,
	s1=0x01, s2=0x02, s3=0x03, s4=0x04, s5=0x05, s6=0x06, s7=0x07, s8=0x08, s9=0x09, s10=0x0A, s11=0x0B, s12=0x0C, s13=0x0D,
	s1a=0x21, s10a=0x2A, s11a=0x2B, s12a=0x2C, s13a=0x2D,
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
	_LogWrite("[COMMUNICATION] File Name: " .. com_path, 1, 1)
	com.sendBytes({0x70, 0xA0, 0xE0, 0x07})
	com.sendBytes({0x05, 0x00, 0x00, 0xFF}) -- version ID
	-- Clear any residue commands so that they aren't executed right at the start of the next session.
	_SaveFile(COM_INPUT_FILE, "")
	_CreateLoopEvent(com.tick, COM_SAVE_INTERVAL)
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
			_LogWrite("[COMMUNICATION] Error executing command `" .. line .. "`: " .. result, 2, 1)
		end
	end
	_SaveFile(COM_INPUT_FILE, "")
end

function com.doCommand(command)
	local operands = _StrSplit(command, " ")
	if operands[1] == "s" then
		_GetSemaphore(operands[2]):setSpeed(assert(tonumber(operands[3]), "Missing speed parameter"), tonumber(operands[4]) or _GetSemaphore(operands[4]))
	elseif operands[1] == "su" then
		_GetSemaphore(operands[2]):stop()
		_GetSemaphore(operands[2]):unreserveAllTracks()
	elseif operands[1] == "j" then
		_GetSwitch(operands[2]):setState(operands[3] == "+")
	elseif operands[1] == "t" then
		if operands[3] == "free" then
			_GetTrack(operands[2]):free()
		elseif operands[3] == "busy" then
			_GetTrack(operands[2]):busy()
		elseif operands[3] == "res" then
			_GetTrack(operands[2]):reserve()
		end
	elseif operands[1] == "tr" then
		_GetTrack(operands[2]):reserve(operands[3] and _GetSemaphore(operands[3]))
	elseif operands[1] == "i" then
		_GetSemaphore(operands[2]):getItinerary(operands[3]):dispatch()
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
		_LogWrite("[COMMUNICATION] Tried to access a nonexistent ID: " .. tostring(id), 2, 1)
		return {0, 0}
	end
	return com.idToBytes(idTable[id].id)
end

-- WARNING! Multiple objects with same name existing in different stations will OVERWRITE each other, that's very important to fix that!!!

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

return com