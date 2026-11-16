local Class = require("lua.class")
local TrackFollower = require("lua.Pathfinder.TrackFollower")
local Itinerary = require("lua.Pathfinder.Itinerary")

---@class Pathfinder : Class
---@overload fun(start: Tile, target: Tile): Pathfinder
local Pathfinder = Class:derive("Pathfinder")

---Creates a new Pathfinder.
---@param start Tile The starting tile.
---@param target Tile The tile to target.
function Pathfinder:new(start, target)
    self.start = start
    self.target = target
    self.speed = 160
    self.mode = PathMode.TRAIN
    self.electrified = false

    -- TODO: Incorporate this for faster lowest cost search?
    self.possibilitySortFn = function(a, b) return a.cost < b.cost end

    -- Total cost is calculated like this: `total = base * speedPenaltyMult + heuristic`
    ---@type table<Tile, {cost: {base: number, speedPenaltyMult: number, heuristic: number, total: number}, explored: boolean, speed: integer, dirFrom: integer}>
    self.tiles = {}

    self:createInitialPossibility()
end

---Sets the dispatching mode for this Pathfinder. This affects the possible paths and the displayed signal.
---@param mode PathMode The mode to be set.
function Pathfinder:setMode(mode)
    self.mode = mode
end

---Sets whether this Pathfinder is for an electric train. If so, it will not pathfind through non-electrified tiles.
---@param electrified boolean The electrification mode to be set.
function Pathfinder:setElectrified(electrified)
    self.electrified = electrified
end

---Creates the initial possibility starting from this Pathfinder's first tile.
---@private
function Pathfinder:createInitialPossibility()
    assert(_Utils.tableIsEmpty(self.tiles), "Attempted to create initial possibilities for a non-empty pathfinder!")
    local dirFrom = assert(self.start:getSemaphoreDirection(), "First tile must be a semaphore! (if you're reading this that means it isn't lol)")
    self.tiles[self.start] = {cost = {base = 0, speedPenaltyMult = 1, heuristic = self:getHeuristic(self.start), total = self:getHeuristic(self.start)}, explored = false, speed = math.huge, dirFrom = _Dir.invertDir(dirFrom)}
end

---Does a single step of the pathfinding procedure.
---Returns `true` if we've found the target tile, `false` if there are no tiles left to explore, and `nil` if the pathfinder should keep going.
---@return boolean?
function Pathfinder:findPathStep()
    -- Find the unexplored tile with the lowest cost and explore it.
    -- TODO: Separate the queue?
    local tile = self:getNextUnexploredTile()
    if not tile then
        return false
    end
    self:exploreTile(tile)
    if tile == self.target then
        return true
    end
end

---Finds the best path considering the constraints.
---Returns the path if it has been found, `nil` otherwise.
---Throws an error after 100,000 iterations, which means there's a very possible infinite loop.
---@return Path?
function Pathfinder:findPath()
    local n = 0
    while true do
        local result = self:findPathStep()
        if result == false then
            _Log.write("Path not found!", Severity.FAIL, 1)
            return
        elseif result == true then
            _Log.write("Path found!", Severity.SUCCESS, 1)
            break
        end
        -- Infinite loop check
        n = n + 1
        assert(n < 100000, "Pathfinder took too long!!!")
    end

    -- If we've got here, we've found the path !!
    local path = assert(self:getPath(self.target))
    _Log.write("Path found:", Severity.SUCCESS, 1)
    for i, node in ipairs(path) do
        _Log.write(string.format("    %s: pos=%s,%s dirs=%s,%s", i, node.tile.x, node.tile.y, node.dir1, node.dir2), Severity.SUCCESS, 1)
    end
    return path
end

