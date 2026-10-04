-- Glass.lua: this addon's instance of the "liquid glass" material.
--
-- The material lives in the embedded library LibGlass-1.0
-- (Libs\LibGlass-1.0, from github.com/Spotnick2/LibGlass through .pkgmeta
-- externals; the TOC loads it first). Its contract, write-up
-- (docs/GLASS-MATERIAL.md there) and textures are there: material changes are
-- LibGlass PRs, not edits here.
--
-- An instance, not the library itself: STYLE, the live setters and the font
-- registry are Gnomesweeper's own, so nothing here touches another glass
-- addon's surfaces. Every call site keeps the dot-call shape (Glass.Apply,
-- Glass.Font, Glass.Mask, ...). Glass.MEDIA is the library's folder: our own
-- art is under Skin.MEDIA.

Gnomesweeper = Gnomesweeper or {}
Gnomesweeper.Glass = LibStub("LibGlass-1.0"):New()
