local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Talent set buttons: a small "1" and "2" at the top of the character window; one click changes
-- talent set. Also /fgui spec (the other one) and /fgui spec 2.
------------------------------------------------------------------------------------------
local function TalentSetCount()
    for _, probe in ipairs({ _G.GetNumTalentGroups, C_SpecializationInfo and C_SpecializationInfo.GetNumSpecGroups }) do
        if type(probe) == "function" then
            local ok, n = pcall(probe)
            if ok and type(n) == "number" and not Secret(n) and n >= 1 and n < 10 then return n end
        end
    end
    return 1
end
ns.TalentSetCount = TalentSetCount
function ns:SwitchTalentSet(n)
    local count = TalentSetCount()
    local now = ns:TalentSet()
    if count < 2 then ns:Print("This character has only one talent set."); return false end
    n = tonumber(n) or (now % count + 1)
    if n < 1 or n > count or n == now then return false end
    if InCombatLockdown() then ns:Print("Not in combat."); return false end
    local set = (C_SpecializationInfo and C_SpecializationInfo.SetActiveSpecGroup) or _G.SetActiveTalentGroup or _G.SetActiveSpecGroup
    if type(set) ~= "function" then ns:Print("This game client does not let add-ons change talent set."); return false end
    return pcall(set, n) and n or false
end
ns:NewModule("specButtons", function()
    local holder
    local buttons = {}
    local function Refresh(win)
        local count = TalentSetCount()
        if count < 2 then ns.specButtonsState = "this character has only one talent set"; if holder then holder:Hide() end return 0 end
        if not holder then
            holder = CreateFrame("Frame", "FantasyGlassUISpecButtons", win)
            holder:SetSize(22 * count + 4, 20)
            holder:SetPoint("BOTTOMRIGHT", win, "TOPRIGHT", -30, 2)
        end
        local now = ns:TalentSet()
        for i = 1, count do
            local b = buttons[i]
            if not b then
                b = ns:CreateButton(holder, tostring(i), 20, 18, function() ns:SwitchTalentSet(i) end)
                b:SetPoint("LEFT", (i - 1) * 22, 0)
                buttons[i] = b
            end
            if b.text and b.text.SetTextColor then if i == now then ns:Paint(b.text, "SetTextColor", "@accent") else b.text:SetTextColor(0.7, 0.7, 0.7) end end
        end
        holder:Show()
        ns.specButtonsState = format("%d talent sets, on the character window", count)
        return count
    end
    ns.specButtonsTest = { Refresh = Refresh, buttons = buttons }
    ns:Every(0.5, "Talent set buttons", function()
        local win = _G.CharacterFrame
        if type(win) == "table" and ns:Usable(win) and win.IsShown and ns.Yes(win:IsShown()) and not ns:Locked(win) then pcall(Refresh, win) end
    end)
end)

