-- Layout.lua: the window's geometry, as pure functions. No frames, no client
-- API: tests/test_layout.lua loads it with every global but a few builtins
-- forbidden. Window.lua applies what this works out.
--
-- Units are the window's own (scale 1). The window is one glass frame: a fixed
-- band of chrome above the board (title, difficulty, the HUD), the board, and
-- the hint lines below it.

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local Layout = {}
Gnomesweeper.Layout = Layout

Layout.TILE = 24              -- one tile, in window units (the user scale comes with #8)
Layout.PAD = 14               -- side padding
Layout.MIN_WIDTH = 300        -- Beginner's 9 tiles are narrower than the title bar
Layout.CHROME_TOP = 138       -- title block 10..50, difficulty 58..82, HUD 90..130, a gap
Layout.CHROME_BOTTOM = 68     -- a gap, three hint lines, the bottom pad
Layout.HUD_MAX = 340          -- the counter, face and clock stay this close on a wide window
Layout.USER_SCALE_MIN = 0.5   -- the player's scale setting: /gsweep scale
Layout.USER_SCALE_MAX = 1.5
Layout.SCREEN_FRACTION = 0.95 -- the window never takes more than this of the screen
Layout.MIN_SCALE = 0.3

local function finite(n)
    return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end

-- The window for a cols x rows board: its size, and where the board sits in it
-- (centred when the window is wider than the board, which is what the minimum
-- width makes Beginner).
function Layout.Size(cols, rows, tile)
    tile = tile or Layout.TILE
    local gridW, gridH = cols * tile, rows * tile
    local width = math.max(Layout.MIN_WIDTH, gridW + 2 * Layout.PAD)
    return {
        width = width,
        height = Layout.CHROME_TOP + gridH + Layout.CHROME_BOTTOM,
        gridW = gridW, gridH = gridH,
        gridX = (width - gridW) / 2,
        gridY = Layout.CHROME_TOP,
        tile = tile,
    }
end

-- The HUD strip's width: the window's, less its padding, but never wider than
-- HUD_MAX, so the counter, the face and the clock stay together and balanced on
-- Expert instead of being stretched across 700 units.
function Layout.HudWidth(windowWidth)
    return math.min(windowWidth - 2 * Layout.PAD, Layout.HUD_MAX)
end

-- A scale the player typed: a number in range, or nil.
function Layout.ValidUserScale(n)
    if finite(n) and n >= Layout.USER_SCALE_MIN and n <= Layout.USER_SCALE_MAX then return n end
    return nil
end

-- The scale to put the window at: the wanted one (default 1), but never so big
-- that the window exceeds SCREEN_FRACTION of the screen. The screen is
-- UIParent's size, so a different UI scale or resolution changes the answer.
-- Floored to 3 places so rounding can never push the window past the limit.
-- (Clamping the POSITION can't fit a window that is simply too big.)
function Layout.FitScale(width, height, screenW, screenH, want)
    local s = (finite(want) and want > 0) and want or 1
    if finite(screenW) and finite(screenH) and screenW > 0 and screenH > 0 and width > 0 and height > 0 then
        s = math.min(s, screenW * Layout.SCREEN_FRACTION / width, screenH * Layout.SCREEN_FRACTION / height)
    end
    return math.max(Layout.MIN_SCALE, math.floor(s * 1000) / 1000)
end

-- Whole seconds (already capped by the caller) as mm:ss. 999 is 16:39.
function Layout.FormatTime(seconds)
    seconds = math.max(0, math.floor(seconds))
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- A saved position is the window's top-left corner in UIParent units, measured
-- from the screen's bottom-left: { left, top }. Anything else is ignored.
function Layout.ValidPos(p)
    return type(p) == "table" and finite(p.left) and finite(p.top)
end

-- Keep a window of on-screen size w x h (its size times its scale) inside the
-- screen. A window bigger than the screen sticks to the top-left.
function Layout.ClampPos(left, top, w, h, screenW, screenH)
    left = math.min(math.max(left, 0), math.max(0, screenW - w))
    top = math.min(math.max(top, math.min(h, screenH)), screenH)
    return left, top
end