---Explores the possibilities for the specified tile and registers new tiles if anything new is found.
---If this tile is not in the tile list or is marked as already explored, returns without doing anything.
---@param tile Tile The tile to be explored.
function Pathfinder:exploreTile(tile)
    local entry = self.tiles[tile]
    if not entry then
        return
    end
    -- Get all directions we can go towards
    local directions = tile:getPossibleTrackDirections(entry.dirFrom)
    for i, direction in ipairs(directions) do
        local nextTile = tile:getNeighbor(direction)
        if nextTile and self:canEnterTile(nextTile) then
            -- For each neighbor tile that exists, make a new entry to fill stuff into.
            local nextEntry = {
                cost = {base = entry.cost.base, speedPenaltyMult = entry.cost.speedPenaltyMult, heuristic = self:getHeuristic(nextTile), total = nil},
                explored = false,
                speed = entry.speed,
                dirFrom = _Dir.invertDir(direction)
            }
            -- Add a base cost.
            if nextTile:isDoubleSwitch() then
                nextEntry.cost.base = nextEntry.cost.base + 4
            elseif nextTile:isSwitch() then
                nextEntry.cost.base = nextEntry.cost.base + 4
            else
                nextEntry.cost.base = nextEntry.cost.base + 1
            end
            -- Check the maximum speed for the PREVIOUS tile, as we don't know where we'll go from the tile we are stepping on.
            local speed = tile:getSpeedForDirections(entry.dirFrom, direction)
            -- Check if that's a reduction from the currently known maximum speed. If so, incur a penalty.
            if speed < entry.speed then
                _Log.write(string.format("Tile %s reduces speed from %s to %s", tile:getLocation(), entry.speed, speed))
                nextEntry.cost.speedPenaltyMult = entry.speed and math.max(self.speed / entry.speed, 1) or 1
                nextEntry.speed = speed
            end
            -- Also check if we will reset the maximum speed on this tile, if it's a new semaphore tile.
            if nextTile:isSemaphore() and nextTile:getSemaphoreDirection() == direction and (self.mode == PathMode.SHUNT or nextTile.semaphoreType ~= SemaphoreType.TM) then
                nextEntry.speed = math.huge
            end
            -- Calculate the total cost.
            nextEntry.cost.total = nextEntry.cost.base * nextEntry.cost.speedPenaltyMult + nextEntry.cost.heuristic
            -- Check if we've already been on that tile.
            -- In such case, only consider the less costly option. In other words, if we've just discovered a less optimal option, discard it.
            if not self.tiles[nextTile] or nextEntry.cost.total < self.tiles[nextTile].cost.total then
                self.tiles[nextTile] = nextEntry
            end
        end
    end
    -- This entry has been explored. That's it.
    entry.explored = true
end

---Returns the heuristic cost for the specified tile for this pathfinder.
---@private
---@param tile Tile The tile for which to calculate the heuristic.
---@return number
function Pathfinder:getHeuristic(tile)
    local dx, dy = math.abs(self.target.x - tile.x), math.abs(self.target.y - tile.y)
    return (dx + dy) * 2
end

---Returns the next unexplored tile with the lowest cost.
---If there are no tiles to explore left, returns `nil`.
---@private
---@return Tile?
function Pathfinder:getNextUnexploredTile()
    local lowest = nil
    for tile, entry in pairs(self.tiles) do
        if not entry.explored and (not lowest or entry.cost.total < self.tiles[lowest].cost.total) then
            lowest = tile
        end
    end
    return lowest
end

---Returns whether this Pathfinder can enter the specified tile.
---@private
---@param tile Tile The tile to be entered.
---@param prevTile Tile? The previous tile that this tile is entered from.
---@return boolean
function Pathfinder:canEnterTile(tile, prevTile)
    if tile:isEmpty() then
        -- We've reached a desert.
        _Log.write(string.format("At %s: Empty tile!", tile:getLocation()))
        return false
    end
    if self.mode == PathMode.TRAIN and tile:isTrackClear() == false then
        -- The track is for sure occupied when in train mode.
        _Log.write(string.format("At %s: Track occupied!", tile:getLocation()))
        return false
    elseif self.mode == PathMode.SHUNT and tile:isTrackClear() and prevTile and prevTile:isTrackClear() == false then
        -- We went past the occupied segment when shunting. Unfortunately current technology doesn't permit us to jump over a train...
        _Log.write(string.format("At %s: Went past a train in shunting mode!", tile:getLocation()))
        return false
    end
    if not tile:isPathModeAllowed(self.mode) then
        -- The track is not allowing this dispatching mode (i.e. forbids shunting or trains)
        _Log.write(string.format("At %s: Mode forbidden!", tile:getLocation()))
        return false
    end
    if self.electrified and not tile.electrified then
        -- The track is not electrified while pathfinding for an electric train.
        _Log.write(string.format("At %s: Not electrified!", tile:getLocation()))
        return false
    end
    return true
end