------------------------------------------------------------------------------------------
-- Missing enchants: a red "E" on a slot of the character window whose item has no enchant, and a
-- "G" where a gem socket is empty.
------------------------------------------------------------------------------------------
ns.ENCHANT_SLOTS = { Back = 15, Chest = 5, Wrist = 9, Hands = 10, Feet = 8, MainHand = 16 }
-- What an item link says: its enchant (0 = none) and how many gems are in it.
function ns.LinkEnchant(link)
    if type(link) ~= "string" then return nil end
    local body = link:match("item:([%-%d:]+)")
    if not body then return nil end
    local fields = {}
    for field in (body .. ":"):gmatch("([^:]*):") do fields[#fields + 1] = tonumber(field) or 0 end
    local gems = 0
    for i = 3, 6 do if (fields[i] or 0) > 0 then gems = gems + 1 end end
    return fields[2] or 0, gems
end
-- The letters to show for an item: "E" (no enchant where one goes), "G" (an empty socket), both or "".
function ns.EnchantMarks(link, enchantable, sockets)
    local enchant, gems = ns.LinkEnchant(link)
    if not enchant then return "" end
    return ((enchantable and enchant == 0) and "E" or "") .. (((tonumber(sockets) or 0) > gems) and "G" or "")
end
ns:NewModule("enchantCheck", function()
    local marks = {}
    local function Refresh()
        local missing = 0
        for _, name in ipairs({ "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand" }) do
            local slot = _G["Character" .. name .. "Slot"]
            if type(slot) == "table" and slot.GetID then
                local mark = marks[name]
                if not mark then
                    mark = ns:NewText(slot, 10, "LEFT")
                    mark:SetPoint("BOTTOMLEFT", 2, 2)
                    mark:SetTextColor(1, 0.25, 0.25)
                    if mark.SetShadowOffset then mark:SetShadowOffset(1, -1); mark:SetShadowColor(0, 0, 0, 1) end
                    marks[name] = mark
                end
                local link = GetInventoryItemLink and GetInventoryItemLink("player", slot:GetID())
                local text = ""
                if type(link) == "string" and not Secret(link) then
                    local sockets = 0
                    local Sockets = C_Item and C_Item.GetItemNumSockets
                    if type(Sockets) == "function" then local ok, n = pcall(Sockets, link); if ok and type(n) == "number" then sockets = n end end
                    text = ns.EnchantMarks(link, ns.ENCHANT_SLOTS[name] ~= nil, sockets)
                end
                if text ~= "" then missing = missing + 1 end
                mark:SetText(text)
            end
        end
        ns.enchantState = format("on; %d pieces marked", missing)
        return missing
    end
    ns.enchantTest = { Refresh = Refresh, marks = marks }
    local dirty, wasShown = true, false
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "PLAYER_EQUIPMENT_CHANGED")
    ev:SetScript("OnEvent", function() dirty = true end)
    ns:Every(0.5, "Missing enchants", function()
        local win = _G.CharacterFrame
        if not (type(win) == "table" and win.IsShown and ns.Yes(win:IsShown())) then wasShown = false; return end
        if dirty or not wasShown then dirty = false; pcall(Refresh) end
        wasShown = true
    end)
end)

------------------------------------------------------------------------------------------
-- More pieces for the info bar (right-click the bar to tick them): hearthstone cooldown, a currency
-- you choose (/fgui currency, then shift-click it or give its number), time to the daily reset, and
-- the master volume (/fgui volume 60).
------------------------------------------------------------------------------------------
function ns.ShortTime(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    if seconds >= 3600 then return format("%dh %dm", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)) end
    return format("%dm", math.ceil(seconds / 60))
end
function ns.InfoPiece(piece)
    if piece == "hearth" then
        local Get = (C_Container and C_Container.GetItemCooldown) or (C_Item and C_Item.GetItemCooldown) or GetItemCooldown
        if type(Get) ~= "function" then return nil end
        local ok, start, duration = pcall(Get, 6948)
        if not ok or type(start) ~= "number" or type(duration) ~= "number" or Secret(start) or Secret(duration) then return nil end
        local left = (duration > 0) and (start + duration - GetTime()) or 0
        if left <= 0 then return "|cff33ff66" .. ns:Tr("hearth ready") .. "|r" end
        return format("|cffffffff%s|r %s", ns.ShortTime(left), ns:Tr("hearth"))
    elseif piece == "reset" then
        local get = C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset
        if type(get) ~= "function" then return nil end
        local ok, left = pcall(get)
        if not ok or type(left) ~= "number" or Secret(left) then return nil end
        return format("%s |cffffffff%s|r", ns:Tr("reset in"), ns.ShortTime(left))
    elseif piece == "currency" then
        local id = tonumber(ns.db.infobarCurrency)
        local get = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo
        if not id or type(get) ~= "function" then return nil end
        local ok, info = pcall(get, id)
        if not ok or type(info) ~= "table" or type(info.quantity) ~= "number" or Secret(info.quantity) then return nil end
        return format("|cffffffff%d|r %s", info.quantity, tostring(info.name or ""))
    elseif piece == "volume" then
        local Get = (C_CVar and C_CVar.GetCVar) or GetCVar
        local ok, v = pcall(Get, "Sound_MasterVolume")
        v = ok and tonumber(v)
        if not v then return nil end
        return format("|cffffffff%d%%|r %s", math.floor(v * 100 + 0.5), ns:Tr("volume"))
    end
