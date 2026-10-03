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

local function db()
    if type(GnomesweeperDB.minimap) ~= "table" then GnomesweeperDB.minimap = {} end
    return GnomesweeperDB.minimap
end

function Minimap_.Shown() return not db().hide end

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
        tip:AddLine("Left-click: play", 0.75, 0.78, 0.85)
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
    icon:Register(NAME, ldb:NewDataObject(NAME, launcher), db())
    registered = true
end

local reg = CreateFrame("Frame")
reg:RegisterEvent("PLAYER_LOGIN")
reg:SetScript("OnEvent", register)

Minimap_._test = { launcher = launcher, registered = function() return registered end }
