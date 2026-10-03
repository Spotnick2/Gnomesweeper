-- #36: localization. The mechanism (Locales\enUS.lua), French (Locales\frFR.lua),
-- every key in the code translated with the same placeholders, and a guard: in a
-- pseudo-language that brackets every translated string, every text the addon
-- shows (on every screen it has) must be bracketed. Anything that isn't is a
-- string that bypassed L.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local function readFile(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

----------------------------------------------------------------------------
-- The mechanism, in English
----------------------------------------------------------------------------
do
    loadAddon()
    local GS = Gnomesweeper
    eq(GS.L["Field cleared!"], "Field cleared!", "English: a key reads back as itself")
    eq(GS.L["anything at all"], "anything at all", "...any key, so a missing translation shows English, never nil")
    eq(GS.Decimal("%.1f", 0.8), "0.8", "English decimals: a point")
    eq(GS.FormatDate(os.time({ year = 2026, month = 10, day = 3, hour = 12 })), "3 Oct 2026", "an English date")
    eq(GS.TAGLINE, "One wrong click. Full wipe.", "the tagline")
end

----------------------------------------------------------------------------
-- French
----------------------------------------------------------------------------
local NBSP = "\194\160"
do
    loadAddon({ locale = "frFR" })
    local GS = Gnomesweeper
    eq(GS.L["Field cleared!"], "Champ déminé" .. NBSP .. "!", "French: translated, with a non-breaking space before !")
    eq(GS.L["Beginner"], "Débutant", "...the difficulties")
    eq(GS.L["not a key"], "not a key", "...a missing entry still shows English")
    eq(GS.Decimal("%.1f", 0.8), "0,8", "French decimals: a comma")
    eq(GS.FormatDate(os.time({ year = 2026, month = 10, day = 3, hour = 12 })), "3 oct. 2026", "a French date")
    eq(GS.Layout.FormatTenths(42.6, 999, GS.LOCALE.decimal), "00:42,6", "a time to the tenth: 00:42,6")
    eq(GS.TAGLINE, "Un mauvais clic, c'est le wipe" .. NBSP .. "!", "the tagline (the owner's)")
    eq(BINDING_NAME_GNOMESWEEPER_TOGGLE, "Ouvrir ou fermer le plateau", "the key binding's line")
    -- The difficulty keys saved stay English: the saved-data contract.
    WoW.slash("/gsweep expert")
    eq(GnomesweeperDB.difficulty, "expert", "a saved value stays a key, never translated text")
    eq(Gnomesweeper.Window._test.ui.diff.label:GetText(), "Expert", "(and the button shows the translation)")
    WoW.slash("/gsweep intermediate")
    eq(Gnomesweeper.Window._test.ui.diff.label:GetText(), "Intermédiaire", "...Intermédiaire")
end
do  -- the TOC's French note, for the AddOns list
    local toc = readFile("Gnomesweeper.toc")
    check(toc:find("## Notes-frFR:", 1, true) ~= nil, "the TOC has a French note for the AddOns list")
    local a = toc:find("Compat.lua", 1, true)
    local b = toc:find("Locales\\enUS.lua", 1, true)
    local c = toc:find("Locales\\frFR.lua", 1, true)
    local d = toc:find("Glass.lua", 1, true)
    check(a and b and c and d and a < b and b < c and c < d, "the locales load after Compat.lua, before anything with text")
end

----------------------------------------------------------------------------
-- Every key in the code has a French entry, with the same placeholders
----------------------------------------------------------------------------
local function keysInCode()
    local keys, n = {}, 0
    for _, file in ipairs(tocFiles()) do
        if not file:match("^Locales/") then
            for raw in readFile(file):gmatch('L%["(.-)"%]') do
                local key = assert(loadstring('return "' .. raw .. '"'))()     -- the literal as Lua reads it
                if not keys[key] then keys[key] = file; n = n + 1 end
            end
        end
    end
    -- Options' theme labels go through L too (Skin keeps them as keys).
    for _, key in ipairs({ "Classic", "Modern" }) do if not keys[key] then keys[key] = "Skin.lua"; n = n + 1 end end
    return keys, n
end
local function directives(s)
    local list = {}
    for d in s:gmatch("%%[%-%d%.]*[%a%%]") do list[#list + 1] = d end
    return table.concat(list, " ")
end
do
    loadAddon({ locale = "frFR" })
    local L = Gnomesweeper.L
    local keys, n = keysInCode()
    check(n > 100, "the code's keys were found (" .. n .. ")")
    local missing = {}
    for key, file in pairs(keys) do
        local fr = rawget(L, key)
        if not fr then
            missing[#missing + 1] = file .. ": " .. key
        else
            eq(directives(fr), directives(key), "French keeps the placeholders, in order: " .. key)
        end
    end
    table.sort(missing)
    for _, m in ipairs(missing) do check(false, "no French for " .. m) end
    eq(#missing, 0, "every key in the code has a French entry")
    -- And no French entry is left over from a key the code no longer uses.
    local stale = {}
    for key in pairs(L) do if not keys[key] then stale[#stale + 1] = key end end
    table.sort(stale)
    for _, k in ipairs(stale) do check(false, "a French entry no code uses: " .. k) end
end

----------------------------------------------------------------------------
-- The guard: a pseudo-language that brackets every translated string
----------------------------------------------------------------------------
local OPEN, CLOSE = "\226\159\166", "\226\159\167"       -- the brackets: U+27E6, U+27E7
local function untranslated(text)
    if type(text) ~= "string" or text == "" then return nil end
    -- Innermost pair first, repeatedly: a translated string can hold another ("Start %s?").
    local rest = text
    while true do
        local o
        local from = 1
        while true do
            local f = rest:find(OPEN, from, true)
            if not f then break end
            o, from = f, f + 1
        end
        local c = o and rest:find(CLOSE, o, true)
        if not c then break end
        rest = rest:sub(1, o - 1) .. " " .. rest:sub(c + #CLOSE)
    end
    rest = rest:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")              -- colour codes
    rest = rest:gsub("https?://%S+", " ")                                     -- the About page's links
    for word in rest:gmatch("%a%a+") do
        -- Names and data, not text: the brand, the links' names, an unpackaged version, the
        -- player who set a best, and a date's month (GS.LOCALE.months: French is tested above).
        local DATA = { Gnomesweeper = true, Gnome = true, sweeper = true, CurseForge = true, GitHub = true, dev = true,
                       Fizzle = true, Sprocketwhistle = true }
        for _, m in ipairs(Gnomesweeper.LOCALE.months) do DATA[m] = true end
        if not DATA[word] then
            return word
        end
    end
    return nil
end

do
    loadAddon({
        db = {},
        afterFile = function(file)
            if file == "Locales/enUS.lua" then
                setmetatable(Gnomesweeper.L, { __index = function(_, k) return OPEN .. k .. CLOSE end })
            end
        end,
    })
    local GS = Gnomesweeper
    local W = GS.Window
    local seen, bad = {}, {}
    local function look(where, text)
        local word = untranslated(text)
        if word and not seen[text] then
            seen[text] = true
            bad[#bad + 1] = where .. ": " .. text
        end
    end
    local function sweep(where)
        for _, w in ipairs(WoW.widgets) do
            if w._shown ~= false and w._text and w._text ~= "" and w._type ~= "GameTooltip" then
                look(where .. " (" .. w._type .. ")", w._text)
            end
        end
    end
    local function hoverAll(where)
        for _, w in ipairs(WoW.widgets) do
            local enter = w._scripts and w._scripts.OnEnter
            if enter then
                GameTooltip._lines = {}
                GameTooltip._text = ""
                pcall(enter, w)
                look(where .. " tooltip", GameTooltip._text)
                for _, line in ipairs(GameTooltip._lines or {}) do look(where .. " tooltip", line) end
            end
        end
    end
    local function tile(i) return GS.Grid._test.tiles[i] end
    local function click(i, b)
        local t = tile(i)
        t._scripts.OnMouseDown(t, b or "LeftButton")
        t._scripts.OnMouseUp(t, b or "LeftButton", true)
    end

    -- The window, first launch (the pointer at the face), the list, the question.
    WoW.slash("/gsweep")
    sweep("the window")
    W._test.ui.diff._scripts.OnClick(W._test.ui.diff)
    sweep("the difficulty list")
    W._test.SetGame(GS.Board._test.FromLayout({ "*..", "...", "..." }), "beginner:area")
    click(2); click(4, "RightButton")
    W._test.ui.diff._scripts.OnClick(W._test.ui.diff)
    W._test.ui.rows.expert._scripts.OnClick(W._test.ui.rows.expert)
    sweep("the question")
    W._test.ui.menu:Hide()
    hoverAll("the window")

    -- A win (a first one, then a new best, then one that doesn't beat it), the result bar.
    WoW.now = 100
    W._test.SetGame(GS.Board._test.FromLayout({ "*.." }), "beginner:area")
    WoW.now = 110
    click(2); click(3)
    sweep("a first win")
    W.DismissEnd()
    sweep("the result bar after a win")
    W._test.SetGame(GS.Board._test.FromLayout({ "*.." }), "beginner:area")
    WoW.now = 200
    click(2); WoW.now = 200.4; click(3)
    sweep("a new best")
    W.DismissEnd()
    sweep("the result bar after a new best")
    W._test.SetGame(GS.Board._test.FromLayout({ "*.." }), "beginner:area")
    WoW.now = 300
    click(2); WoW.now = 330; click(3)
    sweep("a win that doesn't beat the best")
    hoverAll("the end overlay")

    -- A wipe.
    W._test.SetGame(GS.Board._test.FromLayout({ "*..", "..*" }), "beginner:area")
    click(2); click(4, "RightButton"); click(1)
    sweep("a wipe")
    W.DismissEnd()
    sweep("the result bar after a wipe")

    -- The best times, both rules.
    W.ShowBests(true)
    sweep("the best times")
    GnomesweeperDB.safeZone = "cell"
    W.NewGame()
    W.ShowBests(true)
    sweep("the best times, one safe tile")

    -- The settings and About.
    WoW.fire("PLAYER_LOGIN")
    local page = GS.Options._test.page
    page:Show()
    sweep("the settings")
    page.reset._scripts.OnClick(page.reset)
    sweep("the reset button, armed")
    GS.Options._test.about:Show()
    sweep("About")

    -- The minimap button's and the compartment's tooltips.
    local tip = { lines = {} }
    function tip:AddLine(text) self.lines[#self.lines + 1] = text end
    WoW.ldb.objects.Gnomesweeper.OnTooltipShow(tip)
    for _, line in ipairs(tip.lines) do look("the minimap tooltip", line) end

    -- The chat: help and every message a player can get.
    WoW.chat = {}
    for _, cmd in ipairs({ "help", "nonsense", "music", "music", "combat", "combat", "minimap", "minimap",
                           "reset", "scale", "scale 1.2", "scale 9", "scale reset" }) do
        WoW.slash("/gsweep " .. cmd)
    end
    for _, line in ipairs(WoW.chat) do
        if not line:find("(for measuring)", 1, true) then look("chat", line) end   -- the probes stay English
    end

    eq(BINDING_NAME_GNOMESWEEPER_TOGGLE:sub(1, #OPEN), OPEN, "the key binding's name goes through L")
    for _, b in ipairs(bad) do check(false, "text that bypasses L: " .. b) end
    eq(#bad, 0, "every text on every screen goes through L")
end

done("test_locale")
