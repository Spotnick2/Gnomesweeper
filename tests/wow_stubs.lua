-- wow_stubs.lua: Gnomesweeper's model of the Forever client, on WowTestKit's core.
--
-- The mechanics are the kit's (tests/kit.lua loads it at the commit and build
-- tests/kit.pin names; its README is the reference): strict globals, events
-- checked against the build, widgets that answer only the build's methods and
-- record every call (Kit.checkMethods in test_methods checks each Type:Method
-- pair), timers and the clock, print with its stray-"|" check, hooksecurefunc.
--
-- What stays here: the client APIs Gnomesweeper reads (each confirmed in
-- C:\Projects\WoW\References\Forever\api\, signature copied: defining something
-- Forever lacks lets a broken call pass), the templates it uses, the widget
-- behaviour the tests read that the core doesn't model, and the fakes of the
-- vendored libraries.
--
-- Fields that tests drive: WoW.now (GetTime), WoW.screen (UIParent's size),
-- frame._left / frame._top (what GetLeft / GetTop answer), frame._mouseOver.

dofile("tests/kit.lua")
local Methods = WoW.Methods
local newWidget = WoW.newWidget

--------------------------------------------------------------------------------
-- Templates (what the client's make: the field each is proved by, as
-- API.SafeFrame checks), unless the test says the template is missing (it
-- then returns a bare frame, as the client does).
--------------------------------------------------------------------------------

-- A template's font string, with the font its template inherits (so SetText
-- works on it, as on the client: a font string without one refuses).
local function templateText(w, font)
    local fs = WoW.addRegion(w, newWidget("FontString", w))
    fs._fontTemplate = font
    return fs
end
-- Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml (wow-ui-source forever):
-- the check box's "$parentText" (GameFontNormalSmall) is parentKey Text, aliased
-- to .text (UICheckButtonFontString_SetParentKeyAlias); the radio's is .text.
WoW.templates.UICheckButtonTemplate = function(w, t)
    if WoW.missingTemplates[t] then return end
    w.Text = templateText(w, "GameFontNormalSmall")
    w.text = w.Text
end
WoW.templates.UIRadioButtonTemplate = function(w, t)
    if WoW.missingTemplates[t] then return end
    w.text = templateText(w, "GameFontNormalSmall")
end
-- Blizzard_SharedXML/SecureUIPanelTemplates.xml (UIPanelButtonNoTooltipTemplate):
-- the button's text, in GameFontNormal.
WoW.templates.UIPanelButtonTemplate = function(w, t)
    if WoW.missingTemplates[t] then return end
    w.Text = templateText(w, "GameFontNormal")
end
-- The core's (its ScrollBar and buttons), unless the test says it's missing.
do
    local scrollFrame = WoW.templates.UIPanelScrollFrameTemplate
    WoW.templates.UIPanelScrollFrameTemplate = function(w, t)
        if WoW.missingTemplates[t] then return end
        scrollFrame(w, t)
    end
end

--------------------------------------------------------------------------------
-- Widget behaviour the tests read, which the core doesn't model
--------------------------------------------------------------------------------

-- Animations (#10): a group records its animations (ag._anims, each with its
-- _animType) and how often it played (_plays); the delays and looping the
-- tests read are kept.
function Methods.CreateAnimationGroup(w)
    local ag = newWidget("AnimationGroup", w)
    ag._anims, ag._playing = {}, false
    return ag
end
function Methods.CreateAnimation(ag, atype)
    local a = newWidget(atype or "Animation", ag)
    a._animType = atype
    table.insert(ag._anims, a)
    return a
end
function Methods.Play(ag) ag._playing = true; ag._plays = (ag._plays or 0) + 1 end
function Methods.SetLooping(ag, l) ag._looping = l end
function Methods.SetStartDelay(a, d) a._delay = d end
function Methods.SetEndDelay(a, d) a._endDelay = d end

