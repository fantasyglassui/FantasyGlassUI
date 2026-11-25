local _, ns = ...

------------------------------------------------------------------------------------------
-- Planner, batch 4 group A: the route on the world map and the hubs on the map (Task 2).
-- Built on the seams: ns.PlannerHook (Planner.lua), the panel's registries (Guide.lua) and its
-- section of the Guide tab (Bars.lua). Everything here is behind ns:GuideUnlocked().
-- The route: the dots and line of the current hub's loop and the trip to the next. The hubs: a
-- mark on each hub the planner worked out on the map shown, brighter the better its rate, and a
-- click on one plans from there (once).
------------------------------------------------------------------------------------------
local floor = math.floor

-- The steps the map line covers, from step `at`: every step of its hub, then the steps up to and
-- including the first placed step of the next hub. Only steps with a place; at most 30.
ns.PLANNER_MAP_STOPS = 30
function ns.PlannerMapStops(steps, at)
    local out = {}
    if type(steps) ~= "table" then return out end
    local i = tonumber(at) or 1
    local first = steps[i]
    if type(first) ~= "table" then return out end
    local hub, most = first.hub, ns.PLANNER_MAP_STOPS
    local function Add(s)
        if s.map and s.x and s.y and #out < most then out[#out + 1] = { map = s.map, x = s.x, y = s.y, n = #out + 1 } end
    end
    while type(steps[i]) == "table" and steps[i].hub == hub and #out < most do
        Add(steps[i])
        i = i + 1
    end
    while type(steps[i]) == "table" and #out < most do
        local s = steps[i]
        if s.map and s.x and s.y then
            Add(s)
            if s.hub ~= nil then break end              -- (the first placed step of the next hub ends the trip)
        end
        i = i + 1
    end
    return out
end

local function Switch(key) return ns.db and ns.db[key] ~= false end

-- Is there a planned route to draw: unlocked, following the planned guide, out of combat.
local function Following()
    if not (ns.GuideUnlocked and ns:GuideUnlocked() and ns.GuideOn and ns:GuideOn()) then return nil end
    if InCombatLockdown and InCombatLockdown() then return nil end
    local st = ns.GuideState and ns.GuideState()
    if type(st) ~= "table" or st.name == nil or st.name ~= ns.GUIDE_PLANNED then return nil end
    local guide = ns:GuideGet(st.name)
    if type(guide) ~= "table" or type(guide.steps) ~= "table" then return nil end
    return st, guide
end

local function Canvas()
    local map = _G.WorldMapFrame
    local canvas = type(map) == "table" and ((map.ScrollContainer and map.ScrollContainer.Child) or (map.GetCanvas and map:GetCanvas()))
    if type(canvas) ~= "table" or not canvas.GetWidth then return nil end
    return canvas, map
end

local function Num(n)
    n = floor((tonumber(n) or 0) + 0.5)
    if type(BreakUpLargeNumbers) == "function" then
        local ok, s = pcall(BreakUpLargeNumbers, n)
        if ok and type(s) == "string" and s:match("^[%d%.,%s]+$") then return s end
    end
    local s = tostring(n)
    while true do
        local t, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        s = t
        if k == 0 then break end
    end
    return s
end

------------------------------------------------------------------------------------------
-- The drawing: one holder over the canvas (scaled so a dot is the same size at every zoom), a pool
-- of lines, of numbered dots and of hub marks.
------------------------------------------------------------------------------------------
local holder, holderCanvas, holderLevel = nil, nil, 1
local lines, dots, marks = {}, {}, {}
local test = { lines = lines, dots = dots, marks = marks }
ns.PlannerMapTest = test

local function Holder(canvas)
    if holder and holderCanvas == canvas then return holder end
    holder = CreateFrame("Frame", nil, canvas)
    holderCanvas = canvas
    holder:SetSize(1, 1)
    holder:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, 0)
    holderLevel = (tonumber(canvas:GetFrameLevel()) or 1) + 18
    holder:SetFrameLevel(holderLevel)
    lines, dots, marks = {}, {}, {}
    test.lines, test.dots, test.marks = lines, dots, marks
    return holder
end

local function Line(i)
    local l = lines[i]
    if not l then
        l = holder:CreateLine(nil, "OVERLAY")
        l:SetThickness(3)
        l:SetTexture(ns.FLAT)
        ns:Paint(l, "SetVertexColor", "@accent", 0.9)
        lines[i] = l
    end
    return l
end

