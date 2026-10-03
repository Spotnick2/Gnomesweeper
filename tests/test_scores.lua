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

-- The difficulty list's best column, as it reads when the list is opened.
local function menuBest(ui, key)
    ui.diff._scripts.OnClick(ui.diff)
    local text = ui.rows[key].best:GetText()
    ui.menu:Hide()
    return text
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
    check(o.newBest:IsShown() and not o.best:IsShown(), "the overlay says so, on its own bigger line")
    eq(o.newBest:GetText(), "New personal best!", "...New personal best!")
    eq(o.newBest._textColor[1], Skin.COLORS.gold[1], "...in gold")
    check(o.pulse.isPlaying(), "...with a beat (#10)")
    eq(o:GetHeight(), 158, "...with room for the bigger line")
    eq(menuBest(ui, "beginner"), "00:42", "the difficulty list shows the best, whole seconds")
    eq(menuBest(ui, "expert"), "-", "...and a dash where there is none")
    o.view._scripts.OnClick(o.view)
    check(ui.result.sub:GetText():find("New best!", 1, true) ~= nil, "the result bar keeps it")

    winWall(W, "beginner:area", 50)
    check(math.abs(GnomesweeperDB.scores["beginner:area"].best.time - 42.7) < 1e-9, "a slower win leaves the best")
    eq(o.best:GetText(), "Best 00:42", "the overlay shows the best that stands")
    check(not o.newBest:IsShown() and not o.pulse.isPlaying(), "...not the new-best line, no beat")
    eq(o.best._textColor[1], Skin.COLORS.hint[1], "...quietly")
    o.view._scripts.OnClick(o.view)
    check(ui.result.sub:GetText():find("Best 00:42", 1, true) ~= nil, "...and so does the result bar")
    check(ui.result.sub:GetText():find("00:50", 1, true) ~= nil, "...after this game's time")

    winWall(W, "beginner:area", 42.7)
    eq(o.best:GetText(), "Best 00:42.7", "a tie is not a new best (same second: tenths)")
    eq(o.time:GetText(), "Time 00:42.7", "...and the time shows tenths too")
    eq(GnomesweeperDB.scores["beginner:area"].won, 3, "every win counts")

    winWall(W, "beginner:area", 12)
    check(o.newBest:IsShown(), "a faster win is")
    eq(menuBest(ui, "beginner"), "00:12", "...and the list follows")

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
    check(not o.best:IsShown() and not o.newBest:IsShown(), "a loss shows no best line")
end

do  -- kept across a reload
    local W = fresh()
    winWall(W, "expert:area", 300)
    local saved = GnomesweeperDB
    W = fresh(saved)
    eq(GnomesweeperDB.scores["expert:area"].best.time, 300, "the scores survive a reload")
    eq(menuBest(W._test.ui, "expert"), "05:00", "...and the list shows them")
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

