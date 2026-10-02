-- Grid.lua: the board view. A pool of tile Buttons drawn from a Board, and the
-- mouse handling that turns clicks into actions (Input.lua decides which).
--
--   Grid.Attach(parent, action)   once: `parent` is Window.grid; action(kind, i)
--                                 is called with "reveal" / "mark" / "chord"
--   Grid.Rebuild(board)           a new game: place and paint every tile
--   Grid.Refresh(list)            repaint exactly the cells an action changed
--   Grid.SetInteractive(on)       off once the game is over (no hover glow)
--   Grid.Cancel()                 forget a click in flight (hide, reset)
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

local function setIcon(t, texture, desaturate)
    if texture then
        if not t.icon then
            t.icon = t:CreateTexture(nil, "ARTWORK")
            t.icon:SetSize(Skin.TILE_ICON, Skin.TILE_ICON)
            t.icon:SetPoint("CENTER", t, "CENTER", 0, 0)
            t.icon:SetTexCoord(unpack(Skin.ICON_CROP))
        end
        t.icon:SetTexture(texture)
        t.icon:SetDesaturated(desaturate and true or false)
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
        setIcon(t, c.mine and T.mine or nil)
        local n = c.count
        if n and n > 0 then setText(t, tostring(n), Skin.NUMBER_COLORS[n]) else setText(t, nil) end
    else
        t.covered = true
        t.bg:SetTexture(T.tileCovered)
        if c.state == "flag" then
            -- A wrong flag: the banner greyed and a red X over it. (A red X on the
            -- red banner was invisible: seen in game.)
            setIcon(t, T.flag, c.wrongFlag)
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

local function log(fmt, ...)
    if logging then print("|cff7fd4ffGnome|rsweeper input: " .. string.format(fmt, ...)) end
end

function Grid.SetLogging(on) logging = on and true or false end
function Grid.Logging() return logging end

local function onDown(self, button)
    log("tile %d  down  %s", self.index, tostring(button))
    input:Down(self.index, button)
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

function Grid.Attach(parent, action)
    host, act = parent, action
    input = Input.New({
        reveal = function(i) act("reveal", i) end,
        mark = function(i) act("mark", i) end,
        chord = function(i) act("chord", i) end,
    })
end

function Grid.Cancel()
    if input then input:Cancel() end
end

-- A new game: every tile placed and painted for `board`, the pool grown only if
-- this board is bigger than any before it, the rest hidden.
function Grid.Rebuild(board)
    game = board
    input:Cancel()
    interactive = true
    local w = board.w
    for i = 1, board.total do
        local t = tiles[i] or create(i)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", host, "TOPLEFT", ((i - 1) % w) * TILE, -math.floor((i - 1) / w) * TILE)
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
}
