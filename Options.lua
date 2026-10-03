-- Options.lua: the settings (#8). One list of what can be set, one place that
-- checks, saves and applies a change (Options.Set), and two views on it: the
-- glass panel behind the title bar's gear (in the window) and a page in the
-- game's Options > AddOns (Retail's Settings framework, as GlassUnitFrames'
-- Options.lua does on Forever). Both views re-read the values every time they
-- show, and after every change, so neither can show a stale one.
--
-- Question marks and the first-click rule are part of a board, so they apply
-- from the next game; a game not touched yet (no tile revealed, nothing marked)
-- is replaced at once, so nothing is lost and the change shows straight away.
--
-- More settings join the list with their issues: sounds (#9), music (#22),
-- models (#21), hiding in combat (#37).

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local GS = Gnomesweeper
local Options = {}
GS.Options = Options

local Glass, Skin, Widgets, Layout = GS.Glass, GS.Skin, GS.Widgets, GS.Layout
local C, T = Skin.COLORS, Skin.TEXTURES

local function db() return GnomesweeperDB end

Options.ITEMS = {
    { key = "questionMarks", kind = "toggle", label = "Question marks",
      note = "Right-click: flag, then ?, then clear.", nextGame = true },
    { key = "safeZone", kind = "choice", label = "First click",
      choices = { { "area", "Opens an area" }, { "cell", "One safe tile" } },
      note = "One safe tile is Windows XP's rule. Each rule keeps its own best times.", nextGame = true },
    { key = "chordOnLeft", kind = "toggle", label = "Clear with left-click",
      note = "Left-click a number whose flags match." },
    { key = "scale", kind = "scale", label = "Window size" },
}
local BY_KEY = {}
for _, item in ipairs(Options.ITEMS) do BY_KEY[item.key] = item end

Options.SCALE_STEP = 0.1

------------------------------------------------------------
-- The one place a setting changes
------------------------------------------------------------

function Options.Get(key)
    if key == "scale" then return db().scale or 1 end
    return db()[key]
end

local function valid(item, v)
    if item.kind == "toggle" then return type(v) == "boolean" end
    if item.kind == "choice" then
        for _, c in ipairs(item.choices) do if c[1] == v then return true end end
        return false
    end
    if item.kind == "scale" then return Layout.ValidUserScale(v) end
    return false
end

local views = {}     -- refresh functions of the built views

-- A board nobody has touched: every tile still covered, so not started (a game
-- starts with a reveal) and no flag or ? on it either (marks can be placed before
-- the first reveal; replacing the board would throw them away).
local function untouched(game)
    for i = 1, game.total do
        if game:Cell(i).state ~= "covered" then return false end
    end
    return true
end

function Options.Refresh()
    for _, fn in ipairs(views) do fn() end
end

-- Checks, saves and applies one setting. False (and nothing changed) when the
-- value isn't one it can take.
function Options.Set(key, v)
    local item = BY_KEY[key]
    if not (item and valid(item, v)) then return false end
    if v == Options.Get(key) then Options.Refresh(); return true end      -- nothing to change, nothing to replace
    local W = GS.Window
    if item.kind == "scale" then
        if math.abs(v - 1) < 0.001 then v = nil end        -- 100% is no saved scale at all
        W.SetScale(v)
    else
        db()[key] = v
        local game = W.game
        if item.nextGame and game and untouched(game) then W.NewGame() end
        W.SettingsChanged()
    end
    Options.Refresh()
    return true
end

-- The scale one step up or down, on the step grid, within the limits.
function Options.StepScale(dir)
    local v = math.floor(Options.Get("scale") / Options.SCALE_STEP + 0.5) * Options.SCALE_STEP + dir * Options.SCALE_STEP
    v = math.max(Layout.USER_SCALE_MIN, math.min(Layout.USER_SCALE_MAX, v))
    return Options.Set("scale", math.floor(v * 100 + 0.5) / 100)
end

local function percent(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end

-- "Shown at 90% so it fits the screen.", or nil when the window shows as asked.
local function fitNote()
    local want, shown = GS.Window.ScaleInfo()
    if math.abs(want - shown) > 0.005 then return "Shown at " .. percent(shown) .. " so it fits the screen." end
    return nil
end

------------------------------------------------------------
-- The glass panel (the gear)
------------------------------------------------------------

local PANEL_W = 264
local panel

local function switch(parent, onClick)
    local b = Widgets.GlassButton(parent, 54, 20, { fontSize = 11 })
    b:SetScript("OnClick", onClick)
    function b.setOn(self, on)
        self.on = on
        self.label:SetText(on and "On" or "Off")
        local col = on and Skin.RARITY.uncommon or C.hint
        self:setAccent(col[1], col[2], col[3])
        self.label:SetTextColor(col[1], col[2], col[3])
    end
    return b
end

local function buildPanel()
    local win = GS.Window.win
    local p = Widgets.GlassPanel(win)
    p:SetFrameLevel(win:GetFrameLevel() + 30)            -- with the list and the best times
    p:SetPoint("TOP", GS.Window.hud, "TOP", 0, 0)
    p:EnableMouse(true)                                   -- the board under it takes no clicks

    p.title = Glass.Font(p, 16, "LEFT")
    p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -14)
    p.title:SetTextColor(unpack(C.gold))
    p.title:SetText("Settings")
    p.close = Widgets.IconButton(p, 20, T.close, { 1, 0.9, 0.9 })
    p.close:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, -8)
    p.close:setAccent(unpack(C.closeAccent))
    p.close:SetScript("OnClick", function() p:Hide() end)

    local y = -44
    local function text(size, color, s)
        local fs = Glass.Font(p, size, "LEFT")
        fs:SetTextColor(unpack(color))
        fs:SetText(s)
        return fs
    end
    p.controls = {}
    local refreshers = {}
    for _, item in ipairs(Options.ITEMS) do
        local c = {}
        c.label = text(13, C.menuText, item.label)
        c.label:SetPoint("TOPLEFT", p, "TOPLEFT", 14, y)
        if item.kind == "toggle" then
            c.switch = switch(p, function() Options.Set(item.key, not Options.Get(item.key)) end)
            c.switch:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, y + 2)
            refreshers[#refreshers + 1] = function() c.switch:setOn(Options.Get(item.key) and true or false) end
            y = y - 20
        elseif item.kind == "choice" then
            c.buttons = {}
            for i, choice in ipairs(item.choices) do
                local b = Widgets.GlassButton(p, 114, 22, { fontSize = 11 })
                b:SetPoint("TOPLEFT", p, "TOPLEFT", 14 + (i - 1) * 122, y - 20)
                b.label:SetText(choice[2])
                b.value = choice[1]
                b:SetScript("OnClick", function() Options.Set(item.key, choice[1]) end)
                c.buttons[i] = b
            end
            refreshers[#refreshers + 1] = function()
                local current = Options.Get(item.key)
                for _, b in ipairs(c.buttons) do
                    local on = b.value == current
                    local col = on and C.gold or C.accent
                    b:setAccent(col[1], col[2], col[3])
                    b.label:SetTextColor(unpack(on and C.gold or C.hint))
                    b.selected = on
                end
            end
            y = y - 46
        elseif item.kind == "scale" then
            c.minus = Widgets.GlassButton(p, 22, 20, { square = true })
            c.minus.label:SetText("-")
            c.minus:SetScript("OnClick", function() Options.StepScale(-1) end)
            c.plus = Widgets.GlassButton(p, 22, 20, { square = true })
            c.plus.label:SetText("+")
            c.plus:SetScript("OnClick", function() Options.StepScale(1) end)
            c.plus:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, y + 2)
            c.value = text(13, C.menuText, "")
            c.value:SetJustifyH("CENTER")
            c.value:SetWidth(44)
            c.value:SetPoint("RIGHT", c.plus, "LEFT", -4, 0)
            c.minus:SetPoint("RIGHT", c.value, "LEFT", -4, 0)
            refreshers[#refreshers + 1] = function() c.value:SetText(percent(Options.Get("scale"))) end
            y = y - 20
        end
        c.note = text(11, C.hint, "")
        c.note:SetPoint("TOPLEFT", p, "TOPLEFT", 14, y - 2)
        c.note:SetWidth(PANEL_W - 28)
        local key = item.key
        refreshers[#refreshers + 1] = function()
            local note = item.note
            if key == "scale" then note = fitNote() end
            c.note:SetText(note or "")
        end
        y = y - 26
        p.controls[key] = c
    end
    p.footer = text(10, C.hint, "Also in the game's Options > AddOns > Gnomesweeper.")
    p.footer:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 14, 10)
    p:SetSize(PANEL_W, -y + 26)

    views[#views + 1] = function()
        if not p:IsShown() then return end
        for _, fn in ipairs(refreshers) do fn() end
    end
    p:SetScript("OnShow", function() Options.Refresh() end)
    GS.Window.Floating(p)
    p:Hide()
    panel = p
    return p
end

-- Show (or, with no argument, toggle) the glass settings panel. Opens the window.
function Options.ShowPanel(show)
    GS.Window.Open()
    if not panel then buildPanel() end
    if show == nil then show = not panel:IsShown() end
    panel:SetShown(show)
end

------------------------------------------------------------
-- Options > AddOns > Gnomesweeper (Blizzard's look, Blizzard's templates)
------------------------------------------------------------

local page = CreateFrame("Frame", "GnomesweeperOptions")
page.name = "Gnomesweeper"
local category

local CHECK_ART = {
    normal = "Interface\\Buttons\\UI-CheckBox-Up", pushed = "Interface\\Buttons\\UI-CheckBox-Down",
    highlight = "Interface\\Buttons\\UI-CheckBox-Highlight", checked = "Interface\\Buttons\\UI-CheckBox-Check",
}
local RADIO_ART = "Interface\\Buttons\\UI-RadioButton"   -- 4 cells: normal, checked, highlight, pushed

local function pageLabel(text, template)
    local fs = page:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

-- A check or radio button from the client's template, or our own from its art
-- when the template is missing (a missing template returns a bare frame).
local function checkButton(radio)
    local cb, templated = GS.API.SafeFrame("CheckButton", page, radio and "UIRadioButtonTemplate" or "UICheckButtonTemplate", "text")
    if not templated then
        if radio then
            cb:SetSize(16, 16)
            cb:SetNormalTexture(RADIO_ART)
            cb:GetNormalTexture():SetTexCoord(0, 0.25, 0, 1)
            cb:SetCheckedTexture(RADIO_ART)
            cb:GetCheckedTexture():SetTexCoord(0.25, 0.5, 0, 1)
            cb:SetHighlightTexture(RADIO_ART)
            cb:GetHighlightTexture():SetTexCoord(0.5, 0.75, 0, 1)
        else
            cb:SetNormalTexture(CHECK_ART.normal)
            cb:SetPushedTexture(CHECK_ART.pushed)
            cb:SetHighlightTexture(CHECK_ART.highlight)
            cb:SetCheckedTexture(CHECK_ART.checked)
        end
    end
    if not radio then cb:SetSize(24, 24) end
    return cb
end

local function pageButton(text, width, onClick)
    local b, templated = GS.API.SafeFrame("Button", page, "UIPanelButtonTemplate", "Text")
    b:SetSize(width, 22)
    if not templated then
        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(b)
        bg:SetColorTexture(0.2, 0.2, 0.25, 0.9)
        b:SetNormalFontObject("GameFontHighlight")
    end
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function buildPage()
    local title = pageLabel("Gnomesweeper", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -16)
    local sub = pageLabel(GS.TAGLINE .. "  /gsweep opens the board; the gear in its title bar has these settings too.",
        "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 2, -6)

    local y = -72
    local refreshers = {}
    page.controls = {}
    for _, item in ipairs(Options.ITEMS) do
        local c = {}
        if item.kind == "toggle" then
            c.check = checkButton(false)
            c.check:SetPoint("TOPLEFT", page, "TOPLEFT", 16, y)
            c.check:SetScript("OnClick", function(self) Options.Set(item.key, self:GetChecked() and true or false) end)
            c.label = pageLabel(item.label)
            c.label:SetPoint("LEFT", c.check, "RIGHT", 4, 0)
            refreshers[#refreshers + 1] = function() c.check:SetChecked(Options.Get(item.key) and true or false) end
            y = y - 26
        elseif item.kind == "choice" then
            c.label = pageLabel(item.label)
            c.label:SetPoint("TOPLEFT", page, "TOPLEFT", 20, y)
            y = y - 22
            c.radios = {}
            for i, choice in ipairs(item.choices) do
                local rb = checkButton(true)
                rb:SetPoint("TOPLEFT", page, "TOPLEFT", 28, y)
                rb.value = choice[1]
                -- Re-sync the group either way: a refused choice snaps back.
                rb:SetScript("OnClick", function() Options.Set(item.key, choice[1]); Options.Refresh() end)
                local fs = pageLabel(choice[2])
                fs:SetPoint("LEFT", rb, "RIGHT", 4, 0)
                c.radios[i] = rb
                y = y - 22
            end
            refreshers[#refreshers + 1] = function()
                local current = Options.Get(item.key)
                for _, rb in ipairs(c.radios) do rb:SetChecked(rb.value == current) end
            end
        elseif item.kind == "scale" then
            c.label = pageLabel(item.label)
            c.label:SetPoint("TOPLEFT", page, "TOPLEFT", 20, y)
            c.minus = pageButton("-", 26, function() Options.StepScale(-1) end)
            c.minus:SetPoint("LEFT", c.label, "LEFT", 110, 0)
            c.value = pageLabel("")
            c.value:SetWidth(48)
            c.value:SetJustifyH("CENTER")
            c.value:SetPoint("LEFT", c.minus, "RIGHT", 4, 0)
            c.plus = pageButton("+", 26, function() Options.StepScale(1) end)
            c.plus:SetPoint("LEFT", c.value, "RIGHT", 4, 0)
            refreshers[#refreshers + 1] = function() c.value:SetText(percent(Options.Get("scale"))) end
            y = y - 28
        end
        c.note = pageLabel("", "GameFontHighlightSmall")
        c.note:SetPoint("TOPLEFT", page, "TOPLEFT", 48, y + 4)
        c.note:SetWidth(520)
        refreshers[#refreshers + 1] = function()
            local note = item.note
            if item.key == "scale" then note = fitNote() end
            c.note:SetText(note or "")
        end
        y = y - 26
        page.controls[item.key] = c
    end
    views[#views + 1] = function()
        if not page:IsShown() then return end
        for _, fn in ipairs(refreshers) do fn() end
    end
end

page:SetScript("OnShow", function(self)
    if not self.built then
        self.built = true
        buildPage()
    end
    Options.Refresh()
end)

local function register()
    if category or not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    category = Settings.RegisterCanvasLayoutCategory(page, page.name)
    Settings.RegisterAddOnCategory(category)
end

-- Open the Options > AddOns page; false when the Settings framework can't.
function Options.OpenPage()
    if not (category and Settings and Settings.OpenToCategory) then return false end
    return pcall(Settings.OpenToCategory, category:GetID()) and true or false
end

local reg = CreateFrame("Frame")
reg:RegisterEvent("PLAYER_LOGIN")
reg:SetScript("OnEvent", register)

Options._test = {
    panel = function() return panel end,
    page = page,
    category = function() return category end,
}
