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
    eq(W._test.clockState(), "normal", "far from a 60 s best: normal")
    eq(colour(), C.clockNormal[1], "...in its usual colour")
    check(not ui.timerFlash.isPlaying(), "...not flashing")

    at(151)
    eq(W._test.clockState(), "near", "the last 10 s: near")
    local r, g = colour()
    eq(g, C.clockNear[2], "...yellow")
    check(not ui.timerFlash.isPlaying(), "...not flashing yet")

    at(158)
    eq(W._test.clockState(), "last", "the last 3 s: last")
    check(ui.timerFlash.isPlaying(), "...it flashes (owner)")
    eq(ui.timerFlash.ag._looping, "REPEAT", "...until it isn't the last 3 s any more")

    at(161)
    eq(W._test.clockState(), "over", "past the best: over")
    r, g = colour()
    eq(g, C.clockOver[2], "...red")
    check(not ui.timerFlash.isPlaying(), "...steady, no flash")

    -- It keeps the colour after the end; a new game resets it.
    for i = 1, W.game.total do if W.game._mine[i] then click(i); break end end
    eq(W.game:State(), "lost", "(a wipe past the best)")
    r, g = colour()
    eq(g, C.clockOver[2], "after the end the clock keeps its red: a near miss reads as one")
    W.NewGame()
    eq(W._test.clockState(), "normal", "a new game: normal again")
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
    eq(W._test.clockState(), "normal", "no best yet: the clock stays normal, however long")
    check(not ui.timerFlash.isPlaying(), "...and never flashes")
end

do  -- the review of #52
    local function withBest(t) return { scores = { version = 1, ["beginner:area"] = { played = 3, won = 1, best = { time = t } } } } end
    local function winBoard(W)
        W._test.SetGame(Gnomesweeper.Board._test.FromLayout({ "*..", "...", "..." }), "beginner:area")
    end

    -- A new best by less than 10 s is no near miss: the clock isn't left yellow.
    local W = fresh(withBest(60))
    local ui, C = W._test.ui, Gnomesweeper.Skin.COLORS
    WoW.now = 100
    click(41)
    at(155)
    eq(W._test.clockState(), "near", "(yellow, 5 s before the best)")
    for i = 1, W.game.total do
        if not W.game._mine[i] and W.game:Cell(i).state == "covered" then click(i) end
        if W.game:State() ~= "playing" then break end
    end
    eq(W.game:State(), "won", "(won at 55 s, a new best)")
    eq(W._test.clockState(), "normal", "a new best: the clock isn't left in the near-miss yellow")
    eq(ui.timer._textColor[2], C.clockNormal[2], "...it's back to its usual colour")

    -- A best of 3 s or less: the clock isn't yellow before the game starts.
    W = fresh(withBest(2.4))
    eq(W.game:State(), "ready", "(a fresh board)")
    eq(W._test.clockState(), "normal", "a 2.4 s best: a fresh board's clock isn't warning")
    eq(ui.timer._textColor and ui.timer._textColor[2] or C.clockNormal[2], C.clockNormal[2], "...in its usual colour")
    WoW.now = 100
    click(41)
    at(100.1)
    eq(W._test.clockState(), "last", "...and the warning starts with the clock")

    -- The alert plays on the same threshold that turns the clock red, once.
    W = fresh(withBest(60))
    WoW.now = 100
    click(41)
    WoW.sounds = {}
    at(160)
    eq(W._test.clockState(), "last", "(exactly at the best: not over)")
    local function alerts()
        local n = 0
        for _, s in ipairs(WoW.sounds) do if s.kit == Gnomesweeper.Sounds.KITS.alert then n = n + 1 end end
        return n
    end
    eq(alerts(), 0, "...no alert yet")
    at(160.2)
    eq(W._test.clockState(), "over", "past it: red")
    eq(alerts(), 1, "...and the alert, at the same moment")
    at(170)
    eq(alerts(), 1, "...once")

    -- Resetting best times drops the warning at once.
    eq(W._test.clockState(), "over", "(red)")
    Gnomesweeper.Scores.Reset(GnomesweeperDB)
    W.ScoresReset()
    eq(W._test.clockState(), "normal", "resetting best times: the clock's warning goes at once")

    -- The clock is only touched when its look changes.
    W = fresh(withBest(60))
    ui = W._test.ui
    WoW.now = 100
    click(41)
    at(120)
    local calls = 0
    local set = ui.timer.SetTextColor
    ui.timer.SetTextColor = function(...) calls = calls + 1; return set(...) end
    for t = 121, 130 do at(t) end
    eq(calls, 0, "ten ticks in the same state don't repaint the clock")
    at(151)
    eq(calls, 1, "...the change to yellow does, once")
    ui.timer.SetTextColor = set
end

do  -- a 0 s best (a first click that cleared the board) still warns the next game (Codex, #52)
    local W = fresh({ scores = { version = 1, ["beginner:area"] = { played = 1, won = 1, best = { time = 0 } } } })
    eq(W._test.clockState(), "normal", "a 0 s best: a fresh board's clock doesn't warn")
    WoW.sounds = {}
    WoW.now = 100
    click(41)
    if W.game:State() == "playing" then
        at(101)
        eq(W._test.clockState(), "over", "...the next game is past it at once: red")
        local n = 0
        for _, s in ipairs(WoW.sounds) do if s.kit == Gnomesweeper.Sounds.KITS.alert then n = n + 1 end end
        eq(n, 1, "...and the alert plays, once")
    else
        check(false, "(the game should still be in play after the first reveal)")
    end
end

done("test_clock")
