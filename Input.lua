-- Input.lua: turns mouse presses and releases on tiles into actions. PURE: no
-- frames, no client API (tests/test_input.lua loads it with every global but a
-- few builtins forbidden), so every click order can be tested offline. Grid.lua
-- feeds it OnMouseDown / OnMouseUp and handles what it reports.
--
--   local g = Gnomesweeper.Input.New({ reveal = fn(tile), mark = fn(tile), chord = fn(tile) })
--   g:Down(tile, button)            a mouse button went down on `tile`
--   g:Up(tile, button, inside)      ...and came up; `inside` is whether the
--                                   cursor was still over the tile it came up on
--   g:Cancel()                      forget everything in flight
--
-- One dispatch path: every action fires from a RELEASE, never from a press and
-- never from both. Rules (classic Minesweeper):
--   * Left, right or middle pressed and released on the same tile: reveal,
--     mark, chord. Released anywhere else (dragged off, over another tile):
--     nothing.
--   * Left and right both down (either order): a CHORD is latched. It fires
--     once, on the first release of either button, if that release is on the
--     tile both were pressed on. Both buttons' releases are then consumed, so
--     neither also reveals or marks.
--   * Pressing one of the pair again while the other is still held latches a
--     new chord.
--   * A release we never saw the press of (a press before the window opened,
--     or before Cancel) is ignored.
--
-- `tile` is any value that compares equal for the same tile (an index).

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local Input = {}
Gnomesweeper.Input = Input

local LEFT, RIGHT, MIDDLE = "LeftButton", "RightButton", "MiddleButton"

function Input.New(handlers)
    local g = {}
    local down = {}          -- button -> the tile it was pressed on
    local consumed = {}      -- button -> true while part of a latched chord
    local latch              -- { tile = the chord's tile or nil, fired = bool }

    local function pairDown() return down[LEFT] ~= nil and down[RIGHT] ~= nil end

    function g:Down(tile, button)
        if button ~= LEFT and button ~= RIGHT and button ~= MIDDLE then return end
        down[button] = tile
        consumed[button] = nil
        if pairDown() then
            consumed[LEFT], consumed[RIGHT] = true, true
            -- Pressed on two different tiles: a chord nobody can complete.
            latch = { tile = (down[LEFT] == down[RIGHT]) and down[LEFT] or nil, fired = false }
        end
    end

    function g:Up(tile, button, inside)
        local pressed = down[button]
        if pressed == nil then return end
        down[button] = nil
        local onIt = inside and tile == pressed
        if consumed[button] then
            consumed[button] = nil
            if latch and not latch.fired then
                latch.fired = true
                if onIt and latch.tile ~= nil and latch.tile == pressed then handlers.chord(latch.tile) end
            end
            if not (down[LEFT] or down[RIGHT]) then latch = nil end
            return
        end
        if not onIt then return end
        if button == LEFT then
            handlers.reveal(pressed)
        elseif button == RIGHT then
            handlers.mark(pressed)
        else
            handlers.chord(pressed)
        end
    end

    function g:Cancel()
        down, consumed, latch = {}, {}, nil
    end

    return g
end
