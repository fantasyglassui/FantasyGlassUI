local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Accessibility (12.1): reading aloud, the game's own flashing, and sharing your settings.
------------------------------------------------------------------------------------------

-- Read aloud -----------------------------------------------------------------------------
-- A key (or /fgui read) says what is under the mouse with the game's text-to-speech voice: the
-- tooltip if one is showing, otherwise the quest being read, otherwise the last whisper.
-- /fgui read tooltip | quest | whisper picks one.
-- (the ready-check tick a finished objective ends in, Guide.lua: said as a word, since a texture is not read)
local TICK = "|T[Ii]nterface\\[Rr]aid[Ff]rame\\[Rr]eady[Cc]heck%-[Rr]eady[^|]*|t"
local function Plain(text)
    if type(text) ~= "string" or Secret(text) then return nil end
    if text:find(TICK) then
        local word = tostring(ns:Tr("done")):gsub("%%", "%%%%")
        text = text:gsub(TICK, " " .. word)
    end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|n", " ")
    text = text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    return text ~= "" and text or nil
end
local lastWhisper, whisperNew                -- (whisperNew: a whisper not yet read aloud)
local Join                                  -- (parts joined into sentences: below)
do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", function(_, _, msg, sender)
        local text, who = Plain(msg), (type(sender) == "string" and not Secret(sender)) and sender:gsub("%-.*$", "") or nil
        if text then lastWhisper, whisperNew = (who and (who .. ": ") or "") .. text, true end
    end)
end
function ns.ReadSetLastWhisper(text) lastWhisper, whisperNew = text, text ~= nil end      -- (for the tests)
-- Has the list window in front the keyboard (the game-window keys are on and it is the window they work)?
local function ListFocused(w)
    if not (w and ns.db and ns.db.windowKeys and ns.WindowKeysFront) then return false end
    local ok, f = pcall(ns.WindowKeysFront)
    return ok and f == w
end
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
    -- the quest guide's panel (while the mouse is on it, or asked for by name), then the list window in front
    if (what == "guide" or (not what and ns.GuidePanelUnderMouse and ns.GuidePanelUnderMouse())) and ns.GuideReadText then
        local t = Plain(ns.GuideReadText())
        if t then return t, "guide" end
    end
    if not what or what == "list" then
        local w = ns.FrontList and ns:FrontList()
        -- (the key reads a whisper not yet read first, as it always did: the list only when none is waiting, or when it has the keyboard)
        if not what and w and lastWhisper and whisperNew and not ListFocused(w) then return lastWhisper, "whisper" end
        if w then
            local parts = {}
            parts[1] = Plain(w.titleText)
            for _, line in ipairs(type(w.lines) == "table" and w.lines or {}) do
                if type(line) == "table" then
                    local l, r = Plain(line.left or line[1]), (not line.hasSecret) and Plain(line.right or line[2]) or nil
                    if l and r then parts[#parts + 1] = l .. ": " .. r elseif l or r then parts[#parts + 1] = l or r end
                end
                if #parts >= 40 then break end
            end
            if #parts > 0 then return Join(parts), "list" end
        end
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
    if kind == "whisper" then whisperNew = false end          -- (read: the list in front is read next time)
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
                   "targetOutline", "bigControls", "fontScale", "uiScale", "cursorRing", "tooltipCursor", "speakAlerts", "fontStyle", "theme",
                   "readDialog", "readHover", "windowKeys", "windowKeysSay", "stillSky", "tooltipDelay" }
local KEEP_STYLE = { READABLE = true, DYSLEXIC = true }
local KEEP_THEME = { CONTRAST = true, FCONTRAST = true, C_CONTRAST = true }
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
    for _, k in ipairs(ns.ACCESS_KEYS) do allowed[k] = not (ns.NotShared and ns.NotShared(k)) end
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
    if out.tooltipDelay then out.tooltipDelay = math.max(0, math.min(2000, out.tooltipDelay)) end
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

------------------------------------------------------------------------------------------
-- 12.2: more for everyone.
------------------------------------------------------------------------------------------

