-- Every widget method the addon calls must exist on this client.
--
-- The stub answers ANY method call as a recorded no-op, so a call to a method
-- Forever lacks would otherwise pass silently. This exercises the addon, then
-- checks each recorded "Type:Method" against the API dump's widget-method
-- walk. Skipped (loudly) when the dump isn't on this machine.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local DUMP = os.getenv("GNOMESWEEPER_API_DUMP") or "C:/Projects/References/forever-api-1.60.1.70205.md"
local f = io.open(DUMP, "r")
if not f then
    io.write("test_methods: SKIPPED (no API dump at " .. DUMP .. ")\n")
    os.exit(0)
end
local widget, globals = {}, {}
local inWidgets, inGlobals = false, false
for line in f:lines() do
    if line:match("^## ") then
        inWidgets = line:match("^## Widget methods") ~= nil
        inGlobals = line:match("^## Documented functions") ~= nil or line:match("^## Global functions") ~= nil
    elseif inWidgets then
        local m = line:match("^(%a+:[%w_]+)%s*$")
        if m then widget[m] = true end
    elseif inGlobals then
        -- Documented functions carry a signature; the walk of _G is bare names.
        local g = line:match("^([%a_][%w_]*)%(") or line:match("^([%a_][%w_]*)%s*$")
        if g then globals[g] = true end
    end
end
f:close()
check(next(widget) ~= nil, "parsed the dump's widget methods")

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
WoW.settle()                       -- the new game arrives after the lead and the wave (#43)
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
    o._scripts.OnEnter(o); o._scripts.OnLeave(o)
    o._scripts.OnMouseUp(o)
    o:Show()
    o.button._scripts.OnClick(o.button)
    WoW.settle()                       -- the new game arrives after the lead and the wave (#43)
    W._test.SetGame(Gnomesweeper.Board.New(30, 16, 0))
    press(1, "LeftButton")                                -- no mines: one click wins
    o.button._scripts.OnClick(o.button)
    WoW.settle()                       -- the new game arrives after the lead and the wave (#43)
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
    WoW.settle()                       -- the new game arrives after the lead and the wave (#43)
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

-- The Options page's fallback art, as on a client missing the templates.
loadAddon()
WoW.missingTemplates = { UICheckButtonTemplate = true, UIRadioButtonTemplate = true, UIPanelButtonTemplate = true }
Gnomesweeper.Options._test.page:Hide()
Gnomesweeper.Options._test.page:Show()

-- Global functions the addon calls through the strict _G are, by construction,
-- defined in the stub; confirm each is a real one.
for _, name in ipairs({ "GetTime", "IsMouseButtonDown", "CreateFrame", "CreateColor",
        "GetFileIDFromPath", "GetBuildInfo", "UnitName", "GetRealmName", "time", "date",
        "PlaySound", "PlayMusic", "StopMusic", "UnitAffectingCombat", "UnitSex" }) do
    check(globals[name], "global function exists on Forever: " .. name)
end

local n = 0
for name in pairs(WoW.methodsCalled) do
    n = n + 1
    check(widget[name], "method exists on Forever: " .. name)
end
check(n >= 25, "recorded the addon's method calls (" .. n .. ")")
done("test_methods")
