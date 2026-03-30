local Class = require("lua.class")
local Station = require("lua.Station")
local Route = require("lua.Route")
local Track = require("lua.Track")
local Switch = require("lua.Switch")
local Semaphore = require("lua.Semaphore")

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
---@param id string The station ID (shortcut).
---@param data table? The station data. If `nil`, the intiialized station will not have any data.
function Objects:addStation(id, data)
    self.stations[id] = Station(id, data)
end

---Adds a route to the route list. The index is the route name, e.g. "Eb-Tp".
---@param id string The route ID (shortcut).
---@param data table The route data.
function Objects:addRoute(id, data)
    self.routes[id] = Route(id, data)
end

---Adds a track to the track list. The index is the track ID, converted to lowercase, e.g. "Eb_It2" -> "eb_it2".
---@param id string The track ID.
function Objects:addTrack(id)
    self.tracks[string.lower(id)] = Track(id)
end

---Adds a switch to the switch list. The index is the switch ID, converted to lowercase, e.g. "Eb_25ab" -> "eb_25ab".
---@param id string The switch ID.
function Objects:addSwitch(id)
    self.switches[string.lower(id)] = Switch(id)
end

---Adds a semaphore to the semaphore list. The index is the semaphore ID, converted to lowercase, e.g. "Eb_A" -> "eb_a".
---@param id string The semaphore ID.
---@param data table The semaphore data.
function Objects:addSemaphore(id, data)
    self.semaphores[string.lower(id)] = Semaphore(id, data)
end

---Returns a Station based on its simulation name (shortcut), or `nil` if it's not found.
---@param name string Station shortcut.
---@return Station?
function Objects:getStation(name)
	return self.stations[name]
end

---Returns a Station based on its simulation name (shortcut), or throws an error if it's not found.
---@param name string Station shortcut.
---@return Station
function Objects:assertGetStation(name)
	return assert(self:getStation(name), "Tried to access a nonexistent station: " .. tostring(name))
end

---Returns a Route based on its simulation name (shortcut), or `nil` if it's not found.
---@param name string Route shortcut.
---@return Route?
function Objects:getRoute(name)
	return self.routes[name]
end

---Returns a Route based on its simulation name (shortcut), or throws an error if it's not found.
---@param name string Route shortcut.
---@return Route
function Objects:assertGetRoute(name)
	return assert(self:getRoute(name), "Tried to access a nonexistent route: " .. tostring(name))
end

---Returns a Station or Route based on its simulation name (shortcut), or `nil` if it's not found.
---@param name string Station or route shortcut.
---@return Station|Route?
function Objects:getStationOrRoute(name)
	return self.stations[name] or self.routes[name]
end

---Returns a Station or Route based on its simulation name (shortcut), or throws an error if it's not found.
---@param name string Station or route shortcut.
---@return Station|Route
function Objects:assertGetStationOrRoute(name)
	return assert(self:getStationOrRoute(name), "Tried to access a nonexistent station/route: " .. tostring(name))
end

---Returns a Track based on its simulation name, or `nil` if it is not found.
---@param name string For example: `"Eb_It2"`. Case-insensitive.
---@return Track?
function Objects:getTrack(name)
	return self.tracks[string.lower(name)]
end

---Returns a Track based on its simulation name, or throws an error if it is not found.
---@param name string For example: `"Eb_It2"`. Case-insensitive.
---@return Track
function Objects:assertGetTrack(name)
	return assert(self:getTrack(name), "Tried to access an invalid track: " .. tostring(name):lower())
end

---Returns a Switch based on its simulation name, or `nil` if it is not found.
---@param name string For example: `"Eb_39"`. Case-insensitive.
---@return Switch?
function Objects:getSwitch(name)
	return self.switches[string.lower(name)]
end

---Returns a Switch based on its simulation name, or throws an error if it is not found.
---@param name string For example: `"Eb_39"`. Case-insensitive.
---@return Switch
function Objects:assertGetSwitch(name)
	return assert(self:getSwitch(name), "Tried to access an invalid switch: " .. tostring(name):lower())
end

---Returns a Semaphore based on its simulation name, or `nil` if it is not found.
---@param name string For example: `"Eb_A"`. Case-insensitive.
---@return Semaphore?
function Objects:getSemaphore(name)
	return self.semaphores[string.lower(name)]
end

---Returns a Semaphore based on its simulation name, or throws an error if it is not found.
---@param name string For example: `"Eb_A"`. Case-insensitive.
---@return Semaphore
function Objects:assertGetSemaphore(name)
	return assert(self:getSemaphore(name), "Tried to access an invalid semaphore: " .. tostring(name):lower())
end

---Returns a list of track IDs, sorted alphabetically.
---@return string[]
function Objects:getTrackList()
	return _TableGetSortedKeys(self.tracks)
end

---Returns a list of switch IDs, sorted alphabetically.
---@return string[]
function Objects:getSwitchList()
	return _TableGetSortedKeys(self.switches)
end

---Returns a list of semaphore IDs, sorted alphabetically.
---@return string[]
function Objects:getSemaphoreList()
	return _TableGetSortedKeys(self.semaphores)
end

---Returns a Track based on its event, or `nil` if it is not found.
---@param event TEvent* The event from `api.event_preparefunc`.
---@return Track?
function Objects:getTrackFromEvent(event)
	local name = _API:eventGetName(event)
	return self:getTrack(name:sub(1, name:find(":") - 1))
end

---Returns a Switch based on its event, or `nil` if it is not found.
---@param event TEvent* The event from `api.event_preparefunc`.
---@return Switch?
function Objects:getSwitchFromEvent(event)
	local name = _API:eventGetName(event)
	return self:getSwitch(name:sub(1, name:find(":") - 1))
end

---Returns a Semaphore based on its event, or `nil` if it is not found.
---@param event TEvent* The event from `api.event_preparefunc`.
---@return Semaphore?
function Objects:getSemaphoreFromEvent(event)
	local name = _API:eventGetName(event)
    -- I wish we could split at the second underscore, because the ID should always be <station_id>_<semaphore_id>, for exmaple `eb_a` and `eb_szn1`.
	-- But this is not always the case, so we will do very dirty stuff here. Kinky, even.
	-- Check for any suffixes. I wonder if this will crash in the future if I add something new to Semaphore.lua and forget to add it here too.
    -- The event suffixes can have additional underscores, such as `bc_p_sr1` vs `bc_p_sygsz_wyg90`.
	local doubleUnderscore = _StrEndsWith(name, "_sygsz_wyg90") or _StrEndsWith(name, "_wyg_sz")
	local underscores = {}
	while true do
		local pos = name:find("_", (underscores[#underscores] or 0) + 1)
		if not pos then
			break
		end
		table.insert(underscores, pos)
	end
	return self:getSemaphore(name:sub(1, underscores[#underscores - (doubleUnderscore and 1 or 0)] - 1))
end

return Objects