-- Models.lua: live creature models (#21), on what #20's probe measured
-- (docs/MODELS.md "Results"). The end panel gets a model on its left (owner: "put it
-- on the left and increase the width of the dialog"): a Walking Bomb going off on a
-- wipe, Tally Berryfizz, the mascot's own model, jumping for joy on a win.
--
-- AltStable's recipe, as the probe uses it: a plain ModelScene and CreateActor,
-- a far camera with a narrow lens, the actor centred and scaled from its box, the
-- box polled until the model is in. A display ID, never SetCreature. The actor is
-- cleared before each load (switching models may answer with the old box) and the
-- scene stays hidden until the box is in.
--
-- Never a model per tile: one scene, in the panel. Everything degrades: no
-- ModelScene, the display refused (absent: the client says false at once), no box
-- within WAIT, or the "3D models" setting off, and the panel is drawn without it.

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local GS = Gnomesweeper
local Models = {}
GS.Models = Models

-- Who plays what (#20, #21, in game): `steps`, each { animation, seconds [, lift = units] },
-- played in order; a step without seconds is held.
-- Timed, because no actor event says when an animation ends (only Model frames have
-- OnAnimFinished). `lift` raises the model (window units), the cast's for all its steps
-- or a step's while it plays.
Models.CAST = {
    -- The Walking Bomb (Gnomeregan): its death (1) is its explosion; then its dead pose
    -- (6), held while the panel is up. Its wreckage lies lower than it stood, below the
    -- panel (in game): lifted 24 it sits inside (judged right).
    wipe = { display = 6977, particles = true, steps = { { 1, 1.5 }, { 6, lift = 24 } } },
    -- Tally Berryfizz, the mascot's model (owner), cheering (68): it plays once and she
    -- stands. A jump-and-cheer loop was tried: the jumps don't read in a frame (owner: "cheer
    -- is the proper one"). Her voice is the win's sound (Sounds.KITS.win, her /cheer).
    win = { display = 3124, steps = { { 68 } } },
}
-- How tall a model's box is drawn, in window units (tiles are 24). 118 looked right
-- over the field but stood taller than the old end panel; the owner's mockup made the
-- panel taller (142) with the bomb standing on its floor: 104, its fuse inside (#21).
Models.HEIGHT = 104
-- The scene around it: a model drawn past its scene is cut off (in game: a 96-unit
-- scene sliced the top of the bomb's sphere; a 120 one still cut its fuse and blast,
-- which reach past its box). Square, centred on the model's column; its spare room is
-- empty and may reach past the panel's edge.
Models.FRAME = 180
Models.WAIT = 0.5              -- a model not in by then is skipped: the panel is drawn without it
Models.SETTLE = 2             -- seconds its box is read again after it first answers
local POLL = 0.1
local FOV, CAMERA = 0.15, 40   -- AltStable's framing (ModelProbe uses the same)

local function db() return GnomesweeperDB end

-- The setting (on unless turned off).
function Models.Enabled() return db().models ~= false end

-- The box's height as Forever returns it (six numbers), or from Retail's two vectors.
local function readBox(actor)
    local r = { pcall(actor.GetActiveBoundingBox, actor) }
    if not r[1] then return nil end
    local z0, z1
    if type(r[2]) == "table" and type(r[3]) == "table" then
        z0, z1 = r[2].z, r[3].z
    else
        z0, z1 = r[4], r[7]
    end
    z0, z1 = tonumber(z0), tonumber(z1)
    if not (z0 and z1) or z1 - z0 <= 0.001 then return nil end
    return z1 - z0
end

-- A model slot on `parent` at frame level `level`. h.play(key, onFail, delay) loads
-- Models.CAST[key] and plays it; its first step waits `delay` seconds (standing) when given; onFail runs (at once, or after WAIT) when it can't,
-- so the caller can lay the panel out without it. h.stop() hides it and drops any
-- load or timer still on its way. h.scene is nil until the first play.
function Models.Slot(parent, level)
    local h = {}
    local actor, token = nil, 0
    local function build()
        if h.scene ~= nil then return h.scene end
        local ok, s = pcall(CreateFrame, "ModelScene", nil, parent)
        local okA, a
        if ok and s then okA, a = pcall(s.CreateActor, s) end
        if not (okA and a) then h.scene = false; return false end
        s:SetSize(Models.FRAME, Models.FRAME)
        s:SetFrameLevel(level)
        s:EnableMouse(false)                               -- a click on the panel is the panel's
        pcall(s.SetCameraFieldOfView, s, FOV)
        pcall(s.SetCameraNearClip, s, 0.1)
        pcall(s.SetCameraFarClip, s, 100)
        pcall(s.SetCameraPosition, s, CAMERA, 0, 0)
        pcall(s.SetCameraOrientationByYawPitchRoll, s, math.pi, 0, 0)
        pcall(a.SetUseCenterForOrigin, a, true, true, true)
        pcall(a.SetPosition, a, 0, 0, 0)
        s:Hide()
        h.scene, actor = s, a
        return s
    end

    function h.play(key, onFail, delay)
        h.stop()
        local c = Models.CAST[key]
        if not (c and Models.Enabled() and build()) then return onFail() end
        local mine = token
        pcall(h.scene.SetCameraPosition, h.scene, CAMERA, 0, 0)    -- level again after a lift
        pcall(actor.ClearModel, actor)
        local ok, set = pcall(actor.SetModelByCreatureDisplayID, actor, c.display)
        if not ok or set == false then return onFail() end   -- absent: nothing to wait for
        h.playing = key
        local function poll(left)
            if token ~= mine then return end
            local height = readBox(actor)
            if height then
                -- The view spans `span` scene units over FRAME window units: the box comes
                -- out HEIGHT units tall.
                local span = 2 * CAMERA * math.tan(FOV / 2)
                local function fit(hh) pcall(actor.SetScale, actor, span * Models.HEIGHT / (hh * Models.FRAME)) end
                fit(height)
                -- The first box can come while the model is still streaming in, smaller than
                -- the finished one: drawn from it the model was too big, the first time only
                -- (owner, in game: right after a close and reopen). Keep reading it a while
                -- and fit again when it changes. Both heights are kept, for the record.
                local log = { first = height, final = height }
                local boxes = type(db().modelBoxes) == "table" and db().modelBoxes or {}
                db().modelBoxes = boxes
                boxes[key] = log
                local function settle(left)
                    if token ~= mine then return end
                    local hh = readBox(actor)
                    if hh and math.abs(hh - log.final) > log.final * 0.01 then
                        log.final = hh
                        fit(hh)
                    end
                    if left > 0 then C_Timer.After(POLL, function() settle(left - 1) end) end
                end
                C_Timer.After(POLL, function() settle(Models.SETTLE / POLL) end)
                pcall(actor.SetParticleOverrideScale, actor, c.particles and 1 or 0)
                h.scene:Show()
                -- The steps, each after the last; a newer play or a stop drops the rest.
                local function step(i)
                    if token ~= mine then return end
                    local s = c.steps[i]
                    if not s then return end
                    pcall(actor.SetAnimation, actor, s[1])
                    -- The camera down by `lift` window units, in scene units: the model up.
                    pcall(h.scene.SetCameraPosition, h.scene, CAMERA, 0, -(s.lift or c.lift or 0) * span / Models.FRAME)
                    if s[2] then C_Timer.After(s[2], function() step(i + 1) end) end
                end
                if delay and delay > 0 then
                    pcall(actor.SetAnimation, actor, 0)                -- standing until her cue
                    pcall(h.scene.SetCameraPosition, h.scene, CAMERA, 0, -(c.lift or 0) * span / Models.FRAME)
                    C_Timer.After(delay, function() step(1) end)
                else
                    step(1)
                end
            elseif left > 0 then
                C_Timer.After(POLL, function() poll(left - 1) end)
            else
                h.playing = nil
                onFail()                                           -- too slow: drawn without it
            end
        end
        poll(math.floor(Models.WAIT / POLL + 0.5))                 -- tries left
    end

    function h.stop()
        token = token + 1
        h.playing = nil
        if h.scene then h.scene:Hide() end
    end

    h._test = { actor = function() return actor end }
    return h
end
