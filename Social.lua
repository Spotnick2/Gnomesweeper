-- Social.lua: the guild's best times, live (#15; the plan is docs/SOCIAL.md). Guild.lua
-- is the pure half (the wire format, the order, merging, ranking); this is the rest:
-- each character's own bests, the query at login, the deferred replies, receiving,
-- guild changes, sending. Hidden addon messages only: nothing is ever said in chat.
--
--   Social.RecordWin(category, seconds)  a win: this character's own best, and an N
--   Social.Ranking(category)             the guild's times for the Guild tab, best first
--   Social.GuildName()                   the guild's name, or nil
--   Social.QueryIfStale()                the Guild tab opening: ask, if not asked lately
--   Social.Reset()                       Reset best times: this account's own bests go
--
-- And phase 0's measuring probe, /gsweep guildprobe: what this character is called (every
-- API's answer), a "P" message (a type no v1 client knows) to the guild, and the server's
-- echo; kept in GnomesweeperDB.guildProbe for a /reload.

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local GS = Gnomesweeper
local Social = {}
GS.Social = Social
local Guild = GS.Guild

Social.PREFIX = "GSWEEP"
Social.PROBE_KEEP = 200          -- lines kept in GnomesweeperDB.guildProbe
Social.LOGIN_DELAY = 5           -- seconds after login before asking the guild
Social.QUERY_GAP = 60            -- at most one query a minute
Social.STALE = 300               -- the Guild tab asks again after 5 minutes
Social.REPLY_GAP = 60            -- at most one reply a minute, deferred, never dropped
Social.JITTER_MIN, Social.JITTER_MAX = 1, 6
Social.FORGET = 30 * 86400       -- a member silent this long is forgotten

local registered                 -- the prefix's registration result, once asked
local lastQuery                  -- GetTime() of our last Q
local queriedGuild               -- the guild that Q went to
local lastReply                  -- GetTime() of our last B
local pending                    -- the reply waiting to go: { guild = key }, or nil
local currentGuild               -- the guild key last seen (a change cancels what's pending)
local loggedIn                   -- the login query is once a session

local function db() return GnomesweeperDB end
local function realm() return GetNormalizedRealmName() or "" end
local function ownKey() return Guild.Key(GS.API.PlayerFullName(), realm()) end

-- The guild's key: its name and ITS realm (measured: it can differ from ours), or nil.
local function guildKey()
    if not IsInGuild() then return nil end
    local name, _, _, grealm = GetGuildInfo("player")
    if type(name) ~= "string" or name == "" then return nil end   -- not known yet, just after login
    return name .. "-" .. ((type(grealm) == "string" and grealm ~= "") and grealm or realm())
end

-- GnomesweeperDB.social: reading never creates it (as Scores), writing does.
local function social(create)
    local s = db().social
    if type(s) ~= "table" then
        if not create then return nil end
        s = { version = 1 }
        db().social = s
    end
    if create then
        if type(s.mine) ~= "table" then s.mine = {} end
        if type(s.guilds) ~= "table" then s.guilds = {} end
    end
    return s
end

------------------------------------------------------------
-- This character's own bests (docs/SOCIAL.md: per character, beside the account's scores)
------------------------------------------------------------

-- Seeded once from the account's scores: only the records this character set
-- (its full name AND its realm, as the scores keep them: GetRealmName()).
local function seed(mine)
    local scores = db().scores
    if type(scores) ~= "table" then return end
    local name, rname = GS.API.PlayerFullName(), GetRealmName()
    for _, cat in ipairs(Guild.CATEGORIES) do
        local e = scores[cat]
        local best = type(e) == "table" and e.best
        if type(best) == "table" and best.name == name and best.realm == rname and not mine[cat] then
            local cs = Guild.Cs(best.time)
            local at = math.floor(tonumber(best.at) or 0)
            if cs and at >= Guild.MIN_AT and at <= Guild.MAX_AT then mine[cat] = { cs = cs, at = at } end
        end
    end
end

local function mine(create)
    local key = ownKey()
    if not key then return nil end
    local s = social(create)
    local m = s and type(s.mine) == "table" and s.mine[key]
    if type(m) == "table" then return m end
    if not create then
        -- Nothing written yet: what seeding would give, without writing it (reading never
        -- creates the table).
        local preview = {}
        seed(preview)
        return next(preview) and preview or nil
    end
    m = {}
    seed(m)
    s.mine[key] = m
    return m
end

