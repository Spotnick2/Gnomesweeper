-- Grid.lua: the board view. A pool of tile Buttons drawn from a Board, and the
-- mouse handling that turns clicks into actions (Input.lua decides which).
--
--   Grid.Attach(parent, action)   once: `parent` is Window.grid; action(kind, i)
--                                 is called with "reveal" / "mark" / "chord"
--   Grid.Rebuild(board)           a new game: place and paint every tile
--   Grid.Refresh(list)            repaint exactly the cells an action changed
--   Grid.SetInteractive(on)       off once the game is over (no hover glow)
--   Grid.Cancel()                 forget a click in flight (hide, reset)
--   Grid.Shuffle()                the new-game wave (#43); Grid.FinishShuffle() ends it
--
-- Tiles are POOLED: created once, up to the largest board seen (Expert is 480),
-- then reused and hidden across games and difficulty changes. Never per game.
--
-- A tile is a Button with only two regions up front: a background (one of three
-- shared baked textures: covered, revealed, exploded) and a hover glow. The
-- flag/bomb icon and the number are created the first time a tile needs them.
-- No Glass.Apply per tile: it makes 6 textures, a mask and a frame per host,
-- and its sliced mask fails on small squares (docs; tools/make_tiles.py).
--
-- Mouse: OnMouseDown / OnMouseUp only, never OnClick, so each action has ONE
-- dispatch path. Both fire for every button on a plain Button.

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local GS = Gnomesweeper
local Grid = {}
GS.Grid = Grid

local Board, Layout, Glass, Skin, Input = GS.Board, GS.Layout, GS.Glass, GS.Skin, GS.Input
local TILE = Layout.TILE
local T = Skin.TEXTURES

local host, act, game, input
local tiles = {}              -- the pool: tiles[i] is cell i's button
local interactive = true
local logging = false
local paints = 0              -- tiles actually repainted (tests count this)

------------------------------------------------------------
-- Painting
------------------------------------------------------------

-- opts.size (default the tile icon), opts.crop (WoW's own icons carry a border to
-- cut off; ours are drawn without one), opts.desaturate (a wrong flag).
local function setIcon(t, texture, opts)
    opts = opts or {}
    if texture then
        if not t.icon then
            t.icon = t:CreateTexture(nil, "ARTWORK")
            t.icon:SetPoint("CENTER", t, "CENTER", 0, 0)
        end
        local size = opts.size or Skin.TILE_ICON
        t.icon:SetSize(size, size)
        t.icon:SetTexture(texture)
        if opts.crop then
            t.icon:SetTexCoord(unpack(Skin.ICON_CROP))
        else
            t.icon:SetTexCoord(0, 1, 0, 1)
        end
        t.icon:SetDesaturated(opts.desaturate and true or false)
        t.icon:Show()
    elseif t.icon then
        t.icon:Hide()
    end
end

local function setText(t, text, color)
    if text then
        if not t.text then
            t.text = Glass.Font(t, Skin.TILE_FONT, "CENTER")
            t.text:SetPoint("CENTER", t, "CENTER", 0, 0)
        end
        t.text:SetTextColor(color[1], color[2], color[3])
        t.text:SetText(text)
        t.text:Show()
    elseif t.text then
        t.text:Hide()
    end
end

local function hoverAlpha(t)
    t.hl:SetAlpha((interactive and t.covered) and 1 or 0)
end

-- Draws cell i. Skips a tile that already looks right, so a repaint of the whole
-- board only touches what differs.
local function paint(i)
    local t = tiles[i]
    local c = game:Cell(i)
    local key = table.concat({ c.state, c.count or "", c.mine and "m" or "", c.exploded and "e" or "", c.wrongFlag and "w" or "" }, ":")
    if t.key == key then return end
    t.key = key
    paints = paints + 1
    if c.state == "revealed" then
        t.covered = false
        t.bg:SetTexture(c.exploded and T.tileExploded or T.tileRevealed)
        -- The mine that went off is its own drawing (bursting), a SHAPE as well as the red
        -- tile, so it isn't told apart by colour alone.
        setIcon(t, c.mine and (c.exploded and T.mineExploded or T.mine) or nil)
        local n = c.count
        if n and n > 0 then setText(t, tostring(n), Skin.NUMBER_COLORS[n]) else setText(t, nil) end
    else
        t.covered = true
        t.bg:SetTexture(T.tileCovered)
        if c.state == "flag" then
            -- A wrong flag: the banner greyed and a red X over it. (A red X on the
            -- red banner was invisible: seen in game.)
            setIcon(t, T.flag, { size = Skin.FLAG_ICON, desaturate = c.wrongFlag })
            if c.wrongFlag then setText(t, "X", Skin.COLORS.wrongFlag) else setText(t, nil) end
        elseif c.state == "question" then
            setIcon(t, nil)
            setText(t, "?", Skin.COLORS.question)
        else
            setIcon(t, nil)
            setText(t, nil)
        end
    end
    hoverAlpha(t)
end

function Grid.Refresh(list)
    for _, i in ipairs(list) do paint(i) end
end

function Grid.SetInteractive(on)
    interactive = on and true or false
    for i = 1, game and game.total or 0 do hoverAlpha(tiles[i]) end
end

------------------------------------------------------------
-- Mouse
------------------------------------------------------------

-- Printed to chat AND kept in GnomesweeperDB.inputLog (the last MAX_LOG lines), so
-- a /reload writes them to the SavedVariables file and they can be read without
-- copying them out of the chat window. Debug data: it exists only after
-- /gsweep input has been used.
local MAX_LOG = 300

local function log(fmt, ...)
    if not logging then return end
    local line = string.format(fmt, ...)
    print("|cff7fd4ffGnome|rsweeper input: " .. line)
    local db = GnomesweeperDB
    if type(db) == "table" then
        local lines = db.inputLog
        if type(lines) ~= "table" then lines = {}; db.inputLog = lines end
        lines[#lines + 1] = string.format("%.3f  %s", GetTime(), line)
        if #lines > MAX_LOG then table.remove(lines, 1) end
    end
end

-- Turning it on starts a fresh log.
-- For Window.Dispatch: it records what an action did, beside the raw events.
function Grid.Log(fmt, ...) log(fmt, ...) end

function Grid.SetLogging(on)
    on = on and true or false
    if on and not logging and type(GnomesweeperDB) == "table" then GnomesweeperDB.inputLog = {} end
    logging = on
end
function Grid.Logging() return logging end

local shuffling              -- seconds into the new-game wave, or nil
local swallowed = {}         -- buttons held since a press that ended the wave
local held = {}              -- buttons down on a tile right now (the face looks surprised, #10)
local onPress                -- Grid.Attach's third argument: onPress(true) on the first, false on the last

local function release(button)
    if held[button] then
        held[button] = nil
        if not next(held) and onPress then onPress(false) end
    end
end

local function onDown(self, button)
    log("tile %d  down  %s", self.index, tostring(button))
    -- A press during the wave finishes it and is not a click, and neither is any
    -- other button pressed before all of them are up again: a left+right begun
    -- in the wave must not plant a flag on the new board.
    if shuffling or next(swallowed) then
        if shuffling then
            Grid.FinishShuffle()
            log("tile %d  %s ended the new-game wave (not a click)", self.index, tostring(button))
        end
        swallowed[button] = true
        return
    end
    input:Down(self.index, button)
    local first = not next(held)
    held[button] = true
    if first and onPress then onPress(true) end
end

local function onUp(self, button, upInside)
    -- The client says whether the cursor was still over the tile (the UI source
    -- passes upInside); if it doesn't, ask the frame.
    local inside = upInside
    if inside == nil then inside = self:IsMouseOver() end
    if logging then
        log("tile %d  up    %s  upInside=%s  IsMouseOver=%s", self.index, tostring(button),
            tostring(upInside), tostring(self:IsMouseOver()))
    end
    if swallowed[button] then swallowed[button] = nil; return end   -- the gesture that ended the wave
    release(button)
    input:Up(self.index, button, inside)
end

------------------------------------------------------------
-- The pool
------------------------------------------------------------

local function create(i)
    local t = CreateFrame("Button", nil, host)
    t:SetSize(TILE, TILE)
    t.index = i
    t.bg = t:CreateTexture(nil, "BACKGROUND")
    t.bg:SetAllPoints(t)
    t.hl = t:CreateTexture(nil, "HIGHLIGHT")
    t.hl:SetAllPoints(t)
    t.hl:SetTexture(T.tileHover)
    t.hl:SetBlendMode("ADD")
    t:SetScript("OnMouseDown", onDown)
    t:SetScript("OnMouseUp", onUp)
    tiles[i] = t
    return t
end

------------------------------------------------------------
-- The new-game wave (#43): the tiles re-cover in a diagonal wave from the top-
-- left, each fading in and dropping a few units into place, three seconds in
-- all, as long as the gnomish arm's sound, which starts on the same click. One
-- OnUpdate, only while it runs: no animation group per tile (Expert is 480).
-- Each tile's start is worked out once, and a tile is only touched while it
-- moves, so a frame costs the band of tiles in flight, not the whole board.
------------------------------------------------------------

Grid.SHUFFLE_SPREAD = 2.3    -- seconds from the first tile starting to the last
Grid.SHUFFLE_FALL = 0.7      -- seconds one tile takes
Grid.SHUFFLE_DROP = 8        -- units a tile drops from

local driver                 -- the frame whose OnUpdate runs the wave

local function place(t, dy) t:SetPoint("TOPLEFT", host, "TOPLEFT", t.x0, t.y0 + dy) end

-- When each tile starts, from its place on the diagonal: worked out once a wave.
local function startTimes()
    local span = math.max(1, game.w + game.h - 2)
    for i = 1, game.total do
        local t = tiles[i]
        t.waveStart = (t.x0 - t.y0) / TILE / span * Grid.SHUFFLE_SPREAD   -- x0 / TILE + row, from Rebuild's place
        t.waveE = nil
    end
end

-- Draws the wave at `elapsed` seconds; true once every tile has landed. A tile
-- whose look hasn't changed since the last frame is left alone.
local function waveAt(elapsed)
    local landed = true
    for i = 1, game.total do
        local t = tiles[i]
        local p = (elapsed - t.waveStart) / Grid.SHUFFLE_FALL
        if p < 1 then landed = false end
        p = math.max(0, math.min(1, p))
        local e = 1 - (1 - p) * (1 - p)                    -- ease out: fast, then settling
        if e ~= t.waveE then
            t.waveE = e
            t:SetAlpha(e)
            place(t, Grid.SHUFFLE_DROP * (1 - e))
        end
    end
    return landed
end

function Grid.FinishShuffle()
    if not shuffling then return end
    shuffling = nil
    driver:SetScript("OnUpdate", nil)
    for i = 1, game.total do
        tiles[i]:SetAlpha(1)
        place(tiles[i], 0)
    end
    input:Cancel()
    Grid.SetInteractive(game:State() == "ready" or game:State() == "playing")
end

function Grid.Shuffle()
    if not game then return end
    Grid.FinishShuffle()
    shuffling = 0
    Grid.SetInteractive(false)                           -- no hover glow while tiles fly in
    startTimes()
    waveAt(0)
    driver:SetScript("OnUpdate", function(_, dt)
        shuffling = shuffling + dt
        if waveAt(shuffling) then Grid.FinishShuffle() end
    end)
end

function Grid.Shuffling() return shuffling ~= nil end

-- Tile i's frame (the effects anchor to it: the smoke over the tile that went off).
function Grid.Tile(i) return tiles[i] end

function Grid.Attach(parent, action, pressed)
    host, act, onPress = parent, action, pressed
    driver = CreateFrame("Frame", nil, parent)
    input = Input.New({
        reveal = function(i) act("reveal", i) end,
        mark = function(i) act("mark", i) end,
        chord = function(i) act("chord", i) end,
    })
end

function Grid.Cancel()
    if input then input:Cancel() end
    for b in pairs(swallowed) do swallowed[b] = nil end   -- a release lost to a closing window mustn't eat the next press
    for b in pairs(held) do release(b) end
end

-- A new game: every tile placed and painted for `board`, the pool grown only if
-- this board is bigger than any before it, the rest hidden.
function Grid.Rebuild(board)
    Grid.FinishShuffle()                 -- a new board mid-wave starts from a whole one
    game = board
    input:Cancel()
    interactive = true
    local w = board.w
    for i = 1, board.total do
        local t = tiles[i] or create(i)
        t:ClearAllPoints()
        t.x0, t.y0 = ((i - 1) % w) * TILE, -math.floor((i - 1) / w) * TILE   -- its place (the wave drops it in)
        t:SetPoint("TOPLEFT", host, "TOPLEFT", t.x0, t.y0)
        t.key = nil
        paint(i)
        t:Show()
    end
    for i = board.total + 1, #tiles do tiles[i]:Hide() end
end

------------------------------------------------------------
-- Timing (/gsweep perf)
------------------------------------------------------------

local function timed(fn)
    local t0 = debugprofilestop()
    local n = fn()
    return debugprofilestop() - t0, n
end

-- Times the heavy operations on a scratch Expert board, then the caller puts
-- the real game back (Window.Benchmark does). Returns lines of text.
function Grid.Benchmark()
    local out = {}
    local ex, bg = Board.PRESETS.expert, Board.PRESETS.beginner
    local big = Board.New(ex.w, ex.h, ex.mines)
    local small = Board.New(bg.w, bg.h, bg.mines)
    local created = #tiles
    local ms, n = timed(function() Grid.Rebuild(big); return math.max(0, big.total - created) end)
    out[#out + 1] = string.format("build Expert: %.1f ms (%d new tiles)", ms, n)
    ms, n = timed(function()
        local list = big:Reveal(15, 8, GetTime())
        Grid.Refresh(list)
        return #list
    end)
    out[#out + 1] = string.format("first reveal and repaint: %.1f ms (%d cells)", ms, n)
    for i = 1, big.total do                               -- find a mine (the scratch board's own field)
        if big._mine[i] then
            local x, y = big:XY(i)
            ms, n = timed(function()
                local list = big:Reveal(x, y, GetTime())
                Grid.Refresh(list)
                return #list
            end)
            out[#out + 1] = string.format("a loss, every mine shown: %.1f ms (%d cells)", ms, n)
            break
        end
    end
    ms = timed(function()
        for _ = 1, 5 do Grid.Rebuild(small); Grid.Rebuild(big) end
    end)
    out[#out + 1] = string.format("10 difficulty switches: %.1f ms", ms)
    return out
end

Grid._test = {
    tiles = tiles,
    paints = function() return paints end,
    input = function() return input end,
    driver = function() return driver end,
}
