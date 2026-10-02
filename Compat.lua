-- Compat.lua: Gnomesweeper.API, the only route to client APIs that moved or
-- may be absent. Empty for now: lift helpers from ..\GlassXp\Compat.lua
-- (Fail, Button, Window) when a file needs them, rather than rewriting them.

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local API = {}
Gnomesweeper.API = API

-- The client build the notes and stubs describe. Nothing has been measured
-- for Gnomesweeper yet: this is the API dump it was written against
-- (C:\Projects\References\forever-api-1.60.1.70170.md).
Gnomesweeper.MEASURED_ON_BUILD = "1.60.1.70170"
