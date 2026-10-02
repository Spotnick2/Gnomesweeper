-- Board.lua: the game itself. PURE Lua: no frames, no events, no client API,
-- no clock of its own (the caller passes the time in). Everything else is a
-- view on this. tests/test_board.lua loads it with every global but a
-- handful of Lua builtins forbidden, so that stays true.
--
-- The rules are CLAUDE.md "Game rules"; this file implements them.
--
--   local b = Gnomesweeper.Board.New(w, h, mines, opts)   -- or nil, "why not"
--   opts.rng            function(n) -> integer 1..n   (default math.random)
--   opts.safeZone       "area" (default: the first cell and its in-bounds
--                       neighbours) or "cell" (XP: the first cell only)
--   opts.questionMarks  true: right-click cycles covered > flag > ? > covered
--
--   b:Reveal(x, y, now)   b:Chord(x, y, now)   b:ToggleMark(x, y)
--   Each returns the cells it changed: a table of UNIQUE row-major indices
--   (i = (y - 1) * w + x), {} for a no-op. That is everything the view must
--   repaint, including the mines a loss shows and the flags a win plants.
--
--   b:Cell(i)       -> { state, count, mine, exploded, wrongFlag } or nil
--   b:Index(x, y)   -> i or nil (out of bounds)
--   b:State()       -> "ready" | "playing" | "won" | "lost"
--   b:FlagsLeft()   -> mines - flags (may be negative)
--   b:Elapsed(now)  -> ACTIVE seconds, precise and uncapped
--   b:Pause(now) / b:Resume(now)      the window is hidden / shown again
--   Board.DisplaySeconds(t)           what the HUD shows: whole, capped at 999
--
-- Cell state is "covered", "flag", "question" or "revealed". `count` (0..8) is
-- set on a revealed safe cell, `mine` on a revealed mine (a loss shows them),
-- `exploded` on the mine that ended the game, `wrongFlag` on a flag that was
-- not on a mine once the game is lost. Mines are never exposed while hidden.

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local Board = {}
Board.__index = Board
Gnomesweeper.Board = Board

local COVERED, FLAG, QUESTION, REVEALED = "covered", "flag", "question", "revealed"

Board.PRESETS = {
    beginner     = { w = 9,  h = 9,  mines = 10 },
    intermediate = { w = 16, h = 16, mines = 40 },
    expert       = { w = 30, h = 16, mines = 99 },
}
Board.PRESET_ORDER = { "beginner", "intermediate", "expert" }

local DISPLAY_CAP = 999

local function isInt(n)
    return type(n) == "number" and n == math.floor(n) and n > -math.huge and n < math.huge
end

local function needTime(now, what)
    if type(now) ~= "number" then error("Board:" .. what .. " needs the current time", 3) end
end

function Board.New(w, h, mines, opts)
    if not (isInt(w) and isInt(h) and w >= 1 and h >= 1) then
        return nil, "width and height must be whole numbers of at least 1"
    end
    if not (isInt(mines) and mines >= 0 and mines < w * h) then
        return nil, "mines must be a whole number from 0 to one less than the cell count"
    end
    opts = opts or {}
    local b = setmetatable({
        w = w, h = h, mines = mines, total = w * h,
        rng = opts.rng or math.random,
        safeZone = (opts.safeZone == "cell") and "cell" or "area",
        questionMarks = opts.questionMarks and true or false,
        status = "ready",
        flags = 0,
        revealed = 0,            -- SAFE cells revealed; mines shown by a loss don't count
        exploded = nil,
        accum = 0, since = nil, paused = false,
        _state = {}, _mine = {}, _count = {}, _wrong = {},
    }, Board)
    for i = 1, b.total do b._state[i] = COVERED end
    return b
end

function Board:Index(x, y)
    if not (isInt(x) and isInt(y)) or x < 1 or y < 1 or x > self.w or y > self.h then return nil end
    return (y - 1) * self.w + x
end

