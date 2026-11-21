-- The probe's Core.lua (Tools/GnomesweeperProbe, #87): bomb, perf, input, sounds and
-- guild, moved out of the shipped addon, and what the move promises: no line in chat,
-- results in GnomesweeperProbeDB, nothing left in GnomesweeperDB. Loads ForeverProbe
-- from its checkout: local only (CI skips it).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local L, R, M = "LeftButton", "RightButton", "MiddleButton"
local said = probeSaid
local WALL = { "..*..", "..*..", "..*..", "..*.." }       -- a wall of mines down column 3
local function at(x, y) return (y - 1) * 5 + x end
local function tile(i) return Gnomesweeper.Grid._test.tiles[i] end
local function click(i, b)
    local t = tile(i)
    t._scripts.OnMouseDown(t, b or L)
    t._scripts.OnMouseUp(t, b or L, true)
end
local function clearLog(NS) NS.P:ClearLog() end

-- The probe on an open board, a hand-built one when given.
local function open(opts)
    opts = opts or {}
    local NS = loadProbe({ db = opts.db })
    math.randomseed(7)
    WoW.slash("/gsweep" .. (opts.preset and (" " .. opts.preset) or ""))
    local W = Gnomesweeper.Window
    if opts.wall then W._test.SetGame(Gnomesweeper.Board._test.FromLayout(WALL)) end
    WoW.chat = {}
    return NS, W
end