end
function ns:VolumeCommand(text)
    local n = tonumber((ns.Trim(text):gsub("%%", "")))
    local Set = (C_CVar and C_CVar.SetCVar) or SetCVar
    if n and type(Set) == "function" then pcall(Set, "Sound_MasterVolume", tostring(math.max(0, math.min(100, n)) / 100)) end
    local piece = ns.InfoPiece("volume")
    if piece then ns:PrintRaw("|cff33ccffFantasy Glass UI|r: " .. piece) end
    if ns.RefreshInfoBar then ns:RefreshInfoBar() end
end
function ns:CurrencyCommand(text)
    local id = tonumber(ns.Trim(text)) or tonumber(tostring(text):match("currency:(%d+)"))
    if id then ns.db.infobarCurrency = id end
    local piece = ns.InfoPiece("currency")
    if piece then ns:PrintRaw("|cff33ccffFantasy Glass UI|r: " .. piece .. "  (" .. ns:Tr("right-click the info bar and tick Currency to show it there") .. ")")
    else ns:Print("Shift-click a currency into the line, or give its number: /fgui currency 1166.") end
    if ns.RefreshInfoBar then ns:RefreshInfoBar() end
end

------------------------------------------------------------------------------------------
-- Notepad: /fgui notepad. One page for this character and one shared by all of them.
------------------------------------------------------------------------------------------
local pad
function ns:ShowNotepad()
    if type(ns.root) ~= "table" then return end
    if type(ns.root.notepad) ~= "table" then ns.root.notepad = {} end
    local store = ns.root.notepad
    if not pad then
        local w = CreateFrame("Frame", "FantasyGlassUINotepad", UIParent, ns.template)
        w:SetSize(420, 340)
        w:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
        w:SetFrameStrata("DIALOG")
        w:SetBackdrop(ns.BACKDROP)
        ns:Paint(w, "SetBackdropColor", "window", 0.97)
        ns:Paint(w, "SetBackdropBorderColor", "@border", 1)
        ns:Dress(w)
        w:EnableMouse(true); w:SetMovable(true); if w.SetClampedToScreen then w:SetClampedToScreen(true) end; w:RegisterForDrag("LeftButton")
        w:SetScript("OnDragStart", function(self) self:StartMoving() end)
        w:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        if type(UISpecialFrames) == "table" then tinsert(UISpecialFrames, "FantasyGlassUINotepad") end
        w.title = ns:NewText(w, 14, "LEFT")
        w.title:SetPoint("TOPLEFT", 14, -12)
        ns:Paint(w.title, "SetTextColor", "@accent")
        w.title:SetText(ns:Tr("Notepad"))
        local close = ns:CreateButton(w, "X", 22, 20, function() w:Hide() end)
        close:SetPoint("TOPRIGHT", -8, -8)
        w.page = "mine"
        local function Key() return (w.page == "mine") and ns:CharKey() or "shared" end
        local scroll = CreateFrame("ScrollFrame", "FantasyGlassUINotepadScroll", w, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 14, -66)
        scroll:SetPoint("BOTTOMRIGHT", -32, 14)
        local box = CreateFrame("EditBox", nil, scroll)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:SetWidth(370)
        if box.SetFontObject and _G.ChatFontNormal then box:SetFontObject(_G.ChatFontNormal) end
        box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        box:SetScript("OnTextChanged", function(self, user)
            if user then
                local text = self:GetText()
                store[Key()] = (type(text) == "string" and text ~= "") and text or nil
            end
        end)
        scroll:SetScrollChild(box)
        w.box = box
        function w:Load()
            box:SetText(store[Key()] or "")
            if self.mine.text then
                if self.page == "mine" then ns:Paint(self.mine.text, "SetTextColor", "@accent"); self.all.text:SetTextColor(0.7, 0.7, 0.7)
                else ns:Paint(self.all.text, "SetTextColor", "@accent"); self.mine.text:SetTextColor(0.7, 0.7, 0.7) end
            end
        end
        w.mine = ns:CreateButton(w, "This character", 130, 20, function() w.page = "mine"; w:Load() end)
        w.mine:SetPoint("TOPLEFT", 14, -38)
        w.all = ns:CreateButton(w, "All characters", 130, 20, function() w.page = "shared"; w:Load() end)
        w.all:SetPoint("LEFT", w.mine, "RIGHT", 6, 0)
        ns:ButtonTip(w.mine, "Notes only this character sees.")
        ns:ButtonTip(w.all, "Notes every character on your account sees.")
        pad = w
    end
    pad:Load()
    pad:Show()
    return pad
