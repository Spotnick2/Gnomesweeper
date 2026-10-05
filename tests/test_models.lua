-- Models.lua: live models in the end panel (#21). On its left: the Walking Bomb going
-- off on a wipe, Tally jumping for joy on a win, the panel widened for it. Driven
-- through the stub's scenes (WoW.modelBoxes, WoW.modelSetFails; the end panel's models
-- are absent unless a test brings them).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local L = "LeftButton"
local BOMB = { -1.4, -1.2, -1.95, 1.4, 1.2, 1.95 }          -- the Walking Bomb's box: 3.9 high (#20)
local TALLY = { -0.4, -0.4, -0.67, 0.4, 0.4, 0.67 }          -- Tally's: 1.34
local WALL = { "..*..", "..*..", "..*..", "..*.." }         -- a wall of mines in column 3
local function at(x, y) return (y - 1) * 5 + x end

local function tile(i) return Gnomesweeper.Grid._test.tiles[i] end
local function click(i, b)
    local t = tile(i)
    t._scripts.OnMouseDown(t, b or L)
    t._scripts.OnMouseUp(t, b or L, true)
end
local function said(text)
    for _, line in ipairs(WoW.chat) do if line:find(text, 1, true) then return true end end
    return false
end

-- A window with the models brought in (or not), on a board about to end.
local function board(opts)
    opts = opts or {}
    loadAddon({ db = opts.db })
    if not opts.absent then WoW.modelSetFails[6977], WoW.modelSetFails[3124] = nil, nil end
    if not opts.noBox then WoW.modelBoxes[6977], WoW.modelBoxes[3124] = BOMB, TALLY end
    WoW.slash("/gsweep" .. (opts.preset and (" " .. opts.preset) or ""))
    local W = Gnomesweeper.Window
    W._test.SetGame(opts.win and Gnomesweeper.Board.New(5, 4, 0) or Gnomesweeper.Board._test.FromLayout(WALL))
    return W, W._test.ui
end
local function wipe() click(at(3, 2)) end
local function win() click(1) end

-- The panel's width, laid out with or without the model column.
local function widths(W)
    local base = math.min(200, W.size.gridW - 12)
    return base, math.min(340, W.size.width - 16)
