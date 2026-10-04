-- Guild.lua: the guild's best times as pure Lua (#15, docs/SOCIAL.md). The wire
-- format (v1), the one eligibility rule, the one order, merging, ranking, pruning
-- and keys. No WoW API at all: tests/test_guild.lua loads it with every global but
-- a few builtins forbidden. Social.lua is the live half (events, timers, sending).
--
-- A message is fields separated by a tab:  1\t<type>[\t<record>...]
--   Q  a query: no records         B  my bests: 1 to 6 records, a category once
--   N  a new best: exactly one      R  forget my times (a reset): no records
-- R came after v1 shipped with Q, B and N: a client from then ignores it as an unknown type,
-- which is the rule this format was built on, so it needs no version bump.
-- A record is <category>=<cs>@<at>: one of the six categories, the time in whole
-- centiseconds (100..9999999, digits only, no leading zero), the win's epoch
-- (1000000000..9999999999). Anything else is malformed, and a malformed message is
-- dropped whole. A version we don't know, or a type we don't know, is ignored.
--
--   Guild.Cs(seconds)                 -> cs, or nil when the time doesn't count
--   Guild.Encode(type, records)       -> message, or nil, why
--   Guild.Parse(message)              -> { type =, records = { {cat, cs, at}... } }, or nil, why
--   Guild.Better(a, b)                -> a ranks before b: (cs, at, key), lower first
--   Guild.Merge(entry, records, seen) -> entry (created if nil), keeping the better per category
--   Guild.Prune(bucket, now, maxAge)  -> members dropped
--   Guild.Ranking(bucket, cat, own)   -> { {key, cs, at}... }, sorted, our own best merged in
--   Guild.Key(sender, realm)          -> the member key: the sender, with our realm if it has none
--   Guild.Display(key, realm)         -> the name to show: the key without our realm

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local Guild = {}
Gnomesweeper.Guild = Guild

Guild.VERSION = "1"
Guild.CATEGORIES = { "beginner:area", "intermediate:area", "expert:area",
                     "beginner:cell", "intermediate:cell", "expert:cell" }
local KNOWN = {}
for _, c in ipairs(Guild.CATEGORIES) do KNOWN[c] = true end
Guild.MIN_CS, Guild.MAX_CS = 100, 9999999            -- 1 s to about 27 h
Guild.MIN_AT, Guild.MAX_AT = 1000000000, 9999999999   -- 2001 to 2286
Guild.MAX_BYTES = 255
Guild.TYPES = { Q = true, B = true, N = true, R = true }

-- The one eligibility rule (docs/SOCIAL.md): what is sent, ranked and compared.
-- A first click that clears the board at 0 s is a best for the "You" tab, not for a guild.
function Guild.Cs(seconds)
    if type(seconds) ~= "number" or seconds ~= seconds then return nil end
    local cs = math.floor(seconds * 100 + 1e-9)
    if cs < Guild.MIN_CS or cs > Guild.MAX_CS then return nil end
    return cs
end

local function validNumber(n, lo, hi)
    return type(n) == "number" and n == math.floor(n) and n >= lo and n <= hi
end

local function validRecord(r)
    return type(r) == "table" and KNOWN[r.cat] and validNumber(r.cs, Guild.MIN_CS, Guild.MAX_CS)
        and validNumber(r.at, Guild.MIN_AT, Guild.MAX_AT)
end

