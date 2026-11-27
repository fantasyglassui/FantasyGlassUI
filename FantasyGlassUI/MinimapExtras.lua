local _, ns = ...

-- Two more minimap buttons (13.0), beside the launcher and drawn like it: one opens the route
-- planner, the other ways to make gold. Each has its own switch (minimapPlanner, minimapGold) and is
-- dragged along the minimap as the launcher is, its spot kept in the profile.
--
-- They live here, in the main add-on, and call the folder stand-ins (ns:PlannerOpen, ns:GoldOpen in
-- Folders.lua), so they show without the planner's or the gold folder being loaded.
--
-- When one shows: its switch is on, safe mode is off, its folder has not failed to load and is
-- installed (what the stand-in needs), and, for the planner, quest guides are on.
-- (Their names do not end in "MinimapButton", so the minimap button collector leaves them where they
-- are, as it does the launcher.)
local type, ipairs, pcall, tonumber = type, ipairs, pcall, tonumber

local SIZE, STEP = 22, 26          -- the launcher's size, and the distance between two buttons (a 4 px gap)
local DEFS = {
    { key = "minimapPlanner", name = "FantasyGlassUIPlannerButton", slot = 1, folder = "planner", needsGuide = true,
      title = "Route planner", line = "Click: open the planner. Drag: move.",
      atlas = "islands-queue-prop-compass", texture = "Interface\\Minimap\\MinimapArrow",
      open = function() return ns:PlannerOpen() end },
    { key = "minimapGold", name = "FantasyGlassUIGoldButton", slot = 2, folder = "gold",
      title = "Ways to make gold", line = "Click: open the gold window. Drag: move.",
      texture = "Interface\\Icons\\INV_Misc_Coin_01", crop = true,
      open = function() return ns:GoldOpen() end },
}
local buttons = {}                 -- key -> the button
local shown = {}                   -- key -> whether it is meant to show (what Apply last decided)

local function Host() return _G.FantasyGlassUIMinimap or _G.Minimap end    -- (as the launcher: ours if it is there)
local function Dims(host)
    local w, h = host:GetWidth(), host:GetHeight()
    if type(w) ~= "number" or w <= 0 then w = 180 end
    if type(h) ~= "number" or h <= 0 then h = w end
    return w, h
end

-- Is the folder this button opens there to be loaded (what the stand-in needs)?
local function FolderUsable(key)
    if ns.folderBroken and ns.folderBroken[key] then return false end
    local f = ns.FOLDERS and ns.FOLDERS[key]
    local exists = C_AddOns and C_AddOns.DoesAddOnExist
    if type(f) == "table" and type(exists) == "function" then
        local ok, v = pcall(exists, f.addon)
        if ok and v == false then return false end
    end
    return true
end
local function Wanted(def)
    if ns.safeMode or type(ns.db) ~= "table" or ns.db[def.key] == false then return false end
    if def.needsGuide and not (ns.GuideOn and ns:GuideOn()) then return false end
    return FolderUsable(def.folder)
end

-- The default spot: beside the launcher, along the minimap's side, away from its nearer end, so the
-- three never overlap.
local function DefaultSpot(def, host)
    local w, h = Dims(host)
    local pos = ns.db and ns.db.launcherPos
    local lx = type(pos) == "table" and tonumber(pos[1]) or 6
    local ly = type(pos) == "table" and tonumber(pos[2]) or 6
    lx = math.max(-8, math.min(w + 8, lx)); ly = math.max(-8, math.min(h + 8, ly))
    local dir = (ly <= h / 2) and 1 or -1
    return lx, ly + dir * STEP * def.slot
end
local function Clamp(host, x, y)
    local w, h = Dims(host)
    return math.max(-8, math.min(w + 8, tonumber(x) or 0)), math.max(-8, math.min(h + 8, tonumber(y) or 0))
end

local function Tip(def, tooltip)
    tooltip:AddLine(ns:Tr(def.title))
    tooltip:AddLine(ns:Tr(def.line), 1, 1, 1)
end

