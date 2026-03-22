local Class = require("lua.class")

-- Represents a blockade (C, Eap or Eac (SBL)) which is on a route.
---@class Blockade : Class
---@overload fun(route, data): Blockade
local Blockade = Class:derive("Blockade")

---Creates a new Blockade.
---@param route Route The route this blockade is assigned to.
---@param data table The blockade data.
function Blockade:new(route, data)
	_LogWrite("Creating blockade for route: " .. route.name, Severity.INFO, 3)
    self.route = route
    self.type = data.type
    self.bidirectional = data.bidirectional
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
	_LogWrite("Created blockade for route: " .. route.name, Severity.SUCCESS, 2)
end

---Sends an information about this blockade to the log.
---@param text string The message.
---@param severity Severity Severity.
---@param weight integer Weight.
function Blockade:tell(text, severity, weight)
	_LogWrite("Blockade(" .. tostring(self.route.name) .. "): " .. text, severity, weight)
end

---Marks the n-th block in this blockade as occupied.
---@param n integer The block index to be occupied.
function Blockade:occupyBlock(n)
    self:tell("Block " .. n .. " : occupied", Severity.INFO, 3)
    self:setSemaphoreForBlock(n, Speed.STOP, n == 1 and Speed.STOP or Speed.DIM)
end

---Marks the n-th block in this blockade as freed.
---@param n integer The block index to be freed.
function Blockade:freeBlock(n)
    self:tell("Block " .. n .. " : freed", Severity.INFO, 3)
    self:setSemaphoreForBlock(n, Speed.VMAX, n == 1 and Speed.VMAX or Speed.DIM)
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

return Blockade