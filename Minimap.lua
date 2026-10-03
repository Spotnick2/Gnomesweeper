-- Minimap.lua: the minimap button (#40). Left-click opens or closes the board,
-- right-click opens the settings. It is a LibDataBroker launcher shown by
-- LibDBIcon (Libs\, copied from GlassMiniMapBar), which gives dragging around
-- the ring, round and square minimaps, and lets every button collector
-- (GlassMiniMapBar, HidingBar, MBB) pick it up.
--
-- Its position and whether it is shown are LibDBIcon's own table,
-- GnomesweeperDB.minimap ({ hide, minimapPos, ... }). Showing or hiding it is a
-- setting (Options.lua: "minimapButton"), so it goes through Options.Set.

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local GS = Gnomesweeper
local Minimap_ = {}          -- not "Minimap": that is the client's minimap frame
GS.Minimap = Minimap_

local NAME = "Gnomesweeper"
local registered = false

-- LibDBIcon's table. Made (or repaired) once, at ADDON_LOADED (Gnomesweeper.lua),
-- and never replaced after: LibDBIcon keeps a reference to it, and a new table
-- would cut the button off from what is saved.
local function db() return GnomesweeperDB.minimap end

function Minimap_.Shown() return not db().hide end

-- Whether there is a button at all (no libraries, or a name already taken: none).
function Minimap_.Available() return registered end

-- Show or hide it, and save that. LibDBIcon's own Show/Hide never touch the
-- saved table, so the choice is written here.
function Minimap_.SetShown(v)
    db().hide = not v
    Minimap_.Apply()
end

local launcher = {
    type = "launcher",
    label = "Gnomesweeper",
    icon = GS.Skin.TEXTURES.face,
    OnClick = function(_, button)
        if button == "RightButton" then
            GS.Options.Open()
        else
            GS.Window.Toggle()
        end
    end,
    OnTooltipShow = function(tip)
        tip:AddLine("Gnomesweeper")
        tip:AddLine("Left-click: open or close the board", 0.75, 0.78, 0.85)
        tip:AddLine("Right-click: settings", 0.75, 0.78, 0.85)
        tip:AddLine("Drag: move around the minimap", 0.75, 0.78, 0.85)
    end,
}

-- Show or hide it to match the setting (called by Options.Set).
function Minimap_.Apply()
    if not registered then return end
    local icon = LibStub("LibDBIcon-1.0")
    if db().hide then icon:Hide(NAME) else icon:Show(NAME) end
end

local function register()
    if registered then return end
    local ok, ldb = pcall(LibStub, "LibDataBroker-1.1")
    local ok2, icon = pcall(LibStub, "LibDBIcon-1.0")
    if not (ok and ok2 and ldb and icon) then return end    -- no libraries: no button, nothing else breaks
    -- NewDataObject answers nil when another addon already took the name; Register
    -- would then error at login. Either way: no button, and nothing else breaks.
    local obj = ldb:NewDataObject(NAME, launcher)
    if not obj then return end
    registered = pcall(icon.Register, icon, NAME, obj, db())
end

local reg = CreateFrame("Frame")
reg:RegisterEvent("PLAYER_LOGIN")
reg:SetScript("OnEvent", register)

Minimap_._test = { launcher = launcher, registered = function() return registered end }
