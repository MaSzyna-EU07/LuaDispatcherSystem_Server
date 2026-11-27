local Class = require("lua.core.class")
local Pathfinder = require("lua.core.Pathfinder.Pathfinder")
local TrackFollower = require("lua.core.Pathfinder.TrackFollower")
local TrackFollowerSwitchPolicy = require("lua.core.Pathfinder.TrackFollowerSwitchPolicy")
local Severity = require("lua.core.Utils.LogSeverity")
local PathMode = require("lua.core.Enums.PathMode")

---Represents an index of a station schematic. Indexes a schematic, registers objects
---and stores a map of object names to tiles for pathfinding convenience.
---@class SchematicIndex : Class
---@overload fun(schematic): SchematicIndex
local SchematicIndex = Class:derive("SchematicIndex")

---Creates a new Schematic Index.
---@param schematic Schematic The station schematic this Index is of.
function SchematicIndex:new(schematic)
    self.schematic = schematic
    ---@alias TrackIndexData {trainTarget: Tile?, shuntTarget: Tile?, semaphores: Semaphore[], stationID: string?}
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
    ---@alias StationIndexData {tracks: table<string, Tile>, platforms: table<string, string>}
    ---@type table<string, StationIndexData>
    self.stations = {}
    ---@alias NeighborSchematicIndexData {exits: string[]}
    ---@type table<string, NeighborSchematicIndexData>
    self.neighborSchematics = {}
    ---@type table<string, string>
    self.exitsToEntranceSemaphores = {} -- Maps exits to the first CONTROLLED semaphore on the way that is not behind a switch.
    ---@alias RoutingInfo {traversable: boolean}
    ---@type table<string, table<string, RoutingInfo>>
    self.routingInfo = {}
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
                trackData.stationID = tile.stationName or trackData.stationID
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
            if tile:isExitPoint() then
                if tile.warpID then
                    -- Register the exit point.
                    self.exits[tile.warpID] = tile
                    if tile.warp then
                        -- Register the neighbor schematic.
                        ---@type NeighborSchematicIndexData
                        local neighborSchematicData = self.neighborSchematics[tile.warp] or {exits = {}}
                        table.insert(neighborSchematicData.exits, tile.warpID)
                        self.neighborSchematics[tile.warp] = neighborSchematicData
                    end
                end
            end
            if tile.stationName then
                ---@type StationIndexData
                local stationData = self.stations[tile.stationName] or {tracks = {}, platforms = {}}
                if tile.stationTrack then
                    stationData.tracks[tile.stationTrack] = tile
                    if tile.stationPlatform then
                        stationData.platforms[tile.stationTrack] = tile.stationPlatform
                    end
                end
                if not _Obj:getStation(tile.stationName) then
                    _Obj:addStation(tile.stationName)
                end
                self.stations[tile.stationName] = stationData
            end
        end
    end

    -- Also, generate routing information.
    self:scanEntranceSemaphores()
    self:generateRoutingInfo()
end

---Scans for an entrance semaphore for all exits in this index.
function SchematicIndex:scanEntranceSemaphores()
    _Log.write("Scanning entrance semaphores...")
    for i, exitIn in ipairs(_Utils.tableGetSortedKeys(self.exits)) do
        local tileIn = assert(self.exits[exitIn], "Could not find tile for exit " .. tostring(exitIn))
        local exitDir = tileIn:getWarpExitDirection()
        if exitDir then
            _Log.write(string.format("Starting from tile %s", tileIn:getLocation()))
            local follower = TrackFollower(tileIn, exitDir)
            follower:setSwitchPolicy(TrackFollowerSwitchPolicy.STOP)
            follower:setSwitchForceStop(true)
            follower:stepUntil(function(tile) return tile:isSemaphore() and tile:getSemaphoreDirection() == follower.direction and tile:isSemaphoreControllable() end)
            if follower.tile.schematic == self.schematic then
                -- Entrance semaphores on other schematics are not interesting us.
                _Log.write(string.format("Found entrance semaphore %s at %s", follower.tile.semaphoreID, follower.tile:getLocation()))
                self.exitsToEntranceSemaphores[exitIn] = follower.tile.semaphoreID
            end
        end
    end
