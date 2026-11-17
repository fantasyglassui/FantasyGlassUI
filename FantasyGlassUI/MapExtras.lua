local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Waypoints: /fgui way 45 62 the cave      a pin, with an arrow and the distance.
--            /fgui way                     takes it away again.
------------------------------------------------------------------------------------------
-- "45 62 name", "45.5, 62.1 name" -> 45, 62, "name" (percent of the map). Nil when there are no two numbers.
function ns.ParseWay(text)
    text = ns.Trim(text)
    local x, y, label = text:match("^(%d+%.?%d*)[%s,]+(%d+%.?%d*)%s*(.*)$")
    x, y = tonumber(x), tonumber(y)
    if not x or not y or x > 100 or y > 100 then return nil end
    return x, y, label or ""
end
-- Which way to turn the arrow (0 = straight ahead, turning left as it grows), and how far in yards.
-- Positions are fractions of the map; the map's y runs downward. `facing` is the game's: 0 north, growing to the left.
function ns.WayArrow(px, py, wx, wy, width, height, facing)
    local dx, dy = (wx - px) * width, (wy - py) * height
    local distance = math.sqrt(dx * dx + dy * dy)
    local bearing = (math.atan2 or math.atan)(-dx, -dy)
    return bearing - (facing or 0), distance
end

local arrow
local function Position(map, unit)
    if not (C_Map and C_Map.GetPlayerMapPosition) then return nil end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, map, unit)
    if not (ok and pos) then return nil end
    local x, y
    if type(pos) == "table" and pos.GetXY then local okX, a, b = pcall(pos.GetXY, pos); if okX then x, y = a, b end end
    if type(x) ~= "number" or type(y) ~= "number" or Secret(x) or Secret(y) then return nil end
    return x, y
end
ns.MapPosition = Position
local function MapSize(map)
    if C_Map and C_Map.GetMapWorldSize then
        local ok, w, h = pcall(C_Map.GetMapWorldSize, map)
        if ok and type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then return w, h end
    end
    return 1000, 667                                          -- (no size known: the distance is then a rough one)
end
ns.MapWorldSize = MapSize
function ns:ClearWaypoint(quiet)
    ns.waypoint = nil
    if arrow then arrow:Hide() end
    if C_Map and C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
    if not quiet then ns:Print("Waypoint cleared.") end
end
-- (onMap: a map other than the one you are on. quiet: for the quest guide, which says its own things.)
function ns:SetWaypoint(x, y, label, onMap, quiet)
    local map = (type(onMap) == "number") and onMap or (C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player"))
    if type(map) ~= "number" or Secret(map) then
        if not quiet then ns:Print("The game does not say which map you are on here.") end
        return false
    end
    ns.waypoint = { map = map, x = x / 100, y = y / 100, label = label or "", quiet = quiet }
    -- the game's own pin on the map, where it has one
    if C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
        pcall(function()
            C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x / 100, y / 100))
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
        end)
    end
    if not arrow then
        arrow = CreateFrame("Frame", "FantasyGlassUIWaypoint", UIParent)
        arrow:SetSize(120, 62)
        arrow:SetPoint("TOP", UIParent, "TOP", 0, -210)
        arrow.tex = arrow:CreateTexture(nil, "ARTWORK")
        arrow.tex:SetSize(36, 36)
        arrow.tex:SetPoint("TOP")
        arrow.tex:SetTexture("Interface\\Minimap\\MinimapArrow")
        arrow.text = ns:NewText(arrow, 12, "CENTER")
        arrow.text:SetPoint("BOTTOM", 0, 12)
        arrow.name = ns:NewText(arrow, 10, "CENTER")
        arrow.name:SetPoint("BOTTOM", 0, 0)
        arrow.name:SetTextColor(0.75, 0.75, 0.75)
        arrow:SetScript("OnUpdate", ns:Guard("Waypoint", function(self, elapsed)
            self.wait = (self.wait or 0) + (elapsed or 0)
            if self.wait < 0.05 then return end
            self.wait = 0
            local w = ns.waypoint
            if not w then self:Hide() return end
            local px, py = Position(w.map, "player")
            if not px then self.tex:Hide(); self.text:SetText(ns:Tr("another map")); return end
            local width, height = MapSize(w.map)
            local facing = GetPlayerFacing and GetPlayerFacing()
            if type(facing) ~= "number" or Secret(facing) then facing = 0 end
            local turn, distance = ns.WayArrow(px, py, w.x, w.y, width, height, facing)
            if distance < 10 and not w.quiet then ns:Print("You have arrived."); ns:ClearWaypoint(true); return end
            self.tex:Show()
            if self.tex.SetRotation then self.tex:SetRotation(turn) end
            self.text:SetText(format("%d %s", math.floor((tonumber(distance) or 0) + 0.5), ns:Tr("yd")))
        end))
        local entry = ns:RegisterMovable(arrow, "waypoint", "Waypoint")
        if type(entry) == "table" then entry.offPage = true end        -- (scaled from its own right-click menu in move mode)
    end
    arrow.name:SetText(ns.waypoint.label)
    arrow:Show()
    if not quiet then ns:Print("Waypoint set at %s, %s.", tostring(x), tostring(y)) end
    return true
