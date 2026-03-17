local Class = require("lua.class")
local api = require "eu07.events"

---@class Objects : Class
---@overload fun(): Objects
local Objects = Class:derive("Objects")

function Objects:new()
    ---@type table<string, Station>
    self.stations = {}
    ---@type table<string, Route>
    self.routes = {}
    -- Keys for `tracks`, `switches` and `semaphores` are guaranteed to be lowercase.
    ---@type table<string, Track>
    self.tracks = {}
    ---@type table<string, Switch>
    self.switches = {}
    ---@type table<string, Semaphore>
    self.semaphores = {}
end

---Adds a station to the station list. The index is the station name, e.g. "Eb".
---@param station Station The station to be added.
function Objects:addStation(station)
    self.stations[station.name] = station
end

---Adds a route to the route list. The index is the route name, e.g. "Eb-Tp".
---@param route Route The route to be added.
function Objects:addRoute(route)
    self.routes[route.name] = route
end

---Adds a track to the track list. The index is the track ID, converted to lowercase, e.g. "Eb_It2" -> "eb_it2".
---@param track Track The track to be added.
function Objects:addTrack(track)
    self.tracks[string.lower(track.id)] = track
end

---Adds a switch to the switch list. The index is the switch ID, converted to lowercase, e.g. "Eb_25ab" -> "eb_25ab".
---@param switch Switch The switch to be added.
function Objects:addSwitch(switch)
    self.switches[string.lower(switch.id)] = switch
end

---Adds a semaphore to the semaphore list. The index is the semaphore ID, converted to lowercase, e.g. "Eb_A" -> "eb_a".
---@param semaphore Semaphore The semaphore to be added.
function Objects:addSemaphore(semaphore)
    self.semaphores[string.lower(semaphore.id)] = semaphore
end

---Returns a Station based on its simulation name (shortcut), or `nil` if it's not found.
---@param name string Station shortcut.
---@return Station?
function Objects:getStation(name)
	if not self.stations[name] then
		_LogWrite("Tried to access a nonexistent station: " .. tostring(name), 2, 1)
	end
	return self.stations[name]
end

---Returns a Route based on its simulation name (shortcut), or `nil` if it's not found.
---@param name string Route shortcut.
---@return Route?
function Objects:getRoute(name)
	if not self.routes[name] then
		_LogWrite("Tried to access a nonexistent route: " .. tostring(name), 2, 1)
	end
	return self.routes[name]
end

---Returns a Station or Route based on its simulation name (shortcut), or `nil` if it's not found.
---@param name string Station or route shortcut.
---@return Station|Route?
function Objects:getStationOrRoute(name)
	local result = self.stations[name] or self.routes[name]
	if not result then
		_LogWrite("Tried to access a nonexistent station/route: " .. tostring(name), 2, 1)
	end
	return result
end

---Returns a Track based on its simulation name, or `nil` if it is not found.
---@param name string For example: `"Eb_It2"`. Case-insensitive.
---@return Track?
function Objects:getTrack(name)
	name = string.lower(name)
	if not self.tracks[name] then
		_LogWrite("Tried to access an invalid track: " .. tostring(name), 2, 1)
	end
	return self.tracks[name]
end

---Returns a Switch based on its simulation name, or `nil` if it is not found.
---@param name string For example: `"Eb_39"`. Case-insensitive.
---@return Switch?
function Objects:getSwitch(name)
	name = string.lower(name)
	if not self.switches[name] then
		_LogWrite("Tried to access an invalid switch: " .. tostring(name), 2, 1)
	end
	return self.switches[name]
end

---Returns a Semaphore based on its simulation name, or `nil` if it is not found.
---@param name string For example: `"Eb_A"`. Case-insensitive.
---@return Semaphore?
function Objects:getSemaphore(name)
	name = string.lower(name)
	if not self.semaphores[name] then
		_LogWrite("Tried to access an invalid semaphore: " .. tostring(name), 2, 1)
	end
	return self.semaphores[name]
end

---Returns a Track based on its event, or `nil` if it is not found.
---@param event TEvent* The event from `api.event_preparefunc`.
---@return Track?
function Objects:getTrackFromEvent(event)
	local name = api.event_getname(event)
	return self:getTrack(name:sub(1, name:find(":") - 1))
end

---Returns a Switch based on its event, or `nil` if it is not found.
---@param event TEvent* The event from `api.event_preparefunc`.
---@return Switch?
function Objects:getSwitchFromEvent(event)
	local name = api.event_getname(event)
	return self:getSwitch(name:sub(1, name:find(":") - 1))
end

---Returns a Semaphore based on its event, or `nil` if it is not found.
---@param event TEvent* The event from `api.event_preparefunc`.
---@return Semaphore?
function Objects:getSemaphoreFromEvent(event)
	local name = api.event_getname(event)
    -- We are splitting at the second underscore, because the ID is always <station_id>_<semaphore_id>, for exmaple `eb_a` and `eb_szn1`.
    -- The event suffixes can have additional underscores, such as `bc_p_sr1` vs `bc_p_sygsz_wyg90`.
	return self:getSemaphore(name:sub(1, name:find("_", name:find("_") + 1) - 1))
end

return Objects