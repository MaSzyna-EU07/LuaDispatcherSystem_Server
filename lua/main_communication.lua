local com = {}

local COM_IMAGES = {
	uszk=0x00, ciemny=0x00,
	s1=0x01, s2=0x02, s3=0x03, s4=0x04, s5=0x05, s6=0x06, s7=0x07, s8=0x08, s9=0x09, s10=0x0A, s11=0x0B, s12=0x0C, s13=0x0D,
	os1=0x05, os2=0x02, os3=0x03, os4=0x04,
	s1a=0x21, s10a=0x2A, s11a=0x2B, s12a=0x2C, s13a=0x2D,
	sr1=0x41, sr2=0x42, sr3=0x43,
	ms1=0x80, ms2=0x81,
	sz=0xFF, sz1=0xFF
}
local COM_BLOCKADES = {n = true, p = false, x = nil}
local COM_SAVE_INTERVAL = 1
local COM_INPUT_FILE = "logs/command.txt"

local com_path = ""
local com_buffer = ""
---Example index: `com_ids.tracks.sta1_iz2.id`
---@type table<string, table<string, {id: integer}>>
local com_ids = {stations = {}, tracks = {}, switches = {}, semaphores = {}}
local com_counters = {}

function com.init(scenario)
	com_path = "logs/" .. scenario .. "@" .. os.date("%Y-%m-%d_%H-%M-%S") .. ".dsl"
	_LogWrite("[COMMUNICATION] File Name: " .. com_path, Severity.INFO, 1)
	com.sendBytes({0x70, 0xA0, 0xE0, 0x07})
	com.sendBytes({0x05, 0x00, 0x00, 0xFF}) -- version ID
	-- Clear any residue commands so that they aren't executed right at the start of the next session.
	_Utils.saveFile(COM_INPUT_FILE, "")
	_CreateLoopEvent("tick_com", com.tick, COM_SAVE_INTERVAL)
end

---Sends some bytes. A list of bytes is expected, not the raw byte value.
---Values out of the 0..255 range will be modulo-ed, `math.huge` equals 255, anything else will log a warning and will be ignored.
---@param bytes integer[] List of bytes to be sent.
function com.sendBytes(bytes)
	for i, n in ipairs(bytes) do
		if type(n) == "number" then
			com_buffer = com_buffer .. string.char(n == math.huge and 255 or n % 256)
		else
			_LogWrite("Ignored illegal byte in `com.sendBytes()`: " .. tostring(n), Severity.ERROR, 3)
		end
	end
end

---Sends a text message in bytes, alongside a null terminator byte.
---@param text string Text to be sent to the log file.
function com.sendText(text)
	com_buffer = com_buffer .. text .. string.char(0x00)
end

function com.tick()
	com.readCommands()
	com.saveBuffer()
end

function com.readCommands()
	local data = _Utils.loadFile(COM_INPUT_FILE)
	if not data or data == "" then
		return
	end
	local lines = _Utils.strSplit(data, "\n")
	for i, line in ipairs(lines) do
		local success, result = pcall(function() com.doCommand(line) end)
		if not success then
			_LogWrite("[COMMUNICATION] Error executing command `" .. line .. "`: " .. result, Severity.ERROR, 3)
		end
	end
	_Utils.saveFile(COM_INPUT_FILE, "")
end

