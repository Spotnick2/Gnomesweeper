-- #46: the clock warns as you near your best (yellow), flashes in its last 3
-- seconds, and goes red past it; it keeps its colour after the end.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local function fresh(db)
    db = db or {}
    db.seenFaceTip = true
    loadAddon({ db = db })
    math.randomseed(7)
    WoW.slash("/gsweep")
    return Gnomesweeper.Window
end
local function tile(i) return Gnomesweeper.Grid._test.tiles[i] end
local function click(i)
    local t = tile(i)
    t._scripts.OnMouseDown(t, "LeftButton")
    t._scripts.OnMouseUp(t, "LeftButton", true)
end
local function at(t) WoW.now = t; WoW.tick(0.2) end      -- the clock's tick at time t

do
    local W = fresh({ scores = { version = 1, ["beginner:area"] = { played = 3, won = 1, best = { time = 60 } } } })
    local ui, C = W._test.ui, Gnomesweeper.Skin.COLORS
    local function colour() return ui.timer._textColor[1], ui.timer._textColor[2] end
    WoW.now = 100
    click(41)                                            -- the clock starts at 100
    at(120)
    eq(ui.timer.clockState, "normal", "far from a 60 s best: normal")
    eq(colour(), C.clockNormal[1], "...in its usual colour")
    check(not ui.timerFlash.isPlaying(), "...not flashing")

    at(151)
    eq(ui.timer.clockState, "near", "the last 10 s: near")
    local r, g = colour()
    eq(g, C.clockNear[2], "...yellow")
    check(not ui.timerFlash.isPlaying(), "...not flashing yet")

    at(158)
    eq(ui.timer.clockState, "last", "the last 3 s: last")
    check(ui.timerFlash.isPlaying(), "...it flashes (owner)")
    eq(ui.timerFlash.ag._looping, "REPEAT", "...until it isn't the last 3 s any more")

    at(161)
    eq(ui.timer.clockState, "over", "past the best: over")
    r, g = colour()
    eq(g, C.clockOver[2], "...red")
    check(not ui.timerFlash.isPlaying(), "...steady, no flash")

    -- It keeps the colour after the end; a new game resets it.
    for i = 1, W.game.total do if W.game._mine[i] then click(i); break end end
    eq(W.game:State(), "lost", "(a wipe past the best)")
    r, g = colour()
    eq(g, C.clockOver[2], "after the end the clock keeps its red: a near miss reads as one")
    W.NewGame()
    eq(ui.timer.clockState, "normal", "a new game: normal again")
    eq(colour(), C.clockNormal[1], "...in its usual colour")
end

do  -- a game ending in the last 3 s stops the flash but keeps the yellow
    local W = fresh({ scores = { version = 1, ["beginner:area"] = { played = 3, won = 1, best = { time = 60 } } } })
    local ui, C = W._test.ui, Gnomesweeper.Skin.COLORS
    WoW.now = 100
    click(41)
    at(158)
    check(ui.timerFlash.isPlaying(), "(flashing in the last 3 s)")
    for i = 1, W.game.total do if W.game._mine[i] then click(i); break end end
    check(not ui.timerFlash.isPlaying(), "a game ending in its last 3 s: the flash stops")
    eq(ui.timer._textColor[2], C.clockNear[2], "...the yellow stays")
end

do  -- no best at this difficulty: the clock never changes
    local W = fresh()
    local ui = W._test.ui
    WoW.now = 100
    click(41)
    at(5000)
    eq(ui.timer.clockState, "normal", "no best yet: the clock stays normal, however long")
    check(not ui.timerFlash.isPlaying(), "...and never flashes")
end

done("test_clock")
