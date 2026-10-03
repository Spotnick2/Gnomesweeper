-- The manifest, the slash commands, and the lifted glass material.
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

-- Every texture the material names exists in Media/.
for size, S in pairs(Gnomesweeper.Glass.SIZES) do
    for _, key in ipairs({ "mask", "rim", "dark", "shadow" }) do
        local f = "Media/" .. S[key] .. ".tga"
        check(io.open(f, "rb") ~= nil, size .. " texture exists: " .. f)
    end
end
for _, t in ipairs({ "bar_mask", "bar_fill", "gloss", "bar_edge", "grain", "sheen2", "track_fade" }) do
    check(io.open("Media/" .. t .. ".tga", "rb") ~= nil, "texture exists: " .. t)
end

-- Every texture the skin names under Media/ exists (a missing one is a green
-- square in game, and nothing else would notice).
do
    local media = Gnomesweeper.Glass.MEDIA
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

-- Glass.lua is a copy of GlassUnitFrames' material on its MAIN branch: only
-- the header and the namespace lines may differ. Read through git, not the
-- working tree, whose branch another session may have switched.
-- Skipped ONLY when the sibling checkout is absent (as on CI). When it's
-- there, a git failure is a failure: an unreadable main must not pass
-- silently (Codex, plan review).
local NULL = package.config:sub(1, 1) == "\\" and "nul" or "/dev/null"
local function git(args)
    local p = io.popen("git " .. args .. " 2>" .. NULL)
    local out = p and p:read("*a") or ""
    if p then p:close() end
    return out
end
local sibling = io.open("../GlassUnitFrames/Glass.lua", "r")
if sibling then sibling:close() end
local theirs = sibling and git("-C ../GlassUnitFrames show main:Glass.lua") or ""
if sibling then
    check(theirs ~= "", "git can read GlassUnitFrames main:Glass.lua (the sibling exists, so this must work)")
end
if theirs ~= "" then
    local function body(s)
        s = s:gsub("\r", "")
        s = s:gsub("^.-\nlocal ADDON = %.%.%.\n", "")
        s = s:gsub("GlassUF", "Gnomesweeper")
        return s
    end
    check(body(io.open("Glass.lua"):read("*a")) == body(theirs),
        "Glass.lua matches GlassUnitFrames main:Glass.lua (copy it back)")
    local g = git("-C ../GlassUnitFrames show main:Tools/make_textures.py")
    check(g:gsub("\r", "") == io.open("Tools/make_textures.py", "rb"):read("*a"):gsub("\r", ""),
        "Tools/make_textures.py matches GlassUnitFrames main (copy it back)")
    -- The textures too, byte for byte. Compared as git blob hashes: text, so
    -- no binary data passes through a text-mode pipe.
    -- Named, not guessed: these are the copied material. Everything else in Media/ is
    -- ours (tile_*, icon_*, ui_*, face_*: Tools/make_tiles.py, make_ui.py, png_to_tga.py)
    -- and is checked by test_media instead.
    local MATERIAL = { "body_mask", "body_mask_small", "rim5", "rim5_small", "rim_dark5", "rim_dark5_small",
                       "shadow", "shadow_small", "bar_mask", "bar_fill", "gloss", "bar_edge", "grain",
                       "sheen2", "track_fade" }
    for _, name in ipairs(MATERIAL) do
        local f = name .. ".tga"
        local ours = git('hash-object "Media/' .. f .. '"'):gsub("%s", "")
        local up = git("-C ../GlassUnitFrames rev-parse main:Media/" .. f):gsub("%s", "")
        check(ours ~= "" and ours == up, "Media/" .. f .. " matches GlassUnitFrames main (copy it back)")
    end
elseif not sibling then
    io.write("  (upstream material check skipped: no ../GlassUnitFrames checkout)\n")
end

done("test_toc")
