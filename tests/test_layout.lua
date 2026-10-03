-- Layout.lua: the window's geometry. Pure, loaded with every WoW global forbidden.
dofile("tests/harness.lua")

local env = newPureEnv()
local Layout = loadPure(env, "Layout.lua").Layout
check(Layout ~= nil, "Layout.lua defines Gnomesweeper.Layout without touching any other global")

----------------------------------------------------------------------------
-- Size
----------------------------------------------------------------------------
local b = Layout.Size(9, 9)
eq(b.gridW, 216, "Beginner: 9 tiles of 24 is 216 wide")
eq(b.width, Layout.MIN_WIDTH, "Beginner is narrower than the title bar, so the window takes the minimum width")
eq(b.gridX, (Layout.MIN_WIDTH - 216) / 2, "...and the board is centred in it")
eq(b.height, Layout.CHROME_TOP + 216 + Layout.CHROME_BOTTOM, "the height is chrome + board + chrome")
eq(b.gridY, Layout.CHROME_TOP, "the board starts below the chrome")

local i = Layout.Size(16, 16)
eq(i.width, 16 * 24 + 2 * Layout.PAD, "Intermediate: the board plus its padding")
eq(i.gridX, Layout.PAD, "...with the padding either side")

local e = Layout.Size(30, 16)
eq(e.gridW, 720, "Expert: 720 wide")
eq(e.gridH, 384, "Expert: 384 high")
eq(e.width, 748, "Expert's window is 748 wide")
eq(e.height, 590, "Expert's window is 590 high")
eq(Layout.Size(9, 9, 32).gridW, 288, "a different tile size scales the board")

for _, d in ipairs({ { 9, 9 }, { 16, 16 }, { 30, 16 }, { 1, 1 }, { 50, 50 } }) do
    local s = Layout.Size(d[1], d[2])
    check(s.gridX >= 0 and s.gridX + s.gridW <= s.width, "the board fits inside the width: " .. d[1] .. "x" .. d[2])
    check(s.width >= Layout.MIN_WIDTH, "never narrower than the minimum: " .. d[1] .. "x" .. d[2])
end

----------------------------------------------------------------------------
-- FitScale
----------------------------------------------------------------------------
eq(Layout.FitScale(e.width, e.height, 1366, 768), 1, "Expert fits a 1366x768 screen at scale 1")
eq(Layout.FitScale(b.width, b.height, 1366, 768), 1, "Beginner fits at scale 1")
eq(Layout.FitScale(100, 100, 1366, 768, 1.5), 1.5, "a wanted scale that fits is honoured")

local small = Layout.FitScale(e.width, e.height, 1024, 600)
check(small < 1, "Expert on a 1024x600 screen is scaled down")
check(e.width * small <= 1024 * Layout.SCREEN_FRACTION and e.height * small <= 600 * Layout.SCREEN_FRACTION,
    "...so the window fits inside the screen")
check(small > 0.9, "...but only as much as it must (" .. small .. ")")

for _, scr in ipairs({ { 800, 600 }, { 1024, 768 }, { 1280, 720 }, { 640, 480 }, { 3840, 2160 } }) do
    local s = Layout.FitScale(e.width, e.height, scr[1], scr[2], 2)
    check(e.width * s <= scr[1] * Layout.SCREEN_FRACTION + 1e-9 and e.height * s <= scr[2] * Layout.SCREEN_FRACTION + 1e-9
        or s == Layout.MIN_SCALE, "never larger than the screen allows: " .. scr[1] .. "x" .. scr[2])
end

eq(Layout.FitScale(e.width, e.height, 100, 100), Layout.MIN_SCALE, "an absurdly small screen stops at the minimum scale")
eq(Layout.FitScale(300, 300, 0, 768), 1, "a zero-width screen (not up yet) leaves the wanted scale")
eq(Layout.FitScale(300, 300, 0 / 0, 768), 1, "a NaN screen leaves the wanted scale")
eq(Layout.FitScale(300, 300, 1366, 768, -2), 1, "a negative wanted scale is ignored")
eq(Layout.FitScale(300, 300, 1366, 768, "big"), 1, "a non-number wanted scale is ignored")
eq(Layout.FitScale(300, 300, 1366, 768, 0), 1, "a zero wanted scale is ignored")

----------------------------------------------------------------------------
-- The HUD strip's width, and the player's scale
----------------------------------------------------------------------------
eq(Layout.HudWidth(300), 272, "Beginner: the strip fills the window less its padding")
eq(Layout.HudWidth(412), Layout.HUD_MAX, "Intermediate: capped")
eq(Layout.HudWidth(748), Layout.HUD_MAX, "Expert: capped, so the counter, face and clock stay together")
eq(Layout.HUD_MAX, 340, "the cap")

