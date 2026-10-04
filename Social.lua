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
--   Social.SettingsChanged()             the toasts' setting: off clears the queue
--
-- The guild-best toast (#17): a guildmate's N that is strictly faster than every time
-- this client knows for that category, once it has heard the guild since login (a B
-- arrived, and the replies' whole window has passed since our query). Queued (at most
-- 3), rechecked when shown, never in combat (one showing hides, and comes back after),
-- cleared by a guild change or the setting turned off. Toast.lua draws it.
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
-- After our query, the replies' whole window: a reply deferred past the minute, its jitter, and slack.
Social.SYNC_WINDOW = Social.REPLY_GAP + Social.JITTER_MAX + 4
Social.TOAST_QUEUE = 3           -- toasts waiting, at most (the oldest go)

local registered                 -- the prefix's registration result, once asked
local lastQuery                  -- GetTime() of our last Q
local queriedGuild               -- the guild that Q went to
local lastReply                  -- GetTime() of our last B
local pending                    -- the reply waiting to go: { guild = key }, or nil
local currentGuild               -- the guild key last seen (a change cancels what's pending)
local loggedIn                   -- the login query is once a session
local loginDue                   -- the login query couldn't go yet (the guild not known yet)
local firstQuery = {}            -- [guildKey] = GetTime() of this session's first query to it
local heard = {}                 -- [guildKey] = a B or an N arrived this session (the guild is heard)
local inCombat                   -- from the REGEN events, as Sounds.lua (the API can lag behind them)
local queue = {}                 -- toasts waiting: { guild, key, cat, cs }
local current                    -- the toast on screen

local function db() return GnomesweeperDB end
local function realm() return GetNormalizedRealmName() or "" end
local function ownKey() return Guild.Key(GS.API.PlayerFullName(), realm()) end

-- The guild: its name, and its key (its name and ITS realm: measured, it can differ
-- from ours). nil, nil out of a guild, or just after login before the client knows it.
local function guildInfo()
    if not IsInGuild() then return nil, nil end
    local name, _, _, grealm = GetGuildInfo("player")
    if type(name) ~= "string" or name == "" then return nil, nil end
    return name, name .. "-" .. ((type(grealm) == "string" and grealm ~= "") and grealm or realm())
end
local function guildKey() return (select(2, guildInfo())) end

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
    -- Nothing written yet: seed it. Kept at once when there is a record of this character's
    -- (a preview could be lost: an alt beating the account's best before this character's
    -- next win would take the record from the scores). Reading creates nothing otherwise.
    local seeded = {}
    seed(seeded)
    if not create and not next(seeded) then return nil end
    s = social(true)
    s.mine[key] = seeded
    return seeded
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
-- The result is read (docs/SOCIAL.md): a failure calls onFail (with ChatThrottleLib, when the
-- message actually leaves, which can be later) and is kept in Social.lastFailure, which
-- /gsweep guildprobe reports. Returns false when it failed at once.
local function failed(result, onFail)
    Social.lastFailure = tostring(result) .. " at " .. date("%H:%M:%S")
    if onFail then onFail() end
end
local function send(msg, prio, onFail)
    if not (msg and IsInGuild()) then return false end
    register()
    local ctl = rawget(_G, "ChatThrottleLib")
    if ctl and ctl.SendAddonMessage then
        local ok, err = pcall(ctl.SendAddonMessage, ctl, prio or "BULK", Social.PREFIX, msg, "GUILD", nil, nil,
            function(_, didSend, result) if not didSend then failed(result, onFail) end end)
        if not ok then failed(err, onFail) end
        return ok
    end
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, Social.PREFIX, msg, "GUILD")
    if ok and (result == 0 or result == nil or result == true) then return true end
    failed(ok and result or "error", onFail)
    return false
end

-- A query: counted only if it isn't refused (a failed one would block the tab's for 5 minutes).
local function query(force)
    local gk = guildKey()
    if not gk then return false end
    local now = GetTime()
    if not force and lastQuery and now - lastQuery < Social.QUERY_GAP then return false end
    local wasQuery, wasGuild = lastQuery, queriedGuild
    lastQuery, queriedGuild = now, gk
    local wasFirst = firstQuery[gk]
    firstQuery[gk] = firstQuery[gk] or now
    local mineQ = now
    return send(Guild.Encode("Q"), "BULK", function()
        if lastQuery == mineQ then lastQuery, queriedGuild = wasQuery, wasGuild end
        if firstQuery[gk] == mineQ then firstQuery[gk] = wasFirst end
    end)
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
        local wasReply = lastReply
        lastReply = GetTime()
        local mineR = lastReply
        send(Guild.Encode("B", records), "BULK", function()
            if lastReply == mineR then lastReply = wasReply end   -- a failed reply doesn't hold back the next
        end)
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

