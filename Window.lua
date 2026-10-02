-- Window.lua: the glass window. Title bar, difficulty, the HUD (mines left,
-- the mascot, the clock), the board area, the footer. It owns the current game
-- (Window.game, a Board) and is the only thing that creates or replaces one.
-- Grid.lua draws the tiles INTO Window.grid; every click comes back here through
-- Window.Dispatch, the one place an action is carried out.
--
-- Nothing here is secure and nothing is parented to a protected frame, so the
-- window works in combat.
--
-- Geometry is Layout.lua's (pure, tested); the glass controls are Widgets.lua's;
-- this file puts them together and wires them to the game.

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local GS = Gnomesweeper
local Window = {}
GS.Window = Window

local Board, Layout, Glass, Skin, Grid, Widgets = GS.Board, GS.Layout, GS.Glass, GS.Skin, GS.Grid, GS.Widgets
local PAD = Layout.PAD
local T, C = Skin.TEXTURES, Skin.COLORS

local LABELS = { beginner = "Beginner", intermediate = "Intermediate", expert = "Expert" }
local WIN_NAME = "GnomesweeperWindow"
local MULT, DOT = "\195\151", "\194\183"          -- the multiplication sign and the middle dot, as UTF-8

local win, game
local ui = { rows = {} }    -- the widgets Refresh and the layout touch

local function db() return GnomesweeperDB end

local function difficultyKey()
    local d = db().difficulty
    return Board.PRESETS[d] and d or "beginner"
end

-- "9x9 . 10 mines", from the board's own presets, never typed in twice.
local function details(key)
    local p = Board.PRESETS[key]
    return string.format("%d%s%d %s %d mines", p.w, MULT, p.h, DOT, p.mines)
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

local function over()
    local s = game:State()
    return s == "won" or s == "lost"
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
    local key = difficultyKey()
    local col = Skin.DifficultyColor(key)
    ui.counter:SetText(tostring(game:FlagsLeft()))
    ui.timer:SetText(timerText())
    ui.hintStart:SetShown(game:State() == "ready")
    ui.diff.label:SetText(LABELS[key])
    ui.diff.label:SetTextColor(col[1], col[2], col[3])
    ui.diff:setAccent(col[1], col[2], col[3])
    ui.diffArrow:SetVertexColor(col[1], col[2], col[3])
    for k, row in pairs(ui.rows) do row.selected:SetShown(k == key); row.bar:SetShown(k == key) end
    ui.face:setState(game:State())
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
    ui.hud:SetWidth(Layout.HudWidth(size.width))
    ui.grid:SetSize(size.gridW, size.gridH)
    ui.grid:ClearAllPoints()
    ui.grid:SetPoint("TOPLEFT", win, "TOPLEFT", size.gridX, -size.gridY)
    ui.result:SetWidth(size.gridW)
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
-- The difficulty list
------------------------------------------------------------

local MENU_W, ROW_H = 214, 24

local function pickDifficulty(key)
    ui.menu:Hide()
    if key ~= difficultyKey() then Window.NewGame(key) end
end

