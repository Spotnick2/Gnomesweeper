-- Scores.lua: personal bests (#7). Pure Lua, no WoW API: the caller hands in the
-- saved table and the record (name, realm, timestamp), so tests/test_scores.lua
-- loads it with every global forbidden.
--
-- The shape on disk, GnomesweeperDB.scores, is a contract once released (the
-- leaderboards, #15, build on it): add fields, never repurpose them.
--
--   scores = { version = 1, [category] = { best = record, played = n, won = n } }
--   category = difficulty .. ":" .. ruleset      e.g. "expert:area"
--     ruleset is the first click's safe zone, "area" or "cell": the two starts
--     aren't comparable, so they keep separate bests.
--   record = { time = precise active seconds (uncapped), at = completion
--              timestamp (time()), name = full name with surname, realm = realm }
--     The whole seconds shown are derived from `time`, never stored.
--
-- played counts a game once, on its first successful reveal (abandoned games
-- count); won counts once, on the win. A tie keeps the EARLIER record.
--
-- API:
--   Scores.Category(difficulty, safeZone) -> "beginner:area"
--   Scores.Open(db)              -> db.scores, created (or repaired) as needed
--   Scores.Started(scores, cat)  -> played + 1
--   Scores.Won(scores, cat, record) -> isNewBest, previousBest (record or nil)
--   Scores.Best(scores, cat)     -> record or nil
--   Scores.Stats(scores, cat)    -> played, won
--   Scores.Reset(db)             -> forgets every best and count (the settings' reset)

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local Scores = {}
Gnomesweeper.Scores = Scores

Scores.VERSION = 1

function Scores.Category(difficulty, safeZone)
    return tostring(difficulty) .. ":" .. (safeZone == "cell" and "cell" or "area")
end

-- The saved table, created on first use. A field that isn't a table (an edited
-- or damaged file) is replaced rather than crashed on.
function Scores.Open(db)
    if type(db.scores) ~= "table" then db.scores = {} end
    if db.scores.version == nil then db.scores.version = Scores.VERSION end
    return db.scores
end

local function count(v)
    return (type(v) == "number" and v >= 0) and math.floor(v) or 0
end

local function entry(scores, cat)
    local e = scores[cat]
    if type(e) ~= "table" then
        e = {}
        scores[cat] = e
    end
    e.played, e.won = count(e.played), count(e.won)
    return e
end

local function validRecord(r)
    return type(r) == "table" and type(r.time) == "number" and r.time >= 0   -- a NaN fails this too
end

function Scores.Best(scores, cat)
    local e = scores[cat]
    if type(e) == "table" and validRecord(e.best) then return e.best end
    return nil
end

function Scores.Stats(scores, cat)
    local e = scores[cat]
    if type(e) ~= "table" then return 0, 0 end
    return count(e.played), count(e.won)
end

function Scores.Started(scores, cat)
    local e = entry(scores, cat)
    e.played = e.played + 1
end

-- Records a win. Returns whether it is a new best, and the best it replaced (or
-- the one that still stands). Only a strictly faster time takes the place.
function Scores.Won(scores, cat, record)
    local e = entry(scores, cat)
    e.won = e.won + 1
    if e.won > e.played then e.played = e.won end    -- never "won 3 of 2", whatever the file says
    local previous = Scores.Best(scores, cat)
    if not validRecord(record) then return false, previous end
    if previous and record.time >= previous.time then return false, previous end
    e.best = {
        time = record.time,
        at = record.at,
        name = record.name,
        realm = record.realm,
    }
    return true, previous
end

-- Forgets every category's best, played and won: the next write starts afresh.
function Scores.Reset(db)
    db.scores = nil
end

Scores._test = { validRecord = validRecord }
