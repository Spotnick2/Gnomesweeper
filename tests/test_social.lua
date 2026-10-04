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

done("test_social")
