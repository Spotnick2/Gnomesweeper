-- Window.lua: the glass window. Title bar, difficulty, the HUD (mines left,
-- the face, the clock), the board area, the hint lines. It owns the current
-- game (Window.game, a Board) and is the only thing that creates or replaces
-- one. Grid.lua draws the tiles INTO Window.grid; every click comes back here
-- through Window.Dispatch, the one place an action is carried out. The
-- overlays (#5) hang off Window.win.
--
-- Nothing here is secure and nothing is parented to a protected frame, so the
-- window works in combat.
--
-- Geometry is Layout.lua's (pure, tested); this file only applies it.

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local GS = Gnomesweeper
local Window = {}
GS.Window = Window

local Board, Layout, Glass, Skin, Grid = GS.Board, GS.Layout, GS.Glass, GS.Skin, GS.Grid
local PAD = Layout.PAD

local LABELS = { beginner = "Beginner", intermediate = "Intermediate", expert = "Expert" }
local WIN_NAME = "GnomesweeperWindow"

local win, game
local ui = {}       -- the widgets Refresh and the layout touch

local function db() return GnomesweeperDB end

local function difficultyKey()
    local d = db().difficulty
    return Board.PRESETS[d] and d or "beginner"
end

------------------------------------------------------------
-- The game
------------------------------------------------------------

local function newBoard()
    local p = Board.PRESETS[difficultyKey()]
    game = assert(Board.New(p.w, p.h, p.mines, {
        safeZone = db().safeZone,
        questionMarks = db().questionMarks,
    }))
    Window.game = game
end

------------------------------------------------------------
-- Small widgets
------------------------------------------------------------

local function tip(widget, title, line)
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(title)
        if line then GameTooltip:AddLine(line, 0.7, 0.7, 0.7, true) end
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- A flat translucent blue button with a hover glow and a centred label: the
-- storyboard's buttons, without a template's red and gold.
local function flatButton(parent, width, height)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    b.bg:SetColorTexture(unpack(Skin.COLORS.button))
    b.hover = b:CreateTexture(nil, "HIGHLIGHT")
    b.hover:SetAllPoints(b)
    b.hover:SetColorTexture(unpack(Skin.COLORS.buttonHover))
    b.hover:SetBlendMode("ADD")
    b.label = Glass.Font(b, 12, "CENTER")
    b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
    return b
end

local function icon(parent, texture, size)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(size, size)
    t:SetTexture(texture)
    t:SetTexCoord(unpack(Skin.ICON_CROP))
    return t
end

------------------------------------------------------------
-- Refresh: the HUD from the game
------------------------------------------------------------

local function timerText()
    return Layout.FormatTime(Board.DisplaySeconds(game:Elapsed(GetTime())))
end

local acc = 0
local function onUpdate(_, dt)
    acc = acc + dt
    if acc < 0.1 then return end
    acc = 0
    local text = timerText()
    if text ~= ui.timer:GetText() then ui.timer:SetText(text) end
end

-- The clock text only needs driving while a game is in progress and the window
-- is shown; at any other time there is no OnUpdate at all.
local function setTicking(on)
    acc = 0
    win:SetScript("OnUpdate", on and onUpdate or nil)
end

function Window.Refresh()
    if not (win and game) then return end
    ui.counter:SetText(tostring(game:FlagsLeft()))
    ui.timer:SetText(timerText())
    ui.hintStart:SetShown(game:State() == "ready")
    ui.diff.label:SetText(LABELS[difficultyKey()])
    setTicking(game:State() == "playing")
end

------------------------------------------------------------
-- Size, scale, position
------------------------------------------------------------

local function applyPosition()
    local s = win:GetScale()
    local size = Window.size
    win:ClearAllPoints()
    local p = db().pos
    if Layout.ValidPos(p) then
        local left, top = Layout.ClampPos(p.left, p.top, size.width * s, size.height * s,
            UIParent:GetWidth(), UIParent:GetHeight())
        win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / s, top / s)
    else
        win:SetPoint("CENTER", UIParent, "CENTER", 0, 40 / s)
    end
