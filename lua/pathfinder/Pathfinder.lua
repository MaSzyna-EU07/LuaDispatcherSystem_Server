local Class = require("lua.class")
local TraversalPossibility = require("lua.pathfinder.TraversalPossibility")

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

    ---@type TraversalPossibility[]
    self.possibilities = {} -- List of traversal possibilities
    ---@type Itinerary[]
    self.itineraries = {} -- The list of itineraries corresponding to the winning path.

    self.possibilitySortFn = function(a, b) return a.cost < b.cost end
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

---Calculates the path based on the provided start and end point of this Pathfinder. If a path is found, generates itineraries for it.
---Returns `true` if the path has been found, `false` otherwise.
---@return boolean
function Pathfinder:calculatePath()
    self:createInitialPossibility()
    ---@type TraversalPossibility?
    local winner = nil
    while #self.possibilities > 0 do
        -- Get the possibility which has the lowest cost.
        table.sort(self.possibilities, self.possibilitySortFn)
        ---@type TraversalPossibility
        local possibility = table.remove(self.possibilities, 1)
        if possibility:isWinning() then
            possibility:finalize()
            possibility:notifyLastSemaphore()
            winner = possibility
            break
        end
        local newPossibilities = possibility:evaluate()
        _Utils.tableAddInplace(self.possibilities, newPossibilities)
    end

    if not winner then
        return false
    end

    _LogWrite("Path found:", Severity.SUCCESS, 1)
    for i, node in ipairs(winner.path) do
        _LogWrite(string.format("    %s: pos=%s,%s dirs=%s,%s", i, node.tile.x, node.tile.y, node.dir1, node.dir2), Severity.SUCCESS, 1)
    end
    self.itineraries = winner:generateItineraries()
    return true
end

---Creates the initial possibility starting from this Pathfinder's first tile.
---@private
function Pathfinder:createInitialPossibility()
    local direction = self.start:getSemaphoreDirection()
    if not direction then
        -- The first tile is not a semaphore. This is currently a requirement.
        return
    end
    table.insert(self.possibilities, TraversalPossibility(self, self.start, direction))
end

---Reserves all tracks, sets all switches and displays a clear signal on the semaphore.
function Pathfinder:dispatch()
    for i, itinerary in ipairs(self.itineraries) do
        itinerary:dispatch()
    end
end

return Pathfinder