-- Fills `out` with the in-bounds neighbours of i and returns how many.
local function neighbours(b, i, out)
    local w, h = b.w, b.h
    local x = (i - 1) % w + 1
    local y = math.floor((i - 1) / w) + 1
    local n = 0
    for dy = -1, 1 do
        local yy = y + dy
        if yy >= 1 and yy <= h then
            for dx = -1, 1 do
                local xx = x + dx
                if (dx ~= 0 or dy ~= 0) and xx >= 1 and xx <= w then
                    n = n + 1
                    out[n] = (yy - 1) * w + xx
                end
            end
        end
    end
    return n
end

local function computeCounts(b)
    local nb = {}
    for i = 1, b.total do
        if not b._mine[i] then
            local c = 0
            for k = 1, neighbours(b, i, nb) do
                if b._mine[nb[k]] then c = c + 1 end
            end
            b._count[i] = c
        end
    end
end

-- Places the mines for the first reveal at `first`. Samples WITHOUT replacement
-- (a partial Fisher-Yates over the eligible cells), so a dense board needs no
-- retry loop. Flags the player set beforehand do not matter: placement ignores
-- them. Builds into locals first, so a bad rng leaves the board untouched.
local function place(b, first)
    local skip = { [first] = true }
    if b.safeZone == "area" then
        local nb = {}
        local n = neighbours(b, first, nb)
        -- The area only if the mines still fit outside it; else the cell alone.
        if b.total - (n + 1) >= b.mines then
            for k = 1, n do skip[nb[k]] = true end
        end
    end
    local pool, np = {}, 0
    for i = 1, b.total do
        if not skip[i] then np = np + 1; pool[np] = i end
    end
    local mine = {}
    for k = 1, b.mines do
        local left = np - k + 1
        local r = b.rng(left)
        if not isInt(r) or r < 1 or r > left then
            error("Board: rng(" .. left .. ") returned " .. tostring(r) .. ", expected a whole number from 1 to " .. left, 3)
        end
        local j = k + r - 1
        pool[k], pool[j] = pool[j], pool[k]
        mine[pool[k]] = true
    end
    b._mine = mine
    computeCounts(b)
end

-- The clock counts active time only: it runs from the first successful reveal,
-- stops while paused, and freezes when the game ends.
local function startTimer(b, now) b.since = now; b.paused = false end

local function stopTimer(b, now)
    if b.since then b.accum = b.accum + math.max(0, now - b.since); b.since = nil end
end

function Board:Pause(now)
    if self.status == "playing" and self.since then
        stopTimer(self, now)
        self.paused = true
    end
end

function Board:Resume(now)
    if self.status == "playing" and self.paused then
        self.since = now
        self.paused = false
    end
end

function Board:Elapsed(now)
    local t = self.accum
    if self.since then t = t + math.max(0, now - self.since) end
    return t
end

function Board.DisplaySeconds(t)
    return math.min(DISPLAY_CAP, math.floor(t))
end

