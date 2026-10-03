-- The Liquid Glass polish (issue #30, from the UI review): the glass controls, the
-- rarity-coloured difficulty list with its board details, the flag, the detonated
-- tile, the footer and its help, looking at a finished board, the scale setting.
-- Driven through the stub client, on hand-built boards where a shape is asserted.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local L, R, M = "LeftButton", "RightButton", "MiddleButton"
local MULT, DOT = "\195\151", "\194\183"

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

local WALL = { "..*..", "..*..", "..*..", "..*.." }
local function at(x, y) return (y - 1) * 5 + x end
local function onWall()
    local W = fresh()
    WoW.slash("/gsweep")
    W._test.SetGame(Gnomesweeper.Board._test.FromLayout(WALL))
    return W
end

local function chatHas(text)
    for _, line in ipairs(WoW.chat) do
        if line:find(text, 1, true) then return true end
    end
    return false
end

local function pickRow(W, key)
    local ui = W._test.ui
    ui.diff._scripts.OnClick(ui.diff)
    ui.rows[key]._scripts.OnClick(ui.rows[key])
end

local function same(a, b, msg)
    check(a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3], msg)
end

----------------------------------------------------------------------------
-- Rarity: the difficulties wear WoW's item-quality colours
----------------------------------------------------------------------------
do
    local W = fresh()
    WoW.slash("/gsweep")
    local ui, Skin = W._test.ui, Gnomesweeper.Skin

    eq(Skin.RARITY.uncommon[1], 0.12, "uncommon is WoW's green (#1eff00)")
    eq(Skin.RARITY.rare[3], 0.87, "rare is WoW's blue (#0070dd)")
    eq(Skin.RARITY.epic[1], 0.64, "epic is WoW's purple (#a335ee)")
    eq(Skin.RARITY.legendary[1], 1, "legendary is WoW's orange (#ff8000)")
    same(Skin.DifficultyColor("beginner"), Skin.RARITY.uncommon, "Beginner is uncommon")
    same(Skin.DifficultyColor("intermediate"), Skin.RARITY.rare, "Intermediate is rare")
    same(Skin.DifficultyColor("expert"), Skin.RARITY.epic, "Expert is epic")
    for _, key in ipairs(Gnomesweeper.Board.PRESET_ORDER) do
        check(Skin.DifficultyColor(key) ~= Skin.RARITY.legendary, key .. " is not legendary: that is held back for a harder level")
    end

    same(ui.diff.accent, Skin.RARITY.uncommon, "the button's rim is the difficulty's colour")
    same(ui.diff.border._vertex, Skin.RARITY.uncommon, "...actually painted on its rim texture, not only remembered")
    same(ui.diff.label._textColor, Skin.RARITY.uncommon, "...and so is its text")
    same(ui.diffArrow._vertex, Skin.RARITY.uncommon, "...and its arrow")
    eq(ui.diff.label:GetText(), "Beginner", "...which names the difficulty")

    pickRow(W, "intermediate")
    same(ui.diff.accent, Skin.RARITY.rare, "picking Intermediate turns it rare blue")
    same(ui.diff.border._vertex, Skin.RARITY.rare, "...on the rim texture")
    same(ui.diff.label._textColor, Skin.RARITY.rare, "...text too")
    pickRow(W, "expert")
    same(ui.diff.accent, Skin.RARITY.epic, "Expert is epic purple")
    same(ui.diffArrow._vertex, Skin.RARITY.epic, "...arrow too")
    same(ui.rows.expert.label._textColor, Skin.RARITY.epic, "the list's Expert row is purple as well")
    same(ui.rows.beginner.label._textColor, Skin.RARITY.uncommon, "...and its Beginner row green")
end

