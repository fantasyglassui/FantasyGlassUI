local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Keyboard control of the game's windows (12.2): with an NPC's talk, a quest, a vendor, the
-- mailbox, loot, a trainer, a flight master, a book or a question box open, Tab (or Down) goes to
-- the next thing to press, Shift+Tab (or Up) to the one before, and Enter or Space presses it. A
-- ring shows where you are and, if you like, each one is said aloud. Escape closes the window as
-- always. Only while such a window is open, never while you type, and never in a fight (the game
-- does not let add-ons take keys then).
------------------------------------------------------------------------------------------
ns.WINDOW_KEYS_FRAMES = { "GossipFrame", "QuestFrame", "QuestLogPopupDetailFrame", "MerchantFrame", "MailFrame", "OpenMailFrame",
                          "ItemTextFrame", "LootFrame", "ClassTrainerFrame", "TaxiFrame", "BankFrame", "GuildRegistrarFrame",
                          "TabardFrame", "PetStableFrame" }
-- (not the game menu: logging out and quitting are the game's own to press)
local POPUPS = { "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4" }
local shownAt = setmetatable({}, { __mode = "k" })

local function Shown(f)
    if type(f) ~= "table" or not f.IsVisible then return false end
    local ok, v = pcall(f.IsVisible, f)
    return ok and v == true
end
-- The window in front: a question box first, then the one opened last.
function ns.WindowKeysFront()
    for _, name in ipairs(POPUPS) do
        local f = _G[name]
        if Shown(f) then return f end
    end
    local best, at = nil, -1
    for _, name in ipairs(ns.WINDOW_KEYS_FRAMES) do
        local f = _G[name]
        if Shown(f) then
            local t = shownAt[f] or 0
            if t > at then best, at = f, t end
        end
    end
    return best
end

-- What can be pressed in a window, top to bottom and left to right.
local function Pressable(b)
    if b.suiNavSkip then return false end
    local okT, isButton = pcall(b.IsObjectType, b, "Button")
    if not (okT and isButton) or not Shown(b) then return false end
    if b.IsEnabled then local ok, on = pcall(b.IsEnabled, b); if ok and on == false then return false end end
    if b.IsMouseClickEnabled then local ok, on = pcall(b.IsMouseClickEnabled, b); if ok and on == false then return false end end
    local okW, w = pcall(b.GetWidth, b)
    local okH, h = pcall(b.GetHeight, b)
    if okW and okH and type(w) == "number" and type(h) == "number" and not Secret(w) and not Secret(h) and (w < 8 or h < 8) then return false end
    return true
end
function ns.WindowKeysButtons(frame)
    local list, seen, count = {}, {}, 0
    local function walk(f, depth)
        if depth > 8 or count > 400 or type(f) ~= "table" or not f.GetChildren then return end
        for _, child in ipairs({ f:GetChildren() }) do
            count = count + 1
            if type(child) == "table" and not seen[child] then
                seen[child] = true
                if Pressable(child) then list[#list + 1] = child end
                if Shown(child) then walk(child, depth + 1) end
            end
        end
    end
    walk(frame, 0)
    local function place(b)
        local okT, top = pcall(b.GetTop, b)
        local okL, left = pcall(b.GetLeft, b)
        top = (okT and type(top) == "number" and not Secret(top)) and top or 0
        left = (okL and type(left) == "number" and not Secret(left)) and left or 0
        return math.floor(top / 6 + 0.5), left                      -- (buttons a few pixels apart count as one row)
    end
    table.sort(list, function(a, b)
        local ta, la = place(a)
        local tb, lb = place(b)
        if ta ~= tb then return ta > tb end
        return la < lb
    end)
    return list
end
-- What a button says: its own text, a line of text on it, or the name beside it (a vendor's item).
local function Clean(t)
    if type(t) ~= "string" or Secret(t) then return nil end
    t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|H.-|h(.-)|h", "%1")
    t = t:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    return t ~= "" and t or nil
end
local function TextOf(f)
    if type(f) ~= "table" then return nil end
    if f.GetText then local ok, t = pcall(f.GetText, f); t = ok and Clean(t); if t then return t end end
    for _, key in ipairs({ "Text", "Name", "name", "Label", "label", "Title" }) do
        local fs = rawget(f, key)
        if type(fs) == "table" and fs.GetText then local ok, t = pcall(fs.GetText, fs); t = ok and Clean(t); if t then return t end end
    end
    if f.GetRegions then
        for _, r in ipairs({ f:GetRegions() }) do
            local okO, isText = pcall(r.IsObjectType, r, "FontString")
            if okO and isText and Shown(r) then local ok, t = pcall(r.GetText, r); t = ok and Clean(t); if t then return t end end
        end
    end
    return nil
end
function ns.WindowKeysLabel(b)
    local t = TextOf(b)
    if t then return t end
    local parent = b.GetParent and b:GetParent()
    t = parent and TextOf(parent)
    if t then return t end
    local name = b.GetName and b:GetName()
    if type(name) == "string" and name:find("Close") then return ns:Tr("Close") end
    return ns:Tr("Button")
end

-- Moving and pressing ---------------------------------------------------------------------------
local keys, ring, at, front
local function Ring()
    if ring then return ring end
    ring = CreateFrame("Frame", nil, UIParent)
    ring:SetFrameStrata("TOOLTIP")
    local W = 3                                                    -- (thick enough to find at a glance)
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, W }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, W },
                            { "TOPLEFT", "BOTTOMLEFT", W, nil }, { "TOPRIGHT", "BOTTOMRIGHT", W, nil } }) do
        local t = ring:CreateTexture(nil, "OVERLAY")
        t:SetTexture(ns.FLAT)
        t:SetPoint(side[1]); t:SetPoint(side[2])
        if side[3] then t:SetWidth(side[3]) else t:SetHeight(side[4]) end
        ns:Paint(t, "SetVertexColor", "@accent", 1)
        t.sui = true
    end
    ring:Hide()
    return ring