-- A fresh changed-cells list and the function that adds to it without repeats.
local function changes()
    local list, seen = {}, {}
    return list, function(i)
        if not seen[i] then seen[i] = true; list[#list + 1] = i end
    end
end

-- Reveals the covered (or question-marked) safe cell `start`, and floods out
-- from zeros. An iterative queue: Expert has 381 safe cells, and recursion has
-- no business here. Flags stop the flood; a question mark does not.
local function flood(b, start, add)
    local state, count = b._state, b._count
    local queue, head, tail = { start }, 1, 1
    local nb = {}
    state[start] = REVEALED
    b.revealed = b.revealed + 1
    add(start)
    while head <= tail do
        local i = queue[head]
        head = head + 1
        if count[i] == 0 then
            for k = 1, neighbours(b, i, nb) do
                local j = nb[k]
                local s = state[j]
                if s == COVERED or s == QUESTION then
                    state[j] = REVEALED
                    b.revealed = b.revealed + 1
                    add(j)
                    tail = tail + 1
                    queue[tail] = j
                end
            end
        end
    end
end

local function lose(b, now, exploded, add)
    b.status = "lost"
    b.exploded = exploded
    stopTimer(b, now)
    for i = 1, b.total do
        local s = b._state[i]
        if b._mine[i] then
            if s == COVERED or s == QUESTION then
                b._state[i] = REVEALED
                add(i)
            end
        elseif s == FLAG then
            b._wrong[i] = true
            add(i)
        end
    end
end

local function win(b, now, add)
    b.status = "won"
    stopTimer(b, now)
    for i = 1, b.total do
        if b._mine[i] and b._state[i] ~= FLAG then
            b._state[i] = FLAG
            b.flags = b.flags + 1
            add(i)
        end
    end
end

local function cleared(b) return b.revealed == b.total - b.mines end

function Board:Reveal(x, y, now)
    needTime(now, "Reveal")
    local list, add = changes()
    local i = self:Index(x, y)
    if not i or self.status == "won" or self.status == "lost" then return list end
    local s = self._state[i]
    if s ~= COVERED and s ~= QUESTION then return list end   -- a flag blocks, a revealed cell is done
    if self.status == "ready" then
        place(self, i)
        self.status = "playing"
        startTimer(self, now)
    end
    if self._mine[i] then
        lose(self, now, i, add)
    else
        flood(self, i, add)
        if cleared(self) then win(self, now, add) end
    end
    return list
end

-- Chord: a revealed number whose adjacent flags match it reveals every other
-- neighbour. Anything else does nothing. A wrong flag means a mine is among
-- those neighbours, and the game is lost.
function Board:Chord(x, y, now)
    needTime(now, "Chord")
    local list, add = changes()
    local i = self:Index(x, y)
    if not i or self.status ~= "playing" or self._state[i] ~= REVEALED then return list end
    local want = self._count[i]
    if not want or want == 0 then return list end
    local nb, targets, flagged = {}, {}, 0
    for k = 1, neighbours(self, i, nb) do
        local j = nb[k]
        local s = self._state[j]
        if s == FLAG then
            flagged = flagged + 1
        elseif s == COVERED or s == QUESTION then
            targets[#targets + 1] = j
        end
    end
    if flagged ~= want or #targets == 0 then return list end
    local hit
    for _, j in ipairs(targets) do
        local s = self._state[j]
        -- An earlier target's flood may already have revealed this one.
        if s == COVERED or s == QUESTION then
            if self._mine[j] then hit = hit or j else flood(self, j, add) end
        end
    end
    if hit then
        lose(self, now, hit, add)
    elseif cleared(self) then
        win(self, now, add)
    end
    return list
end

-- covered > flag > (question) > covered. Allowed before the first reveal, so a
-- player can flag first; not on a revealed cell, and not once the game is over.
function Board:ToggleMark(x, y)
    local list, add = changes()
    local i = self:Index(x, y)
    if not i or self.status == "won" or self.status == "lost" then return list end
    local s = self._state[i]
    if s == COVERED then
        self._state[i] = FLAG
        self.flags = self.flags + 1
    elseif s == FLAG then
        self.flags = self.flags - 1
        self._state[i] = self.questionMarks and QUESTION or COVERED
    elseif s == QUESTION then
        self._state[i] = COVERED
    else
        return list
    end
    add(i)
    return list
end

function Board:State() return self.status end

function Board:FlagsLeft() return self.mines - self.flags end

function Board:Cell(i)
    local s = self._state[i]
    if not s then return nil end
    local c = { state = s }
    if s == REVEALED then
        if self._mine[i] then c.mine = true else c.count = self._count[i] end
    end
    if self.exploded == i then c.exploded = true end
    if self._wrong[i] then c.wrongFlag = true end
    return c
end

-- Test seam (never used in game): a board whose mines are given as rows of
-- text ("*" a mine, anything else not), already past its first reveal, with
-- the clock started at opts.now (default 0). Lets a test build the exact
-- shapes it asserts on instead of hunting for a seed that produces them.
Board._test = {
    FromLayout = function(rows, opts)
        local h, w = #rows, #rows[1]
        local mines = 0
        for _, row in ipairs(rows) do
            for x = 1, w do if row:sub(x, x) == "*" then mines = mines + 1 end end
        end
        local b = assert(Board.New(w, h, mines, opts))
        for y, row in ipairs(rows) do
            for x = 1, w do
                if row:sub(x, x) == "*" then b._mine[(y - 1) * w + x] = true end
            end
        end
        computeCounts(b)
        b.status = "playing"
        startTimer(b, opts and opts.now or 0)
        return b
    end,
}
