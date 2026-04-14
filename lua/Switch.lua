local class = require "lua.class"

---@class Switch
local Switch = class:derive("Switch")

---Creates a switch.
---@param id string Full switch name, e.g. `"sta1_3"`.
function Switch:new(id)
	_Com.initSwitch(id)

	self.id = id
	self.state = false
	self.forced = false

	self:init()
end

---Initializes callbacks which listen for the changes in the simulator.
function Switch:init()
	_LogWrite("Creating switch: " .. self.id, Severity.INFO, 3)
	_LogWrite("- Creating event callbacks...", Severity.INFO, 3)
	_API:eventCreate(string.lower(self.id) .. ":forced-", 0, 0, function() self:forceState(true) end)
	_API:eventCreate(string.lower(self.id) .. ":forced+", 0, 0, function() self:forceState(false) end)
	_LogWrite("Created switch: " .. self.id, Severity.SUCCESS, 2)
end

function Switch:__tostring()
	return string.format("J[%s : state=%s forced=%s]", self.id, self.state, self.forced)
end

---Sends an information about this switch to the log.
---@param text string The message.
---@param severity Severity Severity.
---@param weight integer Weight.
function Switch:tell(text, severity, weight)
	_LogWrite(tostring(self.id) .. ": " .. text, severity, weight)
end

---Sets the Switch state.
---@param state boolean `true` for `+`, `false` for `-`.
function Switch:setState(state)
	self.state = state
	self:tell("state=>"..tostring(state), Severity.INFO, 3)
	self:refreshSim()
end

function Switch:setForced(forced)
	self.forced = forced
	self:tell("forced=>"..tostring(forced), Severity.INFO, 3)
	self:refreshSim()
end

function Switch:forceState(state)
	self.state = state
	self:setForced(true)
end

function Switch:refreshSim()
	if not self.forced then
		_API:eventDispatch(string.lower(self.id) .. (self.state and "-" or "+"))
	end
	_Com.setSwitch(self.id, self.state, self.forced)
end

return Switch