----------------------------------------------------------------------------
-- The list says what each difficulty is, from the board's own presets
----------------------------------------------------------------------------
do
    local W = fresh()
    WoW.slash("/gsweep")
    local ui, Board = W._test.ui, Gnomesweeper.Board
    eq(ui.rows.beginner.details:GetText(), "9" .. MULT .. "9 " .. DOT .. " 10 mines", "Beginner: 9x9, 10 mines")
    eq(ui.rows.intermediate.details:GetText(), "16" .. MULT .. "16 " .. DOT .. " 40 mines", "Intermediate: 16x16, 40 mines")
    eq(ui.rows.expert.details:GetText(), "30" .. MULT .. "16 " .. DOT .. " 99 mines", "Expert: 30x16, 99 mines")
    for key, p in pairs(Board.PRESETS) do
        local expected = string.format("%d%s%d %s %d mines", p.w, MULT, p.h, DOT, p.mines)
        eq(W._test.details(key), expected, key .. ": the text is built from the preset, not typed")
    end
    eq(ui.rows.beginner.label:GetText(), "Beginner", "the row's name is separate from its details")

    -- The row you're on is marked by a shape (a bar and a tinted body), not only by colour.
    check(ui.rows.beginner.bar:IsShown() and ui.rows.beginner.selected:IsShown(), "the current difficulty's row is marked")
    check(not ui.rows.expert.bar:IsShown() and not ui.rows.intermediate.selected:IsShown(), "...and no other")
    pickRow(W, "expert")
    check(ui.rows.expert.bar:IsShown() and not ui.rows.beginner.bar:IsShown(), "the mark follows the pick")
    eq(W.game.w, 30, "(and the game changed)")
end

----------------------------------------------------------------------------
-- One glass look: the controls
----------------------------------------------------------------------------
do
    local W = fresh()
    WoW.slash("/gsweep")
    local ui, Skin = W._test.ui, Gnomesweeper.Skin
    local T = Skin.TEXTURES

    -- Wide buttons are 9-sliced; a 22-unit square would fold its corners, so it is drawn whole.
    eq(ui.diff.fill._slice[1], 8, "the difficulty button's body is 9-sliced")
    eq(ui.diff.border._slice[1], 8, "...and its rim")
    eq(ui.close.fill._slice, nil, "the 22-unit close button is not sliced")
    eq(ui.gear.border._slice, nil, "...nor the gear")
    eq(ui.diff.fill._texture, T.uiFill, "all of them use the same glass body")
    eq(ui.close.fill._texture, T.uiFill, "(the close button too)")
    eq(ui.gear.border._texture, T.uiBorder, "...and the same rim")
    eq(ui.diff.hover._blend, "ADD", "hover is a glow")
    check(ui.diff.hover._vertex[4] > 0 and ui.diff.hover._vertex[4] < 1, "...a translucent one")

    eq(ui.close.icon._texture, T.close, "the close button wears the X")
    same(ui.close.accent, Skin.COLORS.closeAccent, "...with a soft red rim, so it reads as close")
    eq(ui.gear.icon._texture, T.gear, "the gear is still the gear")
    same(ui.gear.accent, Skin.COLORS.accent, "...with the standard rim")
    check(ui.close._width == 22 and ui.gear._height == 22, "both are comfortable 22-unit targets")

    -- Pressed.
    check(not ui.diff.press:IsShown(), "a button isn't pressed at rest")
    ui.diff._scripts.OnMouseDown(ui.diff, L)
    check(ui.diff.press:IsShown(), "pressing darkens it")
    ui.diff._scripts.OnMouseUp(ui.diff, L, true)
    check(not ui.diff.press:IsShown(), "releasing lets go")

    -- Close and the gear's tooltip.
    ui.close._scripts.OnClick(ui.close)
    check(not W.win:IsShown(), "the close button closes the window")
    W.win:Show()
    GameTooltip._text = nil
    ui.gear._scripts.OnEnter(ui.gear)
    eq(GameTooltip._text, "Settings", "the gear has a tooltip")
    check(GameTooltip._lines[1] and GameTooltip._lines[1]:find("window size", 1, true), "...that says what the settings hold")

    -- The window is darker than bare glass, and the scenery stays behind it.
    check(W.win.backing ~= nil and W.win.backing._color[4] > 0.3 and W.win.backing._color[4] < 0.6, "the window has a translucent dark backing")
    check(W.win.backing._color[1] < 0.1 and W.win.backing._color[3] < 0.2, "...dark navy")
end

