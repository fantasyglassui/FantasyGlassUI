local _, ns = ...

------------------------------------------------------------------------------------------
-- Planner travel: how long it takes to get from one place to another, by running, by a known
-- flight, by the hearthstone, or by boat/zeppelin. Flight points are learned at the flight master
-- (per character), flight and crossing times are recorded from real trips (per account).
------------------------------------------------------------------------------------------
ns.PLANNER_SPEED = { run = 7, mount = 11.2, fastMount = 14, flight = 32 }   -- yards per second
ns.PLANNER_HEARTH_SECONDS = 30

local pcall, type, pairs, ipairs, tonumber = pcall, type, pairs, ipairs, tonumber
local sqrt, huge = math.sqrt, math.huge

------------------------------------------------------------------------------------------
-- Crossings. Boats and zeppelins between the towns. The map ids and coordinates below are from
-- memory and MUST be checked in the game before release; the seconds are a ride plus an average
-- wait (270 boats, 240 zeppelins) until a real crossing has been recorded.
------------------------------------------------------------------------------------------
ns.PLANNER_CROSSINGS = {
    { id = "menethil-theramore", a = { map = 1437, x = 4.9, y = 62.0 }, b = { map = 1445, x = 71.5, y = 56.5 }, faction = "Alliance", seconds = 270 },
    { id = "menethil-auberdine", a = { map = 1437, x = 4.9, y = 62.0 }, b = { map = 1439, x = 33.0, y = 40.0 }, faction = "Alliance", seconds = 270 },
    { id = "auberdine-rutheran", a = { map = 1439, x = 33.0, y = 40.0 }, b = { map = 1438, x = 55.0, y = 93.5 }, faction = "Alliance", seconds = 270 },
    { id = "bootybay-ratchet", a = { map = 1434, x = 26.0, y = 73.0 }, b = { map = 1413, x = 63.5, y = 38.5 }, seconds = 270 },
    { id = "orgrimmar-undercity", a = { map = 1411, x = 50.9, y = 13.8 }, b = { map = 1458, x = 60.5, y = 58.5 }, faction = "Horde", seconds = 240 },
    { id = "orgrimmar-gromgol", a = { map = 1411, x = 50.9, y = 13.8 }, b = { map = 1434, x = 31.5, y = 29.5 }, faction = "Horde", seconds = 240 },
    { id = "undercity-gromgol", a = { map = 1458, x = 60.5, y = 58.5 }, b = { map = 1434, x = 31.5, y = 29.5 }, faction = "Horde", seconds = 240 },
}

------------------------------------------------------------------------------------------
-- Positions
------------------------------------------------------------------------------------------
-- continent, worldX, worldY (yards) of a map position (x and y in percent), or nil.
function ns.PlannerWorldPos(map, x, y)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    map, x, y = tonumber(map), tonumber(x), tonumber(y)
    if not (map and x and y) then return nil end
    local ok, continent, p = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x / 100, y / 100))
    if not ok or continent == nil or type(p) ~= "table" then return nil end
    local wx, wy = p.x, p.y
    if wx == nil and p.GetXY then
        local ok2, a, b = pcall(p.GetXY, p)
        if ok2 then wx, wy = a, b end
    end
    wx, wy = tonumber(wx), tonumber(wy)
    if not (wx and wy) then return nil end
    return continent, wx, wy
end
local WorldPos = ns.PlannerWorldPos

-- Where the player stands: map, x, y in percent; nil when it can't be told.
local function PlayerSpot()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local ok, map = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok or type(map) ~= "number" then return nil end
    local ok2, p = pcall(C_Map.GetPlayerMapPosition, map, "player")
    if not ok2 or type(p) ~= "table" or not p.GetXY then return nil end
    local ok3, x, y = pcall(p.GetXY, p)
    x, y = tonumber(x), tonumber(y)
    if not (ok3 and x and y) then return nil end
    return map, x * 100, y * 100
