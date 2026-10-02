-- Board.lua: the game model. Pure Lua, so it is tested directly, with no WoW
-- stubs at all. The board is loaded with every global but a few builtins
-- forbidden, which is what "pure" means here.
dofile("tests/harness.lua")

local env = newPureEnv()
local Board = loadPure(env, "Board.lua").Board
check(Board ~= nil, "Board.lua defines Gnomesweeper.Board without touching any other global")

local function toc()
    local at = {}
    for i, f in ipairs(tocFiles()) do at[f] = i end
    return at
end
local order = toc()
check(order["Board.lua"] and order["Glass.lua"] and order["Board.lua"] > order["Glass.lua"]
    and order["Board.lua"] < order["Gnomesweeper.lua"], "Board.lua is in the TOC, after Glass and before the entry point")

----------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------
local function seeded(seed)
    local s = seed       -- Park-Miller: small enough that doubles stay exact
    return function(n)
        s = (s * 16807) % 2147483647
        return s % n + 1
    end
end

local function unique(list)
    local seen = {}
    for _, i in ipairs(list) do
        if seen[i] then return false end
        seen[i] = true
    end
    return true
end

local function set(list)
    local s = {}
    for _, i in ipairs(list) do s[i] = true end
    return s
end

local function sameSet(list, expected)
    local a, b = set(list), set(expected)
    for i in pairs(a) do if not b[i] then return false end end
    for i in pairs(b) do if not a[i] then return false end end
    return #list == #expected
end

local function countMines(b)
    local n = 0
    for _ in pairs(b._mine) do n = n + 1 end
    return n
end

local layout = Board._test.FromLayout

