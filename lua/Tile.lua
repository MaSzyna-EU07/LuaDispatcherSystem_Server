local class = require("lua.class")

---@class Tile : Class
---@overload fun(schematic: Schematic, x: integer, y: integer): Tile
local Tile = class:derive("Tile")

---Creates a new Tile.
---@param schematic Schematic The station schematic this Tile is a part of.
---@param x integer The X coordinate of this tile.
---@param y integer The Y coordinate of this tile.
function Tile:new(schematic, x, y)
	self.schematic = schematic
	self.x, self.y = x, y
	self.size = 14
	self.offset = 0

	---@type string
	self.id = "" -- Tile ID, which determines its appearance and some logic.
	self.electrified = true -- Whether the track on this tile is electrified.
	---@type string?
	self.trackID = nil -- Track ID for this tile.
	---@type string?
	self.switchID = nil -- Switch ID for this tile.
	self.switchFlip = false -- Whether the switch's sides are flipped ("+" means straight, "-" means left/right).
	self.switchFlipABCD = false -- Whether the double switch's sides are flipped (`ab` is on the right side, `cd` is on the left side).
	---@type string?
	self.semaphoreID = nil -- Semaphore ID for this tile.
	---@type SemaphoreType?
	self.semaphoreType = nil -- Semaphore type for this tile.
	self.semaphoreAllowTrain = false -- Whether this tile's semaphore can display a clear signal for non-shunting trains.
	self.semaphoreAllowShunt = false -- Whether this tile's semaphore can display a shunting signal.
	self.semaphoreAllowSz = false -- Whether this tile's semaphore can display an Sz signal.
	self.semaphoreShape = false -- Whether this tile's semaphore is a shape semaphore.
	self.semaphoreNoW24 = false -- Whether this tile's semaphore is UNABLE to display the W24 sign.
	self.semaphoreNoDanger = false -- Whether this tile's semaphore has no danger light (next semaphore must be displaying a >=100 speed).
	self.semaphoreOwnShield = false -- Whether this tile's semaphore has its own shield signal and thus should not be considered as a next semaphore when deciding which signal should be used.
	---@type table<integer, integer>
	self.semaphoreShortSpeed = {} -- The tile's short speeds. Maps speeds on the next semaphore to maximum speeds on this semaphore.
	self.semaphoreFourPhase = false -- Whether this tile's semaphore is four phase (when two semaphores ahead are S1, this one will display a fake reduced speed next).
	---@type string|Speed?
	self.semaphoreNext = nil -- The default next speed or semaphore when the pathfinder doesn't specify one.
	---@type string?
	self.itineraryEndID = nil -- Itinerary end ID for this Tile. TODO: Later on, check whether we need this. The only reason we would need this is for dispatcher algorithms.
	self.maxSpeed = math.huge -- The maximum speed for this Tile. Is `math.huge` if no limit is specified.
	self.maxSpeedPlus = math.huge -- Maximum speed for this Tile when the switch on this Tile is set to `true` ("+"). Is `math.huge` if no limit is specified.
	self.maxSpeedMinus = math.huge -- Maximum speed for this Tile when the switch on this Tile is set to `false` ("-"). Is `math.huge` if no limit is specified.
	self.trainTarget = false -- Whether this Tile can be used as a target for train paths.
	self.shuntTarget = false -- Whether this Tile can be used as a target for shunting paths.
	self.targetW24 = false -- Whether this Tile's target will make its pathfinding semaphore display a W24 signal.
	self.forbidTrain = false -- Whether this Tile is excluded from pathfinding train signals.
	self.forbidShunt = false -- Whether this Tile is excluded from pathfinding shunting signals.
	---@type string?
	self.blockadeID = nil -- The ID of this blockade.
	---@type string?
	self.warp = nil -- An index (shortcut) of the schematic to jump to when this tile is clicked.
	---@type string?
	self.warpID = nil -- A unique ID of this exit point.
	---@type string?
	self.warpTargetID = nil -- The ID of the exit point on the target schematic this exit point leads to.
	---@type string?
	self.command = nil -- A command to be sent to the server when this tile is right clicked.
