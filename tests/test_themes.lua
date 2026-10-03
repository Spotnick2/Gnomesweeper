-- #14: the board's themes. Classic (the default, our tiles) and Modern (the
-- generated ice-blue glass); only the tiles change, at once, never the game.
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
local function click(i, b)
    local t = tile(i)
    t._scripts.OnMouseDown(t, b or "LeftButton")
    t._scripts.OnMouseUp(t, b or "LeftButton", true)
end

loadAddon({ db = { seenFaceTip = true } })
local Skin = Gnomesweeper.Skin
local T = Skin.TEXTURES

do  -- the themes themselves
    eq(Skin.THEME_ORDER[1], "classic", "Classic first")
    eq(Skin.Theme("classic").covered, T.tileCovered, "Classic: our tiles")
    eq(Skin.Theme("modern").covered, T.tileModernCovered, "Modern: the generated ones")
    eq(Skin.Theme("nonsense"), Skin.THEMES.classic, "an unknown theme (damaged data): Classic")
    eq(Skin.Theme(nil), Skin.THEMES.classic, "...and none: Classic")
    for _, key in ipairs(Skin.THEME_ORDER) do
        for _, part in ipairs({ "covered", "revealed", "exploded" }) do
            check(type(Skin.THEMES[key][part]) == "string", key .. " has a " .. part .. " tile")
        end
    end
end

do  -- Classic by default; switching to Modern repaints the board in place
    local W = fresh()
    eq(GnomesweeperDB.theme, "classic", "Classic by default")
    -- A board in play: a revealed number, a flag, covered tiles.
    W._test.SetGame(Gnomesweeper.Board._test.FromLayout({ "*..", "...", "..*" }))
    click(2)                                             -- a number
    click(1, "RightButton")                              -- a flag
    eq(tile(2).bg._texture, T.tileRevealed, "(a revealed tile, Classic)")
    eq(tile(4).bg._texture, T.tileCovered, "(a covered tile, Classic)")
    local game, flagIcon = W.game, tile(1).icon and tile(1).icon._texture

    Gnomesweeper.Options.Set("theme", "modern")
    eq(GnomesweeperDB.theme, "modern", "the setting saved")
    eq(W.game, game, "only the look changes: the same game")
    eq(W.game:State(), "playing", "...still in play")
    eq(tile(2).bg._texture, T.tileModernRevealed, "the revealed tile repainted at once")
    eq(tile(4).bg._texture, T.tileModernCovered, "...and the covered ones")
    eq(tile(2).text:GetText(), "1", "...the number still there")
    eq(tile(1).icon._texture, flagIcon, "...the flag the same pennant (both themes keep it)")

    -- A wipe in Modern: the exploded tile is Modern's, the bomb is WoW's.
    click(9)
    eq(W.game:State(), "lost", "(a wipe)")
    eq(tile(9).bg._texture, T.tileModernExploded, "the exploded tile: Modern's")
    eq(tile(9).icon._texture, T.mine, "...with WoW's bomb, as in Classic")

    -- And back.
    Gnomesweeper.Options.Set("theme", "classic")
    eq(tile(9).bg._texture, T.tileExploded, "back to Classic: repainted again")
    eq(tile(4).bg._texture, T.tileCovered, "...every tile")
end

do  -- saved as Modern: the board is built in Modern; a new game keeps it
    local W = fresh({ theme = "modern" })
    eq(tile(1).bg._texture, T.tileModernCovered, "saved Modern: the board opens in Modern")
    W.NewGame("expert")
    eq(tile(480).bg._texture, T.tileModernCovered, "...an Expert board too, every tile")
end

do  -- the setting refuses a theme that doesn't exist; damaged data shows Classic
    local W = fresh({ theme = "neon" })
    eq(tile(1).bg._texture, T.tileCovered, "a damaged theme: Classic tiles")
    check(not Gnomesweeper.Options.Set("theme", "neon"), "Options.Set refuses an unknown theme")
end

do  -- set from the settings page before the window exists: used when it's built
    loadAddon({ db = { seenFaceTip = true } })
    Gnomesweeper.Options.Set("theme", "modern")
    check(Gnomesweeper.Window.win == nil, "(the window not built by the setting)")
    WoW.slash("/gsweep")
    eq(tile(1).bg._texture, T.tileModernCovered, "chosen before the first open: the board opens in Modern")
end

do  -- the settings page has the choice
    fresh()
    WoW.fire("PLAYER_LOGIN")
    local page = Gnomesweeper.Options._test.page
    page:Show()
    local c = page.controls.theme
    check(c and c.radios and #c.radios == 2, "the settings page offers the two themes")
    eq(c.radios[1].value, "classic", "...Classic first")
    c.radios[2]._scripts.OnClick(c.radios[2])
    eq(GnomesweeperDB.theme, "modern", "...picking Modern sets it")
end

done("test_themes")