local function Dot(i)
    local d = dots[i]
    if not d then
        d = CreateFrame("Frame", nil, holder)
        d:SetSize(14, 14)
        d:SetFrameLevel(holderLevel + 3)
        d.tex = d:CreateTexture(nil, "ARTWORK")
        d.tex:SetAllPoints()
        d.tex:SetTexture(ns.MEDIA .. "dot.tga")
        ns:Paint(d.tex, "SetVertexColor", "@accent", 1)
        d.num = d:CreateFontString(nil, "OVERLAY")
        ns:Font(d.num, 9, true)
        d.num:SetPoint("CENTER")
        d.num:SetTextColor(0, 0, 0)
        dots[i] = d
    end
    return d
end

-- What a hub's tooltip says.
local function HubTip(m)
    return { format(ns:Tr("%s xp an hour"), Num((tonumber(m.rate) or 0) * 3600)),
             format(ns:Tr("%d quests"), tonumber(m.quests) or 0),
             ns:Tr("Click: plan from here") }
end
test.tip = HubTip

-- Plan from here: ask once, then plan again with this hub taken first.
function ns.PlannerMapPick(spot)
    if not (ns.GuideUnlocked and ns:GuideUnlocked()) or type(spot) ~= "table" then return nil end
    local w
    local function Close() if w and w.Hide then w:Hide() end end
    w = ns:ShowList("PlanHere", "Plan from here?", {
        { left = ns:Tr("Plan from here"), click = function()
            Close()
            ns.plannerFromHere = { map = spot.map, x = spot.x, y = spot.y }
            if not ns:PlannerReplan("from here") then ns:PlannerStart() end
        end },
        { left = ns:Tr("Cancel"), click = Close },
    }, nil, 260, 130)
    test.window = w
    return w
end

