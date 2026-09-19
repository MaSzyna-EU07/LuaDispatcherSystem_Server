local Class = require("lua.class")
local TrackFollower = require("lua.pathfinder.TrackFollower")

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
    ---@type table<string, Tile>
    self.exits = {}
    ---@alias BlockadeIndexData {tracks: Track[], semaphores: Semaphore[], semaphoresN: Semaphore[]}
    ---@type table<string, BlockadeIndexData>
    self.blockades = {}
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
                -- Register the semaphore.
                self.semaphores[tile.semaphoreID] = tile
                local data = {
                    shape = tile.semaphoreShape,
                    type = tile.semaphoreType,
                    next = tile.semaphoreNext,
                    fourPhase = tile.semaphoreFourPhase,
                    shortSpeed = tile.semaphoreShortSpeed,
                }
                local semaphore = _Obj:getSemaphore(tile.semaphoreID)
                if semaphore then
                    semaphore:setData(data)
                else
                    _Obj:addSemaphore(tile.semaphoreID, data)
                    semaphore = _Obj:getSemaphore(tile.semaphoreID)
                end
                -- Check if the tile behind exists and assign the semaphore to its track.
                local prevTrackID = tile:getSemaphorePrevTrackID()
                if prevTrackID then
                    ---@type TrackIndexData
                    local trackData = self.tracks[prevTrackID] or {semaphores = {}}
                    table.insert(trackData.semaphores, semaphore)
                    self.tracks[prevTrackID] = trackData
                end
            end
            if tile.warpID and tile:isExitPoint() then
                -- Register the exit point.
                self.exits[tile.warpID] = tile
            end
        end
    end
end

---Goes through all indexed uncontrollable semaphores, and if they have no next default semaphore/speed in their data,
---attempts to fill this in with the semaphore physically behind.
---
---This works only if the given semaphore is guaranteed to have the same next semaphore, no matter the route.
---If there's a diverging route between the two semaphores, the next semaphore is ambiguous and the next default semaphore field will stay empty.
---
---Typically, this only affects blockade semaphores.
---The reason why we're not doing this in the blockade itself is that the station entrance semaphores are not considered part of the blockade.
function SchematicIndex:generateSemaphoreNextDefaults()
    for semaphoreID, tile in pairs(self.semaphores) do
        local semaphore = _Obj:assertGetSemaphore(semaphoreID)
        if not tile:isSemaphoreControllable() and semaphore.nextDefault == math.huge then
            _LogWrite(string.format("Looking for an automatically assigned next semaphore for semaphore `%s`", semaphoreID), Severity.INFO, 2)
            -- Scan for the next semaphore.
            local follower = TrackFollower(tile, assert(tile:getSemaphoreDirection()))
            follower:setSwitchPolicy(TrackFollowerSwitchPolicy.STOP_DIVERGING)
            follower:stepUntil(function(stepTile) return stepTile:isSemaphore() and stepTile:getSemaphoreDirection() == follower.direction end)
            _LogWrite(string.format("Found next semaphore for `%s` -> `%s`", semaphoreID, follower:getTile().semaphoreID), Severity.INFO, 2)
            semaphore:setNextDefault(follower:getTile().semaphoreID)
        end
    end
end

