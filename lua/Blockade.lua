local Class = require("lua.class")

-- Represents a blockade (C, Eap or Eac (SBL)) which is on a route.
---@class Blockade : Class
---@overload fun(route, data): Blockade
local Blockade = Class:derive("Blockade")

---Creates a new Blockade.
---@param route Route The route this blockade is assigned to.
---@param data table The blockade data.
function Blockade:new(route, data)
	_LogWrite("Creating blockade for route: " .. route.shortcut, Severity.INFO, 3)
    self.route = route
    self.type = data.type
    self.bidirectional = data.bidirectional
    ---@type table<integer, true>
    self.occupiedBlocks = {}
    ---@type {track: string, semaphore: string, semaphoreN: string?, next: string|integer?}[]
    self.blocks = data.blocks
    for i, block in ipairs(data.blocks) do
        -- Initialize each block by setting up callbacks.
        local track = _Obj:getTrack(block.track)
        if track then
            track:monitor("busy", self.occupyBlock, self, i)
            track:monitor("free", self.freeBlock, self, i)
        end -- Otherwise, data error (pointing to nonexistent track).
        -- By default, all blocks are free. If a block is occupied at the start, it will trigger an appropriate callback when vehicles are placed.
        self:freeBlock(i)
    end
    self.direction = false
	_LogWrite("Created blockade for route: " .. route.shortcut, Severity.SUCCESS, 2)
end

---Sends an information about this blockade to the log.
---@param text string The message.
---@param severity Severity Severity.
---@param weight integer Weight.
function Blockade:tell(text, severity, weight)
	_LogWrite("Blockade(" .. tostring(self.route.shortcut) .. "): " .. text, severity, weight)
end

---Marks the n-th block in this blockade as occupied.
---@param n integer The block index to be occupied.
function Blockade:occupyBlock(n)
    self:tell("Block " .. n .. " : occupied", Severity.INFO, 3)
    self.occupiedBlocks[n] = true
    if not self.direction then
        self:setSemaphoreForBlock(n, Speed.STOP, n == 1 and Speed.STOP or Speed.DIM)
    else
        self:setSemaphoreForBlock(n, n == #self.blocks and Speed.STOP or Speed.DIM, Speed.STOP)
    end
end

---Marks the n-th block in this blockade as freed.
---@param n integer The block index to be freed.
function Blockade:freeBlock(n)
    self:tell("Block " .. n .. " : freed", Severity.INFO, 3)
    self.occupiedBlocks[n] = nil
    if not self.direction then
        self:setSemaphoreForBlock(n, Speed.VMAX, n == 1 and Speed.VMAX or Speed.DIM)
    else
        self:setSemaphoreForBlock(n, n == #self.blocks and Speed.VMAX or Speed.DIM, Speed.VMAX)
    end
end

---Sets the speed for the semaphore for the `n`-th block of this blockade.
---@private
---@param n integer The block index.
---@param speed Speed? The speed for the semaphore.
---@param speedN Speed? The speed for the semaphore in the opposite direction.
function Blockade:setSemaphoreForBlock(n, speed, speedN)
    if n < 1 or n > #self.blocks then
        self:tell(string.format("Attempt to get block %s out of %s", n, #self.blocks), Severity.ERROR, 3)
        return
    end
    if speed and self.blocks[n].semaphore then
        local semaphore = _Obj:getSemaphore(self.blocks[n].semaphore)
        if semaphore then
            semaphore:setSpeed(speed)
        end -- Otherwise, data error (semaphore not found).
    end
    if speedN and self.blocks[n].semaphoreN then
        local semaphore = _Obj:getSemaphore(self.blocks[n].semaphoreN)
        if semaphore then
            semaphore:setSpeed(speedN)
        end -- Otherwise, data error (semaphore not found).
    end
end

---Returns whether all blocks are free in this blockade.
---@return boolean
function Blockade:isFree()
    return _Utils.tableIsEmpty(self.occupiedBlocks)
end

---Sets the direction on this blockade.
---@param direction boolean `true` for the blockade to go the other way, `false` to set it to its primary direction.
function Blockade:setDirection(direction)
    -- Can only switch direction if the blockade has this possibility and is free.
    if not self.bidirectional or not self:isFree() or self.direction == direction then
        return
    end
    self:tell("Switching direction to " .. (direction and "N" or "P"), Severity.INFO, 3)
    self.direction = direction
    -- Reset all semaphores to the other direction.
    -- The direction in which we update the semaphores is crucial, because when dimming semaphores back to front,
    -- the semaphore behind schedules itself to display an S5 signal just before it is dimmed itself.
    -- However, in the MaSzyna events, the S5 event - unlike the dim (_uszk) event - has a small delay.
    -- This means that the semaphore is dimmed at first, but shortly afterwards it starts displaying the S5 signal.
    if direction then
        for i = 1, #self.blocks do
            self:freeBlock(i)
        end
    else
        for i = #self.blocks, 1, -1 do
            self:freeBlock(i)
        end
    end
end

return Blockade