function Social.GuildName() return (guildInfo()) end

-- The Guild tab's view, looked up once: { name = the guild's or nil, ranking = function(category)
-- -> { {key, name, cs, at, mine}... } best first, ours merged in }.
function Social.View()
    local name, gk = guildInfo()
    local view = { name = name }
    if not gk then
        view.ranking = function() return {} end
        return view
    end
    local s = social(false)
    local bucket = s and type(s.guilds) == "table" and s.guilds[gk]
    local key, r, m = ownKey(), realm(), mine(false)
    view.ranking = function(category)
        local list = Guild.Ranking(bucket, category, { key = key, best = m and m[category] })
        for _, e in ipairs(list) do e.name = Guild.Display(e.key, r) end
        return list
    end
    return view
end

function Social.Ranking(category) return Social.View().ranking(category) end

------------------------------------------------------------
-- The guild-best toast (#17)
------------------------------------------------------------

-- Heard the guild since login: a B or an N arrived, and the replies' whole window has passed
-- since our first query (a reply can take ~66 s). Silence never counts. An N counts too (review
-- of #66): in a guild where nobody has a time yet nobody sends a B, and by the window's end
-- anyone with a time would have replied.
local function synced(gk)
    return heard[gk] and firstQuery[gk] and GetTime() - firstQuery[gk] >= Social.SYNC_WINDOW or false
end

-- The fastest time this client knows in a category: the guild's (but `skip`'s) and ours.
local function fastestKnown(gk, cat, skip)
    local best
    local s = social(false)
    local bucket = s and type(s.guilds) == "table" and s.guilds[gk]
    for key, entry in pairs(type(bucket) == "table" and bucket or {}) do
        local b = key ~= skip and type(entry) == "table" and type(entry.bests) == "table" and entry.bests[cat]
        if type(b) == "table" and type(b.cs) == "number" and (not best or b.cs < best) then best = b.cs end
    end
    local m = mine(false)
    local own = m and m[cat]
    if type(own) == "table" and type(own.cs) == "number" and (not best or own.cs < best) then best = own.cs end
    return best
end

-- The difficulty, and the first-click rule when it's the single safe tile (review of #66: each
-- rule keeps its own bests, so "Beginner" alone could contradict a faster time under the other).
local function difficultyLabel(cat)
    local d, rule = cat:match("^(%a+):(%a+)$")
    local name = (GS.Window.LABELS or {})[d] or d or cat
    if rule == "cell" then name = string.format(GS.L["%s (one safe tile)"], name) end
    return name
end

local function toastText(t)
    return string.format(GS.L["%s cleared %s in %s, a new guild best!"], Guild.Display(t.key, realm()),
        difficultyLabel(t.cat), GS.Window.GuildTime(t.cs))
end