end

------------------------------------------------------------------------------------------
-- To-do list: /fgui todo buy flasks        adds it        /fgui todo daily cooking quest   one that comes back each day
--             /fgui todo                   the list: click to tick off, right-click to remove
------------------------------------------------------------------------------------------
-- Is this one ticked off? A daily one is, only if it was done since the last daily reset.
function ns.TodoDone(item, lastReset)
    if not item.doneAt then return false end
    if item.daily then return item.doneAt >= (lastReset or 0) end
    return true
end
-- "daily cooking quest" -> "cooking quest", true
function ns.TodoParse(text)
    text = ns.Trim(text)
    local rest = text:match("^[Dd][Aa][Ii][Ll][Yy]%s+(.+)$")
    if rest then return ns.Trim(rest), true end
    return text, false
end
local function LastReset()
    local now = time and time() or 0
    local get = C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset
    if type(get) == "function" then
        local ok, left = pcall(get)
        if ok and type(left) == "number" and not Secret(left) then return now - (86400 - left) end
    end
    local ok, t = pcall(date, "*t", now)                       -- (no reset known: midnight)
    if ok and type(t) == "table" then return now - ((t.hour or 0) * 3600 + (t.min or 0) * 60 + (t.sec or 0)) end
    return now - 86400
end
function ns:TodoCommand(text)
    if type(ns.root) ~= "table" then return end
    if type(ns.root.todo) ~= "table" then ns.root.todo = {} end
    local list = ns.root.todo
    local what, daily = ns.TodoParse(text)
    if what ~= "" then
        list[#list + 1] = { text = what, daily = daily or nil }
        ns:Print("To do: %s", what)
    end
    local reset = LastReset()
    local lines = {}
    for i, item in ipairs(list) do
        local done = ns.TodoDone(item, reset)
        lines[#lines + 1] = { left = (done and "|cff33ff66[x]|r |cff888888" or "[  ] ") .. item.text .. (done and "|r" or ""), right = item.daily and ("|cff9aa4b4" .. ns:Tr("daily") .. "|r") or "",
            click = function(button)
                if button == "RightButton" then table.remove(list, i)
                else item.doneAt = (not done) and (time and time() or 0) or nil end
                ns:TodoCommand("")
            end }
    end
    if #lines == 0 then lines[1] = { left = ns:Tr("Nothing to do. Add something with /fgui todo buy flasks.") } end
    return ns:ShowList("Todo", "To do", lines, "Click to tick off. Right-click to remove. \"/fgui todo daily ...\" comes back each day.", 420, 320)
end

------------------------------------------------------------------------------------------
-- Calculator: /fgui calc 20*45+3
------------------------------------------------------------------------------------------
-- The answer, or nil and why not. Only numbers and + - * / ^ % ( ) are taken.
function ns.Calc(text)
    text = ns.Trim(text):gsub(",", "."):gsub("[xX]", "*")
    if text == "" then return nil, "nothing to work out" end
    if not text:match("^[%d%.%+%-%*/%^%%%(%)%s]+$") then return nil, "only numbers and + - * / ^ ( ) are understood" end
    local make = loadstring or load
    local fn = make and make("return " .. text)
    if not fn then return nil, "that does not add up" end
    local ok, value = pcall(fn)
    if not ok or type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return nil, "that does not add up" end
    return value
end
function ns:CalcCommand(text)
    local value, why = ns.Calc(text)
    if not value then ns:Print("Calculator: %s.", why); return end
    local shown = (value == math.floor(value) and math.abs(value) < 1e15) and format("%d", value) or format("%.4f", value):gsub("0+$", ""):gsub("%.$", "")
    ns:PrintRaw("|cff33ccffFantasy Glass UI|r: " .. ns.Trim(text) .. " = |cffffffff" .. shown .. "|r")
    return value
end
