-- #48: the mascot moves (level 1, motion on the face we have): a bounce on a
-- win, a shudder on a wipe, a nod on the player's new game, a breath while a
-- game is played; never while the window is closed.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local function fresh()
    loadAddon({ db = { seenFaceTip = true } })
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
local function small(W) W._test.SetGame(Gnomesweeper.Board._test.FromLayout({ "*.." })) end
-- The stub doesn't run animations: a group "finishes" when told to.
local function finish(g) g:Stop(); g._scripts.OnFinished(g) end

do  -- the groups: on the face texture, built once
    local W = fresh()
    local ui = W._test.ui
    local m = ui.mascot
    for _, kind in ipairs({ "win", "wipe", "nod" }) do
        eq(m.groups[kind]._parent, ui.face.face, kind .. ": on the face texture (the button and ring stay still)")
        check(m.groups[kind]._looping ~= "REPEAT", "...once")
    end
    eq(m.breathe._looping, "REPEAT", "the breath repeats")
    local last = m.breathe._anims[#m.breathe._anims]
    check((last._endDelay or 0) >= 3, "...with a rest between breaths (an end delay on its last animation)")
end

do  -- breathing: only while a game is played and shown
    local W = fresh()
    local m = W._test.ui.mascot
    eq(m.playing(), nil, "a fresh board: still")
    WoW.now = 100
    click(41)
    eq(W.game:State(), "playing", "(playing)")
    eq(m.playing(), "breathe", "while a game is played: she breathes")
    local plays = m.breathe._plays
    click(42); click(50)
    eq(m.breathe._plays, plays, "...clicks don't restart the breath")

    W.win:Hide()
    eq(m.playing(), nil, "the window closed: still")
    Gnomesweeper.Options.Set("questionMarks", true)       -- a setting refreshes the hidden window
    eq(m.playing(), nil, "...a setting changed while it's hidden doesn't start her again")
    W.win:Show()
    eq(m.playing(), "breathe", "reopened mid-game: she breathes again")
end

do  -- the win: a bounce, once, then still
    local W = fresh()
    local m = W._test.ui.mascot
    small(W)
    click(2); click(3)
    eq(W.game:State(), "won", "(a win)")
    eq(m.playing(), "win", "the win: a bounce")
    local plays = m.groups.win._plays
    W.Refresh(); W.Refresh()
    eq(m.groups.win._plays, plays, "...refreshes don't replay it")
    finish(m.groups.win)
    eq(m.playing(), nil, "...then still (no breath after the end)")
    W.win:Hide(); W.win:Show()
    eq(m.groups.win._plays, plays, "reopening a won game doesn't replay it")
end

do  -- the wipe: a shudder
    local W = fresh()
    local m = W._test.ui.mascot
    small(W)
    click(1)
    eq(W.game:State(), "lost", "(a wipe)")
    eq(m.playing(), "wipe", "the wipe: a shudder")
    check(not m.groups.win:IsPlaying(), "...nothing else")
end

do  -- the player's new game: a nod, then the breath resumes once a game is played
    local W = fresh()
    local ui = W._test.ui
    local m = ui.mascot
    small(W)
    click(1)                                             -- a wipe: the shudder
    ui.face._scripts.OnClick(ui.face)                    -- the player's new game
    eq(m.playing(), "nod", "the face clicked: a nod")
    check(not m.groups.wipe:IsPlaying(), "...the shudder stopped")
    local plays = m.groups.nod._plays
    ui.face._scripts.OnClick(ui.face)
    eq(m.groups.nod._plays, plays + 1, "...a second click nods again")
    Gnomesweeper.Grid.FinishShuffle()                    -- (a press during the wave isn't a click)
    WoW.now = 200
    click(41)                                            -- playing while she nods
    eq(m.playing(), "nod", "...the nod finishes first")
    check(not m.breathe:IsPlaying(), "...the breath doesn't start on top of it")
    finish(m.groups.nod)
    eq(m.playing(), "breathe", "...then she breathes")
end

do  -- a quiet new game (difficulty, settings) doesn't nod, and stops what ran
    local W = fresh()
    local m = W._test.ui.mascot
    small(W)
    click(2); click(3)
    eq(m.playing(), "win", "(bouncing)")
    W.NewGame("expert")
    eq(m.playing(), nil, "a difficulty change mid-bounce: still, no nod")
    check(not m.groups.win:IsPlaying(), "...the bounce stopped")

    -- a board swapped in (tests) is still too
    small(W)
    click(1)
    eq(m.playing(), "wipe", "(shuddering)")
    small(W)
    check(not m.groups.wipe:IsPlaying(), "a board swapped in: the shudder stopped")
    eq(m.playing(), "breathe", "...and, a game in play, she breathes")
end

do  -- hiding during a nod: still; nothing plays on a hidden window
    local W = fresh()
    local ui = W._test.ui
    local m = ui.mascot
    ui.face._scripts.OnClick(ui.face)
    eq(m.playing(), "nod", "(nodding)")
    W.win:Hide()
    eq(m.playing(), nil, "closed mid-nod: still")
    check(not m.groups.nod:IsPlaying(), "...the nod stopped")
end

done("test_mascot")