do  -- the best times panel: the trophy, /gsweep scores
    local W = fresh()
    local ui = W._test.ui
    local Skin = Gnomesweeper.Skin
    eq(ui.trophy.icon._texture, Skin.TEXTURES.trophy, "the title bar has a trophy")
    local pt = ui.trophy._points[1]
    eq(pt[1], "RIGHT", "...with the icons")
    eq(pt[2], ui.help, "...left of the ? (which is left of the gear)")
    eq(ui.bests, nil, "the panel is built only when asked for")

    ui.trophy._scripts.OnClick(ui.trophy)
    local p = ui.bests
    check(p and p:IsShown(), "the trophy opens the best times")
    eq(p:GetFrameLevel(), W.win:GetFrameLevel() + 30, "...over the board and the end overlay")
    check(p._mouse, "...and the board under it takes no clicks")
    eq(p.title:GetText(), "Best times", "...titled")
    for _, key in ipairs(Gnomesweeper.Board.PRESET_ORDER) do
        eq(p.rows[key].time:GetText(), "-", key .. ": no best yet")
        eq(p.rows[key].who:GetText(), "Not played yet", "...never played")
        eq(p.rows[key].record:GetText(), "", "...no record line")
        eq(p.rows[key].label._textColor[1], Skin.DifficultyColor(key)[1], "...in its rarity colour")
    end
    eq(p.rule:GetText(), "First click: always opens an area.", "it says which first-click rule the bests are for")
    eq(GnomesweeperDB.scores, nil, "opening it writes nothing")
    ui.trophy._scripts.OnClick(ui.trophy)
    check(not p:IsShown(), "the trophy again closes it")

    -- A game played, not won.
    click(41)
    WoW.slash("/gsweep scores")
    check(p:IsShown(), "/gsweep scores opens it")
    eq(p.rows.beginner.who:GetText(), "No win yet", "played but not won says so")
    eq(p.rows.beginner.record:GetText(), "won 0 of 1", "...with the record")

    -- A win while it is open updates it.
    winWall(W, "beginner:area", 35.05)
    check(p:IsShown(), "it can stay open through a game")
    eq(p.rows.beginner.time:GetText(), "00:35", "a win shows at once")
    eq(p.rows.beginner.who:GetText(), "Fizzle Sprocketwhistle  " .. "\194\183" .. "  " .. os.date("%d %b %Y", WoW.epoch), "...with who and when")
    eq(p.rows.beginner.record:GetText(), "won 1 of 1", "...and the record (the hand-built board adds no game)")
    eq(p.rows.expert.time:GetText(), "-", "...other difficulties untouched")

    -- Only one of the list and the panel at a time.
    ui.diff._scripts.OnClick(ui.diff)
    check(ui.menu:IsShown() and not p:IsShown(), "opening the difficulty list closes the panel")
    WoW.slash("/gsweep scores")
    check(p:IsShown() and not ui.menu:IsShown(), "...and opening the panel closes the list")
    WoW.slash("/gsweep scores")
    check(p:IsShown(), "/gsweep scores shows it, never toggles it away")
    p.close._scripts.OnClick(p.close)
    check(not p:IsShown(), "its close button closes it")

    -- From a closed window.
    W.win:Hide()
    WoW.slash("/gsweep scores")
    check(W.win:IsShown() and p:IsShown(), "/gsweep scores opens the window too")

    -- The other first-click rule has its own bests.
    -- Mid-game, a rule change shows with the next game (the one it applies to).
    GnomesweeperDB.safeZone = "cell"
    p:Hide(); WoW.slash("/gsweep scores")
    eq(p.rows.beginner.time:GetText(), "00:35", "a rule changed mid-game: this game's rule still shows")
    eq(p.rule:GetText(), "First click: always opens an area.", "...and says which")
    W.NewGame()
    p:Hide(); WoW.slash("/gsweep scores")
    eq(p.rows.beginner.time:GetText(), "-", "the XP rule shows its own bests")
    eq(p.rule:GetText(), "First click: one safe tile (Windows XP's rule).", "...and says so")
    GnomesweeperDB.safeZone = "area"
end

