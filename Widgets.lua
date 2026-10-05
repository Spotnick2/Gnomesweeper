-- Widgets.lua: the Liquid Glass controls the window is built from, so the close
-- button, the settings gear, the difficulty dropdown, the overlay's buttons and
-- the result bar all share one look: a dark glass body, a bright rim that takes a
-- colour, a hover glow and a pressed state.
--
-- Everything is baked textures from Tools/make_ui.py (9-sliced for the wide
-- buttons), never Glass.Apply: that makes six textures, a mask and a frame per
-- host, and its sliced mask fails on small squares. Nothing here is secure.
--
-- Methods we add to a widget are lower-case (b:setAccent), so none can be
-- mistaken for, or collide with, one of the client's own.

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local Widgets = {}
Gnomesweeper.Widgets = Widgets

local Glass, Skin = Gnomesweeper.Glass, Gnomesweeper.Skin
local T, C = Skin.TEXTURES, Skin.COLORS
local SLICE = 8                              -- texture pixels; the corner radius sits inside it

local function slice(tex)
    tex:SetTextureSliceMargins(SLICE, SLICE, SLICE, SLICE)
    local modes = Enum and Enum.UITextureSliceMode
    tex:SetTextureSliceMode((modes and modes.Stretched) or 0)
end

-- A tooltip on `widget`: a title and any number of grey, wrapping lines.
-- `lines` is a string, a list, or a function returning a list (asked on every
-- hover, for lines that change: a best time).
function Widgets.Tip(widget, title, lines)
    if type(lines) == "string" then lines = { lines } end
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(title)
        local list = type(lines) == "function" and lines() or lines
        for _, line in ipairs(list or {}) do GameTooltip:AddLine(line, 0.75, 0.78, 0.85, true) end
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- A glass button. `opts.square` for the small icon buttons: a texture 22 units
-- across must not be sliced (its corners would meet), so it is drawn whole.
-- b.label is the centred text; b:setAccent(r, g, b) colours the rim.
function Widgets.GlassButton(parent, width, height, opts)
    opts = opts or {}
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height)

    local function layer(name, drawLayer, texture)
        local t = b:CreateTexture(nil, drawLayer)
        t:SetAllPoints(b)
        t:SetTexture(texture)
        if not opts.square then slice(t) end
        b[name] = t
        return t
    end
    layer("fill", "BACKGROUND", T.uiFill)
    layer("border", "BORDER", T.uiBorder)
    local hover = layer("hover", "HIGHLIGHT", T.uiGlow)
    hover:SetBlendMode("ADD")
    hover:SetVertexColor(unpack(C.glassHover))
    local press = layer("press", "ARTWORK", T.uiGlow)
    press:SetVertexColor(0, 0, 0, 0.35)
    press:Hide()

    b.label = Glass.Font(b, opts.fontSize or 12, "CENTER")
    b.label:SetPoint("CENTER", b, "CENTER", 0, 0)

    -- Pressed while the button is down; the release always arrives on the button
    -- that got the press, even after the cursor has left it.
    b:SetScript("OnMouseDown", function(self) self.press:Show() end)
    b:SetScript("OnMouseUp", function(self) self.press:Hide() end)
    -- If it hides before the release arrives (the window closed under a held button), it must not
    -- come back still looking pressed.
    b:SetScript("OnHide", function(self) self.press:Hide() end)

    function b.setAccent(self, r, g, bl)
        self.border:SetVertexColor(r, g, bl)
        self.accent = { r, g, bl }
    end
    -- The panel's main action (#21, the owner's mockups): a filled blue body and a bright
    -- rim (no outer glow: the second mockup took it off). Off: the plain glass button.
    function b.setPrimary(self, on)
        if on then
            self.fill:SetVertexColor(unpack(C.primaryFill))
            self:setAccent(unpack(C.primaryRim))
        else
            self.fill:SetVertexColor(1, 1, 1)
        end
        self.primary = on and true or nil
    end
    b:setAccent(unpack(C.accent))
    return b
end

