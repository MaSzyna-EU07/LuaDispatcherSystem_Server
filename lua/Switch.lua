local class = require "lua.class"
local api = require "eu07.events"

---@class Switch
local Switch = class:derive("Switch")

function Switch:new(station, id)
	_Com.initSwitch(station.name, id)

	self.station = station
	self.id = id
	self.state = false
end

---Connects this object to other objects in the world and to the simulator.
function Switch:init()
	_LogWrite("Creating switch: " .. self.id, 1, 3)
	_LogWrite("Created switch: " .. self.id, 3, 2)
end

function Switch.__tostring(o)
	return tostring(o.id).." : state="..tostring(o.state)
end

function Switch:tell(text, severity, weight)
	_LogWrite(tostring(self.id) .. ": " .. text, severity, weight)
end

function Switch:setState(state)
	self.state = state
	self:tell("state=>"..tostring(state), 1, 3)
	self:refreshSim()
end

function Switch:refreshSim()
	api.event_dispatch_n(string.lower(self.id) .. _SwitchChar(self.state), nil, 0)
	_Com.setSwitch(self.id, self.state)
end

return Switch