----------------------------------------------------------------------------
-- The flag, the bomb, the detonated tile
----------------------------------------------------------------------------
do
    local W = onWall()
    local ui, Skin = W._test.ui, Gnomesweeper.Skin
    local T = Skin.TEXTURES
    check(T.flag:find("icon_flag", 1, true), "the flag is our own red pennant, not a faction crest")
    click(at(4, 4), R)
    eq(tile(at(4, 4)).icon._texture, T.flag, "a flagged tile shows it")
    eq(tile(at(4, 4)).icon._texCoord[1], 0, "...whole (our texture has no border to cut off)")
    eq(tile(at(4, 4)).icon._width, Skin.FLAG_ICON, "...at the flag size")
    eq(ui.counter:GetText(), "3", "(the counter follows)")

    -- Lose on a mine with a wrong flag out.
    click(at(3, 1), L)
    eq(W.game:State(), "lost", "(a mine was revealed)")
    local boom, other = tile(at(3, 1)), tile(at(3, 3))
    eq(boom.bg._texture, T.tileExploded, "the detonated tile is on the red tile")
    check(boom.burst ~= nil and boom.burst:IsShown(), "...with a starburst behind it, so it isn't told apart by colour alone")
    eq(boom.burst._blend, "ADD", "(the burst is additive light)")
    eq(boom.icon._width, 14, "...and the bomb on it is smaller, so the red and the burst show round it")
    eq(other.icon._width, Skin.TILE_ICON, "the other mines are the normal size")
    check(other.burst == nil or not other.burst:IsShown(), "...with no burst")
    eq(other.icon._texCoord[1], Skin.ICON_CROP[1], "(WoW's own bomb icon has its border cropped off)")
    eq(tile(at(4, 4)).text:GetText(), "X", "the wrong flag has an X, a shape")
    eq(tile(at(4, 4)).icon._desaturated, true, "...on a greyed flag")

    -- A new game takes the burst off.
    ui.face._scripts.OnClick(ui.face)
    check(boom.burst == nil or not boom.burst:IsShown(), "a new game clears the burst")
    eq(boom.icon == nil or not boom.icon:IsShown(), true, "...and the bomb")
end

