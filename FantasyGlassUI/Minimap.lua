local _, ns = ...

ns:NewModule("minimap", function()
    local W = 180
    local cluster = _G.MinimapCluster
    local th = ns.theme

    -- Our own minimap panel --------------------------------------------------------
    local box = CreateFrame("Frame", "FantasyGlassUIMinimap", UIParent, ns.template)
    box:SetSize(W + 8, W + 48)
    box:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -12, -12)
    box:SetFrameStrata("BACKGROUND")
    box:SetBackdrop(ns.BACKDROP)
    ns:Paint(box, "SetBackdropColor", "bg", 0.92)
    ns:Paint(box, "SetBackdropBorderColor", "@border", 1)
    ns:Dress(box)

    local zone = box:CreateFontString(nil, "OVERLAY")
    ns:Font(zone, 14, true)
    zone:SetPoint("TOP", box, "TOP", 0, -6)
    zone:SetWidth(W)

    local coords = box:CreateFontString(nil, "OVERLAY")
    ns:Font(coords, 11)
    coords:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 6, 6)

    local clock = box:CreateFontString(nil, "OVERLAY")
    ns:Font(clock, 11)
    clock:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -6, 6)

    -- Move the real minimap into it, square it off ----------------------------------
    local function PlaceMap()
        Minimap:SetParent(box)
        Minimap:ClearAllPoints()
        Minimap:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -22)
        Minimap:SetSize(W, W)
        Minimap:SetFrameStrata("LOW")
    end
    PlaceMap()
    Minimap:SetMaskTexture("Interface\\ChatFrame\\ChatFrameBackground")
    if ns.style == "RUNIC" then                              -- Runic: the map set in a band of carved runes
        local edge = CreateFrame("Frame", nil, Minimap)
        edge:SetAllPoints()
        edge:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 3)
        local function Strip(vertical, a1, a2, x, y)
            local s = ns:RuneStrip(edge, vertical, W, 11, 0.7)
            s:ClearAllPoints()
            s:SetPoint(a1, Minimap, a2, x, y)
            return s
        end
        edge.top = Strip(false, "TOP", "TOP", 0, 0)
        edge.bottom = Strip(false, "BOTTOM", "BOTTOM", 0, 0)
        edge.left = Strip(true, "LEFT", "LEFT", 0, 0)
        edge.right = Strip(true, "RIGHT", "RIGHT", 0, 0)
        ns:Corners(edge, Minimap, 18, 0)                     -- (a rune-stud at each corner)
        ns.minimapRunes = edge
    end
    function GetMinimapShape() return "SQUARE" end
    if ns.db.minimapRound and ns.ApplyMinimapShape then ns:After(0, function() pcall(ns.ApplyMinimapShape, ns) end) end

    -- Remove Blizzard's minimap art
    local kill = {
        Minimap.ZoomIn, Minimap.ZoomOut, _G.MinimapBackdrop, _G.MinimapCompassTexture, _G.MinimapBorder,
        _G.MinimapBorderTop, _G.MiniMapWorldMapButton, _G.MinimapNorthTag, _G.MinimapZoomIn, _G.MinimapZoomOut,
        cluster and cluster.BorderTop, cluster and cluster.ZoneTextButton, _G.MinimapZoneTextButton,
    }
    for _, obj in pairs(kill) do ns:Kill(obj) end

    -- Rescue the useful little buttons into a strip under our panel
    local strip = CreateFrame("Frame", nil, UIParent)
    strip:SetSize(W, 26)
    strip:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -4)
    local ind = cluster and cluster.IndicatorFrame
    local items = {
        cluster and cluster.Tracking, _G.GameTimeFrame, ind and ind.MailFrame, ind and ind.CraftingOrderFrame,
        _G.MiniMapMailFrame, cluster and cluster.InstanceDifficulty, _G.AddonCompartmentFrame,
    }
    local x = 0
    for _, f in pairs(items) do
        if type(f) == "table" and f.SetParent then
            pcall(function()
                f:SetParent(strip)
                f:ClearAllPoints()
                f:SetPoint("RIGHT", strip, "RIGHT", -x, 0)
                f:SetScale(0.75)
                x = x + 28
            end)
        end
    end

    -- Hide what's left of the old cluster
    if cluster then
        cluster:SetAlpha(0)
        cluster:EnableMouse(false)
    end

    -- Mouse wheel zoom
    Minimap:EnableMouseWheel(true)
    Minimap:SetScript("OnMouseWheel", function(self, delta)
        local z = self:GetZoom() + (delta > 0 and 1 or -1)
        self:SetZoom(math.max(0, math.min(5, z)))
    end)

    -- Who pinged the map: their name, in their class color, for a few seconds
    do
        local who = ns:NewText(Minimap, 11, "CENTER")
        who:SetPoint("BOTTOM", Minimap, "BOTTOM", 0, 8)
        who:Hide()
        local until_ = 0
        local ping = CreateFrame("Frame")
        if pcall(ping.RegisterEvent, ping, "MINIMAP_PING") then
            ping:SetScript("OnEvent", ns:Guard("Minimap ping", function(_, _, unit)
                if type(unit) ~= "string" then return end
                local name = UnitName(unit)
                if type(name) ~= "string" or ns:IsSecret(name) then return end
                local r, g, b = ns:ClassColor(unit)
                who:SetText(name)
                who:SetTextColor(r or 1, g or 1, b or 1)
                who:Show()
                until_ = GetTime() + 3
            end))
            ns:Every(0.5, "Minimap ping", function()
                if until_ > 0 and GetTime() > until_ then until_ = 0; who:Hide() end
            end)
        end
    end

    -- Zone text, coordinates, clock ---------------------------------------------------------
    local function ZoneColor()
        local fn = (C_PvP and C_PvP.GetZonePVPInfo) or GetZonePVPInfo
        local t = fn and fn()
        if t == "sanctuary" then return 0.41, 0.80, 0.94
        elseif t == "friendly" then return 0.10, 1.00, 0.10
        elseif t == "hostile" or t == "arena" then return 1.00, 0.10, 0.10
        elseif t == "contested" then return 1.00, 0.70, 0.00 end
        return 1.00, 0.90, 0.50
    end

    local function UpdateZone()
        zone:SetText(GetMinimapZoneText() or "")
        zone:SetTextColor(ZoneColor())
    end

    local function UpdateCoords()
        local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
        if pos and pos.GetXY then
            local px, py = pos:GetXY()
            coords:SetText(format("%.1f, %.1f", px * 100, py * 100))
        else
            coords:SetText("")
        end
    end

    local acc = 0
    box:SetScript("OnUpdate", ns:Safe("Minimap", function(_, e)
        acc = acc + e
        if acc < 0.5 then return end
        acc = 0
        UpdateCoords()
        clock:SetText(ns:ClockText())
    end))

    box:RegisterEvent("ZONE_CHANGED")
    box:RegisterEvent("ZONE_CHANGED_INDOORS")
    box:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    box:RegisterEvent("PLAYER_ENTERING_WORLD")
    box:SetScript("OnEvent", ns:Safe("Minimap", function(_, event)
        UpdateZone()
        if event == "PLAYER_ENTERING_WORLD" then ns:After(1, PlaceMap) end   -- re-assert after Blizzard layout
    end))
    UpdateZone()

    ns:RegisterMovable(box, "minimap", "Minimap")
end)
