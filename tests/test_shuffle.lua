-- The new-game wave (#43): the tiles re-cover in a diagonal wave from the
-- top-left when the player starts a new game, about a second in all.
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
    local t41 = tile(41)
    t41._scripts.OnMouseDown(t41, "LeftButton"); t41._scripts.OnMouseUp(t41, "LeftButton", true)
    local old = W.game
    eq(old:State(), "playing", "(a game in progress)")

    -- The lead: the arm whirs, the old board waits.
    ui.face._scripts.OnClick(ui.face)
    check(G.Shuffling(), "the face starts the new-game shuffle")
    eq(W.game, old, "...the old board stays during the lead")
    eq(tile(1):GetAlpha(), 1, "...still drawn")
    eq(tile(1).hl:GetAlpha(), 0, "...without the hover glow")
    eq(ui.face._scripts.OnUpdate, nil, "(no OnUpdate on the face)")
    local seconds = ui.timer:GetText()
    WoW.now = WoW.now + 5                                -- five seconds pass on the game clock
    run(G.SHUFFLE_LEAD - 0.1)
    eq(W.game, old, "just before the lead ends: still the old board")
    eq(ui.timer:GetText(), seconds, "...its clock stopped (it doesn't count the lead)")

    -- The new board, then the wave.
    run(0.12)
    check(W.game ~= old, "after the lead: the new game")
    eq(W.game:State(), "ready", "...ready")
    check(tile(1):GetAlpha() < 1, "...its tiles starting the wave")
    eq(tile(last):GetAlpha(), 0, "...the last one unseen")
    check(dy(last) > 0, "...lifted, to drop into place")

    run(0.4)
    eq(tile(1):GetAlpha(), 1, "0.4 s into the wave: the top-left tile has landed")
    eq(dy(1), 0, "...in its place")
    eq(tile(last):GetAlpha(), 0, "...the bottom-right hasn't started")
    local mid = 5 + 4 * 9                                -- the centre of Beginner's 9x9
    check(tile(mid):GetAlpha() > 0 and tile(mid):GetAlpha() < 1, "...the middle is on its way")
    check(G.Shuffling(), "...still running")

    run(0.7)
    check(not G.Shuffling(), "a second of wave: done")
    local unlanded = 0
    for i = 1, W.game.total do
        if tile(i):GetAlpha() ~= 1 or dy(i) ~= 0 then unlanded = unlanded + 1 end
    end
    eq(unlanded, 0, "every tile has landed, in its place")
    eq(tile(1).hl:GetAlpha(), 1, "...the hover glow is back")
    eq(G._test.driver()._scripts.OnUpdate, nil, "...and nothing runs any more")
    eq(G.SHUFFLE_SPREAD + G.SHUFFLE_FALL, 1, "the wave is one second")
    eq(G.SHUFFLE_LEAD, 1, "...after a one-second lead (the owner: the sound builds first)")
end

do  -- a click during the lead skips to the new board, landed
    local W, G = fresh()
    local old = W.game
    W._test.ui.face._scripts.OnClick(W._test.ui.face)
    run(0.3)
    local t = tile(41)
    t._scripts.OnMouseDown(t, "LeftButton"); t._scripts.OnMouseUp(t, "LeftButton", true)
    check(not G.Shuffling(), "a click in the lead ends it")
    check(W.game ~= old, "...with the new game made")
    eq(W.game:State(), "ready", "...and the click revealed nothing")
    eq(tile(W.game.total):GetAlpha(), 1, "...every tile in place")
end

do  -- a difficulty picked during the lead: that IS the new game, no second one
    local W, G = fresh()
    W._test.ui.face._scripts.OnClick(W._test.ui.face)
    run(0.3)
    W.NewGame("expert")
    local expert = W.game
    check(not G.Shuffling(), "the pick ends the lead")
    run(2)
    eq(W.game, expert, "...and the face's game is dropped, not made after it")
    eq(G._test.game(), W.game, "...the grid draws the same board the game is played on")
    eq(W.game.total, 480, "...Expert")
    eq(tile(480):GetAlpha(), 1, "...whole")
end

do  -- a click during the wave finishes it, and isn't a reveal
    local W, G = fresh()
    local ui = W._test.ui
    ui.face._scripts.OnClick(ui.face)
    run(G.SHUFFLE_LEAD + 0.2)                              -- into the wave
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
    run(0.5)                                               -- in the lead
    local old = W.game
    W.win:Hide()
    check(not G.Shuffling(), "closing the window finishes the shuffle")
    check(W.game ~= old, "...the new game made")
    W.win:Show()
    eq(tile(W.game.total):GetAlpha(), 1, "...the reopened board is whole")
end

do  -- only the player's new game: a difficulty change is quiet
    local W, G = fresh()
    W.NewGame("expert")
    check(not G.Shuffling(), "a difficulty change: no wave")
    eq(tile(480):GetAlpha(), 1, "...Expert's 480 tiles all there")
    W._test.ui.face._scripts.OnClick(W._test.ui.face)
    check(G.Shuffling(), "the face on Expert: the shuffle")
    run(G.SHUFFLE_LEAD + 1.1)
    check(not G.Shuffling(), "...done in the same second")
    eq(tile(480):GetAlpha(), 1, "...all 480 landed")
    -- A new game mid-wave starts from a whole board.
    W._test.ui.face._scripts.OnClick(W._test.ui.face)
    run(G.SHUFFLE_LEAD + 0.1)                              -- into the wave
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
    check(G.Shuffling(), "Try again: the shuffle")
    check(not o:IsShown(), "...the overlay goes at once, not after the lead")
end

done("test_shuffle")