-- Model scenes (#20): an actor is a "ModelSceneActor" (test_methods checks its calls
-- against the dump's FrameAPIModelSceneFrameActor API). A display's bounding box arrives
-- once the model "streams in": WoW.modelBoxes[display] (or ["unit:player"]) is the six
-- numbers Forever returns, nil while loading or for a model this client lacks.
-- WoW.modelSetFails[display] makes SetModelByCreatureDisplayID answer false. With
-- WoW.modelStale, an actor switched to a model not yet in keeps answering with the
-- PREVIOUS model's box (what the real client may do) until ClearModel is called.
function Methods.CreateActor(scene)
    local a = newWidget("ModelSceneActor", scene)
    scene._actors = scene._actors or {}
    table.insert(scene._actors, a)
    return a
end
function Methods.SetModelByCreatureDisplayID(a, id, composite)
    if a._model ~= nil then a._stale = a._model end
    a._model, a._composite = id, composite
    return not WoW.modelSetFails[id]
end
function Methods.SetModelByUnit(a, unit)
    if a._model ~= nil then a._stale = a._model end
    a._model = "unit:" .. tostring(unit)
    return true
end
function Methods.ClearModel(a) a._model, a._stale = nil, nil; a._clears = (a._clears or 0) + 1 end
function Methods.GetActiveBoundingBox(a)
    local b = a._model ~= nil and WoW.modelBoxes[a._model]
    if not b and WoW.modelStale and a._stale ~= nil then b = WoW.modelBoxes[a._stale] end
    if not b then return nil end
    return b[1], b[2], b[3], b[4], b[5], b[6]
end
function Methods.IsLoaded(a) return a._model ~= nil and WoW.modelBoxes[a._model] ~= nil end
function Methods.SetAnimation(a, id) a._anim = id end
function Methods.SetParticleOverrideScale(a, s) a._particles = s end
function Methods.SetCameraPosition(scene, x, y, z) scene._camera = { x, y, z } end
function Methods.SetUnit(m, unit) m._unit = unit end
function Methods.SetJustifyH(w, j) w._justifyH = j end

function Methods.GetNumPoints(w) return #w._points end

-- An edit box's selection: HighlightText() selects all, (0, 0) none.
function Methods.HighlightText(w, a, b) w._selected = not (a == 0 and b == 0) end
function Methods.SetTextureSliceMargins(w, ...) w._slice = { ... } end
function Methods.SetTexCoord(w, ...) w._texCoord = { ... } end
-- WowTestKit #104: the core keeps no clamp state (its #89 drag state covers the rest).
function Methods.SetClampedToScreen(w, v) w._clamped = v end
function Methods.IsClampedToScreen(w) return w._clamped == true end

--------------------------------------------------------------------------------
-- Driving
--------------------------------------------------------------------------------

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

-- The screen is UIParent's size, in UIParent units (the unit the addon's
-- fit maths works in): a UI-scale or resolution change moves this number.
function WoW.setScreen(w, h)
    WoW.screen = { w = w, h = h }
    UIParent._width, UIParent._height = w, h
end

-- Gnomesweeper's state, reset with the core's (loadAddon resets for each session).
table.insert(WoW.onReset, function()
    WoW.guild, WoW.addonSent, WoW.prefixes, WoW.guildLoading, WoW.addonResult = nil, {}, {}, nil, nil
    WoW.sendResults, WoW.reportedErrors = {}, {}
    WoW.addonSender = "Fizzle Sprocketwhistle"     -- as measured (70205): the full name, no realm
    WoW.now = 0
    WoW.mouseDown = false
    WoW.fileIDs = {}
    -- The end panel's models (#21: the Walking Bomb 6977, Tally 3124) are absent unless a
    -- test brings them (modelSetFails[id] = nil, and a box): the panel is then drawn as
    -- before, as on a client without them.
    WoW.modelBoxes, WoW.modelSetFails = {}, { [6977] = true, [3124] = true }
    WoW.modelStale = nil
    WoW.sounds, WoW.willPlay = {}, {}
    WoW.music, WoW.musicStops, WoW.inCombat = nil, 0, false
    WoW.playerSex = 2
    WoW.ldb, WoW.ldbi = nil, nil                -- made on first use (LibStub, below)
    WoW.missingTemplates = {}
    WoW.settings = { canvas = {}, addons = {}, subs = {} }
    WoW.metadata = { Version = "@project-version@" }
    -- Blizzard's Settings window (HIGH strata), hidden until opened.
    SettingsPanel = newWidget("Frame", UIParent, "SettingsPanel")
    SettingsPanel._strata = "HIGH"
    SettingsPanel._shown, SettingsPanel._vis = false, false
    WoW.epoch = 1790000000
    WoW.playerName, WoW.playerSurname, WoW.realm = "Fizzle", "Sprocketwhistle", "Forever"
    WoW.setScreen(1366, 768)
    SlashCmdList = {}
    UISpecialFrames = {}
    GameTooltip = newWidget("GameTooltip", UIParent, "GameTooltip")
end)

--------------------------------------------------------------------------------
-- Client APIs
--------------------------------------------------------------------------------

