-- Skin.lua: every texture and colour the window uses, in one place, so an art
-- swap never touches logic.
--
-- Most of the art is ours and lives in Media/: baked tiles (Tools/make_tiles.py),
-- the UI (Tools/make_ui.py: flag, clock, close, arrow, glass buttons, the face's
-- ring, the effects), the mascot's ready face cut from the logo (Tools/png_to_tga.py)
-- and the generated art of #12 (her other expressions, the title lettering, the
-- laurels: Tools/export_art.py, Media/README.md). What is still the client's own art
-- is listed in docs/ASSETS.md: the bomb on the board and the settings gear.
--
-- A number is a file ID, a string is a texture path.

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local Skin = {}
Gnomesweeper.Skin = Skin

Skin.TITLE = "|cff7fd4ffGnome|rsweeper"

local MEDIA = Gnomesweeper.Glass.MEDIA

Skin.TEXTURES = {
    -- the mascot: the green-haired gnome from the logo; her face for each game state
    -- is Skin.FACE (the expressions, #12)
    face = MEDIA .. "face_mascot",
    faceRing = MEDIA .. "face_ring",
    -- icons
    flag = MEDIA .. "icon_flag",
    clock = MEDIA .. "icon_clock",
    trophy = MEDIA .. "icon_trophy",        -- the best times button
    music = MEDIA .. "icon_music",          -- the music button (white, tinted)
    mute = MEDIA .. "icon_mute",            -- the slash over it when the music is off
    sound = MEDIA .. "icon_sound",          -- the sounds button (#55), under the same slash when off
    close = MEDIA .. "icon_close",
    arrow = MEDIA .. "icon_arrow",
    burst = MEDIA .. "icon_burst",
    smoke = MEDIA .. "fx_smoke",            -- puffs rising from the tile that went off (#10)
    glow = MEDIA .. "fx_glow",              -- the soft glow behind the mascot on a win (#10)
    gear = "Interface\\WorldMap\\GEAR_64GREY",          -- the client's own; tinted
    mine = 133709,                          -- inv_misc_bomb_01: on the board WoW's own bomb read better than
                                            -- the generated mine (owner, #12); that one is staged
    facePlaying = MEDIA .. "face_playing",  -- the mascot's expressions (#12): focused, goggles down
    faceWon = MEDIA .. "face_won",          -- laughing
    faceLost = MEDIA .. "face_lost",        -- sooty, a cracked lens
    facePressed = MEDIA .. "face_pressed",  -- surprised, while a tile is held
    title = MEDIA .. "title",               -- the gold Gnomesweeper lettering
    laurels = MEDIA .. "laurels",           -- around "New personal best!"
    -- the glass controls (9-sliced, margin 8)
    uiFill = MEDIA .. "ui_fill",
    uiBorder = MEDIA .. "ui_border",
    uiGlow = MEDIA .. "ui_glow",
    -- the board's tiles
    tileCovered = MEDIA .. "tile_covered",
    tileRevealed = MEDIA .. "tile_revealed",
    tileExploded = MEDIA .. "tile_exploded",
    tileHover = MEDIA .. "tile_hover",
    -- the Modern theme's tiles (#14): generated, Tools/export_art.py
    tileModernCovered = MEDIA .. "tile_modern_covered",
    tileModernRevealed = MEDIA .. "tile_modern_revealed",
    tileModernExploded = MEDIA .. "tile_modern_exploded",
}

-- The board's themes (#14, owner): only the tiles change. Classic is ours from
-- Tools/make_tiles.py (the default); Modern the generated ice-blue glass. Both keep
-- WoW's bomb and our pennant, and the number colours read on both revealed tiles.
Skin.THEME_ORDER = { "classic", "modern" }
Skin.THEMES = {
    classic = { label = "Classic", covered = Skin.TEXTURES.tileCovered,
                revealed = Skin.TEXTURES.tileRevealed, exploded = Skin.TEXTURES.tileExploded },
    modern = { label = "Modern", covered = Skin.TEXTURES.tileModernCovered,
               revealed = Skin.TEXTURES.tileModernRevealed, exploded = Skin.TEXTURES.tileModernExploded },
}
function Skin.Theme(key) return Skin.THEMES[key] or Skin.THEMES.classic end

-- The mascot's face for each game state (the expressions, #12), and the colour of
-- her ring.
Skin.FACE = { ready = "face", playing = "facePlaying", won = "faceWon", lost = "faceLost" }
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
Skin.BURST = 26                       -- the starburst behind the bomb that ended the game
Skin.FLAG_ICON = 20                   -- the flag, a little taller: it has a pole
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
-- The title lettering's drawn part in its 512x128 texture (pixels 53..459 x 4..124).
Skin.TITLE_CROP = { 53 / 512, 459 / 512, 4 / 128, 124 / 128 }

-- Width over height of the textures that aren't square (the asset sheet keeps their
-- shape; the title's is its drawn part's).
-- The laurels' drawn part in their 512x128 texture (pixels 99..415 x 7..118): the
-- rest is transparent, and sizing the whole canvas would leave the branches far
-- smaller than they look on paper (Codex, #49).
Skin.LAUREL_CROP = { 99 / 512, 415 / 512, 7 / 128, 118 / 128 }
Skin.ASPECT = { title = (459 - 53) / (124 - 4), laurels = (415 - 99) / (118 - 7) }

Skin.COLORS = {
    -- The clock against your best (#46): WoW's countdown convention (yellow, then red).
    clockNormal = { 1, 1, 1 },
    clockNear = { 1, 0.82, 0 },       -- NORMAL_FONT_COLOR's yellow: closing in on your best
    clockOver = { 1, 0.13, 0.13 },    -- RED_FONT_COLOR: past it
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
