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
    WoW.slash(cmd)
    check(#WoW.chat > before, cmd .. " answers")
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
local NULL = package.config:sub(1, 1) == "\\" and "nul" or "/dev/null"
local upstream = io.popen('git -C ../GlassUnitFrames show main:Glass.lua 2>' .. NULL)
local theirs = upstream and upstream:read("*a") or ""
if upstream then upstream:close() end
if theirs ~= "" then
    local function body(s)
        s = s:gsub("\r", "")
        s = s:gsub("^.-\nlocal ADDON = %.%.%.\n", "")
        s = s:gsub("GlassUF", "Gnomesweeper")
        return s
    end
    check(body(io.open("Glass.lua"):read("*a")) == body(theirs),
        "Glass.lua matches GlassUnitFrames main:Glass.lua (copy it back)")
    local gen = io.popen('git -C ../GlassUnitFrames show main:Tools/make_textures.py 2>' .. NULL)
    local g = gen and gen:read("*a") or ""
    if gen then gen:close() end
    check(g:gsub("\r", "") == io.open("Tools/make_textures.py", "rb"):read("*a"):gsub("\r", ""),
        "Tools/make_textures.py matches GlassUnitFrames main (copy it back)")
else
    io.write("  (Glass.lua upstream check skipped: no ../GlassUnitFrames git repo)\n")
end

done("test_toc")
