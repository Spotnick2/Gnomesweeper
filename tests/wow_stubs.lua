-- wow_stubs.lua: a model of the Forever client, driven through WoW.
--
-- AN ALLOWLIST, like the siblings' (..\GlassRaidFrames\tests\wow_stubs.lua):
--   * Globals are STRICT: reading one that isn't defined here is an error.
--     Before stubbing a global, confirm it is in
--     C:\Projects\References\forever-api-1.60.1.70205.md and copy its signature;
--     defining something Forever lacks lets a broken call pass.
--   * RegisterEvent throws on an event the client doesn't have (the list is
--     tests/events-1.60.1.70205.txt, generated from the dump by
--     Tools/make_events_fixture.py; test_toc checks they agree).
--   * Widgets answer ANY method as a recorded no-op, so a call to a method
--     Forever lacks would pass silently: tests/test_methods.lua checks every
--     "Type:Method" in WoW.methodsCalled against the dump's widget methods.
--
-- Fields that tests drive: WoW.now (GetTime), WoW.screen (UIParent's size),
-- frame._left / frame._top (what GetLeft / GetTop answer), frame._mouseOver.

local EVENTS_FIXTURE = "tests/events-1.60.1.70205.txt"

WoW = { frames = {}, chat = {}, methodsCalled = {}, now = 0, screen = { w = 1366, h = 768 } }

WoW.KNOWN_EVENTS = {}
do
    local f = assert(io.open(EVENTS_FIXTURE, "r"), EVENTS_FIXTURE .. " missing (python Tools/make_events_fixture.py)")
    for line in f:lines() do
        local name = line:match("^([A-Z][A-Z0-9_]+)%s*$")
        if name then WoW.KNOWN_EVENTS[name] = true end
    end
    f:close()
end

--------------------------------------------------------------------------------
-- Widgets
--------------------------------------------------------------------------------

local Methods = {}   -- the methods that do something; every other one is a recorded no-op

local widgetMT = {
    __index = function(w, k)
        if type(k) ~= "string" or not k:match("^%u") then return nil end   -- fields read as nil
        return function(self, ...)
            WoW.methodsCalled[self._type .. ":" .. k] = true
            local impl = Methods[k]
            if impl then return impl(self, ...) end
            return nil
        end
    end,
}

local function newWidget(wtype, parent, name)
    local w = setmetatable({
        _type = wtype, _parent = parent, _name = name, _shown = true, _points = {},
        _scripts = {}, _events = {}, _width = 0, _height = 0, _scale = 1,
        _level = parent and parent._level and (parent._level + 1) or 1,
        _strata = "MEDIUM", _text = "",
    }, widgetMT)
    if parent then
        parent._children = parent._children or {}
        table.insert(parent._children, w)
    end
    return w
end

function CreateFrame(ftype, name, parent, template)
    assert(ftype == "Frame" or ftype == "Button" or ftype == "StatusBar" or ftype == "ModelScene" or ftype == "CheckButton" or ftype == "EditBox",
        "CreateFrame: unexpected frame type " .. tostring(ftype))
    local w = newWidget(ftype, parent or UIParent, name)
    w._template = template
    -- What the client's templates make (the field each is proved by, as API.SafeFrame checks),
    -- unless the test says the template is missing (it then returns a bare frame, as the client does).
    if template and not WoW.missingTemplates[template] then
        if template == "UICheckButtonTemplate" or template == "UIRadioButtonTemplate" then
            w.text = newWidget("FontString", w)
        elseif template == "UIPanelButtonTemplate" then
            w.Text = newWidget("FontString", w)
        end
    end
    table.insert(WoW.frames, w)
    if name then rawset(_G, name, w) end
    return w
end

function Methods.CreateTexture(w, name) return newWidget("Texture", w, name) end
function Methods.CreateMaskTexture(w, name) return newWidget("MaskTexture", w, name) end
function Methods.CreateFontString(w, name) return newWidget("FontString", w, name) end

function Methods.Show(w)
    local was = w._shown
    w._shown = true
    if not was and w._scripts.OnShow then w._scripts.OnShow(w) end    -- only on a hidden > shown change
end
function Methods.Hide(w)
    local was = w._shown
    w._shown = false
    if was and w._scripts.OnHide then w._scripts.OnHide(w) end        -- only on a shown > hidden change
end
function Methods.SetShown(w, v) if v then Methods.Show(w) else Methods.Hide(w) end end
function Methods.IsShown(w) return w._shown end
function Methods.IsVisible(w)
    local p = w
    while p do
        if not p._shown then return false end
        p = p._parent
    end
    return true
end

function Methods.SetPoint(w, ...) table.insert(w._points, { ... }) end
function Methods.SetAllPoints(w, rel) w._points = { { "ALL", rel } } end
function Methods.ClearAllPoints(w) w._points = {} end
function Methods.GetNumPoints(w) return #w._points end
function Methods.GetPoint(w, i)
    local p = w._points[i or 1]
    if not p then return nil end
    return p[1], p[2], p[3], p[4], p[5]
end

function Methods.SetSize(w, x, y) w._width, w._height = x, y end
function Methods.SetWidth(w, x) w._width = x end
function Methods.SetHeight(w, y) w._height = y end
function Methods.GetWidth(w) return w._width end
function Methods.GetHeight(w) return w._height end

-- The scale chain, so a test can catch the "compared in the wrong space" class
-- of mistake (porting guide: GetCenter is in the frame's OWN space).
function Methods.SetScale(w, s) w._scale = s end
function Methods.GetScale(w) return w._scale end
function Methods.GetEffectiveScale(w)
    local s, p = 1, w
    while p do s = s * (p._scale or 1); p = p._parent end
    return s
end

function Methods.SetFrameLevel(w, l) w._level = l end
function Methods.GetFrameLevel(w) return w._level end
function Methods.SetFrameStrata(w, s) w._strata = s end
function Methods.GetFrameStrata(w) return w._strata end
function Methods.SetParent(w, p) w._parent = p end
function Methods.GetParent(w) return w._parent end
function Methods.GetName(w) return w._name end

function Methods.SetScript(w, name, fn) w._scripts[name] = fn end
function Methods.GetScript(w, name) return w._scripts[name] end
function Methods.HookScript(w, name, fn)
    local old = w._scripts[name]
    w._scripts[name] = function(...) if old then old(...) end; fn(...) end
end
function Methods.RegisterEvent(w, e)
    if not WoW.KNOWN_EVENTS[e] then error("Attempt to register unknown event \"" .. tostring(e) .. "\"", 2) end
    w._events[e] = true
    return true
end
function Methods.UnregisterEvent(w, e) w._events[e] = nil end

function Methods.SetText(w, t)
    w._text = t
    if w._type == "GameTooltip" then w._lines = {} end     -- a new tooltip starts with its title
end
function Methods.AddLine(w, text) w._lines = w._lines or {}; w._lines[#w._lines + 1] = text end
function Methods.GetText(w) return w._text end
function Methods.SetTexture(w, t) w._texture = t end
function Methods.SetChecked(w, v) w._checked = v and true or false end
-- An edit box's selection: HighlightText() selects all, (0, 0) none.
function Methods.HighlightText(w, a, b) w._selected = not (a == 0 and b == 0) end
function Methods.GetChecked(w) return w._checked or false end
-- A button's state textures: Set* makes one, Get* returns it (so its tex coords can be set).
for _, part in ipairs({ "Normal", "Pushed", "Highlight", "Checked" }) do
    Methods["Set" .. part .. "Texture"] = function(w, t)
        local tex = newWidget("Texture", w)
        tex._texture = t
        w["_" .. part] = tex
    end
    Methods["Get" .. part .. "Texture"] = function(w) return w["_" .. part] end
end
function Methods.SetColorTexture(w, ...) w._texture = nil; w._color = { ... } end
function Methods.SetAlpha(w, a) w._alpha = a end
function Methods.SetTextureSliceMargins(w, ...) w._slice = { ... } end
function Methods.SetTexCoord(w, ...) w._texCoord = { ... } end
function Methods.SetBlendMode(w, m) w._blend = m end
function Methods.SetDesaturated(w, v) w._desaturated = v end
function Methods.GetAlpha(w) return w._alpha or 1 end
function Methods.SetVertexColor(w, ...) w._vertex = { ... } end
function Methods.SetTextColor(w, ...) w._textColor = { ... } end
function Methods.SetMovable(w, v) w._movable = v end
function Methods.SetClampedToScreen(w, v) w._clamped = v end
function Methods.EnableMouse(w, v) w._mouse = v end
function Methods.IsMovable(w) return w._movable == true end
function Methods.StartMoving(w) w._moving = true end
function Methods.StopMovingOrSizing(w) w._moving = false end
function Methods.GetLeft(w) return w._left end
function Methods.GetTop(w) return w._top end
function Methods.IsMouseOver(w) return w._mouseOver == true end

--------------------------------------------------------------------------------
-- Globals
--------------------------------------------------------------------------------

function WoW.fire(event, ...)
    for _, f in ipairs(WoW.frames) do
        local fn = f._events[event] and f._scripts.OnEvent
        if fn then fn(f, event, ...) end
    end
end

-- One rendered frame: every VISIBLE frame's OnUpdate runs, as the client does.
function WoW.tick(dt)
    for _, f in ipairs(WoW.frames) do
        local fn = f._scripts.OnUpdate
        if fn and Methods.IsVisible(f) then fn(f, dt or 0.016) end
    end
end

-- A player's new game waits SHUFFLE_LEAD (1 s) and then waves in (1 s, #43):
-- render frames until both are done.
function WoW.settle()
    for _ = 1, 140 do WoW.tick(0.02) end
end

-- Runs a slash command as the chat box would, matching SLASH_<KEY><n> aliases.
function WoW.slash(line)
    local cmd, rest = line:match("^(%S+)%s*(.*)$")
    for key, fn in pairs(SlashCmdList) do
        for i = 1, 10 do
            local alias = rawget(_G, "SLASH_" .. key .. i)
            if not alias then break end
            if alias == cmd then return fn(rest) end
        end
    end
    error("unknown slash command " .. cmd)
end

function WoW.reset()
    WoW.frames, WoW.chat = {}, {}
    WoW.now = 0
    WoW.mouseDown = false
    WoW.fileIDs = {}
    WoW.sounds, WoW.willPlay, WoW.timers = {}, {}, {}
    WoW.music, WoW.musicStops, WoW.inCombat = nil, 0, false
    WoW.playerSex = 2
    WoW.ldb, WoW.ldbi = nil, nil                -- made on first use (LibStub, below)
    WoW.missingTemplates = {}
    WoW.settings = { canvas = {}, addons = {}, subs = {} }
    WoW.metadata = { Version = "@project-version@" }
    -- Blizzard's Settings window (HIGH strata), hidden until opened.
    SettingsPanel = newWidget("Frame", UIParent, "SettingsPanel")
    SettingsPanel._strata = "HIGH"
    SettingsPanel._shown = false
    WoW.epoch = 1790000000
    WoW.playerName, WoW.playerSurname, WoW.realm = "Fizzle", "Sprocketwhistle", "Forever"
    WoW.screen = { w = 1366, h = 768 }
    SlashCmdList = {}
    UISpecialFrames = {}
    UIParent = newWidget("Frame", nil, "UIParent")
    UIParent._width, UIParent._height = WoW.screen.w, WoW.screen.h
    GameTooltip = newWidget("GameTooltip", UIParent, "GameTooltip")
end

-- The screen is UIParent's size, in UIParent units (the unit the addon's
-- fit maths works in): a UI-scale or resolution change moves this number.
function WoW.setScreen(w, h)
    WoW.screen = { w = w, h = h }
    UIParent._width, UIParent._height = w, h
end

function print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    WoW.chat[#WoW.chat + 1] = table.concat(parts, " ")
end

function GetTime() return WoW.now end
-- The calendar clock (a global in the client; the dump's _G walk lists it).
function time() return WoW.epoch end
function date(fmt, t) return os.date(fmt, t) end
-- The player, on 70009+: the surname comes back in the second return.
function UnitName(unit) if unit == "player" then return WoW.playerName, WoW.playerSurname end return nil end
function GetRealmName() return WoW.realm end
-- Sounds: every PlaySound is recorded in WoW.sounds ({ kit, channel }); it answers
-- WoW.willPlay[kit] (default true), as the client's willPlay.
function PlaySound(kit, channel)
    WoW.sounds[#WoW.sounds + 1] = { kit = kit, channel = channel }
    local will = WoW.willPlay[kit]
    if will == nil then will = true end
    return will, will and #WoW.sounds or nil
end
-- Music: WoW.music is the file playing (nil when none), WoW.musicStops counts StopMusic.
function PlayMusic(file) WoW.music = file end
function StopMusic() WoW.music = nil; WoW.musicStops = WoW.musicStops + 1 end
function UnitAffectingCombat(unit) return unit == "player" and WoW.inCombat or false end
-- 1 unknown, 2 male, 3 female (WoW.playerSex, default male).
function UnitSex(unit) return unit == "player" and WoW.playerSex or nil end
-- Timers run when WoW.advance moves the clock past them, in order.
C_Timer = {
    After = function(seconds, fn)
        WoW.timers[#WoW.timers + 1] = { at = WoW.now + seconds, fn = fn, seq = #WoW.timers }
    end,
}
function WoW.advance(seconds)
    local target = WoW.now + seconds
    while true do
        local best, bi
        for i, t in ipairs(WoW.timers) do
            if t.at <= target and (not best or t.at < best.at or (t.at == best.at and t.seq < best.seq)) then best, bi = t, i end
        end
        if not best then break end
        table.remove(WoW.timers, bi)
        WoW.now = math.max(WoW.now, best.at)
        best.fn()
    end
    WoW.now = target
end
C_AddOns = { GetAddOnMetadata = function(name, key) return WoW.metadata[key] end }

-- LibStub with fake LibDataBroker-1.1 and LibDBIcon-1.0 (the real Libs\ are not
-- loaded in tests; GlassMiniMapBar's way). The fakes record what they are given:
-- WoW.ldb.objects, WoW.ldbi.registered / .buttons, and Show/Hide on the button.
LibStub = setmetatable({}, { __call = function(_, major)
    if major == "LibDataBroker-1.1" then WoW.ldb = WoW.ldb or WoW.newLDB(); return WoW.ldb end
    if major == "LibDBIcon-1.0" then WoW.ldbi = WoW.ldbi or WoW.newLDBI(); return WoW.ldbi end
    error("LibStub: no stub for " .. tostring(major))
end })
function WoW.newLDB()
    local lib = { objects = {} }
    function lib:NewDataObject(name, obj) self.objects[name] = obj; return obj end
    return lib
end
function WoW.newLDBI()
    local lib = { registered = {}, buttons = {}, registrations = 0 }
    function lib:Register(name, obj, db)
        self.registrations = self.registrations + 1
        local b = newWidget("Button", UIParent, "LibDBIcon10_" .. name)
        b._scripts.OnClick = function(self, mouse) obj.OnClick(self, mouse) end
        b.dataObject, b.db = obj, db
        if db.hide then b._shown = false end
        self.registered[name], self.buttons[name] = db, b
    end
    -- As the real one (LibDBIcon-1.0 MINOR 56): Show/Hide only show or hide the
    -- button (Show re-anchors it on the ring); neither touches the saved table.
    function lib:Show(name) self.buttons[name]:Show(); self.buttons[name]._repositioned = true end
    function lib:Hide(name) self.buttons[name]:Hide() end
    function lib:GetMinimapButton(name) return self.buttons[name] end
    return lib
end
-- Retail's Settings framework: Options > AddOns. Recorded in WoW.settings.
Settings = {
    RegisterCanvasLayoutCategory = function(frame, name)
        local cat = { frame = frame, name = name, GetID = function() return "cat:" .. name end }
        WoW.settings.canvas[#WoW.settings.canvas + 1] = cat
        return cat
    end,
    RegisterAddOnCategory = function(cat) WoW.settings.addons[#WoW.settings.addons + 1] = cat end,
    OpenToCategory = function(id) WoW.settings.opened = id; SettingsPanel:Show() end,
    RegisterCanvasLayoutSubcategory = function(parent, frame, name)
        local cat = { parent = parent, frame = frame, name = name }
        WoW.settings.subs[#WoW.settings.subs + 1] = cat
        return cat
    end,
}
-- The client's file table: WoW.fileIDs[path] = id; anything else answers nil, as for a path it lacks.
function GetFileIDFromPath(path) return WoW.fileIDs[path] end
function GetBuildInfo() return "1.60.1", "70205", "Oct  2 2026", 16001 end
function IsMouseButtonDown(button) return WoW.mouseDown == true end
function debugprofilestop() return os.clock() * 1000 end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
Enum = { UITextureSliceMode = { Stretched = 0, Tiled = 1 } }

WoW.reset()

-- Strict globals: any read of a global not defined above is an error, except
-- the addon's own, which are legitimately nil before their first assignment.
local allowNil = { Gnomesweeper = true, GnomesweeperDB = true }
setmetatable(_G, { __index = function(_, k)
    if allowNil[k] then return nil end
    error("read of undefined global '" .. tostring(k) .. "' (not stubbed: is it in the API dump?)", 2)
end })
