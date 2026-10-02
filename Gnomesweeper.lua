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
    "/gsweep reset - put the window back in the middle of the screen",
}

local function Slash(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "" then
        GS.Window.Toggle()
    elseif GS.Board.PRESETS[msg] then
        GS.Window.Open(msg)
    elseif msg == "reset" then
        GS.Window.ResetPosition()
        Print("window position reset.")
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
