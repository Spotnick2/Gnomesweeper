-- Effects.lua: the small celebrations (#10). Built once each, then played and
-- stopped by Window as the game changes; all of it AnimationGroups on a few
-- textures (the client's own animation, no OnUpdate of ours).
--
--   Effects.Burst(parent, anchor)  the win: a gold starburst turning slowly
--                                  behind the mascot, popping in on the win
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

Effects.BURST_SIZE = 84      -- around the 44-unit face
Effects.BURST_TURN = 14      -- seconds a full turn takes
Effects.SMOKE_SIZE = 26
Effects.SMOKE_RISE = 34      -- units a puff rises
Effects.SMOKE_LIFE = 2.4     -- seconds a puff lives
Effects.PUFFS = 3

------------------------------------------------------------
-- The win: the burst behind the face
------------------------------------------------------------

function Effects.Burst(parent, anchor)
    local tex = parent:CreateTexture(nil, "BACKGROUND", nil, 7)       -- over the HUD's backing, under the face
    tex:SetSize(Effects.BURST_SIZE, Effects.BURST_SIZE)
    tex:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    tex:SetTexture(T.burst)
    tex:SetBlendMode("ADD")
    tex:SetVertexColor(unpack(C.gold))
    tex:Hide()

    local turn = tex:CreateAnimationGroup()
    local spin = turn:CreateAnimation("Rotation")
    spin:SetDegrees(-360)
    spin:SetDuration(Effects.BURST_TURN)
    turn:SetLooping("REPEAT")

    local pop = tex:CreateAnimationGroup()
    local grow = pop:CreateAnimation("Scale")
    grow:SetScaleFrom(0.3, 0.3)
    grow:SetScaleTo(1, 1)
    grow:SetDuration(0.45)
    grow:SetSmoothing("OUT")
    local fade = pop:CreateAnimation("Alpha")
    fade:SetFromAlpha(0)
    fade:SetToAlpha(1)
    fade:SetDuration(0.3)

    local h = { tex = tex, turn = turn, pop = pop }
    function h.play()
        if tex:IsShown() then return end
        tex:Show()
        pop:Play()
        turn:Play()
    end
    function h.stop()
        turn:Stop()
        pop:Stop()
        tex:Hide()
    end
    function h.isPlaying() return tex:IsShown() end
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