----------------------------------------------------------------------------
-- The footer, and the help for middle-click
----------------------------------------------------------------------------
do
    local W = fresh()
    WoW.slash("/gsweep")
    local ui = W._test.ui
    eq(ui.hintStart:GetText(), "Choose a tile to begin.", "the start hint is kept")
    eq(ui.hintKeys:GetText(), "Left-click: Reveal     Right-click: Flag", "the first controls line")
    eq(ui.hintMid:GetText(), "Middle-click: Clear around number", "the middle-click line has its own row (the footer is not crammed into one line)")
    check(ui.hintKeys ~= ui.hintMid, "(two lines)")
    local a, b = ui.hintKeys._points[#ui.hintKeys._points], ui.hintMid._points[#ui.hintMid._points]
    check(b[5] < a[5], "...the second below the first")

    GameTooltip._text = nil
    ui.help._scripts.OnEnter(ui.help)
    eq(GameTooltip._text, "Clearing around a number", "the ? explains it")
    local body = table.concat(GameTooltip._lines, " ")
    check(body:find("revealed number", 1, true), "...naming a revealed number")
    check(body:find("aren't flagged", 1, true), "...that it reveals the tiles around it that aren't flagged")
    check(body:find("number of flags", 1, true) and body:find("equals the number", 1, true), "...only when the flags match the number")
    check(body:find("wrong flag", 1, true) and body:find("reveal a mine", 1, true), "...and that a wrong flag can reveal a mine")
    check(body:find("left and right", 1, true), "...and the left+right way")
    ui.help._scripts.OnLeave(ui.help)

    -- The footer fits under the board at every difficulty (the window height includes it).
    local Layout = Gnomesweeper.Layout
    check(Layout.CHROME_BOTTOM >= 66, "there is room for three lines under the board (" .. Layout.CHROME_BOTTOM .. ")")
end

----------------------------------------------------------------------------
-- A finished board can be inspected, and Play again stays
----------------------------------------------------------------------------
do
    local W = onWall()
    local ui, Skin = W._test.ui, Gnomesweeper.Skin
    click(at(4, 4), R)                     -- a wrong flag, to see it survive
    click(at(3, 1), L)
    local o = ui.overlay
    check(o:IsShown(), "(the wipe overlay is up)")
    eq(o.view.label:GetText(), "See the field", "it has a visible control to look at the board (not \"View board\": read as the scores)")
    check(o.view:IsShown(), "...which is shown")
    check(not ui.result:IsShown(), "the result bar waits until the overlay is put away")

    local before = {}
    for i = 1, 20 do
        local t = tile(i)
        before[i] = (t.bg._texture or "") .. "|" .. (t.icon and t.icon._texture or "") .. "|" .. (t.text and t.text:GetText() or "")
    end
    o.view._scripts.OnClick(o.view)
    check(not o:IsShown(), "See the field puts the overlay away")
    check(ui.result:IsShown(), "...and the result moves to the footer")
    eq(ui.result.title:GetText(), "Boom. Full wipe.", "...still saying what happened")
    eq(ui.result.button.label:GetText(), "Try again", "...with the button to try again")
    check(not ui.hintKeys:IsShown() and not ui.hintMid:IsShown() and not ui.help:IsShown(), "(in place of the controls)")
    for i = 1, 20 do
        local t = tile(i)
        eq((t.bg._texture or "") .. "|" .. (t.icon and t.icon._texture or "") .. "|" .. (t.text and t.text:GetText() or ""),
            before[i], "the finished board is exactly as it was: tile " .. i)
    end
    eq(W.game:State(), "lost", "(and the game is still lost)")

    local frames = #WoW.frames
    ui.result.button._scripts.OnClick(ui.result.button)
    eq(W.game:State(), "ready", "the result bar's button starts a new game")
    check(not ui.result:IsShown(), "...the result bar goes")
    check(ui.hintKeys:IsShown() and ui.hintMid:IsShown() and ui.help:IsShown(), "...and the controls come back")
    eq(#WoW.frames, frames, "(no frames were created)")

    -- A win: the time stays in the footer.
    local W2 = onWall()
    local ui2 = W2._test.ui
    WoW.now = 84
    click(at(1, 1), L); click(at(5, 1), L)
    eq(W2.game:State(), "won", "(cleared)")
    ui2.overlay.view._scripts.OnClick(ui2.overlay.view)
    eq(ui2.result.title:GetText(), "Field cleared!", "a win's result bar says so")
    eq(ui2.result.sub:GetText(), "Time 01:24", "...with the time")
    eq(ui2.result.button.label:GetText(), "Play again", "...and Play again")
    -- Closing and reopening keeps it.
    W2.win:Hide(); W2.win:Show()
    check(ui2.result:IsShown() and not ui2.overlay:IsShown(), "closing and reopening keeps the result bar and not the overlay")
    -- Clicking the board does not bring the overlay back.
    click(at(1, 1), L)
    check(not ui2.overlay:IsShown(), "a click on the finished board leaves the overlay away")
end

----------------------------------------------------------------------------
-- The HUD stays balanced
----------------------------------------------------------------------------
do
    local W = fresh()
    WoW.slash("/gsweep")
    local ui = W._test.ui
    eq(ui.hud._width, 272, "Beginner: the strip fills the narrow window")
    local p = ui.hud._points[#ui.hud._points]
    check(p[1] == "TOP" and p[2] == W.win and p[4] == 0, "...centred under the title")
    pickRow(W, "intermediate")
    eq(ui.hud._width, 340, "Intermediate: capped at 340")
    pickRow(W, "expert")
    eq(ui.hud._width, 340, "Expert: capped, not stretched across 748")
    check(W.win._width > ui.hud._width + 100, "(the window really is much wider)")
    local f = ui.face._points[#ui.face._points]
    check(f[1] == "CENTER" and f[2] == ui.hud, "the mascot stays at the strip's centre")
end

----------------------------------------------------------------------------
-- The scale setting
----------------------------------------------------------------------------
do
    local W = fresh()
    WoW.slash("/gsweep")
    eq(W.win._scale, 1, "the default scale is 1")
    WoW.chat = {}
    WoW.slash("/gsweep scale 1.2")
    eq(GnomesweeperDB.scale, 1.2, "/gsweep scale 1.2 is remembered")
    eq(W.win._scale, 1.2, "...and the window takes it (Beginner fits)")
    check(chatHas("window scale 1.20"), "...and says so")

    WoW.chat = {}
    WoW.slash("/gsweep scale 3")
    eq(GnomesweeperDB.scale, 1.2, "a scale out of range changes nothing")
    check(chatHas("scale must be a number from 0.5 to 1.5"), "...and says what is allowed")
    WoW.slash("/gsweep scale banana")
    eq(GnomesweeperDB.scale, 1.2, "a word changes nothing")
    WoW.slash("/gsweep scale 0.4")
    eq(GnomesweeperDB.scale, 1.2, "too small changes nothing")

    WoW.chat = {}
    WoW.slash("/gsweep scale")
    check(chatHas("window scale 1.20"), "/gsweep scale alone says the current scale")

    WoW.slash("/gsweep scale reset")
    eq(GnomesweeperDB.scale, nil, "reset forgets it")
    eq(W.win._scale, 1, "...and the window goes back to 1")

    -- Wanted and shown can differ: Expert at 1.5 does not fit 1366x768.
    pickRow(W, "expert")
    WoW.chat = {}
    WoW.slash("/gsweep scale 1.5")
    check(W.win._scale < 1.5, "Expert at 1.5 is held to what fits the screen (" .. W.win._scale .. ")")
    check(chatHas("shown at"), "...and the message says so")
    eq(GnomesweeperDB.scale, 1.5, "(the wish is kept)")
    WoW.setScreen(1920, 1080)
    WoW.fire("DISPLAY_SIZE_CHANGED")
    check(W.win._scale > 1.2, "on a bigger screen the same wish is shown larger (" .. W.win._scale .. ")")
end

do   -- every difficulty at every scale, on a few screens: the window always fits
    local sizes = { { 1366, 768 }, { 1024, 600 }, { 1920, 1080 }, { 800, 600 } }
    local W = fresh()
    WoW.slash("/gsweep")
    for _, scr in ipairs(sizes) do
        WoW.setScreen(scr[1], scr[2])
        for _, key in ipairs(Gnomesweeper.Board.PRESET_ORDER) do
            for _, want in ipairs({ 0.5, 1, 1.5 }) do
                W.NewGame(key)
                W.SetScale(want)
                local s = W.win._scale
                local fits = W.win._width * s <= scr[1] * 0.95 + 1e-6 and W.win._height * s <= scr[2] * 0.95 + 1e-6
                check(fits or s == Gnomesweeper.Layout.MIN_SCALE,
                    string.format("%s at %.1f fits a %dx%d screen (shown at %.3f)", key, want, scr[1], scr[2], s))
                check(s <= want + 1e-9, "...and never above what was asked")
            end
        end
    end
end

----------------------------------------------------------------------------
-- Codex's review of PR #31: three bugs
----------------------------------------------------------------------------
do   -- a control that hides mid-press must not come back looking pressed
    local W = fresh()
    WoW.slash("/gsweep")
    local ui = W._test.ui
    ui.diff._scripts.OnMouseDown(ui.diff, L)
    check(ui.diff.press:IsShown(), "(pressed)")
    W.win:Hide()                                        -- the window closes before the release arrives
    W.win:Show()
    ui.diff:Hide(); ui.diff:Show()                      -- and the control itself hiding
    check(not ui.diff.press:IsShown(), "a control that hid while pressed comes back not pressed")
    ui.help._scripts.OnMouseDown(ui.help, L)
    ui.help:Hide(); ui.help:Show()
    check(not ui.help.press:IsShown(), "...the small help button too")
end

do   -- the difficulty list is opaque enough that the HUD can't show through it
    local W = fresh()
    WoW.slash("/gsweep")
    local menu = W._test.menu()
    check(menu.backing ~= nil and menu.backing._color[4] >= 0.95, "the list has a near-opaque backing (" .. tostring(menu.backing and menu.backing._color[4]) .. ")")
    check(menu.mask ~= nil, "...inside a rounded mask, so its corners match the rim")
    check(menu.backing._color[1] < 0.1 and menu.backing._color[3] < 0.2, "...dark navy")
    -- the stock glass body (0.90) is still there on top, with the rim
    eq(menu.fill._texture, Gnomesweeper.Skin.TEXTURES.uiFill, "(the glass body and its rim are kept)")
    eq(menu.border._texture, Gnomesweeper.Skin.TEXTURES.uiBorder, "(and the rim)")
end

do   -- the list opens ABOVE the result overlay, including the glass rim that overlay draws
    local W = onWall()
    local ui = W._test.ui
    click(at(3, 1), L)                                  -- a wipe: the overlay is up
    check(ui.overlay:IsShown(), "(the overlay is up)")
    local rimLevel = ui.overlay.glass.top._level        -- the frame the overlay's rim is drawn on
    check(rimLevel > ui.overlay._level, "(the overlay's rim sits above the overlay itself)")
    check(W._test.menu()._level > rimLevel, "the difficulty list is above the overlay's rim (" ..
        W._test.menu()._level .. " > " .. rimLevel .. ")")
end

done("test_polish")
