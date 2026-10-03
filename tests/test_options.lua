-- Options.lua: the settings (#8). One place that changes them, and the one place
-- to set them: Options > AddOns > Gnomesweeper (the gear opens it), with an About
-- sub-page.
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
-- The gear opens Options > AddOns > Gnomesweeper; the window steps aside
----------------------------------------------------------------------------
do
    local W, O = fresh()
    local ui = W._test.ui
    WoW.chat = {}
    press(ui.gear)
    eq(WoW.settings.opened, nil, "before login there is no page to open")
    check(WoW.chat[#WoW.chat]:find("Options > AddOns > Gnomesweeper", 1, true) ~= nil, "...so it says where the settings are")

    WoW.fire("PLAYER_LOGIN")
    press(ui.gear)
    eq(WoW.settings.opened, "cat:Gnomesweeper", "the gear opens the Gnomesweeper page")
    check(SettingsPanel:IsShown(), "...in Blizzard's Settings window")
    check(not W.win:IsShown(), "our window steps aside (it would draw over Settings)")
    SettingsPanel:Hide()
    check(W.win:IsShown(), "closing Settings brings it back")

    WoW.slash("/gsweep settings")
    check(SettingsPanel:IsShown() and not W.win:IsShown(), "/gsweep settings does the same")
    SettingsPanel:Hide()
    check(W.win:IsShown(), "...and back")

    -- Settings opened from the game menu, with the window open: the same.
    SettingsPanel:Show()
    check(not W.win:IsShown(), "Settings opened any other way: the window steps aside too")
    SettingsPanel:Hide()
    check(W.win:IsShown(), "...and comes back")

    -- A window that was closed stays closed.
    W.win:Hide()
    SettingsPanel:Show(); SettingsPanel:Hide()
    check(not W.win:IsShown(), "a window that was closed is not opened by closing Settings")

    -- Its clock doesn't run while it is away.
    W.Open()
    local tiles = Gnomesweeper.Grid._test.tiles
    WoW.now = 100
    tiles[41]._scripts.OnMouseDown(tiles[41], "LeftButton"); tiles[41]._scripts.OnMouseUp(tiles[41], "LeftButton", true)
    eq(W.game:State(), "playing", "(a game in progress)")
    WoW.now = 110
    SettingsPanel:Show()
    WoW.now = 500
    SettingsPanel:Hide()
    WoW.now = 505
    check(math.abs(W.game:Elapsed(WoW.now) - 15) < 1e-9, "the clock is paused while Settings is open")
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

    -- A change made elsewhere (a slash command) shows on the page.
    WoW.slash("/gsweep scale reset")
    eq(c.scale.value:GetText(), "100%", "a slash command's change shows on the open page")
    -- The best times shown when the window comes back follow the rule changed here.
    c.safeZone.radios[2]._scripts.OnClick(c.safeZone.radios[2])
    WoW.slash("/gsweep scores")
    eq(W._test.ui.bests.rule:GetText(), "First click: one safe tile (Windows XP's rule).", "the best times follow the rule changed here")

    -- The About sub-page, under this one.
    local sub = WoW.settings.subs[1]
    check(sub ~= nil, "an About page is registered")
    eq(sub.parent, cat, "...under the Gnomesweeper page")
    eq(sub.name, "About", "...named About")
    eq(#WoW.settings.subs, 1, "...once")
    local about = O._test.about
    about:Hide(); about:Show()
    eq(about.title:GetText(), "Gnomesweeper", "it has the name")
    eq(about.tagline:GetText(), "One wrong click. Full wipe.", "...the tagline")
    check(about.version:GetText():find("^Version dev ") ~= nil, "...the version (dev for an unpackaged copy)")
    local cmds = {}
    for _, fs in ipairs(about.commands) do cmds[#cmds + 1] = fs:GetText() end
    cmds = table.concat(cmds, "\n")
    check(cmds:find("/gsweep scores", 1, true) ~= nil, "...the commands")
    -- Links: read-only boxes to copy from.
    eq(#about.links, 2, "two links")
    eq(about.links[1]:GetText(), "https://www.curseforge.com/wow/addons/gnomesweeper", "CurseForge")
    eq(about.links[2]:GetText(), "https://github.com/Spotnick2/Gnomesweeper", "GitHub")
    local box = about.links[1]
    eq(box._type, "EditBox", "...in edit boxes")
    box._scripts.OnEditFocusGained(box)
    check(box._selected, "a click selects the whole link, ready for Ctrl+C")
    box:SetText("https://evil.example")
    box._scripts.OnTextChanged(box, true)
    eq(box:GetText(), "https://www.curseforge.com/wow/addons/gnomesweeper", "typing puts the link back")
    check(box._selected, "...selected again")
    box._scripts.OnEditFocusLost(box)
    check(not box._selected, "losing focus clears the selection")
    box._scripts.OnTextChanged(box, false)
    eq(box:GetText(), "https://www.curseforge.com/wow/addons/gnomesweeper", "(a change by the code itself is left alone)")
    check(cmds:find("/gsweep perf", 1, true) == nil and cmds:find("/gsweep assets", 1, true) == nil,
        "...but not the ones for measuring")
end

do  -- the first show builds the pages (owner: About was blank the first time, fine the second)
    loadAddon()
    WoW.fire("PLAYER_LOGIN")
    local O = Gnomesweeper.Options
    check(not O._test.page:IsShown() and not O._test.about:IsShown(), "both pages start hidden")
    O._test.about:Show()                                    -- the first time Settings shows it
    check(O._test.about.title ~= nil, "About is built on its very first show")
    O._test.page:Show()
    check(O._test.page.controls ~= nil, "...and so is the main page")
end

do  -- a packaged copy shows its version
    loadAddon()
    WoW.metadata.Version = "v1.2.0"
    WoW.fire("PLAYER_LOGIN")
    local about = Gnomesweeper.Options._test.about
    about:Hide(); about:Show()
    check(about.version:GetText():find("^Version v1.2.0 ") ~= nil, "the About page shows a packaged version")
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

do  -- the review of #39
    -- Off the grid (a /gsweep scale value): the next point each way, no step skipped.
    local W, O = fresh()
    GnomesweeperDB.scale = 1.27; O.StepScale(1)
    eq(GnomesweeperDB.scale, 1.3, "127% up is 130%")
    GnomesweeperDB.scale = 1.27; O.StepScale(-1)
    eq(GnomesweeperDB.scale, 1.2, "127% down is 120%")
    GnomesweeperDB.scale = 1.23; O.StepScale(-1)
    eq(GnomesweeperDB.scale, 1.2, "123% down is 120%")
    GnomesweeperDB.scale = 1.2; O.StepScale(1)
    eq(GnomesweeperDB.scale, 1.3, "on the grid, up a whole step")
    O.Set("scale", 1)

    -- Settings open: asking for the board (/gsweep, the key, the compartment) doesn't draw
    -- it over Settings; it comes when Settings closes (review of #58).
    WoW.fire("PLAYER_LOGIN")
    W.win:Hide()
    SettingsPanel:Show()
    WoW.slash("/gsweep")
    check(not W.win:IsShown(), "asked for while Settings is open: not drawn over it")
    SettingsPanel:Hide()
    check(W.win:IsShown(), "...it opens when Settings closes")
    W.win:Hide()
    SettingsPanel:Show()
    W.Toggle()                                           -- the key binding's call
    check(not W.win:IsShown(), "the key while Settings is open: waits too")
    SettingsPanel:Hide()
    check(W.win:IsShown(), "...and opens after")

    -- A difficulty asked for meanwhile is kept for that open (Codex, #58).
    W.win:Hide()
    W.NewGame("beginner")
    SettingsPanel:Show()
    WoW.slash("/gsweep expert")
    check(not W.win:IsShown(), "/gsweep expert while Settings is open: waits")
    SettingsPanel:Hide()
    check(W.win:IsShown(), "...opens when Settings closes")
    eq(GnomesweeperDB.difficulty, "expert", "...at the difficulty asked for")
    eq(W.game.w, 30, "...an Expert board")

    -- With progress: the same question as ever, after Settings closes.
    local B = Gnomesweeper.Board
    W._test.SetGame(B._test.FromLayout({ "*..", "...", "..." }))
    local t = Gnomesweeper.Grid._test.tiles[2]
    t._scripts.OnMouseDown(t, "LeftButton"); t._scripts.OnMouseUp(t, "LeftButton", true)   -- a second reveal: progress
    local g = W.game
    W.win:Hide()
    SettingsPanel:Show()
    WoW.slash("/gsweep intermediate")
    SettingsPanel:Hide()
    check(W.win:IsShown(), "a game with progress: the board opens when Settings closes")
    eq(W.game, g, "...the game kept")
    check(W._test.ui.menu.confirm:IsShown(), "...and it asks before switching, as ever")
    W._test.ui.menu:Hide()

    -- Overridden meanwhile (the player opens the board, then closes it): dropped.
    W.win:Hide()
    W.NewGame("beginner")
    SettingsPanel:Show()
    WoW.slash("/gsweep expert")
    W.win:Show(); W.win:Hide()                           -- the player's own open and close
    SettingsPanel:Hide()
    check(not W.win:IsShown(), "overridden by the player: Settings closing doesn't open it")
    W.Open()
    eq(GnomesweeperDB.difficulty, "beginner", "...and a later open doesn't apply the old request")

    -- Through a fight: Settings closed mid-fight hands the open to the fight's end, preset and all.
    W.win:Hide()
    SettingsPanel:Show()
    WoW.slash("/gsweep expert")
    WoW.inCombat = true
    WoW.fire("PLAYER_REGEN_DISABLED")
    SettingsPanel:Hide()
    check(not W.win:IsShown(), "Settings closed mid-fight: still waiting")
    WoW.inCombat = false
    WoW.fire("PLAYER_REGEN_ENABLED")
    check(W.win:IsShown(), "...the fight's end opens it")
    eq(GnomesweeperDB.difficulty, "expert", "...at the difficulty asked for")
    W.NewGame("beginner")

    -- Stepped aside, then the player closes it by the key (it's hidden: the key asks to open
    -- it, so it waits again) - and Settings closing brings it, once.
    SettingsPanel:Show()
    check(not W.win:IsShown(), "(stepped aside)")
    SettingsPanel:Hide()
    check(W.win:IsShown(), "(back)")
end

do  -- the Options page never builds the window
    loadAddon()
    WoW.fire("PLAYER_LOGIN")
    local page = Gnomesweeper.Options._test.page
    page:Hide(); page:Show()
    eq(Gnomesweeper.Window.win, nil, "showing the Options page doesn't build the game window")
    page.controls.scale.plus._scripts.OnClick(page.controls.scale.plus)
    eq(GnomesweeperDB.scale, 1.1, "...a size set there is saved")
    eq(Gnomesweeper.Window.win, nil, "...without building it either")
    WoW.slash("/gsweep")
    eq(Gnomesweeper.Window.ScaleInfo(), 1.1, "...and the window uses it when it is built")
    eq(rawget(_G, "GnomesweeperOptions"), nil, "no global for the page")
    eq(rawget(_G, "GnomesweeperAbout"), nil, "...nor for About")
end

do  -- the version on a client without C_AddOns, or with the old global
    loadAddon()
    local API = Gnomesweeper.API
    local saved = C_AddOns
    C_AddOns = nil
    eq(API.AddOnVersion("Gnomesweeper"), "dev", "no C_AddOns: dev, no error")
    GetAddOnMetadata = function(_, key) return key == "Version" and "v0.9" or nil end
    eq(API.AddOnVersion("Gnomesweeper"), "v0.9", "...the old global if it is there")
    GetAddOnMetadata = nil
    C_AddOns = saved
    WoW.metadata.Version = ""
    eq(API.AddOnVersion("Gnomesweeper"), "dev", "an empty version: dev")
end

do  -- resetting the best times: two clicks (owner: "a wipe high score button")
    loadAddon({ db = { scores = { version = 1, ["beginner:area"] = { played = 9, won = 7, best = { time = 21.2 } } } } })
    WoW.fire("PLAYER_LOGIN")
    local page = Gnomesweeper.Options._test.page
    page:Show()
    local b = page.reset
    eq(b:GetText(), "Reset best times...", "the settings page has the reset button")
    b._scripts.OnClick(b)
    check(GnomesweeperDB.scores ~= nil, "one click resets nothing")
    eq(b:GetText(), "Click again to reset", "...it asks for a second click")
    WoW.advance(6)
    eq(b:GetText(), "Reset best times...", "...and forgets it after a few seconds")
    b._scripts.OnClick(b)
    WoW.advance(6)
    b._scripts.OnClick(b)
    check(GnomesweeperDB.scores ~= nil, "a second click too late arms it again, not resets")
    WoW.chat = {}
    b._scripts.OnClick(b)
    eq(GnomesweeperDB.scores, nil, "two clicks in time: every best and count is gone")
    eq(b:GetText(), "Reset best times...", "...the button is back to its label")
    local said = false
    for _, line in ipairs(WoW.chat) do if line:find("best times reset", 1, true) then said = true end end
    check(said, "...and chat says so")
    WoW.advance(10)
    eq(b:GetText(), "Reset best times...", "...and no late timer changes it")

    -- A stale timer mustn't disarm a newer arming: arm, reset, arm again quickly.
    GnomesweeperDB.scores = { version = 1 }
    b._scripts.OnClick(b)                                -- arm (timer due at +5)
    WoW.advance(1)
    b._scripts.OnClick(b)                                -- reset
    WoW.advance(1)
    b._scripts.OnClick(b)                                -- arm again (its own timer due at +5 from here)
    WoW.advance(3.5)                                     -- the first timer has come due
    eq(b:GetText(), "Click again to reset", "an old arming's timer doesn't disarm the newer one")

    -- The board forgets the best to beat, and the best times panel shows none.
    WoW.slash("/gsweep scores")
    eq(Gnomesweeper.Window._test.ui.bests.rows.beginner.time:GetText(), "-", "the best times panel shows none")
end

do  -- after a reset, the alert has nothing to beat
    loadAddon({ db = { scores = { version = 1, ["beginner:area"] = { played = 3, won = 1, best = { time = 20 } } } } })
    WoW.fire("PLAYER_LOGIN")
    WoW.slash("/gsweep")
    local W = Gnomesweeper.Window
    WoW.now = 100
    local t = Gnomesweeper.Grid._test.tiles[41]
    t._scripts.OnMouseDown(t, "LeftButton"); t._scripts.OnMouseUp(t, "LeftButton", true)
    local page = Gnomesweeper.Options._test.page
    page:Show()
    page.reset._scripts.OnClick(page.reset); page.reset._scripts.OnClick(page.reset)
    WoW.sounds = {}
    WoW.now = 130; WoW.tick(0.2)
    eq(#WoW.sounds, 0, "a game going past the old best after a reset: no alert")
end

do  -- the page scrolls (owner: it outgrew the Settings canvas)
    loadAddon()
    WoW.fire("PLAYER_LOGIN")
    local page = Gnomesweeper.Options._test.page
    page:Show()
    local scroll, canvas = page.scroll, page.canvas
    eq(scroll._type, "ScrollFrame", "the page is a scroll frame")
    eq(scroll._template, "UIPanelScrollFrameTemplate", "...Blizzard's, with its scroll bar")
    eq(canvas._parent, scroll, "...its contents on a canvas inside it")
    eq(page.controls.questionMarks.check._parent, canvas, "the controls are on the canvas, so they scroll")
    eq(page.reset._parent, canvas, "...the reset button too")
    check(canvas:GetHeight() > 500, "the canvas is as tall as what's on it (" .. canvas:GetHeight() .. ")")
    local scaleNote = page.controls.scale.note._points[1]
    eq(scaleNote[2], page.controls.scale.plus, "the size's note sits beside its buttons, not on a row of its own")
end

done("test_options")
