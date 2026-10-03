-- #37: hide the window in combat (a setting, on by default), and bring it back
-- after, only if the fight is what hid it.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local function fresh(db)
    db = db or {}
    db.seenFaceTip = true
    loadAddon({ db = db })
    math.randomseed(7)
    WoW.slash("/gsweep")
    return Gnomesweeper.Window
end
local function tile(i) return Gnomesweeper.Grid._test.tiles[i] end
local function click(i)
    local t = tile(i)
    t._scripts.OnMouseDown(t, "LeftButton")
    t._scripts.OnMouseUp(t, "LeftButton", true)
end
local function pull() WoW.fire("PLAYER_REGEN_DISABLED") end
local function leave() WoW.fire("PLAYER_REGEN_ENABLED") end

do
    local W = fresh()
    eq(GnomesweeperDB.hideInCombat, true, "on by default")

    -- A fight puts it away, its end brings it back; the clock doesn't count the fight.
    WoW.now = 100
    click(41)
    WoW.now = 110
    pull()
    check(not W.win:IsShown(), "a fight puts the window away")
    WoW.now = 500
    leave()
    check(W.win:IsShown(), "...and its end brings it back")
    check(math.abs(W.game:Elapsed(505) - 15) < 1e-9, "...the clock paused through the fight (10 s before, 5 after)")
    eq(W.game:State(), "playing", "...the game where it was")

    -- Closed by the player before the fight: stays closed.
    W.win:Hide()
    pull(); leave()
    check(not W.win:IsShown(), "a window already closed stays closed after the fight")

    -- Closed by the player during the fight: stays closed.
    W.Open()
    pull()
    WoW.slash("/gsweep")                                 -- opened mid-fight...
    check(W.win:IsShown(), "opened during a fight: it opens (an explicit request wins)")
    W.win:Hide()                                         -- ...then closed again
    leave()
    check(not W.win:IsShown(), "...and closed again: the fight's end doesn't bring it back")

    -- Opened during a fight: it stays until the next one.
    pull()                                               -- (closed: nothing to hide)
    WoW.slash("/gsweep")
    check(W.win:IsShown(), "opened mid-fight")
    leave()
    check(W.win:IsShown(), "...it stays open after the fight")
    pull()
    check(not W.win:IsShown(), "...and the next fight puts it away")
    leave()
    check(W.win:IsShown(), "...and brings it back")
end

do  -- a press held when the fight starts fires nothing
    local W = fresh()
    local t = tile(41)
    t._scripts.OnMouseDown(t, "LeftButton")
    pull()
    t._scripts.OnMouseUp(t, "LeftButton", true)          -- the release arrives (capture)
    eq(W.game:State(), "ready", "a press interrupted by a fight reveals nothing")
    leave()
end

do  -- the floating panels go with it
    local W = fresh()
    local ui = W._test.ui
    ui.diff._scripts.OnClick(ui.diff)
    check(ui.menu:IsShown(), "(the difficulty list open)")
    pull()
    check(not ui.menu:IsShown(), "a fight closes the list with the window")
    leave()
    check(not ui.menu:IsShown(), "...it doesn't come back open")
end

do  -- the setting off: the window stays up
    local W = fresh({ hideInCombat = false })
    pull()
    check(W.win:IsShown(), "the setting off: the window stays in combat")
    leave()
    check(W.win:IsShown(), "...and after")

    -- /gsweep combat toggles it and says so.
    WoW.chat = {}
    WoW.slash("/gsweep combat")
    eq(GnomesweeperDB.hideInCombat, true, "/gsweep combat turns it on")
    local said = false
    for _, line in ipairs(WoW.chat) do if line:find("hide in combat on", 1, true) then said = true end end
    check(said, "...and says so")
    pull()
    check(not W.win:IsShown(), "...and the next fight puts it away")
    leave()

    -- The settings page has the switch.
    WoW.fire("PLAYER_LOGIN")
    local page = Gnomesweeper.Options._test.page
    page:Show()
    local cb = page.controls.hideInCombat.check
    eq(cb:GetChecked(), true, "the settings page has the switch")
    cb:SetChecked(false); cb._scripts.OnClick(cb)
    eq(GnomesweeperDB.hideInCombat, false, "...unticking it turns it off")
end

do  -- with Blizzard's Settings window open: our window already stepped aside; the fight isn't the one to bring it back
    local W = fresh()
    WoW.fire("PLAYER_LOGIN")
    SettingsPanel:Show()
    check(not W.win:IsShown(), "(stepped aside for Settings)")
    pull(); leave()
    check(not W.win:IsShown(), "a fight while Settings is open doesn't bring the window back")
    SettingsPanel:Hide()
    check(W.win:IsShown(), "...closing Settings does")
end

done("test_combat")