end
function ns:WayCommand(text)
    if ns.Trim(text) == "" then
        if ns.waypoint then ns:ClearWaypoint() else ns:Print("Set a waypoint with /fgui way 45 62 (and a name, if you like).") end
        return
    end
    local x, y, label = ns.ParseWay(text)
    if not x then ns:Print("That is not a place on the map. Try /fgui way 45 62."); return end
    return ns:SetWaypoint(x, y, label)
end

------------------------------------------------------------------------------------------
-- Flight timer: a bar for the time left on a flight path. A route's time is learned the first
-- time you fly it; until then the bar counts up.
------------------------------------------------------------------------------------------
function ns.FlightKey(from, to) return tostring(from or "?") .. " > " .. tostring(to or "?") end
ns:NewModule("flightTimer", function()
    if type(ns.root) ~= "table" then return end
    if type(ns.root.flights) ~= "table" then ns.root.flights = {} end
    local known = ns.root.flights
    local trip, flying                                        -- { key, to, start, length }
    local bar = ns:NewStatusBar(UIParent, true)
    bar:SetSize(220, 16)
    bar:SetPoint("TOP", UIParent, "TOP", 0, -120)
    ns:Paint(bar, "SetStatusBarColor", "@accent")
    bar.name = ns:NewText(bar, 11, "LEFT"); bar.name:SetPoint("LEFT", 6, 0)
    bar.time = ns:NewText(bar, 11, "RIGHT"); bar.time:SetPoint("RIGHT", -6, 0)
    bar:Hide()
    ns.flightState = "on"

    local function Now() return (GetTime and GetTime()) or 0 end
    local function Chosen(index)
        if type(index) ~= "number" or not (TaxiNodeName and NumTaxiNodes and TaxiNodeGetType) then return end
        local from
        for i = 1, tonumber(NumTaxiNodes()) or 0 do if ns.Is(TaxiNodeGetType(i), "CURRENT") then from = TaxiNodeName(i) end end
        local to = TaxiNodeName(index)
        if type(to) ~= "string" or Secret(to) then return end
        if type(from) ~= "string" or Secret(from) then from = "?" end
        trip = { key = ns.FlightKey(from, to), to = to }
        return trip
    end
    local function Tick()
        local onTaxi = ns.Yes(UnitOnTaxi and UnitOnTaxi("player"))
        if onTaxi and not flying then
            flying = trip or { key = nil, to = ns:Tr("Flight") }
            flying.start, flying.length = Now(), flying.key and known[flying.key] or nil
            trip = nil
            bar.name:SetText(flying.to)
            bar:SetMinMaxValues(0, flying.length or 1)
            bar:Show()
        elseif not onTaxi and flying then
            local took = Now() - flying.start
            if flying.key and took > 5 and not flying.cut then known[flying.key] = took end
            ns.flightLast = flying
            flying = nil
            bar:Hide()
        end
        if flying then
            local gone = Now() - flying.start
            if flying.length then
                bar:SetValue(math.max(0, flying.length - gone))
                bar.time:SetText(ns.Clock(math.max(0, flying.length - gone)))
            else
                bar:SetValue(1)
                bar.time:SetText(ns.Clock(gone))
            end
        end
        return flying
    end
    ns.flightTest = { Chosen = Chosen, Tick = Tick, known = known, Trip = function(t) trip = t end }
    if hooksecurefunc and type(TakeTaxiNode) == "function" then pcall(hooksecurefunc, "TakeTaxiNode", function(index) pcall(Chosen, index) end) end
    ns:Every(0.5, "Flight timer", function() Tick() end)
    local entry = ns:RegisterMovable(bar, "flight", "Flight Timer")
    if type(entry) == "table" then entry.offPage = true end        -- (scaled from its own right-click menu in move mode)
end)

