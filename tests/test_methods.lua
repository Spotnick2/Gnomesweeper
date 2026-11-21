-- Every widget method the addon calls must exist on this client: WowTestKit's
-- exact Type:Method check (Kit.checkMethods), against the build tests/kit.pin names.
--
-- The kit's widgets answer only the build's methods (and the stub's), so a call to
-- one the build lacks fails where it's made; one the stub implements but the
-- widget's type lacks (FontString:SetTexCoord) is recorded, and the check below
-- fails it. This exercises the addon as widely as is cheap, then checks.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

-- The addon calls many client methods through pcall (the model scenes' setters,
-- the templates, the libraries): a method this build lacks reads as nil there, the
-- call fails inside the pcall, and nothing is recorded for Kit.checkMethods to see.
-- Every error a pcall catches during the exercise is kept: there must be none.
local swallowed = {}
do
    local corePcall = pcall
    local function keep(ok, ...)
        if not ok then swallowed[#swallowed + 1] = tostring((...)) end
        return ok, ...
    end
    function pcall(f, ...) return keep(corePcall(f, ...)) end
end

-- Exercise everything, so every method is recorded.
loadAddon()
local W = Gnomesweeper.Window
WoW.slash("/gsweep")
local win, ui = W.win, W._test.ui
for _, key in ipairs({ "expert", "intermediate", "beginner" }) do
    ui.diff._scripts.OnClick(ui.diff)
    local menu = W._test.menu()
    WoW.mouseDown = true
    WoW.tick()
    WoW.mouseDown = false
    ui.diff._scripts.OnClick(ui.diff)
    for _, c in ipairs(menu._children) do
        if c._type == "Button" and c.label:GetText():lower() == key then c._scripts.OnClick(c) end
    end
end
for _, b in ipairs({ ui.gear, ui.face }) do
    b._scripts.OnEnter(b)
    b._scripts.OnLeave(b)
end
ui.face._scripts.OnClick(ui.face)
W.game:Reveal(5, 5, 1)
W.Refresh()
WoW.tick(0.2)
-- The tiles: every kind of click, a flood, a chord, a loss, the measuring commands.
do
    local G = Gnomesweeper.Grid._test
    local function press(i, button)
        local t = G.tiles[i]
        t._scripts.OnMouseDown(t, button)
        t._scripts.OnMouseUp(t, button, true)
    end
    W.NewGame("beginner")
    press(1, "RightButton")                               -- a flag
    press(41, "LeftButton")                               -- a reveal and a flood
    press(41, "MiddleButton")                             -- a chord attempt
    local t = G.tiles[41]
    t._scripts.OnMouseDown(t, "LeftButton"); t._scripts.OnMouseDown(t, "RightButton")
    t._scripts.OnMouseUp(t, "LeftButton", true); t._scripts.OnMouseUp(t, "RightButton", true)
    WoW.slash("/gsweep perf")
    WoW.slash("/gsweep input")
    press(2, "LeftButton")
    WoW.slash("/gsweep input")
    -- End a game on a mine, on a hand-built board (a random one might put the mine under a flag).
    W._test.SetGame(Gnomesweeper.Board._test.FromLayout({ "..*..", "..*..", "..*..", "..*.." }))
    press(3, "LeftButton")
    -- The overlay: the loss above built it; use it, then a win.
    local o = W._test.ui.overlay
    o._scripts.OnMouseUp(o)
    o:Show()
    o.button._scripts.OnClick(o.button)
    W._test.SetGame(Gnomesweeper.Board.New(30, 16, 0))
    press(1, "LeftButton")                                -- no mines: one click wins
    o.bests._scripts.OnClick(o.bests)                     -- the win panel's Best times (#67)
    o.button._scripts.OnClick(o.button)
    W.NewGame("expert")
    W.NewGame("beginner")
end

-- The glass controls and the polish: hover, press, tooltips, the help, the result bar, scale.
do
    local ui = W._test.ui
    local function press(i, button)
        local t = Gnomesweeper.Grid._test.tiles[i]
        t._scripts.OnMouseDown(t, button)
        t._scripts.OnMouseUp(t, button, true)
    end
    for _, b in ipairs({ ui.diff, ui.close, ui.gear, ui.help }) do
        b._scripts.OnMouseDown(b, "LeftButton"); b._scripts.OnMouseUp(b, "LeftButton", true)
    end
    for _, b in ipairs({ ui.diff, ui.help, ui.close, ui.gear, ui.face }) do
        if b._scripts.OnEnter then b._scripts.OnEnter(b); b._scripts.OnLeave(b) end
    end
    W.NewGame("expert")                                 -- the list's Expert row, the rarity colours
    W._test.SetGame(Gnomesweeper.Board._test.FromLayout({ "..*..", "..*..", "..*..", "..*.." }))
    press(3, "LeftButton")                              -- a loss: the burst, the soot, the overlay
    ui.overlay.view._scripts.OnClick(ui.overlay.view)   -- See the field: the result bar
    ui.result.button._scripts.OnClick(ui.result.button)
    WoW.slash("/gsweep scale 1.2"); WoW.slash("/gsweep scale"); WoW.slash("/gsweep scale reset")
    WoW.slash("/gsweep scores")                         -- the best times panel (#7)
    do                                                  -- the settings (#8): every control, About
        local O = Gnomesweeper.Options
        WoW.fire("PLAYER_LOGIN")
        WoW.slash("/gsweep settings")
        SettingsPanel:Hide()
        local page = O._test.page
        page:Hide(); page:Show()
        page.controls.questionMarks.check._scripts.OnClick(page.controls.questionMarks.check)
        page.controls.safeZone.radios[1]._scripts.OnClick(page.controls.safeZone.radios[1])
        page.controls.scale.plus._scripts.OnClick(page.controls.scale.plus)
        O._test.about:Hide(); O._test.about:Show()
        O.Set("safeZone", "area"); O.Set("questionMarks", false); O.Set("scale", 1)
    end
    local bests = Gnomesweeper.Window._test.ui.bests
    bests.close._scripts.OnClick(bests.close)
    do                                                  -- the model probe (#20): sheet, viewer, perf
        WoW.modelSetFails[6977] = nil
        WoW.modelBoxes[6977] = { -0.5, -0.4, -0.6, 0.5, 0.4, 0.6 }
        WoW.modelBoxes["unit:player"] = { -0.3, -0.3, -0.5, 0.3, 0.3, 0.5 }
        WoW.slash("/gsweep models")
        WoW.advance(3.5)
        local P = Gnomesweeper.ModelProbe._test
        P.cells[1]._scripts.OnClick(P.cells[1])
        WoW.advance(0.5)
        local v = P.viewer()
        v.next._scripts.OnClick(v.next); v.prev._scripts.OnClick(v.prev)
        v.sparks._scripts.OnClick(v.sparks)
        WoW.slash("/gsweep models perf")
        for _ = 1, 700 do WoW.tick(0.016) end
        WoW.advance(1)
        for _ = 1, 700 do WoW.tick(0.016) end
        P.sheet():Hide()
    end
    WoW.slash("/gsweep assets")                         -- the contact sheet (#6)
    local sheet = Gnomesweeper.Assets._test.sheet()
    sheet._scripts.OnDragStart(sheet); sheet._scripts.OnDragStop(sheet)
    sheet.close._scripts.OnClick(sheet.close)
    W.NewGame("beginner")
end

win._scripts.OnDragStart(win)
win._left, win._top = 100, 500
win._scripts.OnDragStop(win)
WoW.fire("DISPLAY_SIZE_CHANGED")
WoW.fire("UI_SCALE_CHANGED")
win:Hide()
win:Show()
WoW.slash("/gsweep reset")
WoW.slash("/gsweep help")
WoW.slash("/gsweep")

-- The Options page's fallback art, as on a client missing the templates. A new
-- session resets the client, and with it the calls recorded so far: keep them.
local recordedSoFar = WoW.methodsCalled
loadAddon()
for pair in pairs(recordedSoFar) do WoW.methodsCalled[pair] = true end
WoW.missingTemplates = { UICheckButtonTemplate = true, UIRadioButtonTemplate = true, UIPanelButtonTemplate = true }
Gnomesweeper.Options._test.page:Hide()
Gnomesweeper.Options._test.page:Show()

-- Global functions the addon calls through the strict _G are, by construction,
-- defined in the stub; confirm each is a real one.
local functions, globals = Kit.data("functions"), Kit.data("globals")
for _, name in ipairs({ "GetTime", "IsMouseButtonDown", "CreateFrame", "CreateColor",
        "GetFileIDFromPath", "GetBuildInfo", "UnitName", "GetRealmName", "time", "date",
        "PlaySound", "PlayMusic", "StopMusic", "UnitAffectingCombat", "UnitSex" }) do
    check(functions[name] or globals[name], "global function exists on Forever " .. Kit.BUILD .. ": " .. name)
end

eq(#swallowed, 0, "no error was swallowed by a pcall during the exercise: " .. tostring(swallowed[1]))

-- A model scene's actor is checked like any widget: the kit has its methods (WowTestKit #90).
local recorded = Kit.checkMethods()
-- The floor: what loading and the exercise record today, rounded down, so the
-- exercise can't quietly shrink.
check(recorded >= 180, "the exercise reached the windows (" .. recorded .. " recorded)")

-- FINDING (#95): /gsweep help printed once, its three lines with a bare "|".
eq(acceptKnownStrays(), 3, "the help's known stray | lines (#95), and no other")
done("test_methods")
