local Class = require("lua.class")

---@class TileDatabase : Class
---@overload fun(): TileDatabase
local TileDatabase = Class:derive("TileDatabase")

---@class TileData
---@field tracks integer? Bitmask of tracks rendered on this tile (1 up and then clockwise per 45deg)
---@field background integer? Sprite (n, 1) rendered as the tile background.
---@field backgroundXY [integer, integer]? Sprite (x, y) rendered as the tile background.
---@field foreground integer? Sprite (n, 2) rendered on top of the background. Colored based on track color.
---@field dirs table<integer, "-"|"+"|"ab-"|"ab+"|"cd-"|"cd+">? Table of direction -> state associations. Use "-" and "+" for states in single switches and "ab-", "ab+", "cd-" and "cd+" for states in double switches.
---@field buffer integer? Sprite (n, 3) rendered alongside tracks.
---@field derailer integer? Sprite (n, 7) rendered on top of the tracks.
---@field derailerL integer? Sprite (n, 8) rendered on top of the tracks.
---@field semaphore integer? Sprites (n, 4), (n, 5) and (n, 6) used as semaphore body, first and second lamps respectively.
---@field blockade integer? Sprite (n, 9) rendered as the background, (n, 10) rendered as the foreground. Indicates blockade generator direction.
---@field doubleSwitch boolean? Whether the tile is a double switch.
---@field exit boolean? Whether the tile is an exit tile.

