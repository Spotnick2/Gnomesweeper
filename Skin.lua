-- Skin.lua: every texture and colour the window uses, in one place, so an art
-- swap never touches logic.
--
-- Most of the art is ours and lives in Media/: baked tiles (Tools/make_tiles.py),
-- the UI (Tools/make_ui.py: flag, clock, close, arrow, glass buttons, the face's
-- ring, sparkles and soot) and the mascot's face, cut from the logo
-- (Tools/png_to_tga.py, docs/ART.md). What is still the client's own art is
-- listed in docs/ASSETS.md: the bomb and the settings gear.
--
-- A number is a file ID, a string is a texture path.

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local Skin = {}
Gnomesweeper.Skin = Skin

Skin.TITLE = "|cff7fd4ffGnome|rsweeper"

local MEDIA = Gnomesweeper.Glass.MEDIA

Skin.TEXTURES = {
    -- the mascot: the green-haired gnome from the logo (one face; the state shows in
    -- the ring and the overlays until the real expressions exist, #12)
    face = MEDIA .. "face_mascot",
    faceRing = MEDIA .. "face_ring",
    faceSparkle = MEDIA .. "face_sparkle",
    faceSoot = MEDIA .. "face_soot",
    -- icons
    flag = MEDIA .. "icon_flag",
    clock = MEDIA .. "icon_clock",
    trophy = MEDIA .. "icon_trophy",        -- the best times button
    music = MEDIA .. "icon_music",          -- the music button (white, tinted)
    mute = MEDIA .. "icon_mute",            -- the slash over it when the music is off
    close = MEDIA .. "icon_close",
    arrow = MEDIA .. "icon_arrow",
    burst = MEDIA .. "icon_burst",
    smoke = MEDIA .. "fx_smoke",            -- puffs rising from the tile that went off (#10)
    glow = MEDIA .. "fx_glow",              -- the soft glow behind the mascot on a win (#10)
    gear = "Interface\\WorldMap\\GEAR_64GREY",          -- the client's own; tinted
    mine = 133709,                                      -- inv_misc_bomb_01: the classic black bomb (art needed, #13)
    -- the glass controls (9-sliced, margin 8)
    uiFill = MEDIA .. "ui_fill",
    uiBorder = MEDIA .. "ui_border",
    uiGlow = MEDIA .. "ui_glow",
    -- the board's tiles
    tileCovered = MEDIA .. "tile_covered",
    tileRevealed = MEDIA .. "tile_revealed",
    tileExploded = MEDIA .. "tile_exploded",
    tileHover = MEDIA .. "tile_hover",
}

-- What shows over the mascot's face, and the colour of its ring, per game state.
Skin.FACE_OVERLAY = { won = "faceSparkle", lost = "faceSoot" }
Skin.FACE_RING = {
    ready   = { 0.15, 0.70, 0.99 },
    playing = { 0.15, 0.70, 0.99 },
    won     = { 1.00, 0.77, 0.38 },
    lost    = { 1.00, 0.35, 0.30 },
}

-- The difficulties take WoW's item-quality colours. Legendary is held back for a
-- much harder level some day (#18).
Skin.RARITY = {
    uncommon  = { 0.12, 1.00, 0.00 },     -- #1eff00
    rare      = { 0.00, 0.44, 0.87 },     -- #0070dd
    epic      = { 0.64, 0.21, 0.93 },     -- #a335ee
    legendary = { 1.00, 0.50, 0.00 },     -- #ff8000
}
Skin.DIFFICULTY_QUALITY = { beginner = "uncommon", intermediate = "rare", expert = "epic" }

function Skin.DifficultyColor(key)
    return Skin.RARITY[Skin.DIFFICULTY_QUALITY[key]] or Skin.COLORS.accent
end

Skin.TILE_ICON = 18                   -- the bomb on a 24-unit tile
Skin.FLAG_ICON = 20                   -- the flag, a little taller: it has a pole
Skin.BURST = 26                       -- the starburst behind the bomb that ended the game
Skin.TILE_FONT = 15                   -- the numbers

-- 1-8 on a dark tile: the classic colours, lightened to read on glass.
Skin.NUMBER_COLORS = {
    { 0.35, 0.62, 1.00 },   -- 1 blue
    { 0.35, 0.88, 0.40 },   -- 2 green
    { 1.00, 0.35, 0.35 },   -- 3 red
    { 0.62, 0.50, 1.00 },   -- 4 violet (classic navy is invisible here)
    { 1.00, 0.60, 0.25 },   -- 5 orange (classic maroon)
    { 0.25, 0.88, 0.88 },   -- 6 teal
    { 0.92, 0.92, 0.92 },   -- 7 white (classic black)
    { 0.65, 0.65, 0.70 },   -- 8 grey
}

-- WoW's own icons carry a border: crop it off. (Ours are drawn without one.)
Skin.ICON_CROP = { 0.07, 0.93, 0.07, 0.93 }

Skin.COLORS = {
    smoke = { 0.80, 0.80, 0.84 },     -- the wipe's smoke, over the dark board
    musicOn = { 0.82, 0.92, 1 },      -- the note when the music plays
    musicOff = { 0.50, 0.55, 0.62 },  -- greyed under its red slash
    gold         = { 0.98, 0.77, 0.38 },       -- the logo's lettering, #fbc560
    hint         = { 0.72, 0.76, 0.85 },
    tagline      = { 0.78, 0.87, 1 },
    accent       = { 0.45, 0.80, 1.00 },       -- a glass control's rim unless it says otherwise
    closeAccent  = { 0.95, 0.42, 0.38 },
    glassHover   = { 0.45, 0.85, 1.00, 0.30 },
    panelBacking = { 0.02, 0.04, 0.09, 0.42 }, -- darkens the window so the scenery doesn't compete
    menuBacking  = { 0.02, 0.04, 0.09, 0.97 }, -- the HUD must not show through the difficulty list
    hudBg        = { 0, 0, 0, 0.35 },
    gridBg       = { 0.03, 0.06, 0.12, 0.72 },
    menuText     = { 0.62, 0.68, 0.80 },
    wrongFlag    = { 1, 0.15, 0.15 },          -- the X over a (greyed) flag that wasn't on a mine
    question     = { 0.98, 0.77, 0.38 },
    overlayBg    = { 0.03, 0.06, 0.13, 0.94 },
    winRim       = { 1, 0.82, 0.30 },          -- the cleared overlay's gold rim
    lossRim      = { 1, 0.35, 0.30 },
    boom         = { 1, 0.42, 0.36 },          -- "Boom. Full wipe."
}
