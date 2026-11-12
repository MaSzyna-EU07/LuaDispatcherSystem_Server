---Functions for dealing with logs.
local LogUtils = {}

LogUtils.verboseValue = 3

---Writes a message to the MaSzyna's log file or to the console depending on the API availability.
---@param text string The message to be printed.
---@param severity Severity? The severity.
---@param weight integer? The verbosity. The higher the value, the less important output.
function LogUtils.write(text, severity, weight)
	if LogUtils.verboseValue >= (weight or 1) then
		if _API then
			-- Server mode
			_API:log("LuaDispatcher -> [" .. (severity or Severity.DEBUG) .. "] " .. text)
		else
			-- Client mode
			print("LuaDispatcher -> [" .. (severity or Severity.DEBUG) .. "] " .. text)
		end
	end
end

return LogUtils