end

-- Fit the window to the current board and screen. Called whenever either
-- changes: a new game at another difficulty, the window being shown, and a
-- resolution or UI-scale change.
function Window.Layout()
    if not (win and game) then return end
    local size = Layout.Size(game.w, game.h)
    local scale = Layout.FitScale(size.width, size.height, UIParent:GetWidth(), UIParent:GetHeight(), db().scale)
    Window.size, Window.scale = size, scale
    win:SetScale(scale)
    win:SetSize(size.width, size.height)
    ui.grid:SetSize(size.gridW, size.gridH)
    ui.grid:ClearAllPoints()
    ui.grid:SetPoint("TOPLEFT", win, "TOPLEFT", size.gridX, -size.gridY)
    applyPosition()
end

-- Saved as the top-left corner in UIParent units: GetLeft/GetTop answer in the
-- window's own space, so they're multiplied by its scale (porting guide).
local function savePosition()
    local left, top = win:GetLeft(), win:GetTop()
    if not (left and top) then return end
    local s = win:GetScale()
    db().pos = { left = left * s, top = top * s }
end

function Window.ResetPosition()
    db().pos = nil
    if win then applyPosition() end
end

------------------------------------------------------------
-- Building it
------------------------------------------------------------

local function pickDifficulty(key)
    ui.menu:Hide()
    if key ~= difficultyKey() then Window.NewGame(key) end
end

local function buildMenu()
    local menu = CreateFrame("Frame", nil, win)
    menu:SetFrameLevel(win:GetFrameLevel() + 20)      -- above the glass rim (+10)
    menu:SetSize(ui.diff:GetWidth(), #Board.PRESET_ORDER * 22 + 4)
    menu:SetPoint("TOPLEFT", ui.diff, "BOTTOMLEFT", 0, -2)
    menu:EnableMouse(true)
    menu.bg = menu:CreateTexture(nil, "BACKGROUND")
    menu.bg:SetAllPoints(menu)
    menu.bg:SetColorTexture(unpack(Skin.COLORS.menuBg))
    for i, key in ipairs(Board.PRESET_ORDER) do
        local entry = flatButton(menu, ui.diff:GetWidth() - 4, 22)
        entry:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2 - (i - 1) * 22)
        entry.label:SetText(LABELS[key])
        entry:SetScript("OnClick", function() pickDifficulty(key) end)
    end
    -- Closes on a click anywhere else. Polled while it is open (an OnUpdate
    -- that exists only then) rather than relying on a global mouse event.
    menu:SetScript("OnShow", function(self)
        self:SetScript("OnUpdate", function()
            if IsMouseButtonDown("LeftButton") and not (self:IsMouseOver() or ui.diff:IsMouseOver()) then
                self:Hide()
            end
        end)
    end)
    menu:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
    menu:Hide()
    ui.menu = menu
end

