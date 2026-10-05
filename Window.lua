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
local Scores, API = GS.Scores, GS.API
local L = GS.L             -- the player's language (#36: Locales\)
local PAD = Layout.PAD
local T, C = Skin.TEXTURES, Skin.COLORS

local LABELS = { beginner = L["Beginner"], intermediate = L["Intermediate"], expert = L["Expert"] }
Window.LABELS = LABELS                    -- the difficulties' names, for the toast too (#17)
local WIN_NAME = "GnomesweeperWindow"
local MULT, DOT = "\195\151", "\194\183"          -- the multiplication sign and the middle dot, as UTF-8
-- The title lettering: 28 high (the tagline then ends clear of the difficulty button
-- at -58), as wide as its drawn part's shape (Skin.ASPECT, from Skin.TITLE_CROP).
local TITLE_H = 28
local TITLE_W = math.floor(TITLE_H * Skin.ASPECT.title + 0.5)

local win, game
Window.shownCount = 0
-- The current game's scores category (Scores.Category), nil for a board that
-- isn't a preset (the tests' hand-built ones): those never touch the scores.
local category
-- The current game's first-click rule ("area" or "cell"): what the best times,
-- the list and the tooltip show, so a rule changed mid-game shows with the next
-- game, the one it applies to (#39 review).
local rule = "area"
-- How the last win compared: { new = bool, previous = record or nil }.
local lastWin
local fillBests             -- the best times panel's refresh (defined with the panel)
local playerNewGame        -- the face / Play again / Try again (defined with the entry points)
-- The panels that float over the board (the difficulty list, the best times):
-- one at a time, and all closed with the window.
local floating = {}
local ui = { rows = {} }    -- the widgets Refresh and the layout touch

local function db() return GnomesweeperDB end

local function difficultyKey()
    local d = db().difficulty
    return Board.PRESETS[d] and d or "beginner"
end

-- "9x9 . 10 mines", from the board's own presets, never typed in twice.
local function details(key)
    local p = Board.PRESETS[key]
    return string.format(L["%d%s%d %s %d mines"], p.w, MULT, p.h, DOT, p.mines)
end

------------------------------------------------------------
-- The game
------------------------------------------------------------

local reveals = 0     -- reveals and chords that changed the board this game (#32: progress to lose)
local beat            -- the best to beat this game (its time at the start), or nil
local passed          -- the clock went past it this game (the alert played)

local function newBoard()
    local key = difficultyKey()
    local p = Board.PRESETS[key]
    game = assert(Board.New(p.w, p.h, p.mines, {
        safeZone = db().safeZone,
        questionMarks = db().questionMarks,
    }))
    Window.game = game
    rule = db().safeZone == "cell" and "cell" or "area"
    category = Scores.Category(key, rule)
    lastWin = nil
    reveals = 0
    local best = type(db().scores) == "table" and Scores.Best(db().scores, category)
    beat, passed = best and best.time or nil, false
end

------------------------------------------------------------
-- Personal bests (#7): Scores.lua keeps them; this says when and shows them
------------------------------------------------------------

-- Writing opens (creates) the saved scores; reading never does, so merely opening
-- the window leaves the SavedVariables as they were.
local function scores() return Scores.Open(db()) end
local function peek() return type(db().scores) == "table" and db().scores or {} end

local function bestTime(record)
    return Layout.FormatTime(Board.DisplaySeconds(record.time))
end

-- A difficulty's best, played and won, under the current game's first-click rule.
local function statsFor(key)
    local cat = Scores.Category(key, rule)
    local played, won = Scores.Stats(peek(), cat)
    return Scores.Best(peek(), cat), played, won
end

-- Who set a best: Scores only vouches for the time, and the file can be edited.
local function bestName(record)
    return type(record.name) == "string" and record.name ~= "" and record.name or nil
end

-- The best times column in the difficulty list: filled when the list opens.
local function fillMenuBests()
    for k, row in pairs(ui.rows) do
        local best = statsFor(k)
        row.best:SetText(best and bestTime(best) or "-")
    end
end

-- The difficulty button's tooltip: the best and the record, asked on each hover.
local function difficultyTip()
    local best, played, won = statsFor(difficultyKey())
    local lines = { L["Starts a new game."] }
    if best then
        lines[#lines + 1] = bestName(best) and string.format(L["Best: %s by %s"], bestTime(best), bestName(best))
            or string.format(L["Best: %s"], bestTime(best))
    end
    lines[#lines + 1] = played > 0 and string.format(L["Won %d of %d"], won, played) or L["Not played yet."]
    return lines
end

-- After a win that didn't beat the best: true when the two would both read the
-- same whole seconds ("Time 00:42" over "Best 00:42"), so both show tenths.
local function sameSecond()
    local prev = lastWin and not lastWin.new and lastWin.previous
    return prev and Board.DisplaySeconds(prev.time) == Board.DisplaySeconds(game:Elapsed(GetTime())) or false
end

-- How much a new best beat the old one, as the two times on screen say: both are
-- shown truncated to tenths (00:42.0, 00:41.2), so the margin is their difference
-- (0.8 s), never a rounding that disagrees with them. In the same tenth, the
-- real difference in hundredths ("0.04 s"), or "<0.01 s" below that, never a
-- zero. nil when there was no
-- old best (a first win) or this isn't a new best.
local function margin()
    local prev = lastWin and lastWin.new and lastWin.previous
    if not prev then return nil end
    local now = game:Elapsed(GetTime())
    local tenths = math.floor(prev.time * 10 + 1e-9) - math.floor(now * 10 + 1e-9)
    if tenths >= 1 then return GS.Decimal("%.1f", tenths / 10) .. " s" end
    local d = prev.time - now
    if d < 0.01 then return "<" .. GS.Decimal("%.2f", 0.01) .. " s" end   -- never "0.00 s" (Codex, #47): bests compare precisely
    return GS.Decimal("%.2f", d) .. " s"
end

local function shownTime(t, tenths)
    return tenths and Layout.FormatTenths(t, Board.DisplaySeconds(math.huge), GS.LOCALE.decimal) or Layout.FormatTime(Board.DisplaySeconds(t))
end

-- What the end of a won game says about the best: the text and its colour.
local function bestLine()
    if not lastWin then return nil end
    if lastWin.new then return L["New personal best!"], C.gold end
    if lastWin.previous then return string.format(L["Best %s"], shownTime(lastWin.previous.time, sameSecond())), C.hint end
    return nil
end

-- Called by Dispatch with the state before and after an action.
local function recordScores(was, state)
    if not category then return end
    if was == "ready" and state ~= "ready" then Scores.Started(scores(), category) end
    if state == "won" and was ~= "won" then
        -- This character's own best first (#15): its seeding reads the account's scores, which
        -- must not yet hold this win, or the win would count as already held and send nothing.
        pcall(GS.Social.RecordWin, category, game:Elapsed(GetTime()))   -- never at the scores' expense
        local isNew, previous = Scores.Won(scores(), category, {
            time = game:Elapsed(GetTime()),
            at = time(),
            name = API.PlayerFullName(),
            realm = GetRealmName(),
        })
        lastWin = { new = isNew, previous = previous }
    end
    if was ~= state and ui.bests and ui.bests:IsShown() then fillBests() end
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

-- The clock's colour and flash against the best to beat (#46, Layout.ClockState). It
-- keeps its colour after the end (a near miss reads as one), but a new best is no near
-- miss, and a game not started yet has nothing to warn about; it only flashes in play.
-- It touches the clock only when its look changes. Passing the best plays the alert,
-- once a game, on the same threshold that turns it red.
local CLOCK_COLOR = { normal = C.clockNormal, near = C.clockNear, last = C.clockNear, over = C.clockOver }
local clockLook               -- the state and flash last painted, as "state:flash"
local clockState              -- the state last painted (tests)
local function paintClock(elapsed)
    local s = game:State()
    local state = "normal"
    if s ~= "ready" and not (lastWin and lastWin.new) then
        state = Layout.ClockState(elapsed or game:Elapsed(GetTime()), beat)
    end
    clockState = state
    if state == "over" and beat and not passed and s == "playing" then
        passed = true
        GS.Sounds.BestPassed()
    end
    local flash = state == "last" and s == "playing"
    local look = state .. (flash and ":flash" or "")
    if look == clockLook then return end
    clockLook = look
    local col = CLOCK_COLOR[state]
    ui.timer:SetTextColor(col[1], col[2], col[3])
    if flash then ui.timerFlash.play() else ui.timerFlash.stop() end
end

local acc = 0
local function onUpdate(_, dt)
    acc = acc + dt
    if acc < 0.1 then return end
    acc = 0
    local text = timerText()
    if text ~= ui.timer:GetText() then ui.timer:SetText(text) end
    paintClock()
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
    paintClock()
    ui.hintStart:SetShown(game:State() == "ready")
    ui.diff.label:SetText(LABELS[key])
    ui.diff.label:SetTextColor(col[1], col[2], col[3])
    ui.diff:setAccent(col[1], col[2], col[3])
    ui.diffArrow:SetVertexColor(col[1], col[2], col[3])
    for k, row in pairs(ui.rows) do row.selected:SetShown(k == key); row.bar:SetShown(k == key) end
    ui.face:setState(game:State())
    -- She breathes while a game is played (the mascot checks she can be seen: a
    -- setting changed with the window hidden refreshes it too).
    ui.mascot.idle(game:State() == "playing")
    setTicking(game:State() == "playing")
    -- The burst while the win shows, the smoke while the wipe does (#10).
    local state = game:State()
    if state == "won" then ui.burst.play() else ui.burst.stop() end
    if state == "lost" then
        if not ui.smoke.isPlaying() then
            for i = 1, game.total do
                if game:Cell(i).exploded then ui.smoke.play(Grid.Tile(i)); break end
            end
        end
    else
        ui.smoke.stop()
    end
    local on = db().music == true
    ui.music.icon:SetVertexColor(unpack(on and C.musicOn or C.musicOff))
    ui.music.slash:SetShown(not on)
    local sounds = db().sounds ~= false
    ui.sound.icon:SetVertexColor(unpack(sounds and C.musicOn or C.musicOff))
    ui.sound.slash:SetShown(not sounds)
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
    -- As wide as the board, but never narrower than the window's inside: on Beginner
    -- the board is 216 wide, which leaves the text 104 beside the button, and
    -- "Wrong flags are crossed out." alone needs about 121 (Arial Narrow, measured).
    ui.result:SetWidth(math.max(size.gridW, size.width - 2 * PAD))
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

local MENU_W, ROW_H, BEST_W = 262, 24, 44
local MENU_H = #Board.PRESET_ORDER * ROW_H + 8   -- the list's rows
local CONFIRM_H = 62        -- the question under the rows (#32): room for its text on two lines
local FACE_TIP_W, FACE_TIP_H = 250, 46   -- the first launch's pointer at the face (#45)

-- Something to lose (#32, owner: "a reveal beyond the first, or any flag"): a flag on
-- the board (read from it, so one placed and taken off again isn't progress), or a
-- second reveal or chord. A board not started yet counts too if it has flags. A first
-- reveal alone, or a finished game, has nothing to lose.
local function hasProgress()
    if not game then return false end
    local s = game:State()
    if s ~= "ready" and s ~= "playing" then return false end
    return reveals >= 2 or game:FlagsLeft() < game.mines
end

-- The question inside the list: "Start Expert? This game will be lost."
local function askFor(key)
    local c = ui.menu.confirm
    c.key = key
    c.text:SetText(string.format(L["Start %s? This game will be lost."], LABELS[key]))
    local col = Skin.DifficultyColor(key)
    c.start:setAccent(col[1], col[2], col[3])
    c:Show()
    ui.menu:SetHeight(MENU_H + CONFIRM_H)
    if not ui.menu:IsShown() then ui.menu:Show() end
end

-- The one place a difficulty change is decided (the list and /gsweep <difficulty>):
-- the same one closes the list, progress asks, anything else switches.
local function chooseDifficulty(key)
    if key == difficultyKey() then ui.menu:Hide(); return end
    if hasProgress() then askFor(key); return end
    ui.menu:Hide()
    Window.NewGame(key)
end
local pickDifficulty = chooseDifficulty

-- Any mouse button: a right-click (a flag) or a middle-click (a chord) on the board is an
-- outside click as much as a left one, and must cancel the list's question (Codex, #50).
local function anyButtonDown()
    return IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") or IsMouseButtonDown("MiddleButton")
end

local function buildMenu()
    local menu = Widgets.GlassPanel(win)
    -- Above everything else in the window, including the result overlay (+15) and the glass rim that
    -- overlay draws at its own +10, i.e. +25: a list opened while an overlay is up must not slide under it.
    menu:SetFrameLevel(win:GetFrameLevel() + 30)
    menu:SetSize(MENU_W, MENU_H)
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
        row.details:SetPoint("RIGHT", row, "RIGHT", -8 - BEST_W, 0)
        -- The best time at this difficulty (Refresh fills it in), "-" before a win.
        row.best = Glass.Font(row, 11, "RIGHT")
        row.best:SetWidth(BEST_W)
        row.best:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.best:SetTextColor(unpack(C.gold))
        row.details:SetTextColor(unpack(C.menuText))
        row.details:SetText(details(key))
        row:SetScript("OnClick", function() pickDifficulty(key) end)
        ui.rows[key] = row
    end
    -- Closes on a click anywhere else. Polled while it is open (an OnUpdate
    -- that exists only then) rather than relying on a global mouse event.
    menu:SetScript("OnShow", function(self)
        fillMenuBests()
        self:SetScript("OnUpdate", function()
            if anyButtonDown() and not (self:IsMouseOver() or ui.diff:IsMouseOver()) then
                self:Hide()
            end
        end)
    end)
    -- The question (#32): under the rows, only while it asks. Anything that closes the
    -- list (an outside click, the window closing) cancels it.
    local c = CreateFrame("Frame", nil, menu)
    c:SetSize(MENU_W - 8, CONFIRM_H - 4)
    c:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - #Board.PRESET_ORDER * ROW_H)
    c.text = Glass.Font(c, 12, "CENTER")
    c.text:SetPoint("TOP", c, "TOP", 0, -4)
    c.text:SetWidth(MENU_W - 24)
    c.text:SetWordWrap(true)                   -- a wider font wraps rather than spills past the list
    c.text:SetTextColor(unpack(C.menuText))
    c.start = Widgets.GlassButton(c, 110, 22, { fontSize = 11 })
    c.start:SetPoint("BOTTOMRIGHT", c, "BOTTOM", -4, 4)
    c.start.label:SetText(L["Start"])
    c.start:SetScript("OnClick", function()
        local key = c.key
        menu:Hide()
        Window.NewGame(key)
    end)
    c.keep = Widgets.GlassButton(c, 110, 22, { fontSize = 11 })
    c.keep:SetPoint("BOTTOMLEFT", c, "BOTTOM", 4, 4)
    c.keep.label:SetText(L["Keep game"])
    c.keep:SetScript("OnClick", function() menu:Hide() end)
    c:Hide()
    menu.confirm = c

    menu:SetScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        c:Hide()
        c.key = nil
        self:SetHeight(MENU_H)
    end)
    Window.Floating(menu)
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
    ui.result:SetShown(on)
end

local function buildFooter()
    ui.hintStart = Glass.Font(win, 12, "CENTER")
    ui.hintStart:SetPoint("TOP", ui.grid, "BOTTOM", 0, -8)
    ui.hintStart:SetTextColor(unpack(C.gold))
    ui.hintStart:SetText(L["Choose a tile to begin."])

    ui.hintKeys = Glass.Font(win, 11, "CENTER")
    ui.hintKeys:SetPoint("TOP", ui.grid, "BOTTOM", 0, -25)
    ui.hintKeys:SetTextColor(unpack(C.hint))
    ui.hintKeys:SetText(L["Left-click: Reveal     Right-click: Flag"])

    ui.hintMid = Glass.Font(win, 11, "CENTER")
    ui.hintMid:SetPoint("TOP", ui.grid, "BOTTOM", 0, -41)
    ui.hintMid:SetTextColor(unpack(C.hint))
    ui.hintMid:SetText(L["Middle-click: Clear around number"])

    -- The result bar: what the overlay said, and the button to play again.
    local r = CreateFrame("Frame", nil, win)
    r:SetFrameLevel(Glass.ContentLevel(win))
    r:SetPoint("TOP", ui.grid, "BOTTOM", 0, -6)
    r:SetHeight(44)
    r.title = Glass.Font(r, 14, "LEFT")
    r.title:SetPoint("TOPLEFT", r, "TOPLEFT", 4, -6)
    r.sub = Glass.Font(r, 11, "LEFT")
    r.sub:SetTextColor(unpack(C.hint))
    r.button = Widgets.GlassButton(r, 104, 26)
    r.button:SetPoint("RIGHT", r, "RIGHT", -4, 0)
    -- The texts stop short of the button: a longer one is cut, never drawn under it.
    -- (TOPRIGHT, not RIGHT: a RIGHT point would also pull the text's middle down to the button's.)
    r.title:SetPoint("TOPRIGHT", r, "TOPRIGHT", -(4 + 104 + 6), -6)
    r.sub:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -3)
    r.sub:SetPoint("TOPRIGHT", r.title, "BOTTOMRIGHT", 0, -3)
    r.title:SetWordWrap(false)
    r.sub:SetWordWrap(false)
    r.button:SetScript("OnClick", function() playerNewGame() end)
    r:Hide()
    ui.result = r
end

------------------------------------------------------------
-- The end of a game: the overlay over the board
------------------------------------------------------------

local OVERLAY_W, WIN_H, LOSS_H = 200, 180, 142   -- #21: a line under the title, bigger buttons
local MODEL_COL = 100      -- the end panel's model column, when there is a model (#21)
local PANEL_MAX = 340      -- the end panel's width with a model (#21: near the window's on Beginner)
-- A new best crowns its TIME with the laurels (#12). Measured on the texture: the
-- branches leave about 71% of their drawn width open, in their upper half only;
-- "New personal best!" (~146 units, 160 at the pulse) would need laurels wider than
-- the panel, the time (~98 units) fits. So the time sits a quarter of the way down
-- the wreath (LAUREL_TEXT), and the line and the margin hang under it.
local LAUREL_W = 150
local LAUREL_H = math.floor(LAUREL_W / Skin.ASPECT.laurels + 0.5)     -- 53
local LAUREL_TEXT = 0.25
local NEW_BEST_H = WIN_H + 44           -- the wreath and the line under it, clear of Play again

local function endTexts()
    if game:State() == "won" then
        -- Tenths when they decide something: a new best, or a time in the same second as the best.
        local tenths = sameSecond() or (lastWin and lastWin.new) or false
        return L["Clean sweep!"], C.gold, string.format(L["Time %s"], shownTime(game:Elapsed(GetTime()), tenths)),
            L["Play again"], C.winRim, L["Not a hair out of place."]
    end
    return L["Boom. Full wipe."], C.boom, L["Wrong flags are crossed out."], L["Try again"], C.lossRim,
        L["One more try?"]
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
    -- The line under it (#21, the owner's words): "One more try?", "Not a hair out of place."
    o.subtitle = Glass.Font(o, 13, "CENTER")
    o.subtitle:SetTextColor(unpack(C.hint))
    o.time = Glass.Font(o, 14, "CENTER")
    o.time:SetPoint("TOP", o.title, "BOTTOM", 0, -8)
    o.best = Glass.Font(o, 12, "CENTER")              -- the best that stands ("Best 00:42")
    o.best:SetPoint("TOP", o.time, "BOTTOM", 0, -6)
    -- A new personal best is an event (#10): bigger, gold, and a beat.
    o.newBest = Glass.Font(o, 16, "CENTER")              -- bigger than the quiet line, with room to pulse inside the panel

    o.newBest:SetTextColor(unpack(C.gold))
    o.newBest:SetText(L["New personal best!"])
    o.newBest:Hide()
    o.pulse = GS.Effects.Pulse(o.newBest)
    -- The storyboard's laurels around it (#12): behind the text, open at the top.
    o.laurels = o:CreateTexture(nil, "ARTWORK")
    o.laurels:SetSize(LAUREL_W, LAUREL_H)
    o.laurels:SetTexture(T.laurels)
    o.laurels:SetTexCoord(unpack(Skin.LAUREL_CROP))
    -- the time a quarter of the way down: the wreath's centre is that much lower
    o.laurels:SetPoint("CENTER", o.time, "CENTER", 0, -(0.5 - LAUREL_TEXT) * LAUREL_H)
    o.laurels:Hide()
    o.newBest:SetPoint("TOP", o.laurels, "BOTTOM", 0, -2)     -- under the wreath (it always shows with it)
    -- Under it: by how much, and the record it beat ("0.8 s faster than 00:22.1").
    o.beaten = Glass.Font(o, 12, "CENTER")
    o.beaten:SetPoint("TOP", o.newBest, "BOTTOM", 0, -4)
    o.beaten:SetTextColor(unpack(C.hint))
    o.beaten:Hide()

    o.button = Widgets.GlassButton(o, 136, 26)
    o.button:SetPoint("BOTTOM", o, "BOTTOM", 0, 44)
    o.button:SetScript("OnClick", function() playerNewGame() end)
    -- The way to look at the finished board: a visible control, not only a click on the panel.
    o.view = Widgets.GlassButton(o, 136, 22, { fontSize = 10 })   -- 10: it shares the row with Best times on a win
    o.view:SetPoint("BOTTOM", o, "BOTTOM", 0, 14)
    -- "See the field", not "View board": the owner read "board" as the scoreboard (#7).
    o.view.label:SetText(L["See the field"])
    o.view:SetScript("OnClick", function() Window.DismissEnd() end)
    -- After a win, the best times beside it (#67, owner): the trophy's own words, never "board".
    o.bests = Widgets.GlassButton(o, 87, 22, { fontSize = 10 })
    o.bests.label:SetText(L["Best times"])
    o.bests:setAccent(unpack(C.gold))
    o.bests:SetScript("OnClick", function() Window.ShowBests(true) end)
    o.bests:Hide()

    -- And a click on the panel itself does the same.
    o:SetScript("OnMouseUp", function() Window.DismissEnd() end)
    -- The model on its left (#21): above the glass body, under the rim; it goes with the panel.
    -- Stopped whenever the panel hides (put away, a new game, the window closing: the
    -- client hides children with it), started whenever it shows (a reopened window
    -- replays it).
    ui.slot = GS.Models.Slot(o, Glass.ContentLevel(o))
    o:SetScript("OnHide", function() ui.slot.stop() end)
    o:SetScript("OnShow", function() if not ui.slot.playing then Window.EndModel() end end)
    -- No tooltip on the panel (owner): "See the field" is a visible button now, and the tip was noise.
    o:Hide()
    ui.overlay = o
end

-- The panel's words and buttons (#21, after the owner's mockup): beside a model column
-- `col` units wide on its left, or centred without one (col 0). With a model the panel
-- is as wide as PANEL_MAX or the window allows; the title and its line under it start
-- at the column's left, the buttons span it, the main one filled blue.
local function dressEnd(col)
    local o = ui.overlay
    local title, color, sub, button, rim, subtitle = endTexts()
    local total = col > 0 and math.min(PANEL_MAX, Window.size.width - 16)
        or math.min(OVERLAY_W, Window.size.gridW - 12)
    local w = total - col                            -- the words' and buttons' column
    local cx = col + w / 2                           -- its centre, from the panel's left
    local inner = w - 24                             -- the buttons' width, and the words'
    o:SetWidth(total)
    o.title:ClearAllPoints()
    o.subtitle:ClearAllPoints()
    o.subtitle:SetWidth(inner)
    if col > 0 then
        o.title:SetJustifyH("LEFT")
        o.title:SetPoint("TOPLEFT", o, "TOPLEFT", col + 12, -16)
        o.subtitle:SetJustifyH("LEFT")
        o.subtitle:SetPoint("TOPLEFT", o.title, "BOTTOMLEFT", 0, -4)
    else
        o.title:SetJustifyH("CENTER")
        o.title:SetPoint("TOP", o, "TOPLEFT", cx, -16)
        o.subtitle:SetJustifyH("CENTER")
        o.subtitle:SetPoint("TOP", o.title, "BOTTOM", 0, -4)
    end
    o.subtitle:SetText(subtitle)
    o.time:ClearAllPoints()
    o.time:SetPoint("TOP", o.subtitle, "BOTTOM", 0, -8)  -- the subtitle spans the column: centred on it
    o.button:ClearAllPoints()
    o.button:SetSize(inner, 30)
    o.button:SetPoint("BOTTOM", o, "BOTTOMLEFT", cx, 46)
    -- A win: "See the field" and "Best times" side by side (#67); a wipe: "See the field" alone.
    local won = game:State() == "won"
    local half = math.floor((inner - 6) / 2)
    o.view:ClearAllPoints()
    o.bests:ClearAllPoints()
    if won then
        o.view:SetSize(half, 24)
        o.view:SetPoint("BOTTOMRIGHT", o, "BOTTOMLEFT", cx - 3, 12)
        o.bests:SetSize(half, 24)
        o.bests:SetPoint("BOTTOMLEFT", o, "BOTTOMLEFT", cx + 3, 12)
    else
        o.view:SetSize(inner, 24)
        o.view:SetPoint("BOTTOM", o, "BOTTOMLEFT", cx, 12)
    end
    o.bests:SetShown(won)
    o.title:SetTextColor(color[1], color[2], color[3])
    o.title:SetText(title)
    o.button.label:SetText(button)
    o.button:setPrimary(true)                        -- the action: blue on either panel (owner)
    o.glass.rim:SetVertexColor(rim[1], rim[2], rim[3])
    -- Tall enough for the model beside the words.
    local minH = col > 0 and GS.Models.HEIGHT + 28 or 0     -- its fuse reaches past its box
    if game:State() == "won" then
        local text, tint = bestLine()
        local isNew = lastWin and lastWin.new
        local by = margin()
        o:SetHeight(math.max(minH, isNew and (by and NEW_BEST_H + 17 or NEW_BEST_H) or text and WIN_H or WIN_H - 18))
        if by then o.beaten:SetText(string.format(L["%s faster than %s"], by, shownTime(lastWin.previous.time, true))) end
        o.beaten:SetShown(by ~= nil)
        o.time:SetText(sub)
        o.time:Show()
        if text and not isNew then
            o.best:SetText(text)
            o.best:SetTextColor(tint[1], tint[2], tint[3])
        end
        o.best:SetShown(text ~= nil and not isNew)
        o.newBest:SetShown(isNew and true or false)
        o.laurels:SetShown(isNew and true or false)
        if isNew then o.pulse.play() else o.pulse.stop() end
    else
        o:SetHeight(math.max(minH, LOSS_H))
        o.time:Hide()
        o.best:Hide()
        o.newBest:Hide()
        o.laurels:Hide()
        o.beaten:Hide()
        o.pulse.stop()
    end
end

-- The end panel's model (#21), with "3D models" on: Tally jumping for joy on a win,
-- the Walking Bomb going off on a wipe, on the panel's left. The panel is laid out for
-- it at once, and again without it if it can't play (absent, or not in within
-- Models.WAIT).
function Window.EndModel()
    if not (ui.overlay and over()) then return end
    local withModel = GS.Models.Enabled()
    dressEnd(withModel and MODEL_COL or 0)
    if not withModel then ui.slot.stop(); return end
    ui.slot.play(game:State() == "won" and "win" or "wipe", function() dressEnd(0) end)
    local scene = ui.slot.scene
    if scene then
        scene:ClearAllPoints()
        -- Standing on the panel's floor (the mockup), centred on its column; the scene's
        -- spare room is empty and may reach past the panel.
        scene:SetPoint("CENTER", ui.overlay, "BOTTOMLEFT", MODEL_COL / 2, 8 + GS.Models.HEIGHT / 2)
    end
end

-- Shown once, when an action ends the game (Dispatch): cleared, or the wipe.
function Window.ShowEnd()
    if not over() then return end
    if not ui.overlay then buildOverlay() end
    local o = ui.overlay
    if o:IsShown() then Window.EndModel() else o:Show() end    -- its OnShow starts the model
end

-- Put the overlay away to look at the finished board. The board is exactly as it
-- was, and the result stays in the footer with the button to play again.
function Window.DismissEnd()
    if not (ui.overlay and ui.overlay:IsShown() and over()) then return end
    ui.overlay:Hide()
    local title, color, sub, button, rim = endTexts()
    ui.result.title:SetTextColor(color[1], color[2], color[3])
    ui.result.title:SetText(title)
    local best = game:State() == "won" and bestLine()
    local by = margin()
    local newText = by and string.format(L["New best (-%s)"], by) or L["New best!"]
    ui.result.sub:SetText(best and (sub .. "  " .. DOT .. "  " .. (lastWin.new and newText or best)) or sub)
    ui.result.button.label:SetText(button)
    ui.result.button:setAccent(rim[1], rim[2], rim[3])
    showResultBar(true)
end

------------------------------------------------------------
-- The best times panel (the trophy, /gsweep scores): every difficulty's best
-- under the current first-click rule, whatever the game is doing
------------------------------------------------------------

local BESTS_W, BESTS_ROW = 264, 44
local bestsMode = "you"     -- the best times panel's tab: "you" (the account's) or "guild" (#15)
local GUILD_TOP = 5         -- a guild row's tooltip lists this many
local TABS_H, TAB_W = 26, 72   -- the tabs' row under the title

local function bestsRuleText()
    return rule == "cell" and L["First click: one safe tile (Windows XP's rule)."]
        or L["First click: always opens an area."]
end

-- A guild time, to the tenth: guildmates are ranked to the hundredth (Guild.lua).
local function csTime(cs)
    return Layout.FormatTenths(cs / 100, Board.DisplaySeconds(math.huge), GS.LOCALE.decimal)
end
Window.GuildTime = csTime                 -- the toast's too (#17): one format

-- The Guild tab (#15): per difficulty, the guild's best and where you stand.
local function fillGuild(p)
    local view = GS.Social.View()
    local gname = view.name
    for _, key in ipairs(Board.PRESET_ORDER) do
        local row = p.rows[key]
        local list = view.ranking(Scores.Category(key, rule))
        row.ranking = list
        local first = list[1]
        if first then
            row.time:SetText(csTime(first.cs))
            row.who:SetText(first.name .. "  " .. DOT .. "  " .. GS.FormatDate(first.at))
        else
            row.time:SetText("-")
            row.who:SetText(gname and L["No time shared yet"] or "")
        end
        local rank
        for i, r in ipairs(list) do if r.mine then rank = i end end
        row.record:SetText(rank and string.format(L["you: %d of %d"], rank, #list)
            or (#list > 0 and string.format(L["%d with a time"], #list) or ""))
    end
    local ruleWord = rule == "cell" and L["One safe tile"] or L["Opens an area"]
    p.rule:SetText(gname and (gname .. "  " .. DOT .. "  " .. ruleWord) or L["Not in a guild."])
end

-- Fills the panel from the saved scores. Reads only: never creates them.
function fillBests()
    local p = ui.bests
    if not p then return end
    for _, tab in pairs(p.tabs) do tab:setAccent(unpack(tab.mode == bestsMode and C.gold or C.menuText)) end
    if bestsMode == "guild" then fillGuild(p); return end
    for _, key in ipairs(Board.PRESET_ORDER) do
        local row = p.rows[key]
        local best, played, won = statsFor(key)
        if best then
            row.time:SetText(bestTime(best))
            local who = bestName(best) or "?"
            if type(best.at) == "number" and best.at > 0 then who = who .. "  " .. DOT .. "  " .. GS.FormatDate(best.at) end
            row.who:SetText(who)
        else
            row.time:SetText("-")
            row.who:SetText(played > 0 and L["No win yet"] or L["Not played yet"])
        end
        row.record:SetText(played > 0 and string.format(L["won %d of %d"], won, played) or "")
    end
    p.rule:SetText(bestsRuleText())
end

local function buildBests()
    local p = Widgets.GlassPanel(win)
    p:SetFrameLevel(win:GetFrameLevel() + 30)           -- over the board and the end overlay, like the list
    p:SetSize(BESTS_W, 50 + TABS_H + #Board.PRESET_ORDER * BESTS_ROW + 26)
    p:SetPoint("TOP", ui.hud, "TOP", 0, 0)
    p:EnableMouse(true)                                  -- the board under it takes no clicks

    p.title = Glass.Font(p, 16, "LEFT")
    p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -14)
    p.title:SetTextColor(unpack(C.gold))
    p.title:SetText(L["Best times"])
    p.close = Widgets.IconButton(p, 20, T.close, { 1, 0.9, 0.9 })
    p.close:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, -8)
    p.close:setAccent(unpack(C.closeAccent))
    p.close:SetScript("OnClick", function() p:Hide() end)

    -- The tabs (#15): yours (the account's bests) and the guild's, on their own row under
    -- the title (beside it, a longer title, French « Meilleurs temps », ran into them).
    p.tabs = {}
    local prev
    for _, t in ipairs({ { "you", L["You"] }, { "guild", L["Guild"] } }) do
        local tab = Widgets.GlassButton(p, TAB_W, 20, { fontSize = 11 })
        if prev then tab:SetPoint("LEFT", prev, "RIGHT", 6, 0) else tab:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -38) end
        tab.mode = t[1]
        tab.label:SetText(t[2])
        tab:SetScript("OnClick", function()
            bestsMode = tab.mode
            if bestsMode == "guild" then GS.Social.QueryIfStale() end
            fillBests()
        end)
        p.tabs[t[1]] = tab
        prev = tab
    end

    p.rows = {}
    for i, key in ipairs(Board.PRESET_ORDER) do
        local col = Skin.DifficultyColor(key)
        local row = CreateFrame("Frame", nil, p)
        row:SetSize(BESTS_W - 20, BESTS_ROW - 4)
        row:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -44 - TABS_H - (i - 1) * BESTS_ROW)
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints(row)
        row.bg:SetColorTexture(1, 1, 1, 0.05)        -- neutral: rare blue on a blue tint was hard to read
        row.bar = row:CreateTexture(nil, "ARTWORK")
        row.bar:SetSize(3, BESTS_ROW - 12)
        row.bar:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.bar:SetColorTexture(col[1], col[2], col[3], 1)
        row.label = Glass.Font(row, 13, "LEFT")
        row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 11, -5)
        row.label:SetTextColor(col[1], col[2], col[3])
        row.label:SetText(LABELS[key])
        row.who = Glass.Font(row, 10, "LEFT")
        row.who:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -3)
        row.who:SetWidth(BESTS_W - 20 - 11 - 70)            -- a width, not a RIGHT point: that would set its middle too
        row.who:SetTextColor(unpack(C.menuText))
        row.time = Glass.Font(row, 18, "RIGHT")
        row.time:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -4)
        row.time:SetTextColor(unpack(C.gold))
        row.record = Glass.Font(row, 10, "RIGHT")
        row.record:SetPoint("TOPRIGHT", row.time, "BOTTOMRIGHT", 0, -2)
        row.record:SetTextColor(unpack(C.hint))
        -- On the Guild tab, the top of the guild in this difficulty.
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            if bestsMode ~= "guild" or not self.ranking or #self.ranking == 0 then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(LABELS[key])
            for i = 1, math.min(GUILD_TOP, #self.ranking) do
                local r = self.ranking[i]
                GameTooltip:AddLine(string.format("%d. %s  %s", i, r.name, csTime(r.cs)), 0.75, 0.78, 0.85)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        p.rows[key] = row
    end
    p.rule = Glass.Font(p, 10, "LEFT")
    p.rule:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 14, 10)
    p.rule:SetTextColor(unpack(C.hint))

    p:SetScript("OnShow", function()
        if bestsMode == "guild" then GS.Social.QueryIfStale() end   -- reopened on the Guild tab
        fillBests()
    end)
    Window.Floating(p)
    p:Hide()
    ui.bests = p
end

-- Something arrived from the guild (Social.lua): the Guild tab shows it.
function Window.SocialChanged()
    if ui.bests and ui.bests:IsShown() and bestsMode == "guild" then fillBests() end
end

-- Show (or, with no argument, toggle) the best times panel. Opens the window.
function Window.ShowBests(show)
    Window.Open()
    if not ui.bests then buildBests() end
    if show == nil then show = not ui.bests:IsShown() end
    ui.bests:SetShown(show)
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

    -- Title bar: the name and the tagline (no portrait: the mascot is the HUD's
    -- new-game face), then the icons: music, trophy, ?, gear, close.
    -- The gold lettering (#12). Its texture is 512x128 with transparent sides: crop to
    -- the drawn part (Skin.TITLE_CROP) so it lines up with the tagline, at its own shape.
    local title = win:CreateTexture(nil, "ARTWORK")
    title:SetSize(TITLE_W, TITLE_H)
    title:SetTexture(T.title)
    title:SetTexCoord(unpack(Skin.TITLE_CROP))
    title:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, -8)
    ui.title = title

    local tagline = Glass.Font(win, 11, "LEFT")
    tagline:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    tagline:SetTextColor(unpack(C.tagline))
    tagline:SetText(GS.TAGLINE)

    ui.close = Widgets.IconButton(win, 22, T.close, { 1, 0.9, 0.9 })
    ui.close:SetFrameLevel(content)
    ui.close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -10, -10)
    ui.close:setAccent(unpack(C.closeAccent))
    ui.close:SetScript("OnClick", function() win:Hide() end)
    Widgets.Tip(ui.close, L["Close"], L["Escape closes it too."])

    ui.gear = Widgets.IconButton(win, 22, T.gear, { 0.82, 0.92, 1 })
    ui.gear:SetFrameLevel(content)
    ui.gear:SetPoint("RIGHT", ui.close, "LEFT", -5, 0)
    ui.gear:SetScript("OnClick", function() GS.Options.Open() end)
    Widgets.Tip(ui.gear, L["Settings"], L["Opens Options > AddOns > Gnomesweeper: question marks, the first click, left-click clearing, the window size."])

    -- The music button: the note, greyed with a red slash when the music is off.
    ui.music = Widgets.IconButton(win, 22, T.music)
    ui.music:SetFrameLevel(content)
    ui.music.slash = ui.music:CreateTexture(nil, "OVERLAY", nil, 2)
    ui.music.slash:SetSize(16, 16)
    ui.music.slash:SetPoint("CENTER", ui.music, "CENTER", 0, 0)
    ui.music.slash:SetTexture(T.mute)
    ui.music:SetScript("OnClick", function() GS.Options.Set("music", not db().music) end)
    Widgets.Tip(ui.music, L["Gnomeregan music"], function()
        return { db().music and L["On: click to turn it off."] or L["Off: click to play it while the board is open."],
                 L["It never plays in combat."] }
    end)

    -- The sounds button (#55, owner): the speaker, beside the note, greyed and slashed when off.
    ui.sound = Widgets.IconButton(win, 22, T.sound)
    ui.sound:SetFrameLevel(content)
    ui.sound.slash = ui.sound:CreateTexture(nil, "OVERLAY", nil, 2)
    ui.sound.slash:SetSize(16, 16)
    ui.sound.slash:SetPoint("CENTER", ui.sound, "CENTER", 0, 0)
    ui.sound.slash:SetTexture(T.mute)
    ui.sound:SetScript("OnClick", function() GS.Options.Set("sounds", db().sounds == false) end)
    Widgets.Tip(ui.sound, L["Sounds"], function()
        return { db().sounds ~= false and L["On: click to mute the clicks, the bomb and the cheers."] or L["Muted: click to hear them again."],
                 L["The game's own sound settings apply too. The music has its own button."] }
    end)

    ui.trophy = Widgets.IconButton(win, 22, T.trophy)
    ui.trophy:SetFrameLevel(content)
    -- How to play: the ? with the other icons (owner), between the trophy and the gear.
    local help = Widgets.GlassButton(win, 22, 22, { square = true, fontSize = 13 })
    help:SetFrameLevel(content)
    help:SetPoint("RIGHT", ui.gear, "LEFT", -5, 0)
    help.label:SetText("?")
    Widgets.Tip(help, L["How to play"], {
        L["Left-click reveals a tile. Right-click plants a flag on a mine you've found."],
        L["Middle-click a revealed number (or hold left and right together) to reveal the tiles around it that aren't flagged."],
        L["It only works when the number of flags around it equals the number."],
        L["A wrong flag makes it reveal a mine, so check your flags first."],
        L["The gnome starts a new game; during a game, it gives this one up."],
    })
    ui.help = help

    ui.trophy:SetPoint("RIGHT", ui.help, "LEFT", -5, 0)
    ui.music:SetPoint("RIGHT", ui.trophy, "LEFT", -5, 0)
    ui.sound:SetPoint("RIGHT", ui.music, "LEFT", -5, 0)
    ui.trophy:setAccent(unpack(C.gold))
    ui.trophy:SetScript("OnClick", function() Window.ShowBests() end)
    Widgets.Tip(ui.trophy, L["Best times"], L["Your best at each difficulty, shared by all your characters."])

    -- Difficulty: a glass button in the difficulty's rarity colour, and the list it opens.
    ui.diff = Widgets.GlassButton(win, 150, 24, { fontSize = 13 })
    ui.diff:SetFrameLevel(content)
    ui.diff:SetPoint("TOP", win, "TOP", 0, -58)
    ui.diffArrow = ui.diff:CreateTexture(nil, "OVERLAY")
    ui.diffArrow:SetSize(14, 14)
    ui.diffArrow:SetTexture(T.arrow)
    ui.diffArrow:SetPoint("RIGHT", ui.diff, "RIGHT", -7, 0)
    ui.diff:SetScript("OnClick", function()
        ui.faceTip:Hide()                          -- it sits over this button the first time (#45)
        ui.menu:SetShown(not ui.menu:IsShown())
    end)
    Widgets.Tip(ui.diff, L["Difficulty"], difficultyTip)
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
    ui.face:SetScript("OnClick", function() playerNewGame() end)
    ui.burst = GS.Effects.Burst(hud, ui.face)          -- the win: a gold burst behind her (#10)
    ui.mascot = GS.Effects.Mascot(ui.face.face)        -- she moves: bounce, shudder, nod, breath (#48)

    -- The first launch's pointer at the face (#45, owner: a glass callout). Above her with an
    -- arrow down, never over the tiles; it passes clicks through except its own button.
    local tip = Widgets.GlassPanel(win)
    tip:SetFrameLevel(win:GetFrameLevel() + 31)
    tip:SetSize(FACE_TIP_W, FACE_TIP_H)
    tip:SetPoint("BOTTOM", ui.face, "TOP", 0, 10)
    tip.text = Glass.Font(tip, 11, "LEFT")
    tip.text:SetPoint("LEFT", tip, "LEFT", 10, 0)
    tip.text:SetWidth(FACE_TIP_W - 84)
    tip.text:SetWordWrap(true)
    tip.text:SetTextColor(unpack(C.menuText))
    tip.text:SetText(L["Click the gnome for a new game. During a game, it gives this one up."])
    tip.ok = Widgets.GlassButton(tip, 60, 22, { fontSize = 11 })
    tip.ok:SetPoint("RIGHT", tip, "RIGHT", -8, 0)
    tip.ok.label:SetText(L["Got it"])
    tip.ok:setAccent(unpack(C.gold))
    tip.ok:SetScript("OnClick", function() tip:Hide() end)
    tip.arrow = tip:CreateTexture(nil, "OVERLAY")
    tip.arrow:SetSize(14, 14)
    tip.arrow:SetPoint("TOP", tip, "BOTTOM", 0, 2)
    tip.arrow:SetTexture(T.arrow)
    tip.arrow:SetVertexColor(unpack(C.gold))
    Window.Floating(tip)                       -- one floating panel at a time: the list or Best times put it away
    tip:Hide()
    ui.faceTip = tip
    Widgets.Tip(ui.face, L["New game"], L["Same difficulty."])

    ui.timer = Glass.Font(hud, 22, "RIGHT")
    ui.timer:SetWidth(54)             -- "00:00" is about 47 wide; any more leaves a gap before the clock
    ui.timer:SetPoint("RIGHT", hud, "RIGHT", -10, 0)
    ui.timerFlash = GS.Effects.Flash(ui.timer)     -- the last 3 seconds before your best (#46)
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
    -- The surprised face while a tile is held (#10), only while the game can be played.
    Grid.Attach(grid, function(kind, i) Window.Dispatch(kind, i) end, function(on)
        local s = game and game:State()
        ui.face:setPressed(on and (s == "ready" or s == "playing"))
    end)

    -- The effects over the board (#10): above the tiles, under the end overlay (+15).
    local fx = CreateFrame("Frame", nil, win)
    fx:SetAllPoints(grid)
    fx:SetFrameLevel(win:GetFrameLevel() + 12)
    ui.fx = fx
    ui.smoke = GS.Effects.Smoke(fx)
    ui.fireworks = GS.Effects.Fireworks(fx)

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
        Window.shownCount = Window.shownCount + 1    -- Options: was it shown again since it stepped aside?
        game:Resume(GetTime())
        Window.Layout()
        Window.Refresh()
        GS.Sounds.UpdateMusic()
        GS.Sounds.Greet()
        -- The first time ever: point at the face (#45). Saved now, so it never comes back.
        if not db().seenFaceTip then
            db().seenFaceTip = true
            ui.faceTip:Show()
        end
    end)
    win:SetScript("OnHide", function(self)
        game:Pause(GetTime())
        for _, f in ipairs(floating) do f:Hide() end   -- none comes back over the board on the next open
        if ui.faceTip then ui.faceTip:Hide() end       -- nor the first launch's pointer (#45)
        Grid.Cancel()                  -- a button held when the window closes is not a click
        Grid.FinishShuffle()           -- a reopened board is never half-drawn
        ui.mascot.stop()               -- she's still while nobody sees her (#48)
        ui.face:setPressed(false, true) -- and not left surprised (no lingering on a closed window)
        GS.Sounds.Cancel()
        GS.Sounds.UpdateMusic()        -- the music is for the board: it stops with it
        self:StopMovingOrSizing()
    end)

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
    watcher:RegisterEvent("UI_SCALE_CHANGED")

    -- Hide in combat (#37, a setting, on by default): a fight puts the window away and
    -- its end brings it back, only if the fight is what hid it and the player didn't
    -- show or close it meanwhile (Window.shownCount, as the Settings step-aside does).
    -- Opened during a fight, it stays until the next one. Hiding pauses the clock,
    -- cancels a press and stops the music, as any close does.
    local combat = CreateFrame("Frame")
    combat:RegisterEvent("PLAYER_REGEN_DISABLED")
    combat:RegisterEvent("PLAYER_REGEN_ENABLED")
    combat:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            if db().hideInCombat ~= false and win:IsShown() then
                win:Hide()
                Window.combatHid = Window.shownCount
            end
        else
            local back = Window.combatHid ~= nil and Window.combatHid == Window.shownCount
            Window.combatHid = nil
            -- With Blizzard's Settings window open, it comes back when that closes instead.
            if back and not GS.Options.ReturnAfterSettings() then Window.Open() end
        end
    end)
    watcher:SetScript("OnEvent", function()
        Window.Layout()
        GS.Options.Refresh()          -- the settings say what size the window is shown at
    end)
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
    if #list > 0 and kind ~= "mark" then reveals = reveals + 1 end   -- flags are read off the board (#32)
    local state = game:State()
    recordScores(was, state)             -- first, so the refresh below shows a new best
    local newBest = state == "won" and was ~= "won" and lastWin and lastWin.new
    GS.Sounds.Action(kind, was, state, game:Cell(i), #list, newBest)
    if newBest and db().fireworks ~= false then
        local col = Skin.DifficultyColor(difficultyKey())
        ui.fireworks.play(ui.grid, { C.gold, col, { 1, 1, 1 } }, math.random)   -- the board has a size; fx only its anchors
        GS.Sounds.Fireworks()
    end
    Grid.Refresh(list)
    Window.Refresh()
    -- Only the action that ENDS the game brings the overlay up: a click on a
    -- finished board does nothing, and must not bring back one put away.
    -- The game ended (a right or middle click outside the list can do it): a question
    -- about throwing it away no longer applies.
    if (state == "won" or state == "lost") and state ~= was and ui.menu.confirm:IsShown() then ui.menu:Hide() end
    if (state == "won" or state == "lost") and state ~= was then
        Grid.SetInteractive(false)
        Window.ShowEnd()
        ui.mascot.play(state == "won" and "win" or "wipe")   -- #48
    end
    return list
end

------------------------------------------------------------
-- Entry points
------------------------------------------------------------

-- A new game the player asked for (the face, Play again, Try again): the
-- gnomish arm whirs and the tiles come back in a wave (#43). A difficulty
-- change or a setting starts one quietly.
function playerNewGame()
    if ui.faceTip then ui.faceTip:Hide() end       -- they found the gnome (#45)
    GS.Sounds.NewGame()
    Window.NewGame()
    Grid.Shuffle()
    if ui.mascot then ui.mascot.play("nod") end   -- with the arm (#48)
end

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
        Grid.SetTheme(db().theme)        -- the saved look (#14); a change later comes through SettingsChanged
        syncGame()
    end
end

-- A fresh game, at `preset` (remembered) or the current difficulty.
function Window.NewGame(preset)
    GS.Sounds.Cancel()                   -- the last game's gnome mustn't speak over the new one
    if ui.fireworks then ui.fireworks.stop() end
    if ui.mascot then ui.mascot.stop() end   -- the last game's bounce or shudder doesn't run on (#48)
    if preset and Board.PRESETS[preset] then db().difficulty = preset end
    newBoard()
    if ui.overlay then ui.overlay:Hide() end
    if ui.result then showResultBar(false) end
    if win then syncGame() end
    return game
end

-- A difficulty asked for while the open waits for Settings (`/gsweep expert`): kept
-- for that open, with the show count it was asked at, so one the player overrode
-- since (showing or closing the board) is dropped, not applied later (Codex, #58).
local deferred

function Window.Open(preset)
    ensure()
    -- Blizzard's Settings window is under ours (HIGH vs FULLSCREEN_DIALOG): a key, the
    -- compartment or /gsweep while it's open shows the board when it closes, not over
    -- it (review of #58). Whatever brings it then (Settings closing, or a fight's end
    -- after it) comes back here without a preset: the one asked for is used.
    if not win:IsShown() and GS.Options.ReturnAfterSettings() then
        deferred = { preset = preset or (deferred and deferred.preset), at = Window.shownCount }
        return
    end
    if not preset and deferred and deferred.at == Window.shownCount then preset = deferred.preset end
    deferred = nil
    local switch = preset and Board.PRESETS[preset] and preset ~= difficultyKey()
    -- Nothing to lose: the new board before showing (one layout, not two).
    if switch and not hasProgress() then Window.NewGame(preset); switch = false end
    win:Show()
    if switch then chooseDifficulty(preset) end           -- the same question as the list (#32)
end

function Window.Toggle()
    ensure()
    if win:IsShown() then win:Hide() else Window.Open() end
end

function Window.IsShown() return win ~= nil and win:IsShown() end

-- A panel that floats over the board: showing it puts the others away, and
-- closing the window closes it.
function Window.Floating(f)
    floating[#floating + 1] = f
    f:HookScript("OnShow", function(self)
        for _, o in ipairs(floating) do if o ~= self then o:Hide() end end
    end)
end

-- After a setting changed (Options.Set): what the window shows that depends on one.
-- (The best times refill whenever they show, and can't be open while Settings is.)
-- After the best times were reset (Options): nothing to beat in this game, and
-- whatever shows them shows none.
function Window.ScoresReset()
    beat, passed = nil, false
    if win then paintClock() end          -- no best any more: no warning colour
    if ui.bests and ui.bests:IsShown() then fillBests() end
end

function Window.SettingsChanged()
    Grid.SetTheme(db().theme)              -- the board's look (#14); Grid keeps it until it has tiles
    GS.Social.SettingsChanged()            -- the guild-best toasts (#17)
    if not win then return end
    Window.Refresh()
    GS.Sounds.UpdateMusic()
end

-- The player's own scale (/gsweep scale), nil to go back to 1. The window still
-- never exceeds the screen: the number wanted and the number shown can differ.
-- Saved even before the window exists (the Options page can set it first); it
-- is applied when the window is built.
function Window.SetScale(n)
    db().scale = n
    if win then Window.Layout() end
end

-- The scale wanted, and the one actually in use.
function Window.ScaleInfo()
    ensure()
    return db().scale or 1, Window.scale
end

-- /gsweep bomb (for measuring, #21): replays the end panel's model (the bomb on a
-- wipe, Tally on a win) without ending another game, to judge it by eye. Says why
-- when it can't.
function Window.TestBomb()
    if not Window.IsShown() then return "open the board first (/gsweep)." end
    if not GS.Models.Enabled() then return "3D models are off in the settings." end
    if not (ui.overlay and ui.overlay:IsShown()) then
        return "end a game first (a wipe for the bomb, a win for Tally): this replays the panel's model."
    end
    ui.slot.stop()
    Window.EndModel()
    local c = GS.Models.CAST[game:State() == "won" and "win" or "wipe"]
    -- Its steps as "1 (1.5 s), 6 (held, lift 24)", to judge each by eye.
    local steps = {}
    for _, s in ipairs(c.steps) do
        steps[#steps + 1] = string.format("%d (%s%s)", s[1], s[2] and string.format("%.2f s", s[2]) or "held",
            s.lift and (", lift " .. s.lift) or "")
    end
    return string.format("display %d: %s%s; drawn %d units tall (tiles are 24).", c.display,
        table.concat(steps, ", "), c.loop and ", again" or "", GS.Models.HEIGHT)
end

-- Where a model would go (#20's probe, #21): the face button, and the effects
-- layer over the tiles (above them, under the end overlay). nil before the window
-- is built.
function Window.ModelHosts()
    return ui.face, ui.fx
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
    clockState = function() return clockState end,
    menu = function() return ui.menu end,
    details = details,
    -- Swap in a hand-built board (Board._test.FromLayout), to test exact shapes.
    -- It keeps no scores unless given a category (Scores.Category) to keep them in.
    SetGame = function(b, cat)
        game = b
        Window.game = b
        category, lastWin = cat, nil
        if ui.mascot then ui.mascot.stop() end
        reveals = b:State() == "playing" and 1 or 0        -- a hand-built board is past its first reveal
        local best = cat and type(db().scores) == "table" and Scores.Best(db().scores, cat)
        beat, passed = best and best.time or nil, false
        rule = cat and cat:match(":(%a+)$") or (db().safeZone == "cell" and "cell" or "area")
        if ui.overlay then ui.overlay:Hide() end
        if ui.result then showResultBar(false) end
        if win then syncGame() end
    end,
}