-- The calendar clock (a global in the client; the dump's _G walk lists it).
function time() return WoW.epoch end
function date(fmt, t) return os.date(fmt, t) end
-- The player, on 70009+: the surname comes back in the second return.
function UnitName(unit) if unit == "player" then return WoW.playerName, WoW.playerSurname end return nil end
function GetRealmName() return WoW.realm end
function GetNormalizedRealmName() return (WoW.realm:gsub("%s", "")) end
-- Measured (70205): the second answer is the surname, as UnitName's, not a realm.
function UnitFullName(unit) if unit == "player" then return WoW.playerName, WoW.playerSurname end return nil end

-- Guilds and addon messages (the social plan, #15): WoW.guild is the guild's name (nil:
-- none). A GUILD message is recorded in WoW.addonSent and, as the server does, echoed
-- to its sender as CHAT_MSG_ADDON, from WoW.addonSender. Measured (70205, phase 0): the
-- sender is the full name with the surname and no realm; Ambiguate changes nothing.
function IsInGuild() return WoW.guild ~= nil end
-- WoW.guildLoading: in a guild, but the client doesn't know which yet (just after login).
function GetGuildInfo(unit)
    if unit == "player" and WoW.guild and not WoW.guildLoading then return WoW.guild, "Member", 3, nil end
    return nil
end
function Ambiguate(fullName, context) return fullName end      -- measured a no-op on a guild sender (70205)
C_ChatInfo = {
    RegisterAddonMessagePrefix = function(prefix)
        WoW.prefixes[prefix] = true
        return 0
    end,
    SendAddonMessage = function(prefix, message, chatType, target)
        -- A refused send: the next queued result (WoW.sendResults, AltStable's), else WoW.addonResult.
        local result = table.remove(WoW.sendResults, 1) or WoW.addonResult or 0
        if result ~= 0 then return result end
        table.insert(WoW.addonSent, { prefix = prefix, message = message, chatType = chatType, target = target })
        if chatType == "GUILD" and WoW.guild then
            WoW.fire("CHAT_MSG_ADDON", prefix, message, "GUILD", WoW.addonSender, WoW.addonSender, 0, 0, "", 0)
        end
        return 0
    end,
}
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
C_AddOns = { GetAddOnMetadata = function(name, key) return WoW.metadata[key] end }

-- Fake LibDataBroker-1.1 and LibDBIcon-1.0 (the vendored Libs\ are not loaded
-- in tests; GlassMiniMapBar's way). The fakes record what they are given:
-- WoW.ldb.objects, WoW.ldbi.registered / .buttons, and Show/Hide on the button.
-- LibStub itself is the REAL one the embedded LibGlass-1.0 brings (the harness
-- loads it fresh with the library, #71); WoW.fakeLibs then answers these two
-- names with the fakes, and every other name from the real LibStub.
local function fakeLib(major)
    if major == "LibDataBroker-1.1" then WoW.ldb = WoW.ldb or WoW.newLDB(); return WoW.ldb end
    if major == "LibDBIcon-1.0" then WoW.ldbi = WoW.ldbi or WoW.newLDBI(); return WoW.ldbi end
end
function WoW.fakeLibs(stub)
    setmetatable(stub, { __call = function(self, major, silent)
        return fakeLib(major) or self:GetLibrary(major, silent)
    end })
end
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
        if db.hide then b._shown, b._vis = false, false end
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
function GetBuildInfo() return "1.60.1", "71037", "Nov 18 2026", 16001 end
-- WoW.mouseDown: true (every button down) or one button's name ("RightButton").
function IsMouseButtonDown(button) return WoW.mouseDown == true or WoW.mouseDown == button end
function debugprofilestop() return os.clock() * 1000 end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
Enum = {
    UITextureSliceMode = { Stretched = 0, Tiled = 1 },
    -- What C_ChatInfo.SendAddonMessage returns on this client (AltStable measured; the dump's type).
    SendAddonMessageResult = { Success = 0, InvalidPrefix = 1, InvalidMessage = 2, AddonMessageThrottle = 3,
        InvalidChatType = 4, NotInGroup = 5, TargetRequired = 6, InvalidChannel = 7, ChannelThrottle = 8,
        GeneralError = 9, NotInGuild = 10, AddOnMessageLockdown = 11, TargetOffline = 12 },
}

-- What the REAL ChatThrottleLib (v32) needs, as AltStable's stubs model it (tests/test_ctl.lua
-- loads it): the client's error handler and securecallfunction, table.wipe, the frame rate
-- (the kit's xpcall passes extra arguments, as WoW's does, WowTestKit #91), and the send
-- functions it hooks. Nothing else loads the library: Libs\ is skipped in the other tests.
WoW.reportedErrors = {}
function geterrorhandler() return function(e) table.insert(WoW.reportedErrors, e) end end
function securecallfunction(fn, ...)
    local r = { pcall(fn, ...) }
    if not r[1] then geterrorhandler()(r[2]); return end
    return unpack(r, 2)
end
function table.wipe(t) for k in pairs(t) do t[k] = nil end return t end
wipe = table.wipe
function GetFramerate() return 60 end
C_ChatInfo.SendChatMessage = function() end
C_ChatInfo.SendAddonMessageLogged = function() return 0 end
C_BattleNet = { SendGameData = function() return 0 end }

WoW.reset()

-- Strict globals: any read of a global not defined above is an error, except
-- the addon's own, which are legitimately nil before their first assignment.
-- LibStub: read by its own loader before it exists (the harness clears it for
-- each load, so the embedded LibGlass-1.0 starts fresh). ChatThrottleLib: read
-- before it exists, by the library itself and by Social (rawget).
Kit.strict({ Gnomesweeper = true, GnomesweeperDB = true, LibStub = true, ChatThrottleLib = true,
    GnomesweeperProbeDB = true })   -- the probe's (#87): read at its ADDON_LOADED, before it exists
