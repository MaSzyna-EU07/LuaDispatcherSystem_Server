local class = require "lua.class"
local Track = require("lua.Track")

---@class Route
local Route = class:derive("Route")

function Route:new(name, data)
	_LogWrite("Creating route: " .. name, 1, 3)
	_Com.initRoute(name)

	self.name = name

	-- Tracks
	for i, trackN in ipairs(data.tracks) do
		_Obj:addTrack(Track(self, trackN))
	end

	_LogWrite("Created route: " .. name, 3, 2)
end

function Route:tell(text, severity, weight)
	_LogWrite("route: " .. self.name .. ": " .. text, severity, weight)
end

return Route