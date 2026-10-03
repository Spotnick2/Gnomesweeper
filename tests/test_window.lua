-- Window.lua: the glass window, driven through the stub client (slash
-- commands, clicks, drags, ticks, screen changes). Geometry is Layout's and is
-- tested in test_layout; here it's checked that the window APPLIES it.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local function buttons(frame)
    local out = {}
    for _, c in ipairs(frame._children or {}) do
        if c._type == "Button" then out[#out + 1] = c end
    end
    return out
end

local function lastPoint(w) return w._points[#w._points] end

local function chatHas(text)
    for _, line in ipairs(WoW.chat) do
        if line:find(text, 1, true) then return true end
    end
    return false
end

-- A fresh session with the saved variables `db`, and a fixed random seed so
-- the default rng gives the same boards every run.
local function fresh(db)
    loadAddon({ db = db })
    math.randomseed(7)
    return Gnomesweeper.Window
end

local function mineCell(game)
    for i = 1, game.total do
        if game._mine[i] then return (i - 1) % game.w + 1, math.floor((i - 1) / game.w) + 1 end
    end
end

----------------------------------------------------------------------------
-- Building it
----------------------------------------------------------------------------
do
    fresh()
    check(rawget(_G, "GnomesweeperWindow") == nil, "nothing is built until the window is first opened")
    eq(#UISpecialFrames, 0, "...and nothing is registered for Escape yet")

    WoW.slash("/gsweep")
    local W = Gnomesweeper.Window
    local win = rawget(_G, "GnomesweeperWindow")
    check(win ~= nil and win:IsShown(), "/gsweep builds and shows the window")
    eq(W.win, win, "Window.win is the frame")
    eq(win:GetFrameStrata(), "FULLSCREEN_DIALOG", "it sits in the dialog strata")
    check(win._clamped, "it is clamped to the screen")
    check(win._movable and win._mouse, "it is movable and takes the mouse")
    local special = 0
    for _, n in ipairs(UISpecialFrames) do if n == "GnomesweeperWindow" then special = special + 1 end end
    eq(special, 1, "Escape closes it (registered once in UISpecialFrames)")
    check(win.glass and win.glass.top, "it wears the glass material")

    -- Beginner at the default screen: the minimum width, the board centred.
    eq(win._width, 300, "Beginner: the minimum width")
    eq(win._height, 422, "Beginner: 138 + 216 + 68")
    eq(win._scale, 1, "Beginner fits at scale 1")
    local ui = W._test.ui
    eq(ui.grid._width, 216, "the board area is 9 tiles wide")
    eq(ui.grid._height, 216, "...and 9 tiles high")
    local gp = lastPoint(ui.grid)
    eq(gp[1], "TOPLEFT", "the board is anchored top-left")
    eq(gp[2], win, "...to the window")
    eq(gp[4], 42, "...centred (42 in from the left)")
    eq(gp[5], -138, "...below the chrome")
    eq(W.grid, ui.grid, "the tile grid (#4) draws into Window.grid")
    local cp = lastPoint(win)
    check(cp[1] == "CENTER" and cp[2] == UIParent, "with no saved position it opens in the middle of the screen")

    -- The HUD.
    eq(ui.counter:GetText(), "10", "the counter shows the mines left")
    eq(ui.timer:GetText(), "00:00", "the clock starts at 00:00")
    check(ui.hintStart:IsShown(), "'Choose a tile to begin.' shows in the ready state")
    eq(ui.hintStart:GetText(), "Choose a tile to begin.", "...with the storyboard's words")
    eq(ui.diff.label:GetText(), "Beginner", "the difficulty button names the difficulty")
    eq(W.game:State(), "ready", "the first game is ready")
    eq(W.game.w, 9, "...Beginner-sized")

    -- Toggle, and the close button.
    WoW.slash("/gsweep")
    check(not win:IsShown(), "/gsweep again closes it")
    WoW.slash("/gnomesweeper")
    check(win:IsShown(), "/gnomesweeper opens it")
    WoW.slash("/minewipe")
    check(not win:IsShown(), "/minewipe toggles it too")
    win:Show()
    local close = ui.close
    check(close ~= nil, "there is a close button")
    close._scripts.OnClick(close)
    check(not win:IsShown(), "...and it closes the window")

    -- Nothing here is secure: it works in combat.
    local secure = false
    for _, f in ipairs(WoW.frames) do
        if f._template and f._template:find("Secure") then secure = true end
    end
    check(not secure, "no secure frame anywhere (the window works in combat)")

    -- A tooltip on the gear.
    ui.gear._scripts.OnEnter(ui.gear)
    check(WoW.methodsCalled["GameTooltip:SetOwner"], "the gear shows a tooltip")
    ui.gear._scripts.OnLeave(ui.gear)
end

----------------------------------------------------------------------------
-- The clock and the HUD follow the game
----------------------------------------------------------------------------
do
    local W = fresh()
    WoW.slash("/gsweep")
    local win, ui = W.win, W._test.ui

    WoW.now = 10
    local g = W.game
    g:Reveal(5, 5, 10)
    eq(g:State(), "playing", "(the first reveal didn't end the game)")
    W.Refresh()
    check(win._scripts.OnUpdate ~= nil, "while a game is on, the clock is driven")
    check(not ui.hintStart:IsShown(), "the start hint goes away once playing")

    WoW.now = 15
    WoW.tick(0.05)
    eq(ui.timer:GetText(), "00:00", "a tick under 0.1 s doesn't redraw")
    WoW.tick(0.1)
    eq(ui.timer:GetText(), "00:05", "the clock shows the seconds played")

    WoW.now = 20
    win:Hide()
    WoW.now = 100
    win:Show()
    eq(ui.timer:GetText(), "00:10", "closing the window paused the game: 10 seconds played, not 90")
    WoW.now = 103
    WoW.tick(0.2)
    eq(ui.timer:GetText(), "00:13", "...and it runs on from there")

    -- Flags: place n of them on cells that are still covered.
    local function flag(n)
        for i = 1, g.total do
            if n == 0 then break end
            if g:Cell(i).state == "covered" then
                g:ToggleMark((i - 1) % g.w + 1, math.floor((i - 1) / g.w) + 1)
                n = n - 1
            end
        end
    end
    flag(9)
    W.Refresh()
    eq(ui.counter:GetText(), "1", "the counter follows the flags (10 - 9)")
    flag(2)
    W.Refresh()
    eq(ui.counter:GetText(), "-1", "...and goes negative")

    -- A loss stops the clock and its driver.
    for i = 1, g.total do          -- take every flag off again
        if g:Cell(i).state == "flag" then g:ToggleMark((i - 1) % g.w + 1, math.floor((i - 1) / g.w) + 1) end
    end
    local mx, my = mineCell(g)
    WoW.now = 110
    g:Reveal(mx, my, 110)
    eq(g:State(), "lost", "(a mine was revealed)")
    W.Refresh()
    check(win._scripts.OnUpdate == nil, "once the game is over there is no OnUpdate")
    eq(ui.timer:GetText(), "00:20", "...and the clock holds the final time")
    WoW.now = 500
    WoW.tick(1)
    eq(ui.timer:GetText(), "00:20", "...whatever the time does")

    -- The face is a new game.
    local old = W.game
    ui.face._scripts.OnClick(ui.face)
    check(W.game ~= old, "clicking the face starts a new game")
    eq(W.game:State(), "ready", "...which is ready")
    eq(W.game.w, 9, "...at the same difficulty")
    eq(ui.counter:GetText(), "10", "...with all its mines to find")
    eq(ui.timer:GetText(), "00:00", "...and the clock back at 00:00")
    check(ui.hintStart:IsShown(), "...and the start hint back")
    check(win._scripts.OnUpdate == nil, "...and no clock driver while it's only ready")
end

----------------------------------------------------------------------------
-- Difficulty
----------------------------------------------------------------------------
do
    local W = fresh()
    WoW.slash("/gsweep")
    local win, ui = W.win, W._test.ui
    local menu = W._test.menu()

    check(not menu:IsShown(), "the difficulty list starts closed")
    ui.diff._scripts.OnClick(ui.diff)
    check(menu:IsShown(), "clicking the difficulty button opens the list")
    ui.diff._scripts.OnClick(ui.diff)
    check(not menu:IsShown(), "...and clicking it again closes it")

    local entries = buttons(menu)
    eq(#entries, 3, "three difficulties")
    eq(entries[1].label:GetText(), "Beginner", "...Beginner")
    eq(entries[2].label:GetText(), "Intermediate", "...Intermediate")
    eq(entries[3].label:GetText(), "Expert", "...Expert")

    local before = W.game
    ui.diff._scripts.OnClick(ui.diff)
    entries[1]._scripts.OnClick(entries[1])
    eq(W.game, before, "picking the current difficulty keeps the game")
    check(not menu:IsShown(), "...and closes the list")

    ui.diff._scripts.OnClick(ui.diff)
    entries[3]._scripts.OnClick(entries[3])
    eq(GnomesweeperDB.difficulty, "expert", "picking Expert is remembered")
    eq(W.game.w, 30, "...a new 30-wide game")
    eq(W.game.mines, 99, "...with 99 mines")
    eq(ui.counter:GetText(), "99", "...shown in the counter")
    eq(ui.diff.label:GetText(), "Expert", "...and on the button")
    check(not menu:IsShown(), "...and the list closed")
    eq(win._width, 748, "the window resized to the board (748 wide)")
    eq(win._height, 590, "...(590 high)")
    eq(ui.grid._width, 720, "...with a 720-wide board area")
    eq(ui.grid._height, 384, "...384 high")
    eq(lastPoint(ui.grid)[4], 14, "...which sits 14 in from the left")

    ui.diff._scripts.OnClick(ui.diff)
    entries[2]._scripts.OnClick(entries[2])
    eq(W.game.w, 16, "Intermediate is 16 wide")
    eq(win._width, 412, "...in a 412-wide window")

    -- A click anywhere else closes the list; a click on it or its button doesn't.
    ui.diff._scripts.OnClick(ui.diff)
    WoW.mouseDown = true
    menu._mouseOver, ui.diff._mouseOver = false, false
    WoW.tick()
    check(not menu:IsShown(), "a click outside closes the list")

    ui.diff._scripts.OnClick(ui.diff)
    menu._mouseOver = true
    WoW.tick()
    check(menu:IsShown(), "a click on the list leaves it open (its entry handles it)")
    menu._mouseOver, ui.diff._mouseOver = false, true
    WoW.tick()
    check(menu:IsShown(), "a click on the button leaves it open (its own handler toggles)")
    WoW.mouseDown = false
    menu._mouseOver, ui.diff._mouseOver = false, false
    WoW.tick()
    check(menu:IsShown(), "with no click it stays open")
    win:Hide()
    check(not menu:IsShown(), "closing the window closes the list")
    check(menu._scripts.OnUpdate == nil, "...and leaves no OnUpdate behind")
end

----------------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------------
do
    local W = fresh()
    WoW.slash("/gsweep Expert ")
    check(W.win:IsShown(), "/gsweep expert opens the window")
    eq(W.game.w, 30, "...at Expert (case and spaces don't matter)")
    eq(GnomesweeperDB.difficulty, "expert", "...and remembers it")

    local g = W.game
    WoW.slash("/gsweep expert")
    eq(W.game, g, "the same difficulty again keeps the game")
    check(W.win:IsShown(), "...and the window stays open (it does not toggle)")

    WoW.slash("/gsweep beginner")
    eq(W.game.w, 9, "/gsweep beginner starts a Beginner game")
    eq(W.win._width, 300, "...and resizes")

    g = W.game
    WoW.slash("/gsweep bogus")
    check(chatHas("unknown option 'bogus'"), "an unknown option says so")
    check(chatHas("/gsweep reset"), "...and lists the commands")
    eq(W.game, g, "...without touching the game")
    check(W.win:IsShown(), "...or the window")

    WoW.chat = {}
    WoW.slash("/gsweep help")
    check(chatHas("beginner | intermediate | expert"), "help lists the difficulties")
    check(not chatHas("unknown option"), "...without calling it an error")

    W.Open("bogus")
    eq(GnomesweeperDB.difficulty, "beginner", "Window.Open ignores a difficulty that doesn't exist")
end

----------------------------------------------------------------------------
-- Position
----------------------------------------------------------------------------
do
    local W = fresh()
    WoW.slash("/gsweep")
    local win = W.win
    win._scripts.OnDragStart(win)
    check(win._moving, "dragging the window moves it")
    win._left, win._top = 200, 600
    win._scripts.OnDragStop(win)
    check(not win._moving, "...and dropping stops")
    eq(GnomesweeperDB.pos.left, 200, "the corner is saved (left)")
    eq(GnomesweeperDB.pos.top, 600, "...(top)")
    win:Hide(); win:Show()
    local p = lastPoint(win)
    check(p[1] == "TOPLEFT" and p[2] == UIParent and p[3] == "BOTTOMLEFT" and p[4] == 200 and p[5] == 600,
        "the saved corner is restored on reopening")

    win._scripts.OnDragStart(win)
    win:Hide()
    check(not win._moving, "hiding the window mid-drag drops it")

    WoW.slash("/gsweep reset")
    eq(GnomesweeperDB.pos, nil, "/gsweep reset forgets the position")
    check(lastPoint(win)[1] == "CENTER", "...and recentres the window")
    check(chatHas("position reset"), "...and says so")

    -- A saved position off the screen is pulled back on.
    GnomesweeperDB.pos = { left = -500, top = 5000 }
    win:Hide(); win:Show()
    p = lastPoint(win)
    eq(p[4], 0, "a corner off the left edge is pulled to it")
    eq(p[5], 768, "...and one off the top to the top")
    GnomesweeperDB.pos = "garbage"
    win:Hide(); win:Show()
    eq(lastPoint(win)[1], "CENTER", "a garbage saved position is ignored")
end

do   -- scaled: positions are saved in UIParent units (the window's own space times its scale)
    WoW.setScreen(800, 600)
    local W = fresh()
    WoW.setScreen(800, 600)
    WoW.slash("/gsweep expert")
    local win = W.win
    local s = win._scale
    check(s < 1 and s > 0.9, "Expert on an 800x600 screen is scaled down (" .. s .. ")")
    check(748 * s <= 800 * 0.95 and 590 * s <= 600 * 0.95, "...so the window fits inside the screen")

    win._left, win._top = 50, 550                       -- in the window's own space
    win._scripts.OnDragStop(win)
    check(math.abs(GnomesweeperDB.pos.left - 50 * s) < 1e-9, "the saved left is in UIParent units (own space x scale)")
    check(math.abs(GnomesweeperDB.pos.top - 550 * s) < 1e-9, "...and so is the top")

    win:Hide(); win:Show()
    local p = lastPoint(win)
    -- The top is pulled down so the whole window stays on the screen: the
    -- window is 590 * s tall and the screen 600.
    local wantLeft, wantTop = 50 * s, math.max(550 * s, 590 * s)
    check(math.abs(p[4] * s - wantLeft) < 1e-6, "restored: the offset times the scale is the saved left")
    check(math.abs(p[5] * s - wantTop) < 1e-6, "...and the saved top, kept inside the screen")
end

----------------------------------------------------------------------------
-- Screen changes
----------------------------------------------------------------------------
do
    local W = fresh()
    WoW.slash("/gsweep expert")
    local win = W.win
    eq(win._scale, 1, "Expert fits the default screen")

    WoW.setScreen(1024, 600)
    WoW.fire("DISPLAY_SIZE_CHANGED")
    check(win._scale < 1, "a smaller screen rescales the open window")
    check(748 * win._scale <= 1024 * 0.95 and 590 * win._scale <= 600 * 0.95, "...to fit it")

    WoW.setScreen(1920, 1080)
    WoW.fire("UI_SCALE_CHANGED")
    eq(win._scale, 1, "a UI scale change refits it too, back to 1")

    win:Hide()
    WoW.setScreen(1024, 600)
    win:Show()
    check(win._scale < 1, "reopening after a screen change refits without waiting for an event")
end

----------------------------------------------------------------------------
-- Saved variables
----------------------------------------------------------------------------
do
    local W = fresh()
    WoW.slash("/gsweep expert")
    W.win._left, W.win._top = 120, 640
    W.win._scripts.OnDragStop(W.win)
    local saved = GnomesweeperDB

    W = fresh(saved)
    WoW.slash("/gsweep")
    eq(W.game.w, 30, "the difficulty survives a reload")
    local p = lastPoint(W.win)
    check(p[4] == 120 and p[5] == 640, "...and so does the position")

    W = fresh({ difficulty = "nonsense" })
    WoW.slash("/gsweep")
    eq(W.game.w, 9, "a difficulty that isn't one falls back to Beginner")

    W = fresh({ questionMarks = true, safeZone = "cell" })
    WoW.slash("/gsweep")
    check(W.game.questionMarks, "the question-marks setting reaches the board")
    eq(W.game.safeZone, "cell", "...and so does the safe-zone setting")
end

done("test_window")