end

---Checks paths from all exits to all exits (including themselves) and saves details about each pass for use by dispatchers.
function SchematicIndex:generateRoutingInfo()
    _Log.write("Generating routing information...")
    for i, exitIn in ipairs(_Utils.tableGetSortedKeys(self.exits)) do
        self.routingInfo[exitIn] = {}
        for j, exitOut in ipairs(_Utils.tableGetSortedKeys(self.exits)) do
            local routingInfoData = {traversable = false}
            _Log.write(string.format("Getting route info from %s to %s", exitIn, exitOut))
            local tileIn = assert(self.exits[exitIn], "Could not find tile for exit " .. tostring(exitIn))
            local tileOut = assert(self.exits[exitOut], "Could not find tile for exit " .. tostring(exitOut))
            _Log.write(string.format("Tiles: %s -> %s, %s -> %s", exitIn, tileIn:getLocation(), exitOut, tileOut:getLocation()))
            -- Move the first tile to the entry semaphore.
            local entrySemaphore = self.exitsToEntranceSemaphores[exitIn]
            if entrySemaphore then
                local tileInSem = self:assertGetSemaphore(entrySemaphore)
                local pathfinder = Pathfinder(tileInSem, tileOut)
                local path = pathfinder:findPath()
                routingInfoData.traversable = path ~= nil
            elseif tileIn ~= tileOut and tileIn:getWarpExitDirection() then
                -- Backup path. If there is no entry semaphore, check if there is a direct path between two exits.
                local pathfinder = Pathfinder(tileIn, tileOut)
                pathfinder:setMode(PathMode.TRAIN)
                routingInfoData.traversable = pathfinder:findPath() ~= nil
            end
            self.routingInfo[exitIn][exitOut] = routingInfoData
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
    _Log.write("Generating next semaphore defaults...")
    for semaphoreID, tile in pairs(self.semaphores) do
        local semaphore = _Obj:assertGetSemaphore(semaphoreID)
        if not tile:isSemaphoreControllable() and semaphore.nextDefault == math.huge then
            _Log.write(string.format("Looking for an automatically assigned next semaphore for semaphore `%s`", semaphoreID), Severity.INFO, 2)
            -- Scan for the next semaphore.
            local follower = TrackFollower(tile, assert(tile:getSemaphoreDirection()))
            follower:setSwitchPolicy(TrackFollowerSwitchPolicy.STOP_DIVERGING)
            follower:stepUntil(function(stepTile) return stepTile:isSemaphore() and stepTile:getSemaphoreDirection() == follower.direction end)
            _Log.write(string.format("Found next semaphore for `%s` -> `%s`", semaphoreID, follower:getTile().semaphoreID), Severity.INFO, 2)
            semaphore:setNextDefault(follower:getTile().semaphoreID)
        end
    end
end