end
local function Focus(b, index, total)
    local r = Ring()
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", b, "TOPLEFT", -4, 4)
    r:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 4, -4)
    r:Show()
    ns.windowKeysFocus = b
    local label = ns.WindowKeysLabel(b)
    ns.windowKeysSaid = format(ns:Tr("%s, %d of %d"), label, index, total)
    if ns.db.windowKeysSay then ns:StopReading(); ns:Speak(ns.windowKeysSaid) end
    return label
end
-- Act on one key. Returns true when the key was used (and the game should not have it).
function ns.WindowKeysPress(key)
    if not (ns.db and ns.db.windowKeys) or InCombatLockdown() then return false end
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then return false end      -- (you are typing)
    local f = ns.WindowKeysFront()
    if not f then return false end
    if f ~= front then front, at = f, 0 end
    local list = ns.WindowKeysButtons(f)
    if #list == 0 then return false end
    for i, b in ipairs(list) do if b == ns.windowKeysFocus then at = i end end       -- (the list may have changed under it)
    if key == "TAB" or key == "DOWN" or key == "UP" then
        local back = key == "UP" or (key == "TAB" and IsShiftKeyDown())
        local now = (at and at > 0) and at or 0
        if back then at = (now <= 1) and #list or now - 1 else at = now % #list + 1 end
        Focus(list[at], at, #list)
        return true
    elseif key == "ENTER" or key == "SPACE" then
        local b = list[at or 0] or ns.windowKeysFocus
        if not (b and Shown(b)) then return false end
        ns.windowKeysPressed = b
        pcall(b.Click, b, "LeftButton")
        if ring then ring:Hide() end
        ns.windowKeysFocus = nil
        return true
    end
    return false
end

-- (always ready: the switch is read as it goes, so it works the moment it is switched on)
local start = CreateFrame("Frame")
start:RegisterEvent("PLAYER_LOGIN")
start:SetScript("OnEvent", function()
    keys = CreateFrame("Frame", "FantasyGlassUIWindowKeys", UIParent)
    keys:SetFrameStrata("DIALOG")
    keys:Hide()
    keys:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown() then return end                      -- (the game owns the keys in a fight)
        local used = ns.WindowKeysPress(key)
        pcall(self.SetPropagateKeyboardInput, self, not used)
    end)
    local function Watch(f)
        if type(f) == "table" and f.HookScript and not f.suiWindowKeys then
            f.suiWindowKeys = true
            f:HookScript("OnShow", function(self) shownAt[self] = GetTime() end)
        end
    end
    for _, name in ipairs(ns.WINDOW_KEYS_FRAMES) do Watch(_G[name]) end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:SetScript("OnEvent", function() keys:Hide(); if ring then ring:Hide() end end)
    ns:Every(0.25, "Window keys", function()
        for _, name in ipairs(ns.WINDOW_KEYS_FRAMES) do Watch(_G[name]) end           -- (windows that load later)
        local want = ns.db.windowKeys and not InCombatLockdown() and ns.WindowKeysFront() ~= nil
        if want and not keys:IsShown() then
            keys:Show()
            keys:EnableKeyboard(true)
            pcall(keys.SetPropagateKeyboardInput, keys, true)
        elseif not want and keys:IsShown() then
            keys:Hide()
            if ring then ring:Hide() end
            ns.windowKeysFocus, front = nil, nil
        end
        if ring and ring:IsShown() and not Shown(ns.windowKeysFocus) then ring:Hide() end
    end)
end)