------------------------------------------------------------------------------------------
-- Fishing mode: while a fishing pole is in your hands the splash is loud, music and background
-- noise are turned down, and auto-loot is on. Everything goes back when the pole comes off.
------------------------------------------------------------------------------------------
ns.FISHING = { Sound_EnableSFX = "1", Sound_SFXVolume = "1", Sound_MusicVolume = "0", Sound_AmbienceVolume = "0.1", autoLootDefault = "1" }
function ns.IsFishingPole(class, sub) return class == 2 and sub == 20 end
ns:NewModule("fishingMode", function()
    if type(ns.root) ~= "table" then return end
    local Get = (C_CVar and C_CVar.GetCVar) or GetCVar
    local Set = (C_CVar and C_CVar.SetCVar) or SetCVar
    if type(Get) ~= "function" or type(Set) ~= "function" then return end
    local function HoldingPole()
        local id = GetInventoryItemID and GetInventoryItemID("player", 16)
        if type(id) ~= "number" or Secret(id) then return false end
        local Instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
        if type(Instant) ~= "function" then return false end
        local ok, _, _, _, _, _, class, sub = pcall(Instant, id)
        return ok and ns.IsFishingPole(class, sub)
    end
    local function Apply()
        local pole = HoldingPole()
        local before = ns.root.fishingBefore
        if pole and not before then
            before = {}
            for cvar, value in pairs(ns.FISHING) do
                local ok, now = pcall(Get, cvar)
                if ok and now ~= nil and not Secret(now) then before[cvar] = tostring(now); pcall(Set, cvar, value) end
            end
            ns.root.fishingBefore = before
            ns:Print("Fishing mode on: the splash is loud and auto-loot is on.")
        elseif not pole and before then
            for cvar, value in pairs(before) do pcall(Set, cvar, value) end
            ns.root.fishingBefore = nil
            ns:Print("Fishing mode off: your sound and loot settings are back.")
        end
        ns.fishingState = pole and "on, fishing now" or "on"
        return pole
    end
    ns.fishingTest = { Apply = Apply }
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("MapExtras events", function() ns:After(0.5, function() pcall(Apply) end) end))
end)

