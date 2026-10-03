-- Gnomesweeper.lua: the entry point. SavedVariables defaults and the slash
-- commands. Loads last.

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local GS = Gnomesweeper

GS.TAGLINE = "One wrong click. Full wipe."

-- Missing keys are filled in; existing ones are never overwritten, so the
-- shape on disk only ever grows. (Also kept in GnomesweeperDB, but not here:
-- `pos`, the window's saved corner, which is nil until it has been moved.)
local DEFAULTS = {
    difficulty = "beginner",
    safeZone = "area",         -- "area": the first click opens an area; "cell": XP's single safe cell
    questionMarks = false,
    chordOnLeft = false,       -- left-click a satisfied number to chord it (the settings panel, #8, will offer it)
}

local function EnsureDefaults()
    if type(GnomesweeperDB) ~= "table" then GnomesweeperDB = {} end
    for k, v in pairs(DEFAULTS) do
        if GnomesweeperDB[k] == nil then GnomesweeperDB[k] = v end
    end
end

local function Print(msg)
    print("|cff7fd4ffGnome|rsweeper: " .. msg)
end

local HELP = {
    "/gsweep - open or close the board (also /gnomesweeper, /minewipe)",
    "/gsweep beginner | intermediate | expert - start a game at that difficulty",
    "/gsweep scores - your best times (also the trophy in the title bar)",
    "/gsweep settings - the settings (also the gear, and Options > AddOns > Gnomesweeper)",
    "/gsweep reset - put the window back in the middle of the screen",
    "/gsweep scale 0.5 to 1.5 | reset - resize the window (it never grows past the screen)",
    "/gsweep assets - a sheet of every texture, to check by eye that each one draws",
    "/gsweep perf - time the board on an Expert-sized game (for measuring)",
    "/gsweep input - log every mouse press and release on the tiles (for measuring), kept for /reload to save; again to stop",
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
        GS.Options.ShowPanel(true)
    elseif msg == "reset" then
        GS.Window.ResetPosition()
        Print("window position reset.")
    elseif msg == "scale" or msg:find("^scale%s") then
        local arg = msg:match("^scale%s*(.-)%s*$")
        local W, L = GS.Window, GS.Layout
        if arg == "" then
            local want, shown = W.ScaleInfo()
            Print(string.format("window scale %.2f%s. /gsweep scale %.1f to %.1f, or reset.", want,
                math.abs(want - shown) > 0.005 and string.format(" (shown at %.2f: that is what fits the screen)", shown) or "",
                L.USER_SCALE_MIN, L.USER_SCALE_MAX))
        elseif arg == "reset" then
            GS.Options.Set("scale", 1)
            Print("window scale back to 1.")
        elseif L.ValidUserScale(tonumber(arg)) then
            GS.Options.Set("scale", tonumber(arg))       -- the one place a setting changes
            local want, shown = W.ScaleInfo()
            Print(string.format("window scale %.2f%s.", want,
                math.abs(want - shown) > 0.005 and string.format(" (shown at %.2f: that is what fits the screen)", shown) or ""))
        else
            Print(string.format("scale must be a number from %.1f to %.1f (or reset).", L.USER_SCALE_MIN, L.USER_SCALE_MAX))
        end
    elseif msg == "assets" then
        GS.Assets.Toggle()
    elseif msg == "perf" then
        for _, line in ipairs(GS.Window.Benchmark()) do Print(line) end
    elseif msg == "input" then
        GS.Grid.SetLogging(not GS.Grid.Logging())
        Print("tile input logging " .. (GS.Grid.Logging()
            and "on: click some tiles, then /reload to save the log." or "off."))
    else
        if msg ~= "help" then Print("unknown option '" .. msg .. "'.") end
        for _, line in ipairs(HELP) do Print(line) end
    end
end

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