function com.doCommand(command)
	if command == "" then
		return
	end
	_LogWrite("[COMMUNICATION] Processing command: `" .. command .. "`", Severity.INFO, 1)
	local operands = _Utils.strSplit(command, " ")
	if operands[1] == "s" then
		-- Sets a semaphore. `s <semaphore_id> <speed> [next] ["w24"]`
		-- If `next` is a semaphore ID, it should be prefixed with a `:` character, like `s MMz_A 1 :MMz_X`.
		_Obj:assertGetSemaphore(operands[2]):setW24(operands[5] == "w24")
		-- Convert the next speed/semaphore to a number.
		---@type Speed|Semaphore|string?
		local next = tonumber(operands[4]) or operands[4]
		if type(next) == "string" then
			-- Remove the leading `:` character. This allows using fully numeric semaphore IDs, like 442 (enter `:442` as the argument).
			next = _Obj:assertGetSemaphore(_Utils.strStartsWith(next, ":") and next:sub(2) or next)
		elseif next == 1 then
			-- 1 is an alias for `math.huge` (Vmax)
			next = math.huge
		end
		local speed = assert(tonumber(operands[3]), "Missing speed parameter")
		_Obj:assertGetSemaphore(operands[2]):setSpeed(speed == 1 and math.huge or speed, next)
	elseif operands[1] == "su" then
		-- Stops a semaphore and unreserves all claimed tracks. `s <semaphore_id>`
		_Obj:assertGetSemaphore(operands[2]):stop()
		_Obj:assertGetSemaphore(operands[2]):unreserveAllTracks()
	elseif operands[1] == "j" then
		-- Sets a switch. `j <switch_id> <"+"|"-">`
		_Obj:assertGetSwitch(operands[2]):setState(operands[3] == "+")
	elseif operands[1] == "ju" then
		-- Unforces a switch. `ju <switch_id>`
		_Obj:assertGetSwitch(operands[2]):setForced(false)
	elseif operands[1] == "t" then
		-- Sets a track. `t <track_id> <"free"|"busy"|"res">`
		if operands[3] == "free" then
			_Obj:assertGetTrack(operands[2]):free()
		elseif operands[3] == "busy" then
			_Obj:assertGetTrack(operands[2]):busy()
		elseif operands[3] == "res" then
			_Obj:assertGetTrack(operands[2]):reserve()
		end
	elseif operands[1] == "tr" then
		-- Reserves a track with a semaphore. `tr <track_id> [semaphore_id]`
		_Obj:assertGetTrack(operands[2]):reserve(operands[3] and _Obj:assertGetSemaphore(operands[3]))
	elseif operands[1] == "tc" then
		-- Sends a command to the specified train on a track. `tc <track_id> <str> [num1] [num2]`
		_Obj:assertGetTrack(operands[2]):sendCommand(operands[3], tonumber(operands[4]) or 0, tonumber(operands[5]) or 0)
	elseif operands[1] == "nt" then
		-- Registers a new track. `nt <track_id>`
		-- This DOES NOT WORK !!!
		_Obj:addTrack(operands[2])
	elseif operands[1] == "b" then
		-- Switches the blockade direction. `b <blockade_id> <n|p|x>`
		_Obj:assertGetBlockade(operands[2]):setDirection(COM_BLOCKADES[operands[3]])
	elseif operands[1] == "p" then
		-- Pathfinds a route. `p <station_id> <track1_id> <track2_id> [t|s]`
		local result = _Obj:assertGetStation(operands[2]).schematic:pathfind(operands[3], operands[4], operands[5] == "s" and PathMode.SHUNT or PathMode.TRAIN)
		if not result then
			com.notify("Pathfinding failed... :(", NotificationColor.RED)
		end
	elseif operands[1] == "pm" then
		-- Pathfinds a route by specifying coordinates. `p <station_id> <x1> <y1> <x2> <y2> [t|s]`
		local schematic = _Obj:assertGetStation(operands[2]).schematic
		local x1, y1, x2, y2 = math.floor(assert(tonumber(operands[3]))), math.floor(assert(tonumber(operands[4]))), math.floor(assert(tonumber(operands[5]))), math.floor(assert(tonumber(operands[6])))
		local result = schematic:pathfindTiles(schematic:assertGetTile(x1, y1), schematic:assertGetTile(x2, y2), operands[7] == "s" and PathMode.SHUNT or PathMode.TRAIN)
		if not result then
			com.notify("Pathfinding failed... :(", NotificationColor.RED)
		end
	elseif operands[1] == "r" then
		-- Reloads all schematics. `r [station_id]`
		_LoadSchematics(operands[2])
	elseif operands[1] == "e" then
		-- Dispatches an event. `e <event>`
		_API:eventDispatch(operands[2])
	elseif operands[1] == "st" then
		-- Spawns a trainset. `st <trainset>`
		_API:spawnTrainset(string.sub(command, 4))
	elseif operands[1] == "tt" then
		-- Creates a notification specifying what timetable has the train on the given track. `tt <track_id>`
		local result = _Obj:assertGetTrack(operands[2]):getTimetable()
		com.notify(result and "Timetable: " .. result or "No timetable found! :(", result and NotificationColor.GREEN or NotificationColor.RED)
	else
		error("Unrecognized command: " .. tostring(operands[1]))
	end
end

function com.saveBuffer()
	if com_buffer == "" then return end
	local file = io.open(com_path, "ab")
	if not file then
		_LogWrite("Potential problem! If this is the last line you see before crashing, make sure to make changes in `main_communication.lua`. Thanks!", Severity.ERROR, 3)
	end
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

function com.initObject(typeByte, idTable, counter, name)
	com_counters[counter] = (com_counters[counter] or 0) + 1
	idTable[name] = {id = com_counters[counter]}
	com.sendBytes({typeByte})
	com.sendText(name)
end

function com.initStation(name)
	com.initObject(0xF0, com_ids.stations, "station", name)
end

function com.initTrack(name)
	com.initObject(0xF2, com_ids.tracks, "track", name)
end

function com.initSwitch(name)
	com.initObject(0xF3, com_ids.switches, "switch", name)
end

function com.initSemaphore(name, type)
	com.initObject(0xF4, com_ids.semaphores, "semaphore", name)
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
	com.sendBytes({speed == math.huge and 0x01 or speed, nextSpeed or 0xFF})
	com.sendBytes({COM_IMAGES[image]})
end

function com.print(message)
	com.sendBytes({0x01})
	com.sendText(message)
end

function com.notify(message, color)
	com.sendBytes({0x02})
	com.sendBytes({NotificationColorID[color or NotificationColor.GREEN]})
	com.sendText(message)
end

function com.highlightTile(stationID, x, y, type)
	com.sendBytes({0x03})
	com.sendBytes(com.getObjID(com_ids.stations, stationID))
	com.sendBytes({x, y, type})
end

return com