local function ownRecords()
    local m = mine(false)
    local list = {}
    if not m then return list end
    for _, cat in ipairs(Guild.CATEGORIES) do
        local b = m[cat]
        if type(b) == "table" and type(b.cs) == "number" and type(b.at) == "number" then
            list[#list + 1] = { cat = cat, cs = b.cs, at = b.at }
        end
    end
    return list
end

------------------------------------------------------------
-- Sending
------------------------------------------------------------

local function register()
    if registered == nil then
        local ok, result = pcall(C_ChatInfo.RegisterAddonMessagePrefix, Social.PREFIX)
        registered = ok and result or ("error: " .. tostring(result))
    end
    return registered
end

-- ChatThrottleLib (Libs\, as AltStable) paces it when it's there; else a direct send.
local function send(msg, prio)
    if not (msg and IsInGuild()) then return false end
    register()
    local ctl = rawget(_G, "ChatThrottleLib")
    if ctl and ctl.SendAddonMessage then
        return pcall(ctl.SendAddonMessage, ctl, prio or "BULK", Social.PREFIX, msg, "GUILD") and true or false
    end
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, Social.PREFIX, msg, "GUILD")
    return ok and (result == 0 or result == nil or result == true)
end

local function query(force)
    local gk = guildKey()
    if not gk then return false end
    local now = GetTime()
    if not force and lastQuery and now - lastQuery < Social.QUERY_GAP then return false end
    lastQuery, queriedGuild = now, gk
    return send(Guild.Encode("Q"), "BULK")
end

function Social.QueryIfStale()
    local gk = guildKey()
    if not gk then return false end
    if queriedGuild == gk and lastQuery and GetTime() - lastQuery < Social.STALE then return false end
    return query(false)
end

-- A reply to a Q: deferred and coalesced, never dropped (docs/SOCIAL.md). One pending
-- at most; another Q while it waits changes nothing; after a reply, the next waits
-- out REPLY_GAP, so a late joiner still gets one.
local function scheduleReply(gk)
    if pending then return end
    local now = GetTime()
    local jitter = Social.JITTER_MIN + math.random() * (Social.JITTER_MAX - Social.JITTER_MIN)
    local at = now + jitter
    if lastReply and lastReply + Social.REPLY_GAP + jitter > at then at = lastReply + Social.REPLY_GAP + jitter end
    local mineP = { guild = gk }
    pending = mineP
    C_Timer.After(at - now, function()
        if pending ~= mineP then return end            -- cancelled (a guild change)
        pending = nil
        if guildKey() ~= gk then return end            -- not that guild any more
        local records = ownRecords()
        if #records == 0 then return end
        lastReply = GetTime()
        send(Guild.Encode("B", records), "BULK")
    end)
end

------------------------------------------------------------
-- A win
------------------------------------------------------------

function Social.RecordWin(category, seconds)
    local cs = Guild.Cs(seconds)
    if not (cs and type(category) == "string") then return false end
    local m = mine(true)
    if not m then return false end
    local held = m[category]
    if type(held) == "table" and type(held.cs) == "number" and held.cs <= cs then return false end
    local at = time()
    m[category] = { cs = cs, at = at }
    if guildKey() then send(Guild.Encode("N", { { cat = category, cs = cs, at = at } }), "NORMAL") end
    return true
end

function Social.Reset()
    local s = social(false)
    if s then s.mine = {} end
end

------------------------------------------------------------
-- What the Guild tab shows
------------------------------------------------------------

function Social.GuildName()
    if not IsInGuild() then return nil end
    local name = GetGuildInfo("player")
    return (type(name) == "string" and name ~= "") and name or nil
end

-- The guild's times in a category, best first, ours merged in: { key, name, cs, at, mine }.
function Social.Ranking(category)
    local gk = guildKey()
    if not gk then return {} end
    local s = social(false)
    local bucket = s and type(s.guilds) == "table" and s.guilds[gk]
    local own = { key = ownKey() }
    local m = mine(false)
    own.best = m and m[category]
    local list = Guild.Ranking(bucket, category, own)
    for _, r in ipairs(list) do r.name = Guild.Display(r.key, realm()) end
    return list
end

------------------------------------------------------------
-- Receiving
------------------------------------------------------------

