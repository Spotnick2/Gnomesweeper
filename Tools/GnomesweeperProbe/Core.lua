-- GnomesweeperProbe: Gnomesweeper's developer probes (#87), a ForeverProbe module
-- (..\ForeverProbe, its docs/GUIDE.md). Never packaged: nothing here reaches a
-- player. Its lines go to the ForeverProbe console (/fp) and to
-- GnomesweeperProbeDB.log, never to chat; what a probe measured is also kept in
-- GnomesweeperProbeDB, so a /reload writes it to disk to be read.
--
-- It reads the addon through its public functions and its _test seams; the
-- shipped addon has no probe code and no hook for one. A probe: English.
--
--   /fp gs assets      a sheet of every texture, to check each one draws (Assets.lua, #6)
--   /fp gs models      every candidate creature model, and a viewer (Models.lua, #20)
--   /fp gs modelperf   the frame rate over the board without, then with, two models
--   /fp gs bomb        replay the end panel's model, to judge it (#21)
--   /fp gs sounds      every candidate sound, then the music; again to stop (#9, #22)
--   /fp gs perf        time the board on an Expert-sized game (#4)
--   /fp gs input       log every tile press and release, and what each action did; again to stop (#4)
--   /fp gs guild       how the guild sees this character's addon messages (#15, phase 0)

local ADDON, NS = ...
local GS = Gnomesweeper
local MAX_LOG = 3000

local P = ForeverProbe:Module("GnomesweeperProbe", { api = 1, cmd = "gs" })
NS.P = P

-- A line to the console and the log. With arguments, a format string.
function NS.say(fmt, ...)
    if select("#", ...) > 0 then fmt = string.format(fmt, ...) end
    P:Say(fmt)
end
local say = NS.say

-- The probe's saved table: made at its own ADDON_LOADED (GUIDE section 1), read after.
function NS.db()
    if type(GnomesweeperProbeDB) ~= "table" then GnomesweeperProbeDB = {} end
    return GnomesweeperProbeDB
end

function NS.build()
    local version, build = GetBuildInfo()
    return tostring(version) .. "." .. tostring(build)
end

------------------------------------------------------------
-- /fp gs bomb (#21): replay the end panel's model without ending another game
------------------------------------------------------------

function NS.Bomb()
    local W, Models = GS.Window, GS.Models
    local ui = W._test.ui
    if not W.IsShown() then return "open the board first (/gsweep)." end
    if not Models.Enabled() then return "3D models are off in the settings." end
    if not (ui.overlay and ui.overlay:IsShown()) then
        return "end a game first (a wipe for the bomb, a win for Tally): this replays the panel's model."
    end
    ui.slot.stop()
    W.EndModel()
    local c = Models.CAST[W.game:State() == "won" and "win" or "wipe"]
    -- Its steps as "1 (1.5 s), 6 (held, lift 24)", to judge each by eye.
    local steps = {}
    for _, s in ipairs(c.steps) do
        steps[#steps + 1] = string.format("%d (%s%s)", s[1], s[2] and string.format("%.2f s", s[2]) or "held",
            s.lift and (", lift " .. s.lift) or "")
    end
    return string.format("display %d: %s; drawn %d units tall (tiles are 24).", c.display,
        table.concat(steps, ", "), Models.HEIGHT)
end

P:Command("bomb", function() say(NS.Bomb()) end, "replay the end panel's model (the bomb, or Tally on a win)")

------------------------------------------------------------
-- /fp gs perf (#4): the heavy operations, timed on a scratch Expert board
------------------------------------------------------------

local function timed(fn)
    local t0 = debugprofilestop()
    local n = fn()
    return debugprofilestop() - t0, n
end

-- Times them, then puts the real game back on the board. Returns lines of text.
function NS.Perf()
    local W, Grid, Board = GS.Window, GS.Grid, GS.Board
    if not W.IsShown() then return { "open the board first (/gsweep): this times its tiles." } end
    local out = {}
    local ex, bg = Board.PRESETS.expert, Board.PRESETS.beginner
    local big = Board.New(ex.w, ex.h, ex.mines)
    local small = Board.New(bg.w, bg.h, bg.mines)
    local created = #Grid._test.tiles
    local ms, n = timed(function() Grid.Rebuild(big); return math.max(0, big.total - created) end)
    out[#out + 1] = string.format("build Expert: %.1f ms (%d new tiles)", ms, n)
    ms, n = timed(function()
        local list = big:Reveal(15, 8, GetTime())
        Grid.Refresh(list)
        return #list
    end)
    out[#out + 1] = string.format("first reveal and repaint: %.1f ms (%d cells)", ms, n)
    for i = 1, big.total do                               -- find a mine (the scratch board's own field)
        if big._mine[i] then
            local x, y = big:XY(i)
            ms, n = timed(function()
                local list = big:Reveal(x, y, GetTime())
                Grid.Refresh(list)
                return #list
            end)
            out[#out + 1] = string.format("a loss, every mine shown: %.1f ms (%d cells)", ms, n)
            break
        end
    end
    ms = timed(function()
        for _ = 1, 5 do Grid.Rebuild(small); Grid.Rebuild(big) end
    end)
    out[#out + 1] = string.format("10 difficulty switches: %.1f ms", ms)
    -- The real game back, as the window shows it.
    W.Layout()
    Grid.Rebuild(W.game)
    local s = W.game:State()
    if s == "won" or s == "lost" then Grid.SetInteractive(false) end
    W.Refresh()
    return out
end

P:Command("perf", function()
    for _, line in ipairs(NS.Perf()) do say(line) end
end, "time the board on an Expert-sized game")

------------------------------------------------------------
-- /fp gs input (#4): every press and release on the tiles, and what each action did
------------------------------------------------------------
-- The tiles' scripts are hooked (HookScript: kept, and silent while off), and
-- Window.Dispatch and Grid.Refresh are wrapped while it's on and put back after.

local input = { on = false, hooked = {} }

local function hookTiles()
    for _, t in ipairs(GS.Grid._test.tiles) do
        if not input.hooked[t] then
            input.hooked[t] = true
            t:HookScript("OnMouseDown", function(self, button)
                if input.on then say("tile %d  down  %s", self.index, tostring(button)) end
            end)
            t:HookScript("OnMouseUp", function(self, button, upInside)
                if input.on then
                    say("tile %d  up    %s  upInside=%s  IsMouseOver=%s", self.index, tostring(button),
                        tostring(upInside), tostring(self:IsMouseOver()))
                end
            end)
        end
    end
end

-- What the cell was (its state, its count, the flags around it), so "nothing happened"
-- can be explained from the log alone.
local function describe(game, i)
    local x, y = game:XY(i)
    if not x then return "cell " .. tostring(i) end
    local c, flags = game:Cell(i), 0
    for dy = -1, 1 do
        for dx = -1, 1 do
            local j = (dx ~= 0 or dy ~= 0) and game:Index(x + dx, y + dy)
            if j and game:Cell(j).state == "flag" then flags = flags + 1 end
        end
    end
    return string.format("(%d,%d) %s%s, %d flags around", x, y, c.state, c.count and (" " .. c.count) or "", flags)
end

function NS.SetInput(on)
    local W, Grid = GS.Window, GS.Grid
    on = on and true or false
    if on == input.on then return end
    input.on = on
    if on then
        hookTiles()
        input.dispatch, input.refresh, input.rebuild = W.Dispatch, Grid.Refresh, Grid.Rebuild
        local changed
        Grid.Refresh = function(list, ...)
            changed = (changed or 0) + (type(list) == "table" and #list or 0)
            return input.refresh(list, ...)
        end
        Grid.Rebuild = function(...)                    -- new tiles from a bigger board get hooked too
            local r = input.rebuild(...)
            hookTiles()
            return r
        end
        W.Dispatch = function(kind, i)
            local game = W.game
            local before = game and describe(game, i)
            -- The option turns a left click on a revealed number into a chord (as Dispatch does).
            local shown = kind
            if game and kind == "reveal" and GnomesweeperDB.chordOnLeft and game:Cell(i).state == "revealed" then shown = "chord" end
            changed = nil
            local r = input.dispatch(kind, i)
            if before then
                say("%s on %s -> %d cells changed (%s)", shown, before, changed or 0, W.game:State())
            end
            return r
        end
    else
        W.Dispatch, Grid.Refresh, Grid.Rebuild = input.dispatch, input.refresh, input.rebuild
    end
end
function NS.Input() return input.on end

P:Command("input", function()
    NS.SetInput(not input.on)
    say(input.on and "tile input logging on: click some tiles, then /reload to save the log."
        or "tile input logging off.")
end, "log every tile press and release, and what each action did; again to stop")

------------------------------------------------------------
-- /fp gs sounds (#9, #22): every candidate, one after another, then the music
------------------------------------------------------------

-- The choices still open (the rest are picked and measured: docs/SOUNDS.md).
-- The first round (70205) refused 17484, 17487 and 17569, the Cataclysm-era
-- Operation: Gnomeregan kits. These alert candidates are Blizzard's own SOUNDKIT.
NS.SOUNDS = {
    { 18871, "alert (the clock passed your best): ALARM_CLOCK_WARNING_1" },
    { 12867, "alert: ALARM_CLOCK_WARNING_2" },
    { 12889, "alert: ALARM_CLOCK_WARNING_3" },
    { 8959, "alert: RAID_WARNING" },
    { 8960, "alert: READY_CHECK" },
    { 4574, "alert: IG_PVP_UPDATE" },
    { 8459, "alert: PVP_THROUGH_QUEUE (the battleground is ready)" },
    { 25477, "alert: UI_BATTLEGROUND_COUNTDOWN_TIMER" },
    { 878, "new best: IG_QUEST_LIST_COMPLETE (the current pick)" },
    { 31578, "new best: UI_EPICLOOT_TOAST" },
    { 63971, "new best: UI_LEGENDARY_LOOT_TOAST" },
    { 73277, "new best: UI_WORLDQUEST_COMPLETE" },
    { 8569, "fireworks (the owner's pick)" },
    { 4935, "new game: GnomeRoboArmFidget01Fidget02 (the owner's pick)" },
}
NS.SOUND_GAP = 3       -- seconds between candidates
NS.MUSIC_SECONDS = 12  -- seconds of music at the end

local sounds = { run = 0, on = false }

-- The music is the addon's own check's business when its setting is on (it plays while
-- the board is shown, out of combat); the probe plays it itself only when that's off.
local function stopProbeMusic()
    if sounds.music then
        sounds.music = false
        StopMusic()
        GS.Sounds.UpdateMusic()                          -- the setting's music back, if it wants it
    end
end

function NS.Sounds()
    sounds.run = sounds.run + 1
    sounds.on = true
    local run = sounds.run
    local results = { build = NS.build(), kits = {} }
    NS.db().sounds = results
    local list = NS.SOUNDS
    say("playing %d sounds, %d s apart, then %d s of music. /fp gs sounds again stops it.",
        #list, NS.SOUND_GAP, NS.MUSIC_SECONDS)
    for i, c in ipairs(list) do
        C_Timer.After((i - 1) * NS.SOUND_GAP, function()
            if run ~= sounds.run then return end
            local willPlay = PlaySound(c[1], "SFX")
            results.kits[c[1]] = { name = c[2], willPlay = willPlay and true or false }
            say("%d/%d  %d  %s%s", i, #list, c[1], c[2], willPlay and "" or "  (the client says it won't play)")
        end)
    end
    local t = #list * NS.SOUND_GAP
    C_Timer.After(t, function()
        if run ~= sounds.run then return end
        if GnomesweeperDB.music then
            results.music = { file = GS.Sounds.MUSIC, setting = true }
            say("music: the setting is on, so it plays as the board shows it (%d).", GS.Sounds.MUSIC)
        elseif not GS.Window.IsShown() or UnitAffectingCombat("player") then
            -- The addon's own rule (the board shown, not in combat), at the music's turn.
            results.music = { file = GS.Sounds.MUSIC, started = false }
            say("music: skipped (the board is closed, or you're in combat).")
        else
            sounds.music = true
            PlayMusic(GS.Sounds.MUSIC)
            results.music = { file = GS.Sounds.MUSIC, started = true }
            say("music: Gnomeregan's zone music (%d), for %d s.", GS.Sounds.MUSIC, NS.MUSIC_SECONDS)
        end
    end)
    C_Timer.After(t + NS.MUSIC_SECONDS, function()
        if run ~= sounds.run then return end
        stopProbeMusic()
        sounds.on = false
        say("done. /reload saves what the client said; tell me what you heard.")
    end)
end

function NS.StopSounds()
    sounds.run = sounds.run + 1                          -- the remaining callbacks do nothing
    sounds.on = false
    stopProbeMusic()
    say("sound check stopped.")
end

P:Command("sounds", function()
    if sounds.on then NS.StopSounds() else NS.Sounds() end
end, "play every candidate sound and the music, one after another; again to stop")

------------------------------------------------------------
-- /fp gs guild (#15, phase 0): how the guild names this character's addon messages
------------------------------------------------------------
-- What this character is called (every API's answer), a "P" message (a type no v1
-- client knows) to the guild, and the server's echo. Only our own echo is logged
-- whole: a guildmate's message is logged by its shape (GUIDE section 1).

local guild = { listening = false }
local PREFIX = "GSWEEP"

local function identity()
    local show = P.Show
    local name, second = UnitName("player")
    say("UnitName = %s, %s", show(name), show(second))
    local full, server = UnitFullName("player")
    say("UnitFullName = %s, %s", show(full), show(server))
    say("GetRealmName = %s, GetNormalizedRealmName = %s", show(GetRealmName()), show(GetNormalizedRealmName()))
    say("API.PlayerFullName = %s", show(GS.API.PlayerFullName()))
    say("IsInGuild = %s", show(IsInGuild()))
    local g = { GetGuildInfo("player") }
    say("GetGuildInfo = %s, %s, %s, %s", show(g[1]), show(g[2]), show(g[3]), show(g[4]))
end

local listener = CreateFrame("Frame")
listener:SetScript("OnEvent", function(_, _, prefix, text, channel, sender, target, zone, localID, name, instance)
    if prefix ~= PREFIX then return end
    local show = P.Show
    local ours = sender == GS.API.PlayerFullName()
    say("CHAT_MSG_ADDON channel=%s sender=%s target=%s", show(channel), show(sender), show(target))
    say("  text=%s zone=%s local=%s name=%s instance=%s", ours and show(text) or P.Shape(text),
        show(zone), show(localID), show(name), show(instance))
    for _, ctx in ipairs({ "none", "short", "guild", "mail" }) do
        local ok, out = pcall(Ambiguate, sender, ctx)
        say("  Ambiguate(sender, %q) = %s", ctx, ok and show(out) or ("error " .. tostring(out)))
    end
end)

function NS.Guild()
    local show, S = P.Show, GS.Social
    local ok, registered = pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    say("prefix %s registered: %s", PREFIX, ok and show(registered) or ("error " .. tostring(registered)))
    identity()
    if not guild.listening then
        guild.listening = P:RegisterEvents(listener, { "CHAT_MSG_ADDON" })
    end
    if not IsInGuild() then
        say("not in a guild: nothing sent (join one, or use a character in one, and try again)")
        return
    end
    local message = "1\tP\t" .. time()
    local okS, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, message, "GUILD")
    say("SendAddonMessage(GUILD) = %s", okS and show(result) or ("error " .. tostring(result)))
    say("last guild send failure: %s", show(S.lastFailure))
    local T = S._test
    local gk = T.guildKey()
    local first = gk and T.firstQuery()[gk]
    say("toasts: guild %s, synced %s, heard %s, first query %s, waiting %d, setting %s", show(gk),
        show(gk and T.synced(gk)), show(gk and T.heard()[gk]),
        first and string.format("%.0f s ago", GetTime() - first) or "never",
        #T.queue(), show(GnomesweeperDB.guildToasts))
    say("waiting for the echo (it should arrive within a second or two); then /reload to save")
end

P:Command("guild", function() NS.Guild() end, "how the guild sees this character's addon messages")

------------------------------------------------------------
-- Load
------------------------------------------------------------

P:Command("clear", function() P:ClearLog(); say("log cleared") end, "empty the saved log")

local boot = CreateFrame("Frame")
P:RegisterEvents(boot, { "ADDON_LOADED" })
boot:SetScript("OnEvent", function(_, _, name)
    if name ~= ADDON then return end
    P:Ready()
    local db = NS.db()
    if type(db.log) ~= "table" then db.log = {} end
    P:UseLog(db.log, MAX_LOG)                         -- from here on, lines are saved too
    db.loads = (db.loads or 0) + 1
    say("loaded (%d loads). /fp gs for the commands", db.loads)
end)

NS._test = { P = P, input = input, sounds = sounds, guild = guild }