function Guild.Encode(kind, records)
    records = records or {}
    if not Guild.TYPES[kind] then return nil, "type" end
    local n = #records
    if ((kind == "Q" or kind == "R") and n ~= 0) or (kind == "N" and n ~= 1) or (kind == "B" and (n < 1 or n > #Guild.CATEGORIES)) then
        return nil, "count"
    end
    local parts, seen = { Guild.VERSION, kind }, {}
    for _, r in ipairs(records) do
        if not validRecord(r) or seen[r.cat] then return nil, "record" end
        seen[r.cat] = true
        -- %.0f, not %d: Lua 5.1's %d is 32-bit, and an epoch past 2038 would overflow it.
        parts[#parts + 1] = string.format("%s=%.0f@%.0f", r.cat, r.cs, r.at)
    end
    local msg = table.concat(parts, "\t")
    if #msg > Guild.MAX_BYTES then return nil, "size" end
    return msg
end

-- Every tab-separated field, empty ones kept.
local function split(s)
    local fields, from = {}, 1
    while true do
        local at = s:find("\t", from, true)
        if not at then fields[#fields + 1] = s:sub(from); return fields end
        fields[#fields + 1] = s:sub(from, at - 1)
        from = at + 1
    end
end

-- Digits only, no sign, no leading zero, within bounds.
local function integer(s, lo, hi)
    if type(s) ~= "string" or not s:match("^[1-9]%d*$") or #s > 10 then return nil end
    local n = tonumber(s)
    if not n or n < lo or n > hi then return nil end
    return n
end

function Guild.Parse(msg)
    if type(msg) ~= "string" or #msg > Guild.MAX_BYTES then return nil, "malformed" end
    local f = split(msg)
    if f[1] ~= Guild.VERSION then return nil, "version" end
    local kind = f[2]
    if not Guild.TYPES[kind] then return nil, "type" end
    local n = #f - 2
    if ((kind == "Q" or kind == "R") and n ~= 0) or (kind == "N" and n ~= 1) or (kind == "B" and (n < 1 or n > #Guild.CATEGORIES)) then
        return nil, "malformed"
    end
    local records, seen = {}, {}
    for i = 3, #f do
        local cat, cs, at = f[i]:match("^([%l:]+)=([^@]*)@(.*)$")
        cs = integer(cs, Guild.MIN_CS, Guild.MAX_CS)
        at = integer(at, Guild.MIN_AT, Guild.MAX_AT)
        if not (cat and KNOWN[cat] and cs and at) or seen[cat] then return nil, "malformed" end
        seen[cat] = true
        records[#records + 1] = { cat = cat, cs = cs, at = at }
    end
    return { type = kind, records = records }
end

-- The one order (docs/SOCIAL.md): the faster time, then the earlier win, then the key.
function Guild.Better(a, b)
    if a.cs ~= b.cs then return a.cs < b.cs end
    if a.at ~= b.at then return a.at < b.at end
    return (a.key or "") < (b.key or "")
end

-- A member's entry: { seen = our epoch, bests = { [cat] = { cs, at } } }. A slower or
-- later record never replaces a better one; a category not in the message deletes nothing.
function Guild.Merge(entry, records, seen)
    entry = type(entry) == "table" and entry or {}
    if type(entry.bests) ~= "table" then entry.bests = {} end
    for _, r in ipairs(records) do
        local held = entry.bests[r.cat]
        if type(held) ~= "table" or not validNumber(held.cs, Guild.MIN_CS, Guild.MAX_CS)
            or not validNumber(held.at, Guild.MIN_AT, Guild.MAX_AT) or Guild.Better(r, held) then
            entry.bests[r.cat] = { cs = r.cs, at = r.at }
        end
    end
    entry.seen = seen
    return entry
end

-- Members not heard from in maxAge seconds go.
function Guild.Prune(bucket, now, maxAge)
    local dropped = 0
    if type(bucket) ~= "table" then return 0 end
    for key, entry in pairs(bucket) do
        if type(entry) ~= "table" or type(entry.seen) ~= "number" or now - entry.seen > maxAge then
            bucket[key] = nil
            dropped = dropped + 1
        end
    end
    return dropped
end

-- A category's times, best first: every member's, with ours (own = { key, best = {cs, at} })
-- in place of whatever the cache holds for our key.
function Guild.Ranking(bucket, cat, own)
    local list = {}
    for key, entry in pairs(type(bucket) == "table" and bucket or {}) do
        local b = type(entry) == "table" and type(entry.bests) == "table" and entry.bests[cat]
        if b and not (own and key == own.key) and validNumber(b.cs, Guild.MIN_CS, Guild.MAX_CS)
            and validNumber(b.at, Guild.MIN_AT, Guild.MAX_AT) then
            list[#list + 1] = { key = key, cs = b.cs, at = b.at }
        end
    end
    local mine = own and own.best
    if mine and validNumber(mine.cs, Guild.MIN_CS, Guild.MAX_CS) and validNumber(mine.at, Guild.MIN_AT, Guild.MAX_AT) then
        list[#list + 1] = { key = own.key, cs = mine.cs, at = mine.at, mine = true }
    end
    table.sort(list, Guild.Better)
    return list
end

-- The member key (measured, 70205: a guild sender is "Name Surname", no realm).
function Guild.Key(sender, realm)
    if type(sender) ~= "string" or sender == "" then return nil end
    if sender:find("-", 1, true) then return sender end
    return sender .. "-" .. (realm or "")
end

function Guild.Display(key, realm)
    if type(key) ~= "string" then return "?" end
    local suffix = "-" .. (realm or "")
    if #key > #suffix and key:sub(-#suffix) == suffix then return key:sub(1, #key - #suffix) end
    return key
end

Guild._test = { split = split, integer = integer }