------------------------------------------------------------------------------------------
-- A smaller world map that fades while you move (so you can walk with it open).
------------------------------------------------------------------------------------------
function ns.MapScale(percent) return math.max(40, math.min(100, tonumber(percent) or 75)) / 100 end
ns:NewModule("smallMap", function()
    local map = _G.WorldMapFrame
    if type(map) ~= "table" or not map.SetScale then ns.smallMapState = "this game client has no world map window an add-on can size"; return end
    local moving = false
    local function Apply()
        if ns:Locked(map) then return false end
        local ok = pcall(map.SetScale, map, ns.MapScale(ns.db.mapSize))
        pcall(map.SetAlpha, map, moving and 0.45 or 1)
        ns.smallMapState = format("on, at %d%%", ns.MapScale(ns.db.mapSize) * 100)
        return ok
    end
    ns.smallMapTest = { Apply = Apply, Moving = function(m) moving = m; return Apply() end }
    if map.HookScript then pcall(map.HookScript, map, "OnShow", function() pcall(Apply) end) end
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("MapExtras events", function(_, event)
        moving = (event == "PLAYER_STARTED_MOVING")
        if map.IsShown and ns.Yes(map:IsShown()) then pcall(Apply) end
    end))
end)
function ns:MapSizeCommand(text)
    local n = tonumber((ns.Trim(text):gsub("%%", "")))
    if n then ns.db.mapSize = math.floor(ns.MapScale(n) * 100) end
    ns:Print("The world map opens at %d%% of its size.", math.floor(ns.MapScale(ns.db.mapSize) * 100))
    if not ns.db.smallMap then ns:Print("It is switched off: see \"Smaller world map\" on the Features tab.") end
    if ns.smallMapTest then pcall(ns.smallMapTest.Apply) end
end

------------------------------------------------------------------------------------------
-- Your group on the world map, as dots in class colors.
------------------------------------------------------------------------------------------
-- Where a dot goes on a canvas this size, for a dot drawn at this scale.
function ns.MapDotOffset(x, y, width, height, scale)
    scale = (type(scale) == "number" and scale > 0) and scale or 1
    return x * width / scale, -y * height / scale
end
ns:NewModule("mapGroup", function()
    local map = _G.WorldMapFrame
    local canvas = type(map) == "table" and ((map.ScrollContainer and map.ScrollContainer.Child) or (map.GetCanvas and map:GetCanvas()))
    if type(canvas) ~= "table" or not canvas.GetWidth then ns.mapGroupState = "this game client's world map has no canvas an add-on can draw on"; return end
    ns.mapGroupState = "on"
    local dots = {}
    local function Dot(i)
        local d = CreateFrame("Frame", nil, canvas)
        d:SetSize(12, 12)
        d:SetFrameLevel((canvas:GetFrameLevel() or 1) + 20)
        d.rim = d:CreateTexture(nil, "BACKGROUND")
        d.rim:SetAllPoints()
        d.rim:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall")
        d.rim:SetVertexColor(0, 0, 0, 1)
        d.tex = d:CreateTexture(nil, "ARTWORK")
        d.tex:SetPoint("TOPLEFT", 2, -2)
        d.tex:SetPoint("BOTTOMRIGHT", -2, 2)
        d.tex:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall")
        d:EnableMouse(true)
        d:SetScript("OnEnter", function(self)
            if not self.name then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.name, self.r or 1, self.g or 1, self.b or 1)
            GameTooltip:Show()
        end)
        d:SetScript("OnLeave", function() GameTooltip:Hide() end)
        dots[i] = d
        return d
    end
    local function Update()
        local shown = 0
        local mapID = map.GetMapID and map:GetMapID()
        if type(mapID) == "number" and not Secret(mapID) then
            local w, h, scale = canvas:GetWidth(), canvas:GetHeight(), canvas.GetScale and canvas:GetScale() or 1
            if type(w) == "number" and type(h) == "number" then
                local size = (type(scale) == "number" and scale > 0) and (1 / scale) or 1
                for _, m in ipairs(ns:GroupMembers()) do
                    local x, y = Position(mapID, m.unit)
                    if x and (x > 0 or y > 0) then
                        shown = shown + 1
                        local d = dots[shown] or Dot(shown)
                        d:SetScale(size)
                        d:ClearAllPoints()
                        d:SetPoint("CENTER", canvas, "TOPLEFT", ns.MapDotOffset(x, y, w, h, size))
                        local r, g, b = 1, 1, 1
                        if m.class then local ok, cr, cg, cb = pcall(function() return ns:ClassRGB(m.class) end); if ok and type(cr) == "number" then r, g, b = cr, cg, cb end end
                        d.tex:SetVertexColor(r, g, b, 1)
                        d.name, d.r, d.g, d.b = m.name, r, g, b
                        d:Show()
                    end
                end
            end
        end
        for i = shown + 1, #dots do dots[i]:Hide() end
        return shown
    end
    ns.mapGroupTest = { Update = Update, dots = dots }
    ns:Every(0.5, "Group on the map", function()
        if map.IsShown and ns.Yes(map:IsShown()) then Update() end
    end)
