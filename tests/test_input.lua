-- Input.lua: mouse gestures to actions. Pure, loaded with every WoW global
-- forbidden. The live-client matrix (which events Forever actually sends) is
-- measured in game with /gsweep input; this is what the machine does with them.
dofile("tests/harness.lua")

local env = newPureEnv()
local Input = loadPure(env, "Input.lua").Input
check(Input ~= nil, "Input.lua defines Gnomesweeper.Input without touching any other global")

local L, R, M = "LeftButton", "RightButton", "MiddleButton"

-- A fresh machine and a log of what it dispatched.
local function machine()
    local log = {}
    local g = Input.New({
        reveal = function(t) log[#log + 1] = "reveal:" .. t end,
        mark = function(t) log[#log + 1] = "mark:" .. t end,
        chord = function(t) log[#log + 1] = "chord:" .. t end,
    })
    return g, log
end

local function is(log, expected, msg)
    eq(table.concat(log, ","), table.concat(expected, ","), msg)
end

local function click(g, tile, button, inside)
    g:Down(tile, button)
    g:Up(tile, button, inside ~= false)
end

----------------------------------------------------------------------------
-- Single buttons
----------------------------------------------------------------------------
do
    local g, log = machine()
    click(g, 3, L)
    is(log, { "reveal:3" }, "left click reveals")
    click(g, 4, R)
    is(log, { "reveal:3", "mark:4" }, "right click marks")
    click(g, 5, M)
    is(log, { "reveal:3", "mark:4", "chord:5" }, "middle click chords")
end

do   -- an action fires on release, never on press
    local g, log = machine()
    g:Down(3, L)
    is(log, {}, "nothing happens on the press")
    g:Up(3, L, true)
    is(log, { "reveal:3" }, "...it happens on the release")
    g:Up(3, L, true)
    is(log, { "reveal:3" }, "...once: a second release does nothing")
end

do   -- dragging off cancels
    local g, log = machine()
    g:Down(3, L)
    g:Up(3, L, false)
    is(log, {}, "released with the cursor off the tile: nothing")
    g:Down(3, R); g:Up(3, R, false)
    g:Down(3, M); g:Up(3, M, false)
    is(log, {}, "...for right and middle too")

    -- If the client delivers the release to the tile under the cursor rather
    -- than to the one pressed, that is another tile: nothing.
    g:Down(3, L)
    g:Up(4, L, true)
    is(log, {}, "released over a different tile: nothing")
    click(g, 3, L)
    is(log, { "reveal:3" }, "...and the next click is unaffected")
end

do   -- a release we never saw the press of
    local g, log = machine()
    g:Up(3, L, true)
    g:Up(3, R, true)
    is(log, {}, "a release with no press is ignored")
end

do   -- other buttons are ignored
    local g, log = machine()
    g:Down(3, "Button4")
    g:Up(3, "Button4", true)
    g:Down(3, nil)
    is(log, {}, "an unknown button does nothing")
end

do   -- a lost release (a press with no release) is replaced by the next press
    local g, log = machine()
    g:Down(3, L)
    g:Down(4, L)
    g:Up(4, L, true)
    is(log, { "reveal:4" }, "a second press replaces a lost one")
end

----------------------------------------------------------------------------
-- Chords
----------------------------------------------------------------------------
do   -- left then right
    local g, log = machine()
    g:Down(3, L); g:Down(3, R)
    is(log, {}, "pressing both does nothing yet")
    g:Up(3, L, true)
    is(log, { "chord:3" }, "the chord fires on the first release")
    g:Up(3, R, true)
    is(log, { "chord:3" }, "...and the second release does neither reveal, mark nor chord again")
end

do   -- right then left
    local g, log = machine()
    g:Down(3, R); g:Down(3, L)
    g:Up(3, R, true)
    g:Up(3, L, true)
    is(log, { "chord:3" }, "right then left: one chord")
end

do   -- either release order
    local g, log = machine()
    g:Down(3, L); g:Down(3, R)
    g:Up(3, R, true)
    g:Up(3, L, true)
    is(log, { "chord:3" }, "released right first: one chord, and no reveal")
end

do   -- the next click after a chord is a plain one
    local g, log = machine()
    g:Down(3, L); g:Down(3, R); g:Up(3, L, true); g:Up(3, R, true)
    click(g, 4, L)
    click(g, 5, R)
    is(log, { "chord:3", "reveal:4", "mark:5" }, "after a chord, clicks work as normal")
end

do   -- a chord released off the tile is cancelled, and still consumes both releases
    local g, log = machine()
    g:Down(3, L); g:Down(3, R)
    g:Up(3, L, false)
    g:Up(3, R, true)
    is(log, {}, "the first release off the tile cancels the chord, and the second does nothing")
end

do   -- the first release decides
    local g, log = machine()
    g:Down(3, L); g:Down(3, R)
    g:Up(3, L, true)
    g:Up(3, R, false)
    is(log, { "chord:3" }, "a later release off the tile changes nothing")
end

do   -- pressed on two tiles: nobody can complete it
    local g, log = machine()
    g:Down(3, L); g:Down(4, R)
    g:Up(3, L, true)
    g:Up(4, R, true)
    is(log, {}, "left on one tile, right on another: no chord, no reveal, no mark")
end

do   -- pressing one of the pair again latches a new chord
    local g, log = machine()
    g:Down(3, L); g:Down(3, R)
    g:Up(3, L, true)                 -- chord 1, with right still held
    g:Down(3, L)
    g:Up(3, L, true)                 -- chord 2
    g:Up(3, R, true)
    is(log, { "chord:3", "chord:3" }, "re-pressing one button while the other is held chords again")
end

do   -- a left click and then a right click are two clicks, not a chord
    local g, log = machine()
    click(g, 3, L)
    click(g, 3, R)
    is(log, { "reveal:3", "mark:3" }, "sequential clicks are not a chord")
end

do   -- middle during a held left: no crash, and the middle still chords
    local g, log = machine()
    g:Down(3, L); g:Down(3, M); g:Up(3, M, true)
    is(log, { "chord:3" }, "middle is independent of the left button")
end

----------------------------------------------------------------------------
-- Cancel
----------------------------------------------------------------------------
do
    local g, log = machine()
    g:Down(3, L)
    g:Cancel()
    g:Up(3, L, true)
    is(log, {}, "a gesture cancelled mid-press does nothing on release")

    g:Down(3, L); g:Down(3, R)
    g:Cancel()
    g:Up(3, L, true); g:Up(3, R, true)
    is(log, {}, "...nor does a chord")

    click(g, 3, L)
    is(log, { "reveal:3" }, "...and the machine works again afterwards")
end

done("test_input")
