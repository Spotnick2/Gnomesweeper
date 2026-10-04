-- Gnomesweeper.lua: the entry point. SavedVariables defaults and the slash
-- commands. Loads last.

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local GS = Gnomesweeper
local L = GS.L             -- the player's language (#36)

GS.TAGLINE = L["One wrong click. Full wipe."]

-- Missing keys are filled in; existing ones are never overwritten, so the
-- shape on disk only ever grows. (Also kept in GnomesweeperDB, but not here:
-- `pos`, the window's saved corner, which is nil until it has been moved.)
local DEFAULTS = {
    difficulty = "beginner",
    safeZone = "area",         -- "area": the first click opens an area; "cell": XP's single safe cell
    questionMarks = false,
    chordOnLeft = false,       -- left-click a satisfied number to chord it (a setting, #8)
    sounds = true,             -- the effects (#9)
    music = false,             -- Gnomeregan's music while the board is open (#22)
    fireworks = true,          -- fireworks on a new personal best (#10)
    hideInCombat = true,       -- a fight puts the window away, its end brings it back (#37)
    theme = "classic",         -- the board's tiles: classic or modern (#14)
    guildToasts = true,        -- a toast when a guildmate sets a new guild best (#17)
}

local function EnsureDefaults()
    if type(GnomesweeperDB) ~= "table" then GnomesweeperDB = {} end
    if type(GnomesweeperDB.minimap) ~= "table" then GnomesweeperDB.minimap = {} end   -- LibDBIcon's own table
    for k, v in pairs(DEFAULTS) do
        if GnomesweeperDB[k] == nil then GnomesweeperDB[k] = v end
    end
end

local function Print(msg)
    print("|cff7fd4ffGnome|rsweeper: " .. msg)
end
GS.Print = Print

-- Also listed on Options > AddOns > Gnomesweeper > About (all but the "(for measuring)" ones).
-- The player's commands are translated (the commands themselves stay English); the
-- measuring probes stay English, and their "(for measuring)" is what About skips.
local HELP = {
    L["/gsweep - open or close the board (also /gnomesweeper, /minewipe)"],
    L["/gsweep beginner | intermediate | expert - start a game at that difficulty"],
    L["/gsweep scores - your best times (also the trophy in the title bar)"],
    L["/gsweep settings - open the settings (Options > AddOns > Gnomesweeper; also the gear)"],
    L["/gsweep music - Gnomeregan's music on or off (also the note in the title bar)"],
    L["/gsweep combat - hide the window in combat (and bring it back after), on or off"],
    L["/gsweep minimap - show or hide the minimap button"],
    L["/gsweep reset - put the window back in the middle of the screen"],
    L["/gsweep scale 0.5 to 1.5 | reset - resize the window (it never grows past the screen)"],
    "/gsweep assets - a sheet of every texture, to check by eye that each one draws (for measuring)",
    "/gsweep models | models perf - every candidate creature model (loaded, textured, its animations), then their frame cost over the board (for measuring), kept for /reload to save",
    "/gsweep sounds - play every candidate sound and the music, one after another (for measuring)",
    "/gsweep perf - time the board on an Expert-sized game (for measuring)",
    "/gsweep input - log every mouse press and release on the tiles (for measuring), kept for /reload to save; again to stop",
    "/gsweep guildprobe - how the guild sees this character's addon messages (for measuring), kept for /reload to save",
}

local function Slash(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "" then
        GS.Window.Toggle()
    elseif GS.Board.PRESETS[msg] then
        GS.Window.Open(msg)
    elseif msg == "scores" or msg == "bests" then
        GS.Window.ShowBests(true)
    elseif msg == "settings" or msg == "options" or msg == "config" then
        GS.Options.Open()
    elseif msg == "music" then
        GS.Options.Set("music", not GnomesweeperDB.music)
        Print(GnomesweeperDB.music and L["Gnomeregan's music on."] or L["Gnomeregan's music off."])
    elseif msg == "sounds" then
        GS.Sounds.ToggleProbe()
    elseif msg == "combat" then
        GS.Options.Set("hideInCombat", not GnomesweeperDB.hideInCombat)
        Print(GnomesweeperDB.hideInCombat and L["hide in combat on: a fight puts the window away until it ends."]
            or L["hide in combat off: the window stays up in combat."])
    elseif msg == "minimap" then
        if not GS.Minimap.Available() then
            Print(L["there is no minimap button: its libraries didn't load (or another addon took the name)."])
        else
            GS.Options.Set("minimapButton", not GS.Minimap.Shown())
            Print(GS.Minimap.Shown() and L["minimap button shown."] or L["minimap button hidden: /gsweep minimap brings it back."])
        end
    elseif msg == "reset" then
        GS.Window.ResetPosition()
        Print(L["window position reset."])
    elseif msg == "scale" or msg:find("^scale%s") then
        local arg = msg:match("^scale%s*(.-)%s*$")
        local W, Lay = GS.Window, GS.Layout
        -- A scale shown is in the player's decimals; one to type stays "0.5" (the command's).
        local function shownAt(want, shown)
            return math.abs(want - shown) > 0.005 and string.format(L[" (shown at %s: that is what fits the screen)"], GS.Decimal("%.2f", shown)) or ""
        end
        local lo, hi = string.format("%.1f", Lay.USER_SCALE_MIN), string.format("%.1f", Lay.USER_SCALE_MAX)
        if arg == "" then
            local want, shown = W.ScaleInfo()
            Print(string.format(L["window scale %s%s. /gsweep scale %s to %s, or reset."], GS.Decimal("%.2f", want),
                shownAt(want, shown), lo, hi))
        elseif arg == "reset" then
            GS.Options.Set("scale", 1)
            Print(L["window scale back to 1."])
        elseif Lay.ValidUserScale(tonumber(arg)) then
            GS.Options.Set("scale", tonumber(arg))       -- the one place a setting changes
            local want, shown = W.ScaleInfo()
            Print(string.format(L["window scale %s%s."], GS.Decimal("%.2f", want), shownAt(want, shown)))
        else
            Print(string.format(L["scale must be a number from %s to %s (or reset)."], lo, hi))
        end
    elseif msg == "assets" then
        GS.Assets.Toggle()
    elseif msg == "models" then
        GS.ModelProbe.Toggle()
    elseif msg == "models perf" then
        GS.ModelProbe.Perf()
    elseif msg == "perf" then
        for _, line in ipairs(GS.Window.Benchmark()) do Print(line) end
    elseif msg == "guildprobe" then
        GS.Social.Probe()
    elseif msg == "input" then
        GS.Grid.SetLogging(not GS.Grid.Logging())
        Print("tile input logging " .. (GS.Grid.Logging()
            and "on: click some tiles, then /reload to save the log." or "off."))
    else
        if msg ~= "help" then Print(string.format(L["unknown option '%s'."], msg)) end
        for _, line in ipairs(HELP) do Print(line) end
    end
end

GS.HELP = HELP

-- The key binding (#23, Bindings.xml, its own "Gnomesweeper" section): its line in Key
-- Bindings. A global, as the client looks it up by name.
BINDING_NAME_GNOMESWEEPER_TOGGLE = L["Open or close the board"]

SLASH_GNOMESWEEPER1 = "/gnomesweeper"
SLASH_GNOMESWEEPER2 = "/gsweep"
SLASH_GNOMESWEEPER3 = "/minewipe"
SlashCmdList.GNOMESWEEPER = Slash

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, name)
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    EnsureDefaults()
end)

GS._test = { DEFAULTS = DEFAULTS, Slash = Slash }
