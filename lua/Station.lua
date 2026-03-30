local class = require "lua.class"
local Schematic = require("lua.Schematic")

---@class Station
local Station = class:derive("Station")

---Creates a Station.
---@param shortcut string The station shortcut.
---@param data table? Data for the station. If `nil`, the station will be a dummy and a `:loadSchematic()` call is expected.
function Station:new(shortcut, data)
	_Com.initStation(shortcut)

	self.shortcut = shortcut

	if data then
		-- Tracks
		for i, trackN in ipairs(data.tracks) do
			local id = data.prefixDeviceNames and (self.shortcut .. "_" .. trackN) or trackN
			_Obj:addTrack(id)
		end
		-- Switches
		for i, switchN in ipairs(data.switches) do
			local id = data.prefixDeviceNames and (self.shortcut .. "_" .. switchN) or switchN
			_Obj:addSwitch(id)
		end
		-- Semaphores
		for semaphoreN, semaphoreData in pairs(data.semaphores) do
			local id = data.prefixDeviceNames and (self.shortcut .. "_" .. semaphoreN) or semaphoreN
			_Obj:addSemaphore(id, semaphoreData)
		end
	end

	-- Schematic (optional)
	self.schematic = nil
end

---Loads a schematic for this station.
---@param data table The schematic data.
function Station:loadSchematic(data)
	self:tell("Reloading schematic...", Severity.INFO, 3)
	self.schematic = Schematic(self, data)
	self:tell("Schematic reloaded!", Severity.SUCCESS, 3)
end

---Sends an information about this station to the log.
---@param text string The message to be written.
---@param severity Severity The message severity.
---@param weight integer The message weight.
function Station:tell(text, severity, weight)
	_LogWrite(string.format("St:%s: %s", self.shortcut, text), severity, weight)
end

return Station