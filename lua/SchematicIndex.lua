local Class = require("lua.class")

---Represents an index of a station schematic. Indexes a schematic, registers objects
---and stores a map of object names to tiles for pathfinding convenience.
---@class SchematicIndex : Class
---@overload fun(schematic): SchematicIndex
local SchematicIndex = Class:derive("SchematicIndex")

---Creates a new Schematic Index.
---@param schematic Schematic The station schematic this Index is of.
function SchematicIndex:new(schematic)
    self.schematic = schematic
    ---@alias TrackIndexData {trainTarget: Tile?, shuntTarget: Tile?, semaphores: Semaphore[]}
    ---@type table<string, TrackIndexData>
    self.tracks = {}
    ---@type table<string, Tile>
    self.switches = {}
    ---@type table<string, Tile>
    self.semaphores = {}
end

---Registers a switch into this index and also attempts to add it to the device list.
---@private
---@param id string The switch ID.
---@param tile Tile The tile associated with this switch.
function SchematicIndex:registerSwitch(id, tile)
    self.switches[id] = tile
    if not _Obj:getSwitch(id) then
        _Obj:addSwitch(id)
    end
end

---Indexes the schematic and registers any found objects, if the simulator still accepts that.
function SchematicIndex:generateIndex()
    for x = 1, self.schematic.w do
        for y = 1, self.schematic.h do
            local tile = self.schematic:assertGetTile(x, y)
            if tile.trackID then
                ---@type TrackIndexData
                local trackData = self.tracks[tile.trackID] or {semaphores = {}}
                trackData.trainTarget = tile.trainTarget and tile or trackData.trainTarget
                trackData.shuntTarget = tile.shuntTarget and tile or trackData.shuntTarget
                if not _Obj:getTrack(tile.trackID) then
                    _Obj:addTrack(tile.trackID)
                end
                self.tracks[tile.trackID] = trackData
            end
            if tile.switchID then
                if tile:isDoubleSwitch() then
                    self:registerSwitch(tile.switchID .. "ab", tile)
                    self:registerSwitch(tile.switchID .. "cd", tile)
                else
                    self:registerSwitch(tile.switchID, tile)
                end
            end
            if tile.semaphoreID and tile:isSemaphore() then
                self.semaphores[tile.semaphoreID] = tile
                local prevTile = tile:getNeighbor(_InvertDir(assert(tile:getSemaphoreDirection())))
                if prevTile and prevTile.trackID then
                    ---@type TrackIndexData
                    local trackData = self.tracks[prevTile.trackID] or {semaphores = {}}
                    table.insert(trackData.semaphores, _Obj:getSemaphore(tile.semaphoreID))
                    self.tracks[prevTile.trackID] = trackData
                end
                if not _Obj:getSemaphore(tile.semaphoreID) then
                    local data = {
                        shape = tile.semaphoreShape,
                        type = tile.semaphoreType,
                        next = tile.semaphoreNext,
                        fourPhase = tile.semaphoreFourPhase,
                        shortSpeed = tile.semaphoreShortSpeed,
                    }
                    _Obj:addSemaphore(tile.semaphoreID, data)
                end
            end
        end
    end
end

---Returns the tile location or `"none"` when the tile doesn't exist.
---@private
---@param tile Tile? The tile to return the location of.
---@return string
function SchematicIndex:getTileLocation(tile)
    return tile and string.format("(%s, %s)", tile.x, tile.y) or "none"
end

---Prints the index contents to the log.
function SchematicIndex:print()
    _LogWrite(string.format("Schematic index for station %s:", self.schematic.name), Severity.INFO, 2)
    _LogWrite("- Tracks:", Severity.INFO, 2)
    for i, id in ipairs(_TableGetSortedKeys(self.tracks)) do
        local data = self.tracks[id]
        local trainLocation = self:getTileLocation(data.trainTarget)
        local shuntLocation = self:getTileLocation(data.shuntTarget)
        local semaphoreList = "none"
        for j, semaphore in ipairs(data.semaphores) do
            semaphoreList = (j == 1 and "" or (semaphoreList .. ", ")) .. semaphore.id
        end
        _LogWrite(string.format("  - %s: P -> %s, M -> %s, semaphores: %s", id, trainLocation, shuntLocation, semaphoreList), Severity.INFO, 2)
    end
    _LogWrite("- Switches:", Severity.INFO, 2)
    for i, id in ipairs(_TableGetSortedKeys(self.switches)) do
        _LogWrite(string.format("  - %s: %s", id, self:getTileLocation(self.switches[id])), Severity.INFO, 2)
    end
    _LogWrite("- Semaphores:", Severity.INFO, 2)
    for i, id in ipairs(_TableGetSortedKeys(self.semaphores)) do
        _LogWrite(string.format("  - %s: %s", id, self:getTileLocation(self.semaphores[id])), Severity.INFO, 2)
    end
end

return SchematicIndex