-- A wall of mines down column 3 of a 5x4 board: columns 1-2 and 4-5 are
-- separate regions, so a flood is visibly partial.
local WALL = { "..*..", "..*..", "..*..", "..*.." }
local function cellsOf(b, xs, ys)
    local out = {}
    for _, y in ipairs(ys) do for _, x in ipairs(xs) do out[#out + 1] = b:Index(x, y) end end
    return out
end

----------------------------------------------------------------------------
-- construction
----------------------------------------------------------------------------
check(Board.New(0, 9, 1) == nil, "width 0 is rejected")
check(Board.New(9, 0, 1) == nil, "height 0 is rejected")
check(Board.New(9.5, 9, 1) == nil, "a fractional width is rejected")
check(Board.New("9", 9, 1) == nil, "a string width is rejected")
check(Board.New(9, 9, -1) == nil, "negative mines are rejected")
check(Board.New(9, 9, 81) == nil, "mines == cells is rejected (the first click needs a safe cell)")
check(Board.New(9, 9, 1.5) == nil, "fractional mines are rejected")
check(Board.New(9, 9, 0 / 0) == nil, "NaN mines are rejected")
local _, why = Board.New(0, 0, 0)
check(type(why) == "string", "a rejection says why")
check(Board.New(1, 1, 0) ~= nil, "a 1x1 board with no mines is valid")
check(Board.New(9, 9, 80) ~= nil, "mines == cells - 1 is valid")

eq(Board.PRESETS.beginner.mines, 10, "Beginner is 10 mines")
eq(Board.PRESETS.intermediate.w * Board.PRESETS.intermediate.h, 256, "Intermediate is 16x16")
eq(Board.PRESETS.expert.w, 30, "Expert is 30 wide")
eq(Board.PRESETS.expert.h, 16, "Expert is 16 high")
eq(Board.PRESETS.expert.mines, 99, "Expert is 99 mines")

local fresh = Board.New(9, 9, 10, { rng = seeded(1) })
eq(fresh:State(), "ready", "a new board is ready")
eq(fresh:FlagsLeft(), 10, "a new board shows all its mines")
eq(countMines(fresh), 0, "no mines exist before the first reveal")
eq(fresh:Index(1, 1), 1, "Index(1,1) is 1")
eq(fresh:Index(9, 9), 81, "Index(w,h) is the last cell")
eq(fresh:Index(10, 1), nil, "Index outside the board is nil")
eq(fresh:Index(0, 1), nil, "Index 0 is nil")
eq(fresh:Index(1.5, 1), nil, "a fractional Index is nil")
for _, i in ipairs({ 1, 9, 10, 45, 81 }) do
    local x, y = fresh:XY(i)
    eq(fresh:Index(x, y), i, "XY is the inverse of Index (cell " .. i .. ")")
end
eq(fresh:XY(0), nil, "XY(0) is nil")
eq(fresh:XY(82), nil, "XY past the end is nil")
eq(fresh:XY(1.5), nil, "XY of a fraction is nil")
eq(select(2, fresh:XY(10)), 2, "cell 10 of a 9-wide board is on row 2")
eq(fresh:Cell(1).state, "covered", "cells start covered")
eq(fresh:Cell(82), nil, "Cell past the end is nil")
check(fresh:Cell(1).mine == nil and fresh:Cell(1).count == nil, "a covered cell exposes nothing")

----------------------------------------------------------------------------
-- the first reveal
----------------------------------------------------------------------------
-- Every cell of a small board, many seeds: never a loss, never a mine in the
-- clicked cell or (the default) its in-bounds neighbours, always the right
-- number of mines.
do
    local allSafe, allCounted, allZone, nSeeds = true, true, true, 25
    for first = 1, 25 do
        for seed = 1, nSeeds do
            local b = Board.New(5, 5, 10, { rng = seeded(seed) })
            local x, y = (first - 1) % 5 + 1, math.floor((first - 1) / 5) + 1
            local changed = b:Reveal(x, y, 0)
            if b:State() == "lost" or b:Cell(first).state ~= "revealed" then allSafe = false end
            if countMines(b) ~= 10 then allCounted = false end
            for dy = -1, 1 do
                for dx = -1, 1 do
                    local i = b:Index(x + dx, y + dy)
                    if i and b._mine[i] then allZone = false end
                end
            end
            check(unique(changed), "the first reveal's changes are unique")
        end
    end
    check(allSafe, "the first click never loses, on every cell and many seeds")
    check(allCounted, "a board has exactly the requested number of mines")
    check(allZone, "no mine in the first cell or its in-bounds neighbours (corners and edges too)")
end

-- XP's rule: only the clicked cell is protected. With a dense board some
-- neighbour is a mine, on at least one seed.
do
    local sawNeighbourMine = false
    for seed = 1, 30 do
        local b = Board.New(5, 5, 20, { rng = seeded(seed), safeZone = "cell" })
        b:Reveal(3, 3, 0)
        check(not b._mine[13], "safeZone=cell: the clicked cell is not a mine")
        for _, i in ipairs({ 7, 8, 9, 12, 14, 17, 18, 19 }) do
            if b._mine[i] then sawNeighbourMine = true end
        end
    end
    check(sawNeighbourMine, "safeZone=cell protects the clicked cell only")
end

-- When the mines do not fit outside the area, it falls back to the cell alone.
do
    local b = Board.New(3, 3, 5, { rng = seeded(7) })
    b:Reveal(2, 2, 0)                       -- the area is all 9 cells: 0 left for 5 mines
    check(not b._mine[5], "dense board: the centre is still safe")
    eq(countMines(b), 5, "dense board: all 5 mines placed (single-cell fallback)")

    local c = Board.New(3, 3, 5, { rng = seeded(7) })
    c:Reveal(1, 1, 0)                       -- the corner area is 4 cells: exactly 5 remain
    check(sameSet((function() local l = {} for i in pairs(c._mine) do l[#l + 1] = i end return l end)(),
        { 3, 6, 7, 8, 9 }), "when the mines just fit, the area is protected and they fill everything else")

    local d = Board.New(3, 3, 8, { rng = seeded(3) })
    local changed = d:Reveal(2, 1, 0)
    eq(d:State(), "won", "8 mines on 3x3: the first reveal wins at once")
    eq(d:FlagsLeft(), 0, "...and every mine is flagged")
    eq(#changed, 9, "...and the changes are the revealed cell plus the 8 flagged mines")
    check(unique(changed), "...uniquely")
end

-- No mines at all: the first reveal floods the board, Expert-sized, and wins.
do
    local b = Board.New(30, 16, 0)
    local changed = b:Reveal(15, 8, 0)
    eq(b:State(), "won", "Expert size, no mines: the first reveal wins")
    eq(#changed, 480, "...having flooded all 480 cells, iteratively")
    check(unique(changed), "...each once")
end

-- A real Expert board: the first reveal never touches a mine.
do
    local b = Board.New(30, 16, 99, { rng = seeded(11) })
    local changed = b:Reveal(15, 8, 5)
    check(b:State() == "playing" or b:State() == "won", "Expert: the first reveal is safe")
    if b:State() == "playing" then eq(#changed, b.revealed, "every revealed cell is in the changes") end
    check(unique(changed), "Expert: the changes are unique")
    local anyMine = false
    for _, i in ipairs(changed) do if b._mine[i] then anyMine = true end end
    check(not anyMine, "Expert: a reveal never reports a mine")
end

-- The rng contract.
do
    local calls = {}
    local b = Board.New(9, 9, 10, { rng = function(n) calls[#calls + 1] = n; return 1 end })
    b:Reveal(5, 5, 0)
    eq(#calls, 10, "the rng is called once per mine")
    eq(calls[1], 72, "...first with the eligible cell count (81 - the 3x3 area)")
    eq(calls[10], 63, "...then one fewer each time (sampling without replacement)")

    local a1 = Board.New(9, 9, 10, { rng = seeded(42) }); a1:Reveal(4, 4, 0)
    local a2 = Board.New(9, 9, 10, { rng = seeded(42) }); a2:Reveal(4, 4, 0)
    local same = true
    for i = 1, 81 do if (a1._mine[i] or false) ~= (a2._mine[i] or false) then same = false end end
    check(same, "the same rng, options and first cell give the same board")

    for _, bad in ipairs({ 0, 99999, 1.5, "1" }) do
        local x = Board.New(5, 5, 3, { rng = function() return bad end })
        local ok = pcall(x.Reveal, x, 1, 1, 0)
        check(not ok, "a bad rng result (" .. tostring(bad) .. ") is an error, not a corrupted board")
        eq(x:State(), "ready", "...and the board is untouched (state)")
        eq(countMines(x), 0, "...and untouched (no mines)")
        eq(x:Cell(1).state, "covered", "...and untouched (cell)")
    end
end

-- Flags set before the first reveal do not influence placement.
do
    local b = Board.New(5, 4, 1, { rng = function() return 1 end, safeZone = "cell" })
    b:ToggleMark(1, 1)
    eq(b:State(), "ready", "flagging does not start the game")
    b:Reveal(5, 4, 0)
    check(b._mine[1], "a mine can sit under a flag placed before the first reveal")
    eq(b:Cell(1).state, "flag", "...and the flag stays")
end

-- A flagged first click is not a first click.
do
    local b = Board.New(5, 4, 3, { rng = seeded(2) })
    b:ToggleMark(2, 2)
    eq(#b:Reveal(2, 2, 0), 0, "revealing a flag does nothing")
    eq(b:State(), "ready", "...and does not place the mines")
    eq(b:Elapsed(50), 0, "...or start the clock")
end

-- A question mark does not block a reveal.
do
    local b = Board.New(5, 4, 3, { rng = seeded(2), questionMarks = true })
    b:ToggleMark(2, 2); b:ToggleMark(2, 2)
    eq(b:Cell(b:Index(2, 2)).state, "question", "flag then flag again is a question mark")
    local changed = b:Reveal(2, 2, 0)
    check(#changed >= 1, "a question-marked cell can be revealed")
    eq(b:Cell(b:Index(2, 2)).state, "revealed", "...and is")
end

-- Actions needing the clock refuse to run without one.
check(not pcall(fresh.Reveal, fresh, 1, 1), "Reveal without a time is an error")
check(not pcall(fresh.Chord, fresh, 1, 1), "Chord without a time is an error")

----------------------------------------------------------------------------
-- flood fill
----------------------------------------------------------------------------
do
    local b = layout(WALL)
    eq(b:Cell(b:Index(1, 1)).state, "covered", "layout: covered")
    local changed = b:Reveal(1, 1, 0)
    check(sameSet(changed, cellsOf(b, { 1, 2 }, { 1, 2, 3, 4 })), "a flood from a zero reveals its region and the number border, no more")
    eq(b:State(), "playing", "...and the game goes on")
    eq(b:Cell(b:Index(1, 1)).count, 0, "the zero is a zero")
    eq(b:Cell(b:Index(2, 1)).count, 2, "a border cell counts its mines (2)")
    eq(b:Cell(b:Index(2, 2)).count, 3, "...(3)")
    eq(b:Cell(b:Index(4, 1)).state, "covered", "the far side is untouched")
    check(unique(changed), "flood changes are unique")

    local one = b:Reveal(4, 1, 0)
    eq(#one, 1, "a numbered cell reveals only itself")
    eq(b:Reveal(4, 1, 0)[1], nil, "revealing a revealed cell does nothing")
end

do   -- a flag stops the flood and stays; a question mark does not
    local b = layout(WALL)
    b:ToggleMark(1, 3)
    local changed = b:Reveal(1, 1, 0)
    eq(b:Cell(b:Index(1, 3)).state, "flag", "the flood does not reveal a flagged cell")
    check(not set(changed)[b:Index(1, 3)], "...nor report it")

    local q = layout(WALL, { questionMarks = true })
    q:ToggleMark(1, 3); q:ToggleMark(1, 3)
    eq(q:Cell(q:Index(1, 3)).state, "question", "marked with a question mark")
    q:Reveal(1, 1, 0)
    eq(q:Cell(q:Index(1, 3)).state, "revealed", "the flood reveals a question-marked cell")
end

----------------------------------------------------------------------------
-- marks
----------------------------------------------------------------------------
do
    local b = layout(WALL)
    local i = b:Index(4, 4)
    local c = b:ToggleMark(4, 4)
    check(sameSet(c, { i }), "marking reports the cell")
    eq(b:Cell(i).state, "flag", "covered > flag")
    eq(b:FlagsLeft(), 3, "...and the counter drops")
    b:ToggleMark(4, 4)
    eq(b:Cell(i).state, "covered", "flag > covered when question marks are off")
    eq(b:FlagsLeft(), 4, "...and the counter returns")

    local q = layout(WALL, { questionMarks = true })
    local j = q:Index(4, 4)
    q:ToggleMark(4, 4); q:ToggleMark(4, 4)
    eq(q:Cell(j).state, "question", "flag > question when they are on")
    eq(q:FlagsLeft(), 4, "a question mark is not a flag: the counter returns")
    q:ToggleMark(4, 4)
    eq(q:Cell(j).state, "covered", "question > covered")

    eq(#b:ToggleMark(9, 9), 0, "marking off the board does nothing")
    b:Reveal(1, 1, 0)
    eq(#b:ToggleMark(1, 1), 0, "marking a revealed cell does nothing")
    eq(b:Cell(b:Index(1, 1)).state, "revealed", "...and leaves it revealed")
end

do   -- the counter goes negative
    local b = layout(WALL)
    for y = 1, 4 do b:ToggleMark(1, y) end
    b:ToggleMark(2, 1)
    eq(b:FlagsLeft(), -1, "mines minus flags can go negative")
end

----------------------------------------------------------------------------
-- chord
----------------------------------------------------------------------------
do
    local b = layout(WALL)
    b:Reveal(2, 2, 0)                      -- a 3
    eq(#b:Chord(2, 2, 0), 0, "chord with no flags does nothing")
    b:ToggleMark(3, 1); b:ToggleMark(3, 2)
    eq(#b:Chord(2, 2, 0), 0, "chord with too few flags does nothing")
    b:ToggleMark(3, 3); b:ToggleMark(1, 1)          -- 4 flags around a 3
    eq(#b:Chord(2, 2, 0), 0, "chord with too many flags does nothing")
    b:ToggleMark(1, 1)                              -- back to 3
    local changed = b:Chord(2, 2, 0)
    local expected = {}
    for _, i in ipairs(cellsOf(b, { 1, 2 }, { 1, 2, 3, 4 })) do
        if i ~= b:Index(2, 2) then expected[#expected + 1] = i end
    end
    check(sameSet(changed, expected), "a satisfied chord reveals the other neighbours and floods: 7 new cells")
    eq(b:State(), "playing", "...and the game goes on")
    check(unique(changed), "chord changes are unique")
    eq(b:Cell(b:Index(3, 1)).state, "flag", "...flags are left alone")
end

do   -- the whole field cleared by a chord: a win
    local b = layout({ "*..", "...", "..*" })
    b:Reveal(2, 2, 0)                      -- a 2
    b:ToggleMark(1, 1); b:ToggleMark(3, 3)
    local changed = b:Chord(2, 2, 0)
    eq(b:State(), "won", "a chord that clears the field wins")
    eq(#changed, 6, "...6 cells revealed (both mines were already flagged)")
end

do   -- a wrong flag: the chord reveals a mine and loses
    local b = layout(WALL)
    b:Reveal(2, 2, 0)
    b:ToggleMark(3, 1); b:ToggleMark(3, 2); b:ToggleMark(1, 3)    -- (1,3) is NOT a mine; (3,3) is
    local changed = b:Chord(2, 2, 3)
    eq(b:State(), "lost", "chord with a wrong flag loses")
    eq(b:Cell(b:Index(3, 3)).exploded, true, "...on the unflagged mine")
    eq(b:Cell(b:Index(1, 3)).wrongFlag, true, "...and the wrong flag is marked")
    check(set(changed)[b:Index(3, 3)] and set(changed)[b:Index(1, 3)] and set(changed)[b:Index(3, 4)],
        "...and the changes include the mine, the wrong flag and the other mines")
    check(unique(changed), "...uniquely")
end

do   -- the places a chord does nothing
    local b = layout(WALL, { questionMarks = true })
    eq(#b:Chord(2, 2, 0), 0, "chord on a covered cell does nothing")
    b:ToggleMark(2, 2)
    eq(#b:Chord(2, 2, 0), 0, "chord on a flag does nothing")
    b:ToggleMark(2, 2)
    eq(#b:Chord(2, 2, 0), 0, "chord on a question mark does nothing")
    b:ToggleMark(2, 2)
    b:Reveal(1, 1, 0)
    eq(#b:Chord(1, 1, 0), 0, "chord on a zero does nothing")
    eq(#b:Chord(9, 9, 0), 0, "chord off the board does nothing")
    local r = Board.New(5, 5, 3)
    eq(#r:Chord(1, 1, 0), 0, "chord before the first reveal does nothing")
end

----------------------------------------------------------------------------
-- winning and losing
----------------------------------------------------------------------------
do
    local b = layout(WALL)
    b:Reveal(1, 1, 0)
    local changed = b:Reveal(5, 1, 4)      -- a zero on the far side: floods the rest
    eq(b:State(), "won", "revealing every safe cell wins")
    eq(b:FlagsLeft(), 0, "...and the counter reads 0")
    for y = 1, 4 do eq(b:Cell(b:Index(3, y)).state, "flag", "...mine (3," .. y .. ") is flagged") end
    eq(#changed, 12, "...the changes are the 8 flooded cells plus the 4 mines flagged")
    check(unique(changed), "...uniquely")
end

do
    local b = layout(WALL)
    b:ToggleMark(4, 4)                     -- wrong
    b:ToggleMark(3, 2)                     -- right
    local changed = b:Reveal(3, 1, 7.5)
    eq(b:State(), "lost", "revealing a mine loses")
    local c = b:Cell(b:Index(3, 1))
    check(c.state == "revealed" and c.mine and c.exploded, "...the clicked mine is revealed and exploded")
    local o = b:Cell(b:Index(3, 3))
    check(o.state == "revealed" and o.mine and not o.exploded, "...the other mines are revealed")
    eq(b:Cell(b:Index(3, 2)).state, "flag", "...a correct flag stays a flag")
    eq(b:Cell(b:Index(3, 2)).wrongFlag, nil, "...and is not wrong")
    eq(b:Cell(b:Index(4, 4)).wrongFlag, true, "...a wrong flag is marked wrong")
    check(sameSet(changed, { b:Index(3, 1), b:Index(3, 3), b:Index(3, 4), b:Index(4, 4) }),
        "...the changes are exactly the mines shown and the wrong flag (not the correct flag)")
    eq(b:Cell(b:Index(1, 1)).state, "covered", "...safe covered cells stay covered")
end

do   -- once over, nothing moves
    local b = layout(WALL)
    b:Reveal(3, 1, 0)
    eq(#b:Reveal(1, 1, 0), 0, "no reveal after a loss")
    eq(#b:ToggleMark(1, 1), 0, "no mark after a loss")
    eq(#b:Chord(1, 1, 0), 0, "no chord after a loss")
    eq(b:State(), "lost", "...the state holds")

    local w = layout(WALL)
    w:Reveal(1, 1, 0); w:Reveal(5, 1, 0)
    eq(#w:Reveal(4, 2, 0), 0, "no reveal after a win")
    eq(#w:ToggleMark(4, 2), 0, "no mark after a win")
    eq(w:State(), "won", "...the state holds")
end

----------------------------------------------------------------------------
-- the clock
----------------------------------------------------------------------------
do
    local b = Board.New(9, 9, 10, { rng = seeded(5) })
    eq(b:Elapsed(100), 0, "before the first reveal: 0")
    b:ToggleMark(1, 1)
    eq(b:Elapsed(100), 0, "a mark does not start the clock")
    b:Pause(5); b:Resume(6)
    eq(b:Elapsed(100), 0, "pause and resume before the game do nothing")
    b:Reveal(5, 5, 10)
    eq(b:State(), "playing", "(the clock tests need a game still in progress)")
    eq(b:Elapsed(15), 5, "the clock starts on the first reveal")
    b:Pause(15)
    eq(b:Elapsed(30), 5, "a paused clock stands still")
    b:Pause(20)
    eq(b:Elapsed(30), 5, "pausing twice changes nothing")
    b:Resume(40)
    eq(b:Elapsed(42), 7, "resume continues from where it stopped")
    b:Resume(43)
    eq(b:Elapsed(45), 10, "resume when running changes nothing")
    eq(b:Elapsed(1), 5, "a clock that reads earlier than the segment start never goes backwards")
end

do
    local b = layout(WALL, { now = 0 })
    b:Reveal(3, 1, 7.5)
    eq(b:Elapsed(500), 7.5, "the clock freezes at the loss, precise and uncapped")
    b:Resume(600); b:Pause(700)
    eq(b:Elapsed(900), 7.5, "...and pause and resume cannot move it")

    local w = layout(WALL, { now = 0 })
    w:Reveal(1, 1, 3); w:Reveal(5, 1, 4.25)
    eq(w:Elapsed(900), 4.25, "the clock freezes at the win")
end

eq(Board.DisplaySeconds(7.9), 7, "the display shows whole seconds")
eq(Board.DisplaySeconds(999.9), 999, "...up to 999")
eq(Board.DisplaySeconds(5000), 999, "...and caps there")
eq(Board.DisplaySeconds(0), 0, "...from 0")

done("test_board")
