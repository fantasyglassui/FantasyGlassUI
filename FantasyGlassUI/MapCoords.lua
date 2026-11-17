local _, ns = ...

-- Coordinates on the world map: where you are, and where the mouse is pointing, in the bottom left
-- corner of the map. Both are for the map being looked at, so if you are viewing another zone
-- there is no "you" to show.
function ns.MapCoordsText(px, py, cx, cy)
    local parts = {}
    if type(px) == "number" and type(py) == "number" then
        parts[#parts + 1] = ns:Tr("You") .. "  " .. format("%.1f, %.1f", px * 100, py * 100)
    end
    if type(cx) == "number" and type(cy) == "number" and cx >= 0 and cx <= 1 and cy >= 0 and cy <= 1 then
        parts[#parts + 1] = ns:Tr("Cursor") .. "  " .. format("%.1f, %.1f", cx * 100, cy * 100)
    end
    return table.concat(parts, "      ")
end

ns:NewModule("mapCoords", function()
    local map = _G.WorldMapFrame
    if type(map) ~= "table" or not ns:Usable(map) or not (C_Map and C_Map.GetPlayerMapPosition) then return end
    local canvas = (type(map.ScrollContainer) == "table" and ns:Usable(map.ScrollContainer)) and map.ScrollContainer or map

    local f = CreateFrame("Frame", "FantasyGlassUIMapCoords", map)
    f:SetSize(300, 18)
    f:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", 8, 6)
    f:SetFrameLevel((canvas:GetFrameLevel() or 1) + 30)
    f.text = ns:NewText(f, 12, "LEFT")
    f.text:SetPoint("LEFT", 0, 0)
    f.text:SetTextColor(1, 1, 1)
    if f.text.SetShadowOffset then f.text:SetShadowOffset(1, -1); f.text:SetShadowColor(0, 0, 0, 1) end

    local function Player()
        local id = map.GetMapID and map:GetMapID()
        if type(id) ~= "number" or ns:IsSecret(id) then return end
        local ok, pos = pcall(C_Map.GetPlayerMapPosition, id, "player")
        if not ok or type(pos) ~= "table" or not pos.GetXY then return end       -- (not on this map, or hidden in an instance)
        local x, y = pos:GetXY()
        if ns:IsSecret(x) or ns:IsSecret(y) then return end
        return x, y
    end
    local function Cursor()
        if canvas == map or not canvas.GetNormalizedCursorPosition then return end
        local okO, over = pcall(canvas.IsMouseOver, canvas)
        if not okO or not over then return end
        local ok, x, y = pcall(canvas.GetNormalizedCursorPosition, canvas)
        if ok and not ns:IsSecret(x) and not ns:IsSecret(y) then return x, y end
    end
    local acc = 0
    f:SetScript("OnUpdate", ns:Guard("Map coordinates", function(_, elapsed)
        acc = acc + (tonumber(elapsed) or 0)
        if acc < 0.1 then return end
        acc = 0
        local px, py = Player()
        local cx, cy = Cursor()
        f.text:SetText(ns.MapCoordsText(px, py, cx, cy))
    end))
end)