----------------------------------------------------------------------------
-- The module (what ships without it is test_shipped.lua, which CI runs)
----------------------------------------------------------------------------
do
    local NS = loadProbe()
    check(NS.P ~= nil and type(GnomesweeperProbeDB.log) == "table", "the module is loaded, its log bound")
    check(said("loaded (1 loads)"), "...and says so in its own log")
    eq(#WoW.chat, 0, "...not in chat")
    eq(ForeverProbe.byCmd.sweep ~= nil, true, "its command is /fp sweep (GuildSpyProbe has gs: Codex, #104)")
end

----------------------------------------------------------------------------
-- /fp sweep perf
----------------------------------------------------------------------------
do
    local NS, W = open()
    probeSlash("perf")
    check(said("open the board first") == false, "(the board is open)")
    local game = W.game
    check(said("build Expert"), "/fp sweep perf reports the Expert build")
    check(said("first reveal and repaint"), "...the first reveal")
    check(said("a loss, every mine shown"), "...a loss")
    check(said("10 difficulty switches"), "...and switching difficulty")
    eq(W.game, game, "the real game is untouched by the benchmark")
    eq(tile(1).bg._file, Gnomesweeper.Skin.TEXTURES.tileCovered, "...and the board is put back")
    check(tile(81):IsShown() and not tile(82):IsShown(), "...at the right size")
    eq(#WoW.chat, 0, "...all of it in the probe's log, none in chat")
    W.win:Hide()
    clearLog(NS)
    probeSlash("perf")
    check(said("open the board first"), "with the board closed, it says to open it")
end

----------------------------------------------------------------------------
-- /fp sweep input
----------------------------------------------------------------------------
do
    local NS, W = open()
    probeSlash("input")
    check(said("logging on"), "/fp sweep input turns the log on")
    click(5, L)
    check(said("tile 5  down  LeftButton"), "...and logs a press")
    check(said("upInside=true"), "...and a release with its arguments")
    probeSlash("input")
    check(said("logging off"), "...and again turns it off")
    local n = #GnomesweeperProbeDB.log
    click(6, L)
    eq(#GnomesweeperProbeDB.log, n, "with the log off, nothing more is said")

    -- With the log on, each action says what the cell was and what it did.
    local NS2, W2 = open({ wall = true })
    probeSlash("input")
    click(at(2, 2), L)
    check(said("reveal on (2,2) covered, 0 flags around -> 1 cells changed (playing)"), "a reveal is described")
    click(at(3, 1), R); click(at(3, 2), R)
    check(said("mark on (3,1) covered, 0 flags around -> 1 cells changed"), "a mark is described")
    click(at(2, 2), M)
    check(said("chord on (2,2) revealed 3, 2 flags around -> 0 cells changed"), "a chord that does nothing says why: 3, 2 flags")
    click(at(3, 3), R)
    click(at(2, 2), M)
    check(said("chord on (2,2) revealed 3, 3 flags around -> 7 cells changed"), "a chord that works says what it opened")
    GnomesweeperDB.chordOnLeft = true
    local ok = pcall(W2.Dispatch, "reveal", W2.game.total + 1)
    check(ok, "an index Dispatch ignores stays ignored with the log on and left-click clearing (Codex, #104)")
    GnomesweeperDB.chordOnLeft = false
    local dispatch = NS2._test.input.dispatch
    probeSlash("input")
    eq(W2.Dispatch, dispatch, "off: Window.Dispatch is the addon's own again")
    check(Gnomesweeper.Grid.Refresh ~= nil and Gnomesweeper.Grid.Refresh == NS2._test.input.refresh,
        "...and Grid.Refresh")
    eq(#WoW.chat, 0, "none of it in chat")

    -- A bigger board's new tiles are logged too.
    probeSlash("input")
    W2.NewGame("expert")
    clearLog(NS2)
    click(400, L)
    check(said("tile 400  down  LeftButton"), "a tile made for a bigger board is hooked as it's made")
    probeSlash("input")
end

----------------------------------------------------------------------------
-- /fp sweep bomb
----------------------------------------------------------------------------
do
    local BOMB = { -1.4, -1.2, -1.95, 1.4, 1.2, 1.95 }
    local NS, W = open({ wall = true })
    WoW.modelSetFails[6977], WoW.modelSetFails[3124] = nil, nil
    WoW.modelBoxes[6977] = BOMB
    local ui = W._test.ui
    W.win:Hide()
    probeSlash("bomb")
    check(said("open the board first"), "it needs the board open")
    W.win:Show()
    probeSlash("bomb")
    check(said("end a game first"), "...and an end panel")
    click(at(3, 2))                                          -- a wipe
    WoW.advance(2)
    local actor = ui.slot._test.actor()
    eq(actor._anim, 6, "(lying there)")
    probeSlash("bomb")
    eq(actor._anim, 1, "it goes off again")
    check(said("display 6977: 1 (1.50 s), 6 (held, lift 24); drawn " .. Gnomesweeper.Models.HEIGHT .. " units tall"),
        "the log says what it plays")
    Gnomesweeper.Options.Set("models", false)
    probeSlash("bomb")
    check(said("3D models are off"), "with the setting off, it says so")
    eq(#WoW.chat, 0, "none of it in chat")
end

----------------------------------------------------------------------------
-- /fp sweep sounds
----------------------------------------------------------------------------
do
    local NS, W = open()
    WoW.sounds = {}
    WoW.willPlay[18871] = false
    probeSlash("sounds")
    local n = #NS.SOUNDS
    WoW.advance(n * NS.SOUND_GAP - 1)
    eq(#WoW.sounds, n, "every candidate plays, one by one")
    for i, c in ipairs(NS.SOUNDS) do eq(WoW.sounds[i].kit, c[1], "...in order: " .. c[1]) end
    local probe = GnomesweeperProbeDB.sounds
    eq(probe.build, "1.60.1.71037", "the results are saved with the build, in the probe's table")
    eq(probe.kits[8959].willPlay, true, "...each kit's willPlay")
    eq(probe.kits[18871].willPlay, false, "...including a kit the client refuses")
    check(said("18871") and said("won't play"), "the log says which one won't play")
    WoW.advance(1)
    eq(WoW.music, Gnomesweeper.Sounds.MUSIC, "then the music plays")
    WoW.advance(NS.MUSIC_SECONDS)
    eq(WoW.music, nil, "...and stops")
    check(said("tell me what you heard"), "it says it is done")
    eq(#WoW.chat, 0, "none of it in chat")

    -- Stopping it halfway.
    WoW.sounds = {}
    probeSlash("sounds")
    WoW.advance(NS.SOUND_GAP * 2 - 1)
    probeSlash("sounds")
    WoW.advance(200)
    eq(#WoW.sounds, 2, "a second /fp sweep sounds stops it")
    eq(WoW.music, nil, "...with no music left playing")
end

do  -- the music's turn follows the addon's rule: the board shown, not in combat
    local NS, W = open()
    local n = #NS.SOUNDS
    probeSlash("sounds")
    W.win:Hide()
    WoW.advance(n * NS.SOUND_GAP + 1)
    eq(WoW.music, nil, "its music comes due with the board closed: not started")
    WoW.advance(NS.MUSIC_SECONDS)
    W.win:Show()
    probeSlash("sounds")
    WoW.inCombat = true
    WoW.advance(n * NS.SOUND_GAP + 1)
    eq(WoW.music, nil, "...nor in combat")
    WoW.inCombat = false
    WoW.advance(NS.MUSIC_SECONDS)
end

do  -- the sample stops with the board, or a fight (Codex, #104)
    local NS, W = open()
    local n = #NS.SOUNDS
    probeSlash("sounds")
    WoW.advance(n * NS.SOUND_GAP + 1)
    eq(WoW.music, Gnomesweeper.Sounds.MUSIC, "(the sample plays)")
    W.win:Hide()
    eq(WoW.music, nil, "closing the board stops it")
    W.win:Show()
    WoW.advance(NS.MUSIC_SECONDS)
    probeSlash("sounds")
    WoW.advance(n * NS.SOUND_GAP + 1)
    eq(WoW.music, Gnomesweeper.Sounds.MUSIC, "(again)")
    WoW.inCombat = true
    WoW.fire("PLAYER_REGEN_DISABLED")
    eq(WoW.music, nil, "a fight stops it")
    WoW.inCombat = false
    WoW.fire("PLAYER_REGEN_ENABLED")
    WoW.advance(NS.MUSIC_SECONDS)
end

do  -- the setting turned on during the sample: the addon's music plays on after it (Codex, #104)
    local NS, W = open()
    probeSlash("sounds")
    WoW.advance(#NS.SOUNDS * NS.SOUND_GAP + 1)
    Gnomesweeper.Options.Set("music", true)
    eq(WoW.music, Gnomesweeper.Sounds.MUSIC, "(the addon takes the music over)")
    WoW.advance(NS.MUSIC_SECONDS)
    eq(WoW.music, Gnomesweeper.Sounds.MUSIC, "the sample's end leaves the addon's music playing")
    probeSlash("sounds")
    WoW.advance(NS.SOUND_GAP)
    probeSlash("sounds")
    eq(WoW.music, Gnomesweeper.Sounds.MUSIC, "...and so does stopping the probe")
end

do  -- cancelling it never stops music someone else plays
    local NS = open()
    WoW.music = 777                                          -- another addon's music
    local stops = WoW.musicStops
    probeSlash("sounds")
    WoW.advance(NS.SOUND_GAP)
    probeSlash("sounds")
    eq(WoW.musicStops, stops, "no StopMusic: the probe started none")
    eq(WoW.music, 777, "...the other music plays on")
end

do  -- with the music setting on, the addon plays it and the probe leaves it be
    local NS, W = open({ db = { music = true } })
    probeSlash("sounds")
    WoW.advance(#NS.SOUNDS * NS.SOUND_GAP + NS.MUSIC_SECONDS + 1)
    eq(WoW.music, Gnomesweeper.Sounds.MUSIC, "the setting on: the music plays on after the probe")
end

----------------------------------------------------------------------------
-- /fp sweep guild (phase 0)
----------------------------------------------------------------------------
do  -- in a guild: the identity, the send, the echo, Ambiguate
    local NS = loadProbe()
    WoW.guild = "Gnomeregan Exiles"
    WoW.chat = {}
    probeSlash("guild")
    eq(WoW.prefixes.GSWEEP, true, "the prefix is registered")
    check(said('UnitName = "Fizzle", "Sprocketwhistle"'), "it reports UnitName's two answers")
    check(said("GetNormalizedRealmName"), "...the realm, both ways")
    check(said('API.PlayerFullName = "Fizzle Sprocketwhistle"'), "...the full name the scores use")
    check(said('GetGuildInfo = "Gnomeregan Exiles"'), "...the guild")
    local probes = {}
    for _, m in ipairs(WoW.addonSent) do if m.message:match("^1\tP\t%d+$") then probes[#probes + 1] = m end end
    eq(#probes, 1, "one 'P' message sent: a type no v1 client knows, so they ignore it")
    eq(probes[1].chatType, "GUILD", "...to the guild")
    check(said("SendAddonMessage(GUILD) = 0"), "...and the send's result code is reported")
    check(said('CHAT_MSG_ADDON channel="GUILD" sender="Fizzle Sprocketwhistle"'), "the echo is reported: the channel and the sender, exactly")
    check(said('text="1'), "...our own echo whole")
    check(said('Ambiguate(sender, "short") = "Fizzle Sprocketwhistle"'), "...and what Ambiguate makes of it")
    check(said("toasts: guild"), "...and the toasts' state")
    check(said("last guild send failure"), "...and the last failure")
    eq(#WoW.chat, 0, "none of it in chat")

    clearLog(NS)
    WoW.fire("CHAT_MSG_ADDON", "GSWEEP", "1\tN\texpert:area=900@1790000000", "GUILD", "Ann Gear", "", 0, 0, "", 0)
    check(said('sender="Ann Gear"'), "a guildmate's message: who sent it")
    check(not said("expert:area"), "...but not what they wrote (its shape only)")
    clearLog(NS)
    WoW.fire("CHAT_MSG_ADDON", "OTHER", "x", "GUILD", "Someone", "", 0, 0, "", 0)
    check(not said("CHAT_MSG_ADDON"), "another prefix's message is ignored")
end

do  -- no guild: nothing sent, and it says so
    local NS = loadProbe()
    probeSlash("guild")
    eq(#WoW.addonSent, 0, "not in a guild: nothing is sent")
    check(said("not in a guild"), "...and it says why")
    check(said("UnitName ="), "...the identity is still reported")
end

----------------------------------------------------------------------------
-- Every widget method the probe calls is the build's
----------------------------------------------------------------------------
do
    local NS, W = open({ preset = "expert" })
    WoW.modelSetFails[6977] = nil
    WoW.modelBoxes[6977] = { -0.5, -0.4, -0.6, 0.5, 0.4, 0.6 }
    WoW.modelBoxes["unit:player"] = { -0.3, -0.3, -0.5, 0.3, 0.3, 0.5 }
    probeSlash("perf")
    probeSlash("input"); click(2, L); probeSlash("input")
    probeSlash("models")
    WoW.advance(3.5)
    local P = NS.Models._test
    P.cells[1]._scripts.OnClick(P.cells[1])
    WoW.advance(0.5)
    local v = P.viewer()
    v.next._scripts.OnClick(v.next); v.prev._scripts.OnClick(v.prev)
    v.sparks._scripts.OnClick(v.sparks)
    probeSlash("modelperf")
    for _ = 1, 700 do WoW.tick(0.016) end
    WoW.advance(1)
    for _ = 1, 700 do WoW.tick(0.016) end
    P.sheet():Hide()
    probeSlash("assets")
    local sheet = NS.Assets._test.sheet()
    sheet._scripts.OnDragStart(sheet); sheet._scripts.OnDragStop(sheet)
    sheet.close._scripts.OnClick(sheet.close)
    local recorded = Kit.checkMethods()
    check(recorded >= 150, "the probe's exercise reached its sheets (" .. recorded .. " recorded)")
end

done("test_probe")
