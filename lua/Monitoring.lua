local Class = require("lua.core.class")

-- This class is used to implement subscriptions (not the monthly payments, you dummie!).
-- No, not the YouTube or Twitch kind either!
--
-- Objects of this class should reside in the objects you can subscribe to (monitor) in various categories.
-- Then, as various things happen, you can call functions without linking stuff directly to the classes!
---@class Monitoring : Class
---@overload fun(): Monitoring
local Monitoring = Class:derive("Monitoring")

function Monitoring:new()
    ---@type table<string, {f: function, params: any[]}[]>
    self.actions = {}
end

---Adds a new function for the specified action to be executed.
---Note that once the function is added, it cannot be removed.
---@param action string The action ID to be monitored.
---@param f function The function to be called when the action is performed.
---@param ... any Parameters for the function to be executed with.
function Monitoring:monitor(action, f, ...)
    self.actions[action] = self.actions[action] or {}
    table.insert(self.actions[action], {f = f, params = {...}})
end

---Calls an action.
---If any functions have been registered to this action, all these functions will be executed.
---@param action string The action ID to be executed.
function Monitoring:call(action)
    if self.actions[action] then
        for i, f in ipairs(self.actions[action]) do
            f.f(unpack(f.params))
        end
    end
end

return Monitoring