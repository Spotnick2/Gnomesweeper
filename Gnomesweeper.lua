-- Gnomesweeper.lua: the entry point. SavedVariables defaults and the slash
-- commands. Loads last.

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local GS = Gnomesweeper

GS.TAGLINE = "One wrong click. Full wipe."

-- Missing keys are filled in; existing ones are never overwritten, so the
-- shape on disk only ever grows.
local DEFAULTS = {
    difficulty = "beginner",
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

local function Slash(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "help" then
        Print("/gsweep - open the board (also /gnomesweeper, /minewipe)")
    else
        Print("not playable yet. " .. GS.TAGLINE)
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
