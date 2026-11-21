-- harness.lua: the addon loader and the tests' own helpers. dofile it after
-- wow_stubs.lua. check, eq and done are WowTestKit's (global).

-- The pure tests (Board, Layout, Input, Guild, Media) load no stub: the kit,
-- and with it check / eq / done, comes from here for them.
if not rawget(_G, "Kit") then dofile("tests/kit.lua") end

local TOC = "Gnomesweeper.toc"

-- Every file line of the TOC, in load order, as written (backslashes).
function tocLines() return Kit.tocLines(TOC) end

-- Lua files listed in the TOC, in load order, as paths from the repo root.
-- `all` includes Libs\, which the tests never load: the stub's LibStub hands out
-- fakes instead (GlassMiniMapBar's way). The embedded LibGlass-1.0 is the TOC's
-- .xml line, never in this list: libGlassScripts() has its files.
function tocFiles(all)
    local files = {}
    for _, file in ipairs(Kit.tocFiles(TOC)) do
        if all or not file:match("^Libs/") then files[#files + 1] = file end
    end
    return files
end

-- The embedded LibGlass-1.0 comes from a checkout, not from Libs\ (gitignored,
-- filled by the packager): $LIBGLASS, else ../LibGlass. No checkout fails the
-- run loudly; a silently skipped library would test nothing (#71, after
-- GlassUnitFrames' harness).
LIBGLASS_XML = "Libs\\LibGlass-1.0\\LibGlass-1.0.xml"
function libGlassRoot()
    local root = (os.getenv("LIBGLASS") or "../LibGlass"):gsub("\\", "/"):gsub("/$", "")
    local f = io.open(root .. "/LibGlass-1.0.xml", "rb")
    if not f then
        error("LibGlass checkout not found at " .. root .. " (no LibGlass-1.0.xml): clone "
              .. "github.com/Spotnick2/LibGlass there or set LIBGLASS", 0)
    end
    f:close()
    return root
end

-- The Lua files the library's XML loads, as paths, in order: what the client
-- runs for the TOC's XML line. A listed file that is missing fails here.
function libGlassScripts()
    local root = libGlassRoot()
    local f = assert(io.open(root .. "/LibGlass-1.0.xml", "rb"))
    local xml = f:read("*a"):gsub("<!%-%-.-%-%->", "")   -- listed in a comment is not loaded
    f:close()
    local files = {}
    for file in xml:gmatch('<Script%s+file="([^"]+)"') do
        local path = root .. "/" .. file:gsub("\\", "/")
        local src = io.open(path, "rb")
        if not src then error("LibGlass checkout at " .. root .. " is missing " .. file, 0) end
        src:close()
        files[#files + 1] = path
    end
    if #files == 0 then error("LibGlass-1.0.xml at " .. root .. " lists no Script files", 0) end
    return files
end

-- Load the addon the way the client does: every TOC file with (name, ns), the
-- library's XML expanded in place (a fresh LibStub and LibGlass each time, so
-- no instance outlives its session), the vendored Libs\ left out (faked), then
-- ADDON_LOADED. A fresh session each call; opts.db seeds GnomesweeperDB.
function loadAddon(opts)
    opts = opts or {}
    Gnomesweeper, GnomesweeperDB = nil, opts.db
    WoW.reset()
    WoW.locale = opts.locale            -- the client's language (#36), "enUS" when nil
    local ns = {}
    for _, line in ipairs(tocLines()) do
        local files
        if line == LIBGLASS_XML then
            LibStub = nil
            files = libGlassScripts()
        elseif line:match("^Libs\\") then
            files = {}
        elseif line:match("%.lua$") then
            files = { (line:gsub("\\", "/")) }
        else
            error("the harness can't load TOC line " .. line, 0)
        end
        for _, file in ipairs(files) do
            local chunk = assert(loadfile(file))
            chunk("Gnomesweeper", ns)
            if opts.afterFile then opts.afterFile(file) end   -- a test's hook (the locale guard's pseudo-language)
        end
        if line == LIBGLASS_XML then WoW.fakeLibs(LibStub) end
    end
    WoW.fire("ADDON_LOADED", "Gnomesweeper")
end

-- Pure modules (Board.lua, Layout.lua) are loaded with every global but a few
-- Lua builtins forbidden, reads AND writes (except the addon's own table):
-- "pure" is then enforced, not claimed. A stray client call, or a missing
-- `local`, fails the suite.
local PURE_ALLOWED = { "math", "string", "table", "type", "setmetatable", "error", "tostring",
                       "tonumber", "next", "ipairs", "pairs", "assert", "select" }
function newPureEnv()
    local env = {}
    for _, k in ipairs(PURE_ALLOWED) do env[k] = _G[k] end
    return setmetatable(env, {
        __index = function(_, k)
            if k == "Gnomesweeper" then return nil end   -- the file's own `X = X or {}`
            error("a pure file read the global '" .. tostring(k) .. "'", 2)
        end,
        __newindex = function(t, k, v)
            if k ~= "Gnomesweeper" then error("a pure file wrote the global '" .. tostring(k) .. "'", 2) end
            rawset(t, k, v)
        end,
    })
end

function loadPure(env, file)
    local chunk = assert(loadfile(file))
    setfenv(chunk, env)
    chunk("Gnomesweeper", {})
    return env.Gnomesweeper
end