local showNext
showNext = function()
    if current or GS.Toast.IsShown() then return end
    if inCombat then return end                                -- after the fight
    while #queue > 0 do
        local t = table.remove(queue, 1)
        -- Rechecked: still this guild, and still strictly the fastest (nothing better
        -- arrived meanwhile, the sender's own later best included).
        if guildKey() == t.guild then
            local known = fastestKnown(t.guild, t.cat, t.key)
            local s = social(false)
            local bucket = s and type(s.guilds) == "table" and s.guilds[t.guild]
            local held = type(bucket) == "table" and bucket[t.key]
            local theirs = type(held) == "table" and type(held.bests) == "table" and held.bests[t.cat]
            if (not known or t.cs < known) and not (theirs and theirs.cs < t.cs) then
                current = t
                GS.Toast.Show(toastText(t), function()
                    current = nil
                    showNext()
                end)
                return
            end
        end
    end
end

-- At most TOAST_QUEUE wait: the oldest unseen goes first, never one a fight interrupted.
local function trim()
    while #queue > Social.TOAST_QUEUE do
        local drop = 1
        for i, t in ipairs(queue) do if not t.interrupted then drop = i; break end end
        table.remove(queue, drop)
    end
end

local function enqueue(t)
    queue[#queue + 1] = t
    trim()
    showNext()
end

function Social.SettingsChanged()
    if db().guildToasts == false then
        queue, current = {}, nil
        GS.Toast.Hide()
    end
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
    heard[gk] = true
    -- A guild best? Decided before it's merged in (it would be compared with itself).
    local toast
    if msg.type == "N" and synced(gk) and db().guildToasts ~= false then
        local r = msg.records[1]
        local known = fastestKnown(gk, r.cat, nil)
        if not known or r.cs < known then toast = { guild = gk, key = key, cat = r.cat, cs = r.cs } end
    end
    local s = social(true)
    if type(s.guilds[gk]) ~= "table" then s.guilds[gk] = {} end
    s.guilds[gk][key] = Guild.Merge(s.guilds[gk][key], msg.records, time())
    if toast then enqueue(toast) end
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
    log("last guild send failure: %s", show(Social.lastFailure))
    log("waiting for the echo (it should arrive within a second or two); then /reload to save")
end

------------------------------------------------------------
-- Events
------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_GUILD_UPDATE")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
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
        inCombat = UnitAffectingCombat("player") and true or false
        -- This character's records from the account's scores, kept now (Codex, #63): left
        -- until a win or the Guild tab, an alt's new best could take them from the scores first.
        mine(false)
        -- Forget members silent for 30 days, in every guild we've kept.
        local s = social(false)
        if s and type(s.guilds) == "table" then
            for _, bucket in pairs(s.guilds) do Guild.Prune(bucket, time(), Social.FORGET) end
        end
        C_Timer.After(Social.LOGIN_DELAY, function()
            loginDue = true
            local gk = guildKey()
            if gk and currentGuild == nil then currentGuild = gk end
            -- Already asked this guild (the Guild tab, in the first seconds): that was the login
            -- query; the once-a-minute limit holds (Codex, #63).
            if gk and queriedGuild == gk then loginDue = false end
            if gk and loginDue and query(true) then loginDue = false end
        end)
    elseif event == "PLAYER_GUILD_UPDATE" then
        local gk = guildKey()
        -- In a guild but its name not loaded for a moment (a zone change): not a change (review of #66).
        if gk == nil and IsInGuild() then gk = currentGuild end
        if currentGuild ~= nil and gk ~= currentGuild then
            -- Another guild (or none): what was pending for the old one goes. (Only a change:
            -- the first time the guild is known, just after login, isn't one, and must not
            -- cancel a reply a guildmate is owed.)
            pending, lastQuery, queriedGuild = nil, nil, nil
            queue, current = {}, nil                      -- the old guild's toasts go too
            GS.Toast.Hide()
        end
        if gk then currentGuild = gk end
        if gk == nil and IsInGuild() == false then currentGuild = nil end
        -- The login query, if the guild wasn't known yet when it was due (a slow login).
        if gk and loginDue and queriedGuild ~= gk and query(true) then loginDue = false end
        if GS.Window and GS.Window.SocialChanged then GS.Window.SocialChanged() end   -- a Guild tab open shows it
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        -- A fight: a toast on screen goes, and comes back after (docs/SOCIAL.md).
        if current then
            current.interrupted = true
            table.insert(queue, 1, current)
            current = nil
            trim()
        end
        GS.Toast.Hide()
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        showNext()
    end
end)

Social._test = {
    registered = function() return registered end,
    ownKey = ownKey,
    guildKey = guildKey,
    pending = function() return pending end,
    currentGuild = function() return currentGuild end,
    queue = function() return queue end,
    current = function() return current end,
    synced = synced,
    reset = function()
        registered, lastQuery, queriedGuild, lastReply, pending, currentGuild, loggedIn, loginDue, probing = nil, nil, nil, nil, nil, nil, nil, nil, false
        firstQuery, heard, queue, current, inCombat = {}, {}, {}, nil, nil
    end,
}
