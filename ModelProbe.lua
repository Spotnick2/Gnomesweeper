-- ModelProbe.lua: /gsweep models, the model probe (#20). Which creature models
-- render on this client, how long they take, which animations they have, and
-- what a scene costs over the board: what #21 (live models) builds on.
--
-- A sheet of every candidate in docs/MODELS.md, each in its own ModelScene, on
-- AltStable's measured recipe (its Roster's PetFrame / ReadBox / PlacePet /
-- MeasurePet): a plain scene and CreateActor, a far camera with a narrow lens,
-- the actor centred and scaled from its bounding box, the box polled until the
-- model has streamed in. Display IDs only, never SetCreature (a random skin),
-- and never SetModelByCreatureDisplayID(id, true) (it composites the player).
--
-- Clicking a model opens it in the viewer: the whole body, a head crop at the
-- face button's size (is an expression readable at 44 units?) and a bigger one,
-- with < > stepping through SetAnimation IDs (the owner names the useful ones)
-- and the particles on or off (a bomb may want its fuse sparks).
--
-- The player is probed both ways: a ModelScene actor's SetModelByUnit("player")
-- (declared, unmeasured) and a DressUpModel's SetUnit("player") (measured in
-- AltStable: textured).
--
-- /gsweep models perf: the frame rate over the open board for 5 s, then 5 s with
-- a head over the face and a bomb over the tiles, as #21 would draw them.
--
-- Everything is kept in GnomesweeperDB.modelProbe, so a /reload writes it to the
-- SavedVariables file to be read from disk. A probe: its text stays English.

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local GS = Gnomesweeper
local Probe = {}
GS.ModelProbe = Probe

local Glass, Skin, Widgets = GS.Glass, GS.Skin, GS.Widgets
local C = Skin.COLORS

local SHEET_NAME = "GnomesweeperModels"
local COLS, CELL_W, CELL_H, SCENE, PAD, TOP = 7, 100, 124, 92, 16, 64
local VIEW_W = 300
-- AltStable's framing: far and narrow, or the parts nearest the camera grow past
-- the frame; the frame a little bigger than the box (the idle reaches past it).
local FOV, CAMERA, MARGIN = 0.15, 40, 1.3
-- The head crop, in fractions of the model's height: how much of it the view shows, and
-- where the view is centred (from the bottom). A first guess (the top 40%) showed a
-- gnome's hair and eyes only (in game, 70205). Tuned by eye on Emi Shortfuse (owner): 35%
-- of the height, centred 69% up. Still adjustable in the viewer, and saved.
Probe.headCrop = { size = 0.35, center = 0.69 }
local POLL, TRIES = 0.1, 30      -- the box is polled for up to 3 s
local PERF_SECONDS = 5
local FACE_SIZE = 44             -- the face button (Window: Widgets.FaceButton(hud, 44))

