local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Accessibility (12.1): reading aloud, the game's own flashing, and sharing your settings.
------------------------------------------------------------------------------------------

-- Read aloud -----------------------------------------------------------------------------
-- A key (or /fgui read) says what is under the mouse with the game's text-to-speech voice: the
-- tooltip if one is showing, otherwise the quest being read, otherwise the last whisper.
-- /fgui read tooltip | quest | whisper picks one.
local function Plain(text)
    if type(text) ~= "string" or Secret(text) then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|n", " ")
    text = text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    return text ~= "" and text or nil
end
local lastWhisper
do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", function(_, _, msg, sender)
        local text, who = Plain(msg), (type(sender) == "string" and not Secret(sender)) and sender:gsub("%-.*$", "") or nil
        if text then lastWhisper = (who and (who .. ": ") or "") .. text end
    end)
end
function ns.ReadSetLastWhisper(text) lastWhisper = text end      -- (for the tests)
-- What would be read: the text and which kind it was.
function ns:ReadText(what)
    what = (type(what) == "string" and what ~= "") and what:lower() or nil
    if (not what or what == "tooltip") and GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown() then
        local parts = {}
        local n = tonumber(GameTooltip.NumLines and GameTooltip:NumLines()) or 0
        for i = 1, math.min(n, 30) do
            for _, side in ipairs({ "Left", "Right" }) do
                local fs = _G["GameTooltipText" .. side .. i]
                local t = fs and fs.GetText and Plain(fs:GetText())
                if t then parts[#parts + 1] = t end
            end
        end
        if #parts > 0 then return table.concat(parts, ". "), "tooltip" end
    end
    if not what or what == "quest" then
        local parts = {}
        for _, name in ipairs({ "QuestInfoTitleHeader", "QuestInfoDescriptionText", "QuestInfoObjectivesText", "QuestProgressText",
                                "QuestInfoRewardText", "QuestDetailObjectiveText", "QuestTitleText", "QuestDescription" }) do
            local fs = _G[name]
            if type(fs) == "table" and fs.IsVisible and fs:IsVisible() and fs.GetText then
                local t = Plain(fs:GetText())
                if t then parts[#parts + 1] = t end
            end
        end
        if #parts > 0 then return table.concat(parts, ". "), "quest" end
    end
    if (not what or what == "whisper") and lastWhisper then return lastWhisper, "whisper" end
    return nil
end
function ns:ReadAloud(what)
    local text, kind = ns:ReadText(what)
    if not text then
        ns:Print("Nothing to read: point at something with a tooltip, open a quest, or wait for a whisper.")
        return false
    end
    if not ns:Speak(text) then
        ns:Print("This game client cannot read aloud (%s).", ns:Tr(ns.speakState or "no text-to-speech"))
        return false
    end
    ns.readLast = kind
    return kind
end

-- The game's own flashing ------------------------------------------------------------------
-- Safe flashing also stops the game's red flash at the screen's edge when your health is low,
-- where this client has that setting. Switching it off puts back what the game had.
function ns:ApplySafeFlash()
    local Get = (C_CVar and C_CVar.GetCVar) or GetCVar
    local Set = (C_CVar and C_CVar.SetCVar) or SetCVar
    if type(Get) ~= "function" or type(Set) ~= "function" then return false end
    local ok, now = pcall(Get, "doNotFlashLowHealthWarning")
    if not ok or now == nil then ns.safeFlashCVar = false; return false end
    ns.safeFlashCVar = true
    local store = type(ns.root) == "table" and ns.root or nil
    if ns.db.safeFlash then
        if store and store.lowHealthFlashWas == nil then store.lowHealthFlashWas = tostring(now) end
        if tostring(now) ~= "1" then pcall(Set, "doNotFlashLowHealthWarning", "1") end
    elseif store and store.lowHealthFlashWas ~= nil then
        pcall(Set, "doNotFlashLowHealthWarning", store.lowHealthFlashWas)
        store.lowHealthFlashWas = nil
    end
    return true
end
do
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_LOGIN")
    ev:SetScript("OnEvent", function() if ns.db then pcall(ns.ApplySafeFlash, ns) end end)
end

-- Sharing ----------------------------------------------------------------------------------
-- Your accessibility settings as one line of text, to keep or give to someone; pasting one back
-- sets them all. Only these settings travel: nothing else of the profile.
ns.ACCESS_KEYS = { "colorblind", "colorVision", "reduceMotion", "safeFlash", "calmMode", "captions", "textOutline", "textBands",
                   "targetOutline", "bigControls", "fontScale", "uiScale", "cursorRing", "tooltipCursor", "speakAlerts", "fontStyle", "theme" }
local KEEP_STYLE = { READABLE = true, DYSLEXIC = true }
local KEEP_THEME = { CONTRAST = true, FCONTRAST = true }
local HEAD = "FGUI-ACCESS:1;"
function ns:AccessExport()
    local parts = {}
    for _, k in ipairs(ns.ACCESS_KEYS) do
        local v = ns.db[k]
        if k == "fontStyle" and not KEEP_STYLE[v] then v = nil end           -- (lettering and theme travel only when they are the readable ones)
        if k == "theme" and not KEEP_THEME[v] then v = nil end
        if type(v) == "boolean" then parts[#parts + 1] = k .. "=" .. (v and "1" or "0")
        elseif type(v) == "number" then parts[#parts + 1] = k .. "=" .. tostring(math.floor(v + 0.5))
        elseif type(v) == "string" and v:match("^[%w_]+$") then parts[#parts + 1] = k .. "=" .. v end
    end
    return HEAD .. table.concat(parts, ";")
end
-- Read a shared line. Returns the settings it holds ({ key = value }), or nil and why not.
function ns:AccessParse(text)
    text = type(text) == "string" and text:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if text:sub(1, #HEAD) ~= HEAD then return nil, "That is not a line of accessibility settings." end
    local allowed = {}
    for _, k in ipairs(ns.ACCESS_KEYS) do allowed[k] = true end
    local out, n = {}, 0
    for k, v in text:sub(#HEAD + 1):gmatch("([%w_]+)=([%w_]+)") do
        if allowed[k] then
            local d = ns.defaults[k]
            if type(d) == "boolean" then out[k] = (v == "1")
            elseif type(d) == "number" then out[k] = tonumber(v)
            elseif k == "fontStyle" then out[k] = KEEP_STYLE[v] and v or nil
            elseif k == "theme" then out[k] = KEEP_THEME[v] and v or nil
            elseif k == "colorVision" then out[k] = (v == "redgreen" or v == "blueyellow" or v == "none") and v or nil
            elseif k == "textOutline" then out[k] = (v == "normal" or v == "thin" or v == "thick") and v or nil
            else out[k] = v end
            if out[k] ~= nil then n = n + 1 end
        end
    end
    if n == 0 then return nil, "That line holds no settings." end
    if out.fontScale then out.fontScale = math.max(70, math.min(150, out.fontScale)) end
    if out.uiScale then out.uiScale = math.max(50, math.min(150, out.uiScale)) end
    if out.targetOutline then out.targetOutline = math.max(0, math.min(8, out.targetOutline)) end
    return out, n
end
function ns:AccessImport(text)
    local set, n = ns:AccessParse(text)
    if not set then ns:Print(n); return false end
    for k, v in pairs(set) do ns.db[k] = v end
    if set.theme and ns.themes[set.theme] then ns.db.accent = ns.themes[set.theme].accent or ns.db.accent end
    if ns.Retheme then pcall(ns.Retheme, ns) end
    if ns.ApplyPixelScale then pcall(ns.ApplyPixelScale, ns) end
    pcall(ns.ApplySafeFlash, ns)
    ns:Print(ns:TrN(n, "%d accessibility setting taken. Some take effect after a /reload.", "%d accessibility settings taken. Some take effect after a /reload."), n)
    return n
end
-- A box to paste a line into.
local pasteBox
function ns:ShowAccessPaste()
    if not pasteBox then
        pasteBox = CreateFrame("Frame", "FantasyGlassUIAccessPaste", UIParent, ns.template)
        pasteBox:SetSize(460, 96)
        pasteBox:SetPoint("CENTER", 0, 140)
        pasteBox:SetFrameStrata("TOOLTIP")
        pasteBox:SetBackdrop(ns.BACKDROP)
        ns:Paint(pasteBox, "SetBackdropColor", "window", 0.97)
        ns:Paint(pasteBox, "SetBackdropBorderColor", "@border", 1)
        ns:Dress(pasteBox)
        local label = pasteBox:CreateFontString(nil, "OVERLAY")
        ns:Font(label, 11)
        label:SetPoint("TOPLEFT", 12, -10)
        label:SetWidth(436)
        label:SetJustifyH("LEFT")
        ns:Paint(label, "SetTextColor", "dim")
        label:SetText(ns:Tr("Paste a line of accessibility settings (Ctrl+V), then press Use them."))
        local eb = ns:CreateEditBox(pasteBox, 436, 24)
        eb:SetPoint("TOP", 0, -32)
        ns:Paint(eb, "SetBackdropBorderColor", "@accent", 1)
        eb:SetScript("OnEscapePressed", function() pasteBox:Hide() end)
        local use = ns:CreateButton(pasteBox, "Use them", 120, 22, function()
            if ns:AccessImport(eb:GetText()) then pasteBox:Hide() end
        end)
        use:SetPoint("BOTTOMRIGHT", -12, 10)
        eb:SetScript("OnEnterPressed", function() if ns:AccessImport(eb:GetText()) then pasteBox:Hide() end end)
        local close = ns:CreateButton(pasteBox, "Close", 80, 22, function() pasteBox:Hide() end)
        close:SetPoint("RIGHT", use, "LEFT", -8, 0)
        pasteBox.eb = eb
        tinsert(UISpecialFrames, "FantasyGlassUIAccessPaste")
    end
    pasteBox.eb:SetText("")
    pasteBox:Show()
    pasteBox.eb:SetFocus()
    return pasteBox
end
function ns:AccessCommand(text)
    local word, rest = (text or ""):match("^%s*(%S*)%s*(.-)%s*$")
    word = (word or ""):lower()
    if word == "export" or word == "copy" then
        ns:ShowCopyBox(ns:AccessExport(), ns:Tr("Your accessibility settings in one line: Ctrl+C to copy. /fgui access paste takes one back."))
    elseif word == "paste" or word == "import" then
        if rest ~= "" then ns:AccessImport(rest) else ns:ShowAccessPaste() end
    else
        ns:ToggleConfig("access")
    end
end

-- Readable lettering: one of the two styles made to be read easily, or back to the one chosen before.
function ns:ReadableFont()
    local s = ns.db and ns.db.fontStyle
    return (s == "READABLE" or s == "DYSLEXIC") and s or "off"
end
function ns:SetReadableFont(which)
    if which == "READABLE" or which == "DYSLEXIC" then
        if ns:ReadableFont() == "off" then ns.db.fontBefore = ns.db.fontStyle end
        ns.db.fontStyle = which
    elseif ns:ReadableFont() ~= "off" then
        ns.db.fontStyle = (ns.db.fontBefore and ns.fontStyles[ns.db.fontBefore]) and ns.db.fontBefore or "GLASS"
    end
    if ns.Retheme then pcall(ns.Retheme, ns) end
end
-- The kind of color vision chosen, as one choice: "off" (usual colors), or one of ns.COLOR_VISIONS.
function ns:ColorVisionChoice() return ns:ColorVision() or "off" end
function ns:SetColorVision(which)
    if which == "off" then ns.db.colorblind = false
    else ns.db.colorblind = true; ns.db.colorVision = which end
    if ns.Retheme then pcall(ns.Retheme, ns) end
end