local function buildMenu()
    local menu = Widgets.GlassPanel(win)
    -- Above everything else in the window, including the result overlay (+15) and the glass rim that
    -- overlay draws at its own +10, i.e. +25: a list opened while an overlay is up must not slide under it.
    menu:SetFrameLevel(win:GetFrameLevel() + 30)
    menu:SetSize(MENU_W, #Board.PRESET_ORDER * ROW_H + 8)
    menu:SetPoint("TOP", ui.diff, "BOTTOM", 0, -3)
    menu:EnableMouse(true)
    for i, key in ipairs(Board.PRESET_ORDER) do
        local col = Skin.DifficultyColor(key)
        local row = CreateFrame("Button", nil, menu)
        row:SetSize(MENU_W - 8, ROW_H)
        row:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - (i - 1) * ROW_H)
        row.hover = row:CreateTexture(nil, "HIGHLIGHT")
        row.hover:SetAllPoints(row)
        row.hover:SetColorTexture(unpack(C.glassHover))
        row.hover:SetBlendMode("ADD")
        -- The row you're on: a tinted body and a bar down its edge (a shape, not only a colour).
        row.selected = row:CreateTexture(nil, "BACKGROUND")
        row.selected:SetAllPoints(row)
        row.selected:SetColorTexture(col[1], col[2], col[3], 0.20)
        row.bar = row:CreateTexture(nil, "ARTWORK")
        row.bar:SetSize(3, ROW_H - 8)
        row.bar:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.bar:SetColorTexture(col[1], col[2], col[3], 1)
        row.label = Glass.Font(row, 13, "LEFT")
        row.label:SetPoint("LEFT", row, "LEFT", 11, 0)
        row.label:SetTextColor(col[1], col[2], col[3])
        row.label:SetText(LABELS[key])
        row.details = Glass.Font(row, 11, "RIGHT")
        row.details:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.details:SetTextColor(unpack(C.menuText))
        row.details:SetText(details(key))
        row:SetScript("OnClick", function() pickDifficulty(key) end)
        ui.rows[key] = row
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

------------------------------------------------------------
-- The footer: the controls, or (once a finished board has been put on show) its result
------------------------------------------------------------

-- Show the result bar in place of the controls, or the other way round.
local function showResultBar(on)
    ui.hintKeys:SetShown(not on)
    ui.hintMid:SetShown(not on)
    ui.help:SetShown(not on)
    ui.result:SetShown(on)
end

local function buildFooter()
    ui.hintStart = Glass.Font(win, 12, "CENTER")
    ui.hintStart:SetPoint("TOP", ui.grid, "BOTTOM", 0, -8)
    ui.hintStart:SetTextColor(unpack(C.gold))
    ui.hintStart:SetText("Choose a tile to begin.")

    ui.hintKeys = Glass.Font(win, 11, "CENTER")
    ui.hintKeys:SetPoint("TOP", ui.grid, "BOTTOM", 0, -25)
    ui.hintKeys:SetTextColor(unpack(C.hint))
    ui.hintKeys:SetText("Left-click: Reveal     Right-click: Flag")

    ui.hintMid = Glass.Font(win, 11, "CENTER")
    ui.hintMid:SetPoint("TOP", ui.grid, "BOTTOM", 0, -41)
    ui.hintMid:SetTextColor(unpack(C.hint))
    ui.hintMid:SetText("Middle-click: Clear around number")

    -- A small ? beside it explains what that does.
    local help = Widgets.GlassButton(win, 16, 16, { square = true, fontSize = 11 })
    help:SetFrameLevel(Glass.ContentLevel(win))
    help:SetPoint("LEFT", ui.hintMid, "RIGHT", 6, 0)
    help.label:SetText("?")
    Widgets.Tip(help, "Clearing around a number", {
        "Middle-click a revealed number (or hold left and right together) to reveal the tiles around it that aren't flagged.",
        "It only works when the number of flags around it equals the number.",
        "A wrong flag makes it reveal a mine, so check your flags first.",
    })
    ui.help = help

    -- The result bar: what the overlay said, and the button to play again.
    local r = CreateFrame("Frame", nil, win)
    r:SetFrameLevel(Glass.ContentLevel(win))
    r:SetPoint("TOP", ui.grid, "BOTTOM", 0, -6)
    r:SetHeight(44)
    r.title = Glass.Font(r, 14, "LEFT")
    r.title:SetPoint("TOPLEFT", r, "TOPLEFT", 4, -6)
    r.sub = Glass.Font(r, 11, "LEFT")
    r.sub:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -3)
    r.sub:SetTextColor(unpack(C.hint))
    r.button = Widgets.GlassButton(r, 104, 26)
    r.button:SetPoint("RIGHT", r, "RIGHT", -4, 0)
    r.button:SetScript("OnClick", function() Window.NewGame() end)
    r:Hide()
    ui.result = r