---Returns the already calculated path from the following tile.
---Returns `nil` if the specified tile hasn't been explored and as such found a way to.
---@param tile Tile The tile to be calculated from.
---@return Path?
function Pathfinder:getPath(tile)
    if not self.tiles[tile] then
        return
    end
    -- Work our way backwards.
    ---@type Path
    local path = {}
    local curTile = tile
    while true do
        table.insert(path, 1, {tile = curTile, dir1 = self.tiles[curTile].dirFrom, dir2 = path[1] and _Dir.invertDir(path[1].dir1)})
        if curTile == self.start then
            break
        end
        curTile = assert(curTile:getNeighbor(self.tiles[curTile].dirFrom))
    end
    return path
end

---Extends the specified path to the next semaphore.
---@param path Path The path to be extended.
function Pathfinder:extendPath(path)
    local follower = TrackFollower(path[#path].tile, _Dir.invertDir(path[#path].dir1))
    follower:setPathRecording(true)
    follower:stepUntil(function(tile) return tile ~= self.start and tile:isSemaphore() and (tile:getSemaphoreDirection() == follower.direction or (self.mode == PathMode.SHUNT and not tile.semaphoreAllowShunt and tile:getSemaphoreDirection() ~= follower.direction)) end)
    -- Add the traversed tiles to the path.
    for i, node in ipairs(follower:getPath()) do
        _Log.write(string.format("%s : %s,%s", node.tile:getLocation(), node.dir1 or "-", node.dir2 or "-"))
        if i == 1 then
            path[#path].dir2 = node.dir2
        else
            table.insert(path, node)
        end
    end
end

---Generates a list of itineraries based on the specified path.
---The path should be extended with `:extendPath()` first.
---@param path Path The path that will be turned into itineraries.
---@return Itinerary[]
function Pathfinder:getItineraries(path)
    ---@type Itinerary[]
    local itineraries = {}
    -- Iterate through all tiles.
    for i, node in ipairs(path) do
        local boundary = node.tile:isSemaphore() and node.tile:getSemaphoreDirection() == node.dir2 and (self.mode == PathMode.SHUNT or node.tile.semaphoreType ~= SemaphoreType.TM)
        -- If we are at the end of an itinerary, the previous itinerary gets its next semaphore assigned.
        if (boundary or i == #path) and i > 1 then
            itineraries[#itineraries]:setNext(not node.tile.semaphoreOwnShield and node.tile.semaphoreID or (node.tile:isBuffer() and 0 or math.huge))
            _Com.highlightTile(node.tile.schematic.shortcut, node.tile.x, node.tile.y, 1)
        end
        -- Make a new itinerary if we have crossed an itinerary boundary (a semaphore).
        if boundary and i < #path then
            table.insert(itineraries, Itinerary())
        end
        local itinerary = assert(itineraries[#itineraries], "First tile is not a valid tile for an itinerary! Must be a semaphore!")
        -- Determine which tracks should be reserved.
        if i < #path then
            local track = node.tile.trackID
            if track then
                itinerary:addTrack(track)
            end
        end
        -- Check if we have to consider a switch state on this tile.
        local switchStates = node.tile:getSwitchStatesForDirections(node.dir1, node.dir2)
        for suffix, state in pairs(switchStates) do
            if node.tile.switchID then
                itinerary:addSwitch(node.tile.switchID .. suffix, state, node.tile.trackID)
            else
                _Log.write(string.format("WARNING: Tile at %s does not have a switch ID - switch skipped!", node.tile:getLocation()))
            end
        end
        -- Check if we are going through a W24 tile.
        if node.tile.targetW24 then
            itinerary:setW24(true)
        end
        -- First tile determines the semaphore.
        if boundary then
            itinerary:setSemaphore(assert(node.tile.semaphoreID, "Missing semaphore on starting tile!"))
            if self.mode == PathMode.TRAIN then
                itinerary:setSpeed(node.tile.semaphoreAllowTrain and math.huge or Speed.SZ)
            elseif self.mode == PathMode.SHUNT then
                itinerary:setSpeed(Speed.MS2)
            end
        end
        -- Decrease the speed if necessary.
        itinerary:decreaseSpeed(node.tile:getSpeedForDirections(node.dir1, node.dir2))
    end
    return itineraries
end

---Combines `:findPath()`, `:extendPath()` and `:getItineraries()` into one function.
---Call this if you want to grab a list of itineraries straight up from this pathfinder.
---Returns `nil` if the pathfinding fails.
---@return Itinerary[]?
function Pathfinder:findPathAndGetItineraries()
	local path = self:findPath()
	if not path then
		return
	end
	self:extendPath(path)
    return self:getItineraries(path)
end

return Pathfinder