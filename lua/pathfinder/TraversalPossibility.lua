local Class = require("lua.class")
local Itinerary = require("lua.pathfinder.Itinerary")

---Helper class for the Pathfinder. Represents a single possibility of going somewhere.
---Each possibility remembers its full path from the start.
---A possibility can be dead (violating the constraints) or winning (reached its target).
---@class TraversalPossibility : Class
---@overload fun(pathfinder: Pathfinder, tile: Tile, direction: integer): TraversalPossibility
local TraversalPossibility = Class:derive("TraversalPossibility")

---Constructs a new traversal possibility.
---@param pathfinder Pathfinder The pathfinder which specifies the target and constraints.
---@param tile Tile The starting tile of this Pathfinder. Must be a semaphore.
---@param direction integer The starting direction of this Pathfinder.
function TraversalPossibility:new(pathfinder, tile, direction)
    self.pathfinder = pathfinder
    self.tile = tile
    self.direction = direction
    ---@type {tile: Tile, dir1: integer?, dir2: integer?}[]
    self.path = {{tile = tile, dir2 = direction}}
    self.speed = math.huge
    self.cost = 0
    self.lastSemaphore = tile
    ---@type {start: integer, speed: number}[]
    self.segments = {{start = 1, speed = math.huge}}
end

---Creates a copy of this traversal possibility.
---@private
---@return TraversalPossibility
function TraversalPossibility:copy()
    local copy = TraversalPossibility(self.pathfinder, self.tile, self.direction)
    copy.path = _Utils.copyTable(self.path)
    copy.speed = self.speed
    copy.cost = self.cost
    copy.lastSemaphore = self.lastSemaphore
    copy.segments = {} -- Technically we could do away with this, but we don't want to risk copying a segmentless possibility just in case!
    for i, segment in ipairs(self.segments) do
        copy.segments[i] = _Utils.copyTable(segment)
    end
    return copy
end

