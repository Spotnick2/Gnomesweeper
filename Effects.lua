-- Effects.lua: the small celebrations (#10). Built once each, then played and
-- stopped by Window as the game changes; all of it AnimationGroups on a few
-- textures (the client's own animation, no OnUpdate of ours).
--
--   Effects.Burst(parent, anchor)  the win: a gold ring ripples out from the
--                                  mascot, then a soft glow breathes behind her
--   Effects.Smoke(parent)          the wipe: three puffs rising from the tile
--                                  that went off, looping gently
--   Effects.Pulse(region)          a beat: the "New personal best!" line
--   Effects.Fireworks(parent)      a new personal best: bursts over the board
--
-- Each returns a handle with :play(...) / :stop() / :isPlaying(). The
-- animation methods (Rotation:SetDegrees, Scale:SetScaleFrom...) are the dump's
-- SimpleAnim*API, checked by tests/test_methods.lua.

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local GS = Gnomesweeper
local Effects = {}
GS.Effects = Effects

local Skin = GS.Skin
local T, C = Skin.TEXTURES, Skin.COLORS

Effects.GLOW_SIZE = 70       -- the soft glow around the 44-unit face (its edge is all fade)
Effects.GLOW_LOW = 0.55      -- the glow's alpha at the bottom of a breath
Effects.GLOW_BREATH = 1.1    -- seconds from bright to dim (and back)
Effects.SMOKE_SIZE = 26
Effects.SMOKE_RISE = 34      -- units a puff rises
Effects.SMOKE_LIFE = 2.4     -- seconds a puff lives
Effects.PUFFS = 3

------------------------------------------------------------
-- The win: a glow behind the face. Its choreography is the spell-proc glow's
-- (LibButtonGlow, as Apotheca ports it): a flash that pops out and fades, then
-- a quiet steady state. Here a gold ring ripples out from the face once, and a
-- soft round glow (Media/fx_glow) breathes behind her while the win shows. (The
-- first try, a big spinning starburst, was harsh and spilled over the
-- difficulty button: owner, 2026-10-03.)
------------------------------------------------------------

function Effects.Burst(parent, anchor)
    local glow = parent:CreateTexture(nil, "BACKGROUND", nil, 7)      -- over the HUD's backing, under the face
    glow:SetSize(Effects.GLOW_SIZE, Effects.GLOW_SIZE)
    glow:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    glow:SetTexture(T.glow)
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(unpack(C.gold))
    glow:Hide()

    local ring = parent:CreateTexture(nil, "BACKGROUND", nil, 7)
    ring:SetSize(anchor:GetWidth(), anchor:GetHeight())
    ring:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    ring:SetTexture(T.faceRing)
    ring:SetBlendMode("ADD")
    ring:SetVertexColor(unpack(C.gold))
    ring:SetAlpha(0)
    ring:Hide()

    -- Once: the ring ripples out and fades; the glow swells in.
    local ripple = ring:CreateAnimationGroup()
    local out = ripple:CreateAnimation("Scale")
    out:SetScaleFrom(1, 1)
    out:SetScaleTo(1.8, 1.8)
    out:SetDuration(0.6)
    out:SetSmoothing("OUT")
    local flash = ripple:CreateAnimation("Alpha")
    flash:SetFromAlpha(1)
    flash:SetToAlpha(0)
    flash:SetDuration(0.6)
    ripple:SetScript("OnFinished", function() ring:Hide() end)

    local pop = glow:CreateAnimationGroup()
    local swell = pop:CreateAnimation("Scale")
    swell:SetScaleFrom(0.5, 0.5)
    swell:SetScaleTo(1, 1)
    swell:SetDuration(0.35)
    swell:SetSmoothing("OUT")

    -- Then, while the win shows: the glow breathes.
    local breathe = glow:CreateAnimationGroup()
    breathe:SetLooping("REPEAT")
    local dim = breathe:CreateAnimation("Alpha")
    dim:SetFromAlpha(1)
    dim:SetToAlpha(Effects.GLOW_LOW)
    dim:SetDuration(Effects.GLOW_BREATH)
    dim:SetSmoothing("IN_OUT")
    dim:SetOrder(1)
    local bright = breathe:CreateAnimation("Alpha")
    bright:SetFromAlpha(Effects.GLOW_LOW)
    bright:SetToAlpha(1)
    bright:SetDuration(Effects.GLOW_BREATH)
    bright:SetSmoothing("IN_OUT")
    bright:SetOrder(2)

    local h = { tex = glow, ring = ring, ripple = ripple, pop = pop, breathe = breathe }
    function h.play()
        if glow:IsShown() then return end
        glow:Show()
        ring:Show()
        ripple:Play()
        pop:Play()
        breathe:Play()
    end
    function h.stop()
        ripple:Stop()
        pop:Stop()
        breathe:Stop()
        ring:Hide()
        glow:Hide()
    end
    function h.isPlaying() return glow:IsShown() end
    return h
end

------------------------------------------------------------
-- The wipe: smoke from the tile that went off
------------------------------------------------------------

function Effects.Smoke(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(1, 1)
    holder:Hide()
    local puffs = {}
    for i = 1, Effects.PUFFS do
        local p = holder:CreateTexture(nil, "OVERLAY")
        p:SetSize(Effects.SMOKE_SIZE, Effects.SMOKE_SIZE)
        p:SetPoint("CENTER", holder, "CENTER", (i - 2) * 4, 0)
        p:SetTexture(T.smoke)
        p:SetVertexColor(unpack(C.smoke))
        p:SetAlpha(0)
        local ag = p:CreateAnimationGroup()
        ag:SetLooping("REPEAT")
        local delay = (i - 1) * Effects.SMOKE_LIFE / Effects.PUFFS
        local rise = ag:CreateAnimation("Translation")
        rise:SetOffset((i - 2) * 6, Effects.SMOKE_RISE)
        rise:SetDuration(Effects.SMOKE_LIFE)
        rise:SetStartDelay(delay)
        local grow = ag:CreateAnimation("Scale")
        grow:SetScaleFrom(0.5, 0.5)
        grow:SetScaleTo(1.8, 1.8)
        grow:SetDuration(Effects.SMOKE_LIFE)
        grow:SetStartDelay(delay)
        local show = ag:CreateAnimation("Alpha")
        show:SetFromAlpha(0)
        show:SetToAlpha(0.8)
        show:SetDuration(Effects.SMOKE_LIFE * 0.25)
        show:SetStartDelay(delay)
        local hide = ag:CreateAnimation("Alpha")
        hide:SetFromAlpha(0.8)
        hide:SetToAlpha(0)
        hide:SetDuration(Effects.SMOKE_LIFE * 0.75)
        hide:SetStartDelay(delay + Effects.SMOKE_LIFE * 0.25)
        puffs[i] = { tex = p, ag = ag }
    end

    local h = { holder = holder, puffs = puffs }
    -- Over `region` (the tile that went off), above the tiles.
    function h.play(region)
        holder:ClearAllPoints()
        holder:SetPoint("CENTER", region, "CENTER", 0, 4)
        holder:SetFrameLevel(region:GetFrameLevel() + 2)
        if holder:IsShown() then return end
        holder:Show()
        for _, q in ipairs(puffs) do q.ag:Play() end
    end
    function h.stop()
        for _, q in ipairs(puffs) do q.ag:Stop() end
        holder:Hide()
    end
    function h.isPlaying() return holder:IsShown() end
    return h
end

------------------------------------------------------------
-- A beat: a line that swells and settles, again and again while it shows
------------------------------------------------------------

function Effects.Pulse(region)
    local ag = region:CreateAnimationGroup()
    ag:SetLooping("REPEAT")
    local up = ag:CreateAnimation("Scale")
    up:SetScaleFrom(1, 1)
    up:SetScaleTo(1.18, 1.18)
    up:SetDuration(0.35)
    up:SetSmoothing("OUT")
    up:SetOrder(1)
    local down = ag:CreateAnimation("Scale")
    down:SetScaleFrom(1.18, 1.18)
    down:SetScaleTo(1, 1)
    down:SetDuration(0.45)
    down:SetSmoothing("IN")
    down:SetOrder(2)

    local h = { ag = ag }
    function h.play() ag:Stop(); ag:Play() end
    function h.stop() ag:Stop() end
    function h.isPlaying() return ag:IsPlaying() end
    return h
end

------------------------------------------------------------
-- A new personal best: fireworks over the board (the owner's idea; a setting
-- turns them off). Bursts in the difficulty's colours pop and fade at random
-- places, staggered, once.
------------------------------------------------------------

Effects.ROCKETS = 7
Effects.ROCKET_SPREAD = 1.8   -- seconds from the first burst to the last
Effects.ROCKET_LIFE = 0.9     -- seconds one burst takes
Effects.ROCKET_SIZE = 70

function Effects.Fireworks(parent)
    local rockets = {}
    for i = 1, Effects.ROCKETS do
        local r = parent:CreateTexture(nil, "OVERLAY", nil, 7)
        r:SetSize(Effects.ROCKET_SIZE, Effects.ROCKET_SIZE)
        r:SetTexture(T.burst)
        r:SetBlendMode("ADD")
        r:SetAlpha(0)
        r:Hide()
        local ag = r:CreateAnimationGroup()
        local grow = ag:CreateAnimation("Scale")
        grow:SetScaleFrom(0.15, 0.15)
        grow:SetScaleTo(1.3, 1.3)
        grow:SetDuration(Effects.ROCKET_LIFE)
        grow:SetSmoothing("OUT")
        local flash = ag:CreateAnimation("Alpha")
        flash:SetFromAlpha(0)
        flash:SetToAlpha(1)
        flash:SetDuration(0.12)
        local fade = ag:CreateAnimation("Alpha")
        fade:SetFromAlpha(1)
        fade:SetToAlpha(0)
        fade:SetStartDelay(0.25)
        fade:SetDuration(Effects.ROCKET_LIFE - 0.25)
        ag:SetScript("OnFinished", function() r:Hide() end)
        rockets[i] = { tex = r, ag = ag, anims = { grow, flash, fade } }
    end

    local h = { rockets = rockets }
    -- Over `area` (the board), in `colors` (a list of {r, g, b}), from `rng(n)`.
    function h.play(area, colors, rng)
        local w, ht = area:GetWidth(), area:GetHeight()
        for i, q in ipairs(rockets) do
            local delay = (i - 1) / math.max(1, #rockets - 1) * Effects.ROCKET_SPREAD
            local x = (rng(1000) / 1000 - 0.5) * w * 0.8
            local y = (rng(1000) / 1000 - 0.5) * ht * 0.8
            q.tex:ClearAllPoints()
            q.tex:SetPoint("CENTER", area, "CENTER", x, y)
            local col = colors[(i - 1) % #colors + 1]
            q.tex:SetVertexColor(col[1], col[2], col[3])
            for _, a in ipairs(q.anims) do
                a:SetStartDelay(delay + (a == q.anims[3] and 0.25 or 0))
            end
            q.ag:Stop()
            q.tex:Show()
            q.ag:Play()
        end
    end
    function h.stop()
        for _, q in ipairs(rockets) do q.ag:Stop(); q.tex:Hide() end
    end
    function h.isPlaying()
        for _, q in ipairs(rockets) do if q.tex:IsShown() then return true end end
        return false
    end
    return h
end

Effects._test = {}
