-- Guild.lua (#15, docs/SOCIAL.md): the wire format, the eligibility rule, the order,
-- merging, ranking, pruning and keys, loaded with every global but a few builtins
-- forbidden.
dofile("tests/harness.lua")

local G = loadPure(newPureEnv(), "Guild.lua").Guild

local T = 1791077953                     -- an epoch (2026)
local function rec(cat, cs, at) return { cat = cat, cs = cs, at = at or T } end

-- The eligibility rule
eq(G.Cs(84.129), 8412, "84.129 s is 8412 centiseconds (truncated)")
eq(G.Cs(1), 100, "1 s counts")
eq(G.Cs(0.99), nil, "under 1 s doesn't (a first click that clears the board)")
eq(G.Cs(0), nil, "...nor 0 s")
eq(G.Cs(99999.99), 9999999, "about 27 h is the last that counts")
eq(G.Cs(100000), nil, "...and past it, not")
eq(G.Cs(0 / 0), nil, "NaN doesn't")
eq(G.Cs("42"), nil, "a string doesn't")

-- Encode
eq(G.Encode("Q"), "1\tQ", "Q: no records")
eq(G.Encode("N", { rec("expert:area", 8412) }), "1\tN\texpert:area=8412@" .. T, "N: one record")
eq(G.Encode("B", { rec("beginner:area", 1234), rec("expert:cell", 9000) }),
    "1\tB\tbeginner:area=1234@" .. T .. "\texpert:cell=9000@" .. T, "B: the records, in order")
eq(G.Encode("X", {}), nil, "an unknown type isn't encoded")
eq(G.Encode("N", {}), nil, "N needs exactly one record")
eq(G.Encode("B", {}), nil, "B needs at least one")
eq(G.Encode("Q", { rec("expert:area", 8412) }), nil, "Q has none")
eq(G.Encode("B", { rec("expert:area", 8412), rec("expert:area", 9000) }), nil, "a category twice isn't encoded")
eq(G.Encode("N", { rec("expert:hard", 8412) }), nil, "an unknown category isn't")
eq(G.Encode("N", { rec("expert:area", 99) }), nil, "a time under 1 s isn't")
eq(G.Encode("N", { rec("expert:area", 8412.5) }), nil, "nor a fraction of a centisecond")
eq(G.Encode("N", { rec("expert:area", 8412, 123) }), nil, "nor an epoch that isn't 10 digits")

-- The bound: the longest legal B
local all = {}
for _, c in ipairs(G.CATEGORIES) do all[#all + 1] = rec(c, G.MAX_CS, G.MAX_AT) end
local longest = G.Encode("B", all)
check(longest ~= nil, "the longest legal B encodes")
eq(#longest, 205, "...in 205 bytes (docs/SOCIAL.md)")
check(#longest <= 255, "...under the 255-byte cap")

-- Parse: round trips
local p = G.Parse(longest)
eq(p.type, "B", "the longest B parses")
eq(#p.records, 6, "...six records")
eq(p.records[3].cat, "expert:area", "...in order")
eq(p.records[3].cs, G.MAX_CS, "...the time")
eq(p.records[3].at, G.MAX_AT, "...the epoch")
p = G.Parse("1\tQ")
eq(p and p.type, "Q", "Q parses")
eq(#p.records, 0, "...with no records")
p = G.Parse(G.Encode("N", { rec("intermediate:cell", 4321) }))
eq(p.records[1].cat, "intermediate:cell", "N round-trips")
eq(p.records[1].cs, 4321, "...its time")

-- Parse: what's ignored, and why
local function why(msg) local r, w = G.Parse(msg); return r == nil and w or "parsed" end
eq(why("2\tQ"), "version", "a version we don't know is ignored whole")
eq(why("1\tP\t1791077953"), "type", "an unknown type is ignored (the probe's P)")
eq(why("1\tZ"), "type", "...any unknown type")
-- malformed: dropped whole
local BAD = {
    ["1\tQ\texpert:area=8412@" .. T] = "records on a Q",
    ["1\tN"] = "N without its record",
    ["1\tN\texpert:area=8412@" .. T .. "\texpert:cell=8412@" .. T] = "two records on an N",
    ["1\tB"] = "B without records",
    ["1\tB\texpert:area=8412@" .. T .. "\texpert:area=9000@" .. T] = "a category twice",
    ["1\tB\texpert:area=8412@" .. T .. "\t"] = "an empty trailing field",
    ["1\tB\t\texpert:area=8412@" .. T] = "an empty field",
    ["1\tN\texpert:hard=8412@" .. T] = "an unknown category",
    ["1\tN\texpert:area=-8412@" .. T] = "a sign",
    ["1\tN\texpert:area=+8412@" .. T] = "a plus sign",
    ["1\tN\texpert:area=08412@" .. T] = "a leading zero",
    ["1\tN\texpert:area=84.12@" .. T] = "a decimal point",
    ["1\tN\texpert:area=99@" .. T] = "a time under 1 s",
    ["1\tN\texpert:area=10000000@" .. T] = "a time past 27 h",
    ["1\tN\texpert:area=8412@179107795"] = "a 9-digit epoch",
    ["1\tN\texpert:area=8412@0000000000"] = "an epoch of ten zeros",
    ["1\tN\texpert:area=8412@17910779530"] = "an 11-digit epoch",
    ["1\tN\texpert:area=8412"] = "no epoch",
    ["1\tN\texpert:area@" .. T] = "no time",
    ["1\tN\texpert:area=0x20@" .. T] = "hex",
    ["1\tN\texpert:area=8412@" .. T .. "x"] = "trailing junk",
    [""] = "an empty message",
    ["1"] = "a version alone",
    ["1\tB\t" .. string.rep("x", 260)] = "over 255 bytes",
}
for msg, what in pairs(BAD) do
    local r = G.Parse(msg)
    eq(r, nil, "malformed, dropped whole: " .. what)
end
eq(G.Parse(nil), nil, "nil isn't a message")
eq(G.Parse(42), nil, "nor a number")

-- The order: the faster time, then the earlier win, then the key
check(G.Better({ cs = 100, at = 2, key = "b" }, { cs = 200, at = 1, key = "a" }), "a faster time ranks first")
check(G.Better({ cs = 100, at = 1, key = "b" }, { cs = 100, at = 2, key = "a" }), "a tie: the earlier win")
check(G.Better({ cs = 100, at = 1, key = "a" }, { cs = 100, at = 1, key = "b" }), "a tie on both: the key")
check(not G.Better({ cs = 100, at = 1, key = "a" }, { cs = 100, at = 1, key = "a" }), "...never better than itself")

-- Merge
local e = G.Merge(nil, { rec("expert:area", 9000, T) }, 500)
eq(e.bests["expert:area"].cs, 9000, "a first record is kept")
eq(e.seen, 500, "seen is our clock")
G.Merge(e, { rec("expert:area", 8000, T + 10) }, 600)
eq(e.bests["expert:area"].cs, 8000, "a faster one replaces it")
G.Merge(e, { rec("expert:area", 9500, T - 10) }, 700)
eq(e.bests["expert:area"].cs, 8000, "an older, slower B arriving later never replaces a faster N")
eq(e.seen, 700, "...though it is heard")
G.Merge(e, { rec("expert:area", 8000, T) }, 800)
eq(e.bests["expert:area"].at, T, "the same time, earlier: the earlier win is kept")
G.Merge(e, { rec("beginner:area", 1500) }, 900)
eq(e.bests["expert:area"].cs, 8000, "a category missing from a message deletes nothing")
eq(e.bests["beginner:area"].cs, 1500, "...and a new one is added")
local damaged = { bests = { ["expert:area"] = { cs = "fast", at = T } } }
G.Merge(damaged, { rec("expert:area", 9999) }, 1)
eq(damaged.bests["expert:area"].cs, 9999, "a damaged held record is replaced")

-- Prune
local bucket = { ["A-R"] = { seen = 100 }, ["B-R"] = { seen = 1000 }, ["C-R"] = "junk" }
eq(G.Prune(bucket, 1000 + 30 * 86400 - 1, 30 * 86400), 2, "members silent past 30 days, and junk, go")
check(bucket["B-R"] and not bucket["A-R"] and not bucket["C-R"], "...the recent one stays")

-- Ranking
local guild = {
    ["Ann Gear-R"] = { seen = 1, bests = { ["expert:area"] = { cs = 9000, at = T } } },
    ["Bob Cog-R"] = { seen = 1, bests = { ["expert:area"] = { cs = 8000, at = T + 5 } } },
    ["Cal Bolt-R"] = { seen = 1, bests = { ["expert:area"] = { cs = 8000, at = T } } },
    ["Me Myself-R"] = { seen = 1, bests = { ["expert:area"] = { cs = 1, at = T } } },   -- a stale echo of us: replaced by ours
    ["Dee Nut-R"] = { seen = 1, bests = { ["beginner:area"] = { cs = 500, at = T } } },
}
local r = G.Ranking(guild, "expert:area", { key = "Me Myself-R", best = { cs = 8500, at = T } })
eq(#r, 4, "the ranking: everyone with a time in the category, us included once")
eq(r[1].key, "Cal Bolt-R", "...a tie on time: the earlier win first")
eq(r[2].key, "Bob Cog-R", "...then the later")
eq(r[3].key, "Me Myself-R", "...our own best, from our store, not the cache")
check(r[3].mine, "...marked as ours")
eq(r[4].key, "Ann Gear-R", "...then the slowest")
eq(#G.Ranking(guild, "expert:area", { key = "Me Myself-R" }), 3, "with no best of our own, we're not ranked (and our stale echo isn't)")
eq(#G.Ranking(nil, "expert:area"), 0, "no guild data: an empty ranking")

-- Keys (measured on 70205: a guild sender is "Name Surname", no realm)
eq(G.Key("Kaleid Sumner", "ClassicBetaPvE"), "Kaleid Sumner-ClassicBetaPvE", "a sender without a realm gets ours")
eq(G.Key("Kaleid Sumner-OtherRealm", "ClassicBetaPvE"), "Kaleid Sumner-OtherRealm", "one with a realm keeps it")
eq(G.Key("", "R"), nil, "an empty sender has no key")
eq(G.Key(nil, "R"), nil, "...nor nil")
eq(G.Display("Kaleid Sumner-ClassicBetaPvE", "ClassicBetaPvE"), "Kaleid Sumner", "our realm isn't shown")
eq(G.Display("Kaleid Sumner-OtherRealm", "ClassicBetaPvE"), "Kaleid Sumner-OtherRealm", "another realm is")
eq(G.Display("Zoë Écrou-R", "R"), "Zoë Écrou", "UTF-8 names are kept as they are")

-- R: forget my times from before <at> (a reset); after Q, B, N shipped, so older clients ignore it
eq(G.Encode("R", nil, T), "1\tR\t" .. T, "R: the reset's time, no records")
eq(G.Encode("R", { rec("expert:area", 8412) }, T), nil, "R carries no records")
eq(G.Encode("R", nil, 123), nil, "...and a real epoch")
local pr = G.Parse("1\tR\t" .. T)
eq(pr and pr.type, "R", "R parses")
eq(pr and pr.at, T, "...with its time")
eq(G.Parse("1\tR"), nil, "an R without its time is malformed")
eq(G.Parse("1\tR\t0000000000"), nil, "...or with a bad one")
eq(G.Parse("1\tR\texpert:area=8412@" .. T), nil, "...or with a record")
-- Forget: the records from before the reset go, a newer one stays
local fe = { seen = 1, bests = { ["expert:area"] = { cs = 8000, at = T - 10 }, ["beginner:area"] = { cs = 900, at = T + 10 } } }
fe = G.Forget(fe, T)
eq(fe.bests["expert:area"], nil, "Forget drops a record from before the reset")
eq(fe.bests["beginner:area"].cs, 900, "...and keeps one earned after it (whatever order they arrived in)")
local emptied = G.Forget({ bests = { ["expert:area"] = { cs = 8000, at = T - 10 } } }, T)
eq(next(emptied.bests), nil, "nothing left: no records")
eq(emptied.resetAt, T, "...but the entry stays, with the reset as its cutoff")
G.Merge(emptied, { rec("expert:area", 5000, T - 5) }, 9)
eq(emptied.bests["expert:area"], nil, "a record from before the reset, arriving late, is refused")
G.Merge(emptied, { rec("expert:area", 9000, T + 5) }, 9)
eq(emptied.bests["expert:area"].cs, 9000, "...one from after it is kept")
local fresh = G.Forget(nil, T)
eq(fresh.resetAt, T, "an R before anything cached: an entry with just the cutoff")
G.Merge(fresh, { rec("beginner:area", 500, T - 1) }, 9)
eq(fresh.bests["beginner:area"], nil, "...so an older message arriving after it is refused too")
eq(#G.Ranking({ ["X-R"] = emptied, ["Y-R"] = fresh }, "beginner:area"), 0, "an emptied entry ranks nothing")

done("test_guild")
