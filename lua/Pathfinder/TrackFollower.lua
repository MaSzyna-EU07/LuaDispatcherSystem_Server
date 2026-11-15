local Class = require("lua.class")
local TrackFollowerSwitchPolicy = require("lua.Pathfinder.TrackFollowerSwitchPolicy")

---This is a simple class which wraps logic associated with "I want to see what's 5 tiles away" and can be utilized for scanning or other stuff.
---Think of it as a board game pawn which can move around the station schematics.
---@class TrackFollower : Class
---@overload fun(start: Tile, direction: integer): TrackFollower
local TrackFollower = Class:derive("TrackFollower")

---Creates a Track Follower.
---@param start Tile The tile this Track Follower starts on.
---@param direction integer The direction this Track Follower will go towards. Actually can be the inverse of the source direction.
function TrackFollower:new(start, direction)
    self.tile = start
    -- TODO: Consider taking `sourceDir` and inverting it here instead to be even less misleading!
    self.direction = direction
    ---@alias PathNode {tile: Tile, dir1: integer?, dir2: integer?}
    ---@alias Path PathNode[]
    ---@type Path
    self.path = {}

    self.switchPolicy = TrackFollowerSwitchPolicy.NORMAL
    self.pathRecording = false
end

---Sets the switch policy for this Track Follower.
---@param switchPolicy TrackFollowerSwitchPolicy The new policy to be obeyed.
function TrackFollower:setSwitchPolicy(switchPolicy)
    self.switchPolicy = switchPolicy
end

---Sets whether this Track Follower is going to record the list of tiles it went through and directions.
---@param pathRecording boolean Whether the path recording should be enabled.
function TrackFollower:setPathRecording(pathRecording)
    self.pathRecording = pathRecording
end

---Returns the list of tiles this follower has went through.
---Requires `:setPathRecording(true)` to be called before moving.
---@return Path
function TrackFollower:getPath()
    return self.path
end

---Attempts to move this follower to the next tile in its current direction.
---If the follower cannot advance, either because of a missing track or the switch policy, `false` is returned.
---Otherwise returns `true`.
---@return boolean
function TrackFollower:step()
    -- Record the first tile if recording is enabled.
    if self.pathRecording and #self.path == 0 then
        table.insert(self.path, {tile = self.tile})
    end
    -- Deduce the source direction. It will be useful later.
    local sourceDir = _Dir.invertDir(self.direction)
    -- Check the switch policy and reject movement if applicable.
    if self.switchPolicy == TrackFollowerSwitchPolicy.STOP and self.tile:isSwitch() then
        -- Stopped by any switch
        return false
    end
    if self.switchPolicy == TrackFollowerSwitchPolicy.STOP_DIVERGING and #self.tile:getPossibleTrackDirections(sourceDir) > 1 then
        -- Stopped by a diverging switch
        return false
    end
    -- Check if we are on a warp/exit tile and if so, perform the warp.
    if self.tile:isExitPoint() then
        local destination = self.tile:getWarpDestination()
        if not destination then
            _Log.write("Warp destination not found (dir=" .. self.direction .. ")", Severity.FAIL, 2)
            -- Tile does not lead to a valid destination. End the scan here.
            return false
        end
        self.tile = destination
        -- The exit can be anywhere on the new schematic, and at any angle too!
        self.direction = self.tile:getWarpExitDirection()
        if not self.direction then
            _Log.write(string.format("No direction to go towards - probably an improperly set exit tile at %s", self.tile:getLocation()), Severity.FAIL, 2)
            return false
        end
    else
        -- Determine the next direction in a classic way. Remember to follow the policy!
        local dir
        if self.switchPolicy == TrackFollowerSwitchPolicy.RANDOM then
            dir = _Utils.iTableGetRandomValue(self.tile:getPossibleTrackDirections(sourceDir))
        else
            dir = self.tile:getNextTrackDirection(sourceDir)
        end
        if not dir then
            -- Dead end.
            return false
        end
        self.direction = dir
    end
    -- Move forward.
    local nextTile = self.tile:getNeighbor(self.direction)
    if not nextTile then
        -- We've reached the edge of the schematic. Dead end.
        _Log.write("No nextTile (dir=" .. self.direction .. ")", Severity.FAIL, 2)
        return false
    end
    self.tile = nextTile
    -- Record the new tile if recording is enabled.
    if self.pathRecording then
        self.path[#self.path].dir2 = self.direction
        table.insert(self.path, {tile = self.tile, dir1 = _Dir.invertDir(self.direction)})
    end
    return true
end

---Performs a step until the provided function returns `true` or until the follower gets stuck.
---Throws an error after 10,000 iterations, which means there's a very possible infinite loop.
---@param fn fun(tile: Tile): boolean The steps will continue until this function returns `true`. Its only argument is its current tile.
function TrackFollower:stepUntil(fn)
    local n = 0
    repeat
        local continue = self:step()
        if not continue then
            break
        end
        n = n + 1
        assert(n < 10000, "Infinite loop")
    until fn(self.tile)
end

---Returns the current tile this follower is on.
---@return Tile
function TrackFollower:getTile()
    return self.tile
end

return TrackFollower