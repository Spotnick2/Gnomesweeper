-- Sounds.lua: the effects (#9) and Gnomeregan's music (#22), through the stub
-- (PlaySound / PlayMusic / StopMusic recorded, C_Timer run by WoW.advance).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local L, R = "LeftButton", "RightButton"
local WALL = { "..*..", "..*..", "..*..", "..*.." }       -- column 3 is mines
local function at(x, y) return (y - 1) * 5 + x end

local function fresh(db)
    loadAddon({ db = db })
    math.randomseed(7)
    WoW.slash("/gsweep")
    WoW.sounds = {}
    return Gnomesweeper.Window, Gnomesweeper.Sounds
end
local function tile(i) return Gnomesweeper.Grid._test.tiles[i] end
local function click(i, b)
    local t = tile(i)
    t._scripts.OnMouseDown(t, b or L)
    t._scripts.OnMouseUp(t, b or L, true)
end
local function kits()
    local out = {}
    for _, s in ipairs(WoW.sounds) do out[#out + 1] = s.kit end
    return table.concat(out, ",")
end
local function chatHas(text)
    for _, line in ipairs(WoW.chat) do if line:find(text, 1, true) then return true end end
    return false
end
local function onWall(W)
    W._test.SetGame(Gnomesweeper.Board._test.FromLayout(WALL, { now = WoW.now }))
    WoW.sounds = {}
end

----------------------------------------------------------------------------
-- Effects
----------------------------------------------------------------------------
do
    local W, S = fresh()
    local K = S.KITS
    eq(GnomesweeperDB.sounds, true, "sounds are on by default")
    eq(GnomesweeperDB.music, false, "music is off by default")

    click(41)
    eq(kits(), tostring(K.reveal), "a reveal clicks")
    eq(WoW.sounds[1].channel, "SFX", "...on the sound effects channel (the game's toggle and volume apply)")

    WoW.sounds = {}
    local covered
    for i = 1, 81 do if W.game:Cell(i).state == "covered" then covered = i; break end end
    click(covered, R)
    eq(kits(), tostring(K.flag), "a flag plants with its own click")
    WoW.sounds = {}
    click(covered, R)
    eq(kits(), tostring(K.unflag), "...and comes off with another")

    WoW.sounds = {}
    click(covered, R)                                     -- flag it again
    WoW.sounds = {}
    click(covered)                                         -- a reveal on a flag does nothing
    eq(kits(), "", "an action that changes nothing makes no sound")

    -- The wipe: the bomb, then the gnome, WIPE_DELAY later.
    onWall(W)
    click(at(3, 1))
    eq(W.game:State(), "lost", "(boom)")
    eq(kits(), tostring(K.boom), "a wipe: the bomb at once")
    WoW.advance(S.WIPE_DELAY - 0.05)
    eq(kits(), tostring(K.boom), "...the gnome not yet")
    WoW.advance(0.1)
    eq(kits(), K.boom .. "," .. K.wipe, "...then the gnome's last words")

    -- A new game before the gnome speaks: silence.
    onWall(W)
    click(at(3, 1))
    W.NewGame()
    WoW.advance(2)
    eq(kits(), tostring(K.boom), "a new game cancels the gnome still waiting")
    -- So does closing the window.
    onWall(W)
    click(at(3, 1))
    W.win:Hide()
    WoW.advance(2)
    eq(kits(), tostring(K.boom), "...and so does closing the window")
    W.win:Show()

    -- The win.
    onWall(W)
    click(at(1, 1))
    WoW.sounds = {}
    click(at(5, 1))
    eq(W.game:State(), "won", "(cleared)")
    eq(kits(), tostring(K.win), "a win: the congratulations, and no click on top")

    -- The player's new game: the big red button.
    WoW.sounds = {}
    local ui = W._test.ui
    ui.face._scripts.OnClick(ui.face)
    eq(kits(), tostring(K.newGame), "the face starts a new game with the big red button")
    WoW.sounds = {}
    onWall(W); click(at(3, 1)); WoW.sounds = {}
    ui.overlay.button._scripts.OnClick(ui.overlay.button)
    eq(kits(), tostring(K.newGame), "...so does Try again")
    WoW.sounds = {}
    W.NewGame("expert")
    eq(kits(), "", "a new game the player didn't click for (a difficulty change) is silent")

    -- Off.
    Gnomesweeper.Options.Set("sounds", false)
    WoW.sounds = {}
    click(41); ui.face._scripts.OnClick(ui.face)
    eq(kits(), "", "sounds off: silence")
    Gnomesweeper.Options.Set("sounds", true)
end

----------------------------------------------------------------------------
-- Music
----------------------------------------------------------------------------
do
    local W, S = fresh()
    eq(WoW.music, nil, "music off by default: nothing plays on opening")
    W.win:Hide()
    eq(WoW.musicStops, 0, "...and closing never stops music it didn't start")
    W.win:Show()

    Gnomesweeper.Options.Set("music", true)
    eq(WoW.music, S.MUSIC, "music on: Gnomeregan's music plays")
    W.win:Hide()
    eq(WoW.music, nil, "closing the window stops it")
    W.win:Show()
    eq(WoW.music, S.MUSIC, "...opening it starts it again")

    WoW.fire("PLAYER_REGEN_DISABLED")
    eq(WoW.music, nil, "combat stops it")
    W.win:Hide(); W.win:Show()
    eq(WoW.music, nil, "...opening the window in combat doesn't start it")
    Gnomesweeper.Options.Set("music", false); Gnomesweeper.Options.Set("music", true)
    eq(WoW.music, nil, "...nor does turning it on in combat")
    WoW.fire("PLAYER_REGEN_ENABLED")
    eq(WoW.music, S.MUSIC, "leaving combat brings it back (the window is open)")
    W.win:Hide()
    WoW.fire("PLAYER_REGEN_DISABLED"); WoW.fire("PLAYER_REGEN_ENABLED")
    eq(WoW.music, nil, "...but not with the window closed")
    W.win:Show()

    -- The music button.
    local ui = W._test.ui
    check(not ui.music.slash:IsShown(), "on: the note has no slash")
    ui.music._scripts.OnClick(ui.music)
    eq(GnomesweeperDB.music, false, "the note turns it off")
    eq(WoW.music, nil, "...and it stops")
    check(ui.music.slash:IsShown(), "...the red slash shows")
    eq(ui.music.icon._vertex[1], Gnomesweeper.Skin.COLORS.musicOff[1], "...over a greyed note")
    ui.music._scripts.OnEnter(ui.music)
    check(GameTooltip._lines[1]:find("^Off") ~= nil, "its tooltip says off")
    ui.music._scripts.OnClick(ui.music)
    eq(WoW.music, S.MUSIC, "...and on again")
    eq(ui.music._points[1][2], ui.trophy, "the note sits left of the trophy")

    -- /gsweep music
    WoW.chat = {}
    WoW.slash("/gsweep music")
    eq(WoW.music, nil, "/gsweep music turns it off")
    check(chatHas("music off."), "...and says so")
    WoW.slash("/gsweep music")
    eq(WoW.music, S.MUSIC, "...and on")
end

do  -- a zone event while ours plays: play it again (the owner heard both at once)
    local W, S = fresh({ music = true })
    eq(WoW.music, S.MUSIC, "(playing)")
    WoW.music = 99999                                     -- the zone started its own music
    WoW.fire("ZONE_CHANGED")
    eq(WoW.music, S.MUSIC, "a sub-zone change: ours again")
    WoW.music = 99999
    WoW.fire("ZONE_CHANGED_INDOORS")
    eq(WoW.music, S.MUSIC, "...going indoors too")
    WoW.music = 99999
    WoW.fire("ZONE_CHANGED_NEW_AREA")
    eq(WoW.music, S.MUSIC, "...a new area too")
    WoW.music = 99999
    WoW.fire("PLAYER_ENTERING_WORLD")
    eq(WoW.music, S.MUSIC, "...and entering the world")
    W.win:Hide()
    WoW.music = 99999
    WoW.fire("ZONE_CHANGED")
    eq(WoW.music, 99999, "not ours to play while the board is closed: the zone's stays")
    local log = table.concat(GnomesweeperDB.musicLog, "\n")
    check(log:find("ZONE_CHANGED: PlayMusic(53189) again", 1, true) ~= nil, "the log records each replay")
    check(log:find("StopMusic (music true, window false, combat false)", 1, true) ~= nil, "...and why it stopped")
    check(log:find("ZONE_CHANGED (not playing)", 1, true) ~= nil, "...and a zone event while it wasn't playing")
    for _ = 1, 100 do WoW.fire("ZONE_CHANGED") end
    eq(#GnomesweeperDB.musicLog, 60, "the log keeps the last 60 lines")
end

do  -- a /reload in the middle of a fight: no music until it ends
    WoW.inCombat = true
    loadAddon({ db = { music = true } })
    WoW.inCombat = true
    WoW.fire("PLAYER_LOGIN")
    WoW.slash("/gsweep")
    eq(WoW.music, nil, "logging in during combat: no music")
    WoW.inCombat = false
    WoW.fire("PLAYER_REGEN_ENABLED")
    eq(WoW.music, Gnomesweeper.Sounds.MUSIC, "...it starts when the fight ends")
end

----------------------------------------------------------------------------
-- /gsweep sounds (the probe)
----------------------------------------------------------------------------
do
    local W, S = fresh()
    WoW.willPlay[18871] = false
    WoW.chat = {}
    WoW.slash("/gsweep sounds")
    local n = #S.CANDIDATES
    WoW.advance(n * S.PROBE_GAP - 1)
    eq(#WoW.sounds, n, "every candidate plays, one by one")
    for i, c in ipairs(S.CANDIDATES) do eq(WoW.sounds[i].kit, c[1], "...in order: " .. c[1]) end
    local probe = GnomesweeperDB.soundProbe
    eq(probe.build, "1.60.1.70205", "the results are saved with the build")
    eq(probe.kits[7517].willPlay, true, "...each kit's willPlay")
    eq(probe.kits[18871].willPlay, false, "...including a kit the client refuses")
    check(chatHas("18871") and chatHas("won't play"), "chat says which one won't play")
    WoW.advance(1)
    eq(WoW.music, S.MUSIC, "then the music plays")
    WoW.advance(S.MUSIC_PROBE)
    eq(WoW.music, nil, "...and stops")
    check(chatHas("tell me what you heard"), "it says it is done")

    -- Stopping it halfway.
    WoW.sounds = {}
    WoW.slash("/gsweep sounds")
    WoW.advance(S.PROBE_GAP * 2 - 1)
    WoW.slash("/gsweep sounds")
    WoW.advance(200)
    eq(#WoW.sounds, 2, "a second /gsweep sounds stops it")
    eq(WoW.music, nil, "...with no music left playing")
end

done("test_sounds")
