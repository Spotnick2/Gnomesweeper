-- Options.lua: the settings (#8). One place that changes them, the glass panel
-- behind the gear, and the page in Options > AddOns.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local function fresh(db)
    loadAddon({ db = db })
    math.randomseed(7)
    WoW.slash("/gsweep")
    return Gnomesweeper.Window, Gnomesweeper.Options
end

local function tile(i) return Gnomesweeper.Grid._test.tiles[i] end
local function click(i, b)
    local t = tile(i)
    t._scripts.OnMouseDown(t, b or "LeftButton")
    t._scripts.OnMouseUp(t, b or "LeftButton", true)
end
local function press(b) b._scripts.OnClick(b, "LeftButton") end

----------------------------------------------------------------------------
-- Options.Set: checks, saves, applies
----------------------------------------------------------------------------
do
    local W, O = fresh()
    eq(O.Set("questionMarks", "yes"), false, "a toggle takes only true or false")
    eq(O.Set("safeZone", "everywhere"), false, "a choice only its choices")
    eq(O.Set("scale", 3), false, "the scale only 0.5 to 1.5")
    eq(O.Set("scale", 0 / 0), false, "...never NaN")
    eq(O.Set("volume", 1), false, "an unknown setting is refused")
    eq(GnomesweeperDB.questionMarks, false, "...and nothing changed")
    eq(GnomesweeperDB.safeZone, "area", "...nothing")
    eq(GnomesweeperDB.scale, nil, "...nothing")

    -- Question marks, before the first reveal: the game is replaced, so it applies now.
    local before = W.game
    eq(O.Set("questionMarks", true), true, "question marks on")
    eq(GnomesweeperDB.questionMarks, true, "...saved")
    check(W.game ~= before, "...and a game not started yet is replaced at once")
    click(41, "RightButton"); click(41, "RightButton")
    eq(W.game:Cell(41).state, "question", "...so a second right-click now makes a ?")

    -- Re-picking the same value changes nothing (Codex review: it replaced the board).
    W.NewGame()
    local same = W.game
    eq(O.Set("questionMarks", true), true, "the value it already has is accepted")
    eq(W.game, same, "...and the board is kept")

    -- Marks placed before the first reveal are kept: the board isn't replaced.
    W.NewGame()
    local marked = W.game
    click(5, "RightButton")
    eq(W.game:Cell(5).state, "flag", "(a flag before the first reveal)")
    O.Set("safeZone", "cell")
    eq(W.game, marked, "a board with a flag on it is never replaced")
    eq(W.game:Cell(5).state, "flag", "...the flag stays")
    O.Set("safeZone", "area")
    click(5, "RightButton"); click(5, "RightButton")          -- flag, ?, clear

    -- Mid-game: the game is kept; the next one has it.
    click(41)
    eq(W.game:State(), "playing", "(a game in progress)")
    local playing = W.game
    O.Set("questionMarks", false)
    eq(W.game, playing, "a game in progress is never thrown away")
    W.NewGame()
    click(41, "RightButton"); click(41, "RightButton")
    eq(W.game:Cell(41).state, "covered", "...the next game has the change")

    -- The first-click rule: a new category, and the list and tooltip follow.
    local fresh2 = W.game
    O.Set("safeZone", "cell")
    eq(GnomesweeperDB.safeZone, "cell", "the first-click rule is saved")
    check(W.game ~= fresh2, "...and applies at once to a game not started")
    click(41)
    eq(GnomesweeperDB.scores["beginner:cell"].played, 1, "...its games count under its own rule")

    -- Left-click clearing: read on every click, nothing to restart.
    local g = W.game
    O.Set("chordOnLeft", true)
    eq(GnomesweeperDB.chordOnLeft, true, "left-click clearing is saved")
    eq(W.game, g, "...and needs no new game")

    -- The scale, by steps.
    eq(O.StepScale(1), true, "one step up")
    eq(GnomesweeperDB.scale, 1.1, "...is 110%")
    O.StepScale(-1); O.StepScale(-1)
    eq(GnomesweeperDB.scale, 0.9, "two down is 90%")
    for _ = 1, 20 do O.StepScale(1) end
    eq(GnomesweeperDB.scale, 1.5, "it stops at 150%")
    for _ = 1, 20 do O.StepScale(-1) end
    eq(GnomesweeperDB.scale, 0.5, "...and at 50%")
    O.Set("scale", 1)
    eq(GnomesweeperDB.scale, nil, "100% is no saved scale at all")
    GnomesweeperDB.scale = 1.23
    O.StepScale(1)
    eq(GnomesweeperDB.scale, 1.3, "a scale set by /gsweep scale steps onto the grid")
    GnomesweeperDB.scale = 1.46
    O.StepScale(1)
    eq(GnomesweeperDB.scale, 1.5, "...and a step past the top lands on it, not refused")
    GnomesweeperDB.scale = 0.54
    O.StepScale(-1)
    eq(GnomesweeperDB.scale, 0.5, "...the bottom too")
end

----------------------------------------------------------------------------
-- The glass panel (the gear)
----------------------------------------------------------------------------
do
    local W, O = fresh()
    local ui = W._test.ui
    eq(O._test.panel(), nil, "the panel is built only when asked for")
    press(ui.gear)
    local p = O._test.panel()
    check(p and p:IsShown(), "the gear opens the settings")
    eq(p.title:GetText(), "Settings", "...titled")
    eq(p:GetFrameLevel(), W.win:GetFrameLevel() + 30, "...over the board, with the list and the best times")
    check(p._mouse, "...and the board under it takes no clicks")
    local c = p.controls

    eq(c.questionMarks.switch.label:GetText(), "Off", "it shows question marks off")
    eq(c.questionMarks.note:GetText(), "Right-click: flag, then ?, then clear.", "...with what it does")
    press(c.questionMarks.switch)
    eq(GnomesweeperDB.questionMarks, true, "the switch turns them on")
    eq(c.questionMarks.switch.label:GetText(), "On", "...and says so")
    eq(c.questionMarks.switch.accent[1], Gnomesweeper.Skin.RARITY.uncommon[1], "...in green")

    check(c.safeZone.buttons[1].selected and not c.safeZone.buttons[2].selected, "the first click: opens an area")
    press(c.safeZone.buttons[2])
    eq(GnomesweeperDB.safeZone, "cell", "the other button: one safe tile")
    check(c.safeZone.buttons[2].selected and not c.safeZone.buttons[1].selected, "...and it is the one marked")
    eq(c.safeZone.buttons[2].label._textColor[1], Gnomesweeper.Skin.COLORS.gold[1], "...in gold")

    press(c.chordOnLeft.switch)
    eq(GnomesweeperDB.chordOnLeft, true, "left-click clearing on")

    eq(c.scale.value:GetText(), "100%", "the window size")
    press(c.scale.plus)
    eq(c.scale.value:GetText(), "110%", "+ makes it bigger")
    press(c.scale.minus); press(c.scale.minus)
    eq(c.scale.value:GetText(), "90%", "- smaller")
    eq(c.scale.note:GetText(), "", "...no note while it fits")
    WoW.setScreen(500, 380)
    WoW.fire("DISPLAY_SIZE_CHANGED")
    check(c.scale.note:GetText():find("^Shown at %d+%% so it fits the screen%.$") ~= nil, "a smaller screen: the open panel says the size it is shown at")
    WoW.setScreen(1920, 1080)
    WoW.fire("UI_SCALE_CHANGED")
    eq(c.scale.note:GetText(), "", "...and drops it when it fits again")

    -- A change made elsewhere shows at once.
    WoW.slash("/gsweep scale reset")
    eq(c.scale.value:GetText(), "100%", "a slash command's change shows in the open panel")

    -- One floating panel at a time.
    press(ui.diff)
    check(ui.menu:IsShown() and not p:IsShown(), "the difficulty list puts the settings away")
    press(ui.gear)
    check(p:IsShown() and not ui.menu:IsShown(), "...and the settings put the list away")
    press(ui.trophy)
    check(ui.bests:IsShown() and not p:IsShown(), "the best times put the settings away")
    press(ui.gear)
    check(p:IsShown() and not ui.bests:IsShown(), "...and the other way round")
    press(ui.gear)
    check(not p:IsShown(), "the gear again closes it")
    WoW.slash("/gsweep settings")
    check(p:IsShown(), "/gsweep settings opens it")
    W.win:Hide()
    check(not p:IsShown(), "closing the window closes it")
    WoW.slash("/gsweep")
    check(not p:IsShown(), "...so it doesn't come back over the board")
    WoW.slash("/gsweep settings")
    press(p.close)
    check(not p:IsShown(), "its close button closes it")
end

----------------------------------------------------------------------------
-- Options > AddOns > Gnomesweeper
----------------------------------------------------------------------------
do
    local W, O = fresh()
    eq(O._test.category(), nil, "nothing is registered before login")
    WoW.fire("PLAYER_LOGIN")
    local cat = O._test.category()
    check(cat ~= nil, "at login the page is registered with the Settings framework")
    eq(cat.name, "Gnomesweeper", "...as Gnomesweeper")
    eq(WoW.settings.addons[1], cat, "...under AddOns")
    WoW.fire("PLAYER_LOGIN")
    eq(#WoW.settings.canvas, 1, "...once")
    eq(O.OpenPage(), true, "it can be opened")
    eq(WoW.settings.opened, "cat:Gnomesweeper", "...to its own category")

    local page = O._test.page
    page:Hide(); page:Show()                                -- the Settings window shows it
    local c = page.controls
    eq(c.questionMarks.check:GetChecked(), false, "a check box per toggle, showing the saved value")
    eq(c.questionMarks.check._template, "UICheckButtonTemplate", "...the client's check box")
    c.questionMarks.check:SetChecked(true)
    c.questionMarks.check._scripts.OnClick(c.questionMarks.check)
    eq(GnomesweeperDB.questionMarks, true, "ticking it sets it")
    c.questionMarks.check:SetChecked(false)
    c.questionMarks.check._scripts.OnClick(c.questionMarks.check)
    eq(GnomesweeperDB.questionMarks, false, "...unticking clears it")
    c.questionMarks.check:SetChecked(true)
    c.questionMarks.check._scripts.OnClick(c.questionMarks.check)
    check(c.safeZone.radios[1]:GetChecked() and not c.safeZone.radios[2]:GetChecked(), "radio buttons for the first click")
    c.safeZone.radios[2]._scripts.OnClick(c.safeZone.radios[2])
    eq(GnomesweeperDB.safeZone, "cell", "...picking one sets it")
    check(c.safeZone.radios[2]:GetChecked() and not c.safeZone.radios[1]:GetChecked(), "...and only it is checked")
    press(c.scale.plus)
    eq(c.scale.value:GetText(), "110%", "the size, with - and +")
    WoW.setScreen(500, 380); W.Layout(); O.Refresh()
    check(c.scale.note:GetText():find("^Shown at %d+%% so it fits the screen%.$") ~= nil, "...and the size it is shown at on a small screen")
    WoW.setScreen(1920, 1080); W.Layout(); O.Refresh()
    eq(c.scale.note:GetText(), "", "...nothing when it fits")

    -- The open best times follow a rule changed on this page.
    O.Set("safeZone", "area")
    WoW.slash("/gsweep scores")
    local bests = W._test.ui.bests
    eq(bests.rule:GetText(), "First click: always opens an area.", "(the best times, open)")
    c.safeZone.radios[2]._scripts.OnClick(c.safeZone.radios[2])
    eq(bests.rule:GetText(), "First click: one safe tile (Windows XP's rule).", "an open best times panel follows the rule changed here")

    -- Both views are one: a change in the glass panel shows on this page.
    WoW.slash("/gsweep settings")
    press(Gnomesweeper.Options._test.panel().controls.chordOnLeft.switch)
    eq(c.chordOnLeft.check:GetChecked(), true, "a change in the gear's panel shows on the page")
end

do  -- a client without the templates: our own art, nothing missing
    loadAddon()
    WoW.missingTemplates = { UICheckButtonTemplate = true, UIRadioButtonTemplate = true, UIPanelButtonTemplate = true }
    local page = Gnomesweeper.Options._test.page
    page:Hide(); page:Show()
    local c = page.controls
    eq(c.questionMarks.check:GetNormalTexture()._texture, "Interface\\Buttons\\UI-CheckBox-Up", "a check box from the client's art")
    eq(c.questionMarks.check:GetCheckedTexture()._texture, "Interface\\Buttons\\UI-CheckBox-Check", "...with its tick")
    eq(c.safeZone.radios[1]:GetNormalTexture()._texture, "Interface\\Buttons\\UI-RadioButton", "a radio from the client's art")
    c.questionMarks.check:SetChecked(true)
    c.questionMarks.check._scripts.OnClick(c.questionMarks.check)
    eq(GnomesweeperDB.questionMarks, true, "...and it still works")
end

done("test_options")
