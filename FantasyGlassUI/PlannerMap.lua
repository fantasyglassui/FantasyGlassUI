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
        if s.map and s.x and s.y and #out < most then out[#out + 1] = { map = s.map, x = s.x, y = s.y, n = #out + 1, step = s } end
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

local function Now() return tonumber(GetTime and GetTime()) or 0 end

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
    if holder and holder.Hide then holder:Hide() end
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

-- A stop's dot: big enough for its number at every font scale, and its step under the mouse (clicks go to the map).
local function Dot(i)
    local d = dots[i]
    if not d then
        d = CreateFrame("Frame", nil, holder)
        d:SetFrameLevel(holderLevel + 3)
        d.tex = d:CreateTexture(nil, "ARTWORK")
        d.tex:SetAllPoints()
        d.tex:SetTexture(ns.MEDIA .. "dot.tga")
        ns:Paint(d.tex, "SetVertexColor", "@accent", 1)
        d.num = d:CreateFontString(nil, "OVERLAY")
        ns:Font(d.num, 9, true)
        d.num:SetPoint("CENTER")
        d.num:SetTextColor(0, 0, 0)
        if d.SetMouseMotionEnabled and d.SetMouseClickEnabled then
            pcall(d.SetMouseMotionEnabled, d, true)
            pcall(d.SetMouseClickEnabled, d, false)
            d:SetScript("OnEnter", function(self)
                if type(self.step) ~= "table" then return end
                local ok, text = pcall(ns.GuideStepBase, self.step)
                if not (ok and type(text) == "string") then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(ns:AccentHex() .. format("%d. %s", tonumber(self.n) or 0, text) .. "|r", 1, 1, 1, true)
                GameTooltip:Show()
            end)
            d:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        dots[i] = d
    end
    local size = math.max(14, math.ceil(9 * (tonumber(ns.fontScale) or 1)) + 7)
    d:SetSize(size, size)
    return d
end

-- What a hub's tooltip says.
local function HubTip(m)
    return { format(ns:Tr("%s xp an hour"), Num((tonumber(m.rate) or 0) * 3600)),
             m.quests and format(ns:Tr("%d quests"), tonumber(m.quests) or 0) or false,
             ns:Tr("Click: plan from here") }
end
test.tip = HubTip
test.holder = function() return holder end