local function build()
    win = CreateFrame("Frame", WIN_NAME, UIParent)
    Window.win = win
    win:SetFrameStrata("FULLSCREEN_DIALOG")
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:Hide()
    local escapable = false
    for _, name in ipairs(UISpecialFrames) do if name == WIN_NAME then escapable = true end end
    if not escapable then table.insert(UISpecialFrames, WIN_NAME) end
    win.glass = Glass.Apply(win, "large")
    local content = Glass.ContentLevel(win)

    -- Title bar: the logo, the name, the tagline, the settings gear, close.
    local logo = icon(win, Skin.TEXTURES.logo, 44)
    logo:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, -12)
    local title = Glass.Font(win, 20, "LEFT")
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -3)
    title:SetText(Skin.TITLE)
    local tagline = Glass.Font(win, 11, "LEFT")
    tagline:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    tagline:SetTextColor(unpack(Skin.COLORS.tagline))
    tagline:SetText(GS.TAGLINE)

    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetFrameLevel(content)
    close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() win:Hide() end)

    local gear = CreateFrame("Button", nil, win)
    gear:SetFrameLevel(content)
    gear:SetSize(22, 22)
    gear:SetPoint("RIGHT", close, "LEFT", -2, 0)
    local gearTex = gear:CreateTexture(nil, "ARTWORK")
    gearTex:SetAllPoints(gear)
    gearTex:SetTexture(Skin.TEXTURES.gear)
    gear.hover = gear:CreateTexture(nil, "HIGHLIGHT")
    gear.hover:SetAllPoints(gear)
    gear.hover:SetColorTexture(unpack(Skin.COLORS.buttonHover))
    gear.hover:SetBlendMode("ADD")
    tip(gear, "Settings", "Coming soon.")           -- inert until #8
    ui.gear = gear

    -- Difficulty: a button and the small list it opens.
    local diff = flatButton(win, 130, 24)
    diff:SetFrameLevel(content)
    diff:SetPoint("TOP", win, "TOP", 0, -66)
    local arrow = diff:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(14, 14)
    arrow:SetTexture(Skin.TEXTURES.arrow)
    arrow:SetPoint("RIGHT", diff, "RIGHT", -6, 0)
    diff:SetScript("OnClick", function() ui.menu:SetShown(not ui.menu:IsShown()) end)
    ui.diff = diff
    buildMenu()

    -- The HUD strip: mines left, the face (a new game), the clock.
    local hud = CreateFrame("Frame", nil, win)
    hud:SetFrameLevel(content)
    hud:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, -98)
    hud:SetPoint("TOPRIGHT", win, "TOPRIGHT", -PAD, -98)
    hud:SetHeight(44)
    hud.bg = hud:CreateTexture(nil, "BACKGROUND")
    hud.bg:SetAllPoints(hud)
    hud.bg:SetColorTexture(unpack(Skin.COLORS.hudBg))

    local flag = icon(hud, Skin.TEXTURES.flag, 22)
    flag:SetPoint("LEFT", hud, "LEFT", 12, 0)
    ui.counter = Glass.Font(hud, 22, "LEFT")
    ui.counter:SetPoint("LEFT", flag, "RIGHT", 6, 0)

    local face = CreateFrame("Button", nil, hud)
    face:SetSize(40, 40)
    face:SetPoint("CENTER", hud, "CENTER", 0, 0)
    local faceTex = icon(face, Skin.TEXTURES.face, 40)
    faceTex:SetAllPoints(face)
    face.hover = face:CreateTexture(nil, "HIGHLIGHT")
    face.hover:SetAllPoints(face)
    face.hover:SetColorTexture(unpack(Skin.COLORS.buttonHover))
    face.hover:SetBlendMode("ADD")
    face:SetScript("OnClick", function() Window.NewGame() end)
    tip(face, "New game", "Same difficulty.")
    ui.face = face

    ui.timer = Glass.Font(hud, 22, "RIGHT")
    ui.timer:SetWidth(54)             -- "00:00" is about 47 wide; any more leaves a gap before the clock icon
    ui.timer:SetPoint("RIGHT", hud, "RIGHT", -12, 0)
    local clock = icon(hud, Skin.TEXTURES.clock, 22)
    clock:SetPoint("RIGHT", ui.timer, "LEFT", -6, 0)

    -- The board area: a dark panel the tiles sit on (Grid.lua fills it).
    local grid = CreateFrame("Frame", nil, win)
    grid:SetFrameLevel(content)
    grid.bg = grid:CreateTexture(nil, "BACKGROUND")
    grid.bg:SetAllPoints(grid)
    grid.bg:SetColorTexture(unpack(Skin.COLORS.gridBg))
    ui.grid = grid
    Window.grid = grid
    Grid.Attach(grid, function(kind, i) Window.Dispatch(kind, i) end)

    ui.hintStart = Glass.Font(win, 12, "CENTER")
    ui.hintStart:SetPoint("TOP", grid, "BOTTOM", 0, -8)
    ui.hintStart:SetTextColor(unpack(Skin.COLORS.gold))
    ui.hintStart:SetText("Choose a tile to begin.")
    local hintKeys = Glass.Font(win, 11, "CENTER")
    hintKeys:SetPoint("TOP", grid, "BOTTOM", 0, -26)
    hintKeys:SetTextColor(unpack(Skin.COLORS.hint))
    hintKeys:SetText("Left-click: Reveal     Right-click: Flag")

    -- Moving it.
    win:SetScript("OnDragStart", function(self) self:StartMoving() end)
    win:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition()
    end)

    -- The clock runs on active time: closing the window pauses the game,
    -- opening it resumes. It also refits, so a reopen after a resolution or UI
    -- scale change is never the wrong size.
    win:SetScript("OnShow", function()
        game:Resume(GetTime())
        Window.Layout()
        Window.Refresh()
    end)
    win:SetScript("OnHide", function(self)
        game:Pause(GetTime())
        ui.menu:Hide()
        Grid.Cancel()                  -- a button held when the window closes is not a click
        self:StopMovingOrSizing()
    end)

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
    watcher:RegisterEvent("UI_SCALE_CHANGED")
    watcher:SetScript("OnEvent", function() Window.Layout() end)
