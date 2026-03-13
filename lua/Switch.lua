local class = require "lua.class"
local api = require "eu07.events"

---@class Switch
local Switch = class:derive("Switch")

function Switch:new(station, id)
	_Com.initSwitch(station.name, id)

	self.station = station
	self.id = id
	self.state = false
	self.forced = false

	self:init()
end

---Initializes callbacks which listen for the changes in the simulator.
function Switch:init()
	_LogWrite("Creating switch: " .. self.id, 1, 3)
	_LogWrite("- Creating event callbacks...", 1, 3)
	api.event_create(string.lower(self.id) .. ":forced-", 0, 0, api.event_preparefunc(function(event, activator) self:forceState(true) end))
	api.event_create(string.lower(self.id) .. ":forced+", 0, 0, api.event_preparefunc(function(event, activator) self:forceState(false) end))
	_LogWrite("Created switch: " .. self.id, 3, 2)
end

function Switch:__tostring()
	return string.format("%s : state=%s forced=%s", self.id, self.state, self.forced)
end

function Switch:tell(text, severity, weight)
	_LogWrite(tostring(self.id) .. ": " .. text, severity, weight)
end

function Switch:setState(state)
	self.state = state
	self:tell("state=>"..tostring(state), 1, 3)
	self:refreshSim()
end

function Switch:setForced(forced)
	self.forced = forced
	self:tell("forced=>"..tostring(forced), 1, 3)
	self:refreshSim()
end

function Switch:forceState(state)
	self.state = state
	self:setForced(true)
end

function Switch:refreshSim()
	if not self.forced then
		api.event_dispatch_n(string.lower(self.id) .. _SwitchChar(self.state), nil, 0)
	end
	_Com.setSwitch(self.id, self.state, self.forced)
end

return Switch