-- Skin.lua: every texture and colour the window uses, in one place, so an art
-- swap never touches logic. These are PLACEHOLDERS from the client's own art
-- (docs/ASSETS.md); none is verified on Forever yet (#6 checks them all), and
-- the generated gnome art replaces them in M3.
--
-- A number is a file ID, a string is a texture path.

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local Skin = {}
Gnomesweeper.Skin = Skin

Skin.TITLE = "|cff7fd4ffGnome|rsweeper"

Skin.TEXTURES = {
    logo  = 236446,                                     -- achievement_character_gnome_male
    flag  = 132485,                                     -- inv_bannerpvp_01: red (_02 is the blue Alliance banner, seen in game)
    clock = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    gear  = "Interface\\WorldMap\\GEAR_64GREY",
    arrow = "Interface\\Buttons\\Arrow-Down-Up",
}

-- The face in the HUD, one per game state. Placeholders from gnome heads until
-- the generated set (#12); chosen by looking at them (docs/ASSETS.md).
Skin.FACES = {
    ready   = 236446,       -- achievement_character_gnome_male: goggles, a smile (the logo too)
    playing = 134164,       -- inv_misc_head_gnome_01: serious
    won     = 236445,       -- achievement_character_gnome_female: beaming
    lost    = 133709,       -- inv_misc_bomb_01: the bomb; the state reads at a glance at 40 px
}

-- The board's own art: baked textures from Tools/make_tiles.py, shared by
-- every tile (never a glass frame per tile), and the icons a tile can show.
local MEDIA = Gnomesweeper.Glass.MEDIA
Skin.TEXTURES.tileCovered  = MEDIA .. "tile_covered"
Skin.TEXTURES.tileRevealed = MEDIA .. "tile_revealed"
Skin.TEXTURES.tileExploded = MEDIA .. "tile_exploded"
Skin.TEXTURES.tileHover    = MEDIA .. "tile_hover"
Skin.TEXTURES.mine = 133709           -- inv_misc_bomb_01: the classic black bomb, legible at 18 px

Skin.TILE_ICON = 18                   -- the flag and the bomb on a 24-unit tile
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

-- Icon textures carry a border: crop it off.
Skin.ICON_CROP = { 0.07, 0.93, 0.07, 0.93 }

Skin.COLORS = {
    gold        = { 1, 0.82, 0 },
    hint        = { 0.72, 0.76, 0.85 },
    tagline     = { 0.78, 0.87, 1 },
    hudBg       = { 0, 0, 0, 0.35 },
    gridBg      = { 0.03, 0.06, 0.12, 0.6 },
    button      = { 0.16, 0.28, 0.5, 0.75 },
    buttonHover = { 0.25, 0.4, 0.7, 0.35 },
    menuBg      = { 0.04, 0.07, 0.15, 0.97 },
    wrongFlag   = { 1, 0.15, 0.15 },           -- the X over a (greyed) flag that wasn't on a mine
    question    = { 1, 0.82, 0 },
    overlayBg   = { 0.03, 0.06, 0.13, 0.94 },
    winRim      = { 1, 0.82, 0.30 },           -- the cleared overlay's gold rim
    lossRim     = { 1, 0.35, 0.30 },
    boom        = { 1, 0.42, 0.36 },           -- "Boom. Full wipe."
}
