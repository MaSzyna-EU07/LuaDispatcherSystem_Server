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
function Objects:addStation(id)
    self.stations[id] = Station(id)
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
	return _Utils.tableGetSortedKeys(self.tracks)
end

---Returns a list of switch IDs, sorted alphabetically.
---@return string[]
function Objects:getSwitchList()
	return _Utils.tableGetSortedKeys(self.switches)
end

---Returns a list of semaphore IDs, sorted alphabetically.
---@return string[]
function Objects:getSemaphoreList()
	return _Utils.tableGetSortedKeys(self.semaphores)
end

-- The following are simplified state objects which are used both in the client and in the server.

---@alias TrackState {occupied: boolean, reserved: boolean}
---@alias SwitchState {state: boolean, forced: boolean}
---@alias SemaphoreState {speed: Speed, nextSpeed: Speed, image: string}

---Returns the track state, or `nil` if the provided track doesn't exist.
---@param name string The full track ID.
---@return TrackState?
function Objects:getTrackState(name)
    return self:getTrack(name)
end

---Returns the switch state, or `nil` if the provided switch doesn't exist.
---@param name string The full switch ID.
---@return SwitchState?
function Objects:getSwitchState(name)
    return self:getSwitch(name)
end

---Returns the semaphore state, or `nil` if the provided semaphore doesn't exist.
---@param name string The full semaphore ID.
---@return SemaphoreState?
function Objects:getSemaphoreState(name)
    local semaphore = self:getSemaphore(name)
    return semaphore and semaphore:getState()
end

return Objects