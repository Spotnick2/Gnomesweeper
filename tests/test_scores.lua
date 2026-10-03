-- Scores.lua (pure) and personal bests in the window (#7).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

----------------------------------------------------------------------------
-- The model, with every global forbidden
----------------------------------------------------------------------------
local S = loadPure(newPureEnv(), "Scores.lua").Scores

eq(S.Category("expert", "area"), "expert:area", "a category is difficulty:ruleset")
eq(S.Category("expert", "cell"), "expert:cell", "...the XP single cell is its own ruleset")
eq(S.Category("expert", nil), "expert:area", "...and anything else is the default area")

do
    local db = {}
    local sc = S.Open(db)
    eq(db.scores, sc, "Open creates the scores in the saved table")
    eq(sc.version, 1, "...versioned")
    eq(S.Open(db), sc, "...and opens the same table again")
    db.scores = "junk"
    check(type(S.Open(db)) == "table", "a damaged field is replaced, not crashed on")
    local keep = { version = 1, ["beginner:area"] = { played = 3, won = 1 } }
    db.scores = keep
    eq(S.Open(db), keep, "existing scores are kept")
    eq(select(1, S.Stats(keep, "beginner:area")), 3, "...with their counts")
end

do
    local sc = S.Open({})
    local cat = "beginner:area"
    eq(S.Best(sc, cat), nil, "no best before a win")
    eq(select(1, S.Stats(sc, cat)), 0, "nothing played")
    S.Started(sc, cat); S.Started(sc, cat)
    local played, won = S.Stats(sc, cat)
    eq(played, 2, "each started game counts")
    eq(won, 0, "...none won")

    local isNew, prev = S.Won(sc, cat, { time = 42.5, at = 100, name = "Fizzle Sprocketwhistle", realm = "Forever" })
    eq(isNew, true, "the first win is a best")
    eq(prev, nil, "...replacing nothing")
    local best = S.Best(sc, cat)
    eq(best.time, 42.5, "the precise time is kept")
    eq(best.at, 100, "...when")
    eq(best.name, "Fizzle Sprocketwhistle", "...who, with the surname")
    eq(best.realm, "Forever", "...and the realm")
    local fields = 0
    for _ in pairs(best) do fields = fields + 1 end
    eq(fields, 4, "...and nothing derived (no shown seconds)")
    eq(select(2, S.Stats(sc, cat)), 1, "the win is counted")

    isNew, prev = S.Won(sc, cat, { time = 50, at = 200 })
    eq(isNew, false, "a slower win is not a best")
    eq(prev.time, 42.5, "...the standing best is returned")
    eq(S.Best(sc, cat).at, 100, "...and stays")

    isNew = S.Won(sc, cat, { time = 42.5, at = 300 })
    eq(isNew, false, "a tie is not a best")
    eq(S.Best(sc, cat).at, 100, "...the EARLIER record stays")

    isNew, prev = S.Won(sc, cat, { time = 42.49, at = 400 })
    eq(isNew, true, "a faster win is a best, even by a hundredth")
    eq(prev.at, 100, "...returning the best it replaced")
    eq(S.Best(sc, cat).at, 400, "...and takes its place")
    eq(select(2, S.Stats(sc, cat)), 4, "every win counts")

    eq(S.Best(sc, "beginner:cell"), nil, "the other ruleset keeps its own best")
    eq(S.Best(sc, "expert:area"), nil, "...and so does another difficulty")
end

do  -- damaged or odd data
    local sc = S.Open({})
    local cat = "expert:area"
    eq(S.Won(sc, cat, { time = 0 / 0 }), false, "a NaN time is never a best")
    eq(S.Won(sc, cat, { time = -1 }), false, "...nor a negative one")
    eq(S.Won(sc, cat, {}), false, "...nor none")
    eq(S.Best(sc, cat), nil, "...so there is still no best")
    local played, won = S.Stats(sc, cat)
    eq(won, 3, "the wins still count")
    eq(played, 3, "...and played is never less than won")
    sc[cat] = "junk"
    eq(S.Best(sc, cat), nil, "a damaged entry has no best")
    S.Started(sc, cat)
    eq(select(1, S.Stats(sc, cat)), 1, "...and is replaced on the next game")
    sc[cat].best = { time = "fast" }
    eq(S.Best(sc, cat), nil, "a damaged best is ignored")
    eq(S.Won(sc, cat, { time = 99 }), true, "...and the next win replaces it")
    sc[cat].played, sc[cat].won = -4, 2.7
    local p, w = S.Stats(sc, cat)
    eq(p, 0, "a negative count reads as 0")
    eq(w, 2, "...a fraction as whole")
end

----------------------------------------------------------------------------
-- The player's full name (Compat)
----------------------------------------------------------------------------
loadAddon()
local API = Gnomesweeper.API
eq(API.PlayerFullName(), "Fizzle Sprocketwhistle", "70009+: the surname in the second return is joined on")
WoW.playerName, WoW.playerSurname = "Fizzle Sprocketwhistle", "SomeRealm"
eq(API.PlayerFullName(), "Fizzle Sprocketwhistle", "69977: a name with a space is whole, the second return ignored")
WoW.playerName, WoW.playerSurname = "Fizzle", nil
eq(API.PlayerFullName(), "Fizzle", "no surname: the first name alone")
WoW.playerName = nil
eq(API.PlayerFullName(), nil, "no name at all: nil")

----------------------------------------------------------------------------
-- In the window
----------------------------------------------------------------------------
local L = "LeftButton"
local WALL = { "..*..", "..*..", "..*..", "..*.." }       -- column 3 is mines: two clicks win
local function at(x, y) return (y - 1) * 5 + x end

local function fresh(db)
    loadAddon({ db = db })
    math.randomseed(7)
    WoW.slash("/gsweep")
    return Gnomesweeper.Window
end

local function tile(i) return Gnomesweeper.Grid._test.tiles[i] end
local function click(i)
    local t = tile(i)
    t._scripts.OnMouseDown(t, L)
    t._scripts.OnMouseUp(t, L, true)
end

-- Win the wall in `seconds` of play, keeping scores in `cat`.
local function winWall(W, cat, seconds)
    WoW.now = 1000
    W._test.SetGame(Gnomesweeper.Board._test.FromLayout(WALL, { now = 1000 }), cat)
    WoW.now = 1000 + seconds
    click(at(1, 1)); click(at(5, 1))
    eq(W.game:State(), "won", "(the wall is cleared)")
end

local function tipLines(widget)
    widget._scripts.OnEnter(widget)
    return GameTooltip._lines or {}
end

do  -- played: counted on the first successful reveal
    local W = fresh()
    local sc = function() return GnomesweeperDB.scores or {} end
    eq(sc()["beginner:area"], nil, "nothing is counted on opening")
    tile(1)._scripts.OnMouseDown(tile(1), "RightButton"); tile(1)._scripts.OnMouseUp(tile(1), "RightButton", true)
    eq(sc()["beginner:area"], nil, "...nor on a flag")
    tile(1)._scripts.OnMouseDown(tile(1), "RightButton"); tile(1)._scripts.OnMouseUp(tile(1), "RightButton", true)
    click(41)
    eq(sc()["beginner:area"].played, 1, "the first reveal counts the game")
    for i = 1, 81 do if W.game:State() == "playing" and W.game:Cell(i).state == "covered" and not W.game._mine[i] then click(i); break end end
    eq(sc()["beginner:area"].played, 1, "...once")
    W.NewGame()
    click(41)
    eq(sc()["beginner:area"].played, 2, "an abandoned game still counted; the next one counts too")
    eq(sc()["beginner:area"].won, 0, "...and nothing is won")

    W.NewGame("expert")
    click(200)
    eq(sc()["expert:area"].played, 1, "each difficulty counts apart")

    GnomesweeperDB.safeZone = "cell"
    W.NewGame("expert")
    click(200)
    eq(sc()["expert:cell"].played, 1, "...and each first-click rule")
    eq(sc()["expert:area"].played, 1, "...without touching the other")
    GnomesweeperDB.safeZone = "area"

    for i = 1, W.game.total do if W.game._mine[i] then click(i); break end end
    eq(W.game:State(), "lost", "(a mine)")
    eq(sc()["expert:cell"].won, 0, "a loss wins nothing")
    eq(sc()["expert:cell"].best, nil, "...and sets no best")
end

do  -- a hand-built board keeps no scores unless told where
    local W = fresh()
    winWall(W, nil, 30)
    eq(GnomesweeperDB.scores, nil, "a test board without a category touches no scores")
    check(not W._test.ui.overlay.best:IsShown(), "...and the overlay has no best line")
end

do  -- the first win, then slower, then faster
    local W = fresh()
    local ui = W._test.ui
    local Skin = Gnomesweeper.Skin
    winWall(W, "beginner:area", 42.7)
    local best = GnomesweeperDB.scores["beginner:area"].best
    check(math.abs(best.time - 42.7) < 1e-9, "the win's precise active time is saved")
    eq(best.at, WoW.epoch, "...the date")
    eq(best.name, "Fizzle Sprocketwhistle", "...the full name, surname included")
    eq(best.realm, "Forever", "...the realm")
    local o = ui.overlay
    check(o.best:IsShown(), "the overlay says so")
    eq(o.best:GetText(), "New personal best!", "...New personal best!")
    eq(o.best._textColor[1], Skin.COLORS.gold[1], "...in gold")
    eq(o:GetHeight(), 152, "...with room for the line")
    eq(ui.rows.beginner.best:GetText(), "00:42", "the difficulty list shows the best, whole seconds")
    eq(ui.rows.expert.best:GetText(), "-", "...and a dash where there is none")
    o.view._scripts.OnClick(o.view)
    check(ui.result.sub:GetText():find("New best!", 1, true) ~= nil, "the result bar keeps it")

    winWall(W, "beginner:area", 50)
    check(math.abs(GnomesweeperDB.scores["beginner:area"].best.time - 42.7) < 1e-9, "a slower win leaves the best")
    eq(o.best:GetText(), "Best 00:42", "the overlay shows the best that stands")
    eq(o.best._textColor[1], Skin.COLORS.hint[1], "...quietly")
    o.view._scripts.OnClick(o.view)
    check(ui.result.sub:GetText():find("Best 00:42", 1, true) ~= nil, "...and so does the result bar")
    check(ui.result.sub:GetText():find("00:50", 1, true) ~= nil, "...after this game's time")

    winWall(W, "beginner:area", 42.7)
    eq(o.best:GetText(), "Best 00:42", "a tie is not a new best")
    eq(GnomesweeperDB.scores["beginner:area"].won, 3, "every win counts")

    winWall(W, "beginner:area", 12)
    eq(o.best:GetText(), "New personal best!", "a faster win is")
    eq(ui.rows.beginner.best:GetText(), "00:12", "...and the list follows")

    local lines = tipLines(ui.diff)
    eq(lines[1], "Starts a new game.", "the difficulty tooltip still says what it does")
    eq(lines[2], "Best: 00:12 by Fizzle Sprocketwhistle", "...the best and who")
    eq(lines[3], "Won 4 of 4", "...and the record")

    W.NewGame("intermediate")
    lines = tipLines(ui.diff)
    eq(lines[2], "Not played yet.", "a difficulty never played says so")
    eq(#lines, 2, "...and has no best line")

    -- A new game clears the last result: losing next shows no best line.
    W.NewGame("beginner")
    W._test.SetGame(Gnomesweeper.Board._test.FromLayout(WALL, { now = WoW.now }), "beginner:area")
    click(at(3, 1))
    eq(W.game:State(), "lost", "(boom)")
    check(not o.best:IsShown(), "a loss shows no best line")
end

do  -- kept across a reload
    local W = fresh()
    winWall(W, "expert:area", 300)
    local saved = GnomesweeperDB
    W = fresh(saved)
    eq(GnomesweeperDB.scores["expert:area"].best.time, 300, "the scores survive a reload")
    eq(W._test.ui.rows.expert.best:GetText(), "05:00", "...and the list shows them")
end

do  -- the result bar's text never reaches its button (Codex review of #7)
    -- Widest texts it shows, measured in Arial Narrow at the size used (12):
    -- "Wrong flags are crossed out." 121, "Time 00:42  .  Best 00:38" 108.
    local LONGEST = 121
    local W = fresh()
    local ui = W._test.ui
    for _, key in ipairs(Gnomesweeper.Board.PRESET_ORDER) do
        W.NewGame(key)
        local r = ui.result
        local room = r:GetWidth() - (4 + 104 + 6) - 4
        check(room >= LONGEST, key .. ": the result bar leaves room for its longest text (" .. room .. ")")
    end
    local pt = ui.result.title._points[#ui.result.title._points]
    eq(pt[1], "TOPRIGHT", "the title stops short of the button")
    eq(pt[4], -(4 + 104 + 6), "...by the button's width and a gap")
    pt = ui.result.sub._points[#ui.result.sub._points]
    eq(pt[1], "TOPRIGHT", "...and so does the line under it")
end

done("test_scores")
