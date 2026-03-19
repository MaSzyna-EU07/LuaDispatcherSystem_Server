local Class = require("lua.class")

-- Represents a blockade (C, Eap or Eac (SBL)) which is on a route.
---@class Blockade : Class
---@overload fun(route, data): Blockade
local Blockade = Class:derive("Blockade")

---Creates a new Blockade.
---@param route Route The route this blockade is assigned to.
---@param data table The blockade data.
function Blockade:new(route, data)
	_LogWrite("Creating blockade for route: " .. route.name, 1, 3)
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
	_LogWrite("Created blockade for route: " .. route.name, 3, 2)
end

---Sends an information about this blockade to the log.
---@param text string The message.
---@param severity integer Severity.
---@param weight integer Weight.
function Blockade:tell(text, severity, weight)
	_LogWrite("Blockade(" .. tostring(self.route.name) .. "): " .. text, severity, weight)
end

---Marks the n-th block in this blockade as occupied.
---@param n integer The block index to be occupied.
function Blockade:occupyBlock(n)
    self:tell("Block " .. n .. " : occupied", 1, 3)
    self:setSemaphoreForBlock(n, 0)
    -- TODO: Handle semaphores in the other direction.
end

---Marks the n-th block in this blockade as freed.
---@param n integer The block index to be freed.
function Blockade:freeBlock(n)
    self:tell("Block " .. n .. " : freed", 1, 3)
    self:setSemaphoreForBlock(n, 1)
    -- TODO: Handle semaphores in the other direction.
end

---Sets the speed for the semaphore for the `n`-th block of this blockade.
---@private
---@param n integer The block index.
---@param speed integer The speed for the semaphore.
function Blockade:setSemaphoreForBlock(n, speed)
    if n < 1 or n > #self.blocks then
        -- Wrong block!
        -- TODO: Log
        return
    end
    local semaphore = _Obj:getSemaphore(self.blocks[n].semaphore)
    if semaphore then
        semaphore:setSpeed(speed, self:getNextForBlock(n))
    end -- Otherwise, data error (pointing to nonexistent semaphore).
end

---Gets the next semaphore or speed for the `n`-th block of this blockade.
---@private
---@param n integer The block index.
---@return integer|Semaphore?
function Blockade:getNextForBlock(n)
    local block = assert(self.blocks[n])
    local nextBlock = self.blocks[n + 1]
    if block.next then
        -- If `block.next` is defined, use that.
        return type(block.next) == "string" and _Obj:getSemaphore(block.next) or block.next
    elseif nextBlock then
        -- Otherwise, use the next block's semaphore, if it exists.
        return _Obj:getSemaphore(nextBlock.semaphore)
    end
    return 1
end

return Blockade