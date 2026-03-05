local class = require "lua.class"
local Track = require("lua.Track")

---@class Route
local Route = class:derive("Route")

function Route:new(name, data)
	_LogWrite("Creating route: " .. name, 1, 3)
	_Com.initRoute(name)

	self.name = name
	---@type table<string, Track>
	self.tracks = {}

	-- Tracks
	for trackN, trackData in pairs(data.tracks) do
		self.tracks[trackN] = Track(self, trackN, trackData)
	end

	_LogWrite("Created route: " .. name, 3, 2)
end

function Route:init()
	for name, track in pairs(self.tracks) do
		track:init()
	end
end

function Route:tell(text, severity, weight)
	_LogWrite("route: " .. self.name .. ": " .. text, severity, weight)
end

function Route:getTrack(trackN)
	if not self.tracks[trackN] then self:tell("Tried to access a nonexistent track: " .. tostring(trackN), 2, 1) end
	return self.tracks[trackN]
end

return Route