-- This is the LOVE2D wrapper for the server emulator.
-- The emulator is botched and will probably not serve all the intended functionality.
-- You should use the server in the simulator itself instead - its proper environment.

-- Define LOVE2D functions.
function love.draw()
    love.graphics.print("This is the server.\nWhile it does provide a way to not need to wait a few minutes until the simulator loads,\nit does not provide any visual features.\nPlease use the client alongside the server to view the traffic.\n\nVersion " .. VERSION .. " by jakubg1", 50, 50)
    love.graphics.print("Tracks:", 50, 150)
    for i, name in ipairs(_Obj:getTrackList()) do
        love.graphics.print(name, 50, 160 + i * 15)
    end
    love.graphics.print("Switches:", 250, 150)
    for i, name in ipairs(_Obj:getSwitchList()) do
        love.graphics.print(name, 250, 160 + i * 15)
    end
    love.graphics.print("Semaphores:", 450, 150)
    for i, name in ipairs(_Obj:getSemaphoreList()) do
        love.graphics.print(name, 450, 160 + i * 15)
    end
end

function love.update(dt)
    _API:update(dt)
end

-- Start the library.
local DS = require("lua.main")
local config = {
    scenario = "td",
    filename = "td.json"
}
DS.init(config)