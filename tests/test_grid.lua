-- Grid.lua and the controller: the tile pool, painting, clicks through the
-- window, the end of a game. Driven through the stub client with hand-built
-- boards, so every shape asserted is exact.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local L, R, M = "LeftButton", "RightButton", "MiddleButton"

local function lastPoint(w) return w._points[#w._points] end

local function chatHas(text)
    for _, line in ipairs(WoW.chat) do
        if line:find(text, 1, true) then return true end
    end
    return false
end

local function fresh(db)
    loadAddon({ db = db })
    math.randomseed(7)
    return Gnomesweeper.Window
end

-- The tile at cell i, and a press and release on it.
local function tiles() return Gnomesweeper.Grid._test.tiles end
local function paints() return Gnomesweeper.Grid._test.paints() end
local function tile(i) return tiles()[i] end
local function down(i, b) local t = tile(i); t._scripts.OnMouseDown(t, b) end
local function up(i, b, inside) local t = tile(i); t._scripts.OnMouseUp(t, b, inside) end
local function click(i, b) down(i, b); up(i, b, true) end

-- 5 wide, 4 tall: a wall of mines down column 3. Cell (x, y) is (y - 1) * 5 + x.
local WALL = { "..*..", "..*..", "..*..", "..*.." }
local function at(x, y) return (y - 1) * 5 + x end

-- A window open on a hand-built board.
local function onWall(opts)
    local W = fresh()
    WoW.slash("/gsweep")
    local game = Gnomesweeper.Board._test.FromLayout(WALL, opts)
    W._test.SetGame(game)
    return W, game
end

local Skin

----------------------------------------------------------------------------
-- The pool
----------------------------------------------------------------------------
do
    local W = fresh()
    WoW.slash("/gsweep")
    Skin = Gnomesweeper.Skin
    local grid = W.grid

    eq(#tiles(), 81, "Beginner: 81 tiles in the pool")
    for _, i in ipairs({ 1, 40, 81 }) do check(tile(i):IsShown(), "tile " .. i .. " is shown") end
    eq(tile(82), nil, "...and there is no 82nd")
    eq(tile(1)._parent, grid, "tiles are children of the board area")
    eq(tile(1)._width, 24, "a tile is 24 wide")
    eq(tile(1)._height, 24, "...and 24 high")

    local p = lastPoint(tile(1))
    check(p[1] == "TOPLEFT" and p[2] == grid and p[3] == "TOPLEFT" and p[4] == 0 and p[5] == 0, "cell 1 is the board's top-left corner")
    p = lastPoint(tile(9))
    check(p[4] == 192 and p[5] == 0, "cell 9 is 8 tiles along the top row")
    p = lastPoint(tile(10))
    check(p[4] == 0 and p[5] == -24, "cell 10 starts the second row")
    p = lastPoint(tile(81))
    check(p[4] == 192 and p[5] == -192, "cell 81 is the bottom-right corner")

    local t = tile(1)
    eq(t.bg._texture, Skin.TEXTURES.tileCovered, "a fresh tile is covered")
    eq(t.hl:GetAlpha(), 1, "...with its hover glow on")
    eq(t.icon, nil, "...no icon is created for a covered tile")
    eq(t.text, nil, "...and no number text")

    -- Created once, never per game or per difficulty change.
    local frames = #WoW.frames
    W.NewGame("expert")
    eq(#tiles(), 480, "Expert: 480 tiles")
    eq(#WoW.frames - frames, 480 - 81, "...only the 399 new ones were created")
    check(tile(480):IsShown() and tile(81):IsShown(), "all 480 are shown")
    p = lastPoint(tile(31))
    check(p[4] == 0 and p[5] == -24, "Expert's 31st cell starts its second row (30 wide)")

    frames = #WoW.frames
    W.NewGame("beginner")
    eq(#tiles(), 480, "back to Beginner: the pool keeps its 480")
    check(tile(81):IsShown() and not tile(82):IsShown() and not tile(480):IsShown(), "...showing 81 and hiding the rest")
    W.NewGame("expert")
    W.NewGame("beginner")
    W.NewGame()
    eq(#WoW.frames, frames, "difficulty changes and new games create no frames")

    check(Skin.NUMBER_COLORS[8] ~= nil and Skin.NUMBER_COLORS[9] == nil, "the skin has colours for 1 to 8")
    for n = 1, 8 do eq(#Skin.NUMBER_COLORS[n], 3, "number " .. n .. " has an RGB colour") end
end

----------------------------------------------------------------------------
-- Clicking
----------------------------------------------------------------------------
do
    local W, game = onWall()
    local ui = W._test.ui
    eq(#tiles(), 81, "the pool is still 81 after a smaller board")
    check(tile(20):IsShown() and not tile(21):IsShown(), "a 5x4 board shows 20 tiles")
    local p = lastPoint(tile(at(1, 2)))
    check(p[4] == 0 and p[5] == -24, "the 5-wide board's second row is at -24")

    -- Left click a zero: a flood, repainting exactly the cells it changed.
    local before = paints()
    click(at(1, 1), L)
    eq(paints() - before, 8, "revealing a region repaints the 8 cells it changed, no more")
    eq(game.revealed, 8, "(the board agrees: 8 cells)")
    eq(tile(at(1, 1)).bg._texture, Skin.TEXTURES.tileRevealed, "a revealed tile is flat")
    eq(tile(at(1, 1)).hl:GetAlpha(), 0, "...and has no hover glow")
    check(tile(at(1, 1)).text == nil or not tile(at(1, 1)).text:IsShown(), "a zero shows no number")
    eq(tile(at(2, 1)).text:GetText(), "2", "a border cell shows its count")
    eq(tile(at(2, 1)).text._textColor[1], Skin.NUMBER_COLORS[2][1], "...in that number's colour")
    eq(tile(at(2, 2)).text:GetText(), "3", "(a 3)")
    eq(tile(at(2, 2)).text._textColor[3], Skin.NUMBER_COLORS[3][3], "...in its colour")
    eq(tile(at(4, 1)).bg._texture, Skin.TEXTURES.tileCovered, "the far side is still covered")
    eq(ui.counter:GetText(), "4", "the HUD still shows all 4 mines")
    check(W.win._scripts.OnUpdate ~= nil, "the clock is running")

    -- Right click flags, and again takes it off.
    before = paints()
    click(at(4, 1), R)
    eq(paints() - before, 1, "a flag repaints one tile")
    eq(tile(at(4, 1)).icon._texture, Skin.TEXTURES.flag, "it shows the flag")
    check(tile(at(4, 1)).icon:IsShown(), "...visibly")
    eq(ui.counter:GetText(), "3", "the counter follows the flag")
    click(at(4, 1), R)
    check(not tile(at(4, 1)).icon:IsShown(), "a second right click takes the flag off")
    eq(ui.counter:GetText(), "4", "...and the counter returns")
    eq(tile(at(4, 1)).hl:GetAlpha(), 1, "...and the hover glow is on again")

    -- Clicking a revealed cell does nothing, and costs nothing.
    before = paints()
    click(at(1, 1), L)
    eq(paints() - before, 0, "a click that changes nothing repaints nothing")
end

do   -- question marks
    local W = fresh()
    WoW.slash("/gsweep")
    W._test.SetGame(Gnomesweeper.Board._test.FromLayout(WALL, { questionMarks = true }))
    local i = at(4, 1)
    click(i, R); click(i, R)
    eq(tile(i).text:GetText(), "?", "flag then right click again is a question mark")
    check(not tile(i).icon:IsShown(), "...with no flag")
    eq(tile(i).text._textColor[1], Skin.COLORS.question[1], "...in the question colour")
    eq(W._test.ui.counter:GetText(), "4", "...and it isn't counted as a flag")
    click(i, R)
    check(not tile(i).text:IsShown(), "a third right click clears it")
end

----------------------------------------------------------------------------
-- Chords
----------------------------------------------------------------------------
local function setUpChord()
    local W, game = onWall()
    click(at(2, 2), L)                          -- a 3, alone
    click(at(3, 1), R); click(at(3, 2), R); click(at(3, 3), R)
    return W, game
end

do
    local W, game = setUpChord()
    local before = paints()
    down(at(2, 2), L); down(at(2, 2), R)
    eq(paints() - before, 0, "pressing both buttons changes nothing yet")
    up(at(2, 2), L, true)
    eq(paints() - before, 7, "left+right on a satisfied number reveals its neighbours: 7 cells")
    eq(tile(at(1, 3)).bg._texture, Skin.TEXTURES.tileRevealed, "...flooding the region")
    eq(tile(at(3, 1)).icon._texture, Skin.TEXTURES.flag, "...and leaving the flags")
    up(at(2, 2), R, true)
    eq(paints() - before, 7, "the second release does nothing more")
    eq(game:State(), "playing", "the game goes on")
end

do
    local W, game = setUpChord()
    local before = paints()
    click(at(2, 2), M)
    eq(paints() - before, 7, "a middle click chords too")
end

do   -- a wrong flag loses
    local W, game = onWall()
    click(at(2, 2), L)
    click(at(3, 1), R); click(at(3, 2), R); click(at(1, 3), R)      -- (1,3) is safe
    down(at(2, 2), R); down(at(2, 2), L); up(at(2, 2), R, true); up(at(2, 2), L, true)
    eq(game:State(), "lost", "a chord with a wrong flag loses")
    eq(tile(at(3, 3)).bg._texture, Skin.TEXTURES.tileExploded, "...on the unflagged mine")
    eq(tile(at(1, 3)).text:GetText(), "X", "...and the wrong flag is crossed")
end

do   -- the option: a left click on a satisfied number chords
    local W = fresh({ chordOnLeft = true })
    WoW.slash("/gsweep")
    local game = Gnomesweeper.Board._test.FromLayout(WALL)
    W._test.SetGame(game)
    click(at(2, 2), L)
    click(at(3, 1), R); click(at(3, 2), R); click(at(3, 3), R)
    click(at(2, 2), L)
    eq(tile(at(1, 3)).bg._texture, Skin.TEXTURES.tileRevealed, "chordOnLeft: a left click on a satisfied number chords")

    local W2, game2 = setUpChord()
    click(at(2, 2), L)
    eq(tile(at(1, 3)).bg._texture, Skin.TEXTURES.tileCovered, "without the option, the same click does nothing")
end

----------------------------------------------------------------------------
-- Gestures that must not act
----------------------------------------------------------------------------
do
    local W, game = onWall()
    down(at(1, 1), L)
    up(at(1, 1), L, false)
    eq(game.revealed, 0, "dragging off the tile and releasing reveals nothing")
    eq(tile(at(1, 1)).bg._texture, Skin.TEXTURES.tileCovered, "...and the tile stays covered")

    -- The client may not pass upInside: then the frame is asked.
    local t = tile(at(1, 1))
    t._mouseOver = true
    down(at(1, 1), L); up(at(1, 1), L, nil)
    check(game.revealed > 0, "no upInside argument, cursor over the tile: it counts")

    local W2, game2 = onWall()
    local t2 = tile(at(1, 1))
    t2._mouseOver = false
    down(at(1, 1), L); up(at(1, 1), L, nil)
    eq(game2.revealed, 0, "no upInside argument, cursor off the tile: it doesn't")

    -- Closing the window with a button held is not a click.
    local W3, game3 = onWall()
    down(at(1, 1), L)
    W3.win:Hide()
    W3.win:Show()
    up(at(1, 1), L, true)
    eq(game3.revealed, 0, "a press cut off by closing the window does nothing on release")

    -- A new game forgets a click in flight.
    local W4, game4 = onWall()
    down(at(1, 1), L)
    W4.NewGame()
    up(at(1, 1), L, true)
    eq(W4.game.revealed, 0, "a new game forgets a press in flight")

    W4.Dispatch("reveal", 99999)
    W4.Dispatch("bogus", 1)
    check(true, "an unknown cell or action doesn't error")
end

----------------------------------------------------------------------------
-- The end of a game
----------------------------------------------------------------------------
do
    local W, game = onWall()
    local ui = W._test.ui
    click(at(4, 4), R)                          -- a wrong flag: (4,4) is safe
    click(at(3, 2), R)                          -- a right one
    click(at(3, 1), L)                          -- a mine
    eq(game:State(), "lost", "revealing a mine loses")

    local boom = tile(at(3, 1))
    eq(boom.bg._texture, Skin.TEXTURES.tileExploded, "the mine you hit is on a red tile")
    eq(boom.icon._texture, Skin.TEXTURES.mine, "...with the bomb on it")
    local other = tile(at(3, 3))
    eq(other.bg._texture, Skin.TEXTURES.tileRevealed, "the other mines are shown on flat tiles")
    eq(other.icon._texture, Skin.TEXTURES.mine, "...with their bombs")
    eq(tile(at(3, 2)).icon._texture, Skin.TEXTURES.flag, "a correct flag stays a flag")
    check(tile(at(3, 2)).text == nil or not tile(at(3, 2)).text:IsShown(), "...uncrossed")
    eq(tile(at(4, 4)).icon._texture, Skin.TEXTURES.flag, "a wrong flag still shows its flag")
    eq(tile(at(4, 4)).text:GetText(), "X", "...with a red X over it")
    eq(tile(at(4, 4)).text._textColor[1], Skin.COLORS.wrongFlag[1], "(red)")
    eq(tile(at(4, 4)).icon._desaturated, true, "...over a greyed flag, so the red X shows (red on the red banner was invisible)")
    eq(tile(at(3, 2)).icon._desaturated, false, "a correct flag keeps its colour")

    eq(tile(at(1, 1)).hl:GetAlpha(), 0, "once the game is over a covered tile has no hover glow")
    eq(tile(at(5, 4)).hl:GetAlpha(), 0, "...none of them")
    check(W.win._scripts.OnUpdate == nil, "the clock stopped")

    local before = paints()
    click(at(1, 1), L)
    click(at(1, 2), R)
    eq(paints() - before, 0, "clicks after the game do nothing")

    -- The face starts again.
    ui.face._scripts.OnClick(ui.face)
    WoW.settle()                       -- the new game arrives after the lead and the wave (#43)
    eq(W.game:State(), "ready", "the face starts a new game")
    eq(tile(at(3, 1)).bg._texture, Skin.TEXTURES.tileCovered, "...with every tile covered again")
    eq(tile(at(1, 1)).hl:GetAlpha(), 1, "...and the hover glow back once the wave lands")
end

do   -- a win
    local W, game = onWall()
    click(at(1, 1), L)
    click(at(5, 1), L)
    eq(game:State(), "won", "revealing every safe cell wins")
    for y = 1, 4 do eq(tile(at(3, y)).icon._texture, Skin.TEXTURES.flag, "mine (3," .. y .. ") is flagged") end
    eq(W._test.ui.counter:GetText(), "0", "the counter reads 0")
    eq(tile(at(4, 2)).hl:GetAlpha(), 0, "no hover glow after a win")
end

----------------------------------------------------------------------------
-- The commands that measure
----------------------------------------------------------------------------
do
    local W = fresh()
    WoW.slash("/gsweep")
    local game = W.game
    WoW.chat = {}
    WoW.slash("/gsweep perf")
    check(chatHas("build Expert"), "/gsweep perf reports the Expert build")
    check(chatHas("first reveal and repaint"), "...the first reveal")
    check(chatHas("a loss, every mine shown"), "...a loss")
    check(chatHas("10 difficulty switches"), "...and switching difficulty")
    eq(W.game, game, "the real game is untouched by the benchmark")
    eq(tile(1).bg._texture, Skin.TEXTURES.tileCovered, "...and the board is put back")
    check(tile(81):IsShown() and not tile(82):IsShown(), "...at the right size")

    WoW.chat = {}
    WoW.slash("/gsweep input")
    check(chatHas("logging on"), "/gsweep input turns the log on")
    click(5, L)
    check(chatHas("tile 5  down  LeftButton"), "...and logs a press")
    check(chatHas("upInside=true"), "...and a release with its arguments")
    local saved = GnomesweeperDB.inputLog
    check(type(saved) == "table" and #saved >= 2, "...and keeps the lines in the saved variables, for a /reload to write out")
    check(saved[1]:find("tile 5  down  LeftButton", 1, true), "...each with its time and its text")
    WoW.slash("/gsweep input")
    check(chatHas("logging off"), "...and again turns it off")

    -- With the log on, each action says what the cell was and what it did.
    do
        local W2, game2 = onWall()
        WoW.chat = {}
        WoW.slash("/gsweep input")
        click(at(2, 2), L)
        check(chatHas("reveal on (2,2) covered, 0 flags around -> 1 cells changed (playing)"), "a reveal is described")
        click(at(3, 1), R); click(at(3, 2), R)
        check(chatHas("mark on (3,1) covered, 0 flags around -> 1 cells changed"), "a mark is described")
        click(at(2, 2), M)
        check(chatHas("chord on (2,2) revealed 3, 2 flags around -> 0 cells changed"), "a chord that does nothing says why: 3, 2 flags")
        click(at(3, 3), R)
        click(at(2, 2), M)
        check(chatHas("chord on (2,2) revealed 3, 3 flags around -> 7 cells changed"), "a chord that works says what it opened")
        WoW.slash("/gsweep input")
    end
    local count = #GnomesweeperDB.inputLog
    click(6, L)
    eq(#GnomesweeperDB.inputLog, count, "with the log off, nothing more is kept")

    -- A new session starts a fresh log, and it is capped.
    WoW.slash("/gsweep input")
    eq(#GnomesweeperDB.inputLog, 0, "turning it on again starts a fresh log")
    for i = 1, 200 do click(7, L) end
    check(#GnomesweeperDB.inputLog <= 300, "the saved log is capped (" .. #GnomesweeperDB.inputLog .. " lines)")
    WoW.slash("/gsweep input")
end

done("test_grid")