end

local function Dist(c1, x1, y1, c2, x2, y2)
    if c1 ~= c2 then return huge end
    local dx, dy = x1 - x2, y1 - y2
    return sqrt(dx * dx + dy * dy)
end

------------------------------------------------------------------------------------------
-- Saved data (created when first needed; ns.root may be absent early)
------------------------------------------------------------------------------------------
-- Saved tables: read without creating (nil when absent); create = true only when writing.
local function CharData(create)
    if type(ns.root) ~= "table" then return nil end
    local key = ns:CharKey()
    if type(ns.root.planner) ~= "table" then
        if not create then return nil end
        ns.root.planner = {}
    end
    if type(ns.root.planner[key]) ~= "table" then
        if not create then return nil end
        ns.root.planner[key] = {}
    end
    return ns.root.planner[key]
end

local function Account(name, create)
    if type(ns.root) ~= "table" then return nil end
    if type(ns.root[name]) ~= "table" then
        if not create then return nil end
        ns.root[name] = {}
    end
    return ns.root[name]
end

-- A time for a route: the average of the last 5 recordings, so one odd trip can't spoil it.
local function RecordTime(tableName, key, secs)
    local times, samples = Account(tableName, true), Account("plannerTimeSamples", true)
    if not (times and samples) then return end
    local id = tableName .. ":" .. key
    local list = type(samples[id]) == "table" and samples[id] or {}
    list[#list + 1] = secs
    while #list > 5 do table.remove(list, 1) end
    samples[id] = list
    local sum = 0
    for _, v in ipairs(list) do sum = sum + v end
    times[key] = sum / #list
end

function ns.PlannerKnownFlight(node)
    local d = CharData()
    return d ~= nil and type(d.flights) == "table" and d.flights[node] == true
end

local landed, crossed

function ns.PlannerLandedAt(node) return landed ~= nil and landed == node end
function ns.PlannerCrossed(id) return crossed ~= nil and crossed == id end

-- Every flight point seen so far: { node, map, x, y, known } for the planner's ctx.flights.
function ns.PlannerFlightPoints()
    local out, nodes = {}, Account("plannerNodes")
    if not nodes then return out end
    for node, n in pairs(nodes) do
        if type(n) == "table" and n.map then out[#out + 1] = { node = node, map = n.map, x = n.x, y = n.y, known = ns.PlannerKnownFlight(node), name = n.name } end
    end
    return out
end

-- The known flight point nearest to a map position, or nil.
local NEAR = 300   -- yards
local function NearestKnown(map, x, y)
    local c, wx, wy = WorldPos(map, x, y)
    if not c then return nil end
    local best, bestD
    for _, f in ipairs(ns.PlannerFlightPoints()) do
        if f.known then
            local c2, x2, y2 = WorldPos(f.map, f.x, f.y)
            local d = c2 and Dist(c, wx, wy, c2, x2, y2) or huge
            if d <= NEAR and (not bestD or d < bestD) then best, bestD = f.node, d end
        end
    end
    return best
end

-- The flight master's map was opened: every point we can fly from or to is known now.
local function LearnFlights()
    if not (C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and TaxiNodeGetType) then return end
    local map = (GetTaxiMapID and GetTaxiMapID()) or (C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player"))
    local ok, list = pcall(C_TaxiMap.GetAllTaxiNodes, map)
    if not ok or type(list) ~= "table" then return end
    local data, nodes = CharData(true), Account("plannerNodes", true)
    if not data or not nodes then return end
    data.flights = type(data.flights) == "table" and data.flights or {}
    local learned = false
    for i, n in ipairs(list) do
        if type(n) == "table" and n.nodeID then
            local pos = n.position
            if type(pos) == "table" and map and tonumber(pos.x) and tonumber(pos.y) then
                nodes[n.nodeID] = { map = map, x = pos.x * 100, y = pos.y * 100, name = n.name }
            end
            local t = TaxiNodeGetType(n.slotIndex or i)
            if (t == "REACHABLE" or t == "CURRENT") and not data.flights[n.nodeID] then
                data.flights[n.nodeID] = true
                learned = true
            end
        end
    end
    if learned and ns.PlannerReplan then ns.PlannerReplan(ns, "flight") end
end

------------------------------------------------------------------------------------------
-- Recording trips
------------------------------------------------------------------------------------------
local takeoff, dock

local function NearDock(spot, d, radius)
    local c, wx, wy = WorldPos(spot.map, spot.x, spot.y)
    local c2, x2, y2 = WorldPos(d.map, d.x, d.y)
    return c ~= nil and c2 ~= nil and Dist(c, wx, wy, c2, x2, y2) <= radius
end

local function ControlLost()
    if not (UnitOnTaxi and UnitOnTaxi("player")) then return end
    local map, x, y = PlayerSpot()
    takeoff = { node = map and NearestKnown(map, x, y) or nil, time = GetTime() }
end

local function ControlGained()
    local from = takeoff
    takeoff = nil
    if not from then return end                          -- a stun or a fear, not a flight
    local map, x, y = PlayerSpot()
    local node = map and NearestKnown(map, x, y)
    if not node then return end
    landed = node
    if from.node and from.node ~= node then
        local secs = GetTime() - from.time
        if secs > 0 then RecordTime("plannerFlightTimes", from.node .. "-" .. node, secs) end
    end
end

-- Every couple of seconds: which dock are we standing at, and since when?
local function DockTick()
    if not ns:GuideUnlocked() then return end
    local map, x, y = PlayerSpot()
    if not map then return end
    local here = { map = map, x = x, y = y }
    for _, c in ipairs(ns.PLANNER_CROSSINGS) do
        for side = 1, 2 do
            if NearDock(here, side == 1 and c.a or c.b, NEAR) then
                if dock and dock.id == c.id and dock.side == side then
                    if not dock.inside then dock.since, dock.inside = GetTime(), true end
                else
                    dock = { id = c.id, side = side, since = GetTime(), inside = true }
                end
                return
            end
        end
    end
    if dock then dock.inside = false end
end
ns.PlannerDockTick = DockTick

-- Back from a loading screen: are we at the other end of the crossing we waited for?
local function EnteringWorld()
    local from = dock
    if not from then return end
    local map, x, y = PlayerSpot()
    if not map then return end
    for _, c in ipairs(ns.PLANNER_CROSSINGS) do
        if c.id == from.id then
            if NearDock({ map = map, x = x, y = y }, from.side == 1 and c.b or c.a, NEAR) then
                local secs = GetTime() - from.since
                dock = nil
                if secs >= 60 then
                    crossed = c.id
                    RecordTime("plannerCrossTimes", c.id, secs)
                end
            end
            return
        end
    end
end

do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "TAXIMAP_OPENED", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "PLAYER_ENTERING_WORLD" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Planner travel", function(_, event)
        if not ns:GuideUnlocked() then return end
        if event == "TAXIMAP_OPENED" then LearnFlights()
        elseif event == "PLAYER_CONTROL_LOST" then ControlLost()
        elseif event == "PLAYER_CONTROL_GAINED" then ControlGained()
        elseif event == "PLAYER_ENTERING_WORLD" then EnteringWorld() end
    end))
    if ns.Every then ns:Every(2, "Planner docks", DockTick) end
end

------------------------------------------------------------------------------------------
-- Travel time
------------------------------------------------------------------------------------------
local function Spot(p) return { map = p.map, x = p.x, y = p.y } end

local function FlightSeconds(ctx, a, b, d)
    local t = ctx.flightTime and ctx.flightTime(a, b)
    if type(t) ~= "number" or t <= 0 then t = d / ns.PLANNER_SPEED.flight end
    return t
end

-- The cheapest way on one continent: running, run-fly-run, or the hearthstone and a run.
local function Local(from, to, ctx, hearth)
    local c1, x1, y1 = WorldPos(from.map, from.x, from.y)
    local c2, x2, y2 = WorldPos(to.map, to.x, to.y)
    if not c2 then return huge end
    local speed = ctx.speed or ns.PLANNER_SPEED.run
    local best, legs = huge, {}
    local pts = {}
    if c1 == c2 then
        best = Dist(c1, x1, y1, c2, x2, y2) / speed
        legs = { { kind = "run", to = Spot(to), seconds = best } }
    end
    for _, f in ipairs(ctx.flights or {}) do
        if f.known and c1 == c2 then
            local c, x, y = WorldPos(f.map, f.x, f.y)
            if c == c1 then pts[#pts + 1] = { f = f, x = x, y = y } end
        end
    end
    for _, a in ipairs(pts) do
        local toA = Dist(c1, x1, y1, c1, a.x, a.y) / speed
        if toA < best then
            for _, b in ipairs(pts) do
                if a ~= b then
                    local fly = FlightSeconds(ctx, a.f.node, b.f.node, Dist(c1, a.x, a.y, c1, b.x, b.y))
                    local fromB = Dist(c1, b.x, b.y, c1, x2, y2) / speed
                    local total = toA + fly + fromB
                    if total < best then
                        best = total
                        legs = { { kind = "run", to = { map = a.f.map, x = a.f.x, y = a.f.y }, node = a.f.node, seconds = toA },
                                 { kind = "fly", to = { map = b.f.map, x = b.f.x, y = b.f.y }, node = b.f.node, seconds = fly },
                                 { kind = "run", to = Spot(to), seconds = fromB } }
                    end
                end
            end
        end
    end
    if hearth then
        local c, hx, hy = WorldPos(hearth.map, hearth.x, hearth.y)
        if c == c2 then
            local run = Dist(c, hx, hy, c2, x2, y2) / speed
            local total = ns.PLANNER_HEARTH_SECONDS + run
            if total < best then
                best = total
                legs = { { kind = "hearth", to = Spot(hearth), seconds = ns.PLANNER_HEARTH_SECONDS },
                         { kind = "run", to = Spot(to), seconds = run } }
            end
        end
    end
    return best, legs
end

-- seconds, legs. math.huge when there is no way.
function ns.PlannerTravel(from, to, ctx)
    if type(from) ~= "table" or type(to) ~= "table" or type(ctx) ~= "table" then return huge, {} end
    local best, legs = Local(from, to, ctx, ctx.hearth)
    local cross = Account("plannerCrossTimes")
    for _, c in ipairs(ctx.crossings or {}) do
        if c.faction == nil or c.faction == ctx.faction then
            local secs = cross and tonumber(cross[c.id]) or c.seconds or 270
            for dir = 1, 2 do
                local p, q = c.a, c.b
                if dir == 2 then p, q = c.b, c.a end
                -- the ride is only a candidate when it changes the continent, or shortens the way
                local t1, l1 = Local(from, p, ctx, ctx.hearth)
                if t1 < best then
                    local t2, l2 = Local(q, to, ctx, nil)
                    if t1 + secs + t2 < best then
                        best = t1 + secs + t2
                        legs = {}
                        for _, l in ipairs(l1) do legs[#legs + 1] = l end
                        legs[#legs + 1] = { kind = "sail", to = Spot(q), crossing = c.id, seconds = secs }
                        for _, l in ipairs(l2) do legs[#legs + 1] = l end
                    end
                end
            end
        end
    end
    if best == huge then return huge, {} end
    local speed, kept = ctx.speed or ns.PLANNER_SPEED.run, {}
    for _, l in ipairs(legs) do
        if l.kind ~= "run" or l.seconds * speed >= 1 then kept[#kept + 1] = l end   -- no zero-length runs
    end
    return best, kept
end
