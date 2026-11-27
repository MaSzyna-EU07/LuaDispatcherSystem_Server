local Class = require("lua.core.class")
local Severity = require("lua.core.Utils.LogSeverity")
local PathMode = require("lua.core.Enums.PathMode")

---@class MapPathfinder : Class
---@overload fun(start: Schematic, target: Schematic): MapPathfinder
local MapPathfinder = Class:derive("MapPathfinder")

---@alias MapPathNode {schematic: Schematic, exitIn: string?, exitOut: string?}
---@alias MapPath MapPathNode[]

---Creates a new Map Pathfinder.
---Unlike the regular Pathfinder, this one pathfinds between schematics.
---@param start Schematic The starting schematic.
---@param target Schematic The target schematic.
function MapPathfinder:new(start, target)
    self.start = start
    self.startInboundExit = nil
    self.target = target
    self.targetTile = nil -- More precise information for the pathfinder
    self.speed = 160
    self.mode = PathMode.TRAIN
    self.electrified = false
    self.bidirectional = true

    -- TODO: Incorporate this for faster lowest cost search?
    self.possibilitySortFn = function(a, b) return a.cost < b.cost end

    -- Each entry in this table is an exploration possibility.
    --
    -- The entries are keyed per schematic AND THEN per that schematic's inbound exit, because a route can incorporate going through a single schematic
    -- multiple times from different directions (for example, if we are turning around at the next station and have to backtrack a bit).
    --
    -- `prev` determines the previous entry in the table, used for tracing the route back at the end.
    ---@alias MapPathfinderEntry {cost: {base: number, total: number}, explored: boolean, prev: {schematic: Schematic, exit: string, exitOut: string}?}
    ---@type table<Schematic, table<string, MapPathfinderEntry>>
    self.schematics = {}
    self.targetInboundExit = nil -- Stores the inbound exit of the target schematic after pathfinding is complete.
end

---Returns a pathfinder entry for the specified combination of schematic and its inbound exit, or `nil` if it is not there.
---@private
---@param schematic Schematic The schematic to be searched for.
---@param exit string? The inbound exit to be searched for.
---@return MapPathfinderEntry?
function MapPathfinder:getEntry(schematic, exit)
    return self.schematics[schematic] and self.schematics[schematic][exit or ""]
end

---Sets a pathfinder entry for the specified combination of schematic and its inbound exit.
---@private
---@param schematic Schematic The schematic to be used.
---@param exit string? The schematic's inbound exit to be saved into.
---@param entry MapPathfinderEntry The pathfinder entry to be saved.
function MapPathfinder:setEntry(schematic, exit, entry)
    self.schematics[schematic] = self.schematics[schematic] or {}
    self.schematics[schematic][exit or ""] = entry
end

---Sets the starting inbound exit for the starting schematic for this Map Pathfinder.
---@param exitIn string? The exit to be considered as the entrance for this Pathfinder.
function MapPathfinder:setInboundExit(exitIn)
    self.startInboundExit = exitIn
end

---Sets the target tile to target in the target schematic.
---@param tile Tile? The target tile.
function MapPathfinder:setTargetTile(tile)
    self.targetTile = tile
end

---Sets the dispatching mode for this MapPathfinder. This affects the possible paths and the displayed signal.
---@param mode PathMode The mode to be set.
function MapPathfinder:setMode(mode)
    self.mode = mode
end

---Sets whether this MapPathfinder is for an electric train. If so, it will not pathfind through non-electrified tiles.
---@param electrified boolean The electrification mode to be set.
function MapPathfinder:setElectrified(electrified)
    self.electrified = electrified
end

---Sets whether this MapPathfinder is for a bidirectional train (loco only, EMU/DMU, push-pull...). If so, the direction change will be more permissible and less penalized.
---@param bidirectional boolean The bidirectionality mode to be set.
function MapPathfinder:setBidirectional(bidirectional)
    self.bidirectional = bidirectional
end

---Creates the initial possibility starting from this MapPathfinder's first tile.
---@private
function MapPathfinder:createInitialPossibility()
    assert(_Utils.tableIsEmpty(self.schematics), "Attempted to create initial possibilities for a non-empty pathfinder!")
    self:setEntry(self.start, self.startInboundExit, {cost = {base = 0, total = 0}, explored = false})
end

---Does a single step of the pathfinding procedure.
---Returns `true` if we've found the target schematic (this also sets the `targetInboundExit` field), `false` if there are no tiles left to explore, and `nil` if the pathfinder should keep going.
---@return boolean?
function MapPathfinder:findPathStep()
    -- Create the initial possibility if we don't have anything yet.
    if _Utils.tableIsEmpty(self.schematics) then
        self:createInitialPossibility()
    end
    -- Find the unexplored tile with the lowest cost and explore it.
    -- TODO: Separate the queue?
    local schematic, exitIn = self:getNextUnexploredSchematic()
    if not schematic or not exitIn then
        return false
    end
    if schematic == self.target and (not self.targetTile or schematic:doesPathExist({schematic.index:getExit(exitIn), self.targetTile}, self.mode)) then
        -- We've taken a winner!
        self.targetInboundExit = exitIn
        return true
    end
    self:exploreSchematic(schematic, exitIn)
end

---Finds the best path considering the constraints.
---Returns the path if it has been found, `nil` otherwise.
---Throws an error after 100,000 iterations, which means there's a very possible infinite loop.
---@return MapPath?
function MapPathfinder:findPath()
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
        assert(n < 100000, "MapPathfinder took too long!!!")
    end

    -- If we've got here, we've found the path !!
    local path = assert(self:getPath(self.target, self.targetInboundExit))
    _Log.write("Path found:", Severity.SUCCESS, 1)
    for i, node in ipairs(path) do
        _Log.write(string.format("  - %s%s%s", node.exitIn and ("[" .. node.exitIn .. "] => ") or "", node.schematic.shortcut, node.exitOut and (" => [" .. node.exitOut .. "]") or ""), Severity.SUCCESS, 1)
    end
    return path