end

------------------------------------------------------------
-- The end of a game: the overlay over the board
------------------------------------------------------------

local OVERLAY_W, WIN_H, LOSS_H = 200, 152, 114

-- #7 (personal bests) will say whether this win beat the player's best. Until it
-- exists nothing is true, and the line stays hidden.
local function isPersonalBest() return false end

local function endTexts()
    if game:State() == "won" then
        return "Field cleared!", C.gold, "Time " .. timerText(), "Play again", C.winRim
    end
    return "Boom. Full wipe.", C.boom, "Wrong flags are crossed out.", "Try again", C.lossRim
end

local function buildOverlay()
    local o = CreateFrame("Frame", nil, win)
    o:SetFrameLevel(win:GetFrameLevel() + 15)       -- over the tiles and the rim, under the difficulty list (+20)
    o:SetPoint("CENTER", ui.grid, "CENTER", 0, 0)
    o:EnableMouse(true)                              -- the board under it takes no clicks
    o.glass = Glass.Apply(o, "small")
    o.backing = o:CreateTexture(nil, "BACKGROUND", nil, -7)
    o.backing:SetAllPoints(o)
    o.backing:SetColorTexture(unpack(C.overlayBg))
    o.backing:AddMaskTexture(o.glass.mask)

    o.title = Glass.Font(o, 20, "CENTER")
    o.title:SetPoint("TOP", o, "TOP", 0, -14)
    o.time = Glass.Font(o, 14, "CENTER")
    o.time:SetPoint("TOP", o.title, "BOTTOM", 0, -8)
    o.best = Glass.Font(o, 12, "CENTER")
    o.best:SetPoint("TOP", o.time, "BOTTOM", 0, -6)
    o.best:SetTextColor(unpack(C.gold))
    o.best:SetText("New personal best!")

    o.button = Widgets.GlassButton(o, 136, 26)
    o.button:SetPoint("BOTTOM", o, "BOTTOM", 0, 44)
    o.button:SetScript("OnClick", function() Window.NewGame() end)
    -- The way to look at the finished board: a visible control, not only a click on the panel.
    o.view = Widgets.GlassButton(o, 136, 22, { fontSize = 11 })
    o.view:SetPoint("BOTTOM", o, "BOTTOM", 0, 14)
    o.view.label:SetText("View board")
    o.view:SetScript("OnClick", function() Window.DismissEnd() end)

    -- And a click on the panel itself does the same.
    o:SetScript("OnMouseUp", function() Window.DismissEnd() end)
    Widgets.Tip(o, "Click to see the board", "Play again or Try again stays at the bottom, and the face starts a new game.")
    o:Hide()
    ui.overlay = o
end

-- Shown once, when an action ends the game (Dispatch): cleared, or the wipe.
function Window.ShowEnd()
    if not over() then return end
    if not ui.overlay then buildOverlay() end
    local o = ui.overlay
    local title, color, sub, button, rim = endTexts()
    o:SetWidth(math.min(OVERLAY_W, Window.size.gridW - 12))
    o.title:SetTextColor(color[1], color[2], color[3])
    o.title:SetText(title)
    o.button.label:SetText(button)
    o.button:setAccent(rim[1], rim[2], rim[3])
    o.glass.rim:SetVertexColor(rim[1], rim[2], rim[3])
    if game:State() == "won" then
        local best = isPersonalBest()
        o:SetHeight(best and WIN_H or WIN_H - 18)
        o.time:SetText(sub)
        o.time:Show()
        o.best:SetShown(best)
    else
        o:SetHeight(LOSS_H)
        o.time:Hide()
        o.best:Hide()
    end
    o:Show()
end

