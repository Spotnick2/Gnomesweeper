-- Effects.lua and its hooks (#10): the burst on a win, the smoke on a wipe, the
-- surprised face while a tile is held, and a new personal best's
-- beat, fanfare and fireworks.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local L, R = "LeftButton", "RightButton"
local WALL = { "..*..", "..*..", "..*..", "..*.." }       -- column 3 is mines
local function at(x, y) return (y - 1) * 5 + x end

local function fresh(db)
    loadAddon({ db = db })
    math.randomseed(7)
    WoW.slash("/gsweep")
    return Gnomesweeper.Window
end
local function tile(i) return Gnomesweeper.Grid._test.tiles[i] end
local function down(i, b) local t = tile(i); t._scripts.OnMouseDown(t, b or L) end
local function up(i, b) local t = tile(i); t._scripts.OnMouseUp(t, b or L, true) end
local function click(i, b) down(i, b); up(i, b) end
local function onWall(W, cat)
    WoW.now = 1000
    W._test.SetGame(Gnomesweeper.Board._test.FromLayout(WALL, { now = 1000 }), cat)
    WoW.sounds = {}
end
local function kits()
    local out = {}
    for _, s in ipairs(WoW.sounds) do out[#out + 1] = s.kit end
    return table.concat(out, ",")
end

----------------------------------------------------------------------------
-- The burst and the smoke follow the game
----------------------------------------------------------------------------
do
    local W = fresh()
    local ui = W._test.ui
    check(not ui.burst.isPlaying() and not ui.smoke.isPlaying(), "a new game: no burst, no smoke")

    onWall(W)
    click(at(1, 1)); click(at(5, 1))
    eq(W.game:State(), "won", "(cleared)")
    check(ui.burst.isPlaying(), "a win: a gold glow behind the face")
    check(ui.burst.ripple._playing, "...a ring ripples out first")
    eq(ui.burst.ripple._looping, nil, "...once")
    check(ui.burst.pop._playing, "...the glow swells in")
    check(ui.burst.breathe._playing, "...then breathes")
    eq(ui.burst.breathe._looping, "REPEAT", "...for as long as the win shows")
    eq(ui.burst.tex._texture, Gnomesweeper.Skin.TEXTURES.glow, "...a soft glow, not the spiky starburst")
    eq(ui.burst.tex._blend, "ADD", "...glowing (ADD)")
    eq(ui.burst.tex._points[1][2], ui.face, "...centred on the face")
    check(ui.burst.tex._width <= 72, "...small enough to stay off the difficulty button")
    check(not ui.smoke.isPlaying(), "...and no smoke")

    onWall(W)
    check(not ui.burst.isPlaying(), "a new board: the burst goes")
    click(at(3, 2))
    eq(W.game:State(), "lost", "(boom)")
    check(ui.smoke.isPlaying(), "a wipe: smoke")
    eq(ui.smoke.holder._points[#ui.smoke.holder._points][2], tile(at(3, 2)), "...rising from the tile that went off")
    check(ui.smoke.holder:GetFrameLevel() > tile(at(3, 2)):GetFrameLevel(), "...above the tiles")
    check(ui.fx:GetFrameLevel() < W.win:GetFrameLevel() + 15, "...under the end overlay")
    for i, p in ipairs(ui.smoke.puffs) do
        check(p.ag._playing, "puff " .. i .. " rises")
        eq(p.ag._looping, "REPEAT", "...and keeps rising while the wipe shows")
    end
    check(ui.smoke.puffs[2].ag._anims[1]._delay > ui.smoke.puffs[1].ag._anims[1]._delay, "...one after another, not all at once")
    check(not ui.burst.isPlaying(), "...and no burst")

    W.NewGame()
    check(not ui.smoke.isPlaying(), "a new game clears the smoke")
end

----------------------------------------------------------------------------
-- The face while a tile is held
----------------------------------------------------------------------------
do
    local W = fresh()
    local face = W._test.ui.face
    local T = Gnomesweeper.Skin.TEXTURES
    down(41)
    check(face.pressed, "a tile held down: the gnome reacts")
    eq(face.face._texture, T.facePressed, "...surprised (the art, #12)")
    up(41)
    check(not face.pressed, "let go: she's back")
    eq(face.face._texture, T.facePlaying, "...with the face of the game in progress")

    -- Two buttons: she reacts until the last one is up.
    down(41, L); down(41, R)
    up(41, L)
    check(face.pressed, "left+right: still held while one button is down")
    up(41, R)
    check(not face.pressed, "...back once both are up")

    -- A held button when the window closes: she isn't left surprised.
    down(41)
    W.win:Hide(); W.win:Show()
    check(not face.pressed, "the window closing mid-press resets her")

    -- After the end: no reaction (the board takes no clicks).
    onWall(W)
    click(at(3, 1))
    down(at(1, 1))
    check(not face.pressed, "a finished game: no reaction")
    up(at(1, 1))
end


----------------------------------------------------------------------------
-- A new personal best: a beat, a fanfare, fireworks
----------------------------------------------------------------------------
do
    local W = fresh()
    local S = Gnomesweeper.Sounds
    local ui = W._test.ui
    onWall(W, "beginner:area")
    click(at(1, 1)); WoW.sounds = {}
    WoW.now = 1030
    click(at(5, 1))
    eq(W.game:State(), "won", "(a first win: a new best)")
    eq(kits(), S.KITS.best .. "," .. S.KITS.fireworks, "a new best: the fanfare and the fireworks")
    WoW.advance(S.BEST_DELAY + 0.1)
    eq(kits(), S.KITS.best .. "," .. S.KITS.fireworks .. "," .. S.KITS.win, "...then the gnome cheers")
    check(ui.fireworks.isPlaying(), "fireworks over the board")
    local n, inside = 0, 0
    for _, q in ipairs(ui.fireworks.rockets) do
        if q.ag._playing then n = n + 1 end
        local p = q.tex._points[#q.tex._points]
        local w, h = ui.grid:GetWidth(), ui.grid:GetHeight()
        if math.abs(p[4]) <= w * 0.4 + 1e-9 and math.abs(p[5]) <= h * 0.4 + 1e-9 then inside = inside + 1 end
    end
    eq(n, Gnomesweeper.Effects.ROCKETS, "...every rocket goes off")
    eq(inside, Gnomesweeper.Effects.ROCKETS, "...all over the board")
    local spread = 0
    for _, q in ipairs(ui.fireworks.rockets) do local p = q.tex._points[#q.tex._points]; spread = math.max(spread, math.abs(p[4])) end
    check(spread > 10, "...spread out, not stacked in the middle (" .. spread .. ")")
    check(ui.fireworks.rockets[3].anims[1]._delay > ui.fireworks.rockets[1].anims[1]._delay, "...one after another")

    -- A win that isn't a best: just the cheer.
    onWall(W, "beginner:area")
    click(at(1, 1)); WoW.sounds = {}
    WoW.now = 1100
    click(at(5, 1))
    eq(kits(), tostring(S.KITS.win), "a slower win: only the gnome's cheer")

    -- A new game stops the fireworks.
    onWall(W, "beginner:area")
    click(at(1, 1))
    WoW.now = 1001
    click(at(5, 1))
    check(ui.fireworks.isPlaying(), "(another new best)")
    W.NewGame()
    check(not ui.fireworks.isPlaying(), "a new game puts the fireworks away")
end

do  -- the setting
    local W = fresh({ fireworks = false })
    local S = Gnomesweeper.Sounds
    onWall(W, "beginner:area")
    click(at(1, 1)); WoW.sounds = {}
    click(at(5, 1))
    check(not W._test.ui.fireworks.isPlaying(), "fireworks off: none")
    eq(kits(), tostring(S.KITS.best), "...and no fireworks sound (the fanfare stays)")
    check(W._test.ui.overlay.newBest:IsShown(), "...the new best still shows")

    WoW.fire("PLAYER_LOGIN")
    local page = Gnomesweeper.Options._test.page
    page:Show()
    eq(page.controls.fireworks.check:GetChecked(), false, "the settings page has the switch")
    Gnomesweeper.Options.Set("fireworks", true)
    eq(GnomesweeperDB.fireworks, true, "...and turns them back on")
end

do  -- a game ended by a left+right chord: her ending face, not the surprised one (Codex, #49)
    for _, case in ipairs({ { flag = 1, state = "won", face = "faceWon" }, { flag = 3, state = "lost", face = "faceLost" } }) do
        local W = fresh()
        W._test.SetGame(Gnomesweeper.Board._test.FromLayout({ "*..", "...", "..." }))
        click(2)                                         -- reveal the 1 next to the mine
        click(case.flag, R)                              -- the right flag (a win) or a wrong one (a loss)
        down(2, L); down(2, R)
        up(2, L)                                         -- the chord fires on the first release
        eq(W.game:State(), case.state, "(the chord ends the game: " .. case.state .. ")")
        eq(W._test.ui.face.face._texture, Gnomesweeper.Skin.TEXTURES[case.face],
            "a chord that ends the game (" .. case.state .. "): her ending face at once, with the right button still down")
        up(2, R)
        eq(W._test.ui.face.face._texture, Gnomesweeper.Skin.TEXTURES[case.face], "...and still after it's up")
    end
end

done("test_effects")