-- docs/MODELS.md's candidates (Wowhead, 2026-10-02). Gnomeregan first.
Probe.CANDIDATES = {
    { key = "walkingBomb", display = 6977, name = "Walking Bomb", role = "bomb" },
    { key = "landMine", display = 6271, name = "Goblin Land Mine", role = "bomb" },
    { key = "boombot", display = 19139, name = "XE-321 Boombot", role = "bomb" },
    { key = "sheep", display = 3886, name = "Explosive Sheep", role = "bomb" },
    { key = "alarmBomb", display = 6888, name = "Alarm-a-bomb 2600", role = "alarm" },
    { key = "shortfuse", display = 7138, name = "Emi Shortfuse", role = "face" },
    { key = "tally", display = 3124, name = "Tally Berryfizz", role = "face" },   -- Tinker Town alchemist (NPC 5177): the mascot? (owner)
    { key = "kernobee", display = 7132, name = "Kernobee", role = "face" },
    { key = "technician", display = 6628, name = "Holdout Technician", role = "face" },
    { key = "namdo", display = 4953, name = "Namdo Bizzfizzle", role = "face" },
    { key = "mekkatorque", display = 143349, name = "Mekkatorque", role = "face" },
    { key = "leperAssistant", display = 6967, name = "Leprous Assistant", role = "face" },
    { key = "leperDefender", display = 6982, name = "Leprous Defender", role = "face" },
    { key = "machinesmith", display = 6936, name = "Leprous Machinesmith", role = "face" },
    { key = "thermaplugg", display = 6980, name = "Thermaplugg", role = "villain" },
    { key = "sentry", display = 6978, name = "Mechanized Sentry", role = "bot" },
    { key = "guardian", display = 6979, name = "Mechanized Guardian", role = "bot" },
    { key = "nullifier", display = 6889, name = "Arcane Nullifier X-21", role = "bot" },
    { key = "flamewalker", display = 6890, name = "Mechano-Flamewalker", role = "bot" },
    { key = "electrocutioner", display = 6915, name = "Electrocutioner 6000", role = "bot" },
    { key = "pummeler", display = 6774, name = "Crowd Pummeler 9-60", role = "bot" },
    { key = "fallout", display = 5497, name = "Viscous Fallout", role = "radiation" },
    { key = "horror", display = 4907, name = "Irradiated Horror", role = "radiation" },
    { key = "player", unit = "player", name = "You (scene actor)", role = "face" },
    { key = "playerDressUp", dressUp = true, name = "You (DressUpModel)", role = "face" },
}
-- What the perf run draws: the face and the bomb #21 is most likely to use. Tally is the
-- mascot's model (owner, 2026-10-04); measured first with Emi Shortfuse, the same body.
Probe.PERF_FACE, Probe.PERF_BOMB = "tally", "walkingBomb"

-- The animations worth checking, by WoW's animation numbers (stable since vanilla; the
-- names are what each should be, unmeasured on these models: the owner's eye decides).
-- Stepping through every number was too many to judge (owner, 2026-10-04). A model
-- that lacks one plays its stand instead.
Probe.ANIMS = {
    { 0, "stand" }, { 60, "talk" }, { 64, "talk!" }, { 65, "talk?" }, { 68, "cheer" },
    { 70, "laugh" }, { 80, "applaud" }, { 69, "dance" }, { 67, "wave" }, { 83, "shy" },
    { 77, "cry" }, { 14, "stun" }, { 8, "stand, wounded" }, { 1, "death" }, { 6, "dead" },
    { 4, "walk" }, { 2, "spell" }, { 32, "spell cast" }, { 33, "spell, area" },
    { 25, "ready" }, { 16, "attack" }, { 74, "roar" },
}

local sheet, viewer, perf
local cells = {}

local function Print(msg) print("|cff7fd4ffGnome|rsweeper: " .. msg) end

local function record()
    local probe = type(GnomesweeperDB.modelProbe) == "table" and GnomesweeperDB.modelProbe or {}
    local version, build = GetBuildInfo()
    probe.build = tostring(version) .. "." .. tostring(build)
    probe.candidates = probe.candidates or {}
    GnomesweeperDB.modelProbe = probe
    return probe
end

local function byKey(key)
    for _, c in ipairs(Probe.CANDIDATES) do if c.key == key then return c end end
end

-- The box as Forever returns it: six numbers (measured in AltStable), or Retail's
-- two vectors should a later build switch. nil until the model has loaded.
function Probe.ReadBox(actor)
    local r = { pcall(actor.GetActiveBoundingBox, actor) }
    if not r[1] then return nil end
    local x0, y0, z0, x1, y1, z1
    if type(r[2]) == "table" and type(r[3]) == "table" then
        x0, y0, z0, x1, y1, z1 = r[2].x, r[2].y, r[2].z, r[3].x, r[3].y, r[3].z
    else
        x0, y0, z0, x1, y1, z1 = r[2], r[3], r[4], r[5], r[6], r[7]
    end
    x0, y0, z0 = tonumber(x0), tonumber(y0), tonumber(z0)
    x1, y1, z1 = tonumber(x1), tonumber(y1), tonumber(z1)
    if not (x0 and y0 and z0 and x1 and y1 and z1) then return nil end
    local h = z1 - z0
    if h <= 0.001 then return nil end
    return { l = x1 - x0, w = y1 - y0, h = h, shape = type(r[2]) == "table" and "vectors" or "numbers" }
end

