-- Compat.lua: Gnomesweeper.API, the only route to client APIs that moved or
-- may be absent. Empty for now: lift helpers from ..\GlassXp\Compat.lua
-- (Fail, Button, Window) when a file needs them, rather than rewriting them.

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local API = {}
Gnomesweeper.API = API

-- The client build the notes and stubs describe: the API dump the tests check
-- against (C:\Projects\References\forever-api-1.60.1.70205.md). 70205's
-- documented API is identical to 70170's (Compare-Dumps, 2026-10-02), and the
-- asset probe ran on it: every texture draws.
Gnomesweeper.MEASURED_ON_BUILD = "1.60.1.70205"