do  -- the same whole second: tenths, so a slower time can't look like a tie (review of #38)
    local W = fresh()
    local o = function() return W._test.ui.overlay end
    winWall(W, "beginner:area", 42.1)
    eq(o().time:GetText(), "Time 00:42.1", "a first best: with tenths (owner: a new best shows the decimal)")
    check(not o().beaten:IsShown(), "...and no 'faster than' line: there was no old best")
    o().view._scripts.OnClick(o().view)
    check(W._test.ui.result.sub:GetText():find("New best!", 1, true) ~= nil, "...the result bar: New best!")
    winWall(W, "beginner:area", 42.6)
    eq(o().time:GetText(), "Time 00:42.6", "slower in the same second: the time shows tenths")
    eq(o().best:GetText(), "Best 00:42.1", "...and so does the best that stands")
    o().view._scripts.OnClick(o().view)
    check(W._test.ui.result.sub:GetText():find("Time 00:42.6", 1, true) ~= nil, "...in the result bar too")
    check(W._test.ui.result.sub:GetText():find("Best 00:42.1", 1, true) ~= nil, "...both")
    winWall(W, "beginner:area", 50.3)
    eq(o().time:GetText(), "Time 00:50", "a different second: whole seconds")
    eq(o().best:GetText(), "Best 00:42", "...for both")
    winWall(W, "beginner:area", 42.05)
    check(o().newBest:IsShown(), "a new best by a hundredth")
    eq(o().time:GetText(), "Time 00:42.0", "...its time with tenths")
    eq(o().beaten:GetText(), "0.1 s faster than 00:42.1", "...by how much, as the times on screen say (42.1 - 42.0), and the old best")

    winWall(W, "beginner:area", 41.2)
    eq(o().time:GetText(), "Time 00:41.2", "another new best")
    eq(o().beaten:GetText(), "0.8 s faster than 00:42.0", "...0.8 s faster than the one before: 42.0 - 41.2 as shown (not 0.85 rounded)")
    check(o().beaten:IsShown() and o().newBest:IsShown(), "...both lines")
    eq(o():GetHeight(), 152 + 6 + 16, "...the overlay grows for the second line")
    o().view._scripts.OnClick(o().view)
    eq(W._test.ui.result.sub:GetText(), "Time 00:41.2  " .. string.char(194, 183) .. "  New best (-0.8 s)", "the result bar keeps both, short")

    winWall(W, "beginner:area", 50)
    check(not o().beaten:IsShown(), "a slower win: no 'faster than' line")

    -- Two bests in the same tenth: the real difference, in hundredths, never "0.0 s".
    winWall(W, "intermediate:area", 30.28)
    winWall(W, "intermediate:area", 30.21)
    eq(o().beaten:GetText(), "0.07 s faster than 00:30.2", "in the same tenth: hundredths")
end

do  -- the panel follows every game, closes with the window, and survives a damaged file
    local W = fresh()
    local ui = W._test.ui
    WoW.slash("/gsweep scores")
    local p = ui.bests
    click(41)
    eq(p.rows.beginner.record:GetText(), "won 0 of 1", "an open panel counts a game the moment it starts")
    for i = 1, W.game.total do if W.game._mine[i] then click(i); break end end
    eq(W.game:State(), "lost", "(a loss)")
    eq(p.rows.beginner.who:GetText(), "No win yet", "...and still reads right after a loss")

    W.win:Hide()
    check(not p:IsShown(), "closing the window closes the panel")
    WoW.slash("/gsweep")
    check(W.win:IsShown() and not p:IsShown(), "...so it doesn't come back over the board")

    GnomesweeperDB.scores["beginner:area"].best = { time = 30, name = {}, at = "yesterday" }
    WoW.slash("/gsweep scores")
    eq(p.rows.beginner.time:GetText(), "00:30", "a best with a damaged name still shows its time")
    eq(p.rows.beginner.who:GetText(), "?", "...with no name and no date, and no error")
    local lines = tipLines(ui.diff)
    eq(lines[2], "Best: 00:30", "the tooltip leaves the name out")
    eq(p.rows.beginner.who._width, 264 - 20 - 11 - 70, "the who line has a width (not a RIGHT point)")
    eq(#p.rows.beginner.who._points, 1, "...and only its top-left point")
end

do  -- the list's column is filled when the list opens, not on every click
    local W = fresh()
    local ui = W._test.ui
    winWall(W, "expert:area", 77)
    local row = ui.rows.expert
    row.best:SetText("stale")
    click(at(1, 1))
    eq(row.best:GetText(), "stale", "a click doesn't touch the hidden list")
    eq(menuBest(ui, "expert"), "01:17", "...opening it fills it")
end

done("test_scores")
