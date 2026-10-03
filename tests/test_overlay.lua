-- The end of a game: the faces, the cleared and wipe overlays. Driven through the
-- stub client on hand-built boards, so every shape asserted is exact.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local L, R = "LeftButton", "RightButton"

local function lastPoint(w) return w._points[#w._points] end

local function fresh(db)
    loadAddon({ db = db })
    math.randomseed(7)
    return Gnomesweeper.Window
end

local function tile(i) return Gnomesweeper.Grid._test.tiles[i] end
local function click(i, b)
    local t = tile(i)
    t._scripts.OnMouseDown(t, b)
    t._scripts.OnMouseUp(t, b, true)
end

local WALL = { "..*..", "..*..", "..*..", "..*.." }       -- 5 wide, 4 tall: a wall of mines in column 3
local function at(x, y) return (y - 1) * 5 + x end

local function onWall()
    local W = fresh()
    WoW.slash("/gsweep")
    W._test.SetGame(Gnomesweeper.Board._test.FromLayout(WALL))
    return W
end

local Skin

----------------------------------------------------------------------------
-- The face follows the game
----------------------------------------------------------------------------
do
    local W = fresh()
    WoW.slash("/gsweep")
    Skin = Gnomesweeper.Skin
    local ui = W._test.ui
    eq(ui.face.state, "ready", "a new game: the mascot is ready")
    eq(ui.face.face._texture, Skin.TEXTURES.face, "...and her face is the logo's gnome")
    eq(ui.logo._texture, Skin.TEXTURES.face, "...the same one in the title bar (one mascot, not three characters)")
    eq(ui.face.ring._vertex[1], Skin.FACE_RING.ready[1], "...in the ready ring")
    check(not ui.face.overlay:IsShown(), "...with nothing over her")
    eq(ui.overlay, nil, "...and no overlay has even been built")

    click(41, L)
    eq(W.game:State(), "playing", "(the first click started the game)")
    eq(ui.face.state, "playing", "playing: the mascot follows the game")
    eq(ui.face.face._texture, Skin.TEXTURES.face, "...still the same gnome")

    for i = 1, W.game.total do                          -- end it on a mine
        if W.game._mine[i] then click(i, L); break end
    end
    eq(W.game:State(), "lost", "(a mine was revealed)")
    eq(ui.face.state, "lost", "lost: the mascot follows the game")
    eq(ui.face.face._texture, Skin.TEXTURES.face, "...still the same gnome, not a bomb")
    eq(ui.face.ring._vertex[1], Skin.FACE_RING.lost[1], "...in a red ring")
    check(ui.face.overlay:IsShown() and ui.face.overlay._texture == Skin.TEXTURES.faceSoot, "...with soot over her")

    ui.face._scripts.OnClick(ui.face)
    WoW.settle()                       -- the new game arrives after the lead and the wave (#43)
    eq(ui.face.state, "ready", "the face starts a new game, and goes back to ready")
    check(not ui.face.overlay:IsShown(), "...and the soot is gone")

    -- She is one character; the state shows in her ring and what is over her, and the ready,
    -- cleared and wiped looks are three different ones.
    local function look(state)
        return table.concat(Skin.FACE_RING[state], ",") .. "/" .. tostring(Skin.FACE_OVERLAY[state])
    end
    check(look("ready") ~= look("won") and look("won") ~= look("lost") and look("ready") ~= look("lost"),
        "ready, cleared and wiped look different from one another (by ring and overlay, not by colour alone)")
    -- ...and the colours mean what they say (not compared with themselves).
    local ready, won, lost = Skin.FACE_RING.ready, Skin.FACE_RING.won, Skin.FACE_RING.lost
    check(won[1] > 0.9 and won[2] > 0.7 and won[3] < 0.5, "the cleared ring is gold")
    check(lost[1] > 0.9 and lost[2] < 0.5 and lost[3] < 0.5, "the wiped ring is red")
    check(ready[3] > 0.9 and ready[1] < 0.3, "the ready ring is cyan-blue")
end

----------------------------------------------------------------------------
-- Field cleared
----------------------------------------------------------------------------
do
    local W = onWall()
    local ui = W._test.ui
    Skin = Gnomesweeper.Skin
    WoW.now = 10
    click(at(1, 1), L)
    check(ui.overlay == nil or not ui.overlay:IsShown(), "no overlay while the game is on")
    WoW.now = 84
    click(at(5, 1), L)
    eq(W.game:State(), "won", "(the field is cleared)")

    local o = ui.overlay
    check(o ~= nil and o:IsShown(), "the cleared overlay is up")
    eq(o.title:GetText(), "Field cleared!", "...with the storyboard's words")
    eq(o.title._textColor[1], Skin.COLORS.gold[1], "...in gold")
    eq(o.time:GetText(), "Time 01:24", "...and the time (84 seconds)")
    check(o.time:IsShown(), "...shown")
    check(not o.best:IsShown(), "'New personal best!' stays hidden until #7 can say it's true")
    eq(o.button.label:GetText(), "Play again", "the button says Play again")
    eq(o.glass.rim._vertex[1], Skin.COLORS.winRim[1], "the rim is gold")
    eq(o.glass.rim._vertex[3], Skin.COLORS.winRim[3], "(its blue is low)")
    eq(ui.face.state, "won", "the mascot is in her cleared state")
    eq(ui.face.ring._vertex[1], Skin.FACE_RING.won[1], "...in a gold ring")
    check(ui.face.overlay:IsShown() and ui.face.overlay._texture == Skin.TEXTURES.faceSparkle, "...with sparkles over her")
    eq(ui.counter:GetText(), "0", "every mine is flagged, so the counter reads 0")

    check(o._mouse, "the overlay takes the mouse, so the board under it gets no clicks")
    check(o._level > tile(1)._level and o._level > ui.grid._level, "...and sits above the tiles")
    check(o._level < W._test.menu()._level, "...but under the difficulty list")
    check(o._width <= ui.grid._width, "it fits the board (" .. o._width .. " of " .. ui.grid._width .. ")")
    local p = lastPoint(o)
    check(p[1] == "CENTER" and p[2] == ui.grid and p[3] == "CENTER", "...centred on it")
    eq(o._height, 134, "without the personal-best line it is shorter")
end

----------------------------------------------------------------------------
-- The wipe
----------------------------------------------------------------------------
do
    local W = onWall()
    local ui = W._test.ui
    click(at(3, 1), L)
    eq(W.game:State(), "lost", "(a mine was revealed)")

    local o = ui.overlay
    check(o ~= nil and o:IsShown(), "the wipe overlay is up")
    eq(o.title:GetText(), "Boom. Full wipe.", "...with the storyboard's words")
    eq(o.title._textColor[2], Skin.COLORS.boom[2], "...in red")
    check(not o.time:IsShown(), "no time on a loss")
    check(not o.best:IsShown(), "...and no personal best")
    eq(o.button.label:GetText(), "Try again", "the button says Try again")
    eq(o.glass.rim._vertex[1], Skin.COLORS.lossRim[1], "the rim is red")
    eq(o._height, 114, "the wipe overlay is the short one")
    eq(ui.face.state, "lost", "the mascot is in her wiped state")

    -- Both overlays are one frame, re-dressed: no second one is built.
    local frames = #WoW.frames
    ui.face._scripts.OnClick(ui.face)
    WoW.settle()                       -- the new game arrives after the lead and the wave (#43)
    check(not o:IsShown(), "a new game puts the overlay away")
    W._test.SetGame(Gnomesweeper.Board._test.FromLayout(WALL))
    click(at(1, 1), L); click(at(5, 1), L)
    check(ui.overlay == o and o:IsShown(), "the next game's end reuses the same overlay")
    eq(o.title:GetText(), "Field cleared!", "...dressed for a win")
    eq(#WoW.frames, frames, "...creating no frames")
end

----------------------------------------------------------------------------
-- What the overlay does
----------------------------------------------------------------------------
do   -- the button starts a new game
    local W = onWall()
    local ui = W._test.ui
    click(at(3, 1), L)
    local old = W.game
    local o = ui.overlay
    o.button._scripts.OnClick(o.button)
    WoW.settle()                       -- the new game arrives after the lead and the wave (#43)
    check(W.game ~= old, "Try again starts a new game")
    eq(W.game:State(), "ready", "...which is ready")
    check(not o:IsShown(), "...and the overlay goes")
    eq(tile(1).bg._texture, Skin.TEXTURES.tileCovered, "...with the board covered again")
    eq(tile(1).hl:GetAlpha(), 1, "...and tiles live again once the wave lands")
end

do   -- a click on the overlay puts it away, to look at the board
    local W = onWall()
    local ui = W._test.ui
    click(at(3, 1), L)
    local o = ui.overlay
    o._scripts.OnMouseUp(o)
    check(not o:IsShown(), "clicking the overlay puts it away")
    eq(W.game:State(), "lost", "...the game is still over")
    eq(tile(at(3, 3)).icon._texture, Skin.TEXTURES.mine, "...with the mines on show")

    click(at(1, 1), L)
    check(not o:IsShown(), "a click on a finished board doesn't bring it back")
    click(at(1, 2), R)
    check(not o:IsShown(), "...nor a right click")

    W.win:Hide(); W.win:Show()
    check(not o:IsShown(), "closing and reopening the window doesn't either")

    GameTooltip._text = nil
    o._scripts.OnEnter(o)
    eq(GameTooltip._text, "Click to see the field", "hovering it says what a click does")
    o._scripts.OnLeave(o)
end

do   -- the overlay survives closing the window, if it hasn't been put away
    local W = onWall()
    local ui = W._test.ui
    click(at(3, 1), L)
    W.win:Hide(); W.win:Show()
    check(ui.overlay:IsShown(), "an overlay still up stays up through a close and reopen")
end

do   -- the dropdown and the face still work under an overlay
    local W = onWall()
    local ui = W._test.ui
    click(at(3, 1), L)
    ui.diff._scripts.OnClick(ui.diff)
    check(W._test.menu():IsShown(), "the difficulty list opens over a wipe")
    local entries = {}
    for _, c in ipairs(W._test.menu()._children) do
        if c._type == "Button" then entries[#entries + 1] = c end
    end
    entries[3]._scripts.OnClick(entries[3])
    eq(W.game.w, 30, "...and picks a new game")
    check(not ui.overlay:IsShown(), "...which puts the overlay away")
end

do   -- on Expert the overlay is its full width
    local W = fresh()
    WoW.slash("/gsweep expert")
    W._test.SetGame(Gnomesweeper.Board.New(30, 16, 0))      -- no mines: the first click wins
    click(1, L)
    local o = W._test.ui.overlay
    eq(W.game:State(), "won", "(Expert with no mines is won by one click)")
    eq(o._width, 200, "the overlay is 200 wide on a big board")
    check(o.time:GetText():find("^Time %d%d:%d%d$"), "...and shows a clock time")
end

done("test_overlay")