-- Reading on its own ------------------------------------------------------------------------
-- "Read talk and quests aloud": what an NPC says, a quest's text and a book or letter are read as their
-- window opens, and the reading stops when it closes. "Read what I point at": a tooltip is read once the
-- mouse rests on something. (The game's own screen narrator works only before you log in.)
Join = function(parts)
    local out = ""
    for _, t in ipairs(parts) do
        t = Plain(t)
        if t then
            if out == "" then out = t
            elseif out:find("[%.!%?:]$") then out = out .. " " .. t      -- (a sentence that ends already)
            else out = out .. ". " .. t end
        end
    end
    return out ~= "" and out or nil
end
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    return ok and v or nil
end
-- The text of the window that just opened, by the event that opened it.
function ns:DialogText(event)
    if event == "GOSSIP_SHOW" then
        local parts = { Call(C_GossipInfo.GetText) }
        local okO, options = pcall(C_GossipInfo.GetOptions)
        local names = {}
        if okO and type(options) == "table" then
            for _, o in ipairs(options) do local n = type(o) == "table" and Plain(o.name); if n then names[#names + 1] = n end end
        end
        for _, get in ipairs({ C_GossipInfo.GetAvailableQuests, C_GossipInfo.GetActiveQuests }) do
            local okQ, quests = pcall(get)
            if okQ and type(quests) == "table" then
                for _, q in ipairs(quests) do local n = type(q) == "table" and Plain(q.title); if n then names[#names + 1] = n end end
            end
        end
        if #names > 0 then parts[#parts + 1] = ns:Tr("Choices") .. ": " .. table.concat(names, ", ") end
        return Join(parts)
    elseif event == "QUEST_DETAIL" then
        return Join({ Call(GetTitleText), Call(GetQuestText), Call(GetObjectiveText) })
    elseif event == "QUEST_PROGRESS" then
        return Join({ Call(GetTitleText), Call(GetProgressText) })
    elseif event == "QUEST_COMPLETE" then
        return Join({ Call(GetTitleText), Call(GetRewardText) })
    elseif event == "QUEST_GREETING" then
        return Join({ Call(GetGreetingText) })
    elseif event == "ITEM_TEXT_READY" then
        return Join({ Call(ItemTextGetItem), Call(ItemTextGetText) })
    end
    return nil
end
function ns:StopReading()
    pcall(C_VoiceChat.StopSpeakingText)
end
do
    local opens = { "GOSSIP_SHOW", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING", "ITEM_TEXT_READY" }
    local closes = { GOSSIP_CLOSED = true, QUEST_FINISHED = true, ITEM_TEXT_CLOSED = true }
    local ev = CreateFrame("Frame")
    for _, e in ipairs(opens) do pcall(ev.RegisterEvent, ev, e) end
    for e in pairs(closes) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Read aloud", function(_, event)
        if not (ns.db and ns.db.readDialog) then return end
        if closes[event] then ns:StopReading(); return end
        local text = ns:DialogText(event)
        if not text then return end
        ns:StopReading()                                              -- (the page before stops: this one is read)
        if ns:Speak(text) then ns.readLast = event end
    end))
end
-- What the mouse rests on: a tooltip that has stayed the same for half a second is read, once.
do
    local heard, since, last = nil, 0, nil
    function ns.HoverReadTick(now)
        if not (ns.db and ns.db.readHover) then heard, last = nil, nil; return nil end
        local text = GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown() and ns:ReadText("tooltip")
        if not text then heard, last = nil, nil; return nil end
        now = now or GetTime()
        if text ~= last then last, since = text, now; return nil end           -- (still settling)
        if text == heard or now - since < 0.5 then return nil end
        heard = text
        ns:StopReading()
        if ns:Speak(text) then ns.readLast = "hover"; return text end
        return nil
    end
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function()
        if ns.Every then ns:Every(0.2, "Read what I point at", function() ns.HoverReadTick() end) end
    end)
end

-- Tooltip delay -----------------------------------------------------------------------------
-- The mouse must rest a moment before a tooltip shows, so sweeping across the screen does not
-- throw up one after another. (The tooltip is there all along, unseen until the time is up.)
do
    local shownAt
    function ns.TooltipDelayTick(now)
        local tip = GameTooltip
        local wait = (tonumber(ns.db and ns.db.tooltipDelay) or 0) / 1000
        if not (tip and tip.IsShown and tip:IsShown()) then shownAt = nil; return nil end
        if wait <= 0 then
            if shownAt then tip:SetAlpha(1); shownAt = nil end
            return nil
        end
        now = now or GetTime()
        if not shownAt then shownAt = now; tip:SetAlpha(0); return false end
        if now - shownAt >= wait then tip:SetAlpha(1); return true end
        return false
    end
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function()
        if GameTooltip and GameTooltip.HookScript then
            GameTooltip:HookScript("OnShow", function(self)
                shownAt = nil
                if (tonumber(ns.db and ns.db.tooltipDelay) or 0) > 0 then shownAt = GetTime(); self:SetAlpha(0) end
            end)
            GameTooltip:HookScript("OnHide", function(self) shownAt = nil; self:SetAlpha(1) end)
        end
        if ns.Every then ns:Every(0.05, "Tooltip delay", function() ns.TooltipDelayTick() end) end
    end)
