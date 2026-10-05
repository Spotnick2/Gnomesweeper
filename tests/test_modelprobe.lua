-- ModelProbe.lua: /gsweep models, the model probe (#20).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local function chatHas(text)
    for _, line in ipairs(WoW.chat) do
        if line:find(text, 1, true) then return true end
    end
    return false
end

local BOMB = { -0.5, -0.4, -0.6, 0.5, 0.4, 0.6 }       -- six numbers, as Forever answers (h 1.2)

local function setup()
    loadAddon()
    WoW.modelSetFails[6977], WoW.modelSetFails[3124] = nil, nil   -- the stub's default: the end panel's models absent
    return Gnomesweeper.ModelProbe, Gnomesweeper.ModelProbe._test
end

local function indexOf(P, key)
    for i, c in ipairs(P.CANDIDATES) do if c.key == key then return i end end
end

----------------------------------------------------------------------------
-- The box: both shapes, and nothing until the model is in
----------------------------------------------------------------------------
do
    local P = setup()
    local function actor(...)
        local r = { ... }
        return { GetActiveBoundingBox = function() return unpack(r) end }
    end
    local b = P.ReadBox(actor(-0.5, -0.4, -0.6, 0.5, 0.4, 0.6))
    check(b and math.abs(b.h - 1.2) < 1e-9 and math.abs(b.l - 1) < 1e-9 and math.abs(b.w - 0.8) < 1e-9,
        "six numbers: length, width, height")
    eq(b.shape, "numbers", "...and the shape is recorded")
    b = P.ReadBox(actor({ x = 0, y = 0, z = 0 }, { x = 2, y = 1, z = 3 }))
    check(b and b.h == 3 and b.l == 2 and b.w == 1, "Retail's two vectors read too")
    eq(b.shape, "vectors", "...and recorded as such")
    eq(P.ReadBox(actor(nil)), nil, "no box while the model streams in")
    eq(P.ReadBox(actor(0, 0, 0, 0, 0, 0)), nil, "a flat box is not a model")
    eq(P.ReadBox({ GetActiveBoundingBox = function() error("no") end }), nil, "a throwing getter is no box")
end

----------------------------------------------------------------------------
-- The sheet: every candidate, AltStable's recipe, loads and timeouts, saved
----------------------------------------------------------------------------
do
    local P, T = setup()
    WoW.modelSetFails[19139] = true                         -- Boombot: not on this client
    WoW.slash("/gsweep models")
    local sheet = T.sheet()
    check(sheet and sheet:IsShown(), "/gsweep models shows the sheet")
    eq(#T.cells, #P.CANDIDATES, "one cell per candidate")
    local bomb = T.cells[indexOf(P, "walkingBomb")]
    local scene, actor = bomb.scene, bomb.scene.actor
    eq(scene._type, "ModelScene", "each cell is a ModelScene")
    eq(actor._type, "ModelSceneActor", "...with an actor")
    eq(actor._model, 6977, "loaded by its display ID")
    check(actor._composite ~= true, "never composited with the player")
    eq(actor._particles, 0, "no particles on the sheet (AltStable: they swell the box)")
    eq(scene._camera[1], 40, "the far camera")
    check(not scene._shown, "hidden until its box arrives")
    eq(bomb.state:GetText(), "...", "waiting")

    -- The bomb streams in after 0.4 s; the rest never do.
    WoW.advance(0.25)
    WoW.modelBoxes[6977] = BOMB
    WoW.advance(0.25)
    check(scene._shown, "shown once its box arrived")
    local span = 2 * 40 * math.tan(0.15 / 2)
    check(math.abs(actor._scale - span / (1.2 * 1.3)) < 1e-9, "scaled from its box, with the margin")
    check(bomb.state:GetText():find("^0%.3s") ~= nil, "the cell says how long it took: " .. bomb.state:GetText())
    check(bomb.state:GetText():find("h 1.20", 1, true) ~= nil, "...and its height")
    WoW.advance(3)
    local far = T.cells[indexOf(P, "sheep")]
    eq(far.state:GetText(), "no box in 3s", "a model that never loads says so")
    check(chatHas("loaded a box"), "the summary once every model has answered")

    local probe = GnomesweeperDB.modelProbe
    eq(probe.build, "1.60.1.70205", "the build is recorded")
    local e = probe.candidates.walkingBomb
    eq(e.display, 6977, "the display")
    check(e.box and math.abs(e.box.h - 1.2) < 1e-9, "the box")
    check(e.seconds and math.abs(e.seconds - 0.3) < 1e-9, "the seconds it took")
    eq(e.set, true, "SetModelByCreatureDisplayID answered")
    eq(e.loaded, true, "IsLoaded is recorded")
    eq(probe.candidates.sheep.timeout, true, "a timeout is recorded")
    eq(probe.candidates.sheep.box, nil, "...with no box")
    eq(probe.candidates.boombot.set, false, "a refused display is recorded as refused")

    -- The player, both ways.
    local you = T.cells[indexOf(P, "player")]
    eq(you.scene.actor._model, "unit:player", "the actor's SetModelByUnit(\"player\")")
    local dress = T.cells[indexOf(P, "playerDressUp")]
    eq(dress.model._type, "DressUpModel", "a DressUpModel for the measured way")
    eq(dress.model._unit, "player", "...SetUnit(\"player\")")
    eq(probe.candidates.playerDressUp.set, true, "...recorded")

    -- Closing drops answers still on their way; showing again loads everything afresh.
    WoW.slash("/gsweep models")
    check(not sheet:IsShown(), "/gsweep models again closes it")
    WoW.modelBoxes = {}
    WoW.slash("/gsweep models")
    eq(bomb.state:GetText(), "...", "a new survey starts over")
    WoW.advance(0.2)
    sheet:Hide()
    WoW.modelBoxes[6977] = BOMB
    WoW.advance(1)
    eq(GnomesweeperDB.modelProbe.candidates.walkingBomb.box, nil, "an answer after the sheet closed is dropped")
    eq(bomb.state:GetText(), "...", "...and doesn't touch the cell")
end

----------------------------------------------------------------------------
-- The head crop: the camera rises, the actor grows; tuned by eye and kept
----------------------------------------------------------------------------
do
    local P, T = setup()
    WoW.slash("/gsweep models")
    local scene = T.cells[1].scene
    local box = { l = 1, w = 1, h = 2 }
    local span = 2 * 40 * math.tan(0.15 / 2)
    P.headCrop.size, P.headCrop.center = 0.5, 0.72
    T.fit(scene, box, true)
    check(math.abs(scene.actor._scale - span / (2 * 0.5)) < 1e-9, "the head: half the height fills the view")
    local s = scene.actor._scale
    check(math.abs(scene._camera[3] - s * 2 * (0.72 - 0.5)) < 1e-9, "the camera rises to the crop's centre")
    T.fit(scene, box, false)
    eq(scene._camera[3], 0, "the whole body: the camera back level")

    -- Tuning in the viewer: both heads re-fitted at once, printed, saved.
    WoW.modelBoxes[7138] = { -0.4, -0.4, -0.67, 0.4, 0.4, 0.67 }
    local cell = T.cells[6]
    cell._scripts.OnClick(cell)
    local v = T.viewer()
    local before = v.headFace.actor._scale
    v.zoomIn._scripts.OnClick(v.zoomIn)
    check(math.abs(P.headCrop.size - 0.45) < 1e-9, "Zoom + shows less of the height")
    check(v.headFace.actor._scale > before and v.headBig.actor._scale > before, "...both heads come closer")
    local z = v.headBig._camera[3]
    v.up._scripts.OnClick(v.up)
    check(math.abs(P.headCrop.center - 0.75) < 1e-9, "Up moves the centre up")
    check(v.headBig._camera[3] > z, "...the camera rises")
    eq(v.body._camera[3], 0, "the body isn't touched")
    check(chatHas("head crop: 45% of the height, centred 75% up"), "the crop is printed")
    local saved = GnomesweeperDB.modelProbe.headCrop
    check(saved and math.abs(saved.size - 0.45) < 1e-9 and math.abs(saved.center - 0.75) < 1e-9, "...and saved")
    for _ = 1, 30 do v.zoomIn._scripts.OnClick(v.zoomIn); v.down._scripts.OnClick(v.down) end
    check(math.abs(P.headCrop.size - 0.15) < 1e-9 and P.headCrop.center == 0, "clamped")

    -- A /reload: the saved crop comes back.
    local db = GnomesweeperDB
    db.modelProbe.headCrop = { size = 0.6, center = 0.7 }
    loadAddon({ db = db })
    WoW.slash("/gsweep models")
    local P2 = Gnomesweeper.ModelProbe
    check(math.abs(P2.headCrop.size - 0.6) < 1e-9 and math.abs(P2.headCrop.center - 0.7) < 1e-9, "the saved crop is used again")
    loadAddon({ db = { modelProbe = { headCrop = { size = "x" } } } })
    WoW.slash("/gsweep models")
    eq(Gnomesweeper.ModelProbe.headCrop.size, 0.35, "a damaged one is ignored (the tuned default)")
end

----------------------------------------------------------------------------
-- The viewer: the body and two heads, stepping the animations, particles
----------------------------------------------------------------------------
do
    local P, T = setup()
    WoW.modelBoxes[6977] = BOMB
    WoW.slash("/gsweep models")
    WoW.advance(0.2)
    local cell = T.cells[indexOf(P, "walkingBomb")]
    cell._scripts.OnClick(cell)
    local v = T.viewer()
    WoW.advance(0.2)
    for _, s in ipairs({ v.body, v.headBig, v.headFace }) do
        eq(s.actor._model, 6977, "the viewer loads it into every scene")
        check(s._shown, "...and shows it")
    end
    eq(v.headFace._width, 44, "a head at the face button's size")
    check(v.headFace.actor._scale > v.body.actor._scale, "the head crop is closer than the body")
    check(v.label:GetText():find("1/" .. #P.ANIMS .. ": stand (0)", 1, true) ~= nil, "starts at the first of the list, stand")
    v.next._scripts.OnClick(v.next)
    v.next._scripts.OnClick(v.next)
    local third = P.ANIMS[3]
    for _, s in ipairs(v.scenes) do eq(s.actor._anim, third[1], "> walks the named list, in every scene") end
    check(v.label:GetText():find(third[2] .. " (" .. third[1] .. ")", 1, true) ~= nil, "the label names it")
    check(chatHas("Walking Bomb: " .. third[2] .. " (" .. third[1] .. ")"), "each step is printed, name and number")
    for _ = 1, 60 do v.next._scripts.OnClick(v.next) end
    eq(v.body.actor._anim, P.ANIMS[#P.ANIMS][1], "> stops at the end of the list")
    for _ = 1, 60 do v.prev._scripts.OnClick(v.prev) end
    eq(v.body.actor._anim, 0, "< stops at stand")
    local seen = {}
    for _, a in ipairs(P.ANIMS) do
        check(not seen[a[1]], "each animation listed once: " .. a[1])
        seen[a[1]] = true
    end
    check(seen[0] and seen[68] and seen[1], "stand, cheer and death are in the list")
    v.sparks._scripts.OnClick(v.sparks)
    for _, s in ipairs(v.scenes) do eq(s.actor._particles, 1, "particles on, everywhere") end
    eq(v.sparks.label:GetText(), "Particles: on", "...and the button says so")
    v.sparks._scripts.OnClick(v.sparks)
    eq(v.body.actor._particles, 0, "and off again")

    -- A new model starts its animations over; the DressUpModel cell has no viewer.
    v.next._scripts.OnClick(v.next)
    local other = T.cells[indexOf(P, "landMine")]
    other._scripts.OnClick(other)
    eq(v.body.actor._model, 6271, "another model")
    eq(v.anim, 0, "...from stand")
    eq(v.animIndex, 1, "...the top of the list")
    local dress = T.cells[indexOf(P, "playerDressUp")]
    dress._scripts.OnClick(dress)
    eq(v.body.actor._model, 6271, "the DressUpModel cell doesn't open in the viewer")
end

----------------------------------------------------------------------------
-- /gsweep models perf
----------------------------------------------------------------------------
do
    local P, T = setup()
    WoW.slash("/gsweep models perf")
    check(chatHas("open the board first"), "it needs the board open")
    eq(T.perf(), nil, "...and does nothing else")

    WoW.slash("/gsweep expert")
    WoW.modelBoxes[6977] = BOMB
    WoW.modelBoxes[3124] = { -0.3, -0.3, -0.5, 0.3, 0.3, 0.5 }
    WoW.slash("/gsweep models perf")
    local face, fx = Gnomesweeper.Window.ModelHosts()
    local s = T.perf().scenes
    check(not s.head._shown and not s.bomb._shown, "measured without them first")
    eq(s.head._points[1][2], face, "the head is drawn over the face")
    eq(s.bomb._points[1][2], fx, "the bomb over the effects layer on the tiles")
    check(s.head._parent ~= face and s.bomb._parent ~= fx, "...but belongs to the probe, not the game window")
    eq(s.head:GetFrameStrata(), face:GetFrameStrata(), "in the window's strata")
    check(s.head:GetFrameLevel() > face:GetFrameLevel() and s.bomb:GetFrameLevel() > fx:GetFrameLevel(), "...above its host")
    check(math.abs(s.head:GetEffectiveScale() - face:GetEffectiveScale()) < 1e-9, "...at the window's scale")
    WoW.slash("/gsweep models perf")
    check(chatHas("already being measured"), "one run at a time")
    WoW.modelBoxes[6977] = nil                             -- the bomb streams in late
    for _ = 1, 400 do WoW.tick(0.0125) end                 -- 5 s at 80 fps
    check(s.head._shown and not s.bomb._shown, "then the models load")
    for _ = 1, 40 do WoW.tick(0.0125) end                  -- while the bomb loads: not counted
    WoW.modelBoxes[6977] = BOMB
    WoW.advance(0.2)
    check(s.head._shown and s.bomb._shown, "then with them")
    eq((GnomesweeperDB.modelProbe or {}).perf, nil, "nothing is saved mid-run")
    eq(s.head.actor._model, 3124, "the face model: Tally, the mascot")
    eq(s.bomb.actor._model, 6977, "the bomb model")
    eq(s.bomb.actor._particles, 1, "the bomb with its particles")
    for _ = 1, 200 do WoW.tick(0.025) end                  -- 5 s at 40 fps
    local perf = GnomesweeperDB.modelProbe.perf
    check(perf and math.abs(perf.without.fps - 80) < 0.5, "the frame rate without: " .. tostring(perf and perf.without.fps))
    check(perf and math.abs(perf.with.fps - 40) < 0.5, "and with: " .. tostring(perf and perf.with.fps))
    eq(perf.board, "30x16", "over the Expert board")
    eq(perf.headLoad, "0.0s", "how long the face took to load")
    eq(perf.bombLoad, "0.1s", "...and the bomb (found at the first poll after it arrived)")
    check(not s.head._shown and not s.bomb._shown, "the scenes go away after")
    check(chatHas("fps"), "the result is printed")
end

----------------------------------------------------------------------------
-- No ModelScene on this client: the sheet says so, nothing throws
----------------------------------------------------------------------------
do
    local P, T = setup()
    local real = CreateFrame
    CreateFrame = function(ftype, ...)
        if ftype == "ModelScene" then error("unknown frame type") end
        return real(ftype, ...)
    end
    WoW.slash("/gsweep models")
    CreateFrame = real
    eq(T.cells[1].state:GetText(), "no ModelScene", "a cell without a scene says so")
    check(chatHas("no ModelScene"), "...and the chat")
    eq(GnomesweeperDB.modelProbe.candidates.walkingBomb.error, "no ModelScene", "...and the record")
end

----------------------------------------------------------------------------
-- Help: listed, and kept off About (a measuring command)
----------------------------------------------------------------------------
do
    setup()
    local found
    for _, line in ipairs(Gnomesweeper.HELP) do
        if line:find("/gsweep models", 1, true) then found = line end
    end
    check(found and found:find("(for measuring)", 1, true), "/gsweep models is in the help, as a measuring command")
end

----------------------------------------------------------------------------
-- The review's fixes (#74)
----------------------------------------------------------------------------
local function count(text)
    local n = 0
    for _, line in ipairs(WoW.chat) do if line:find(text, 1, true) then n = n + 1 end end
    return n
end

-- Every box already in (cached): the summary once, with the right totals.
do
    local P, T = setup()
    for _, c in ipairs(P.CANDIDATES) do if c.display then WoW.modelBoxes[c.display] = BOMB end end
    WoW.modelBoxes["unit:player"] = BOMB
    WoW.modelSetFails[19139] = true
    WoW.slash("/gsweep models")
    eq(count("loaded a box"), 1, "the summary is printed once, not per cached model")
    check(chatHas("23 of 24 models loaded a box"), "...of every model that tried (Boombot, absent, didn't load): "
        .. tostring(WoW.chat[#WoW.chat]))
end

-- An absent model says so at once.
do
    local P, T = setup()
    WoW.slash("/gsweep models")
    local boom = T.cells[indexOf(P, "boombot")]
    eq(boom.state:GetText(), "...", "(Boombot isn't refused here)")
    loadAddon()
    WoW.modelSetFails[19139] = true
    WoW.slash("/gsweep models")
    P, T = Gnomesweeper.ModelProbe, Gnomesweeper.ModelProbe._test
    boom = T.cells[indexOf(P, "boombot")]
    eq(boom.state:GetText(), "absent", "a refused display says absent, without waiting")
    local e = GnomesweeperDB.modelProbe.candidates.boombot
    eq(e.absent, true, "...recorded as absent")
    eq(e.timeout, nil, "...not as a timeout")
end

-- The viewer switching models: the old box never frames the new one, the old model
-- never shows under the new name.
do
    local P, T = setup()
    WoW.modelStale = true                                   -- the client may keep the old box
    WoW.modelBoxes[6977] = BOMB
    WoW.slash("/gsweep models")
    local function click(key) local c = T.cells[indexOf(P, key)]; c._scripts.OnClick(c) end
    click("walkingBomb")
    local v = T.viewer()
    check(v.body._shown, "the bomb is shown")
    click("tally")                                          -- Tally isn't in yet
    check(not v.body._shown and not v.headFace._shown, "the bomb is gone while Tally loads")
    check((v.body.actor._clears or 0) > 0, "the actor was cleared before the new model")
    eq(v.body.box, nil, "...and nothing was framed by the bomb's box")
    check(v.label:GetText():find("Tally Berryfizz  -  loading", 1, true) ~= nil, "the label says loading")
    WoW.modelBoxes[3124] = { -0.4, -0.4, -0.67, 0.4, 0.4, 0.67 }
    WoW.advance(0.2)
    check(v.body._shown and math.abs(v.body.box.h - 1.34) < 1e-9, "framed by Tally's own box once it's in")

    WoW.modelSetFails[19139] = true
    click("boombot")
    check(not v.body._shown, "an absent model leaves the viewer empty")
    check(v.label:GetText():find("XE-321 Boombot  -  absent", 1, true) ~= nil, "...and says so: " .. v.label:GetText())
    click("sheep")                                          -- never loads
    WoW.advance(3.5)
    check(v.label:GetText():find("Explosive Sheep  -  no box in 3s", 1, true) ~= nil, "a timeout says so")
    check(not v.body._shown, "...with nothing drawn")

    -- Closed mid-load, then reopened: the viewer starts clean.
    WoW.modelBoxes[6271] = nil
    click("landMine")
    T.sheet():Hide()
    WoW.slash("/gsweep models")
    eq(v.c, nil, "the viewer forgot the model it was loading")
    eq(v.label:GetText(), "Click a model to view it here.", "...and says to pick one")
    check(not v.body._shown, "...with nothing drawn")
end

-- The perf run: closes the sheet first; dropped, unsaved, if the board closes.
do
    local P, T = setup()
    WoW.slash("/gsweep expert")
    WoW.slash("/gsweep models")
    WoW.slash("/gsweep models perf")
    check(not P.IsShown(), "the models sheet is closed for the run")
    check(chatHas("closed the models sheet"), "...and the chat says why")
    for _ = 1, 100 do WoW.tick(0.0125) end
    Gnomesweeper.Window.win:Hide()                          -- Escape, a fight, Settings
    WoW.tick(0.0125)
    check(chatHas("frame rate run dropped"), "a run without the board is dropped")
    eq((GnomesweeperDB.modelProbe or {}).perf, nil, "...nothing saved")
    eq(T.perf().running, false, "...and it stopped")
    local s = T.perf().scenes
    check(not s.head._shown and not s.bomb._shown, "...its scenes hidden")
    Gnomesweeper.Window.win:Show()
    WoW.slash("/gsweep models perf")
    check(T.perf().running, "a new run can start")
end

done("test_modelprobe")