---Generates blockades which start on this schematic.
function SchematicIndex:generateBlockades()
    for x = 1, self.schematic.w do
        for y = 1, self.schematic.h do
            local tile = self.schematic:assertGetTile(x, y)
            if tile.blockadeID and tile:isBlockadeGenerator() then
                _LogWrite(string.format("Blockade start found: %s (%s)", tile.blockadeID, self.schematic.name), Severity.INFO, 2)
                ---@type BlockadeIndexData
                local blockadeData = {tracks = {}, semaphores = {}, semaphoresN = {}}
                -- Start going through tiles until we find a controlled semaphore.
                local follower = TrackFollower(tile, assert(tile:getBlockadeDirection()))
                local n = 0
                while not (follower.tile:isSemaphore() and follower.tile:isSemaphoreControllable()) do
                    local scanTile = follower.tile
                    _LogWrite(string.format("Traversing: %s:%s,%s", scanTile.schematic.shortcut, scanTile.x, scanTile.y), Severity.INFO, 1)
                    -- Scan the traversed tile.
                    if scanTile.trackID then
                        table.insert(blockadeData.tracks, _Obj:assertGetTrack(scanTile.trackID))
                    end
                    if scanTile.semaphoreID then
                        if scanTile:getSemaphoreDirection() == follower.direction then
                            table.insert(blockadeData.semaphores, _Obj:assertGetSemaphore(scanTile.semaphoreID))
                        else
                            table.insert(blockadeData.semaphoresN, _Obj:assertGetSemaphore(scanTile.semaphoreID))
                        end
                    end
                    local continue = follower:step()
                    if not continue then
                        break
                    end
                    n = n + 1
                    assert(n < 10000, "Infinite loop")
                end
                -- Scan finished.
                _Utils.tableRemoveDuplicatesInplace(blockadeData.tracks)
                _Utils.tableRemoveDuplicatesInplace(blockadeData.semaphores)
                _Utils.tableRemoveDuplicatesInplace(blockadeData.semaphoresN)
                -- Before we confirm the blockade, verify a few assumptions.
                local valid = true
                if #blockadeData.tracks == 0 then
                    _LogWrite(string.format("Blockade `%s` invalid: No tracks found!", tile.blockadeID), Severity.FAIL, 2)
                    valid = false
                elseif #blockadeData.semaphores ~= #blockadeData.tracks - 1 then
                    _LogWrite(string.format("Blockade `%s` invalid: Number of semaphores (%s) does not match number of tracks (%s) minus 1!", tile.blockadeID, #blockadeData.semaphores, #blockadeData.tracks), Severity.FAIL, 2)
                    valid = false
                elseif #blockadeData.semaphoresN > 0 and #blockadeData.semaphoresN ~= #blockadeData.tracks - 1 then
                    _LogWrite(string.format("Blockade `%s` invalid: Number of semaphores-N (%s) does neither equal 0 nor match number of tracks (%s) minus 1!", tile.blockadeID, #blockadeData.semaphoresN, #blockadeData.tracks), Severity.FAIL, 2)
                    valid = false
                end
                if valid then
                    self.blockades[tile.blockadeID] = blockadeData
                    -- Assemble final blockade data and create the actual blockade.
                    ---@type BlockadeData
                    local finalBlockadeData = {type = "sbl", bidirectional = #blockadeData.semaphoresN > 0, blocks = {}}
                    for i, track in ipairs(blockadeData.tracks) do
                        table.insert(finalBlockadeData.blocks, {track = track, semaphore = blockadeData.semaphores[i - 1], semaphoreN = blockadeData.semaphoresN[i]})
                    end
                    _Obj:addBlockade(tile.blockadeID, finalBlockadeData)
                    _Obj:getBlockade(tile.blockadeID):init()
                end
            end
        end
    end
end

---Returns data about the given track. If the track does not exist in the index, returns `nil`.
---@param name string The track name.
---@return TrackIndexData?
function SchematicIndex:getTrack(name)
    return self.tracks[name]
end

---Returns the tile on which the provided switch is on. If the switch doesn't exist in the index, returns `nil`.
---@param name string The switch name.
---@return Tile?
function SchematicIndex:getSwitch(name)
    return self.switches[name]
end

---Returns the tile on which the provided semaphore is on. If the semaphore doesn't exist in the index, returns `nil`.
---@param name string The semaphore name.
---@return Tile?
function SchematicIndex:getSemaphore(name)
    return self.semaphores[name]
end

---Returns the tile on which the provided exit is on. If the exit doesn't exist in the index, returns `nil`.
---@param name string The exit name.
---@return Tile?
function SchematicIndex:getExit(name)
    return self.exits[name]
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
    for i, id in ipairs(_Utils.tableGetSortedKeys(self.tracks)) do
        local data = self.tracks[id]
        local trainLocation = self:getTileLocation(data.trainTarget)
        local shuntLocation = self:getTileLocation(data.shuntTarget)
        local semaphoreList = _StrSemaphoreList(data.semaphores)
        _LogWrite(string.format("  - %s: P -> %s, M -> %s, semaphores: %s", id, trainLocation, shuntLocation, semaphoreList), Severity.INFO, 2)
    end
    _LogWrite("- Switches:", Severity.INFO, 2)
    for i, id in ipairs(_Utils.tableGetSortedKeys(self.switches)) do
        _LogWrite(string.format("  - %s: %s", id, self:getTileLocation(self.switches[id])), Severity.INFO, 2)
    end
    _LogWrite("- Semaphores:", Severity.INFO, 2)
    for i, id in ipairs(_Utils.tableGetSortedKeys(self.semaphores)) do
        _LogWrite(string.format("  - %s: %s", id, self:getTileLocation(self.semaphores[id])), Severity.INFO, 2)
    end
    _LogWrite("- Exits:", Severity.INFO, 2)
    for i, id in ipairs(_Utils.tableGetSortedKeys(self.exits)) do
        _LogWrite(string.format("  - %s: %s", id, self:getTileLocation(self.exits[id])), Severity.INFO, 2)
    end
    _LogWrite("- Blockades:", Severity.INFO, 2)
    for i, id in ipairs(_Utils.tableGetSortedKeys(self.blockades)) do
        local data = self.blockades[id]
        _LogWrite(string.format("  - %s:", id), Severity.INFO, 2)
        _LogWrite(string.format("    - tracks: %s", _StrTrackList(data.tracks)), Severity.INFO, 2)
        _LogWrite(string.format("    - semaphores: %s", _StrSemaphoreList(data.semaphores)), Severity.INFO, 2)
        _LogWrite(string.format("    - semaphores-N: %s", _StrSemaphoreList(data.semaphoresN)), Severity.INFO, 2)
    end
end

return SchematicIndex