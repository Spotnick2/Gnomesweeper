-- harness.lua: assertions and the addon loader. dofile it after wow_stubs.lua.

local passed, failed = 0, 0

function check(cond, msg)
    if cond then passed = passed + 1 else
        failed = failed + 1
        io.write("  FAIL: " .. tostring(msg) .. "\n")
    end
end

function eq(actual, expected, msg)
    check(actual == expected, string.format("%s: expected %s, got %s", msg, tostring(expected), tostring(actual)))
end

function done(name)
    io.write(string.format("%s: %d passed, %d failed\n", name, passed, failed))
    os.exit(failed == 0 and 0 or 1)
end

-- Lua files listed in the TOC, in load order, as paths from the repo root.
-- `all` includes Libs\, which the tests never load: the stub's LibStub hands out
-- fakes instead (GlassMiniMapBar's way).
function tocFiles(all)
    local files = {}
    for line in io.lines("Gnomesweeper.toc") do
        line = line:gsub("\r", "")
        if line:match("%.lua$") and not line:match("^#") and (all or not line:match("^Libs\\")) then
            files[#files + 1] = (line:gsub("\\", "/"))
        end
    end
    return files
end

-- Load the addon the way the client does: every TOC file with (name, ns),
-- then ADDON_LOADED. A fresh session each call; opts.db seeds GnomesweeperDB.
function loadAddon(opts)
    opts = opts or {}
    Gnomesweeper, GnomesweeperDB = nil, opts.db
    WoW.reset()
    WoW.locale = opts.locale            -- the client's language (#36), "enUS" when nil
    local ns = {}
    for _, file in ipairs(tocFiles()) do
        local chunk = assert(loadfile(file))
        chunk("Gnomesweeper", ns)
        if opts.afterFile then opts.afterFile(file) end   -- a test's hook (the locale guard's pseudo-language)
    end
    WoW.fire("ADDON_LOADED", "Gnomesweeper")
end

-- Pure modules (Board.lua, Layout.lua) are loaded with every global but a few
-- Lua builtins forbidden, reads AND writes (except the addon's own table):
-- "pure" is then enforced, not claimed. A stray client call, or a missing
-- `local`, fails the suite.
local PURE_ALLOWED = { "math", "string", "table", "type", "setmetatable", "error", "tostring",
                       "tonumber", "ipairs", "pairs", "assert", "select" }
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
