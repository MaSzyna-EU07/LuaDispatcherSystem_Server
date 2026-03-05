local api = {}

api.gui = true

function api.writelog(txt)
	print("lua: log: " .. txt)
end

function api.event_preparefunc(func)
	return
end

function api.event_create(name, delay, randomdelay, func)
	return
end

function api.event_dispatch_n(event, activator, delay)
	print("-----------------------> DISP: " .. event)
end





local eventLoops = {}

function api.update(dt)
	for i, event in ipairs(eventLoops) do
		event.time = event.time - dt
		if event.time <= 0 then
			event.func()
			event.time = event.delay
		end
	end
end

function api.createLoopEvent(func, delay)
	table.insert(eventLoops, {func = func, time = delay, delay = delay})
end

return api