-- A scene with one actor, set up as AltStable's pets are. nil without ModelScene.
local function newScene(parent, size)
    local ok, scene = pcall(CreateFrame, "ModelScene", nil, parent)
    local okA, actor
    if ok and scene then okA, actor = pcall(scene.CreateActor, scene) end
    if not (okA and actor) then return nil end
    scene:SetSize(size, size)
    pcall(scene.SetCameraFieldOfView, scene, FOV)
    pcall(scene.SetCameraNearClip, scene, 0.1)
    pcall(scene.SetCameraFarClip, scene, 100)
    pcall(scene.SetCameraPosition, scene, CAMERA, 0, 0)
    pcall(scene.SetCameraOrientationByYawPitchRoll, scene, math.pi, 0, 0)
    pcall(actor.SetUseCenterForOrigin, actor, true, true, true)
    pcall(actor.SetPosition, actor, 0, 0, 0)
    pcall(actor.SetParticleOverrideScale, actor, 0)
    scene:EnableMouse(false)
    scene.actor = actor
    return scene
end

-- Fit the model to its (square) scene: the whole body, or its head. The head
-- raises the CAMERA rather than moving the actor: the camera is in scene units
-- for sure, while whether an actor's position is scaled with it is unmeasured.
local function fit(scene, box, head)
    local span = 2 * CAMERA * math.tan(FOV / 2)        -- the view's height at the actor
    local actor = scene.actor
    scene.box, scene.head = box, head
    if head then
        local crop = Probe.headCrop
        local s = span / (box.h * crop.size)
        pcall(actor.SetScale, actor, s)
        pcall(scene.SetCameraPosition, scene, CAMERA, 0, s * box.h * (crop.center - 0.5))
    else
        pcall(actor.SetScale, actor, span / (box.h * MARGIN))
        pcall(scene.SetCameraPosition, scene, CAMERA, 0, 0)
    end
end

-- Load a candidate into a scene and poll for its box. done(result) once: the box
-- and the seconds it took, or timeout. A newer load on the scene drops this one.
local function load(scene, c, head, done)
    scene.token = (scene.token or 0) + 1
    local token, t0, actor = scene.token, GetTime(), scene.actor
    local result = {}
    local ok, set
    if c.unit then
        ok, set = pcall(actor.SetModelByUnit, actor, c.unit)
    else
        ok, set = pcall(actor.SetModelByCreatureDisplayID, actor, c.display)
    end
    result.set = ok and set ~= false
    if not ok then result.error = tostring(set) end
    local function poll(tries)
        if scene.token ~= token then return end
        local box = Probe.ReadBox(actor)
        if box then
            result.box, result.seconds = box, GetTime() - t0
            local okL, loaded = pcall(actor.IsLoaded, actor)
            result.loaded = okL and loaded or nil
            fit(scene, box, head)
            scene:Show()
            done(result)
        elseif tries > 0 then
            C_Timer.After(POLL, function() poll(tries - 1) end)
        else
            result.timeout = true
            done(result)
        end
    end
    poll(TRIES)
end

local function summary(r)
    if not r then return "...", C.hint end
    if r.error then return "error", C.boom end
    if r.box then
        return string.format("%.1fs  h %.2f", r.seconds, r.box.h), C.hint
    end
    if r.timeout then return "no box in 3s", C.boom end
    return "...", C.hint
end

----------------------------------------------------------------------------
-- The viewer
----------------------------------------------------------------------------

