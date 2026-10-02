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
eq(files[1], "Compat.lua", "Compat loads first")
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
    local DUMP = os.getenv("GNOMESWEEPER_API_DUMP") or "C:/Projects/References/forever-api-1.60.1.70170.md"
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
    for f in io.popen('dir /b "Media\\*.tga" 2>' .. NULL):lines() do
        local ours = git('hash-object "Media/' .. f .. '"'):gsub("%s", "")
        local up = git("-C ../GlassUnitFrames rev-parse main:Media/" .. f):gsub("%s", "")
        check(ours ~= "" and ours == up, "Media/" .. f .. " matches GlassUnitFrames main (copy it back)")
    end
elseif not sibling then
    io.write("  (upstream material check skipped: no ../GlassUnitFrames checkout)\n")
end

done("test_toc")
