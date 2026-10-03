-- Compat.lua: Gnomesweeper.API, the only route to client APIs that moved or
-- may be absent. Lift helpers from ..\GlassXp\Compat.lua (Fail, Button, Window)
-- and ..\AltStable\Compat.lua when a file needs them, rather than rewriting them.

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local API = {}
Gnomesweeper.API = API

-- The client build the notes and stubs describe: the API dump the tests check
-- against (C:\Projects\References\forever-api-1.60.1.70205.md). 70205's
-- documented API is identical to 70170's (Compare-Dumps, 2026-10-02), and the
-- asset probe ran on it: every texture draws.
Gnomesweeper.MEASURED_ON_BUILD = "1.60.1.70205"

-- CreateFrame with a template that may be missing on this client. A missing
-- template doesn't throw, it returns a bare frame (Priestly, FOREVER-PROBE), so
-- `proof` names a field the template would have made. Returns the frame and
-- whether the template really applied. Lifted from GlassUnitFrames' Compat.lua.
function API.SafeFrame(ftype, parent, template, proof)
    local ok, f = pcall(CreateFrame, ftype, nil, parent, template)
    if ok and f then return f, (proof == nil) or f[proof] ~= nil end
    return CreateFrame(ftype, nil, parent), false
end

-- The player's full name, with the surname every Forever character has.
-- Lifted from AltStable's API.PlayerFullName (measured there on 69977 and 70009):
-- through 69977 UnitName("player") returned "First Surname" as one string; on
-- 70009 the surname moved into the SECOND return, the slot documented as the
-- realm. A first return that already has a space is a whole name. "player"
-- only: for any other unit that second return really can be a realm.
function API.PlayerFullName()
    local name, second = UnitName("player")
    if type(name) ~= "string" or name == "" then return nil end
    if name:find(" ") then return name end
    if type(second) == "string" and second ~= "" then
        return name .. " " .. second
    end
    return name
end