-- Plan from here: ask once, then plan again with this hub taken first.
function ns.PlannerMapPick(spot)
    if not (ns.GuideUnlocked and ns:GuideUnlocked()) or type(spot) ~= "table" then return nil end
    local w
    local function Close() if w and w.Hide then w:Hide() end end
    local lines = {
        { left = ns:Tr("Plan from here"), action = true, click = function()
            Close()
            ns.plannerFromHere = { map = spot.map, x = spot.x, y = spot.y, at = Now() }
            local ok, refused = ns:PlannerReplan("from here")
            if not ok and not refused then ns:PlannerStart() end    -- (not following: start; a refused replan stays refused)
            if refused then
                ns.plannerFromHere = nil                            -- (and its pick goes: a later plan of your own does not start from it)
                if ns.GuideSaySent then ns.GuideSaySent() end       -- (planning together: your partner plans)
            end
        end },
        { left = ns:Tr("Cancel"), action = true, click = Close },
    }
    local goal = ns.PlannerZoneGoal and ns.PlannerZoneGoal()
    if goal and goal ~= spot.map then lines[#lines + 1] = { left = ns:Tr("Your zone goal resumes after this hub."), tone = "dim", wrap = true } end
    w = ns:ShowList("PlanHere", "Plan from here?", lines, nil, 280, goal and 170 or 140)
    test.window = w
    return w
end

local function Mark(i)
    local m = marks[i]
    if not m then
        m = CreateFrame("Button", nil, holder)
        m:SetSize(24, 24)                                    -- (a 24 click target round a 20 ring)
        m:SetFrameLevel(holderLevel + 1)
        m.back = m:CreateTexture(nil, "BACKGROUND")         -- (a dark disc, so the ring and its digit read on a pale map)
        m.back:SetPoint("TOPLEFT", 3, -3)
        m.back:SetPoint("BOTTOMRIGHT", -3, 3)
        m.back:SetTexture(ns.MEDIA .. "dot.tga")
        m.back:SetVertexColor(0, 0, 0, 0.6)
        m.tex = m:CreateTexture(nil, "ARTWORK")
        m.tex:SetPoint("TOPLEFT", 2, -2)
        m.tex:SetPoint("BOTTOMRIGHT", -2, 2)
        m.tex:SetTexture(ns.MEDIA .. "ring.tga")            -- (a ring in the theme's light: never mistaken for a route stop's accent dot)
        ns:Paint(m.tex, "SetVertexColor", "@light", 1)
        m.tier = m:CreateFontString(nil, "OVERLAY")
        ns:Font(m.tier, 11, true)
        m.tier:SetPoint("CENTER")
        ns:Paint(m.tier, "SetTextColor", "@light")
        if m.RegisterForClicks then m:RegisterForClicks("LeftButtonUp") end
        if m.SetPropagateMouseClicks then pcall(m.SetPropagateMouseClicks, m, true) end     -- (the map's own right-click zoom-out still works over a mark)
        m:SetScript("OnClick", function(self) ns.PlannerMapPick({ map = self.map, x = self.x, y = self.y }) end)
        m:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local tip = HubTip(self)
            GameTooltip:AddLine(ns:AccentHex() .. tip[1] .. "|r")
            if tip[2] then GameTooltip:AddLine(tip[2], 1, 1, 1) end
            local r, g, b = ns:Role("dim")
            GameTooltip:AddLine(tip[3], r, g, b)
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
                        d.n, d.step = s.n, s.step
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
                local here, best, worst, have = {}, nil, nil, {}
                local function Take(hb)
                    local key = tostring(hb.x) .. "," .. tostring(hb.y)
                    if hb.map ~= mapID or not (hb.x and hb.y) or have[key] then return end
                    have[key] = true
                    here[#here + 1] = hb
                    local r = tonumber(hb.rate) or 0
                    if not best or r > best then best = r end
                    if not worst or r < worst then worst = r end
                end
                for _, hb in ipairs(st.summary.hubs) do Take(hb) end
                -- summary.hubs is cut to the best 80: the hubs the plan took are added from summary.taken
                for _, tk in pairs(type(st.summary.taken) == "table" and st.summary.taken or {}) do
                    if type(tk) == "table" then
                        local secs = tonumber(tk.seconds) or 0
                        Take({ map = tk.map, x = tk.x, y = tk.y, rate = secs > 0 and (tonumber(tk.xp) or 0) / secs or 0, quests = tk.quests })
                    end
                end
                for _, hb in ipairs(here) do
                    local r = tonumber(hb.rate) or 0
                    nMarks = nMarks + 1
                    local m = Mark(nMarks)
                    m.map, m.x, m.y, m.rate, m.quests = hb.map, hb.x, hb.y, r, tonumber(hb.quests) or false
                    m.alpha = (best > worst) and (0.55 + 0.45 * (r - worst) / (best - worst)) or 1   -- (the weakest still seen on a yellow map)
                    local rank = 1                                    -- (1 = the best rate on this map)
                    for _, o in ipairs(here) do if (tonumber(o.rate) or 0) > r then rank = rank + 1 end end
                    m.tierText = tostring(math.min(3, floor((rank - 1) * 3 / #here) + 1))    -- (1 the best third: not by brightness alone)
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

local lastSig
local function Signature(canvas, map)
    local id = map.GetMapID and map:GetMapID()
    if type(id) ~= "number" or ns:IsSecret(id) then return nil, nil end
    local scale = canvas.GetScale and canvas:GetScale()
    return id, id .. "|" .. tostring(type(scale) == "number" and scale or 1) .. "|" .. (Following() and "on" or "off")
end
function ns.PlannerMapRedraw()
    local canvas, map = Canvas()
    if not canvas or not (map.IsShown and ns.Yes(map:IsShown())) then return false end
    local id, sig = Signature(canvas, map)
    if not id then return false end
    lastSig = sig
    ns.PlannerMapDraw(id)
    return true
end

-- Every half second while the map is shown: again when the map, its zoom or whether the route is followed changed.
local function Tick()
    local canvas, map = Canvas()
    if not canvas or not (map.IsShown and ns.Yes(map:IsShown())) then lastSig = nil return end
    local id, sig = Signature(canvas, map)
    if id and sig ~= lastSig then ns.PlannerMapRedraw() end
end
test.tick = Tick
ns:Every(0.5, "Planner on the map", Tick)
if ns.GuideRegisterAdvance then ns.GuideRegisterAdvance("map", function() ns.PlannerMapRedraw() end) end

------------------------------------------------------------------------------------------
-- Plan from here, through the planner's hooks: the map the hub is on, the hub taken first, once.
------------------------------------------------------------------------------------------
-- The pick is used by the next plan that applies (the "applied" hook drops it, used or not). Until then it
-- waits: while a plan is queued or being made, or you are in combat (no plan is made then), it does not age;
-- a pick that waited 120 s with nothing queued and out of combat is dropped.
ns.PLANNER_FROM_HERE_SECONDS = 120
local function Waiting()
    if ns.plannerQueued or ns.plannerBusy then return true end
    return InCombatLockdown and InCombatLockdown() and true or false
end
-- Add the time since the last look to the pick's idle time (only when nothing waits for a plan); true when too old.
local function Aged(from)
    local now = Now()
    local last = tonumber(from.last) or tonumber(from.at) or now
    if not Waiting() then from.idle = (tonumber(from.idle) or 0) + math.max(0, now - last) end
    from.last = now
    return (tonumber(from.idle) or 0) > ns.PLANNER_FROM_HERE_SECONDS
end
local function FromHere()
    local from = ns.plannerFromHere
    if type(from) ~= "table" then return nil end
    if not (ns.GuideUnlocked and ns:GuideUnlocked()) or Aged(from) then
        ns.plannerFromHere = nil
        return nil
    end
    return from
end
test.fromHere = FromHere
ns:Every(1, "Planner pick", function() if ns.plannerFromHere then FromHere() end end)
ns.PlannerHook("zone", "map", function()
    local from = FromHere()
    if from then return from.map end
end)
ns.PlannerHook("rank", "map", function(ranked, _, info)
    local from = FromHere()
    if not from then return end
    local fc, fx, fy
    if ns.PlannerWorldPos then fc, fx, fy = ns.PlannerWorldPos(from.map, from.x, from.y) end
    local r2 = ns.PLANNER_HUB_YARDS * ns.PLANNER_HUB_YARDS
    for _, e in ipairs(ranked) do
        if e.lead then
            e.score = -1                                      -- (no detour on the way to the hub you picked)
        elseif info.round == 1 and e.hub and e.hub.map == from.map then
            local near = math.abs((tonumber(e.hub.x) or -99) - (tonumber(from.x) or 99)) <= 0.051     -- (a mark's place is the hub's to 0.1)
                and math.abs((tonumber(e.hub.y) or -99) - (tonumber(from.y) or 99)) <= 0.051
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
