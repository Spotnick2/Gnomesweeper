-- Locales/enUS.lua: the localization (#36). Loads right after Compat.lua, before
-- anything with text in it.
--
-- Gnomesweeper.L is keyed by the English text itself: L["Field cleared!"]. A key
-- with no translation reads back as itself, so English needs no table, a missing
-- translation shows English (never nil, never an error), and the code stays
-- readable. Text built from parts is one format string (L["Won %d of %d"]), so a
-- language can reorder the words around the same arguments.
--
-- A locale file (Locales\frFR.lua) fills L when GetLocale() is its own. What stays
-- English: the slash commands and their arguments, the name, the measuring probes,
-- and every saved value (keys, never translated text).
--
-- Gnomesweeper.LOCALE holds what isn't a string: the decimal mark and the months.

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local GS = Gnomesweeper

GS.L = setmetatable({}, { __index = function(_, key) return key end })

GS.LOCALE = {
    decimal = ".",
    months = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" },
}

-- "3 Oct 2026", in the player's language (date's %b is always English).
function GS.FormatDate(t)
    local d = date("*t", t)
    return string.format("%d %s %d", d.day, GS.LOCALE.months[d.month] or "?", d.year)
end

-- A number with the language's decimal mark: GS.Decimal("%.1f", 0.8) is "0,8" in French.
function GS.Decimal(fmt, v)
    return (string.format(fmt, v):gsub("%.", GS.LOCALE.decimal))
end
