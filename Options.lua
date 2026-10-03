-- Options.lua: the settings (#8). One list of what can be set, one place that
-- checks, saves and applies a change (Options.Set), and ONE place to set them:
-- a page in the game's Options > AddOns > Gnomesweeper (Retail's Settings
-- framework, as GlassUnitFrames' Options.lua does on Forever). The title bar's
-- gear and /gsweep settings open it. (The owner's call: more settings are coming,
-- guild scores among them, and a panel inside the window would outgrow it.)
-- The page re-reads the values every time it shows and after every change.
--
-- Blizzard's Settings window is in the HIGH strata and ours in FULLSCREEN_DIALOG,
-- above it: while the Settings window is open, ours steps aside (hidden, so its
-- clock pauses), and comes back when it closes.
--
-- Question marks and the first-click rule are part of a board, so they apply
-- from the next game; a game not touched yet (no tile revealed, nothing marked)
-- is replaced at once, so nothing is lost and the change shows straight away.
--
-- More settings join the list with their issues: sounds (#9), music (#22),
-- models (#21), hiding in combat (#37). An item with get/set keeps its value
-- somewhere else than GnomesweeperDB[key], or applies it itself (the scale, the
-- minimap button in LibDBIcon's table); the rest are GnomesweeperDB[key].

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local GS = Gnomesweeper
local Options = {}
GS.Options = Options

local Layout = GS.Layout

local function db() return GnomesweeperDB end

Options.ITEMS = {
    { key = "questionMarks", kind = "toggle", label = "Question marks",
      note = "Right-click: flag, then ?, then clear.", nextGame = true },
    { key = "safeZone", kind = "choice", label = "First click",
      choices = { { "area", "Opens an area" }, { "cell", "One safe tile" } },
      note = "One safe tile is Windows XP's rule. Each rule keeps its own best times.", nextGame = true },
    { key = "chordOnLeft", kind = "toggle", label = "Clear with left-click",
      note = "Left-click a number whose flags match." },
    { key = "sounds", kind = "toggle", label = "Sounds",
      note = "Clicks, flags, the bomb and the cheers. The game's own sound settings apply too." },
    { key = "music", kind = "toggle", label = "Gnomeregan music",
      note = "While the board is open; never in combat. Also the note in the title bar." },
    { key = "hideInCombat", kind = "toggle", label = "Hide in combat",
      note = "A fight puts the window away, paused; it comes back when the fight ends." },
    { key = "fireworks", kind = "toggle", label = "Fireworks",
      note = "Over the board when you beat your best time." },
    { key = "scale", kind = "scale", label = "Window size",
      get = function() return db().scale or 1 end,
      set = function(v)
          if math.abs(v - 1) < 0.001 then v = nil end    -- 100% is no saved scale at all
          GS.Window.SetScale(v)
      end },
    { key = "minimapButton", kind = "toggle", label = "Minimap button",
      note = "Left-click opens or closes the board, right-click opens these settings. Drag it around the minimap.",
      get = function() return GS.Minimap.Shown() end,
      set = function(v) GS.Minimap.SetShown(v) end },
}
local BY_KEY = {}
for _, item in ipairs(Options.ITEMS) do BY_KEY[item.key] = item end

Options.SCALE_STEP = 0.1

------------------------------------------------------------
-- The one place a setting changes
------------------------------------------------------------

function Options.Get(key)
    local item = BY_KEY[key]
    if item and item.get then return item.get() end
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
    if item.set then
        item.set(v)
    else
        db()[key] = v
        local game = W.game
        if item.nextGame and game and untouched(game) then W.NewGame() end
        W.SettingsChanged()
    end
    Options.Refresh()
    return true
end

-- The scale one step up or down to the next point on the step grid, within the
-- limits: from 127%, up is 130% and down is 120% (never a whole step skipped).
function Options.StepScale(dir)
    local n = Options.Get("scale") / Options.SCALE_STEP
    n = dir > 0 and math.floor(n + 1e-6) + 1 or math.ceil(n - 1e-6) - 1
    local v = n * Options.SCALE_STEP
    v = math.max(Layout.USER_SCALE_MIN, math.min(Layout.USER_SCALE_MAX, v))
    return Options.Set("scale", math.floor(v * 100 + 0.5) / 100)
end

local function percent(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end

-- "Shown at 90% so it fits the screen.", or nil when the window shows as asked.
local function fitNote()
    if not GS.Window.win then return nil end           -- never build the window just to say this
    local want, shown = GS.Window.ScaleInfo()
    if math.abs(want - shown) > 0.005 then return "Shown at " .. percent(shown) .. " so it fits the screen." end
    return nil
end

------------------------------------------------------------
-- Options > AddOns > Gnomesweeper (Blizzard's look, Blizzard's templates)
------------------------------------------------------------

-- Hidden from the start (GlassRaidFrames' Click-casting page does the same): a
-- frame is created SHOWN, so the first time Settings displays it no OnShow would
-- fire, nothing would be built, and the page would be blank until the second
-- visit (seen on the About page, 70205).
local page = CreateFrame("Frame")
page.name = "Gnomesweeper"
page:Hide()
local category

local CHECK_ART = {
    normal = "Interface\\Buttons\\UI-CheckBox-Up", pushed = "Interface\\Buttons\\UI-CheckBox-Down",
    highlight = "Interface\\Buttons\\UI-CheckBox-Highlight", checked = "Interface\\Buttons\\UI-CheckBox-Check",
}
local RADIO_ART = "Interface\\Buttons\\UI-RadioButton"   -- 4 cells: normal, checked, highlight, pushed

local function label(parent, text, template, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    fs:SetJustifyH("LEFT")
    if width then fs:SetWidth(width) end
    fs:SetText(text)
    return fs
end
local function pageLabel(text, template) return label(page, text, template) end

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
    local sub = pageLabel(GS.TAGLINE .. "  /gsweep opens the board; the gear in its title bar opens this page.",
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
                rb:SetScript("OnClick", function() Options.Set(item.key, choice[1]) end)
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

    -- Reset the best times (owner). Two clicks: the first only arms it for a few
    -- seconds (no popup: none has been measured on Forever, and two clicks guard
    -- as well).
    y = y - 6
    local reset = pageButton(Options.RESET_LABEL, 190, function(self) Options.ResetClick(self) end)
    reset:SetPoint("TOPLEFT", page, "TOPLEFT", 16, y)
    page.reset = reset
    local note = pageLabel("Every difficulty's best time and games won, for both first-click rules.", "GameFontHighlightSmall")
    note:SetPoint("LEFT", reset, "RIGHT", 10, 0)
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

------------------------------------------------------------
-- Options > AddOns > Gnomesweeper > About: a sub-page, as GlassRaidFrames'
-- Click-casting is under its page. More sub-pages (guild scores) go the same way.
------------------------------------------------------------

local about = CreateFrame("Frame")
about.name = "About"
about:Hide()                -- see `page`: or its first show is blank

local function aboutLabel(text, template, width) return label(about, text, template, width) end

Options.LINKS = {
    { "CurseForge", "https://www.curseforge.com/wow/addons/gnomesweeper" },
    { "GitHub", "https://github.com/Spotnick2/Gnomesweeper" },
}

-- A link the player can copy: addons can't open a browser or touch the
-- clipboard, so it is a read-only edit box that selects itself on a click, for
-- Ctrl+C (GlassPanel's Share window does the same). Typing puts the link back.
local function linkBox(url)
    local box = CreateFrame("EditBox", nil, about)
    box:SetSize(400, 22)
    box:SetAutoFocus(false)
    box:SetFontObject("ChatFontNormal")
    box:SetTextInsets(6, 6, 0, 0)
    box.bg = box:CreateTexture(nil, "BACKGROUND")
    box.bg:SetAllPoints(box)
    box.bg:SetColorTexture(0, 0, 0, 0.5)
    box.url = url
    box:SetText(url)
    box:SetCursorPosition(0)
    box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    box:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
    box:SetScript("OnMouseUp", function(self) self:HighlightText() end)
    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(self.url)
            self:HighlightText()
        end
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return box
end

local function buildAbout()
    local y = -16
    local function add(fs, height, indent)
        fs:SetPoint("TOPLEFT", about, "TOPLEFT", 16 + (indent or 0), y)
        y = y - height
        return fs
    end
    about.title = add(aboutLabel("Gnomesweeper", "GameFontNormalHuge"), 30)
    about.tagline = add(aboutLabel(GS.TAGLINE, "GameFontHighlightLarge"), 26, 2)
    about.version = add(aboutLabel("Version " .. GS.API.AddOnVersion(ADDON) .. "  " .. "\194\183" .. "  for World of Warcraft: Forever  " .. "\194\183" .. "  by Spotnick",
        "GameFontHighlightSmall"), 30, 2)

    add(aboutLabel("How to play", "GameFontNormalLarge"), 24)
    for _, line in ipairs({
        "Left-click reveals a tile. Right-click flags it. Clear every tile that isn't a mine.",
        "A number says how many mines touch it. Middle-click a number (or hold left and right) to reveal",
        "the tiles around it, once its flags match. A wrong flag reveals a mine.",
        "The first click is always safe. The rules are Windows XP Minesweeper's.",
    }) do add(aboutLabel(line, nil, 620), 18, 4) end

    y = y - 10
    add(aboutLabel("Links", "GameFontNormalLarge"), 24)
    about.links = {}
    for _, link in ipairs(Options.LINKS) do
        local name = aboutLabel(link[1], nil, 90)
        name:SetPoint("TOPLEFT", about, "TOPLEFT", 20, y - 4)
        local box = linkBox(link[2])
        box:SetPoint("TOPLEFT", about, "TOPLEFT", 110, y)
        about.links[#about.links + 1] = box
        y = y - 26
    end
    add(aboutLabel("Click a link, then Ctrl+C to copy it.", "GameFontHighlightSmall"), 22, 4)

    y = y - 6
    add(aboutLabel("Commands", "GameFontNormalLarge"), 24)
    about.commands = {}
    for _, line in ipairs(GS.HELP or {}) do
        if not line:find("(for measuring)", 1, true) then
            about.commands[#about.commands + 1] = add(aboutLabel(line, "GameFontHighlightSmall", 620), 16, 4)
        end
    end
end

about:SetScript("OnShow", function(self)
    if not self.built then
        self.built = true
        buildAbout()
    end
end)

-- While Blizzard's Settings window is open, ours steps aside (it would draw over
-- it), and comes back when it closes, if it was open.
local steppedAside       -- Window.shownCount when it stepped aside, or nil
local function watchSettingsWindow()
    local sp = rawget(_G, "SettingsPanel")
    if not (sp and sp.HookScript) then return end
    sp:HookScript("OnShow", function()
        if GS.Window.IsShown() then
            GS.Window.win:Hide()
            steppedAside = GS.Window.shownCount
        end
    end)
    sp:HookScript("OnHide", function()
        -- Shown again meanwhile (and maybe closed again): the player decided; leave it.
        local back = steppedAside == GS.Window.shownCount
        steppedAside = nil
        if back then GS.Window.Open() end
    end)
end

------------------------------------------------------------
-- Resetting the best times: arm, then confirm
------------------------------------------------------------

Options.RESET_LABEL = "Reset best times..."
Options.RESET_ARMED = "Click again to reset"
Options.RESET_WINDOW = 5     -- seconds the second click has

local armed = 0              -- bumped to disarm a pending confirmation

function Options.ResetClick(button)
    if button.armed then
        button.armed = false
        armed = armed + 1
        button:SetText(Options.RESET_LABEL)
        GS.Scores.Reset(GnomesweeperDB)
        GS.Window.ScoresReset()
        GS.Print("best times reset.")
        return
    end
    button.armed = true
    button:SetText(Options.RESET_ARMED)
    armed = armed + 1
    local mine = armed
    C_Timer.After(Options.RESET_WINDOW, function()
        if mine == armed then
            button.armed = false
            button:SetText(Options.RESET_LABEL)
        end
    end)
end

local function register()
    if category or not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    category = Settings.RegisterCanvasLayoutCategory(page, page.name)
    Settings.RegisterAddOnCategory(category)
    -- The sub-pages, under this one: registered here, in order (GlassRaidFrames' way).
    if Settings.RegisterCanvasLayoutSubcategory then
        pcall(Settings.RegisterCanvasLayoutSubcategory, category, about, about.name)
    end
    watchSettingsWindow()
end

-- Open the Options > AddOns page; false when the Settings framework can't.
function Options.OpenPage()
    if not (category and Settings and Settings.OpenToCategory) then return false end
    return pcall(Settings.OpenToCategory, category:GetID()) and true or false
end

-- The gear and /gsweep settings: open the page, or say where it is.
function Options.Open()
    if Options.OpenPage() then return true end
    GS.Print("the settings are in the game's Options > AddOns > Gnomesweeper.")
    return false
end

local reg = CreateFrame("Frame")
reg:RegisterEvent("PLAYER_LOGIN")
reg:SetScript("OnEvent", register)

Options._test = {
    page = page,
    about = about,
    category = function() return category end,
}
