local Class = require("lua.class")

---Helper clas for teh Map Pathfinder. Represents a single possibility of going somewhere.
---Each possibility remembers its full path from the start.
---A possibility can be dead (violating the constraints) or winning (reached its target).
---@class MapTraversalPossibility : Class
---@overload fun(pathfinder: MapPathfinder, schematic: Schematic, routeIn: string?): MapTraversalPossibility
local MapTraversalPossibility = Class:derive("MapTraversalPossibility")

---Constructs the map traversal possibility.
---@param pathfinder MapPathfinder The map pathfinder which specifies the target and constraints.
---@param schematic Schematic The current schematic this possibility is on.
---@param routeIn string? The route ID (on this schematic's side) that has been entered, if any. Used to evaluate exit-exit path capabilities on the schematic.
function MapTraversalPossibility:new(pathfinder, schematic, routeIn)
    self.pathfinder = pathfinder
    self.schematic = schematic
    self.routeIn = routeIn
    ---@type {schematic: Schematic, routeIn: string?, routeOut: string?}[]
    self.path = {}
    self.cost = 0
end

---Creates a copy of this traversal possibility.
---@private
---@return MapTraversalPossibility
function MapTraversalPossibility:copy()
    local copy = MapTraversalPossibility(self.pathfinder, self.schematic, self.routeIn)
    copy.path = _Utils.copyTable(self.path)
    return copy
end

---Explores this possibility and returns all newly found possibilities.
---@return MapTraversalPossibility[]
function MapTraversalPossibility:evaluate()
    _Log.write("Starting evaluation: " .. self.schematic.shortcut .. " , " .. tostring(self.routeIn))
    -- This is the list of newly found possibilities.
    local found = {}

    -- Look at the neighbor schematics.
    local neighbors = self.schematic.index:getNeighborSchematics()
    for newSchematicID, data in pairs(neighbors) do
        -- Fetch some more data.
        local newSchematic = _Obj:getSchematic(newSchematicID)
        if newSchematic and newSchematic ~= self.pathfinder.start then
            -- Create a new possibility for this exit.
            local newPossibility = self:copy()
            newPossibility.schematic = newSchematic
            newPossibility.routeIn = "" -- TODO
            -- Add the new path node.
            table.insert(newPossibility.path, {schematic = self.schematic, routeIn = self.routeIn, routeOut = ""}) -- TODO
            -- TODO: A lot of logic here? Check if we have to change direction, if the track is electrified, etc...
            -- Assemble the possiblity and add it to the list.
            newPossibility.cost = newPossibility:getCost()
            table.insert(found, newPossibility)
            _Log.write("- Possibility found: " .. newSchematicID .. " , cost: " .. newPossibility.cost)
        end
    end

    --[[
    -- Look at all exits on the current schematic.
    local exits = self.schematic.index:getExits()
    for exitID, tile in pairs(exits) do
        -- Fetch some more data.
        local oppositeExitID = tile.warpTargetID
        local newSchematic = _Obj:getSchematic(tile.warp)
        if newSchematic and newSchematic ~= self.pathfinder.start then
            -- Create a new possibility for this exit.
            local newPossibility = self:copy()
            newPossibility.schematic = newSchematic
            newPossibility.routeIn = oppositeExitID
            -- Add the new path node.
            table.insert(newPossibility.path, {schematic = self.schematic, routeIn = self.routeIn, routeOut = exitID})
            -- TODO: A lot of logic here? Check if we have to change direction, if the track is electrified, etc...
            -- Assemble the possiblity and add it to the list.
            newPossibility.cost = newPossibility:getCost()
            table.insert(found, newPossibility)
            _Log.write("- Possibility found: " .. exitID .. " , " .. tile:getLocation() .. " , cost: " .. newPossibility.cost)
        end
    end
    ]]
    return found
end

---Calculates and returns the cost of this possibility.
---@private
---@return number
function MapTraversalPossibility:getCost()
    -- Calculate the cost (what we went through so far).
    local cost = 0
    ---@type table<Schematic, true>
    local visitedSchematics = {}
    for i, node in ipairs(self.path) do
        cost = cost + 1
        -- Penalize going through the same schematic multiple times.
        if visitedSchematics[node.schematic] then
            cost = cost + 20
        else
            visitedSchematics[node.schematic] = true
        end
        -- TODO: Penalize stuff like traversal speed, direction change, going on the left track, etc.
    end
    -- There is no heuristic, because we cannot calculate it in any reasonable way. Return the cost.
    return cost
end

---Returns `true` if this possibility is a winner (it has a complete path satisfying the pathfinder's requirements).
---@return boolean
function MapTraversalPossibility:isWinning()
    return self.schematic == self.pathfinder.target
end

---Finalizes this possibility by filling out the path.
function MapTraversalPossibility:finalize()
    table.insert(self.path, {schematic = self.schematic, routeIn = self.routeIn})
end

---A simple debug function which returns this possibility's currently traversed path.
---@return string
function MapTraversalPossibility:getPathText()
    local s = ""
    for i, node in ipairs(self.path) do
        if s ~= "" then
            s = s .. " -> "
        end
        s = s .. node.schematic.shortcut
    end
    s = s .. " -> (" .. self.schematic.shortcut .. ")"
    return s
end

return MapTraversalPossibility