-- Put the overlay away to look at the finished board. The board is exactly as it
-- was, and the result stays in the footer with the button to play again.
function Window.DismissEnd()
    if not (ui.overlay and ui.overlay:IsShown() and over()) then return end
    ui.overlay:Hide()
    local title, color, sub, button, rim = endTexts()
    ui.result.title:SetTextColor(color[1], color[2], color[3])
    ui.result.title:SetText(title)
    ui.result.sub:SetText(sub)
    ui.result.button.label:SetText(button)
    ui.result.button:setAccent(rim[1], rim[2], rim[3])
    showResultBar(true)
end

------------------------------------------------------------
-- Building it
------------------------------------------------------------

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
    -- A darker body under the glass, so the scenery doesn't compete with the board. It sits
    -- above the shadow and under the tint (GlassPanel's window does the same), inside the mask.
    win.backing = win:CreateTexture(nil, "BACKGROUND", nil, -7)
    win.backing:SetAllPoints(win)
    win.backing:SetColorTexture(unpack(C.panelBacking))
    win.backing:AddMaskTexture(win.glass.mask)
    local content = Glass.ContentLevel(win)

    -- Title bar: the mascot, the name, the tagline, the settings gear, close.
    ui.logo = win:CreateTexture(nil, "ARTWORK")
    ui.logo:SetSize(40, 40)
    ui.logo:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, -10)
    ui.logo:SetTexture(T.logo)
    local title = Glass.Font(win, 19, "LEFT")
    title:SetPoint("TOPLEFT", ui.logo, "TOPRIGHT", 9, -2)
    title:SetText(Skin.TITLE)
    local tagline = Glass.Font(win, 11, "LEFT")
    tagline:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    tagline:SetTextColor(unpack(C.tagline))
    tagline:SetText(GS.TAGLINE)

    ui.close = Widgets.IconButton(win, 22, T.close, { 1, 0.9, 0.9 })
    ui.close:SetFrameLevel(content)
    ui.close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -10, -10)
    ui.close:setAccent(unpack(C.closeAccent))
    ui.close:SetScript("OnClick", function() win:Hide() end)
    Widgets.Tip(ui.close, "Close", "Escape closes it too.")

    ui.gear = Widgets.IconButton(win, 22, T.gear, { 0.82, 0.92, 1 })
    ui.gear:SetFrameLevel(content)
    ui.gear:SetPoint("RIGHT", ui.close, "LEFT", -5, 0)
    Widgets.Tip(ui.gear, "Settings", {            -- inert until #8
        "A settings panel is coming.",
        "For now: /gsweep scale 0.5 to 1.5 resizes the window.",
    })

    -- Difficulty: a glass button in the difficulty's rarity colour, and the list it opens.
    ui.diff = Widgets.GlassButton(win, 150, 24, { fontSize = 13 })
    ui.diff:SetFrameLevel(content)
    ui.diff:SetPoint("TOP", win, "TOP", 0, -58)
    ui.diffArrow = ui.diff:CreateTexture(nil, "OVERLAY")
    ui.diffArrow:SetSize(14, 14)
    ui.diffArrow:SetTexture(T.arrow)
    ui.diffArrow:SetPoint("RIGHT", ui.diff, "RIGHT", -7, 0)
    ui.diff:SetScript("OnClick", function() ui.menu:SetShown(not ui.menu:IsShown()) end)
    Widgets.Tip(ui.diff, "Difficulty", "Starts a new game.")
    buildMenu()

    -- The HUD strip: mines left, the mascot (a new game), the clock. Its width is capped
    -- (Layout.HudWidth), so on Expert the three stay together instead of spreading out.
    local hud = CreateFrame("Frame", nil, win)
    hud:SetFrameLevel(content)
    hud:SetPoint("TOP", win, "TOP", 0, -90)
    hud:SetHeight(40)
    hud.bg = hud:CreateTexture(nil, "BACKGROUND")
    hud.bg:SetAllPoints(hud)
    hud.bg:SetColorTexture(unpack(C.hudBg))
    ui.hud = hud

    local flag = hud:CreateTexture(nil, "ARTWORK")
    flag:SetSize(24, 24)
    flag:SetPoint("LEFT", hud, "LEFT", 10, 0)
    flag:SetTexture(T.flag)
    ui.counter = Glass.Font(hud, 22, "LEFT")
    ui.counter:SetPoint("LEFT", flag, "RIGHT", 5, 0)

    ui.face = Widgets.FaceButton(hud, 44)
    ui.face:SetPoint("CENTER", hud, "CENTER", 0, 0)
    ui.face:SetScript("OnClick", function() Window.NewGame() end)
    Widgets.Tip(ui.face, "New game", "Same difficulty.")

    ui.timer = Glass.Font(hud, 22, "RIGHT")
    ui.timer:SetWidth(54)             -- "00:00" is about 47 wide; any more leaves a gap before the clock
    ui.timer:SetPoint("RIGHT", hud, "RIGHT", -10, 0)
    local clock = hud:CreateTexture(nil, "ARTWORK")
    clock:SetSize(22, 22)
    clock:SetPoint("RIGHT", ui.timer, "LEFT", -5, 0)
    clock:SetTexture(T.clock)

    -- The board area: a dark panel the tiles sit on (Grid.lua fills it).
    local grid = CreateFrame("Frame", nil, win)
    grid:SetFrameLevel(content)
    grid.bg = grid:CreateTexture(nil, "BACKGROUND")
    grid.bg:SetAllPoints(grid)
    grid.bg:SetColorTexture(unpack(C.gridBg))
    ui.grid = grid
    Window.grid = grid
    Grid.Attach(grid, function(kind, i) Window.Dispatch(kind, i) end)

    buildFooter()

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
    -- While /gsweep input is on, say what the cell was and what the action did,
    -- so "nothing happened" can be explained from the log alone.
    local before
    if Grid.Logging() then
        local c, flags = game:Cell(i), 0
        for dy = -1, 1 do
            for dx = -1, 1 do
                local j = (dx ~= 0 or dy ~= 0) and game:Index(x + dx, y + dy)
                if j and game:Cell(j).state == "flag" then flags = flags + 1 end
            end
        end
        before = string.format("(%d,%d) %s%s, %d flags around", x, y, c.state, c.count and (" " .. c.count) or "", flags)
    end
    local was = game:State()
    local list
    if kind == "reveal" then
        list = game:Reveal(x, y, GetTime())
    elseif kind == "chord" then
        list = game:Chord(x, y, GetTime())
    else
        list = game:ToggleMark(x, y)
    end
    if before then Grid.Log("%s on %s -> %d cells changed (%s)", kind, before, #list, game:State()) end
    Grid.Refresh(list)
    Window.Refresh()
    local state = game:State()
    -- Only the action that ENDS the game brings the overlay up: a click on a
    -- finished board does nothing, and must not bring back one put away.
    if (state == "won" or state == "lost") and state ~= was then
        Grid.SetInteractive(false)
        Window.ShowEnd()
    end
    return list
end

------------------------------------------------------------
-- Entry points
------------------------------------------------------------

-- Fit the window and (re)build the tiles for the current game.
local function syncGame()
    Window.Layout()
    Grid.Rebuild(game)
    if over() then Grid.SetInteractive(false) end
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
    if ui.overlay then ui.overlay:Hide() end
    if ui.result then showResultBar(false) end
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

-- The player's own scale (/gsweep scale), nil to go back to 1. The window still
-- never exceeds the screen: the number wanted and the number shown can differ.
function Window.SetScale(n)
    ensure()
    db().scale = n
    Window.Layout()
end

-- The scale wanted, and the one actually in use.
function Window.ScaleInfo()
    ensure()
    return db().scale or 1, Window.scale
end

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
    details = details,
    -- Swap in a hand-built board (Board._test.FromLayout), to test exact shapes.
    SetGame = function(b)
        game = b
        Window.game = b
        if ui.overlay then ui.overlay:Hide() end
        if ui.result then showResultBar(false) end
        if win then syncGame() end
    end,
}