---Generates blockades which start on this schematic.
function SchematicIndex:generateBlockades()
    _Log.write("Generating blockades...")
    for x = 1, self.schematic.w do
        for y = 1, self.schematic.h do
            local tile = self.schematic:assertGetTile(x, y)
            if tile.blockadeID and tile:isBlockadeGenerator() then
                _Log.write(string.format("Blockade start found: %s (%s)", tile.blockadeID, self.schematic.name), Severity.INFO, 2)
                ---@type BlockadeIndexData
                local blockadeData = {tracks = {}, semaphores = {}, semaphoresN = {}}
                -- Start going through tiles until we find a controlled semaphore.
                local follower = TrackFollower(tile, assert(tile:getBlockadeDirection()))
                local n = 0
                while not (follower.tile:isSemaphore() and follower.tile:isSemaphoreControllable()) do
                    local scanTile = follower.tile
                    _Log.write(string.format("Traversing: %s", scanTile:getLocation()), Severity.INFO, 1)
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
                    _Log.write(string.format("Blockade `%s` invalid: No tracks found!", tile.blockadeID), Severity.FAIL, 2)
                    valid = false
                elseif #blockadeData.semaphores ~= #blockadeData.tracks - 1 then
                    _Log.write(string.format("Blockade `%s` invalid: Number of semaphores (%s) does not match number of tracks (%s) minus 1!", tile.blockadeID, #blockadeData.semaphores, #blockadeData.tracks), Severity.FAIL, 2)
                    valid = false
                elseif #blockadeData.semaphoresN > 0 and #blockadeData.semaphoresN ~= #blockadeData.tracks - 1 then
                    _Log.write(string.format("Blockade `%s` invalid: Number of semaphores-N (%s) does neither equal 0 nor match number of tracks (%s) minus 1!", tile.blockadeID, #blockadeData.semaphoresN, #blockadeData.tracks), Severity.FAIL, 2)
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

---Returns the tile on which the provided semaphore is on. If the semaphore doesn't exist in the index, throws an error.
---@param name string The semaphore name.
---@return Tile
function SchematicIndex:assertGetSemaphore(name)
    local semaphore = assert(self.semaphores[name], "Could not find tile for semaphore " .. tostring(name))
    return semaphore
end

---Returns the tile on which the provided exit is on. If the exit doesn't exist in the index, returns `nil`.
---@param name string The exit name.
---@return Tile?
function SchematicIndex:getExit(name)
    return self.exits[name]
end

---Returns the tile on which the provided exit is on. If the exit doesn't exist in the index, throws an error.
---@param name string The exit name.
---@return Tile
function SchematicIndex:assertGetExit(name)
    local exit = assert(self.exits[name], "Could not find tile for exit " .. tostring(name))
    return exit
end

---Returns the list of exits on this schematic - the exit name is the key, and the tile it corresponds to is the value.
---@return table<string, Tile>
function SchematicIndex:getExits()
    return self.exits
end

---Returns the list of neighbor schematics based on this schematic's exits.
---@return table<string, NeighborSchematicIndexData>
function SchematicIndex:getNeighborSchematics()
    return self.neighborSchematics
end

---Returns routing information for this schematic between two exits.
---If one or both of these exits do not exist, returns `nil`.
---@param exitIn string The inbound exit to check its route from.
---@param exitOut string The outbound exit to check its route towards.
---@return RoutingInfo?
function SchematicIndex:getRoutingInfo(exitIn, exitOut)
    return self.routingInfo[exitIn] and self.routingInfo[exitIn][exitOut]
end

---Returns routing information for this schematic between two exits.
---If one or both of these exits do not exist, throws an error.
---@param exitIn string The inbound exit to check its route from.
---@param exitOut string The outbound exit to check its route towards.
---@return RoutingInfo
function SchematicIndex:assertGetRoutingInfo(exitIn, exitOut)
	local routingInfo = assert(self:getRoutingInfo(exitIn, exitOut), string.format("Attempted to get routing info for an invalid pair of exits: %s -> %s", tostring(exitIn), tostring(exitOut)))
    return routingInfo
end

---Returns a tile that is in the specified station and track on this schematic.
---Returns `nil` if such tile doesn't exist.
---@param station string The station name.
---@param track string The track name.
---@return Tile?
function SchematicIndex:getTileForStationAndTrack(station, track)
    return self.stations[station] and self.stations[station].tracks[track]
end

---Returns a random tile from the specified station on this schematic.
---Returns `nil` if such tile doesn't exist.
---@param station string The station name.
---@return Tile?
function SchematicIndex:getRandomTrackTileForStation(station)
    local tracks = self.stations[station] and self.stations[station].tracks
    return tracks[_Utils.iTableGetRandomValue(_Utils.tableGetSortedKeys(tracks))]
end

---Returns the tile location or `"none"` when the tile doesn't exist.
---@private
---@param tile Tile? The tile to return the location of.
---@return string
function SchematicIndex:getTileLocation(tile)
    return tile and tile:getLocation() or "none"
end

---Prints the index contents to the log.
function SchematicIndex:print()
    _Log.write(string.format("Schematic index for station %s:", self.schematic.name), Severity.INFO, 2)
    _Log.write("- Tracks:", Severity.INFO, 2)
    for i, id in ipairs(_Utils.tableGetSortedKeys(self.tracks)) do
        local data = self.tracks[id]
        local trainLocation = self:getTileLocation(data.trainTarget)
        local shuntLocation = self:getTileLocation(data.shuntTarget)
        local semaphoreList = _StrSemaphoreList(data.semaphores)
        local stationID = data.stationID
        _Log.write(string.format("  - %s: P -> %s, M -> %s, semaphores: %s, station: %s", id, trainLocation, shuntLocation, semaphoreList, stationID), Severity.INFO, 2)
    end
    _Log.write("- Switches:", Severity.INFO, 2)
    for i, id in ipairs(_Utils.tableGetSortedKeys(self.switches)) do
        _Log.write(string.format("  - %s: %s", id, self:getTileLocation(self.switches[id])), Severity.INFO, 2)
    end
    _Log.write("- Semaphores:", Severity.INFO, 2)
    for i, id in ipairs(_Utils.tableGetSortedKeys(self.semaphores)) do
        _Log.write(string.format("  - %s: %s", id, self:getTileLocation(self.semaphores[id])), Severity.INFO, 2)
    end
    _Log.write("- Exits:", Severity.INFO, 2)
    for i, id in ipairs(_Utils.tableGetSortedKeys(self.exits)) do
        _Log.write(string.format("  - %s: %s", id, self:getTileLocation(self.exits[id])), Severity.INFO, 2)
    end
    _Log.write("- Blockades:", Severity.INFO, 2)
    for i, id in ipairs(_Utils.tableGetSortedKeys(self.blockades)) do
        local data = self.blockades[id]
        _Log.write(string.format("  - %s:", id), Severity.INFO, 2)
        _Log.write(string.format("    - tracks: %s", _StrTrackList(data.tracks)), Severity.INFO, 2)
        _Log.write(string.format("    - semaphores: %s", _StrSemaphoreList(data.semaphores)), Severity.INFO, 2)
        _Log.write(string.format("    - semaphores-N: %s", _StrSemaphoreList(data.semaphoresN)), Severity.INFO, 2)
    end
    _Log.write("- Stations:", Severity.INFO, 2)
    for i, id in ipairs(_Utils.tableGetSortedKeys(self.stations)) do
        local data = self.stations[id]
        _Log.write(string.format("  - %s:", id), Severity.INFO, 2)
        _Log.write(string.format("    - tracks:"))
        for j, track in ipairs(_Utils.tableGetSortedKeys(data.tracks)) do
            _Log.write(string.format("      - %s: %s", track, self:getTileLocation(data.tracks[track])))
        end
        _Log.write(string.format("    - platforms:"))
        for j, track in ipairs(_Utils.tableGetSortedKeys(data.platforms)) do
            _Log.write(string.format("      - %s: %s", track, data.platforms[track]))
        end
    end
    _Log.write("- Neighbor schematics:", Severity.INFO, 2)
    for i, id in ipairs(_Utils.tableGetSortedKeys(self.neighborSchematics)) do
        _Log.write(string.format("  - %s: %s", id, table.concat(self.neighborSchematics[id].exits, ", ")), Severity.INFO, 2)
    end
    _Log.write("- Entrance semaphores:", Severity.INFO, 2)
    for i, exit in ipairs(_Utils.tableGetSortedKeys(self.exitsToEntranceSemaphores)) do
        _Log.write(string.format("  - %s: %s", exit, self.exitsToEntranceSemaphores[exit]))
    end
    _Log.write("- Routing information:", Severity.INFO, 2)
    for i, exitIn in ipairs(_Utils.tableGetSortedKeys(self.routingInfo)) do
        for j, exitOut in ipairs(_Utils.tableGetSortedKeys(self.routingInfo[exitIn])) do
            local data = self.routingInfo[exitIn][exitOut]
            _Log.write(string.format("  - %s->%s: %s", exitIn, exitOut, data.traversable and "traversable" or "non-traversable"), Severity.INFO, 2)
        end
    end
end

return SchematicIndex