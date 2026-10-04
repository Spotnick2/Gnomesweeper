-- Toast.lua: the guild-best card (#17, docs/SOCIAL.md). A small glass panel near the
-- top of the screen, on UIParent (the board open or not), with the mascot's face and a
-- line of text; a click puts it away. Built the first time it's needed. Social.lua
-- decides when one shows (the rules, the queue, combat); this only draws one.
--
--   Toast.Show(text, onDone)   shows it for Toast.SHOW seconds; onDone() when it goes
--   Toast.Hide()               puts it away now (combat starting), without onDone
--   Toast.IsShown()

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local GS = Gnomesweeper
local Toast = {}
GS.Toast = Toast

local Skin, Glass, Widgets = GS.Skin, GS.Glass, GS.Widgets
local T, C = Skin.TEXTURES, Skin.COLORS

Toast.SHOW = 6                -- seconds on screen
Toast.W, Toast.H = 320, 58
Toast.TOP = -110              -- below the top of the screen, clear of the minimap and buffs' row

local card, token = nil, 0    -- token: a new show (or a hide) cancels the last one's timer

local function build()
    card = Widgets.GlassPanel(UIParent)
    card:SetFrameStrata("DIALOG")
    card:SetSize(Toast.W, Toast.H)
    card:SetPoint("TOP", UIParent, "TOP", 0, Toast.TOP)
    card:EnableMouse(true)
    card.border:SetVertexColor(unpack(C.gold))
    card.face = card:CreateTexture(nil, "ARTWORK")
    card.face:SetSize(42, 42)
    card.face:SetPoint("LEFT", card, "LEFT", 9, 0)
    card.face:SetTexture(T.faceWon)
    card.text = Glass.Font(card, 12, "LEFT")
    card.text:SetPoint("LEFT", card.face, "RIGHT", 10, 0)
    card.text:SetWidth(Toast.W - 42 - 9 - 10 - 12)
    card.text:SetWordWrap(true)
    card.text:SetTextColor(unpack(C.menuText))
    card:SetScript("OnMouseUp", function()
        local done = card.onDone
        Toast.Hide()
        if done then done() end
    end)
    card:Hide()
end

function Toast.Show(text, onDone)
    if not card then build() end
    token = token + 1
    local mine = token
    card.text:SetText(text)
    card.onDone = onDone
    card:Show()
    C_Timer.After(Toast.SHOW, function()
        if token ~= mine then return end
        card:Hide()
        card.onDone = nil
        if onDone then onDone() end
    end)
end

function Toast.Hide()
    token = token + 1
    if card then
        card:Hide()
        card.onDone = nil
    end
end

function Toast.IsShown() return card ~= nil and card:IsShown() end

Toast._test = { card = function() return card end }