local function Mark(i)
    local m = marks[i]
    if not m then
        m = CreateFrame("Button", nil, holder)
        m:SetSize(20, 20)
        m:SetFrameLevel(holderLevel + 1)
        m.tex = m:CreateTexture(nil, "ARTWORK")
        m.tex:SetAllPoints()
        m.tex:SetTexture(ns.MEDIA .. "dot.tga")
        m.tex:SetVertexColor(1, 0.82, 0.2, 1)
        m.tier = m:CreateFontString(nil, "OVERLAY")
        ns:Font(m.tier, 11, true)
        m.tier:SetPoint("CENTER")
        m.tier:SetTextColor(0, 0, 0)
        if m.RegisterForClicks then m:RegisterForClicks("LeftButtonUp") end
        m:SetScript("OnClick", function(self) ns.PlannerMapPick({ map = self.map, x = self.x, y = self.y }) end)
        m:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local tip = HubTip(self)
            GameTooltip:AddLine(tip[1], 1, 0.82, 0.2)
            GameTooltip:AddLine(tip[2], 1, 1, 1)
            GameTooltip:AddLine(tip[3], 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        m:SetScript("OnLeave", function() GameTooltip:Hide() end)
        marks[i] = m
    end
    return m
end

-- Draw the route and the hubs of the map `mapID`. Returns how many lines, hub marks and stop dots are
-- shown. Nothing unless unlocked, following the planned guide and out of combat.
function ns.PlannerMapDraw(mapID)
    local nLines, nMarks, nDots = 0, 0, 0
    local canvas = Canvas()
    if canvas then
        local w, h = canvas:GetWidth(), canvas:GetHeight()
        local st, guide = Following()
        if st and guide and type(mapID) == "number" and not ns:IsSecret(mapID) and type(w) == "number" and type(h) == "number" then
            Holder(canvas)
            local scale = canvas.GetScale and canvas:GetScale() or 1
            local size = (type(scale) == "number" and scale > 0) and (1 / scale) or 1
            holder:SetScale(size)
            holder:Show()
            local function At(x, y) return ns.MapDotOffset(x / 100, y / 100, w, h, size) end
            if Switch("plannerMapLine") then
                local prev
                for _, s in ipairs(ns.PlannerMapStops(guide.steps, st.at)) do
                    if s.map == mapID then
                        nDots = nDots + 1
                        local d = Dot(nDots)
                        d:ClearAllPoints()
                        d:SetPoint("CENTER", holder, "TOPLEFT", At(s.x, s.y))
                        d.num:SetText(s.n)
                        d:Show()
                        if prev then
                            nLines = nLines + 1
                            local l = Line(nLines)
                            local ax, ay = At(prev.x, prev.y)
                            local bx, by = At(s.x, s.y)
                            l:SetStartPoint("TOPLEFT", holder, ax, ay)
                            l:SetEndPoint("TOPLEFT", holder, bx, by)
                            l:Show()
                        end
                        prev = s
                    else
                        prev = nil
                    end
                end
            end
            if Switch("plannerMapHubs") and type(st.summary) == "table" and type(st.summary.hubs) == "table" then
                local here, best, worst = {}, nil, nil
                for _, hb in ipairs(st.summary.hubs) do
                    if hb.map == mapID and hb.x and hb.y then
                        here[#here + 1] = hb
                        local r = tonumber(hb.rate) or 0
                        if not best or r > best then best = r end
                        if not worst or r < worst then worst = r end
                    end
                end
                local vision = ns:ColorVision()
                for _, hb in ipairs(here) do
                    local r = tonumber(hb.rate) or 0
                    nMarks = nMarks + 1
                    local m = Mark(nMarks)
                    m.map, m.x, m.y, m.rate, m.quests = hb.map, hb.x, hb.y, r, hb.quests
                    m.alpha = (best > worst) and (0.35 + 0.65 * (r - worst) / (best - worst)) or 1
                    local rank = 1                                    -- (1 = the best rate on this map)
                    for _, o in ipairs(here) do if (tonumber(o.rate) or 0) > r then rank = rank + 1 end end
                    m.tierText = vision and tostring(math.min(3, floor((rank - 1) * 3 / #here) + 1)) or ""
                    m.tier:SetText(m.tierText)
                    m:SetAlpha(m.alpha)
                    m:ClearAllPoints()
                    m:SetPoint("CENTER", holder, "TOPLEFT", At(hb.x, hb.y))
                    m:Show()
                end
            end
        end
    end
    for i = nLines + 1, #lines do lines[i]:Hide() end
    for i = nDots + 1, #dots do dots[i]:Hide() end
    for i = nMarks + 1, #marks do marks[i]:Hide() end
    return nLines, nMarks, nDots
end

local lastMap
function ns.PlannerMapRedraw()
    local canvas, map = Canvas()
    if not canvas or not (map.IsShown and ns.Yes(map:IsShown())) then return false end
    local id = map.GetMapID and map:GetMapID()
    if type(id) ~= "number" or ns:IsSecret(id) then return false end
    lastMap = id
    ns.PlannerMapDraw(id)
    return true
end

ns:Every(0.5, "Planner on the map", function()
    local canvas, map = Canvas()
    if not canvas or not (map.IsShown and ns.Yes(map:IsShown())) then lastMap = nil return end
    local id = map.GetMapID and map:GetMapID()
    if id ~= lastMap and type(id) == "number" and not ns:IsSecret(id) then ns.PlannerMapRedraw() end
end)
if ns.GuideRegisterAdvance then ns.GuideRegisterAdvance("map", function() ns.PlannerMapRedraw() end) end

------------------------------------------------------------------------------------------
-- Plan from here, through the planner's hooks: the map the hub is on, the hub taken first, once.
------------------------------------------------------------------------------------------
ns.PlannerHook("zone", "map", function()
    local from = ns.plannerFromHere
    if type(from) == "table" and ns.GuideUnlocked and ns:GuideUnlocked() then return from.map end
end)
ns.PlannerHook("rank", "map", function(ranked, _, info)
    local from = ns.plannerFromHere
    if type(from) ~= "table" or not (ns.GuideUnlocked and ns:GuideUnlocked()) then return end
    local fc, fx, fy
    if ns.PlannerWorldPos then fc, fx, fy = ns.PlannerWorldPos(from.map, from.x, from.y) end
    local r2 = ns.PLANNER_HUB_YARDS * ns.PLANNER_HUB_YARDS
    for _, e in ipairs(ranked) do
        if e.lead then
            e.score = -1                                      -- (no detour on the way to the hub you picked)
        elseif info.round == 1 and e.hub and e.hub.map == from.map then
            local near = e.hub.x == from.x and e.hub.y == from.y
            if not near and fc and ns.PlannerWorldPos then
                local c, x, y = ns.PlannerWorldPos(e.hub.map, e.hub.x, e.hub.y)
                near = c == fc and (x - fx) ^ 2 + (y - fy) ^ 2 <= r2
            end
            if near then e.first = 3 end
        end
    end
end)
ns.PlannerHook("applied", "map", function()
    ns.plannerFromHere = nil
    ns.PlannerMapRedraw()
end)