function TileDatabase:new()
    -- Tracks:
    --[[
    128  1   2        8  1  2
       \ | /           \ | /
    64 - * -  4      7 - * - 3
       / | \           / | \
    32  16   8        6  5  4
    ]]

    ---@type table<string, TileData>
    self.tiles = {
        [""] = {},
        ["track-"] = {tracks = 68},
        ["track\\"] = {tracks = 136},
        ["track|"] = {tracks = 17},
        ["track/"] = {tracks = 34},
        ["track+"] = {tracks = 85},
        ["trackX"] = {tracks = 170},
        ["platformP"] = {tracks = 68, background = 9},
        ["platformF"] = {tracks = 68, background = 10},
        ["curve1"] = {tracks = 33},
        ["curve2"] = {tracks = 66},
        ["curve3"] = {tracks = 132},
        ["curve4"] = {tracks = 9},
        ["curve5"] = {tracks = 18},
        ["curve6"] = {tracks = 36},
        ["curve7"] = {tracks = 72},
        ["curve8"] = {tracks = 144},
        ["switchL1"] = {tracks = 25, dirs = {[5] = "-", [4] = "+"}},
        ["switchL2"] = {tracks = 50, dirs = {[6] = "-", [5] = "+"}},
        ["switchL3"] = {tracks = 100, dirs = {[7] = "-", [6] = "+"}},
        ["switchL4"] = {tracks = 200, dirs = {[8] = "-", [7] = "+"}},
        ["switchL5"] = {tracks = 145, dirs = {[1] = "-", [8] = "+"}},
        ["switchL6"] = {tracks = 35, dirs = {[2] = "-", [1] = "+"}},
        ["switchL7"] = {tracks = 70, dirs = {[3] = "-", [2] = "+"}},
        ["switchL8"] = {tracks = 140, dirs = {[4] = "-", [3] = "+"}},
        ["switchR1"] = {tracks = 49, dirs = {[5] = "-", [6] = "+"}},
        ["switchR2"] = {tracks = 98, dirs = {[6] = "-", [7] = "+"}},
        ["switchR3"] = {tracks = 196, dirs = {[7] = "-", [8] = "+"}},
        ["switchR4"] = {tracks = 137, dirs = {[8] = "-", [1] = "+"}},
        ["switchR5"] = {tracks = 19, dirs = {[1] = "-", [2] = "+"}},
        ["switchR6"] = {tracks = 38, dirs = {[2] = "-", [3] = "+"}},
        ["switchR7"] = {tracks = 76, dirs = {[3] = "-", [4] = "+"}},
        ["switchR8"] = {tracks = 152, dirs = {[4] = "-", [5] = "+"}},
        ["switchW1"] = {tracks = 41, dirs = {[4] = "-", [6] = "+"}},
        ["switchW2"] = {tracks = 82, dirs = {[5] = "-", [7] = "+"}},
        ["switchW3"] = {tracks = 164, dirs = {[6] = "-", [8] = "+"}},
        ["switchW4"] = {tracks = 73, dirs = {[7] = "-", [1] = "+"}},
        ["switchW5"] = {tracks = 146, dirs = {[8] = "-", [2] = "+"}},
        ["switchW6"] = {tracks = 37, dirs = {[1] = "-", [3] = "+"}},
        ["switchW7"] = {tracks = 74, dirs = {[2] = "-", [4] = "+"}},
        ["switchW8"] = {tracks = 148, dirs = {[3] = "-", [5] = "+"}},
        ["switchD1"] = {tracks = 51, dirs = {[1] = "ab-", [2] = "ab+", [5] = "cd-", [6] = "cd+"}, doubleSwitch = true},
        ["switchD2"] = {tracks = 102, dirs = {[3] = "ab-", [2] = "ab+", [7] = "cd-", [6] = "cd+"}, doubleSwitch = true},
        ["switchD3"] = {tracks = 204, dirs = {[3] = "ab-", [4] = "ab+", [7] = "cd-", [8] = "cd+"}, doubleSwitch = true},
        ["switchD4"] = {tracks = 153, dirs = {[1] = "ab-", [8] = "ab+", [5] = "cd-", [4] = "cd+"}, doubleSwitch = true},
        ["switchT1"] = {tracks = 57},
        ["switchT2"] = {tracks = 114},
        ["switchT3"] = {tracks = 228},
        ["switchT4"] = {tracks = 201},
        ["switchT5"] = {tracks = 147},
        ["switchT6"] = {tracks = 39},
        ["switchT7"] = {tracks = 78},
        ["switchT8"] = {tracks = 156},
        ["switchDerL1"] = {tracks = 25, dirs = {[5] = "-", [4] = "+"}, derailerL = 8},
        ["switchDerL2"] = {tracks = 50, dirs = {[6] = "-", [5] = "+"}, derailerL = 1},
        ["switchDerL3"] = {tracks = 100, dirs = {[7] = "-", [6] = "+"}, derailerL = 2},
        ["switchDerL4"] = {tracks = 200, dirs = {[8] = "-", [7] = "+"}, derailerL = 3},
        ["switchDerL5"] = {tracks = 145, dirs = {[1] = "-", [8] = "+"}, derailerL = 4},
        ["switchDerL6"] = {tracks = 35, dirs = {[2] = "-", [1] = "+"}, derailerL = 5},
        ["switchDerL7"] = {tracks = 70, dirs = {[3] = "-", [2] = "+"}, derailerL = 6},
        ["switchDerL8"] = {tracks = 140, dirs = {[4] = "-", [3] = "+"}, derailerL = 7},
        ["switchDerR1"] = {tracks = 49, dirs = {[5] = "-", [6] = "+"}, derailer = 2},
        ["switchDerR2"] = {tracks = 98, dirs = {[6] = "-", [7] = "+"}, derailer = 3},
        ["switchDerR3"] = {tracks = 196, dirs = {[7] = "-", [8] = "+"}, derailer = 4},
        ["switchDerR4"] = {tracks = 137, dirs = {[8] = "-", [1] = "+"}, derailer = 5},
        ["switchDerR5"] = {tracks = 19, dirs = {[1] = "-", [2] = "+"}, derailer = 6},
        ["switchDerR6"] = {tracks = 38, dirs = {[2] = "-", [3] = "+"}, derailer = 7},
        ["switchDerR7"] = {tracks = 76, dirs = {[3] = "-", [4] = "+"}, derailer = 8},
        ["switchDerR8"] = {tracks = 152, dirs = {[4] = "-", [5] = "+"}, derailer = 1},
        ["buffer1"] = {tracks = 1, buffer = 1},
        ["buffer2"] = {tracks = 2, buffer = 2},
        ["buffer3"] = {tracks = 4, buffer = 3},
        ["buffer4"] = {tracks = 8, buffer = 4},
        ["buffer5"] = {tracks = 16, buffer = 5},
        ["buffer6"] = {tracks = 32, buffer = 6},
        ["buffer7"] = {tracks = 64, buffer = 7},
        ["buffer8"] = {tracks = 128, buffer = 8},
        ["derailer1"] = {tracks = 17, derailer = 1},
        ["derailer2"] = {tracks = 34, derailer = 2},
        ["derailer3"] = {tracks = 68, derailer = 3},
        ["derailer4"] = {tracks = 136, derailer = 4},
        ["derailer5"] = {tracks = 17, derailer = 5},
        ["derailer6"] = {tracks = 34, derailer = 6},
        ["derailer7"] = {tracks = 68, derailer = 7},
        ["derailer8"] = {tracks = 136, derailer = 8},
        ["derailerL1"] = {tracks = 17, derailerL = 1},
        ["derailerL2"] = {tracks = 34, derailerL = 2},
        ["derailerL3"] = {tracks = 68, derailerL = 3},
        ["derailerL4"] = {tracks = 136, derailerL = 4},
        ["derailerL5"] = {tracks = 17, derailerL = 5},
        ["derailerL6"] = {tracks = 34, derailerL = 6},
        ["derailerL7"] = {tracks = 68, derailerL = 7},
        ["derailerL8"] = {tracks = 136, derailerL = 8},
        ["curveDerL1"] = {tracks = 33, derailerL = 5},
        ["curveDerL2"] = {tracks = 66, derailerL = 6},
        ["curveDerL3"] = {tracks = 132, derailerL = 7},
        ["curveDerL4"] = {tracks = 9, derailerL = 8},
        ["curveDerL5"] = {tracks = 18, derailerL = 1},
        ["curveDerL6"] = {tracks = 36, derailerL = 2},
        ["curveDerL7"] = {tracks = 72, derailerL = 3},
        ["curveDerL8"] = {tracks = 144, derailerL = 4},
        ["curveDerR1"] = {tracks = 33, derailer = 2},
        ["curveDerR2"] = {tracks = 66, derailer = 3},
        ["curveDerR3"] = {tracks = 132, derailer = 4},
        ["curveDerR4"] = {tracks = 9, derailer = 5},
        ["curveDerR5"] = {tracks = 18, derailer = 6},
        ["curveDerR6"] = {tracks = 36, derailer = 7},
        ["curveDerR7"] = {tracks = 72, derailer = 8},
        ["curveDerR8"] = {tracks = 144, derailer = 1},
        ["semaphore1"] = {tracks = 17, semaphore = 1},
        ["semaphore2"] = {tracks = 34, semaphore = 2},
        ["semaphore3"] = {tracks = 68, semaphore = 3},
        ["semaphore4"] = {tracks = 136, semaphore = 4},
        ["semaphore5"] = {tracks = 17, semaphore = 5},
        ["semaphore6"] = {tracks = 34, semaphore = 6},
        ["semaphore7"] = {tracks = 68, semaphore = 7},
        ["semaphore8"] = {tracks = 136, semaphore = 8},
        ["blockade1"] = {tracks = 17, blockade = 1},
        ["blockade2"] = {tracks = 34, blockade = 2},
        ["blockade3"] = {tracks = 68, blockade = 3},
        ["blockade4"] = {tracks = 136, blockade = 4},
        ["blockade5"] = {tracks = 17, blockade = 5},
        ["blockade6"] = {tracks = 34, blockade = 6},
        ["blockade7"] = {tracks = 68, blockade = 7},
        ["blockade8"] = {tracks = 136, blockade = 8},
        ["arrow3"] = {tracks = 68, background = 12, foreground = 12, exit = true},
        ["arrow7"] = {tracks = 68, background = 11, foreground = 11, exit = true},
        ["arrow-"] = {tracks = 68, background = 13, foreground = 13, exit = true},
        ["loco"] = {background = 14, foreground = 14},
        ["square"] = {background = 15, foreground = 15},
        ["letter1"] = {backgroundXY = {9, 3}},
        ["letter2"] = {backgroundXY = {10, 3}},
        ["letter3"] = {backgroundXY = {11, 3}},
        ["letter4"] = {backgroundXY = {12, 3}},
        ["letter5"] = {backgroundXY = {13, 3}},
        ["letter6"] = {backgroundXY = {14, 3}},
        ["letter7"] = {backgroundXY = {15, 3}},
        ["letter8"] = {backgroundXY = {16, 3}},
        ["letter9"] = {backgroundXY = {17, 3}},
        ["letterA"] = {backgroundXY = {9, 4}},
        ["letterĄ"] = {backgroundXY = {10, 4}},
        ["letterB"] = {backgroundXY = {11, 4}},
        ["letterC"] = {backgroundXY = {12, 4}},
        ["letterĆ"] = {backgroundXY = {13, 4}},
        ["letterD"] = {backgroundXY = {14, 4}},
        ["letterE"] = {backgroundXY = {15, 4}},
        ["letterĘ"] = {backgroundXY = {16, 4}},
        ["letterF"] = {backgroundXY = {17, 4}},
        ["letterG"] = {backgroundXY = {9, 5}},
        ["letterH"] = {backgroundXY = {10, 5}},
        ["letterI"] = {backgroundXY = {11, 5}},
        ["letterJ"] = {backgroundXY = {12, 5}},
        ["letterK"] = {backgroundXY = {13, 5}},
        ["letterL"] = {backgroundXY = {14, 5}},
        ["letterŁ"] = {backgroundXY = {15, 5}},
        ["letterM"] = {backgroundXY = {16, 5}},
        ["letterN"] = {backgroundXY = {17, 5}},
        ["letterŃ"] = {backgroundXY = {9, 6}},
        ["letterO"] = {backgroundXY = {10, 6}},
        ["letterÓ"] = {backgroundXY = {11, 6}},
        ["letterP"] = {backgroundXY = {12, 6}},
        ["letterQ"] = {backgroundXY = {13, 6}},
        ["letterR"] = {backgroundXY = {14, 6}},
        ["letterS"] = {backgroundXY = {15, 6}},
        ["letterŚ"] = {backgroundXY = {16, 6}},
        ["letterT"] = {backgroundXY = {17, 6}},
        ["letterU"] = {backgroundXY = {9, 7}},
        ["letterV"] = {backgroundXY = {10, 7}},
        ["letterW"] = {backgroundXY = {11, 7}},
        ["letterX"] = {backgroundXY = {12, 7}},
        ["letterY"] = {backgroundXY = {13, 7}},
        ["letterZ"] = {backgroundXY = {14, 7}},
        ["letterŹ"] = {backgroundXY = {15, 7}},
        ["letterŻ"] = {backgroundXY = {16, 7}},
        ["tower"] = {backgroundXY = {17, 7}},
        ["crane"] = {backgroundXY = {9, 8}},
    }

    -- Name convention:
    -- Tile type can be:
    -- - track - Track shape as a character of -/|\+X
    -- - platform - P - passenger, F - freight
    -- - curve - Starting direction, turning left
    -- - switch - Starting direction (where two tracks converge), with a letter beforehand:
    --   - L - left switch, R - right switch, W - wye switch, D - double switch, T - triple switch
    -- - buffer - Starting direction (from which we are approaching the buffer)
    -- - derailer - Exit direction (which way we need to go to be affected by it)
    -- - semaphore - Exit direction (which way we need to go to be affected by it)
    -- - arrow - Direction it is pointing to, or -/|\ for double arrows
    -- - loco, square - Images
    -- - letter - Capital character
    self.compatibilityList = {
        [0] = "",
        "track-", "track|", "track+", "platformP", "track/", "track\\", "trackX", "platformF",
        "curve6", "curve3", "curve7", "curve2", "curve1", "curve8", "curve4", "curve5",
        "switchL3", "switchR3", "switchR7", "switchL7", "switchR1", "switchL5", "switchL1", "switchR5",
        "switchD2", "switchD3", "switchD4", "switchD1", "switchR2", "switchR6", "switchL6", "switchL2",
        "switchL8", "switchL4", "switchR4", "switchR8", "switchW6", "switchW8", "switchW4", "switchW2",
        "switchT6", "switchT8", "switchT4", "switchT2", "switchT7", "switchT3", "switchT1", "switchT5",
        "switchW7", "switchW3", "switchW1", "switchW5", "buffer7", "buffer3", "buffer1", "buffer5",
        "derailer3", "derailer7", "derailer5", "derailer1", "semaphore3", "semaphore7", "semaphore5", "semaphore1",
        "semaphore2", "semaphore6", "semaphore4", "semaphore8", "arrow7", "arrow3", "arrow-", "loco", "square",
        "buffer2", "buffer4", "buffer6", "buffer8", "derailer6", "derailer2", "derailer4", "derailer8"
    }
