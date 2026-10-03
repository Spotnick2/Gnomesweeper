-- Minimap.lua: the minimap button (#40). LibDBIcon and LibDataBroker are the
-- stub's recording fakes (the real Libs\ are not loaded in tests).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local function chatHas(text)
    for _, line in ipairs(WoW.chat) do if line:find(text, 1, true) then return true end end
    return false
end

do
    loadAddon()
    local M = Gnomesweeper.Minimap
    eq(type(GnomesweeperDB.minimap), "table", "its saved table exists from the start (LibDBIcon's own shape)")
    eq(M._test.registered(), false, "nothing is registered before login")
    WoW.fire("PLAYER_LOGIN")
    eq(M._test.registered(), true, "at login the button is registered")
    eq(WoW.ldbi.registered.Gnomesweeper, GnomesweeperDB.minimap, "...with LibDBIcon, keeping its place in GnomesweeperDB.minimap")
    local obj = WoW.ldb.objects.Gnomesweeper
    eq(obj.type, "launcher", "...as a LibDataBroker launcher")
    eq(obj.icon, Gnomesweeper.Skin.TEXTURES.face, "...with the mascot's face")
    WoW.fire("PLAYER_LOGIN")
    eq(WoW.ldbi.registrations, 1, "a second login event registers nothing twice")

    local button = WoW.ldbi:GetMinimapButton("Gnomesweeper")
    check(button:IsShown(), "it is shown by default")
    eq(Gnomesweeper.Window.IsShown(), false, "(the board is closed)")
    button._scripts.OnClick(button, "LeftButton")
    eq(Gnomesweeper.Window.IsShown(), true, "left-click opens the board")
    button._scripts.OnClick(button, "LeftButton")
    eq(Gnomesweeper.Window.IsShown(), false, "...and closes it")
    button._scripts.OnClick(button, "RightButton")
    eq(WoW.settings.opened, "cat:Gnomesweeper", "right-click opens the settings")

    local tip = { lines = {} }
    function tip:AddLine(text) self.lines[#self.lines + 1] = text end
    obj.OnTooltipShow(tip)
    eq(tip.lines[1], "Gnomesweeper", "the tooltip names it")
    eq(tip.lines[2], "Left-click: play", "...says what a left-click does")
    eq(tip.lines[3], "Right-click: settings", "...and a right-click")

    -- A setting, through Options.Set.
    local O = Gnomesweeper.Options
    eq(O.Get("minimapButton"), true, "the setting reads shown")
    eq(O.Set("minimapButton", false), true, "it can be hidden")
    check(not button:IsShown(), "...the button goes")
    eq(GnomesweeperDB.minimap.hide, true, "...saved in LibDBIcon's table")
    eq(O.Get("minimapButton"), false, "...and the setting reads hidden")
    eq(O.Set("minimapButton", "no"), false, "a value that isn't true or false is refused")
    O.Set("minimapButton", true)
    check(button:IsShown(), "shown again")

    -- The settings page has it.
    local page = O._test.page
    page:Show()
    local cb = page.controls.minimapButton.check
    eq(cb:GetChecked(), true, "the settings page has a check box for it")
    cb:SetChecked(false); cb._scripts.OnClick(cb)
    check(not button:IsShown(), "...unticking hides the button")
    cb:SetChecked(true); cb._scripts.OnClick(cb)

    -- /gsweep minimap
    WoW.chat = {}
    WoW.slash("/gsweep minimap")
    check(not button:IsShown(), "/gsweep minimap hides it")
    check(chatHas("hidden: /gsweep minimap brings it back"), "...and says how to bring it back")
    WoW.slash("/gsweep minimap")
    check(button:IsShown(), "...and again shows it")
    check(chatHas("minimap button shown."), "...saying so")
end

do  -- hidden in the saved file: it stays hidden
    loadAddon({ db = { minimap = { hide = true, minimapPos = 123 } } })
    WoW.fire("PLAYER_LOGIN")
    check(not WoW.ldbi:GetMinimapButton("Gnomesweeper"):IsShown(), "a button saved hidden starts hidden")
    eq(GnomesweeperDB.minimap.minimapPos, 123, "...and its saved place is kept")
    eq(Gnomesweeper.Options.Get("minimapButton"), false, "...and the setting says so")
end

do  -- a damaged saved table is replaced
    loadAddon({ db = { minimap = "junk" } })
    eq(type(GnomesweeperDB.minimap), "table", "a minimap entry that isn't a table is replaced")
end

do  -- no libraries: no button, nothing else breaks
    loadAddon()
    local real = LibStub
    LibStub = function() error("no such library") end
    WoW.fire("PLAYER_LOGIN")
    LibStub = real
    eq(Gnomesweeper.Minimap._test.registered(), false, "without the libraries there is no button")
    Gnomesweeper.Minimap.Apply()
    check(true, "...and showing or hiding it is a no-op, not an error")
    WoW.slash("/gsweep")
    check(Gnomesweeper.Window.IsShown(), "...and the game still opens")
end

done("test_minimap")
