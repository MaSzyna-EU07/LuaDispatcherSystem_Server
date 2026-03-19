local class = require "lua.class"
local Track = require("lua.Track")
local Semaphore = require("lua.Semaphore")
local Blockade = require("lua.Blockade")

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
	-- Semaphores
	if data.semaphores then
		for semaphoreN, semaphoreData in pairs(data.semaphores) do
			_Obj:addSemaphore(Semaphore(self, semaphoreN, semaphoreData))
		end
	end
	-- Blockades
	self.blockades = {}
	if data.blockades then
		for i, blockade in ipairs(data.blockades) do
			self.blockades[i] = Blockade(self, blockade)
		end
	end

	_LogWrite("Created route: " .. name, 3, 2)
end

function Route:tell(text, severity, weight)
	_LogWrite("route: " .. self.name .. ": " .. text, severity, weight)
end

return Route