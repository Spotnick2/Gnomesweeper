-- Assets.lua: /gsweep assets. A contact sheet of every texture the skin names,
-- so each can be checked on the live client by eye, plus what the client can say
-- about them by itself (#6).
--
-- Entries come in kinds that are checked differently (plan review on #6):
--   media    our own files in Media/ (Tools/*.py): the tests check they exist and
--            are valid TGAs; in game only the eye can tell they draw
--   path     a client texture path: GetFileIDFromPath answers nil for one this
--            client doesn't have (porting guide, "Checking a texture exists")
--   fileID   a client file ID: getters echo even nonsense IDs (AltStable
--            measured this), so only the sheet proves it
-- What GetFileIDFromPath answers for a media path is recorded too: whether it
-- knows addon files is itself a measurement.
--
-- The results are kept in GnomesweeperDB.assetProbe, so a /reload writes them to
-- the SavedVariables file and they can be read from disk.

local ADDON = ...
Gnomesweeper = Gnomesweeper or {}
local GS = Gnomesweeper
local Assets = {}
GS.Assets = Assets

local Glass, Skin, Widgets = GS.Glass, GS.Skin, GS.Widgets
local C = Skin.COLORS

local SHEET_NAME = "GnomesweeperAssets"
local COLS, CELL_W, CELL_H, PICTURE, PAD, TOP = 6, 96, 100, 56, 16, 64

local sheet
local cells = {}

-- What a skin entry is.
function Assets.Kind(value)
    if type(value) == "number" then return "fileID" end
    if type(value) == "string" then
        if value:sub(1, #Glass.MEDIA) == Glass.MEDIA then return "media" end
        return "path"
    end
    return "unknown"
end

-- Every entry, sorted by key: its kind, and what GetFileIDFromPath says for a string.
function Assets.Survey()
    local keys = {}
    for k in pairs(Skin.TEXTURES) do keys[#keys + 1] = k end
    table.sort(keys)
    local out = {}
    for _, key in ipairs(keys) do
        local value = Skin.TEXTURES[key]
        local e = { key = key, value = value, kind = Assets.Kind(value) }
        if type(value) == "string" then
            local ok, id = pcall(GetFileIDFromPath, value)
            e.checked = ok
            e.fileID = ok and id or nil
        end
        out[#out + 1] = e
    end
    return out
end

-- The paths the client says it doesn't have. (Media and file IDs can't be judged this way.)
function Assets.Missing(entries)
    local missing = {}
    for _, e in ipairs(entries) do
        if e.kind == "path" and e.checked and e.fileID == nil then missing[#missing + 1] = e end
    end
    return missing
end

local function status(e)
    if e.kind == "path" then
        if not e.checked then return "path: check failed", C.boom end
        if e.fileID == nil then return "path: MISSING", C.boom end
        return "path: file " .. tostring(e.fileID), C.hint
    elseif e.kind == "media" then
        return "ours" .. (e.fileID and (" (file " .. tostring(e.fileID) .. ")") or ""), C.hint
    elseif e.kind == "fileID" then
        return "client id " .. tostring(e.value), C.hint
    end
    return "unknown kind", C.boom
end

local function build(entries)
    sheet = CreateFrame("Frame", SHEET_NAME, UIParent)
    sheet:SetFrameStrata("FULLSCREEN_DIALOG")
    sheet:SetClampedToScreen(true)
    sheet:SetMovable(true)
    sheet:EnableMouse(true)
    sheet:RegisterForDrag("LeftButton")
    sheet:SetScript("OnDragStart", function(self) self:StartMoving() end)
    sheet:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    sheet:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    sheet:Hide()
    local escapable = false
    for _, name in ipairs(UISpecialFrames) do if name == SHEET_NAME then escapable = true end end
    if not escapable then table.insert(UISpecialFrames, SHEET_NAME) end
    sheet.glass = Glass.Apply(sheet, "large")
    sheet.backing = sheet:CreateTexture(nil, "BACKGROUND", nil, -7)
    sheet.backing:SetAllPoints(sheet)
    sheet.backing:SetColorTexture(unpack(C.overlayBg))
    sheet.backing:AddMaskTexture(sheet.glass.mask)

    sheet.title = Glass.Font(sheet, 16, "LEFT")
    sheet.title:SetPoint("TOPLEFT", sheet, "TOPLEFT", PAD, -14)
    sheet.title:SetText(Skin.TITLE .. " textures")
    sheet.hint = Glass.Font(sheet, 11, "LEFT")
    sheet.hint:SetPoint("TOPLEFT", sheet.title, "BOTTOMLEFT", 0, -4)
    sheet.hint:SetTextColor(unpack(C.hint))
    sheet.hint:SetText("Each picture should draw. A green square or an empty cell is a texture the client doesn't have.")

    sheet.close = Widgets.IconButton(sheet, 22, Skin.TEXTURES.close, { 1, 0.9, 0.9 })
    sheet.close:SetFrameLevel(Glass.ContentLevel(sheet))
    sheet.close:SetPoint("TOPRIGHT", sheet, "TOPRIGHT", -10, -10)
    sheet.close:setAccent(unpack(C.closeAccent))
    sheet.close:SetScript("OnClick", function() sheet:Hide() end)

    for i, e in ipairs(entries) do
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        local cell = CreateFrame("Frame", nil, sheet)
        cell:SetFrameLevel(Glass.ContentLevel(sheet))
        cell:SetSize(CELL_W - 6, CELL_H - 6)
        cell:SetPoint("TOPLEFT", sheet, "TOPLEFT", PAD + col * CELL_W, -(TOP + row * CELL_H))
        cell.bg = cell:CreateTexture(nil, "BACKGROUND")
        cell.bg:SetSize(PICTURE + 8, PICTURE + 8)
        cell.bg:SetPoint("TOP", cell, "TOP", 0, 0)
        cell.bg:SetColorTexture(0.10, 0.12, 0.17, 1)
        cell.picture = cell:CreateTexture(nil, "ARTWORK")
        local aspect = Skin.ASPECT[e.key] or 1                   -- a wide texture keeps its shape
        cell.picture:SetSize(PICTURE, PICTURE / aspect)
        local crop = (e.key == "title" and Skin.TITLE_CROP) or (e.key == "laurels" and Skin.LAUREL_CROP)
        if crop then cell.picture:SetTexCoord(unpack(crop)) end  -- the part the window draws, at its shape
        cell.picture:SetPoint("CENTER", cell.bg, "CENTER", 0, 0)
        cell.picture:SetTexture(e.value)
        cell.name = Glass.Font(cell, 10, "CENTER")
        cell.name:SetPoint("TOP", cell.bg, "BOTTOM", 0, -3)
        cell.name:SetText(e.key)
        cell.state = Glass.Font(cell, 9, "CENTER")
        cell.state:SetPoint("TOP", cell.name, "BOTTOM", 0, -2)
        cells[i] = cell
    end
    local rows = math.ceil(#entries / COLS)
    sheet:SetSize(2 * PAD + COLS * CELL_W - 6, TOP + rows * CELL_H + 8)
end

local function save(entries)
    local version, build = GetBuildInfo()
    local probe = { build = tostring(version) .. "." .. tostring(build), entries = {} }
    for _, e in ipairs(entries) do
        probe.entries[e.key] = { kind = e.kind, value = tostring(e.value), fileID = e.fileID, checked = e.checked }
    end
    GnomesweeperDB.assetProbe = probe
end

-- /gsweep assets: show (or hide) the sheet, refresh what the client says, save it, report.
function Assets.Toggle()
    if sheet and sheet:IsShown() then sheet:Hide(); return end
    local entries = Assets.Survey()
    if not sheet then build(entries) end
    for i, e in ipairs(entries) do
        local text, color = status(e)
        cells[i].state:SetText(text)
        cells[i].state:SetTextColor(color[1], color[2], color[3])
    end
    save(entries)
    sheet:Show()

    local missing, names = Assets.Missing(entries), {}
    for _, e in ipairs(missing) do names[#names + 1] = e.key .. " (" .. tostring(e.value) .. ")" end
    print(string.format("|cff7fd4ffGnome|rsweeper: %d textures on the sheet. Client paths it doesn't have: %s.",
        #entries, #names > 0 and table.concat(names, ", ") or "none"))
    print("|cff7fd4ffGnome|rsweeper: our own files and client file IDs can only be checked by eye: look at the sheet. /reload saves the results.")
end

function Assets.IsShown() return sheet ~= nil and sheet:IsShown() end

Assets._test = {
    cells = cells,
    sheet = function() return sheet end,
}