end

---Returns the data of the specified tile, or throws an error if it doesn't exist.
---@param id integer|string The tile ID.
---@return TileData
function TileDatabase:getTile(id)
    return assert(self.tiles[id] or self.tiles[self.compatibilityList[id]], "Invalid tile ID: " .. tostring(id))
end

---Returns the string ID from the integer ID, or the ID itself if it is already string ID.
---@param id integer|string The tile ID.
---@return string
function TileDatabase:idToString(id)
    return self.compatibilityList[id] or tostring(id)
end

---Returns a tile ID with the specified track layout.
---If no tile with that layout exists, returns `nil`.
---@param tracks integer The track mask.
---@param refID string? The tile ID to be used as a reference for maximum similarity.
---@return string?
function TileDatabase:getTileWithTracks(tracks, refID)
    if tracks == 0 then
        return ""
    end
    -- First pass: Try to match the original tile
    if refID then
        local ref = self:getTile(refID)
        for id, data in pairs(self.tiles) do
            if data.tracks == tracks and data.blockade == ref.blockade and data.derailer == ref.derailer and data.derailerL == ref.derailerL and data.exit == ref.exit and data.semaphore == ref.semaphore and data.background == ref.background then
                return id
            end
        end
    end
    -- Second pass: Raw track
    for id, data in pairs(self.tiles) do
        if data.tracks == tracks and not data.blockade and not data.derailer and not data.derailerL and not data.exit and not data.semaphore and not data.background then
            return id
        end
    end
end

return TileDatabase