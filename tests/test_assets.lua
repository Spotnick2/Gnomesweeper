-- Assets.lua: /gsweep assets, the contact sheet of every texture (#6).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local function chatHas(text)
    for _, line in ipairs(WoW.chat) do
        if line:find(text, 1, true) then return true end
    end
    return false
end

loadAddon()
local A, Skin, Glass = Gnomesweeper.Assets, Gnomesweeper.Skin, Gnomesweeper.Glass
local T = Skin.TEXTURES

----------------------------------------------------------------------------
-- Kinds
----------------------------------------------------------------------------
eq(A.Kind(T.flag), "media", "our own file in Media/ is media")
eq(A.Kind(T.gear), "path", "a client texture path is a path")
eq(A.Kind(T.mine), "fileID", "a number is a client file ID")
eq(A.Kind(nil), "unknown", "anything else is unknown")
eq(A.Kind(Glass.MEDIA .. "x"), "media", "anything under our Media/ is ours")

----------------------------------------------------------------------------
-- The survey
----------------------------------------------------------------------------
do
    WoW.fileIDs = { [T.gear] = 136243 }
    local entries = A.Survey()
    local n = 0
    for _ in pairs(T) do n = n + 1 end
    eq(#entries, n, "every texture the skin names is surveyed")
    for i = 2, #entries do check(entries[i - 1].key < entries[i].key, "...in key order (" .. entries[i].key .. ")") end
    local byKey = {}
    for _, e in ipairs(entries) do byKey[e.key] = e end
    eq(byKey.gear.fileID, 136243, "a path the client knows has its file ID")
    eq(byKey.gear.checked, true, "...and is marked as checked")
    eq(byKey.flag.fileID, nil, "what the client says for our own file is recorded (here: nothing)")
    eq(byKey.flag.checked, true, "...after asking")
    eq(byKey.mine.checked, nil, "a file ID isn't asked about: getters echo anything")
    eq(#A.Missing(entries), 0, "nothing is missing")

    WoW.fileIDs = {}
    local missing = A.Missing(A.Survey())
    eq(#missing, 1, "a client path the client doesn't know is missing")
    eq(missing[1].key, "gear", "...the gear")
    check(#A.Missing(A.Survey()) == 1, "...and our own files are never called missing on GetFileIDFromPath's word")
end

do   -- a GetFileIDFromPath that throws is a failed check, not a crash
    local real = GetFileIDFromPath
    GetFileIDFromPath = function() error("boom") end
    local entries = A.Survey()
    for _, e in ipairs(entries) do
        if e.kind == "path" then eq(e.checked, false, "a throwing check is recorded as not checked") end
    end
    eq(#A.Missing(entries), 0, "...and is not reported as missing")
    GetFileIDFromPath = real
end

----------------------------------------------------------------------------
-- The sheet
----------------------------------------------------------------------------
do
    loadAddon()
    A, Skin, T = Gnomesweeper.Assets, Gnomesweeper.Skin, Gnomesweeper.Skin.TEXTURES
    WoW.fileIDs = { [T.gear] = 136243 }
    check(rawget(_G, "GnomesweeperAssets") == nil, "nothing is built until it is asked for")
    WoW.slash("/gsweep assets")
    local sheet = A._test.sheet()
    check(sheet ~= nil and sheet:IsShown(), "/gsweep assets shows the sheet")
    eq(sheet:GetFrameStrata(), "FULLSCREEN_DIALOG", "...over the game")
    local special = 0
    for _, name in ipairs(UISpecialFrames) do if name == "GnomesweeperAssets" then special = special + 1 end end
    eq(special, 1, "...and Escape closes it")

    local cells, entries = A._test.cells, A.Survey()
    eq(#cells, #entries, "one cell per texture")
    for i, e in ipairs(entries) do
        if e.key == "title" then
            check(cells[i].picture._width > cells[i].picture._height * 3, "the title keeps its wide shape on the sheet")
        end
        eq(cells[i].picture._texture, e.value, "cell " .. i .. " draws " .. e.key)
        eq(cells[i].name:GetText(), e.key, "...and is labelled with its name")
    end
    local byKey = {}
    for i, e in ipairs(entries) do byKey[e.key] = cells[i] end
    eq(byKey.gear.state:GetText(), "path: file 136243", "a known client path shows its file ID")
    eq(byKey.mine.state:GetText(), "client id " .. tostring(T.mine), "a file ID says so")
    eq(byKey.flag.state:GetText(), "ours", "our own file says so")

    check(chatHas("textures on the sheet"), "it reports in chat")
    check(chatHas("Client paths it doesn't have: none"), "...that no client path is missing")

    -- Saved, for a /reload to write out.
    local probe = GnomesweeperDB.assetProbe
    eq(probe.build, "1.60.1.70205", "the results are saved with the build")
    eq(probe.entries.gear.fileID, 136243, "...and each texture's result")
    eq(probe.entries.mine.kind, "fileID", "...and its kind")
    eq(probe.entries.flag.value, T.flag, "...and its value")

    WoW.slash("/gsweep assets")
    check(not sheet:IsShown(), "again hides it")

    -- A missing path, the next time it opens.
    WoW.fileIDs = {}
    WoW.chat = {}
    WoW.slash("/gsweep assets")
    eq(byKey.gear.state:GetText(), "path: MISSING", "a path the client lacks says MISSING")
    eq(byKey.gear.state._textColor[1], Skin.COLORS.boom[1], "...in red")
    check(chatHas("Client paths it doesn't have: gear"), "...and chat names it")
    check(chatHas("/reload saves the results"), "...and says how to keep the results")
    local frames = #WoW.frames
    WoW.slash("/gsweep assets"); WoW.slash("/gsweep assets")
    eq(#WoW.frames, frames, "reopening builds nothing new")

    sheet.close._scripts.OnClick(sheet.close)
    check(not sheet:IsShown(), "the close button closes it")
end

done("test_assets")
