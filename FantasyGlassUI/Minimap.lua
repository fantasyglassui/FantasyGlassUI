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
    if ns.style == "CELESTIAL" then ns:CelestialMinimap(W) end      -- (Celestial: the map as a star chart)
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

------------------------------------------------------------------------------------------
-- Celestial (11.11): the minimap as a star chart. Square (as it comes): degree marks along its edges,
-- a star point at north, east, south and west (north the largest), and the sun by day or the moon by
-- night riding along the top edge by the game's clock. Round (the minimap's "round" switch): a still
-- ring of degree marks with the four directions, an outer orbit that turns slowly (held still with
-- "Reduce motion"), and the sun or moon on it: noon at the top, midnight at the foot.
------------------------------------------------------------------------------------------
local function GameHours()
    local ok, h, m = pcall(GetGameTime)
    if ok and type(h) == "number" and type(m) == "number" and not ns:IsSecret(h) then return h + m / 60 end
    local ok2, t = pcall(date, "*t")
    if ok2 and type(t) == "table" then return (tonumber(t.hour) or 12) + (tonumber(t.min) or 0) / 60 end
    return 12
end
ns.MinimapGameHours = GameHours
-- Where the sun or moon sits, for a time of day: on the square's top edge (0 left .. 1 right, the
-- day from 6:00 to 18:00 and the night from 18:00 to 6:00), and on the round ring (radians, 0 at
-- the top, clockwise).
function ns.SkyBody(hours)
    hours = (tonumber(hours) or 12) % 24
    local day = hours >= 6 and hours < 18
    return day, ((hours - 6) % 12) / 12, ((hours - 12) / 24) * 2 * math.pi
end
function ns:CelestialMinimap(W)
    if ns.minimapRunes then return ns.minimapRunes end
    local edge = CreateFrame("Frame", nil, Minimap)
    edge:SetAllPoints()
    edge:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 3)
    local THICK, REPEAT = 12, 192                           -- (the marks drawn 12 high; one run of them every 192 across)
    local function Ticks(side)
        local t = edge:CreateTexture(nil, "OVERLAY")
        if not pcall(t.SetTexture, t, ns.MEDIA .. "ticks_celestial.tga", "REPEAT", "REPEAT") then t:SetTexture(ns.MEDIA .. "ticks_celestial.tga") end
        if t.SetBlendMode then t:SetBlendMode("ADD") end
        ns:Paint(t, "SetVertexColor", "@accent", 0.75)
        local reps = W / REPEAT
        if side == "TOP" or side == "BOTTOM" then
            t:SetHeight(THICK)
            t:SetPoint(side .. "LEFT"); t:SetPoint(side .. "RIGHT")
            if side == "TOP" then t:SetTexCoord(0, reps, 0, 1) else t:SetTexCoord(0, reps, 1, 0) end      -- (the marks face inward)
        else
            t:SetWidth(THICK)
            t:SetPoint("TOP" .. side); t:SetPoint("BOTTOM" .. side)
            -- (the strip turned on its side: corners in the order upper-left, lower-left, upper-right, lower-right)
            if side == "LEFT" then t:SetTexCoord(0, 0, reps, 0, 0, 1, reps, 1) else t:SetTexCoord(0, 1, reps, 1, 0, 0, reps, 0) end
        end
        t.sui = true
        return t
    end
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do Ticks(side) end
    for k, def in ipairs({ { "TOP", 26 }, { "RIGHT", 16 }, { "BOTTOM", 16 }, { "LEFT", 16 } }) do
        local star = ns:Sparkle(edge, Minimap, def[1], def[2])
        if ns.SkyBreathe then ns.SkyBreathe(star, 0.25, 1, 1.1 + k * 0.4) end     -- (each twinkling in its own time)
        if ns.SkyLoop then ns:SkyLoop(star, "Rotation", 8 + k * 2, function(r) r:SetDegrees((k % 2 == 0) and 360 or -360) end, false) end
    end
    local body = edge:CreateTexture(nil, "OVERLAY", nil, 1)
    body:SetSize(20, 20)
    if body.SetBlendMode then body:SetBlendMode("ADD") end
    body.sui = true
    edge.body = body
    if ns.SkyLoop then                                       -- the sun's rays turning; the moon's light breathing
        edge.spin = ns:SkyLoop(body, "Rotation", 40, function(r) r:SetDegrees(-360) end, false)
    end
    local function Place()
        local day, along = ns.SkyBody(GameHours())
        body:SetTexture(ns.MEDIA .. (day and "sun_celestial.tga" or "moon_celestial.tga"))
        if day then body:SetVertexColor(1, 0.85, 0.5, 1) else local lt = ns.theme.light; body:SetVertexColor(lt[1], lt[2], lt[3], 1) end
        body:ClearAllPoints()
        body:SetPoint("TOP", Minimap, "TOPLEFT", 14 + along * (W - 28), -(THICK + 1))   -- (inside the top edge, under the marks: clear of the zone's name)
        if edge.spin then                                     -- (only the sun turns; a turning crescent looks wrong)
            if day and ns:Motion() then if not edge.spin:IsPlaying() then edge.spin:Play() end else edge.spin:Stop() end
        end
        edge.day, edge.along = day, along
    end
    Place()
    ns:Every(20, "Minimap sky", function() if edge:IsShown() then Place() end; if ns.CelestialRoundTick then ns:CelestialRoundTick() end end)
    edge.Place = Place
    ns.minimapRunes = edge                                   -- (the square map's frame: hidden when the map is round)
    return edge
end
