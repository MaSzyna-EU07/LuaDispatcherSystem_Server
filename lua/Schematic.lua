local Class = require("lua.class")
local Tile = require("lua.Tile")
local SchematicIndex = require("lua.SchematicIndex")
local Dispatcher = require("lua.Dispatcher")
local Pathfinder = require("lua.Pathfinder.Pathfinder")
local TrackFollower = require("lua.Pathfinder.TrackFollower")

---Represents a station schematic, comprised of tiles.
---@class Schematic : Class
---@overload fun(shortcut): Schematic
local Schematic = Class:derive("Schematic")

---Creates a new empty schematic.
---To load data from it, call `:reload()` on the created schematic.
---@param shortcut string The schematic shortcut.
function Schematic:new(shortcut)
	_Com.initSchematic(shortcut)
	self.shortcut = shortcut

    self.name = ""
    self.w, self.h = 25, 10
    ---@type Tile[][]
    self.tiles = {}

    self.index = nil
	self.dispatcher = Dispatcher(self)
end

---Reloads this schematic.
---@param data table New schematic data.
function Schematic:reload(data)
	self:tell("Reloading schematic...", Severity.INFO, 3)
	self:deserialize(data)
    self.index = SchematicIndex(self)
	self.index:generateIndex()
	self.index:print()
	self:tell("Schematic reloaded!", Severity.SUCCESS, 3)
	_Com.notify(self.shortcut .. ": Schematic reloaded!")
end

---Returns a tile from this schematic based on coordinates, or `nil` if no tile lies at that location.
---@param x integer X coordinate of the tile.
---@param y integer Y coordinate of the tile.
---@return Tile?
function Schematic:getTile(x, y)
	return self.tiles[x] and self.tiles[x][y]
end

---Returns a tile from this schematic based on coordinates, or throws an error if no tile lies at that location.
---@param x integer X coordinate of the tile.
---@param y integer Y coordinate of the tile.
---@return Tile
function Schematic:assertGetTile(x, y)
	return assert(self:getTile(x, y), string.format("There is no tile at %s:%s,%s", self.shortcut, x, y))
end

---Fills in default next semaphore pointers based on the schematic layout.
---@see SchematicIndex.generateSemaphoreNextDefaults
function Schematic:generateSemaphoreNextDefaults()
	self.index:generateSemaphoreNextDefaults()
end

---Generates blockades originating on this schematic.
function Schematic:generateBlockades()
	self.index:generateBlockades()
end