-- A square glass button with a picture on it (the close X, the settings gear).
function Widgets.IconButton(parent, size, texture, tint)
    local b = Widgets.GlassButton(parent, size, size, { square = true })
    b.icon = b:CreateTexture(nil, "OVERLAY")
    b.icon:SetSize(size - 8, size - 8)
    b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.icon:SetTexture(texture)
    if tint then b.icon:SetVertexColor(tint[1], tint[2], tint[3]) end
    return b
end

-- The mascot as a button: her face in a ring, the face and the ring's colour
-- following the game state (Skin.FACE, Skin.FACE_RING), a brighter ring on hover.
-- b:setState("ready" | "playing" | "won" | "lost").
Widgets.FACE_PRESS_MIN = 0.35    -- seconds she stays surprised after a quick click

function Widgets.FaceButton(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    local inner = size - 6
    b.face = b:CreateTexture(nil, "BACKGROUND")
    b.face:SetSize(inner, inner)
    b.face:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.face:SetTexture(T.face)
    b.ring = b:CreateTexture(nil, "OVERLAY")
    b.ring:SetAllPoints(b)
    b.ring:SetTexture(T.faceRing)
    b.glow = b:CreateTexture(nil, "HIGHLIGHT")
    b.glow:SetAllPoints(b)
    b.glow:SetTexture(T.faceRing)
    b.glow:SetBlendMode("ADD")
    b.glow:SetVertexColor(1, 1, 1, 0.9)

    function b.setState(self, state)
        self.stateFace = T[Skin.FACE[state] or "face"] or T.face
        -- A game that ends while a button is still down (a left+right chord fires on
        -- the first release) shows how it ended, not the surprised face (Codex, #49).
        if state == "won" or state == "lost" then self.pressed = false end
        if not self.pressed then self.face:SetTexture(self.stateFace) end
        local ring = Skin.FACE_RING[state] or Skin.FACE_RING.ready
        self.ring:SetVertexColor(ring[1], ring[2], ring[3])
        self.state = state
    end
    -- While a tile is held down (#10): her surprised face (#12). A click is held
    -- about a tenth of a second, too quick to see her (owner), so she stays
    -- surprised at least FACE_PRESS_MIN; `now` lets go at once (the window closing).
    -- A new press cancels a pending let-go; the game ending lets go itself (setState).
    local hold = 0
    function b.setPressed(self, on, now)
        hold = hold + 1
        if on then
            self.pressedAt = GetTime()
            if self.pressed then return end
            self.pressed = true
            self.face:SetTexture(T.facePressed)
            return
        end
        if not self.pressed then return end
        local function release()
            self.pressed = false
            self.face:SetTexture(self.stateFace or T.face)
        end
        local wait = Widgets.FACE_PRESS_MIN - (GetTime() - (self.pressedAt or 0))
        if now or wait <= 0 then release(); return end
        local mine = hold
        C_Timer.After(wait, function()
            if hold == mine and self.pressed then release() end
        end)
    end

    b:setState("ready")
    return b
end

-- A plain glass panel (a dropdown's list): the body and the rim, no behaviour. The glass body is
-- translucent (0.90), so it has a near-opaque backing under it, inside the same rounded mask: a list that
-- sits over the HUD and the tiles must not let them show through its entries (UI review, PR #31).
function Widgets.GlassPanel(parent)
    local p = CreateFrame("Frame", nil, parent)
    p.mask = Glass.Mask(p, "body_mask_small", 8)
    p.backing = p:CreateTexture(nil, "BACKGROUND", nil, -1)
    p.backing:SetAllPoints(p)
    p.backing:SetColorTexture(unpack(C.menuBacking))
    p.backing:AddMaskTexture(p.mask)
    p.fill = p:CreateTexture(nil, "BACKGROUND")
    p.fill:SetAllPoints(p)
    p.fill:SetTexture(T.uiFill)
    slice(p.fill)
    p.border = p:CreateTexture(nil, "BORDER")
    p.border:SetAllPoints(p)
    p.border:SetTexture(T.uiBorder)
    slice(p.border)
    p.border:SetVertexColor(unpack(C.accent))
    return p
end
