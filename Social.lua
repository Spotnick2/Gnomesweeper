-- Social.lua: the guild's best times and the guild-best toasts (#15, #17, #16).
-- The plan is docs/SOCIAL.md. Phase 0, here for now: the probe that measures what
-- the plan's identity rests on, before anything is saved or sent for real.
--
--   /gsweep guildprobe   what this character is called (every API's answer), then a
--                        probe message to the guild; the server echoes a guild addon
--                        message to its sender, so one character in a guild is enough.
--                        Every line is also kept in GnomesweeperDB.guildProbe, for a
--                        /reload to write it to disk.
--
-- The probe's message is type "P", which no v1 client knows: anyone else with the
-- addon ignores it (docs/SOCIAL.md: an unknown type is ignored).

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local GS = Gnomesweeper
local Social = {}
GS.Social = Social

Social.PREFIX = "GSWEEP"
Social.PROBE_KEEP = 200          -- lines kept in GnomesweeperDB.guildProbe

local registered                 -- the prefix's registration result, once asked

local function show(v)
    if v == nil then return "nil" end
    if type(v) == "string" then return string.format("%q", v) end
    return tostring(v)
end

local function log(fmt, ...)
    local line = string.format(fmt, ...)
    GS.Print("guildprobe: " .. line)
    local db = GnomesweeperDB
    if type(db.guildProbe) ~= "table" then db.guildProbe = {} end
    table.insert(db.guildProbe, date("%H:%M:%S") .. "  " .. line)
    while #db.guildProbe > Social.PROBE_KEEP do table.remove(db.guildProbe, 1) end
end

local function register()
    if registered == nil then
        local ok, result = pcall(C_ChatInfo.RegisterAddonMessagePrefix, Social.PREFIX)
        registered = ok and result or ("error: " .. tostring(result))
    end
    return registered
end

-- Every way the client names this character, side by side.
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

-- What arrives: every argument, and what Ambiguate makes of the sender.
local function onAddon(_, _, prefix, text, channel, sender, target, zoneChannelID, localID, name, instanceID)
    if prefix ~= Social.PREFIX then return end
    log("CHAT_MSG_ADDON channel=%s sender=%s target=%s", show(channel), show(sender), show(target))
    log("  text=%s zone=%s local=%s name=%s instance=%s", show(text), show(zoneChannelID), show(localID), show(name), show(instanceID))
    for _, ctx in ipairs({ "none", "short", "guild", "mail" }) do
        local ok, out = pcall(Ambiguate, sender, ctx)
        log("  Ambiguate(sender, %q) = %s", ctx, ok and show(out) or ("error " .. tostring(out)))
    end
end

local listener = CreateFrame("Frame")
listener:RegisterEvent("CHAT_MSG_ADDON")
listener:SetScript("OnEvent", onAddon)

function Social.Probe()
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

Social._test = { onAddon = onAddon, registered = function() return registered end }
