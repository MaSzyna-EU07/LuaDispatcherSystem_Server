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

-- Prepare the functions once for all switches.
-- Each `api.event_preparefunc` call creates a new FFI callback, and only so many can be defined.
local forced0 = _API:eventPrepareFunction(function(event, activator) _Obj:getSwitchFromEvent(event):forceState(true) end)
local forced1 = _API:eventPrepareFunction(function(event, activator) _Obj:getSwitchFromEvent(event):forceState(false) end)

---Initializes callbacks which listen for the changes in the simulator.
function Switch:init()
	_LogWrite("Creating switch: " .. self.id, Severity.INFO, 3)
	_LogWrite("- Creating event callbacks...", Severity.INFO, 3)
	_API:eventCreate(string.lower(self.id) .. ":forced-", 0, 0, forced0)
	_API:eventCreate(string.lower(self.id) .. ":forced+", 0, 0, forced1)
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
		_API:eventDispatch(string.lower(self.id) .. _SwitchChar(self.state))
	end
	_Com.setSwitch(self.id, self.state, self.forced)
end

return Switch