local api = {}

api.gui = true

local events = {}
local eventQueue = {}

function api.writelog(txt)
	print("lua: log: " .. txt)
end

function api.event_create(name, delay, randomdelay, func)
	events[name] = {delay = delay, randomdelay = randomdelay, func = func}
end

function api.event_exists(name)
	return events[name] ~= nil
end

function api.event_find(name)
	return ""
end

function api.event_dispatch_n(name, activator, delay)
	print("-----------------------> DISP: " .. name)
	local event = events[name]
	if event then
		table.insert(eventQueue, {time = delay + event.delay + math.random() * event.randomdelay, func = event.func})
	end
end



function api.update(dt)
	for i, event in ipairs(eventQueue) do
		event.time = event.time - dt
		if event.time <= 0 then
			event.func()
			event.delQueue = true
		end
	end
	for i = #eventQueue, 1, -1 do
		if eventQueue[i].delQueue then
			table.remove(eventQueue, i)
		end
	end
end

return api