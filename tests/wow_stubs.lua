-- wow_stubs.lua: a minimal model of the Forever client, driven through WoW.
--
-- AN ALLOWLIST. Before stubbing a global, confirm it exists in
-- C:\Projects\References\forever-api-1.60.1.70170.md and copy its signature:
-- defining something Forever lacks lets a broken call pass. When the window
-- lands, grow this toward ..\GlassRaidFrames\tests\wow_stubs.lua (events and
-- widget methods validated against the dump) instead of inventing a new one.

WoW = { frames = {}, chat = {} }

function WoW.reset()
    WoW.frames, WoW.chat = {}, {}
    SlashCmdList = {}
end

local Frame = {}
Frame.__index = Frame
function Frame:RegisterEvent(e) self.events[e] = true; return true end
function Frame:UnregisterEvent(e) self.events[e] = nil end
function Frame:SetScript(k, fn) self.scripts[k] = fn end
function Frame:GetScript(k) return self.scripts[k] end

function CreateFrame(kind, name, parent)
    local f = setmetatable({ kind = kind, name = name, parent = parent, events = {}, scripts = {} }, Frame)
    WoW.frames[#WoW.frames + 1] = f
    if name then _G[name] = f end
    return f
end

function WoW.fire(event, ...)
    for _, f in ipairs(WoW.frames) do
        local fn = f.events[event] and f.scripts.OnEvent
        if fn then fn(f, event, ...) end
    end
end

-- Runs a slash command as the chat box would, matching SLASH_<KEY><n> aliases.
function WoW.slash(line)
    local cmd, rest = line:match("^(%S+)%s*(.*)$")
    for key, fn in pairs(SlashCmdList) do
        for i = 1, 10 do
            local alias = _G["SLASH_" .. key .. i]
            if not alias then break end
            if alias == cmd then return fn(rest) end
        end
    end
    error("unknown slash command " .. cmd)
end

function print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    WoW.chat[#WoW.chat + 1] = table.concat(parts, " ")
end

WoW.reset()
