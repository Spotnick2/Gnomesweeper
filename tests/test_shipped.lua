-- What ships carries no probe (#87, owner: no probe in a release). The measuring
-- commands are Tools/GnomesweeperProbe's (test_probe*.lua, which need ForeverProbe and
-- so run locally only); this file needs nothing but the addon, so CI runs it too.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

do  -- the old saved results go at load; the settings and the live diagnostics stay
    loadAddon({ db = { assetProbe = { build = "x" }, modelProbe = {}, soundProbe = {},
        guildProbe = { "a" }, inputLog = { "b" }, socialLog = { "kept" }, musicLog = { "kept too" },
        theme = "modern" } })
    for _, k in ipairs({ "assetProbe", "modelProbe", "soundProbe", "guildProbe", "inputLog" }) do
        eq(GnomesweeperDB[k], nil, "the addon drops a probe's old results at load: " .. k)
    end
    eq(GnomesweeperDB.socialLog[1], "kept", "...but keeps its own diagnostics (socialLog, owner)")
    eq(GnomesweeperDB.musicLog[1], "kept too", "...and musicLog")
    eq(GnomesweeperDB.theme, "modern", "...and the settings")
end

do  -- no probe on the addon's own surface
    loadAddon()
    for _, line in ipairs(Gnomesweeper.HELP) do
        check(not line:find("(for measuring)", 1, true), "the help lists no measuring command: " .. line)
    end
    eq(Gnomesweeper.ModelProbe, nil, "the addon has no model probe")
    eq(Gnomesweeper.Assets, nil, "...no asset sheet")
    eq(Gnomesweeper.Sounds.Probe, nil, "...no sound probe")
    eq(Gnomesweeper.Sounds.CANDIDATES, nil, "...no sound candidates")
    eq(Gnomesweeper.Social.Probe, nil, "...no guild probe")
    eq(Gnomesweeper.Grid.SetLogging, nil, "...no input logging")
    eq(Gnomesweeper.Grid.Benchmark, nil, "...no benchmark in the grid")
    eq(Gnomesweeper.Window.Benchmark, nil, "...nor the window")
    eq(Gnomesweeper.Window.TestBomb, nil, "...no bomb replay")
    eq(Gnomesweeper.Window.ModelHosts, nil, "...no model hosts")
    for _, cmd in ipairs({ "perf", "input", "sounds", "assets", "models", "bomb", "guildprobe" }) do
        WoW.chat = {}
        WoW.slash("/gsweep " .. cmd)
        check(#WoW.chat > 0 and WoW.chat[1]:find("unknown option '" .. cmd .. "'", 1, true) ~= nil,
            "/gsweep " .. cmd .. " is an unknown option")
    end
end

do  -- no shipped file is a probe's, or names one
    for _, file in ipairs(tocFiles()) do
        check(not file:find("Probe", 1, true) and not file:find("Assets", 1, true), "the TOC loads no probe: " .. file)
        local fh = assert(io.open(file, "rb"))
        local src = fh:read("*a")
        fh:close()
        check(not src:find("GnomesweeperProbeDB", 1, true) and not src:find("ForeverProbe:", 1, true),
            file .. " touches no probe")
    end
end

done("test_shipped")