local Apply
local function Build(def)
    if buttons[def.key] then return buttons[def.key] end
    local host = Host()
    if type(host) ~= "table" or not host.GetWidth then return nil end
    local btn = CreateFrame("Button", def.name, host, ns.template)
    btn:SetSize(SIZE, SIZE)                                  -- (the launcher's look: its size, layer, glass and rim)
    btn:SetFrameLevel((host:GetFrameLevel() or 1) + 8)
    btn:SetBackdrop(ns.BACKDROP)
    ns:Paint(btn, "SetBackdropColor", "window", 0.9)
    ns:Paint(btn, "SetBackdropBorderColor", "@border", 1)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", 2, -2)
    btn.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    local drawn = false
    if def.atlas and btn.icon.SetAtlas then
        local ok, yes = pcall(btn.icon.SetAtlas, btn.icon, def.atlas)
        drawn = ok and yes ~= false
    end
    if not drawn then btn.icon:SetTexture(def.texture) end
    if def.crop then btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end   -- (an item icon's own frame trimmed off)
    btn:RegisterForClicks("LeftButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn.suiKey = def.key

    local function Place(x, y)
        x, y = Clamp(host, x, y)
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", host, "BOTTOMLEFT", x, y)
        btn.suiX, btn.suiY = x, y
        return x, y
    end
    btn.suiPlace = Place
    local pos = ns.db[def.key .. "Pos"]
    if type(pos) == "table" and type(pos[1]) == "number" and type(pos[2]) == "number" then Place(pos[1], pos[2])
    else Place(DefaultSpot(def, host)) end

    local dragging = false
    btn:SetScript("OnDragStart", function() dragging = true; GameTooltip:Hide() end)
    btn:SetScript("OnDragStop", function()
        dragging = false
        local x, y = btn.suiX, btn.suiY
        if type(x) == "number" and type(y) == "number" then ns.db[def.key .. "Pos"] = { x, y } end
    end)
    btn:SetScript("OnUpdate", function()
        if not dragging then return end
        local cx, cy = GetCursorPosition()
        local scale, left, bottom = host:GetEffectiveScale(), host:GetLeft(), host:GetBottom()
        if type(cx) ~= "number" or type(scale) ~= "number" or scale <= 0 or type(left) ~= "number" or type(bottom) ~= "number" then return end
        Place(cx / scale - left, cy / scale - bottom)
    end)
    btn:SetScript("OnClick", function() ns.MinimapExtraClick(def.key) end)
    btn:SetScript("OnEnter", function(self)
        if dragging then return end
        ns:Paint(self, "SetBackdropBorderColor", "@accent", 1)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        Tip(def, GameTooltip)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        ns:Paint(self, "SetBackdropBorderColor", "@border", 1)
        GameTooltip:Hide()
    end)
    buttons[def.key] = btn
    return btn
end

-- Build what is wanted, and show or hide each by its switch (the options call it as a switch changes,
-- the guide's switch too). Returns how many show.
function Apply()
    local n = 0
    for _, def in ipairs(DEFS) do
        local want = Wanted(def)
        local btn = buttons[def.key] or (want and Build(def)) or nil
        if btn then
            if want then btn:Show() else btn:Hide() end
        end
        shown[def.key] = want and btn ~= nil
        if shown[def.key] then n = n + 1 end
    end
    return n
end
function ns:ApplyMinimapExtras() return Apply() end

-- A click: the stand-in loads the folder (not in a fight, before it is loaded: it says so) and opens the window.
function ns.MinimapExtraClick(key)
    for _, def in ipairs(DEFS) do
        if def.key == key then
            GameTooltip:Hide()
            local ok, err = pcall(def.open)
            if not ok and type(ns.errors) == "table" and #ns.errors < 60 then ns.errors[#ns.errors + 1] = "Minimap button " .. key .. ": " .. tostring(err) end
            if ns.folderBroken and ns.folderBroken[def.folder] then Apply() end   -- (it could not start: the button goes)
            return ok
        end
    end
    return false
end

-- For the tests: the buttons, what is meant to show, a button's spot and its default.
ns.minimapExtras = {
    defs = DEFS, buttons = buttons, shown = shown,
    Spot = function(key) local b = buttons[key]; if b then return b.suiX, b.suiY end end,
    Place = function(key, x, y) local b = buttons[key]; if b then return b.suiPlace(x, y) end end,
    Default = function(key) for _, def in ipairs(DEFS) do if def.key == key then local h = Host(); if type(h) == "table" then return DefaultSpot(def, h) end end end end,
}

-- Built after the minimap has been set up, as the launcher is: each switch is a module of its own, and
-- either starts both (Apply looks at both switches).
local function Start()
    ns:After(1, Apply)
    if ns.minimapExtrasEvents then return end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", ns:Guard("Minimap buttons events", function() ns:After(1, Apply) end))
    ns.minimapExtrasEvents = ev
end
ns:NewModule("minimapPlanner", Start)
ns:NewModule("minimapGold", Start)
