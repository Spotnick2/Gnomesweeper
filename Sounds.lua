-- Sounds.lua: the sound effects (#9) and Gnomeregan's music (#22).
--
-- Effects are the client's own sound kits, played with the global
-- PlaySound(kit, "SFX") (so the game's Sound Effects toggle and volume apply).
-- PlaySoundFile refuses the game's own file paths on Forever (porting guide); kit
-- IDs play. (C_Sound.PlaySound's second argument is a UISoundSubType enum, not a
-- channel: it isn't used here.) The kits are the candidates in docs/SOUNDS.md;
-- /gsweep sounds plays each one to choose by ear and records what the client
-- said.
--
-- The wipe is two sounds in a row, the bomb and then a gnome's last words: two
-- PlaySound calls at once overlap, so the second waits WIPE_DELAY. A new game, or
-- the window closing, cancels a sound still waiting.
--
-- Music: PlayMusic(fileID) replaces the zone's music until StopMusic(). One check
-- gates it (the setting on, the window shown, not in combat), run whenever any of
-- those changes. StopMusic() only when this addon started it: it is the client's
-- shared music, not our handle.
--
-- The owner heard the zone's music AND ours "sometimes" (70205). Soundtrack (a
-- music addon) replays its track on every zone event, so it would never notice
-- the client starting a zone's music on a sub-zone change; we didn't. So while
-- ours plays, every zone event plays it again. Every music decision is logged
-- (GnomesweeperDB.musicLog, the last 60), so the next overlap can be matched to
-- what happened, read from disk after a /reload.

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local GS = Gnomesweeper
local Sounds = {}
GS.Sounds = Sounds

-- The picks (docs/SOUNDS.md). Unmeasured on Forever until /gsweep sounds.
Sounds.KITS = {
    reveal = 1115,       -- SOUNDKIT.U_CHAT_SCROLL_BUTTON: a soft click
    flag = 856,          -- SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
    unflag = 857,        -- SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
    boom = 7517,         -- GnomeBomBotDeath: the Walking Bomb's own death
    wipe = 1038,         -- GnomeDeath: the owner's pick, after the bomb
    win = 6131,          -- a gnome saying "Congratulations"
    newGame = 4779,      -- G_ButtonBigRed: Mimiron's big red button
}
Sounds.WIPE_DELAY = 0.7  -- seconds from the bomb to the gnome; tune by ear
Sounds.MUSIC = 53189     -- gnomeragon01-zone

local function db() return GnomesweeperDB end

------------------------------------------------------------
-- Effects
------------------------------------------------------------

-- Plays one effect if sounds are on. Returns the client's willPlay (nil when off).
function Sounds.Play(name)
    if db().sounds == false then return nil end
    local kit = Sounds.KITS[name]
    if not kit then return nil end
    return (PlaySound(kit, "SFX"))
end

local pending = 0        -- bumped to cancel a sound still waiting

function Sounds.Cancel() pending = pending + 1 end

local function later(delay, name)
    local mine = pending
    C_Timer.After(delay, function()
        if mine == pending then Sounds.Play(name) end
    end)
end

-- After an action on the board (Window.Dispatch): what it did, by sound.
-- `kind` is reveal/chord/mark, `was` and `now` the game's state before and
-- after, `cell` the acted-on cell after the action, `changed` how many cells.
function Sounds.Action(kind, was, now, cell, changed)
    if changed == 0 then return end
    if now == "lost" and was ~= "lost" then
        Sounds.Play("boom")
        later(Sounds.WIPE_DELAY, "wipe")
    elseif now == "won" and was ~= "won" then
        Sounds.Play("win")
    elseif kind == "mark" then
        Sounds.Play(cell.state == "covered" and "unflag" or "flag")
    else
        Sounds.Play("reveal")
    end
end

-- A new game the player asked for (the face, Play again / Try again).
function Sounds.NewGame()
    Sounds.Cancel()
    Sounds.Play("newGame")
end

------------------------------------------------------------
-- Music
------------------------------------------------------------

local playing = false    -- this addon started the music and hasn't stopped it
local inCombat = false

local LOG_MAX = 60
local function log(fmt, ...)
    local l = GnomesweeperDB and GnomesweeperDB.musicLog
    if type(l) ~= "table" then
        if not GnomesweeperDB then return end
        l = {}
        GnomesweeperDB.musicLog = l
    end
    l[#l + 1] = string.format("%.1f  ", GetTime()) .. string.format(fmt, ...)
    while #l > LOG_MAX do table.remove(l, 1) end
end

local function eligible()
    return db().music == true and GS.Window.IsShown() and not inCombat
end

-- Starts or stops the music to match the one check. Safe to call any time.
function Sounds.UpdateMusic()
    if eligible() then
        if not playing then
            PlayMusic(Sounds.MUSIC)
            playing = true
            log("PlayMusic(%d)", Sounds.MUSIC)
        end
    elseif playing then
        StopMusic()
        playing = false
        log("StopMusic (music %s, window %s, combat %s)", tostring(db().music), tostring(GS.Window.IsShown()), tostring(inCombat))
    end
end

-- A zone event while ours plays: play it again, over whatever the zone started.
local function reassert(event)
    if playing then
        PlayMusic(Sounds.MUSIC)
        log("%s: PlayMusic(%d) again", event, Sounds.MUSIC)
    else
        log("%s (not playing)", event)
    end
end

function Sounds.MusicPlaying() return playing end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
for _, e in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
    events:RegisterEvent(e)
end
events:SetScript("OnEvent", function(_, event)
    if event:find("^ZONE_CHANGED") or event == "PLAYER_ENTERING_WORLD" then
        reassert(event)
        return
    end
    log("%s", event)
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
    else                                                   -- a /reload in the middle of a fight
        inCombat = UnitAffectingCombat("player") and true or false
    end
    Sounds.UpdateMusic()
end)

------------------------------------------------------------
-- /gsweep sounds: every candidate, one after another (for measuring)
------------------------------------------------------------

-- (17484, 17487 and 17569, the Cataclysm-era Operation: Gnomeregan kits, were
-- refused on 70205: willPlay false. Dropped.)
Sounds.CANDIDATES = {
    { 1115, "reveal: U_CHAT_SCROLL_BUTTON (soft click)" },
    { 856, "flag: IG_MAINMENU_OPTION_CHECKBOX_ON" },
    { 857, "unflag: IG_MAINMENU_OPTION_CHECKBOX_OFF" },
    { 7517, "boom: GnomeBomBotDeath (the Walking Bomb)" },
    { 1038, "wipe voice: GnomeDeath (owner's pick)" },
    { 3278, "wipe voice: GnomeMaleFinalDeath" },
    { 3272, "wipe voice: GnomeFemaleMainDeath1" },
    { 6131, "win: a gnome says Congratulations" },
    { 4779, "new game: G_ButtonBigRed (Mimiron's button)" },
    { 15252, "new game: UL_Gnomewing_ButtonBigRed_Close" },
    { 5925, "window opens: GnomeMaleZanyNPCGreetings" },
    { 5931, "window opens: GnomeFemaleNerdyNPCGreetings" },
    { 18871, "alarm: AlarmClockWarning1" },
}
Sounds.PROBE_GAP = 3       -- seconds between candidates
Sounds.MUSIC_PROBE = 12    -- seconds of music at the end

local probeRun = 0

function Sounds.Probe()
    probeRun = probeRun + 1
    local run = probeRun
    local version, build = GetBuildInfo()
    local results = { build = tostring(version) .. "." .. tostring(build), kits = {} }
    db().soundProbe = results
    local list = Sounds.CANDIDATES
    GS.Print(string.format("playing %d sounds, %d s apart, then %d s of music. /gsweep sounds again stops it.",
        #list, Sounds.PROBE_GAP, Sounds.MUSIC_PROBE))
    for i, c in ipairs(list) do
        C_Timer.After((i - 1) * Sounds.PROBE_GAP, function()
            if run ~= probeRun then return end
            local willPlay = PlaySound(c[1], "SFX")
            results.kits[c[1]] = { name = c[2], willPlay = willPlay and true or false }
            GS.Print(string.format("%d/%d  %d  %s%s", i, #list, c[1], c[2], willPlay and "" or "  (the client says it won't play)"))
        end)
    end
    local t = #list * Sounds.PROBE_GAP
    C_Timer.After(t, function()
        if run ~= probeRun then return end
        local ok, r1 = pcall(PlayMusic, Sounds.MUSIC)
        results.music = { file = Sounds.MUSIC, ok = ok, returned = tostring(r1) }
        GS.Print(string.format("music: PlayMusic(%d), Gnomeregan's zone music, for %d s.", Sounds.MUSIC, Sounds.MUSIC_PROBE))
    end)
    C_Timer.After(t + Sounds.MUSIC_PROBE, function()
        if run ~= probeRun then return end
        StopMusic()
        playing = false
        Sounds.UpdateMusic()
        GS.Print("done. /reload saves what the client said; tell me what you heard.")
    end)
end

-- Toggle: a second /gsweep sounds while one runs stops it.
local probing = false
function Sounds.ToggleProbe()
    if probing then
        probeRun = probeRun + 1
        probing = false
        StopMusic()
        playing = false
        Sounds.UpdateMusic()
        GS.Print("sound check stopped.")
        return
    end
    probing = true
    Sounds.Probe()
    local run = probeRun
    C_Timer.After(#Sounds.CANDIDATES * Sounds.PROBE_GAP + Sounds.MUSIC_PROBE, function()
        if run == probeRun then probing = false end
    end)
end

Sounds._test = {
    inCombat = function() return inCombat end,
}
