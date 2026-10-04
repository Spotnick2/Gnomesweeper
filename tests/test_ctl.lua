-- test_ctl.lua: the REAL bundled ChatThrottleLib, with Gnomesweeper's own sends going
-- through it (ported from AltStable's tests/test_ctl.lua, #138 there).
--
-- Every other test leaves Libs\ out, and test_social.lua's ChatThrottleLib is a fake
-- that calls our callback the way I believed the library does. This file loads the
-- library itself, so our use of it (the argument order, the callback's signature, the
-- priorities) is checked against the real thing. On this client
-- C_ChatInfo.SendAddonMessage returns an Enum.SendAddonMessageResult, and
-- AddonMessageThrottle (3) means the server refused the message; v32 retries it.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local GUILD = "Gnomeregan Exiles"
local T = 1790000000

local function loadWithCTL()
    loadAddon()
    WoW.guild = GUILD
    WoW.now = 100
    ChatThrottleLib = nil                        -- so the real one installs
    dofile("Libs/ChatThrottleLib/ChatThrottleLib.lua")
    local CTL = ChatThrottleLib
    local onUpdate = CTL.Frame._scripts.OnUpdate
    local function pump(seconds)
        local step = 0.1
        for _ = 1, math.floor(seconds / step + 0.5) do
            WoW.now = WoW.now + step
            onUpdate(CTL.Frame, step)
        end
    end
    pump(6)                                      -- past its start-up hard throttle
    WoW.addonSent = {}
    return CTL, pump
end
local function sent(kind)
    local list = {}
    for _, m in ipairs(WoW.addonSent) do
        if m.prefix == "GSWEEP" and m.message:match("^1\t" .. kind) then list[#list + 1] = m.message end
    end
    return list
end

do  -- the library itself
    local CTL = loadWithCTL()
    check((CTL.version or 0) >= 32, "the bundled ChatThrottleLib is v32 or newer (" .. tostring(CTL.version) .. ")")
end

do  -- an N refused by the server's throttle is retried, and arrives once, whole
    local CTL, pump = loadWithCTL()
    local S = Gnomesweeper.Social
    WoW.sendResults = { 3 }                      -- the first attempt: AddonMessageThrottle
    eq(S.RecordWin("expert:area", 84.12), true, "(a new best)")
    pump(3)
    local n = sent("N")
    eq(#n, 1, "a throttled N is retried by the library and delivered once")
    eq(n[1], "1\tN\texpert:area=8412@" .. T, "...whole")
    eq(S.lastFailure, nil, "...and a throttle the library retried isn't a failure")
end

do  -- a burst (an N, a query, a reply) all arrive, in order, through throttles
    local CTL, pump = loadWithCTL()
    local S = Gnomesweeper.Social
    WoW.sendResults = { 0, 3, 3, 0 }
    S.RecordWin("expert:area", 84)
    S.RecordWin("beginner:area", 20)
    S.QueryIfStale()
    pump(5)
    eq(#sent("N"), 2, "two N through two throttles: both delivered")
    eq(#sent("Q"), 1, "...and the query")
    WoW.fire("CHAT_MSG_ADDON", "GSWEEP", "1\tQ", "GUILD", "Ann Gear", "", 0, 0, "", 0)
    WoW.advance(7)                               -- the reply's deferral (a C_Timer)
    pump(3)                                      -- then the library sends it
    local b = sent("B")
    eq(#b, 1, "a guildmate's query: our reply goes through the library")
    eq(b[1], "1\tB\tbeginner:area=2000@" .. T .. "\texpert:area=8400@" .. T, "...whole, every best")
    eq(#WoW.reportedErrors, 0, "nothing reached the error handler")
end

do  -- a refusal that isn't the throttle: not retried, and our callback reads it
    local CTL, pump = loadWithCTL()
    local S = Gnomesweeper.Social
    WoW.sendResults = { 10 }                     -- NotInGuild
    S.QueryIfStale()
    pump(2)
    eq(#sent("Q"), 0, "a NotInGuild refusal isn't delivered (nor retried)")
    check(S.lastFailure and S.lastFailure:find("^10 at") ~= nil, "...the library's callback reports it, and Social keeps it")
    eq(S.QueryIfStale(), true, "...and the refused query doesn't count as made")
    pump(2)
    eq(#sent("Q"), 1, "...the next one goes")
end

do  -- a second batch through a reused pipe (v32 recycles them with table.wipe)
    local CTL, pump = loadWithCTL()
    local S = Gnomesweeper.Social
    S.RecordWin("expert:area", 90)
    pump(2)
    WoW.sendResults = { 3 }
    S.RecordWin("expert:area", 80)
    S.RecordWin("expert:area", 70)
    pump(3)
    eq(#sent("N"), 3, "a later batch, through a reused pipe, is delivered too")
    eq(#WoW.reportedErrors, 0, "...without an error")
end

done("test_ctl")
