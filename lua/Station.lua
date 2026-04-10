local class = require "lua.class"
local Schematic = require("lua.Schematic")

---@class Station
local Station = class:derive("Station")

---Creates a Station.
---@param shortcut string The station shortcut.
function Station:new(shortcut)
	_Com.initStation(shortcut)
	self.shortcut = shortcut
	-- Schematic (required if the station has any devices)
	self.schematic = nil
end

---Loads a schematic for this station.
---@param data table The schematic data.
function Station:loadSchematic(data)
	self:tell("Reloading schematic...", Severity.INFO, 3)
	self.schematic = Schematic(self, data)
	self:tell("Schematic reloaded!", Severity.SUCCESS, 3)
	_Com.notify(self.shortcut .. ": Schematic reloaded!")
	self.schematic.index:print()
end

---Sends an information about this station to the log.
---@param text string The message to be written.
---@param severity Severity The message severity.
---@param weight integer The message weight.
function Station:tell(text, severity, weight)
	_LogWrite(string.format("%s: %s", self.shortcut, text), severity, weight)
end

return Station