---Attempts to pathfind between two given tracks on this schematic with the given path mode.
---Returns `true` on success, `false` on failure.
---@param track1 string The ID of the first track to pathfind from. This would usually be a track a train is on.
---@param track2 string The ID of the destination track to pathfind to.
---@param mode PathMode The mode of the dispatching: whether to display a train or a shunting signal.
---@return boolean
function Schematic:pathfind(track1, track2, mode)
	self:tell(string.format("Pathfinding from %s to %s...", track1, track2), Severity.INFO, 1)
	local track1Info = self.index:getTrack(track1)
	local track2Info = self.index:getTrack(track2)
	if not track1Info or not track2Info then
		self:tell("Failed: Not all tracks exist", Severity.FAIL, 1)
		-- If any of the tracks doesn't exist, we're out.
		return false
	end
	local target = mode == PathMode.TRAIN and track2Info.trainTarget or track2Info.shuntTarget
	if not target then
		self:tell("Failed: Target point not found", Severity.FAIL, 1)
		-- We cannot pathfind there.
		return false
	end
	-- Attempt to pathfind from any of the semaphores on the starting track.
	for i, semaphore in ipairs(track1Info.semaphores) do
		self:tell(string.format("Attempting with %s...", semaphore.id), Severity.INFO, 1)
		local tile = self.index:getSemaphore(semaphore.id)
		if tile then
			local result = self:pathfindTiles(tile, target, mode)
			if result then
				-- Hooray! The route has been found and dispatched!
				return true
			end
		end
	end
	self:tell("Failed: Pathfinding failed for all semaphores", Severity.FAIL, 1)
	-- Nothing worked... :(
	return false
end

---Attempts to pathfind between two given tiles on this schematic with the given path mode.
---Returns `true` on success, `false` on failure.
---@param tile1 Tile The first tile to pathfind from. Must be a semaphore tile.
---@param tile2 Tile The destination tile to pathfind to.
---@param mode PathMode The mode of the dispatching: whether to display a train or a shunting signal.
---@return boolean
function Schematic:pathfindTiles(tile1, tile2, mode)
	if not tile1:isSemaphore() then
		-- The first tile must be a semaphore.
		return false
	end
	-- Summon a pathfinder and let it find the path...
	local pathfinder = Pathfinder(tile1, tile2)
	pathfinder:setMode(mode)
	local itineraries = pathfinder:findPathAndGetItineraries()
	if itineraries then
		-- We found a route! Dispatch it and we can start a party
		self:dispatchItineraries(itineraries)
		return true
	end
	-- We didn't find the path...
	return false
end

---Reserves all tracks, sets all switches and displays a clear signal on the semaphore.
---@param itineraries Itinerary[] The list of itineraries to be dispatched.
function Schematic:dispatchItineraries(itineraries)
    local dispatched = 0
    for i, itinerary in ipairs(itineraries) do
        -- Itineraries are dispatched only until the first failing one, so that we aren't left with a partially dispatched route.
        if not itinerary:canBeDispatched() then
            if dispatched == 0 then
                _Com.notify("None of the itineraries could be dispatched... Check log for details.", NotificationColor.RED)
            else
                _Com.notify(string.format("Dispatched only %s out of %s itineraries! Check log for details.", dispatched, #itineraries), NotificationColor.ORANGE)
            end
            return
        end
        itinerary:dispatch()
        dispatched = dispatched + 1
    end
end

---@alias RoutingInfo {traversable: boolean}

---Returns routing information from the specified exit to the specified exit on this schematic.
---Throws an error if an invalid exit is specified.
---@param exitIn string? The inbound exit where the pathfinding starts.
---@param exitOut string The outbound exit where the pathfinding ends.
---@return RoutingInfo
function Schematic:getRoutingInfo(exitIn, exitOut)
	_Log.write(string.format("> Getting route info from %s to %s", exitIn, exitOut))
	-- TODO: Write this again, but not in a half-assed way.
	if not exitIn then
		return {traversable = true}
	end
	local tileIn = assert(self.index:getExit(exitIn), "Could not find tile for exit " .. tostring(exitIn))
	local tileOut = assert(self.index:getExit(exitOut), "Could not find tile for exit " .. tostring(exitOut))
	--_Log.write(string.format("> Tiles: %s -> %s, %s -> %s", exitIn, tileIn:getLocation(), exitOut, tileOut:getLocation()))
	-- Move the first tile to the entry semaphore.
	local exitDir = tileIn:getWarpExitDirection()
	if not exitDir then
		return {traversable = false}
	end
	local start = assert(tileIn:getNeighbor(exitDir))
	--_Log.write(string.format("> Starting from tile %s", start:getLocation()))
	local follower = TrackFollower(start, exitDir)
	if not (start:isSemaphore() and start:getSemaphoreDirection() == follower.direction) then
		follower:stepUntil(function(tile) return tile:isSemaphore() and tile:getSemaphoreDirection() == follower.direction end)
	end
	--_Log.write(string.format("> Found entrance semaphore %s at %s", follower.tile.semaphoreID, follower.tile:getLocation()))
	local pathfinder = Pathfinder(follower.tile, tileOut)
	local path = pathfinder:findPath()
	return {traversable = path ~= nil}
end

---Sends an information about this schematic to the log.
---@param text string The message to be written.
---@param severity Severity The message severity.
---@param weight integer The message weight.
function Schematic:tell(text, severity, weight)
	_Log.write(string.format("%s: %s", self.shortcut, text), severity, weight)
end

---Deserializes the schematic data loaded from a file.
---@param t table The saved data.
function Schematic:deserialize(t)
	self.name = t.name
	-- The shortcut is deliberately omitted as it could cause desynchronization and other bad things! It's constant anyway lol
	self.w, self.h = t.w, t.h
	self.tiles = {}
	for x = 1, self.w do
		self.tiles[x] = {}
		for y = 1, self.h do
			local tile = Tile(self, x, y)
			tile:deserialize(t.tiles[tostring(x) .. "," .. tostring(y)])
			self.tiles[x][y] = tile
		end
	end
end

return Schematic