local function receive(text, channel, sender)
    if channel ~= "GUILD" then return end
    local key = Guild.Key(sender, realm())
    if not key or key == ownKey() then return end      -- our own echo
    local msg = Guild.Parse(text)
    if not msg then return end
    local gk = guildKey()
    if not gk then return end
    if msg.type == "Q" then
        scheduleReply(gk)
        return
    end
    local s = social(true)
    if type(s.guilds[gk]) ~= "table" then s.guilds[gk] = {} end
    s.guilds[gk][key] = Guild.Merge(s.guilds[gk][key], msg.records, time())
    if GS.Window and GS.Window.SocialChanged then GS.Window.SocialChanged() end
end

------------------------------------------------------------
-- The probe (phase 0, for measuring)
------------------------------------------------------------

local function show(v)
    if v == nil then return "nil" end
    if type(v) == "string" then return string.format("%q", v) end
    return tostring(v)
end

local probing = false

local function log(fmt, ...)
    local line = string.format(fmt, ...)
    GS.Print("guildprobe: " .. line)
    local d = db()
    if type(d.guildProbe) ~= "table" then d.guildProbe = {} end
    table.insert(d.guildProbe, date("%H:%M:%S") .. "  " .. line)
    while #d.guildProbe > Social.PROBE_KEEP do table.remove(d.guildProbe, 1) end
end

local function identity()
    local name, second = UnitName("player")
    log("UnitName = %s, %s", show(name), show(second))
    local full, server = UnitFullName("player")
    log("UnitFullName = %s, %s", show(full), show(server))
    log("GetRealmName = %s, GetNormalizedRealmName = %s", show(GetRealmName()), show(GetNormalizedRealmName()))
    log("API.PlayerFullName = %s", show(GS.API.PlayerFullName()))
    log("IsInGuild = %s", show(IsInGuild()))
    local g = { GetGuildInfo("player") }
    log("GetGuildInfo = %s, %s, %s, %s", show(g[1]), show(g[2]), show(g[3]), show(g[4]))
end

local function probeLog(text, channel, sender, target, zoneChannelID, localID, name, instanceID)
    log("CHAT_MSG_ADDON channel=%s sender=%s target=%s", show(channel), show(sender), show(target))
    log("  text=%s zone=%s local=%s name=%s instance=%s", show(text), show(zoneChannelID), show(localID), show(name), show(instanceID))
    for _, ctx in ipairs({ "none", "short", "guild", "mail" }) do
        local ok, out = pcall(Ambiguate, sender, ctx)
        log("  Ambiguate(sender, %q) = %s", ctx, ok and show(out) or ("error " .. tostring(out)))
    end
end

function Social.Probe()
    probing = true
    log("prefix %s registered: %s", Social.PREFIX, show(register()))
    identity()
    if not IsInGuild() then
        log("not in a guild: nothing sent (join one, or use a character in one, and try again)")
        return
    end
    local message = "1\tP\t" .. time()
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, Social.PREFIX, message, "GUILD")
    log("SendAddonMessage(GUILD) = %s", ok and show(result) or ("error " .. tostring(result)))
    log("waiting for the echo (it should arrive within a second or two); then /reload to save")
end

------------------------------------------------------------
-- Events
------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_GUILD_UPDATE")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender, target, zone, localID, name, instance = ...
        if prefix ~= Social.PREFIX then return end
        if probing then probeLog(text, channel, sender, target, zone, localID, name, instance) end
        receive(text, channel, sender)
    elseif event == "PLAYER_ENTERING_WORLD" then
        if loggedIn then return end                    -- once a session, not on every loading screen
        loggedIn = true
        register()
        -- Forget members silent for 30 days, in every guild we've kept.
        local s = social(false)
        if s and type(s.guilds) == "table" then
            for _, bucket in pairs(s.guilds) do Guild.Prune(bucket, time(), Social.FORGET) end
        end
        C_Timer.After(Social.LOGIN_DELAY, function()
            currentGuild = guildKey()
            query(true)
        end)
    elseif event == "PLAYER_GUILD_UPDATE" then
        local gk = guildKey()
        if gk ~= currentGuild then
            -- Another guild (or none): what was pending for the old one goes.
            pending, lastQuery, queriedGuild = nil, nil, nil
            currentGuild = gk
        end
    end
end)

Social._test = {
    registered = function() return registered end,
    ownKey = ownKey,
    guildKey = guildKey,
    pending = function() return pending end,
    reset = function() registered, lastQuery, queriedGuild, lastReply, pending, currentGuild, loggedIn, probing = nil, nil, nil, nil, nil, nil, nil, false end,
}
