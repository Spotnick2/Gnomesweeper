-- The manifest, the slash commands, and the embedded glass material.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local toc = io.open("Gnomesweeper.toc"):read("*a")
check(toc:find("## Interface: 16001", 1, true), "interface 16001 (1.60.1; 11601 is the transposed-digit bug)")
check(toc:find("## Version: @project-version@", 1, true), "packager version token kept")
check(toc:find("## SavedVariables: GnomesweeperDB", 1, true), "saved variables declared")
local files, seen = tocFiles(), {}
for _, f in ipairs(files) do
    check(io.open(f, "r") ~= nil, "TOC file exists: " .. f)
    check(not seen[f], "TOC lists each file once: " .. f)
    seen[f] = true
end
-- The embedded material loads before anything: Glass.lua calls
-- LibStub("LibGlass-1.0") at file scope (#71).
eq(tocLines()[1], LIBGLASS_XML, "LibGlass-1.0 loads first")
eq(files[1], "Compat.lua", "Compat loads first (after the libraries)")
local all = tocFiles(true)
for i, lib in ipairs({ "LibStub/LibStub", "CallbackHandler-1.0/CallbackHandler-1.0",
                       "LibDataBroker-1.1/LibDataBroker-1.1", "LibDBIcon-1.0/LibDBIcon-1.0" }) do
    eq(all[i], "Libs/" .. lib .. ".lua", "the libraries load first, in order: " .. lib)
    check(io.open(all[i], "r") ~= nil, "...and the file is there")
end
eq(files[#files], "Gnomesweeper.lua", "the entry point loads last")

-- Boot: defaults filled in, existing values kept, all three commands answer.
loadAddon()
eq(GnomesweeperDB.difficulty, "beginner", "default difficulty")
loadAddon({ db = { difficulty = "expert" } })
eq(GnomesweeperDB.difficulty, "expert", "a saved setting is not overwritten")
for _, cmd in ipairs({ "/gnomesweeper", "/gsweep", "/minewipe" }) do
    local before = #WoW.chat
    WoW.slash(cmd .. " help")
    check(#WoW.chat > before, cmd .. " help answers")
end

-- The event list the stub validates against is checked in; it must be the
-- dump's, exactly (regenerate with Tools/make_events_fixture.py).
do
    local DUMP = os.getenv("GNOMESWEEPER_API_DUMP") or "C:/Projects/References/forever-api-1.60.1.70205.md"
    local f = io.open(DUMP, "r")
    if f then
        local inEvents, dumpEvents, n = false, {}, 0
        for line in f:lines() do
            if line:match("^## ") then
                inEvents = line:match("^## Documented events") ~= nil
            elseif inEvents then
                local name = line:match("^([A-Z][A-Z0-9_]+)%s+%(")
                if name then dumpEvents[name] = true; n = n + 1 end
            end
        end
        f:close()
        local missing, extra = {}, {}
        for e in pairs(dumpEvents) do if not WoW.KNOWN_EVENTS[e] then missing[#missing + 1] = e end end
        for e in pairs(WoW.KNOWN_EVENTS) do if not dumpEvents[e] then extra[#extra + 1] = e end end
        eq(#missing, 0, "every dump event is in the fixture (regenerate it): " .. table.concat(missing, ","))
        eq(#extra, 0, "no fixture event is missing from the dump: " .. table.concat(extra, ","))
        check(n > 1000, "the dump's event list was read (" .. n .. ")")
    else
        io.write("  (events fixture check skipped: no API dump at " .. DUMP .. ")\n")
    end
end

-- Every texture the material names ships with the library (Libs\LibGlass-1.0\Media
-- in the package; the checkout's Media/ here), and none is left in ours.
local root = libGlassRoot()
for size, S in pairs(Gnomesweeper.Glass.SIZES) do
    for _, key in ipairs({ "mask", "rim", "dark", "shadow" }) do
        check(io.open(root .. "/Media/" .. S[key] .. ".tga", "rb") ~= nil, size .. " texture exists: " .. S[key])
        check(io.open("Media/" .. S[key] .. ".tga", "rb") == nil, "no stale copy in our Media/: " .. S[key])
    end
end
for _, t in ipairs({ "bar_mask", "bar_fill", "gloss", "bar_edge", "grain", "sheen2", "track_fade" }) do
    check(io.open(root .. "/Media/" .. t .. ".tga", "rb") ~= nil, "texture exists: " .. t)
    check(io.open("Media/" .. t .. ".tga", "rb") == nil, "no stale copy in our Media/: " .. t)
end
-- Glass.MEDIA points into the embedded copy, where the packager puts it; our
-- own art has its own path (a skin texture under Glass.MEDIA draws nothing).
eq(Gnomesweeper.Glass.MEDIA, "Interface\\AddOns\\Gnomesweeper\\Libs\\LibGlass-1.0\\Media\\", "MEDIA is the embedded copy's")
eq(Gnomesweeper.Skin.MEDIA, "Interface\\AddOns\\Gnomesweeper\\Media\\", "our art is in our Media/")

-- Every texture the skin names under Media/ exists (a missing one is a green
-- square in game, and nothing else would notice).
do
    local media = Gnomesweeper.Skin.MEDIA
    local n = 0
    for key, value in pairs(Gnomesweeper.Skin.TEXTURES) do
        if type(value) == "string" and value:sub(1, #media) == media then
            n = n + 1
            local file = "Media/" .. value:sub(#media + 1) .. ".tga"
            check(io.open(file, "rb") ~= nil, "Skin.TEXTURES." .. key .. " exists: " .. file)
        end
    end
    check(n >= 4, "the skin's own tile textures were checked (" .. n .. ")")
end

-- No control characters in a text file (but tab, CR, LF): an edit script's "\f" in
-- "Locales\frFR.lua" once wrote a form feed into CLAUDE.md, twice.
do
    local p = io.popen("git ls-files")
    local listed = p and p:read("*a") or ""
    if p then p:close() end
    local n = 0
    for path in listed:gmatch("[^\r\n]+") do
        if path:match("%.lua$") or path:match("%.md$") or path:match("%.toc$") or path:match("%.xml$")
            or path:match("%.yml$") or path:match("%.ps1$") or path:match("%.py$") or path == ".pkgmeta" then
            local f = io.open(path, "rb")
            if f then
                n = n + 1
                local text = f:read("*a")
                f:close()
                local bad = text:find("[%z\1-\8\11\12\14-\31\127]")
                check(not bad, path .. " has no control character (one at byte " .. tostring(bad) .. ")")
            end
        end
    end
    check(n > 30 or listed == "", "(the text files were read: " .. n .. ")")
end

done("test_toc")
