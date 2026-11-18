local Class = require("lua.core.class")
local api = require("eu07.events")

---@alias TEvent* userdata
---@alias TDynamicObject* userdata
---@alias MemcellValues {str: string, num1: number, num2: number}

-- Serves as an interface between all of the other Lua files and the simulator.
-- This is the ONLY file that should require the `eu07.events` module!
---@class API : Class
---@overload fun(): API
local API = Class:derive("API")

function API:new()
    -- The API has no state.
end

---Returns whether this server is running in dummy mode (standalone instead of as a part of real MaSzyna instance).
---@return boolean
function API:isGui()
    return api.gui
end

---Updates the dummy server instance's internals.
---Throws an error if it is a real MaSzyna instance.
---@param dt number Time delta in seconds.
function API:update(dt)
    api.update(dt)
end

---Prints a message to the log.
---@param message string The message to be printed to the log.
function API:log(message)
    api.writelog(message)
end

---Creates a new event.
---@param name string The event name.
---@param delay number The delay before this event is executed.
---@param randomDelay number Additional delay before this event is executed, randomly chosen from 0 to this value.
---@param handler function The function which will be called when this event is executed.
function API:eventCreate(name, delay, randomDelay, handler)
    api.event_create(name, delay, randomDelay, handler)
end

---Returns the name of the specified event.
---@param event TEvent* The event to retrieve the name from.
---@return string
function API:eventGetName(event)
    return api.event_getname(event)
end

---Returns whether the specified event exists by name.
---@param event string The event to check the existence of.
---@return boolean
function API:eventExists(event)
    return api.event_exists(event)
end

---Dispatches an event.
---@param event string The event name.
---@param activator TDynamicObject*? The vehicle to dispatch this event as, if any.
---@param delay number? The delay between calling this function and dispatching the event.
function API:eventDispatch(event, activator, delay)
    if not self:eventExists(event) then
        api.writeerrorlog("Failed to find event: " .. tostring(event))
        return
    end
    api.event_dispatch_n(event, activator, delay or 0)
end

---Dispatches an event if it exists.
---@param event string The event name.
---@param activator TDynamicObject*? The vehicle to dispatch this event as, if any.
---@param delay number? The delay between calling this function and dispatching the event.
function API:eventDispatchIfExists(event, activator, delay)
    if self:eventExists(event) then
        api.event_dispatch_n(event, activator, delay or 0)
    end
end

---Returns the timetable name of the specified vehicle.
---@param vehicle TDynamicObject* The vehicle to get the timetable from.
---@return string
function API:trainGetName(vehicle)
    return api.train_getname(vehicle)
end

---Sends a command to the specified vehicle.
---@param vehicle TDynamicObject* The vehicle to send the command to.
---@param values MemcellValues The command details to be sent to the vehicle.
function API:dynobjCommand(vehicle, values)
    api.dynobj_putvalues(vehicle, values)
end

---Spawns a new trainset.
---@param trainset string The trainset entry to be parsed and spawned.
function API:spawnTrainset(trainset)
    api.spawn_trainset(trainset)
end

---Retrieves values from the specified memcell.
---@param name string The memcell name.
---@return MemcellValues
function API:memcellRead(name)
    return api.memcell_read_n(name)
end

---Puts values into the specified memcell.
---@param name string The memcell name.
---@param values MemcellValues The values to be put into the memcell.
function API:memcellUpdate(name, values)
    api.memcell_update_n(name, values)
end

---Returns the current simulation time: hours, minutes.
---TODO: Replace with a proper call once time can be obtained directly from EXE.
---@return integer, integer
function API:getTime()
    local vals = self:memcellRead("__simulation.time")
    return vals.num1, vals.num2
end

return API