end
-- The centre of the words' column, from the panel's left (the model's column is 100).
local function centre(total, col) return col + (total - col) / 2 end

----------------------------------------------------------------------------
-- A wipe: the panel at once, the bomb going off on its left
----------------------------------------------------------------------------
do
    local W, ui = board()
    local Mo = Gnomesweeper.Models
    wipe()
    local o = ui.overlay
    check(o and o:IsShown(), "the panel comes at once")
    local scene, actor = ui.slot.scene, ui.slot._test.actor()
    check(scene and scene._shown, "the bomb is shown")
    eq(scene._type, "ModelScene", "in a ModelScene")
    eq(scene._parent, o, "in the panel")
    eq(scene._points[1][1], "CENTER", "centred...")
    eq(scene._points[1][2], o, "...on the panel's...")
    eq(scene._points[1][3], "BOTTOMLEFT", "...left column...")
    eq(scene._points[1][4], 50, "...centred in it (100 wide)")
    eq(scene._points[1][5], 8 + Mo.HEIGHT / 2, "...standing on the panel's floor (the mockup)")
    check(Mo.FRAME - Mo.HEIGHT >= 50, "room above and below the model for its fuse and blast (in game: 2 units cut them)")
    eq(scene:GetFrameLevel(), Gnomesweeper.Glass.ContentLevel(o), "at the panel's content level, under its rim")
    eq(scene._width, Mo.FRAME, "its scene")
    check(Mo.FRAME > Mo.HEIGHT, "...bigger than the model drawn in it (a model past its scene is cut off)")
    eq(actor._model, 6977, "the Walking Bomb, by display ID")
    check(actor._composite ~= true, "never composited with the player")
    check((actor._clears or 0) > 0, "the actor cleared before the load")
    eq(actor._anim, 1, "playing its death: the explosion (#20)")
    eq(actor._particles, 1, "with its particles")
    local span = 2 * 40 * math.tan(0.15 / 2)
    check(math.abs(actor._scale * 3.9 / span * Mo.FRAME - Mo.HEIGHT) < 1e-9, "its box drawn HEIGHT units tall")

    local narrow, wide = widths(W)
    eq(o._width, wide, "the panel widened for it")
    check(o._height >= Mo.HEIGHT + 28, "...and tall enough for it, fuse included")
    eq(o._height, 142, "the wipe panel: as tall with or without it")
    eq(o.title._points[1][1], "TOP", "the title centred...")
    eq(o.title._points[1][4], centre(wide, 100), "...on the words' column, beside the bomb")
    eq(o.title._justifyH, "CENTER", "...like the win panel (owner: cohesive)")
    check(o.divider:IsShown(), "a thin line parts the model's column from the words'")
    eq(o.divider._points[1][4], 100, "...at the column's edge")
    eq(o.subtitle:GetText(), "One more try?", "the line under it (owner)")
    eq(o.subtitle._points[1][2], o.title, "...under the title")
    local cx = centre(wide, 100)
    eq(o.button._points[1][4], cx, "the buttons span the column...")
    eq(o.button:GetWidth(), wide - 100 - 24, "...edge to edge, less its margins")
    eq(o.view._points[1][4], cx, "...both")
    check(o.button.primary, "Try again is the main action: filled blue (the mockup)")
    check(not o.view.primary, "See the field isn't")

    eq(scene._camera[3], 0, "level while it stands and goes off")
    WoW.advance(Mo.CAST.wipe.steps[1][2] + 0.05)
    eq(actor._anim, 6, "then it lies in its dead pose")
    local span = 2 * 40 * math.tan(0.15 / 2)
    check(math.abs(scene._camera[3] + Mo.CAST.wipe.steps[2].lift * span / Mo.FRAME) < 1e-9,
        "...raised by its lift: its wreckage lies lower than it stood (in game: below the panel)")
    check(scene._shown, "...still there while the panel is up")

    o.view._scripts.OnClick(o.view)                           -- See the field
    check(not scene._shown, "put away: gone with the panel")
    eq(ui.slot.playing, nil, "...stopped")
end

-- Expert's panel isn't capped by the window; Beginner's is.
do
    -- A board of w x h with one mine in the top-left corner; tile 1 sets it off.
    local function sized(w, h)
        local rows = {}
        for y = 1, h do rows[y] = (y == 1 and "*" or ".") .. string.rep(".", w - 1) end
        return Gnomesweeper.Board._test.FromLayout(rows)
    end
    local W, ui = board()
    W._test.SetGame(sized(30, 16))
    click(1)
    eq(ui.overlay._width, 340, "Expert: as wide as the mockup's panel")
    W, ui = board()
    W._test.SetGame(sized(9, 9))
    click(1)
    eq(ui.overlay._width, W.size.width - 16, "Beginner: as wide as the window allows")
    check(ui.overlay._width < 340, "...which is less")
end

----------------------------------------------------------------------------
-- A win: Tally jumping for joy
----------------------------------------------------------------------------
do
    local W, ui = board({ win = true })
    win()
    eq(W.game:State(), "won", "(won)")
    local actor = ui.slot._test.actor()
    check(ui.overlay:IsShown() and ui.slot.scene._shown, "the panel, with her")
    eq(actor._model, 3124, "Tally Berryfizz, the mascot's model")
    eq(actor._particles, 0, "no particles")
    -- Jumping for joy: jump start, in the air, landing, cheer, and again (owner: Blizzard's
    -- cheer plays once). Walked step by step on the stub's clock.
    local seen, steps = {}, Gnomesweeper.Models.CAST.win.steps
    for round = 1, 2 do
        for _, s in ipairs(steps) do
            seen[#seen + 1] = actor._anim
            WoW.advance(s[2])
        end
    end
    eq(table.concat(seen, " "), "37 38 39 68 37 38 39 68", "jump start, in the air, landing, cheer, and again")
    ui.overlay.view._scripts.OnClick(ui.overlay.view)       -- put away
    local at = actor._anim
    WoW.advance(10)
    eq(actor._anim, at, "put away: the sequence stops")
    ui.overlay:Show()
    eq(actor._anim, 37, "shown again: from the first jump")
    local narrow, wide = widths(W)
    eq(ui.overlay._width, wide, "the win panel widened too")
    eq(ui.overlay.bests._points[1][4], centre(wide, 100) + 3, "Best times shares the bottom row")
    eq(ui.overlay.title:GetText(), "Clean sweep!", "the owner's words: Clean sweep!")
    eq(ui.overlay.subtitle:GetText(), "Not a hair out of place.", "...Not a hair out of place.")
    eq(ui.overlay.button.label:GetText(), "Play again", "...Play again")
    check(ui.overlay.button.primary, "...the main action, blue")
    eq(ui.overlay.button.glow, nil, "...without an outer glow (the second mockup)")
    eq(ui.overlay.bests.accent[1], ui.overlay.view.accent[1], "Best times styled like See the field (the second mockup)")
    eq(ui.overlay.bests.accent[3], ui.overlay.view.accent[3], "...both")
    check(ui.overlay.divider:IsShown(), "the same thin line as the wipe's")
end

----------------------------------------------------------------------------
-- When it can't play: the panel as before
----------------------------------------------------------------------------
do
    local W, ui = board({ absent = true })
    wipe()
    local narrow = widths(W)
    check(ui.overlay:IsShown(), "the model absent: the panel")
    eq(ui.overlay._width, narrow, "...at its old width")
    eq(ui.overlay.title._points[1][1], "TOP", "...the title centred")
    eq(ui.overlay.title._points[1][4], narrow / 2, "...on the panel")
    eq(ui.overlay._height, 142, "...and the same height")
    check(not ui.slot.scene._shown, "nothing drawn")
end
do
    local W, ui = board({ db = { models = false } })
    wipe()
    eq(ui.overlay._width, (widths(W)), "the setting off: the old width")
    eq(ui.slot.scene, nil, "no scene made")
end
do
    local W, ui = board({ noBox = true })                     -- present, but too slow
    wipe()
    local narrow, wide = widths(W)
    eq(ui.overlay._width, wide, "a model on its way: laid out for it")
    WoW.advance(Gnomesweeper.Models.WAIT + 0.05)
    eq(ui.overlay._width, narrow, "not in after WAIT: laid out without it")
    WoW.modelBoxes[6977] = BOMB
    WoW.advance(3)
    check(not ui.slot.scene._shown, "a box arriving late draws nothing")
end
do
    loadAddon()
    WoW.modelSetFails[6977] = nil
    WoW.modelBoxes[6977] = BOMB
    local real = CreateFrame
    CreateFrame = function(ftype, ...)
        if ftype == "ModelScene" then error("unknown frame type") end
        return real(ftype, ...)
    end
    WoW.slash("/gsweep")
    local W = Gnomesweeper.Window
    W._test.SetGame(Gnomesweeper.Board._test.FromLayout(WALL))
    wipe()
    CreateFrame = real
    local o = W._test.ui.overlay
    check(o:IsShown() and o._width == (widths(W)), "no ModelScene on this client: the panel as before")
end

----------------------------------------------------------------------------
-- Interrupted, and shown again
----------------------------------------------------------------------------
do
    local W, ui = board()
    wipe()
    local actor = ui.slot._test.actor()
    ui.face._scripts.OnClick(ui.face)                         -- a new game, mid-explosion
    check(not ui.slot.scene._shown, "a new game: the bomb is gone")
    WoW.advance(5)
    eq(actor._anim, 1, "...and its dead pose never comes")
end
do
    local W, ui = board({ noBox = true })
    wipe()                                                    -- the bomb still loading...
    WoW.advance(0.2)
    ui.face._scripts.OnClick(ui.face)                         -- ...a new game
    WoW.modelBoxes[6977] = BOMB                               -- ...and then its box arrives
    WoW.advance(2)
    check(not ui.slot.scene._shown, "a load dropped by a new game never shows")
end
do
    local W, ui = board()
    wipe()
    WoW.advance(2)
    local actor = ui.slot._test.actor()
    eq(actor._anim, 6, "(lying there)")
    ui.overlay:Hide()                                         -- the window closing hides it (the client)
    check(not ui.slot.scene._shown, "hidden with the panel")
    ui.overlay:Show()                                         -- reopened
    check(ui.slot.scene._shown, "shown again")
    eq(actor._anim, 1, "...and it goes off again")
    eq(ui.slot.scene._camera[3], 0, "...level again, standing")
end

----------------------------------------------------------------------------
-- The setting
----------------------------------------------------------------------------
do
    loadAddon()
    local O = Gnomesweeper.Options
    eq(GnomesweeperDB.models, true, "on by default")
    local found
    for _, item in ipairs(O.ITEMS) do if item.key == "models" then found = item end end
    check(found and found.kind == "toggle", "a toggle in the settings")
    O.Set("models", false)
    eq(GnomesweeperDB.models, false, "turned off")
    check(not Gnomesweeper.Models.Enabled(), "...and the models know")
    O.Set("models", "x")
    eq(GnomesweeperDB.models, false, "a bad value is refused")
end

----------------------------------------------------------------------------
-- /gsweep bomb (for measuring): the panel's model again
----------------------------------------------------------------------------
do
    local W, ui = board()
    W.win:Hide()
    WoW.slash("/gsweep bomb")
    check(said("open the board first"), "it needs the board open")
    W.win:Show()
    WoW.slash("/gsweep bomb")
    check(said("end a game first"), "...and an end panel")
    wipe()
    WoW.advance(2)
    local actor = ui.slot._test.actor()
    eq(actor._anim, 6, "(lying there)")
    WoW.slash("/gsweep bomb")
    eq(actor._anim, 1, "it goes off again")
    check(said("display 6977: 1 (1.50 s), 6 (held, lift 24); drawn " .. Gnomesweeper.Models.HEIGHT .. " units tall"), "the chat says what it plays")
    Gnomesweeper.Options.Set("models", false)
    WoW.slash("/gsweep bomb")
    check(said("3D models are off"), "with the setting off, it says so")
    local found
    for _, line in ipairs(Gnomesweeper.HELP) do if line:find("/gsweep bomb", 1, true) then found = line end end
    check(found and found:find("(for measuring)", 1, true), "in the help, as a measuring command")
end

done("test_models")