end

-- Keys for one hand ---------------------------------------------------------------------------
-- Moving, jumping, the first action buttons and targeting, all within reach of one hand: the left
-- hand round W, A, S and D, or the right hand on the number pad. The keys these take are noted
-- first, so "Put my keys back" returns every one of them as it was.
ns.KEY_PRESETS = {
    left = { MOVEFORWARD = "W", MOVEBACKWARD = "S", TURNLEFT = "A", TURNRIGHT = "D", STRAFELEFT = "Q", STRAFERIGHT = "E",
             JUMP = "SPACE", TOGGLEAUTORUN = "R", TARGETNEARESTENEMY = "TAB", INTERACTTARGET = "F",
             ACTIONBUTTON1 = "1", ACTIONBUTTON2 = "2", ACTIONBUTTON3 = "3", ACTIONBUTTON4 = "4", ACTIONBUTTON5 = "5",
             ACTIONBUTTON6 = "G", ACTIONBUTTON7 = "T", ACTIONBUTTON8 = "Z", ACTIONBUTTON9 = "X", ACTIONBUTTON10 = "C",
             ACTIONBUTTON11 = "V", ACTIONBUTTON12 = "B" },
    numpad = { MOVEFORWARD = "NUMPAD8", MOVEBACKWARD = "NUMPAD5", TURNLEFT = "NUMPAD4", TURNRIGHT = "NUMPAD6",
               STRAFELEFT = "NUMPAD7", STRAFERIGHT = "NUMPAD9", JUMP = "NUMPAD0", TARGETNEARESTENEMY = "NUMPADPLUS",
               INTERACTTARGET = "NUMPADDECIMAL", ACTIONBUTTON1 = "NUMPAD1", ACTIONBUTTON2 = "NUMPAD2", ACTIONBUTTON3 = "NUMPAD3",
               ACTIONBUTTON4 = "NUMPADDIVIDE", ACTIONBUTTON5 = "NUMPADMULTIPLY", ACTIONBUTTON6 = "NUMPADMINUS" },
}
local function KeysWere()
    if type(ns.root) ~= "table" then return nil end
    if type(ns.root.keysWere) ~= "table" then ns.root.keysWere = {} end
    return ns.root.keysWere
end
local function SaveKeys()
    local ok, set = pcall(GetCurrentBindingSet)
    pcall(SaveBindings, (ok and type(set) == "number") and set or 1)
end
-- Bind one preset. Returns how many keys it set, or false and why.
function ns:UseKeyPreset(which)
    local preset = ns.KEY_PRESETS[which]
    if not preset then return false, "no such key set" end
    if InCombatLockdown() then ns:Print("Keys can't be changed during a fight: try again after it."); return false, "fight" end
    local was = KeysWere()
    if not was then return false, "not ready" end
    local n = 0
    for action, key in pairs(preset) do
        if was[key] == nil then                                        -- (note each key once: the first time it is taken)
            local okA, before = pcall(GetBindingAction, key)
            was[key] = (okA and type(before) == "string") and before or ""
        end
        if pcall(SetBinding, key, action) then n = n + 1 end
    end
    SaveKeys()
    ns.db.keyPreset = which
    ns:Print("%d keys set for one hand. \"Put my keys back\" returns them as they were.", n)
    return n
end
function ns:RestoreKeys()
    if InCombatLockdown() then ns:Print("Keys can't be changed during a fight: try again after it."); return false end
    local was = KeysWere()
    if not was or next(was) == nil then ns:Print("Your keys are as they were."); return 0 end
    local n = 0
    for key, action in pairs(was) do
        if action == "" then pcall(SetBinding, key) else pcall(SetBinding, key, action) end
        n = n + 1
        was[key] = nil
    end
    SaveKeys()
    ns.db.keyPreset = nil
    ns:Print("%d keys put back as they were.", n)
    return n
end

-- High contrast: the high-contrast theme of the family you use ------------------------------------
ns.CONTRAST_THEMES = { GLASS = "CONTRAST", FANTASY = "FCONTRAST", CELESTIAL = "C_CONTRAST" }
function ns:UseHighContrast()
    local t = ns.themes[ns.db.theme]
    local family = (t and t.style) or "FANTASY"
    local key = ns.CONTRAST_THEMES[family] or "FCONTRAST"
    ns.db.theme = key
    ns.db.accent = ns.themes[key].accent or ns.db.accent
    if ns.NoteHomeTheme then pcall(ns.NoteHomeTheme, ns) end
    if ns.Retheme then pcall(ns.Retheme, ns) end
    return key
end