local function showAnim()
    if not viewer.c then return end
    local a = Probe.ANIMS[viewer.animIndex]
    viewer.anim = a[1]
    viewer.label:SetText(string.format("%s%s  -  %d/%d: %s (%d)", viewer.c.name,
        viewer.c.display and (" (" .. viewer.c.display .. ")") or "", viewer.animIndex, #Probe.ANIMS, a[2], a[1]))
    for _, s in ipairs(viewer.scenes) do pcall(s.actor.SetAnimation, s.actor, viewer.anim) end
end

local function step(by)
    if not viewer.c then return end
    viewer.animIndex = math.min(#Probe.ANIMS, math.max(1, viewer.animIndex + by))
    showAnim()
    Print(string.format("%s: %s (%d)", viewer.c.name, Probe.ANIMS[viewer.animIndex][2], viewer.anim))
end

local function setParticles(on)
    viewer.particles = on
    viewer.sparks.label:SetText(on and "Particles: on" or "Particles: off")
    for _, s in ipairs(viewer.scenes) do pcall(s.actor.SetParticleOverrideScale, s.actor, on and 1 or 0) end
end

-- Tune the head crop by eye (#20: the first guess was off): the two head scenes are
-- re-fitted at once, the values printed and kept, and used again after a /reload.
local function crop(dSize, dCenter)
    local c = Probe.headCrop
    c.size = math.min(1, math.max(0.15, c.size + dSize))
    c.center = math.min(1, math.max(0, c.center + dCenter))
    for _, s in ipairs({ viewer.headBig, viewer.headFace }) do
        if s.box then fit(s, s.box, true) end
    end
    record().headCrop = { size = c.size, center = c.center }
    Print(string.format("head crop: %d%% of the height, centred %d%% up", c.size * 100 + 0.5, c.center * 100 + 0.5))
end

local function buildViewer()
    viewer = CreateFrame("Frame", nil, sheet)
    viewer:SetFrameLevel(Glass.ContentLevel(sheet))
    viewer:SetSize(VIEW_W, CELL_H * 4)
    viewer:SetPoint("TOPRIGHT", sheet, "TOPRIGHT", -PAD, -TOP)
    viewer.anim, viewer.animIndex, viewer.particles = 0, 1, false
    viewer.label = Glass.Font(viewer, 11, "LEFT")
    viewer.label:SetPoint("TOPLEFT", viewer, "TOPLEFT", 0, 0)
    viewer.label:SetWidth(VIEW_W)
    viewer.label:SetText("Click a model to view it here.")
    local function bg(scene)
        local t = viewer:CreateTexture(nil, "BACKGROUND")
        t:SetPoint("TOPLEFT", scene, "TOPLEFT", -2, 2)
        t:SetPoint("BOTTOMRIGHT", scene, "BOTTOMRIGHT", 2, -2)
        t:SetColorTexture(0.10, 0.12, 0.17, 1)
    end
    viewer.scenes = {}
    viewer.body = newScene(viewer, 180)
    viewer.headBig = newScene(viewer, 110)
    viewer.headFace = newScene(viewer, FACE_SIZE)
    if not viewer.body then return end
    viewer.body:SetPoint("TOPLEFT", viewer, "TOPLEFT", 0, -20)
    viewer.headBig:SetPoint("TOPLEFT", viewer.body, "TOPRIGHT", 10, 0)
    viewer.headFace:SetPoint("TOPLEFT", viewer.headBig, "BOTTOMLEFT", 0, -22)
    for _, s in ipairs({ viewer.body, viewer.headBig, viewer.headFace }) do
        bg(s); s:Hide()
        viewer.scenes[#viewer.scenes + 1] = s
    end
    viewer.faceNote = Glass.Font(viewer, 9, "LEFT")
    viewer.faceNote:SetPoint("TOPLEFT", viewer.headFace, "BOTTOMLEFT", 0, -4)
    viewer.faceNote:SetTextColor(unpack(C.hint))
    viewer.faceNote:SetText("at the face's size")

    viewer.prev = Widgets.GlassButton(viewer, 40, 24)
    viewer.prev.label:SetText("<")
    viewer.prev:SetPoint("TOPLEFT", viewer.body, "BOTTOMLEFT", 0, -10)
    viewer.prev:SetScript("OnClick", function() step(-1) end)
    viewer.next = Widgets.GlassButton(viewer, 40, 24)
    viewer.next.label:SetText(">")
    viewer.next:SetPoint("LEFT", viewer.prev, "RIGHT", 6, 0)
    viewer.next:SetScript("OnClick", function() step(1) end)
    viewer.sparks = Widgets.GlassButton(viewer, 110, 24)
    viewer.sparks:SetPoint("TOPLEFT", viewer.prev, "BOTTOMLEFT", 0, -8)
    viewer.sparks:SetScript("OnClick", function() setParticles(not viewer.particles) end)
    setParticles(false)
    -- The head crop's four buttons, under the heads.
    local function cropButton(text, dSize, dCenter)
        local b = Widgets.GlassButton(viewer, 52, 22, { fontSize = 10 })
        b.label:SetText(text)
        b:SetScript("OnClick", function() crop(dSize, dCenter) end)
        return b
    end
    viewer.zoomIn = cropButton("Zoom +", -0.05, 0)
    viewer.zoomIn:SetPoint("TOPLEFT", viewer.faceNote, "BOTTOMLEFT", 0, -10)
    viewer.zoomOut = cropButton("Zoom -", 0.05, 0)
    viewer.zoomOut:SetPoint("LEFT", viewer.zoomIn, "RIGHT", 4, 0)
    viewer.up = cropButton("Up", 0, 0.03)
    viewer.up:SetPoint("TOPLEFT", viewer.zoomIn, "BOTTOMLEFT", 0, -4)
    viewer.down = cropButton("Down", 0, -0.03)
    viewer.down:SetPoint("LEFT", viewer.up, "RIGHT", 4, 0)
    viewer.help = Glass.Font(viewer, 9, "LEFT")
    viewer.help:SetPoint("TOPLEFT", viewer.sparks, "BOTTOMLEFT", 0, -8)
    viewer.help:SetWidth(VIEW_W)
    viewer.help:SetTextColor(unpack(C.hint))
    viewer.help:SetText("< > step through the animations worth checking. A model without one plays its stand. Zoom and Up/Down frame the heads; the crop is kept.")
end

function Probe.View(key)
    local c = byKey(key)
    if not (c and viewer and viewer.body) or c.dressUp then return end
    viewer.c, viewer.anim, viewer.animIndex = c, 0, 1
    viewer.label:SetText(c.name .. "  -  loading")
    load(viewer.body, c, false, function() showAnim() end)
    load(viewer.headBig, c, true, function() end)
    load(viewer.headFace, c, true, function() end)
    setParticles(viewer.particles)
end

----------------------------------------------------------------------------
-- The sheet
----------------------------------------------------------------------------

local function buildCell(i, c)
    local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
    local cell = CreateFrame("Button", nil, sheet)
    cell:SetFrameLevel(Glass.ContentLevel(sheet))
    cell:SetSize(CELL_W - 6, CELL_H - 6)
    cell:SetPoint("TOPLEFT", sheet, "TOPLEFT", PAD + col * CELL_W, -(TOP + row * CELL_H))
    cell.bg = cell:CreateTexture(nil, "BACKGROUND")
    cell.bg:SetSize(SCENE, SCENE)
    cell.bg:SetPoint("TOP", cell, "TOP", 0, 0)
    cell.bg:SetColorTexture(0.10, 0.12, 0.17, 1)
    if c.dressUp then
        local ok, m = pcall(CreateFrame, "DressUpModel", nil, cell)
        if ok and m then
            m:SetSize(SCENE, SCENE)
            m:SetPoint("TOP", cell, "TOP", 0, 0)
            m:EnableMouse(false)
            cell.model = m
        end
    else
        cell.scene = newScene(cell, SCENE)
        if cell.scene then
            cell.scene:SetPoint("TOP", cell, "TOP", 0, 0)
            cell.scene:Hide()
        end
    end
    cell.name = Glass.Font(cell, 9, "CENTER")
    cell.name:SetPoint("TOP", cell.bg, "BOTTOM", 0, -3)
    cell.name:SetWidth(CELL_W - 6)
    cell.name:SetText(c.name)
    cell.state = Glass.Font(cell, 9, "CENTER")
    cell.state:SetPoint("TOP", cell.name, "BOTTOM", 0, -2)
    cell:SetScript("OnClick", function() Probe.View(c.key) end)
    cells[i] = cell
    return cell
end

local function build()
    sheet = CreateFrame("Frame", SHEET_NAME, UIParent)
    sheet:SetFrameStrata("FULLSCREEN_DIALOG")
    sheet:SetClampedToScreen(true)
    sheet:SetMovable(true)
    sheet:EnableMouse(true)
    sheet:RegisterForDrag("LeftButton")
    sheet:SetScript("OnDragStart", function(self) self:StartMoving() end)
    sheet:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    sheet:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    sheet:Hide()
    local escapable = false
    for _, name in ipairs(UISpecialFrames) do if name == SHEET_NAME then escapable = true end end
    if not escapable then table.insert(UISpecialFrames, SHEET_NAME) end
    sheet.glass = Glass.Apply(sheet, "large")
    sheet.backing = sheet:CreateTexture(nil, "BACKGROUND", nil, -7)
    sheet.backing:SetAllPoints(sheet)
    sheet.backing:SetColorTexture(unpack(C.overlayBg))
    sheet.backing:AddMaskTexture(sheet.glass.mask)

    sheet.title = Glass.Font(sheet, 16, "LEFT")
    sheet.title:SetPoint("TOPLEFT", sheet, "TOPLEFT", PAD, -14)
    sheet.title:SetText(Skin.TITLE .. " models")
    sheet.hint = Glass.Font(sheet, 11, "LEFT")
    sheet.hint:SetPoint("TOPLEFT", sheet.title, "BOTTOMLEFT", 0, -4)
    sheet.hint:SetTextColor(unpack(C.hint))
    sheet.hint:SetText("Is each one there, and textured (not white)? Click one to see its head and animations.")

    sheet.close = Widgets.IconButton(sheet, 22, Skin.TEXTURES.close, { 1, 0.9, 0.9 })
    sheet.close:SetFrameLevel(Glass.ContentLevel(sheet))
    sheet.close:SetPoint("TOPRIGHT", sheet, "TOPRIGHT", -10, -10)
    sheet.close:setAccent(unpack(C.closeAccent))
    sheet.close:SetScript("OnClick", function() sheet:Hide() end)
    -- Closing drops every answer still on its way.
    sheet:SetScript("OnHide", function()
        for _, cell in ipairs(cells) do if cell.scene then cell.scene.token = (cell.scene.token or 0) + 1 end end
        if viewer then for _, s in ipairs(viewer.scenes or {}) do s.token = (s.token or 0) + 1 end end
    end)

    for i, c in ipairs(Probe.CANDIDATES) do buildCell(i, c) end
    buildViewer()
    local rows = math.ceil(#Probe.CANDIDATES / COLS)
    sheet:SetSize(2 * PAD + COLS * CELL_W + PAD + VIEW_W, TOP + math.max(rows * CELL_H, 4 * CELL_H) + 8)
end

-- Load every candidate, fill its cell, keep what it measured.
local function survey()
    local probe = record()
    probe.at = time()
    probe.candidates = {}
    local waiting, loadedN, total = 0, 0, 0
    local function finished()
        waiting = waiting - 1
        if waiting == 0 then
            Print(string.format("%d of %d models loaded a box. Textured or white is for your eyes; /reload saves the results.",
                loadedN, total))
        end
    end
    for i, c in ipairs(Probe.CANDIDATES) do
        local cell = cells[i]
        local entry = { name = c.name, role = c.role, display = c.display, unit = c.unit }
        probe.candidates[c.key] = entry
        if c.dressUp then
            if cell.model then
                local ok, err = pcall(cell.model.SetUnit, cell.model, "player")
                entry.set = ok
                if not ok then entry.error = tostring(err) end
                cell.state:SetText(ok and "SetUnit(\"player\")" or "error")
                cell.state:SetTextColor(unpack(ok and C.hint or C.boom))
            else
                entry.error = "no DressUpModel"
                cell.state:SetText("no DressUpModel")
                cell.state:SetTextColor(unpack(C.boom))
            end
        elseif not cell.scene then
            entry.error = "no ModelScene"
            cell.state:SetText("no ModelScene")
            cell.state:SetTextColor(unpack(C.boom))
        else
            total, waiting = total + 1, waiting + 1
            cell.state:SetText("...")
            cell.state:SetTextColor(unpack(C.hint))
            load(cell.scene, c, false, function(r)
                entry.set, entry.error, entry.seconds, entry.loaded, entry.timeout = r.set, r.error, r.seconds, r.loaded, r.timeout
                if r.box then
                    entry.box = { l = r.box.l, w = r.box.w, h = r.box.h, shape = r.box.shape }
                    loadedN = loadedN + 1
                end
                local text, color = summary(r)
                cell.state:SetText(text)
                cell.state:SetTextColor(color[1], color[2], color[3])
                finished()
            end)
        end
    end
    if total == 0 then Print("this client has no ModelScene: nothing to probe.") end
end

-- /gsweep models: show (or hide) the sheet; each show loads everything afresh.
function Probe.Toggle()
    if sheet and sheet:IsShown() then sheet:Hide(); return end
    local saved = type(GnomesweeperDB.modelProbe) == "table" and GnomesweeperDB.modelProbe.headCrop
    if type(saved) == "table" and tonumber(saved.size) and tonumber(saved.center) then
        Probe.headCrop.size, Probe.headCrop.center = tonumber(saved.size), tonumber(saved.center)
    end
    if not sheet then build() end
    sheet:Show()
    survey()
end

----------------------------------------------------------------------------
-- /gsweep models perf
----------------------------------------------------------------------------

local function perfScenes(face, fx)
    if perf.scenes then return perf.scenes end
    local head = newScene(face, FACE_SIZE)
    local bomb = newScene(fx, 72)
    if not (head and bomb) then return nil end
    head:SetPoint("CENTER", face, "CENTER", 0, 0)
    head:SetFrameLevel(face:GetFrameLevel() + 5)
    bomb:SetPoint("CENTER", fx, "CENTER", 0, 0)
    bomb:SetFrameLevel(fx:GetFrameLevel() + 1)
    perf.scenes = { head = head, bomb = bomb }
    return perf.scenes
end

-- Frames counted over PERF_SECONDS without, then with, the two scenes.
function Probe.Perf()
    local face, fx = GS.Window.ModelHosts()
    if not (GS.Window.IsShown() and face and fx) then
        Print("open the board first (/gsweep expert is the worst case), then /gsweep models perf.")
        return
    end
    perf = perf or CreateFrame("Frame", nil, UIParent)
    if perf.running then Print("the frame rate is already being measured."); return end
    local scenes = perfScenes(face, fx)
    if not scenes then Print("this client has no ModelScene: nothing to measure."); return end
    scenes.head:Hide(); scenes.bomb:Hide()
    local result = { seconds = PERF_SECONDS }
    local phase, frames, elapsed = "without", 0, 0
    perf.running = true
    Print(string.format("measuring the frame rate: %d s as it is, then %d s with a head and a bomb. Keep still.",
        PERF_SECONDS, PERF_SECONDS))
    -- "with" is counted from when both models are in (or gave up), not while they stream.
    local waiting = 0
    local function arrived(name, r)
        result[name] = r.box and string.format("%.1fs", r.seconds) or "no box"
        waiting = waiting - 1
        if waiting == 0 then phase, frames, elapsed = "with", 0, 0 end
    end
    perf:SetScript("OnUpdate", function(self, dt)
        if phase == "loading" then return end
        frames, elapsed = frames + 1, elapsed + dt
        if elapsed < PERF_SECONDS then return end
        result[phase] = { fps = frames / elapsed, ms = 1000 * elapsed / frames }
        if phase == "without" then
            phase, waiting = "loading", 2
            load(scenes.head, byKey(Probe.PERF_FACE), true, function(r) arrived("headLoad", r) end)
            load(scenes.bomb, byKey(Probe.PERF_BOMB), false, function(r)
                if r.box then pcall(scenes.bomb.actor.SetParticleOverrideScale, scenes.bomb.actor, 1) end
                arrived("bombLoad", r)
            end)
            return
        end
        self:SetScript("OnUpdate", nil)
        self.running = false
        scenes.head:Hide(); scenes.bomb:Hide()
        scenes.head.token = (scenes.head.token or 0) + 1
        scenes.bomb.token = (scenes.bomb.token or 0) + 1
        local w, h = GS.Window.game and GS.Window.game.w, GS.Window.game and GS.Window.game.h
        result.board = w and h and (w .. "x" .. h) or nil
        record().perf = result
        Print(string.format("%.1f fps (%.1f ms) without the models, %.1f fps (%.1f ms) with them%s. /reload saves it.",
            result.without.fps, result.without.ms, result.with.fps, result.with.ms,
            result.board and (" over a " .. result.board .. " board") or ""))
    end)
end

function Probe.IsShown() return sheet ~= nil and sheet:IsShown() end

Probe._test = {
    cells = cells,
    sheet = function() return sheet end,
    viewer = function() return viewer end,
    perf = function() return perf end,
    fit = fit,
}
