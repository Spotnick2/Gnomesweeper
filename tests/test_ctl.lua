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

do  -- a second batch through a REUSED pipe: v32 recycles an emptied pipe with table.wipe,
    -- bound once when it loads. Both batches are forced to queue (a throttle first), so the
    -- second takes the first's pipe from the bin (Codex, #64: an immediate send never queues).
    local realWipe, wipes = table.wipe, 0
    table.wipe = function(t) wipes = wipes + 1; return realWipe(t) end
    collectgarbage("stop")                       -- the bin is weak-keyed: no collection mid-scenario
    local CTL, pump = loadWithCTL()
    table.wipe = realWipe
    local S = Gnomesweeper.Social
    WoW.sendResults = { 3 }                      -- the first batch queues: a pipe is made
    S.RecordWin("expert:area", 90)
    pump(2)
    eq(#sent("N"), 1, "(the first batch, through a pipe, delivered: the pipe goes to the bin)")
    eq(wipes, 0, "(nothing recycled yet)")
    WoW.sendResults = { 3 }                      -- the second queues too: it takes the binned pipe
    S.RecordWin("expert:area", 80)
    S.RecordWin("expert:area", 70)
    pump(3)
    collectgarbage("restart")
    check(wipes >= 1, "the second batch reused the first's pipe (table.wipe ran " .. wipes .. " time(s))")
    eq(#sent("N"), 3, "...and is delivered through it")
    eq(#WoW.reportedErrors, 0, "...without an error")
end

do  -- a refused reset, a slower win in the same category, the retry: the guildmate ends up right
    -- (Codex, #69). The sender runs on the real library; what it actually delivered is then
    -- replayed, in order, into a second addon instance playing the guildmate.
    local CTL, pump = loadWithCTL()
    local S = Gnomesweeper.Social
    WoW.fire("PLAYER_ENTERING_WORLD", true, false)           -- logged in: the retry runs on guild events
    WoW.advance(5.5)
    pump(2)
    WoW.addonSent = {}
    local reset = T - 100
    GnomesweeperDB.social = { version = 1, mine = {}, guilds = {}, resetAt = reset, resetSent = {} }   -- a reset still pending
    WoW.sendResults = { 10 }                                 -- the R refused (NotInGuild), not the throttle
    S.RecordWin("beginner:area", 20)                         -- a 20 s win, after the reset
    pump(3)
    WoW.fire("PLAYER_GUILD_UPDATE", "player")                -- the next chance: the R retried
    pump(3)
    local delivered = {}
    for _, m in ipairs(WoW.addonSent) do
        if m.prefix == "GSWEEP" and not m.message:match("^1\tQ") then delivered[#delivered + 1] = m.message end
    end
    local kinds = {}
    for _, m in ipairs(delivered) do kinds[#kinds + 1] = m:sub(3, 3) end
    eq(table.concat(kinds), "NRB", "delivered: (the R refused) the N, then the retried R and the bests behind it")

    -- The guildmate: Ann, who held Fizzle's old 10 s best from before the reset.
    loadAddon({ db = { social = { version = 1, mine = {}, guilds = { [GUILD .. "-Forever"] = {
        ["Fizzle Sprocketwhistle-Forever"] = { seen = T, bests = { ["beginner:area"] = { cs = 1000, at = reset - 100 } } },
    } } } } })
    WoW.playerName, WoW.playerSurname = "Ann", "Gear"
    WoW.guild = GUILD
    for _, m in ipairs(delivered) do
        WoW.fire("CHAT_MSG_ADDON", "GSWEEP", m, "GUILD", "Fizzle Sprocketwhistle", "", 0, 0, "", 0)
    end
    local e = GnomesweeperDB.social.guilds[GUILD .. "-Forever"]["Fizzle Sprocketwhistle-Forever"]
    eq(e and e.bests["beginner:area"] and e.bests["beginner:area"].cs, 2000,
        "the guildmate ends with the 20 s win: the old 10 s gone, the post-reset time not lost")
end

do  -- a win that publishes a pending reset still toasts on the guildmate (Codex, #69): the reset's
    -- B carries the bests from before the win, so the win's N is a real improvement there.
    local CTL, pump = loadWithCTL()
    local S = Gnomesweeper.Social
    WoW.fire("PLAYER_ENTERING_WORLD", true, false)
    WoW.advance(5.5)
    pump(2)
    local reset = T - 100
    GnomesweeperDB.social = { version = 1, guilds = {}, resetAt = reset, resetSent = {},
        mine = { ["Fizzle Sprocketwhistle-Forever"] = { ["expert:area"] = { cs = 9000, at = reset + 10 } } } }
    WoW.addonSent = {}
    S.RecordWin("beginner:area", 20)                         -- the win: it sends the pending R first
    pump(3)
    local delivered = {}
    for _, m in ipairs(WoW.addonSent) do
        if m.prefix == "GSWEEP" and not m.message:match("^1\tQ") then delivered[#delivered + 1] = m.message end
    end
    local kinds = {}
    for _, m in ipairs(delivered) do kinds[#kinds + 1] = m:sub(3, 3) end
    eq(table.concat(kinds), "RBN", "delivered: the reset, the bests from before the win, then the win")
    check(not delivered[2]:find("beginner", 1, true), "...the B doesn't carry the win (it would beat its own N)")

    -- The guildmate, synced, where Bob holds the Beginner guild best at 30 s.
    loadAddon()
    WoW.playerName, WoW.playerSurname = "Ann", "Gear"
    WoW.guild = GUILD
    WoW.fire("PLAYER_ENTERING_WORLD", true, false)
    WoW.advance(5.5)
    WoW.fire("CHAT_MSG_ADDON", "GSWEEP", "1\tB\tbeginner:area=3000@" .. T, "GUILD", "Bob Cog", "", 0, 0, "", 0)
    WoW.advance(75)
    for _, m in ipairs(delivered) do
        WoW.fire("CHAT_MSG_ADDON", "GSWEEP", m, "GUILD", "Fizzle Sprocketwhistle", "", 0, 0, "", 0)
    end
    local e = GnomesweeperDB.social.guilds[GUILD .. "-Forever"]["Fizzle Sprocketwhistle-Forever"]
    eq(e and e.bests["beginner:area"] and e.bests["beginner:area"].cs, 2000, "the guildmate holds the 20 s win")
    check(Gnomesweeper.Toast.IsShown(), "...and shows the toast: a new guild best, beating Bob's 30 s")
end

done("test_ctl")
