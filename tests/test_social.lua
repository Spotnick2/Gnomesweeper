-- The social plan (docs/SOCIAL.md). Phase 0: /gsweep guildprobe measures how the
-- guild names this character's addon messages, before anything is saved for real.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local function chatHas(text)
    for _, line in ipairs(WoW.chat) do if line:find(text, 1, true) then return true end end
    return false
end
local function savedHas(text)
    for _, line in ipairs(GnomesweeperDB.guildProbe or {}) do if line:find(text, 1, true) then return true end end
    return false
end

do  -- in a guild: the identity, the send, the echo, Ambiguate, the saved lines
    loadAddon()
    WoW.guild = "Gnomeregan Exiles"
    WoW.chat = {}
    WoW.slash("/gsweep guildprobe")
    eq(WoW.prefixes.GSWEEP, true, "the prefix is registered")
    check(chatHas('UnitName = "Fizzle", "Sprocketwhistle"'), "it reports UnitName's two answers (the surname's place, measured on 70009)")
    check(chatHas("GetNormalizedRealmName"), "...the realm, both ways")
    check(chatHas('API.PlayerFullName = "Fizzle Sprocketwhistle"'), "...the full name the scores use")
    check(chatHas('GetGuildInfo = "Gnomeregan Exiles"'), "...the guild")
    eq(#WoW.addonSent, 1, "one message sent")
    local m = WoW.addonSent[1]
    eq(m.prefix, "GSWEEP", "...on the prefix")
    eq(m.chatType, "GUILD", "...to the guild")
    check(m.message:match("^1\tP\t%d+$") ~= nil, "...a v1 'P' (probe) message: a type no v1 client knows, so they ignore it")
    check(chatHas("SendAddonMessage(GUILD) = 0"), "...and the send's result code is reported")
    check(chatHas('CHAT_MSG_ADDON channel="GUILD" sender="Fizzle Sprocketwhistle"'), "the echo is reported: the channel and the sender, exactly")
    check(chatHas('Ambiguate(sender, "none")'), "...and what Ambiguate makes of the sender, in each context")
    check(chatHas('Ambiguate(sender, "short") = "Fizzle Sprocketwhistle"'), "...(measured a no-op on a guild sender)")
    check(savedHas("CHAT_MSG_ADDON"), "the lines are kept in GnomesweeperDB.guildProbe, for a /reload to save")
    check(#GnomesweeperDB.guildProbe <= Gnomesweeper.Social.PROBE_KEEP, "...at most PROBE_KEEP of them")

    -- Another addon's message, or another prefix: not ours.
    local before = #GnomesweeperDB.guildProbe
    WoW.fire("CHAT_MSG_ADDON", "OTHER", "x", "GUILD", "Someone-Forever", "", 0, 0, "", 0)
    eq(#GnomesweeperDB.guildProbe, before, "another prefix's message is ignored")

    -- The prefix is registered once, however many probes.
    WoW.slash("/gsweep guildprobe")
    eq(#WoW.addonSent, 2, "a second probe sends again")
end

do  -- no guild: nothing sent, and it says so
    loadAddon()
    WoW.chat = {}
    WoW.slash("/gsweep guildprobe")
    eq(#WoW.addonSent, 0, "not in a guild: nothing is sent")
    check(chatHas("not in a guild"), "...and it says why")
    check(chatHas("UnitName ="), "...the identity is still reported")
end

do  -- the help lists it as a measuring command (About leaves it out)
    loadAddon()
    WoW.chat = {}
    WoW.slash("/gsweep help")
    check(chatHas("/gsweep guildprobe"), "the help lists the probe")
    local listed = false
    for _, line in ipairs(Gnomesweeper.HELP) do
        if line:find("guildprobe", 1, true) then listed = line:find("(for measuring)", 1, true) ~= nil end
    end
    check(listed, "...marked (for measuring), so About doesn't list it and it stays English")
end

----------------------------------------------------------------------------
-- Phase 1 (#15): the guild's best times, live
----------------------------------------------------------------------------
local G = nil
local GUILD = "Gnomeregan Exiles"
local GKEY = "Gnomeregan Exiles-Forever"         -- GetGuildInfo's realm is nil in the stub: ours
local function sent(kind)
    local list = {}
    for _, m in ipairs(WoW.addonSent) do
        if m.prefix == "GSWEEP" and m.message:match("^1\t" .. kind) then list[#list + 1] = m end
    end
    return list
end
local function from(sender, msg) WoW.fire("CHAT_MSG_ADDON", "GSWEEP", msg, "GUILD", sender, "", 0, 0, "", 0) end
local function cache() return GnomesweeperDB.social and GnomesweeperDB.social.guilds[GKEY] end
local function login() WoW.fire("PLAYER_ENTERING_WORLD", true, false); WoW.advance(5.5) end
local T = 1790000000

do  -- login: one query, once a session
    loadAddon()
    WoW.guild = GUILD
    G = Gnomesweeper.Guild
    login()
    eq(#sent("Q"), 1, "a query to the guild, a few seconds after login")
    eq(sent("Q")[1].chatType, "GUILD", "...to the guild, hidden")
    WoW.fire("PLAYER_ENTERING_WORLD", false, false)    -- a loading screen
    WoW.advance(10)
    eq(#sent("Q"), 1, "a loading screen doesn't ask again: once a session")
    eq(#WoW.chat, 0, "nothing is ever said in chat")
end

do  -- no guild: nothing sent
    loadAddon()
    login()
    eq(#WoW.addonSent, 0, "not in a guild: nothing is sent")
end

do  -- this character's own bests, and N
    loadAddon()
    WoW.guild = GUILD
    local S = Gnomesweeper.Social
    eq(S.RecordWin("expert:area", 84.129), true, "a win: this character's best")
    local mine = GnomesweeperDB.social.mine["Fizzle Sprocketwhistle-Forever"]
    eq(mine["expert:area"].cs, 8412, "...kept per character, in centiseconds")
    eq(#sent("N"), 1, "...and a new best goes to the guild as an N")
    eq(sent("N")[1].message, "1\tN\texpert:area=8412@" .. T, "...exactly")
    eq(S.RecordWin("expert:area", 90), false, "a slower win isn't a best")
    eq(S.RecordWin("expert:area", 84.125), false, "...nor the same centisecond (ties keep the earlier)")
    eq(#sent("N"), 1, "...and sends nothing")
    eq(S.RecordWin("expert:area", 80), true, "a faster one is")
    eq(S.RecordWin("beginner:area", 0.5), false, "a win under 1 s doesn't count for the guild")
    eq(#sent("N"), 2, "(two N in all)")
    eq(cache(), nil, "our own echo isn't cached as a guildmate (it's us)")
    WoW.guild = nil
    eq(S.RecordWin("expert:cell", 50), true, "out of a guild a best is still kept")
    eq(#sent("N"), 2, "...but nothing is sent")
end

do  -- seeding: only the account's records this character set (name AND realm)
    loadAddon({ db = { scores = { version = 1,
        ["expert:area"] = { played = 9, won = 3, best = { time = 70.5, at = T - 100, name = "Fizzle Sprocketwhistle", realm = "Forever" } },
        ["beginner:area"] = { played = 9, won = 3, best = { time = 9.5, at = T - 100, name = "Ann Gear", realm = "Forever" } },
        ["intermediate:area"] = { played = 9, won = 3, best = { time = 40, at = T - 100, name = "Fizzle Sprocketwhistle", realm = "Elsewhere" } },
    } } })
    WoW.guild = GUILD
    local S = Gnomesweeper.Social
    local r = S.Ranking("expert:area")
    eq(#r, 1, "our record from the account's scores is ours before anything is written")
    eq(r[1].cs, 7050, "...its time")
    eq(GnomesweeperDB.social, nil, "...and reading created nothing")
    S.RecordWin("expert:area", 90)
    local mine = GnomesweeperDB.social.mine["Fizzle Sprocketwhistle-Forever"]
    eq(mine["expert:area"].cs, 7050, "seeded on the first write: the account record this character set")
    eq(mine["beginner:area"], nil, "...not another character's")
    eq(mine["intermediate:area"], nil, "...nor a same-named character's on another realm")
end

do  -- replies: deferred, coalesced, never dropped
    loadAddon()
    WoW.guild = GUILD
    math.randomseed(3)
    local S = Gnomesweeper.Social
    S.RecordWin("expert:area", 84.12)
    WoW.addonSent = {}
    from("Ann Gear", "1\tQ")
    eq(#sent("B"), 0, "a query isn't answered at once (a guild would answer all together)")
    local timers = #WoW.timers
    from("Bob Cog", "1\tQ")
    from("Cal Bolt", "1\tQ")
    eq(#WoW.timers, timers, "more queries while one reply waits add no timer (and so can't push it back)")
    WoW.advance(6.5)
    eq(#sent("B"), 1, "three queries, one reply within 1-6 s: coalesced")
    eq(sent("B")[1].message, "1\tB\texpert:area=8412@" .. T, "...our bests")
    from("Dee Nut", "1\tQ")                     -- a late joiner, during the minute after our reply
    WoW.advance(30)
    eq(#sent("B"), 1, "a late joiner's query waits out the minute...")
    WoW.advance(40)
    eq(#sent("B"), 2, "...and is answered after it, not dropped")
end

do  -- no bests: no reply
    loadAddon()
    WoW.guild = GUILD
    from("Ann Gear", "1\tQ")
    WoW.advance(10)
    eq(#sent("B"), 0, "with no best of our own, a query gets no reply")
end

do  -- receiving: B and N fill the cache; the ranking; what's ignored
    loadAddon()
    WoW.guild = GUILD
    local S = Gnomesweeper.Social
    S.RecordWin("expert:area", 85)
    from("Ann Gear", "1\tB\texpert:area=9000@" .. T .. "\tbeginner:area=1500@" .. T)
    from("Bob Cog", "1\tN\texpert:area=8000@" .. T)
    eq(cache()["Ann Gear-Forever"].bests["expert:area"].cs, 9000, "a B fills the cache, keyed by the sender with our realm")
    eq(cache()["Ann Gear-Forever"].seen, T, "...seen by our clock")
    eq(cache()["Bob Cog-Forever"].bests["expert:area"].cs, 8000, "an N too")
    local r = S.Ranking("expert:area")
    eq(#r, 3, "the ranking: both guildmates and us")
    eq(r[1].name, "Bob Cog", "...best first, shown without our realm")
    check(r[2].mine, "...us second")
    eq(r[3].name, "Ann Gear", "...then Ann")
    from("Bob Cog", "1\tB\texpert:area=9500@" .. (T - 50))
    eq(cache()["Bob Cog-Forever"].bests["expert:area"].cs, 8000, "an older, slower B after an N doesn't replace it")
    from("Eve Spring", "1\tN\texpert:area=0800@" .. T)
    eq(cache()["Eve Spring-Forever"], nil, "a malformed message is dropped whole")
    from("Eve Spring", "2\tN\texpert:area=800@" .. T)
    eq(cache()["Eve Spring-Forever"], nil, "...a version we don't know is ignored")
    WoW.fire("CHAT_MSG_ADDON", "GSWEEP", "1\tN\texpert:area=800@" .. T, "WHISPER", "Eve Spring", "", 0, 0, "", 0)
    eq(cache()["Eve Spring-Forever"], nil, "...a whisper is ignored (guild only, in phase 1)")
    from("Fizzle Sprocketwhistle", "1\tN\texpert:area=100@" .. T)
    eq(cache()["Fizzle Sprocketwhistle-Forever"], nil, "...and so is our own echo")
    from("Gus Far-OtherRealm", "1\tN\texpert:area=7000@" .. T)
    eq(S.Ranking("expert:area")[1].name, "Gus Far-OtherRealm", "another realm's guildmate keeps the realm in the name")
end

do  -- a guild change cancels what was pending for the old one
    loadAddon()
    WoW.guild = GUILD
    login()
    local S = Gnomesweeper.Social
    S.RecordWin("expert:area", 84)
    WoW.addonSent = {}
    from("Ann Gear", "1\tQ")
    check(S._test.pending() ~= nil, "(a reply pending)")
    WoW.guild = "Another Guild"
    WoW.fire("PLAYER_GUILD_UPDATE", "player")
    eq(S._test.pending(), nil, "a guild change cancels the pending reply")
    WoW.advance(10)
    eq(#sent("B"), 0, "...and it never goes")
end

do  -- pruning at login, reset
    loadAddon({ db = { social = { version = 1, mine = {}, guilds = { [GKEY] = {
        ["Old Timer-Forever"] = { seen = T - 31 * 86400, bests = { ["expert:area"] = { cs = 5000, at = T - 31 * 86400 } } },
        ["New Comer-Forever"] = { seen = T - 86400, bests = { ["expert:area"] = { cs = 6000, at = T - 86400 } } },
    } } } } })
    WoW.guild = GUILD
    login()
    eq(cache()["Old Timer-Forever"], nil, "a member silent for 30 days is forgotten at login")
    check(cache()["New Comer-Forever"] ~= nil, "...a recent one stays")
    Gnomesweeper.Social.RecordWin("expert:area", 70)
    Gnomesweeper.Social.Reset()
    eq(next(GnomesweeperDB.social.mine), nil, "Reset best times forgets this account's own bests")
    check(cache()["New Comer-Forever"] ~= nil, "...not the guildmates' (theirs to keep)")
end

do  -- ChatThrottleLib paces sends when it's loaded
    loadAddon()
    WoW.guild = GUILD
    local paced = {}
    ChatThrottleLib = { SendAddonMessage = function(self, prio, prefix, msg, chatType)
        paced[#paced + 1] = { prio = prio, prefix = prefix, msg = msg, chatType = chatType }
    end }
    Gnomesweeper.Social.RecordWin("expert:area", 84)
    ChatThrottleLib = nil
    eq(#paced, 1, "with ChatThrottleLib, the send goes through it")
    eq(paced[1].chatType, "GUILD", "...to the guild")
    eq(paced[1].prio, "NORMAL", "...an N at NORMAL")
    eq(#sent("N"), 0, "...not straight to the client")
end

do  -- the window: a win sends an N; the Guild tab
    loadAddon({ db = { seenFaceTip = true } })
    WoW.guild = GUILD
    WoW.slash("/gsweep")
    local W = Gnomesweeper.Window
    WoW.now = 0                                          -- a hand-built board's clock starts at 0
    W._test.SetGame(Gnomesweeper.Board._test.FromLayout({ "*.." }), "beginner:area")
    local t = Gnomesweeper.Grid._test.tiles
    t[2]._scripts.OnMouseDown(t[2], "LeftButton"); t[2]._scripts.OnMouseUp(t[2], "LeftButton", true)
    WoW.now = 12.5
    t[3]._scripts.OnMouseDown(t[3], "LeftButton"); t[3]._scripts.OnMouseUp(t[3], "LeftButton", true)
    eq(W.game:State(), "won", "(a win)")
    eq(#sent("N"), 1, "a win that's this character's best goes to the guild (its first win too: own best first, then the account's)")
    from("Ann Gear", "1\tB\tbeginner:area=1000@" .. T)
    W.ShowBests(true)
    local p = W._test.ui.bests
    check(p.tabs and p.tabs.guild and p.tabs.you, "Best times has two tabs, You and Guild")
    eq(p.tabs.you.label:GetText(), "You", "...You")
    p.tabs.guild._scripts.OnClick(p.tabs.guild)
    local row = p.rows.beginner
    eq(row.time:GetText(), "00:10.0", "the Guild tab: the guild's best, to the tenth")
    check(row.who:GetText():find("Ann Gear", 1, true) ~= nil, "...who set it")
    eq(row.record:GetText(), "you: 2 of 2", "...and where you stand")
    eq(p.rows.expert.time:GetText(), "-", "a difficulty no one has a time in")
    eq(p.rows.expert.who:GetText(), "No time shared yet", "...says so")
    check(p.rule:GetText():find(GUILD, 1, true) ~= nil, "the guild's name at the bottom")
    GameTooltip._lines = {}
    row._scripts.OnEnter(row)
    eq(GameTooltip._text, "Beginner", "a row's tooltip: the difficulty")
    eq(GameTooltip._lines[1], "1. Ann Gear  00:10.0", "...the guild's top, in order")
    eq(GameTooltip._lines[2], "2. Fizzle Sprocketwhistle  00:12.5", "...us included")
    from("Bob Cog", "1\tN\tbeginner:area=900@" .. T)
    eq(row.time:GetText(), "00:09.0", "a time arriving while the tab is open shows at once")
    p.tabs.you._scripts.OnClick(p.tabs.you)
    eq(row.time:GetText(), "00:12", "the You tab: the account's best, as before")
    p.tabs.guild._scripts.OnClick(p.tabs.guild)
    WoW.guild = nil
    W.ShowBests(false); W.ShowBests(true)
    eq(p.rule:GetText(), "Not in a guild.", "no guild: the Guild tab says so")
end

done("test_social")