end

---Returns whether this Tile is empty.
---@return boolean
function Tile:isEmpty()
	return self.id == ""
end

---Returns whether this Tile is a track, regardless of its type or what else is with it.
---@return boolean
function Tile:isTrack()
	return self:getData().tracks ~= nil
end

---Returns whether this Tile is a switch, regardless of its type.
---@return boolean
function Tile:isSwitch()
	return self:getData().dirs ~= nil
end

---Returns whether this Tile is a double switch ("rozjazd krzyżowy").
---@return boolean
function Tile:isDoubleSwitch()
	return self:getData().doubleSwitch
end

---Returns whether this Tile is a semaphore.
---@return boolean
function Tile:isSemaphore()
	return self:getData().semaphore ~= nil
end

---Returns whether this Tile is a blockade generator.
---@return boolean
function Tile:isBlockadeGenerator()
	return self:getData().blockade ~= nil
end

---Returns whether this Tile is an exit point.
---@return boolean
function Tile:isExitPoint()
	return self:getData().exit ~= nil
end

---Returns whether this Tile is a buffer.
---@return boolean
function Tile:isBuffer()
	return self:getData().buffer ~= nil
end

--######################################--
---------------- L O G I C ---------------
--######################################--

---Returns tile data coming from its ID.
---@return TileData
function Tile:getData()
	return _TileDB:getTile(self.id)
end

---Returns the neighbor tile in the provided direction, or `nil` if we're out of bounds.
---@param dir integer The direction for which the tile should be returned.
---@return Tile?
function Tile:getNeighbor(dir)
	return self.schematic:getTile(self.x + _DIRS[dir].x, self.y + _DIRS[dir].y)
end

---Returns `true` if this Tile has a track in that direction.
---@param dir integer The direction for the track to be looked for.
---@return boolean
function Tile:hasTrackInDirection(dir)
	local data = self:getData()
	return data.tracks and _Utils.getBit(data.tracks, dir) or false
end