eq(Layout.ValidUserScale(1), 1, "scale 1 is valid")
eq(Layout.ValidUserScale(0.5), 0.5, "the smallest is valid")
eq(Layout.ValidUserScale(1.5), 1.5, "the largest is valid")
eq(Layout.ValidUserScale(0.49), nil, "below the range is not")
eq(Layout.ValidUserScale(1.51), nil, "above the range is not")
eq(Layout.ValidUserScale(nil), nil, "nil is not")
eq(Layout.ValidUserScale("1"), nil, "a string is not")
eq(Layout.ValidUserScale(0 / 0), nil, "NaN is not")
eq(Layout.ValidUserScale(math.huge), nil, "infinity is not")

----------------------------------------------------------------------------
-- FormatTime
----------------------------------------------------------------------------
eq(Layout.FormatTime(0), "00:00", "zero")
eq(Layout.FormatTime(59), "00:59", "59 seconds")
eq(Layout.FormatTime(60), "01:00", "a minute")
eq(Layout.FormatTime(84), "01:24", "the storyboard's 01:24")
-- ClockState: the clock against the best to beat (#46)
eq(Layout.ClockState(10, nil), "normal", "no best: normal")
eq(Layout.ClockState(10, 60), "normal", "far from a 60 s best: normal")
eq(Layout.ClockState(49.9, 60), "normal", "...10.1 s before it: normal (near is at most the last 10 s)")
eq(Layout.ClockState(50, 60), "near", "the last 10 s of a 60 s best: near")
eq(Layout.ClockState(56.9, 60), "near", "...3.1 s before it: still near")
eq(Layout.ClockState(57, 60), "last", "the last 3 s: last (it flashes)")
eq(Layout.ClockState(60, 60), "last", "exactly at the best: not over yet")
eq(Layout.ClockState(60.01, 60), "over", "past it: over")
eq(Layout.ClockState(14, 20), "normal", "a 20 s best: near is its last 25% (5 s), so 6 s before is normal")
eq(Layout.ClockState(15, 20), "near", "...and 5 s before is near")
eq(Layout.ClockState(0, 8), "normal", "an 8 s best, at the start: normal")
eq(Layout.ClockState(5, 8), "last", "...its last 3 s: last (near, 2 s, is inside it)")
eq(Layout.ClockState(0, 2), "last", "a 2 s best: the whole game is the last 3 s")
eq(Layout.ClockState(5, 0), "normal", "a best of 0 (damaged): normal")
-- FormatTenths: for two times in the same second
eq(Layout.FormatTenths(42.6), "00:42.6", "tenths")
eq(Layout.FormatTenths(42.69), "00:42.6", "...truncated, like the whole seconds")
eq(Layout.FormatTenths(42), "00:42.0", "...a whole second shows .0")
eq(Layout.FormatTenths(0.3), "00:00.3", "...under a second")
eq(Layout.FormatTenths(42.7 + 1000 - 1000), "00:42.7", "...a float that is a hair under 42.7")
eq(Layout.FormatTenths(1200.5, 999), "16:39", "...never past the display cap")
eq(Layout.FormatTenths(-1), "00:00.0", "...never negative")
eq(Layout.FormatTime(999), "16:39", "the cap, 999 seconds")
eq(Layout.FormatTime(7.9), "00:07", "fractions are dropped")
eq(Layout.FormatTime(-5), "00:00", "never negative")

----------------------------------------------------------------------------
-- Saved positions
----------------------------------------------------------------------------
check(Layout.ValidPos({ left = 10, top = 700 }), "a corner is a valid position")
check(Layout.ValidPos({ left = -5, top = 0, extra = true }), "extra fields don't matter")
check(not Layout.ValidPos(nil), "nil is not a position")
check(not Layout.ValidPos(false), "false is not a position")
check(not Layout.ValidPos("10,10"), "a string is not a position")
check(not Layout.ValidPos({ left = 1 }), "a missing coordinate is not a position")
check(not Layout.ValidPos({ left = "1", top = 2 }), "a string coordinate is not a position")
check(not Layout.ValidPos({ left = 0 / 0, top = 2 }), "NaN is not a position")
check(not Layout.ValidPos({ left = 1, top = math.huge }), "infinity is not a position")

local l, t = Layout.ClampPos(100, 500, 300, 400, 1366, 768)
eq(l, 100, "a position inside the screen is left alone (left)")
eq(t, 500, "...(top)")
l, t = Layout.ClampPos(-50, 900, 300, 400, 1366, 768)
eq(l, 0, "off the left edge: pulled to 0")
eq(t, 768, "off the top: pulled to the top")
l, t = Layout.ClampPos(1300, 100, 300, 400, 1366, 768)
eq(l, 1066, "off the right edge: the right edge sits on the screen's")
eq(t, 400, "below the bottom: the bottom edge sits on the screen's")
l, t = Layout.ClampPos(10, 10, 2000, 1000, 1366, 768)
eq(l, 0, "a window wider than the screen sticks to the left")
eq(t, 768, "...and one taller sticks to the top")

done("test_layout")