end)

------------------------------------------------------------------------------------------
-- Minimap: right-click for the tracking menu, and the name of whoever pinged it.
------------------------------------------------------------------------------------------
function ns:OpenTrackingMenu()
    local cluster = _G.MinimapCluster
    local button = cluster and ((cluster.Tracking and cluster.Tracking.Button) or (cluster.TrackingFrame and cluster.TrackingFrame.Button))
    if type(button) == "table" and button.OpenMenu then return pcall(button.OpenMenu, button) and "menu" or false end
    if type(button) == "table" and button.Click then return pcall(button.Click, button) and "click" or false end
    if _G.MiniMapTrackingDropDown and ToggleDropDownMenu then
        return pcall(ToggleDropDownMenu, 1, nil, _G.MiniMapTrackingDropDown, "cursor") and "dropdown" or false
    end
    if _G.MiniMapTrackingButton and _G.MiniMapTrackingButton.Click then return pcall(_G.MiniMapTrackingButton.Click, _G.MiniMapTrackingButton) and "click" or false end
    return false
end
ns:NewModule("mapTracking", function()
    local mini = _G.Minimap
    if type(mini) ~= "table" or not mini.HookScript then return end
    pcall(mini.HookScript, mini, "OnMouseUp", ns:Guard("Tracking menu", function(_, button)
        if button == "RightButton" then ns.trackingOpened = ns:OpenTrackingMenu() end
    end))
end)
ns:NewModule("mapPing", function()
    local mini = _G.Minimap
    if type(mini) ~= "table" then return end
    local f = CreateFrame("Frame", nil, mini)
    f:SetSize(120, 14)
    f:SetPoint("TOP", mini, "TOP", 0, -14)
    f:SetFrameLevel((mini.GetFrameLevel and mini:GetFrameLevel() or 1) + 10)
    f.text = ns:NewText(f, 11, "CENTER")
    f.text:SetPoint("CENTER")
    if f.text.SetShadowOffset then f.text:SetShadowOffset(1, -1); f.text:SetShadowColor(0, 0, 0, 1) end
    f:Hide()
    f:SetScript("OnUpdate", function(self, elapsed)
        self.left = (self.left or 0) - (elapsed or 0)
        if self.left <= 0 then self:Hide() end
    end)
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "MINIMAP_PING")
    ev:SetScript("OnEvent", ns:Guard("Minimap ping", function(_, _, unit)
        if type(unit) ~= "string" or ns.Yes(UnitIsUnit(unit, "player")) then return end
        local name = UnitName(unit)
        if name == nil then return end
        if not pcall(f.text.SetText, f.text, name) then return end
        local r, g, b = 1, 1, 1
        local _, class = UnitClass(unit)
        if type(class) == "string" and not Secret(class) then local ok, cr, cg, cb = pcall(function() return ns:ClassRGB(class) end); if ok and type(cr) == "number" then r, g, b = cr, cg, cb end end
        f.text:SetTextColor(r, g, b)
        f.left = 3
        f:Show()
        ns.pingCount = (ns.pingCount or 0) + 1
    end))
end)
