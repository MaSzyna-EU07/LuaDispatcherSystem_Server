local class = require "lua.class"
local Blockade = require("lua.Blockade")

---@class Route
local Route = class:derive("Route")

---Creates a Route.
---@param shortcut string The route shortcut.
---@param data table? Data for the route.
function Route:new(shortcut, data)
	_LogWrite("Creating route: " .. shortcut, Severity.INFO, 3)
	_Com.initRoute(shortcut)

	self.shortcut = shortcut

	---@type Blockade[]
	self.blockades = {}
	if data then
		-- Tracks
		for i, trackN in ipairs(data.tracks) do
			_Obj:addTrack(trackN)
		end
		-- Semaphores
		if data.semaphores then
			for semaphoreN, semaphoreData in pairs(data.semaphores) do
				_Obj:addSemaphore(semaphoreN, semaphoreData)
			end
		end
		-- Blockades
		if data.blockades then
			for i, blockade in ipairs(data.blockades) do
				self.blockades[i] = Blockade(self, blockade)
			end
		end
	end

	_LogWrite("Created route: " .. shortcut, Severity.SUCCESS, 2)
end

---Initializes the blockades for this route.
function Route:init()
	for i, blockade in ipairs(self.blockades) do
		blockade:init()
	end
end

function Route:tell(text, severity, weight)
	_LogWrite("route: " .. self.shortcut .. ": " .. text, severity, weight)
end

---Returns tne n-th blockade on this route, or `nil` if it does not exist.
---@param n integer The blockade index.
---@return Blockade?
function Route:getBlockade(n)
	return self.blockades[n]
end

return Route