end

---Explores the specified entry and registers new entries if anything new is found.
---@param schematic Schematic The schematic to be explored.
---@param exitIn string? The schematic's inbound exit ID. `nil` means we are starting at that schematic.
function MapPathfinder:exploreSchematic(schematic, exitIn)
    local entry = self:getEntry(schematic, exitIn)
    if not entry then
        return
    end
    -- Get all directions we can go towards
    local exits = schematic.index:getExits()
    for exit, tile in pairs(exits) do
        local nextTile = tile:getWarpDestination()
        local nextSchematic = nextTile and nextTile.schematic
        local nextExit = nextTile and nextTile.warpID -- Inbound exit on the next schematic
        -- TODO: Fetch the list of tiles to be traversed on that schematic. It can be more than just the exits.
        if nextTile and nextSchematic and nextExit and self:canPassSchematic(schematic, exitIn, exit) then -- TODO: Add `:canEnter...()` for checking whether we can go there at all or anything extra is needed
            -- For each neighbor schematic that exists, make a new entry to fill stuff into.
            local nextEntry = {
                cost = {base = entry.cost.base, total = nil},
                explored = false,
                prev = {schematic = schematic, exit = exitIn, exitOut = exit}
            }
            -- Add base cost.
            nextEntry.cost.base = nextEntry.cost.base + 1
            -- Penalize for going in the opposite direction (W24)
            if tile.targetW24 then
                nextEntry.cost.base = nextEntry.cost.base + 2
            end
            -- TODO: Add more cost if there's going to be a direction change or a turnaround needed!
            -- Calculate the total cost.
            nextEntry.cost.total = nextEntry.cost.base
            -- Save this possibility unless a better one already exists.
            local rivalEntry = self:getEntry(nextSchematic, nextExit)
            if not rivalEntry or nextEntry.cost.total < rivalEntry.cost.total then
                self:setEntry(nextSchematic, nextExit, nextEntry)
            end
        end
    end
    -- This entry has been explored. That's it.
    entry.explored = true
end

---Returns the next unexplored pair (schematic, its inbound exit) with the lowest cost.
---If there are no entries left to explore, returns `nil, nil`.
---@private
---@return Schematic?, string?
function MapPathfinder:getNextUnexploredSchematic()
    local lowestSchematic, lowestExit = nil, nil
    for schematic, entries in pairs(self.schematics) do
        for exit, entry in pairs(entries) do
            if not entry.explored and (not lowestSchematic or not lowestExit or entry.cost.total < self:getEntry(lowestSchematic, lowestExit).cost.total) then
                lowestSchematic, lowestExit = schematic, exit ~= "" and exit or nil
            end
        end
    end
    return lowestSchematic, lowestExit
end

---Returns whether this MapPathfinder can pass through the specified schematic.
---@private
---@param schematic Schematic The schematic to pathfind through.
---@param exitIn string? The inbound exit of the schematic.
---@param exitOut string The outbound exit of the schematic.
---@return boolean
function MapPathfinder:canPassSchematic(schematic, exitIn, exitOut)
    if not exitIn then
        -- TODO: This is not always true! Depending on the track, we might be barred from accessing some exits.
        return true
    end
    local tileIn = schematic.index:getExit(exitIn)
    local tileOut = schematic.index:getExit(exitOut)
    if not tileIn or not tileOut then
        -- Both tiles should exist. If they don't, abort.
        return false
    end
    local info = schematic.index:assertGetRoutingInfo(exitIn, exitOut)
    if not info.traversable then
        -- There is no physical track between the two exits.
        return false
    end
    return true
end

---Returns the already calculated path from the following tile.
---Returns `nil` if the specified tile hasn't been explored and as such found a way to.
---@param schematic Schematic The schematic to start from.
---@param exit string The schematic's inbound exit ID.
---@return MapPath?
function MapPathfinder:getPath(schematic, exit)
    local entry = self:getEntry(schematic, exit)
    if not entry then
        return
    end
    -- Work our way backwards.
    ---@type {entry: MapPathfinderEntry, schematic: Schematic, exitIn: string}[]
    local entries = {}
    local curSchematic = schematic
    local curExit = exit
    while true do
        local curEntry = assert(self:getEntry(curSchematic, curExit))
        table.insert(entries, 1, {entry = curEntry, schematic = curSchematic, exitIn = curExit})
        if not curEntry.prev then
            break
        end
        curSchematic, curExit = curEntry.prev.schematic, curEntry.prev.exit
    end
    ---@type MapPath
    local path = {}
    for i, curEntry in ipairs(entries) do
        table.insert(path, {schematic = curEntry.schematic, exitIn = curEntry.exitIn, exitOut = entries[i + 1] and entries[i + 1].entry.prev.exitOut})
    end
    return path
end

---Prints internal state of this Map Pathfinder for debugging purposes.
function MapPathfinder:examine()
    _Log.write(string.format("State of MapPathfinder from %s to %s:", self.start.shortcut, self.target.shortcut))
    _Log.write("- Schematics:")
    for schematic, entries in pairs(self.schematics) do
        for exitIn, entry in pairs(entries) do
            local prevText = entry.prev and string.format("%s(%s)", entry.prev.schematic.shortcut, entry.prev.exit) or "none"
            _Log.write(string.format("  - %s(%s) -> cost: %s, explored: %s, prev: %s", schematic.shortcut, exitIn, entry.cost.total, entry.explored, prevText))
        end
    end
end

return MapPathfinder