end

------------------------------------------------------------
-- The controller
------------------------------------------------------------

-- Carries out an action on the game: Grid.lua reports "reveal" / "mark" /
-- "chord" on tile i, the board says which cells changed, the grid repaints
-- exactly those and the HUD follows. The one place the game is acted on.
function Window.Dispatch(kind, i)
    if not game then return end
    local x, y = game:XY(i)
    if not x then return end
    -- The option: a left click on a revealed number chords it.
    if kind == "reveal" and db().chordOnLeft and game:Cell(i).state == "revealed" then kind = "chord" end
    local list
    if kind == "reveal" then
        list = game:Reveal(x, y, GetTime())
    elseif kind == "chord" then
        list = game:Chord(x, y, GetTime())
    else
        list = game:ToggleMark(x, y)
    end
    Grid.Refresh(list)
    Window.Refresh()
    local state = game:State()
    if state == "won" or state == "lost" then Grid.SetInteractive(false) end
    return list
end

------------------------------------------------------------
-- Entry points
------------------------------------------------------------

-- Fit the window and (re)build the tiles for the current game.
local function syncGame()
    Window.Layout()
    Grid.Rebuild(game)
    local state = game:State()
    if state == "won" or state == "lost" then Grid.SetInteractive(false) end
    Window.Refresh()
end

local function ensure()
    if not game then newBoard() end
    if not win then
        build()
        syncGame()
    end
end

-- A fresh game, at `preset` (remembered) or the current difficulty.
function Window.NewGame(preset)
    if preset and Board.PRESETS[preset] then db().difficulty = preset end
    newBoard()
    if win then syncGame() end
    return game
end

function Window.Open(preset)
    ensure()
    if preset and Board.PRESETS[preset] and preset ~= difficultyKey() then Window.NewGame(preset) end
    win:Show()
end

function Window.Toggle()
    ensure()
    win:SetShown(not win:IsShown())
end

function Window.IsShown() return win ~= nil and win:IsShown() end

-- /gsweep perf: times the heavy operations on a scratch Expert board, then puts
-- the real game back.
function Window.Benchmark()
    ensure()
    local lines = Grid.Benchmark()
    syncGame()
    return lines
end

Window._test = {
    ui = ui,
    menu = function() return ui.menu end,
    -- Swap in a hand-built board (Board._test.FromLayout), to test exact shapes.
    SetGame = function(b)
        game = b
        Window.game = b
        if win then syncGame() end
    end,
}
