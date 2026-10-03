-- The new-game wave (#43): the tiles re-cover in a diagonal wave from the
-- top-left when the player starts a new game, three seconds in all (the length
-- of the arm's sound, which starts on the same click).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local function fresh()
    loadAddon()
    math.randomseed(7)
    WoW.slash("/gsweep")
    return Gnomesweeper.Window, Gnomesweeper.Grid
end
local function tile(i) return Gnomesweeper.Grid._test.tiles[i] end
local function dy(i)                                     -- how far the tile sits above its place
    local t = tile(i)
    local p = t._points[#t._points]
    return p[5] - t.y0
end
local function run(seconds)                              -- render frames for `seconds`
    for _ = 1, math.floor(seconds / 0.02 + 0.5) do WoW.tick(0.02) end
end

do
    local W, G = fresh()
    local ui = W._test.ui
    local last = W.game.total                            -- the bottom-right tile, the last to land
    ui.face._scripts.OnClick(ui.face)
    check(G.Shuffling(), "the face starts the wave")
    eq(tile(1):GetAlpha(), 0, "...every tile starts unseen")
    eq(tile(last):GetAlpha(), 0, "...the last one too")
    eq(dy(1), G.SHUFFLE_DROP, "...lifted, to drop into place")
    eq(tile(1).hl:GetAlpha(), 0, "...and no hover glow while tiles fly in")

    run(1.4)
    eq(tile(1):GetAlpha(), 1, "1.4 s in: the top-left tile has landed")
    eq(dy(1), 0, "...in its place")
    eq(tile(last):GetAlpha(), 0, "...the bottom-right hasn't started")
    local mid = 5 + 4 * 9                                -- the centre of Beginner's 9x9
    check(tile(mid):GetAlpha() > 0 and tile(mid):GetAlpha() < 1, "...the middle is on its way")
    check(G.Shuffling(), "...still running")

    run(1.7)
    check(not G.Shuffling(), "three seconds in all: done")
    local unlanded = 0
    for i = 1, W.game.total do
        if tile(i):GetAlpha() ~= 1 or dy(i) ~= 0 then unlanded = unlanded + 1 end
    end
    eq(unlanded, 0, "every tile has landed, in its place")
    eq(tile(1).hl:GetAlpha(), 1, "...the hover glow is back")
    eq(G._test.driver()._scripts.OnUpdate, nil, "...and nothing runs any more")
    eq(G.SHUFFLE_SPREAD + G.SHUFFLE_FALL, 3, "the whole wave is three seconds, as long as the arm's sound")
end

do  -- a click during the wave finishes it, and isn't a reveal
    local W, G = fresh()
    local ui = W._test.ui
    ui.face._scripts.OnClick(ui.face)
    run(0.2)
    local t = tile(41)
    t._scripts.OnMouseDown(t, "LeftButton"); t._scripts.OnMouseUp(t, "LeftButton", true)
    check(not G.Shuffling(), "a click finishes the wave")
    eq(tile(W.game.total):GetAlpha(), 1, "...every tile is in place")
    eq(W.game:State(), "ready", "...and the click revealed nothing")
    t._scripts.OnMouseDown(t, "LeftButton"); t._scripts.OnMouseUp(t, "LeftButton", true)
    eq(W.game:State(), "playing", "the next click plays")
end

do  -- closing the window mid-wave: the board is whole when it comes back
    local W, G = fresh()
    W._test.ui.face._scripts.OnClick(W._test.ui.face)
    run(0.2)
    W.win:Hide()
    check(not G.Shuffling(), "closing the window finishes the wave")
    W.win:Show()
    eq(tile(W.game.total):GetAlpha(), 1, "...the reopened board is whole")
end

do  -- only the player's new game: a difficulty change is quiet
    local W, G = fresh()
    W.NewGame("expert")
    check(not G.Shuffling(), "a difficulty change: no wave")
    eq(tile(480):GetAlpha(), 1, "...Expert's 480 tiles all there")
    W._test.ui.face._scripts.OnClick(W._test.ui.face)
    check(G.Shuffling(), "the face on Expert: the wave")
    run(3.1)
    check(not G.Shuffling(), "...done in the same three seconds")
    eq(tile(480):GetAlpha(), 1, "...all 480 landed")
    -- A new game mid-wave starts from a whole board.
    W._test.ui.face._scripts.OnClick(W._test.ui.face)
    run(0.1)
    W.NewGame("beginner")
    check(not G.Shuffling(), "a new board mid-wave ends the old wave")
    eq(tile(1):GetAlpha(), 1, "...whole")
end

do  -- Play again / Try again play it too
    local W, G = fresh()
    W._test.SetGame(Gnomesweeper.Board._test.FromLayout({ "..*..", "..*.." }))
    local t = tile(3)
    t._scripts.OnMouseDown(t, "LeftButton"); t._scripts.OnMouseUp(t, "LeftButton", true)
    eq(W.game:State(), "lost", "(a wipe)")
    local o = W._test.ui.overlay
    o.button._scripts.OnClick(o.button)
    check(G.Shuffling(), "Try again: the wave")
end

do  -- a left+right begun in the wave plants nothing (review of #44)
    local W, G = fresh()
    W._test.ui.face._scripts.OnClick(W._test.ui.face)
    run(0.2)
    local t = tile(41)
    t._scripts.OnMouseDown(t, "LeftButton")              -- ends the wave
    t._scripts.OnMouseDown(t, "RightButton")             -- the second half of the chord
    t._scripts.OnMouseUp(t, "LeftButton", true)
    t._scripts.OnMouseUp(t, "RightButton", true)
    eq(W.game:Cell(41).state, "covered", "no flag: the whole gesture was swallowed")
    t._scripts.OnMouseDown(t, "RightButton"); t._scripts.OnMouseUp(t, "RightButton", true)
    eq(W.game:Cell(41).state, "flag", "the next right-click flags")

    -- A window closed mid-gesture: the lost release doesn't eat the next press.
    t._scripts.OnMouseDown(t, "RightButton"); t._scripts.OnMouseUp(t, "RightButton", true)  -- unflag
    W._test.ui.face._scripts.OnClick(W._test.ui.face)
    run(0.2)
    t._scripts.OnMouseDown(t, "LeftButton")              -- ends the wave, then the window closes
    W.win:Hide(); W.win:Show()
    t._scripts.OnMouseDown(t, "RightButton"); t._scripts.OnMouseUp(t, "RightButton", true)
    eq(W.game:Cell(41).state, "flag", "after the window closed mid-gesture, the next press counts")
end

do  -- the input log says a press ended the wave
    local W, G = fresh()
    WoW.slash("/gsweep input")
    W._test.ui.face._scripts.OnClick(W._test.ui.face)
    local t = tile(41)
    t._scripts.OnMouseDown(t, "LeftButton"); t._scripts.OnMouseUp(t, "LeftButton", true)
    local log = table.concat(GnomesweeperDB.inputLog, "\n")
    check(log:find("tile 41  LeftButton ended the new-game wave (not a click)", 1, true) ~= nil,
        "/gsweep input logs the press that ended the wave")
    WoW.slash("/gsweep input")
end

do  -- a frame touches only the tiles in flight, not the whole board
    local W, G = fresh()
    W.NewGame("expert")
    W._test.ui.face._scripts.OnClick(W._test.ui.face)
    run(1.0)                                           -- a band of tiles is in flight
    local calls = 0
    for i = 1, W.game.total do
        local t = tile(i)
        t.SetAlpha = function(self, a) calls = calls + 1; self._alpha = a end
    end
    WoW.tick(0.02)
    check(calls > 0, "a frame mid-wave moves some tiles (" .. calls .. ")")
    check(calls < W.game.total / 2, "...but not the whole board: only the band in flight (" .. calls .. " of 480)")
    for i = 1, W.game.total do tile(i).SetAlpha = nil end
end

done("test_shuffle")