---Evaluates this traversal possibility and returns a list of new possibilities if any are discovered, with updated statistics.
---@return TraversalPossibility[]
function TraversalPossibility:evaluate()
    -- Abort if this possibility is dead.
    if self:isDead() then
        return {}
    end
    -- This is the list of newly found possibilities.
    local found = {}
    -- This is the tile we are stepping on.
    local tile = self.tile:getNeighbor(self.direction)
    if not tile then
        return {}
    end
    -- See which directions we can go next.
    local directions = tile:getPossibleTrackDirections(_InvertDir(self.direction))
    -- Each direction is a single possibility.
    for i, direction in ipairs(directions) do
        -- Create a new copy of this possibility.
        local newPossibility = self:copy()
        newPossibility.tile = tile
        newPossibility.direction = direction
        -- Add the new tile.
        table.insert(newPossibility.path, {tile = tile, dir1 = _InvertDir(self.direction), dir2 = direction})
        -- A segment splits occurs on a semaphore tile. The semaphore must be faced in our direction. We ignore shunting-only semaphores in train mode.
        if tile:isSemaphore() and tile:getSemaphoreDirection() == direction and (self.pathfinder.mode == PathMode.SHUNT or tile.semaphoreType ~= SemaphoreType.TM) then
            newPossibility.lastSemaphore = tile
            table.insert(newPossibility.segments, {start = #newPossibility.path, speed = math.huge})
        end
        -- Check if we need to lower the speed, globally and for this segment.
        local prevTileSpeed = self.tile:getSpeedForDirections(newPossibility.path[#newPossibility.path - 1].dir1, self.direction)
        newPossibility.speed = math.min(self.speed, prevTileSpeed)
        newPossibility.segments[#newPossibility.segments].speed = math.min(newPossibility.segments[#newPossibility.segments].speed, prevTileSpeed)
        -- Assemble the possiblity and add it to the list.
        newPossibility.cost = newPossibility:calculateCost()
        table.insert(found, newPossibility)
    end
    return found
end

---Calculates the cost of this possibility.
---@return number
function TraversalPossibility:calculateCost()
    -- Calculate the cost (what we went through so far).
    local cost = 0
    for i, node in ipairs(self.path) do
        if node.tile:isDoubleSwitch() then
            cost = cost + 4
        elseif node.tile:isSwitch() then
            cost = cost + 4
        else
            cost = cost + 1
        end
    end
    local speedPenaltyMult = self.speed and math.max(self.pathfinder.speed / self.speed, 1) or 1
    cost = cost * speedPenaltyMult
    -- Calculate the heuristic (estimate cost to go).
    local tile = assert(self.tile:getNeighbor(self.direction))
    local dx, dy = math.abs(self.pathfinder.target.x - tile.x), math.abs(self.pathfinder.target.y - tile.y)
    local heuristic = (dx + dy) * 2
    -- Return the total value.
    return cost + heuristic
end

---Returns `true` if this possibility does not satisfy some of its pathfinder's conditions and cannot be recovered from that.
---@return boolean
function TraversalPossibility:isDead()
    local prevTile = self:getPreviousTile()
    if self.pathfinder.mode == PathMode.TRAIN and self.tile:isTrackClear() == false then
        -- The track is for sure occupied when in train mode.
        --_Notifications:post(string.format("After %s tiles at (%s, %s): Track occupied!", #self.path, self.tile.x, self.tile.y), NotificationColor.GRAY)
        return true
    elseif self.pathfinder.mode == PathMode.SHUNT and self.tile:isTrackClear() and prevTile and prevTile:isTrackClear() == false then
        -- We went past the occupied segment when shunting. Unfortunately current technology doesn't permit us to jump over a train...
        return true
    end
    if not self.tile:isPathModeAllowed(self.pathfinder.mode) then
        -- The track is not allowing this dispatching mode (i.e. forbids shunting or trains)
        --_Notifications:post(string.format("After %s tiles at (%s, %s): Mode forbidden!", #self.path, self.tile.x, self.tile.y), NotificationColor.GRAY)
        return true
    end
    if self.pathfinder.electrified and not self.tile.electrified then
        -- The track is not electrified while pathfinding for an electric train.
        --_Notifications:post(string.format("After %s tiles at (%s, %s): Not electrified!", #self.path, self.tile.x, self.tile.y), NotificationColor.GRAY)
        return true
    end
    local segmentSpeed = self.segments[#self.segments].speed
    if #self.segments >= 2 and segmentSpeed < 100 and self.path[self.segments[#self.segments - 1].start].tile.semaphoreNoDanger then
        -- If the segment we're on mandates speeds less than 100 km/h, and the previous semaphore does not allow that, this entire possibility will not pass.
        return true
    end
    return false
end

---Returns `true` if this possibility is a winner (points to the target tile with conditions such as W24 being present on the last semaphore).
---@return boolean
function TraversalPossibility:isWinning()
    return self.tile:getNeighbor(self.direction) == self.pathfinder.target and self.pathfinder.target:isTargetForW24(not self.lastSemaphore.semaphoreNoW24)
end

---Finalizes this possibility by extending its path until a semaphore or a dead end is found.
function TraversalPossibility:finalize()
    local n = 0
    while not (self.tile:isSemaphore() and self.tile:getSemaphoreDirection() == self.direction and self.tile ~= self.pathfinder.start) do
        local tile = self.tile:getNeighbor(self.direction)
        if not tile then
            -- Dead end.
            break
        end
        local directions = tile:getPossibleTrackDirections(_InvertDir(self.direction))
        local direction = directions[1]
        table.insert(self.path, {tile = tile, dir1 = _InvertDir(self.direction), dir2 = direction})
        if not direction then
            -- Dead end.
            break
        end
        self.tile = tile
        self.direction = direction
        n = n + 1
        assert(n < 10000, "Infinite loop")
    end
end

---Posts a notification about the position of the last semaphore tile traversed by this possibility.
function TraversalPossibility:notifyLastSemaphore()
    _Com.notify(string.format("Last semaphore: %s, %s", self.lastSemaphore.x, self.lastSemaphore.y), NotificationColor.GRAY)
    local segmentText = ""
    for i, segment in ipairs(self.segments) do
        segmentText = segmentText .. (i > 1 and ", " or "") .. "[start=" .. segment.start .. ",speed=" .. segment.speed .. "]"
    end
    _Com.notify("Segments: " .. segmentText)
end

---Returns a list of itineraries based on this possibility.
---@return Itinerary[]
function TraversalPossibility:generateItineraries()
    local itineraries = {}
    -- Iterate through all segments and generate an itinerary for each one.
    for i, segment in ipairs(self.segments) do
        local startIndex = segment.start
        local endIndex = self.segments[i + 1] and self.segments[i + 1].start or #self.path
        -- Prepare a new itinerary for this segment.
        local itinerary = Itinerary()
        for j = startIndex, endIndex do
            local node = self.path[j]
            -- Determine which tracks should be reserved. Last tile is exempt.
            if j < endIndex then
                local track = node.tile.trackID
                if track then
                    itinerary:addTrack(track)
                end
            end
            -- Check if we have to consider a switch state on this tile.
            local switchStates = node.tile:getSwitchStatesForDirections(node.dir1, node.dir2)
            for suffix, state in pairs(switchStates) do
                itinerary:addSwitch(node.tile.switchID .. suffix, state)
            end
            -- First tile determines the semaphore.
            if j == startIndex then
                itinerary:setSemaphore(assert(node.tile.semaphoreID, "Missing semaphore on starting tile!"))
                if self.pathfinder.mode == PathMode.TRAIN then
                    itinerary:setSpeed(node.tile.semaphoreAllowTrain and segment.speed or Speed.SZ)
                elseif self.pathfinder.mode == PathMode.SHUNT then
                    itinerary:setSpeed(Speed.MS2)
                end
            end
            -- Last tile determines the next semaphore, if it exists, and also determines whether W24 will be displayed.
            if j == endIndex then
                itinerary:setNext(node.tile.semaphoreID or (node.tile:isBuffer() and 0 or math.huge))
                itinerary:setW24(node.tile.targetW24)
            end
        end
        -- Add the itinerary to the list.
        table.insert(itineraries, 1, itinerary)
    end
    return itineraries
end

---Returns the penultimate tile of this possibility's path, or `nil` if the possibility's path consists of just one tile.
---@return Tile?
function TraversalPossibility:getPreviousTile()
    return self.path[#self.path - 1] and self.path[#self.path - 1].tile
end

return TraversalPossibility