---Returns `true` if this Tile has a track in the specified direction, taking the switch state into account.
---@param dir integer The direction for the track to be looked for.
---@return boolean
function Tile:hasTraversibleTrackInDirection(dir)
	if not self:hasTrackInDirection(dir) then
		return false
	end
	local data = self:getData()
	if not data.dirs then
		-- No switch.
		return true
	end
	local dirData = data.dirs[dir]
	if not dirData then
		-- This direction is not governed by the switch.
		return true
	end
	local switchState = self:getSwitchState(self:flipSwitchSuffix(dirData:sub(1, #dirData - 1)))
	local expectedState = dirData:sub(#dirData) == "+"
	return switchState == nil or (switchState.state ~= self.switchFlip) == expectedState
end

---Returns a list of directions for pathfinders to be able to go towards, starting from this tile.
---@return integer[]
function Tile:getTrackDirections()
	local results = {}
	for i = 1, 8 do
		if self:hasTrackInDirection(i) then
			table.insert(results, i)
		end
	end
	return results
end

---Returns a list of directions this tile is currently traversible in. Takes switch state into account.
---@return integer[]
function Tile:getTraversibleTrackDirections()
	local results = {}
	for i = 1, 8 do
		if self:hasTraversibleTrackInDirection(i) then
			table.insert(results, i)
		end
	end
	return results
end

---Returns a list of 0 to 3 directions for pathfinders to be able to go towards, when going from the specified direction.
---@param sourceDir integer The direction from which we are going from.
---@return integer[]
function Tile:getPossibleTrackDirections(sourceDir)
	local straight = _InvertDir(sourceDir)
	local left = (straight - 2) % 8 + 1
	local right = straight % 8 + 1
	local results = {}
	if self:hasTrackInDirection(straight) then
		table.insert(results, straight)
	end
	if self:hasTrackInDirection(left) then
		table.insert(results, left)
	end
	if self:hasTrackInDirection(right) then
		table.insert(results, right)
	end
	return results
end

---Returns a direction for pathfinders to go towards, when going from the specified direction, depending on the switch states.
---Returns `nil` if we hit a dead end.
---@param sourceDir integer The direction from which we are going from.
---@return integer?
function Tile:getNextTrackDirection(sourceDir)
	for i = 1, 8 do
		if i ~= sourceDir and self:hasTraversibleTrackInDirection(i) then
			return i
		end
	end
end

---Returns `true` if this Tile is behind a switch which is switched the other way and shares the track ID with this Tile. 
---@param sourceDir integer? If specified, only the directions coming from the specified direction will be considered.
---@return boolean
function Tile:isDimmedBySwitch(sourceDir)
	if not self.trackID then
		return false
	end
	local dirs = sourceDir and {self:getNextTrackDirection(sourceDir)} or self:getTraversibleTrackDirections()
	for i, dir in ipairs(dirs) do
		local tile = self:getNeighbor(dir)
		if tile and tile.trackID == self.trackID then
			local invDir = _InvertDir(dir)
			if tile:isSwitch() and not tile:hasTraversibleTrackInDirection(invDir) then
				return true -- Direct check
			elseif tile:isDimmedBySwitch(invDir) then
				return true -- Indirect check
			end
		end
	end
	return false
end

---Returns whether this Tile is a target for the specified path mode.
---@param mode PathMode The path mode to be checked against.
---@return boolean
function Tile:isTargetForMode(mode)
	if mode == PathMode.TRAIN then
		return self.trainTarget
	elseif mode == PathMode.SHUNT then
		return self.shuntTarget
	end
	return false
end

---Returns whether this Tile is a valid target for whether the semaphore pathfinding to it has a W24 signal.
---@param w24 boolean Whether the initial semaphore can display the W24 signal.
---@return boolean
function Tile:isTargetForW24(w24)
	return w24 or not self.targetW24
end

---Returns whether this Tile is traversible by the specified path mode.
---@param mode PathMode The path mode to be checked against.
---@return boolean
function Tile:isPathModeAllowed(mode)
	if mode == PathMode.TRAIN then
		return not self.forbidTrain
	elseif mode == PathMode.SHUNT then
		return not self.forbidShunt
	end
	return true
end

---Returns the current track state in the simulation.
---If no track ID is specified for this tile, the function will return `nil`.
---@return TrackState?
function Tile:getTrackState()
	return self.trackID and _Obj:getTrackState(self.trackID)
end

---Returns whether this tile's track is occupied, or `nil` if no track is specified for this tile.
---@return boolean?
function Tile:isTrackOccupied()
	local state = self:getTrackState()
	return state and state.occupied
end

---Returns whether this tile's track is reserved, or `nil` if no track is specified for this tile.
---@return boolean?
function Tile:isTrackReserved()
	local state = self:getTrackState()
	return state and state.reserved
end

---Returns whether this tile's track is neither occupied nor reserved, or `nil` if no track is specified for this tile.
---@return boolean?
function Tile:isTrackClear()
	local state = self:getTrackState()
	return state and not (state.occupied or state.reserved)
end

---Returns the state for this tile's switch, or `nil` if no switch is specified for this tile.
---@param suffix "ab"|"cd"? Used for double switches, where the suffix determines which subswitch state should be returned.
---@return SwitchState?
function Tile:getSwitchState(suffix)
	return self.switchID and _Obj:getSwitchState(self.switchID .. (suffix or ""))
end

---Returns whether this tile's switch has been forcefully switched, or `nil` if no switch is specified for this tile.
---@return boolean?
function Tile:isSwitchForced()
	local main = self:getSwitchState()
	local ab = self:getSwitchState("ab")
	local cd = self:getSwitchState("cd")
	return (main and main.forced) or (ab and ab.forced) or (cd and cd.forced)
end

---Returns the direction towards which this tile's semaphore is pointing, or `nil` if there's no semaphore.
---@return integer?
function Tile:getSemaphoreDirection()
	return self:getData().semaphore
end

---If this Tile is a semaphore, returns the track ID on the tile in front of it.
---Returns `nil` if this Tile is not a semaphore or there's no track in front of it.
---@return string?
function Tile:getSemaphorePrevTrackID()
	local prevTile = self:isSemaphore() and self:getNeighbor(_InvertDir(assert(self:getSemaphoreDirection()))) or nil
	return prevTile and prevTile.trackID
end

---Returns this tile's semaphore state, or `nil` if no semaphore is specified for this tile.
---@return SemaphoreState?
function Tile:getSemaphoreState()
	return self.semaphoreID and _Obj:getSemaphoreState(self.semaphoreID)
end

---Returns whether this tile's semaphore is displaying a stop signal (S1 or Ms1), or `nil` if there's no semaphore.
---@return boolean?
function Tile:isSemaphoreStop()
	local state = self:getSemaphoreState()
	return state and (state.image == "s1" or state.image == "ms1")
end

---Returns whether any route can ever be reserved by this semaphore.
---@return boolean
function Tile:isSemaphoreControllable()
	return self.semaphoreAllowTrain or self.semaphoreAllowShunt or self.semaphoreAllowSz
end

---Returns the direction towards which this tile's blockade is pointing, or `nil` if there's no blockade.
---@return integer?
function Tile:getBlockadeDirection()
	return self:getData().blockade
end

---Returns the current maximum speed on this Tile, or `nil` if there is no speed limit.
---@return number
function Tile:getSpeed()
	local main = self:getSwitchState()
	local ab = self:getSwitchState("ab")
	local cd = self:getSwitchState("cd")
	return self:getSpeedForSwitchStates({[""] = main and main.state, ab = ab and ab.state, cd = cd and cd.state})
end

---Returns the maximum speed on this Tile were the switches in the specified states, or `nil` if there is no speed limit.
---@param states table<""|"ab"|"cd", boolean?>
---@return number
function Tile:getSpeedForSwitchStates(states)
	local speed = self.maxSpeed
	if self:isSwitch() then
		local switchSpeed
		if self:isDoubleSwitch() then
			-- Straight = "-", curve = "+"
			switchSpeed = states["ab"] ~= states["cd"] and self.maxSpeedPlus or self.maxSpeedMinus
		else
			switchSpeed = states[""] and self.maxSpeedPlus or self.maxSpeedMinus
		end
		speed = math.min(speed, switchSpeed)
	end
	return speed
end

---Returns the maximum speed on this Tile when going from dir1 to dir2, or `nil` if no speed limit exists for that relation.
---@param dir1 integer? First direction.
---@param dir2 integer? Second direction.
---@return number
function Tile:getSpeedForDirections(dir1, dir2)
	return self:getSpeedForSwitchStates(self:getSwitchStatesForDirections(dir1, dir2))
end

---Given two directions, if this Tile is a switch tile, returns a table mapping switch suffixes to their states for this Tile.
---@param dir1 integer? First direction.
---@param dir2 integer? Second direction.
---@return table<""|"ab"|"cd", boolean?>
function Tile:getSwitchStatesForDirections(dir1, dir2)
	local switchStates = {}
	local data = self:getData()
	if not data.dirs then
		return switchStates
	end
	if dir1 then
		local dirData1 = data.dirs[dir1]
		if dirData1 then
			local state = (dirData1:sub(#dirData1) == "+") ~= self.switchFlip
			switchStates[self:flipSwitchSuffix(dirData1:sub(1, dirData1:len() - 1))] = state
		end
	end
	if dir2 then
		local dirData2 = data.dirs[dir2]
		if dirData2 then
			local state = (dirData2:sub(#dirData2) == "+") ~= self.switchFlip
			switchStates[self:flipSwitchSuffix(dirData2:sub(1, dirData2:len() - 1))] = state
		end
	end
	return switchStates
end

---Returns a flipped double switch suffix if the `switchFlipABCD` property is set on this tile.
---@param suffix ""|"ab"|"cd"? The switch suffix to be flipped.
---@return string?
function Tile:flipSwitchSuffix(suffix)
	if not suffix or suffix == "" or not self.switchFlipABCD then
		return suffix
	end
	return suffix == "ab" and "cd" or "ab"
end

---Returns the destination tile, if this Tile is a warp tile and the destinations are properly set.
---@return Tile?
function Tile:getWarpDestination()
	if not self.warp or not self.warpTargetID then
        -- No warp specified
        _LogWrite("Warp destination search failed: no warp specified", Severity.INFO, 2)
        return
    end
    local schematic = _Obj:getSchematic(self.warp)
    if not schematic then
        -- Warp is to an invalid schematic
        _LogWrite(string.format("Warp destination search failed: target schematic `%s` not found", self.warp), Severity.INFO, 2)
        return
    end
    local destination = schematic.index:getExit(self.warpTargetID)
    if not destination then
        -- Exit not found on the target schematic
        _LogWrite(string.format("Warp destination search failed: target exit point `%s` not found on schematic `%s`", self.warpTargetID, schematic.shortcut), Severity.INFO, 2)
        return
    end
    return destination
end

--################################################--
---------------- S I M U L A T I O N ---------------
--################################################--

---Sends a command to the server to change the state of this tile's track.
---@param state "free"|"busy"|"res" The new state for this track to be set.
function Tile:sendTrackState(state)
	if self.trackID then
		_Com.sendCommand("t " .. self.trackID .. " " .. state)
	end
end

---Sends a command to the server to change this tile's switch state.
---@param state boolean `false` is the "-" position, `true` is the "+" position.
---@param suffix "ab"|"cd"? Used for double switches, where the suffix determines which subswitch state should be changed.
function Tile:sendSwitchState(state, suffix)
	if self.switchID then
		_Com.sendCommand("j " .. self.switchID .. (suffix or "") .. " " .. (state and "+" or "-"))
	end
end

---Sends a command to the server to unforce tile's switch. ("kasowanie rozprucia rozjazdu")
function Tile:sendSwitchUnforce()
	if self.switchID then
		_Com.sendCommand("ju " .. self.switchID)
		_Com.sendCommand("ju " .. self.switchID .. "ab")
		_Com.sendCommand("ju " .. self.switchID .. "cd")
	end
end

---Sends a command to the server to set the speeds on this tile's semaphore.
---@param this Speed The current speed to be displayed.
---@param next Speed|string? The next speed or the next semaphore ID to be displayed.
---@param extras "w24"? An additional token to be sent, for example to show W24.
function Tile:sendSemaphoreState(this, next, extras)
	if self.semaphoreID then
		next = type(next) == "string" and " :" .. next or (next and (" " .. next) or "")
		_Com.sendCommand("s " .. self.semaphoreID .. " " .. (this == math.huge and "1" or this) .. next .. (extras and (" " .. extras) or ""))
	end
end

---Sends a command to the server to display the stop speed on this tile's semaphore.
function Tile:sendSemaphoreStop()
	self:sendSemaphoreState(0)
end

---Sends a command to the server to cancel this tile's semaphore's itinerary.
function Tile:sendSemaphoreUnreserve()
	if self.semaphoreID then
		_Com.sendCommand("su " .. self.semaphoreID)
	end
end

---Sends a command to the server to send a command to the train on this tile's track.
---@param str string The command string.
---@param num1 number? The first number.
---@param num2 number? The second number.
function Tile:sendTrainCommand(str, num1, num2)
	if self.trackID then
		_Com.sendCommand("tc " .. self.trackID .. " " .. str .. (num1 and (" " .. num1) or "") .. (num2 and (" " .. num2) or ""))
	end
end

---Sends a custom specified command to the server.
function Tile:sendCustomCommand()
	if self.command then
		_Com.sendCommand(self.command)
	end
end

--####################################--
---------------- D A T A ---------------
--####################################--

---Serializes this Tile's data to be saved. If this Tile is empty, `nil` is returned to save space.
---@return table?
function Tile:serialize()
	if self.id == "" then
		return nil
	end
	local t =  {
		id = _TileDB:idToString(self.id),
		--electrified = self.electrified,
		trackID = self.trackID,
		switchID = self.switchID,
		switchFlip = self.switchFlip or nil,
		switchFlipABCD = self.switchFlipABCD or nil,
		semaphoreID = self.semaphoreID,
		semaphoreType = self:isSemaphore() and (self.semaphoreType ~= SemaphoreType.SEM and self.semaphoreType or nil) or nil,
		semaphoreAllowTrain = self.semaphoreAllowTrain or nil,
		semaphoreAllowShunt = self.semaphoreAllowShunt or nil,
		semaphoreAllowSz = self.semaphoreAllowSz or nil,
		semaphoreShape = self.semaphoreShape or nil,
		semaphoreNoW24 = self.semaphoreNoW24 or nil,
		semaphoreNoDanger = self.semaphoreNoDanger or nil,
		semaphoreOwnShield = self.semaphoreOwnShield or nil,
		semaphoreShortSpeed = not _Utils.tableIsEmpty(self.semaphoreShortSpeed) and _Utils.stringifyKeys(self.semaphoreShortSpeed) or nil,
		semaphoreFourPhase = self.semaphoreFourPhase or nil,
		semaphoreNext = self.semaphoreNext,
		itineraryEndID = self.itineraryEndID,
		maxSpeed = self.maxSpeed ~= math.huge and self.maxSpeed or nil,
		maxSpeedPlus = self.maxSpeedPlus ~= math.huge and self.maxSpeedPlus or nil,
		maxSpeedMinus = self.maxSpeedMinus ~= math.huge and self.maxSpeedMinus or nil,
		trainTarget = self.trainTarget or nil,
		shuntTarget = self.shuntTarget or nil,
		targetW24 = self.targetW24 or nil,
		forbidTrain = self.forbidTrain or nil,
		forbidShunt = self.forbidShunt or nil,
		blockadeID = self.blockadeID,
		warp = self.warp,
		warpID = self.warpID,
		warpTargetID = self.warpTargetID,
		command = self.command
	}
	if not self.electrified then
		-- TODO: Figure out a way how to convert (true, false) into (nil, false) in a single expression.
		t.electrified = false
	end
	return t
end

---Deserializes previously saved Tile's data and loads it into this tile.
---@param t table? Data to be deserialized. `nil` will make nothing happen.
function Tile:deserialize(t)
	if not t then
		return
	end
	self.id = t.id or ""
	self.electrified = t.electrified ~= false
	self.trackID = t.trackID
	self.switchID = t.switchID
	self.switchFlip = t.switchFlip == true
	self.switchFlipABCD = t.switchFlipABCD == true
	self.semaphoreID = t.semaphoreID
	self.semaphoreType = t.semaphoreID and (t.semaphoreType or SemaphoreType.SEM) or nil
	self.semaphoreAllowTrain = t.semaphoreAllowTrain == true
	self.semaphoreAllowShunt = t.semaphoreAllowShunt == true
	self.semaphoreAllowSz = t.semaphoreAllowSz == true
	self.semaphoreShape = t.semaphoreShape == true
	self.semaphoreNoW24 = t.semaphoreNoW24 == true
	self.semaphoreNoDanger = t.semaphoreNoDanger == true
	self.semaphoreOwnShield = t.semaphoreOwnShield == true
	self.semaphoreShortSpeed = t.semaphoreShortSpeed and (type(t.semaphoreShortSpeed) == "table" and _Utils.numifyKeys(t.semaphoreShortSpeed) or {[0] = t.semaphoreShortSpeed}) or {}
	self.semaphoreFourPhase = t.semaphoreFourPhase == true
	self.semaphoreNext = t.semaphoreNext
	self.itineraryEndID = t.itineraryEndID
	self.maxSpeed = t.maxSpeed or math.huge
	self.maxSpeedPlus = t.maxSpeedPlus or math.huge
	self.maxSpeedMinus = t.maxSpeedMinus or math.huge
	self.trainTarget = t.trainTarget == true
	self.shuntTarget = t.shuntTarget == true
	self.targetW24 = t.targetW24 == true
	self.forbidTrain = t.forbidTrain == true
	self.forbidShunt = t.forbidShunt == true
	self.blockadeID = t.blockadeID
	self.warp = t.warp
	self.warpID = t.warpID
	self.warpTargetID = t.warpTargetID
	self.command = t.command
end

return Tile
