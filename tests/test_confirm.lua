-- #32: a difficulty change asks first when the game in progress has something to
-- lose. #45: the first launch's pointer at the face.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local L, R = "LeftButton", "RightButton"

local function fresh(db)
    loadAddon({ db = db })
    math.randomseed(7)
    WoW.slash("/gsweep")
    return Gnomesweeper.Window
end
local function tile(i) return Gnomesweeper.Grid._test.tiles[i] end
local function click(i, b)
    local t = tile(i)
    t._scripts.OnMouseDown(t, b or L)
    t._scripts.OnMouseUp(t, b or L, true)
end
local function press(b) b._scripts.OnClick(b, L) end
local function covered(W)
    for i = 1, W.game.total do
        if W.game:Cell(i).state == "covered" and not W.game._mine[i] then return i end
    end
end

----------------------------------------------------------------------------
-- #32: when it asks, and when it doesn't
----------------------------------------------------------------------------
do
    local W = fresh({ seenFaceTip = true })
    local ui = W._test.ui
    local function pick(key) press(ui.diff); press(ui.rows[key]) end

    -- A fresh board: switches at once.
    local g = W.game
    pick("intermediate")
    check(W.game ~= g and GnomesweeperDB.difficulty == "intermediate", "a fresh board: the difficulty switches at once")
    check(not ui.menu:IsShown(), "...and the list closes")

    -- Only the first reveal: nothing to lose yet.
    click(100)
    eq(W.game:State(), "playing", "(the first reveal)")
    g = W.game
    pick("beginner")
    check(W.game ~= g, "after only the first reveal: switches at once")

    -- Progress: a second move.
    click(41)
    click(covered(W))
    g = W.game
    pick("expert")
    eq(W.game, g, "a game with progress: it doesn't switch")
    eq(GnomesweeperDB.difficulty, "beginner", "...nor change the saved difficulty")
    local c = ui.menu.confirm
    check(ui.menu:IsShown() and c:IsShown(), "...it asks, in the list")
    eq(c.text:GetText(), "Start Expert? This game will be lost.", "...naming the difficulty")
    check(ui.menu:GetHeight() > 3 * 24 + 8, "...the list grows for the question")
    press(c.keep)
    eq(W.game, g, "Keep game keeps it")
    check(not ui.menu:IsShown() and not c:IsShown(), "...and puts the list away")
    eq(ui.menu:GetHeight(), 3 * 24 + 8, "...back to its size")

    pick("expert")
    press(c.start)
    check(W.game ~= g and GnomesweeperDB.difficulty == "expert", "Start switches")
    check(not ui.menu:IsShown(), "...and closes the list")
    click(200)                                           -- the new game's first reveal
    g = W.game
    pick("intermediate")
    check(W.game ~= g, "the new game counts its own moves: its first reveal alone switches at once")
    pick("expert")

    -- A flag is progress too.
    click(200)
    local f = covered(W)
    click(f, R)
    g = W.game
    pick("beginner")
    check(W.game == g and c:IsShown(), "a first reveal and a flag: it asks")

    -- An outside click cancels.
    WoW.mouseDown = true
    WoW.tick(0.02)
    WoW.mouseDown = false
    check(not ui.menu:IsShown(), "an outside click closes the list")
    eq(W.game, g, "...and keeps the game")
    pick("beginner")
    W.win:Hide()
    check(not c:IsShown(), "closing the window cancels the question")
    W.win:Show()
    eq(W.game, g, "...and the game is still there")

    -- The same difficulty: just closes.
    pick("expert")
    check(not ui.menu:IsShown() and W.game == g, "the difficulty it already is: the list just closes")

    -- /gsweep <difficulty> mid-game asks the same.
    WoW.slash("/gsweep intermediate")
    check(ui.menu:IsShown() and c:IsShown(), "/gsweep intermediate mid-game asks")
    eq(c.text:GetText(), "Start Intermediate? This game will be lost.", "...the same question")
    eq(W.game, g, "...without switching")
    press(c.start)
    eq(GnomesweeperDB.difficulty, "intermediate", "...and Start switches")

    -- A finished game has nothing to lose, however many moves it had.
    W._test.SetGame(Gnomesweeper.Board._test.FromLayout({ "*.." }))
    click(2, R)                                          -- a flag (a move)
    click(1)                                             -- then the mine
    eq(W.game:State(), "lost", "(a wipe, after two moves)")
    g = W.game
    pick("expert")
    check(W.game ~= g, "a finished game: switches at once")
end

----------------------------------------------------------------------------
-- #45: the first launch's pointer at the face
----------------------------------------------------------------------------
do
    local W = fresh()
    local ui = W._test.ui
    local tip = ui.faceTip
    check(tip:IsShown(), "the first time the board opens: a pointer at the face")
    eq(tip.text:GetText(), "Click the gnome for a new game. During a game, it gives this one up.", "...saying what she does")
    eq(GnomesweeperDB.seenFaceTip, true, "...saved at once, so it never comes back")
    eq(tip._points[1][1], "BOTTOM", "...above her")
    eq(tip._points[1][2], ui.face, "...pointing at the face")
    eq(tip._points[1][3], "TOP", "...from above (never over the tiles)")
    check(not tip._mouse, "...and it lets clicks through, but for its button")
    press(tip.ok)
    check(not tip:IsShown(), "Got it puts it away")
    W.win:Hide(); W.win:Show()
    check(not tip:IsShown(), "...and it doesn't come back")
end

do  -- each way it goes
    local W = fresh()
    W._test.ui.face._scripts.OnClick(W._test.ui.face)
    check(not W._test.ui.faceTip:IsShown(), "clicking the gnome puts it away")

    W = fresh()
    press(W._test.ui.diff)
    check(not W._test.ui.faceTip:IsShown(), "opening the difficulty list (under it) puts it away")

    W = fresh()
    W.win:Hide()
    check(not W._test.ui.faceTip:IsShown(), "closing the window puts it away")
    W.win:Show()
    check(not W._test.ui.faceTip:IsShown(), "...for good")
end

do  -- seen before: never
    local W = fresh({ seenFaceTip = true })
    check(not W._test.ui.faceTip:IsShown(), "seen before: no pointer")
end

done("test_confirm")
