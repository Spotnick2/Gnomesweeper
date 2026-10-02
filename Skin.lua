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
    face  = 134164,                                     -- inv_misc_head_gnome_01
    flag  = 132485,                                     -- inv_bannerpvp_01: red (_02 is the blue Alliance banner, seen in game)
    clock = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    gear  = "Interface\\WorldMap\\GEAR_64GREY",
    arrow = "Interface\\Buttons\\Arrow-Down-Up",
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
}
