local _, ns = ...

------------------------------------------------------------------------------------------
-- Planner route: hubs, the zone to go to, and the route as guide steps; the live game as the
-- planner's ctx. Scoring (experience, time, candidates) is in Planner.lua.
------------------------------------------------------------------------------------------
local ipairs, pairs, type, tonumber, math = ipairs, pairs, type, tonumber, math
local floor, min, max, sqrt = math.floor, math.min, math.max, math.sqrt
local PaceRecord = function(create) return ns.PlannerCharRecord(create) end
local format = string.format

------------------------------------------------------------------------------------------
-- Hubs: givers and hand-ins close together on one map. A hub's loop is: pick up, do the objectives
-- in a sweep (nearest next), hand in. Inside a hub the walking is counted at run speed in a straight
-- line; the full travel (flights, the hearthstone, boats) is only worked out between hubs.
------------------------------------------------------------------------------------------
ns.PLANNER_HUB_YARDS = 150
ns.PLANNER_HORIZON = 2
ns.PLANNER_LEARN_SECONDS = 120
ns.PLANNER_REPICK_LEVELS = 3

local huge = math.huge
local HANDLE = 5                        -- seconds to talk to a giver and take or hand in a quest

local function Pos(s)
    if type(s) ~= "table" then return nil end
    return ns.PlannerWorldPos(s.map, s.x, s.y)
end

-- Straight-line yards between two spots (math.huge on different continents or unplaceable).
local function Yards(a, b)
    local c1, x1, y1 = Pos(a)
    local c2, x2, y2 = Pos(b)
    if not c1 or c1 ~= c2 then return huge end
    local dx, dy = x1 - x2, y1 - y2
    return sqrt(dx * dx + dy * dy)
end

local function Speed(ctx) return tonumber(ctx.speed) or ns.PLANNER_SPEED.run end

-- The spot of a list nearest to `from` (only spots that can be placed).
local function Nearest(list, from)
    local best, bestD
    for _, s in ipairs(list or {}) do
        local d = from and Yards(from, s) or (Pos(s) and 0 or huge)
        if d < huge and (not bestD or d < bestD) then best, bestD = s, d end
    end
    return best
end

-- Order items { spot = ... } nearest-next starting at `from`; items without a spot go last, in order.
local function Sweep(items, from)
    local left, out, placeless = {}, {}, {}
    for _, it in ipairs(items) do
        if it.spot then left[#left + 1] = it else placeless[#placeless + 1] = it end
    end
    local at = from
    while #left > 0 do
        ns.PlannerYield()
        local bi, bd = 1, huge
        for i, it in ipairs(left) do
            local d = at and Yards(at, it.spot) or 0
            if d < bd then bi, bd = i, d end
        end
        local it = table.remove(left, bi)
        out[#out + 1] = it
        at = it.spot
    end
    for _, it in ipairs(placeless) do out[#out + 1] = it end
    return out
end

local function Walk(a, b, ctx)
    if not (a and b) then return 0 end
    local d = Yards(a, b)
    return d < huge and d / Speed(ctx) or 0
end

-- Where the quest's place in a hub is: its giver (when it is still to be picked up), else its hand-in.
local function Anchor(rec, ctx)
    local onQuest = ctx.onQuest and ctx.onQuest(rec.id)
    if not onQuest then
        local s = Nearest(rec.starts)
        if s then return s, true end
    end
    return Nearest(rec.ends), false
end

-- The objective spot to go to for a quest: the one nearest `from`.
local function DoSpot(rec, from)
    local spots = {}
    for _, o in ipairs(rec.objectives or {}) do
        for _, s in ipairs(o.spots or {}) do spots[#spots + 1] = s end
    end
    return Nearest(spots, from)
end

-- Is this quest one with a clock on it? In your log: the game gives it a time limit. Not yet taken: a time
-- is known for it (ns.PlannerTimedQuest, PlannerSource.lua, when there: seconds or nil).
local function IsTimed(ctx, q)
    if ctx.onQuest and ctx.onQuest(q.id) then
        return type(ctx.timed) == "function" and ctx.timed(q.id) and true or false
    end
    local known = ns.PlannerTimedQuest
    if type(known) ~= "function" then return false end
    local ok, seconds = pcall(known, q.id)
    seconds = ok and tonumber(seconds) or nil
    return seconds ~= nil and seconds > 0
end
function ns.PlannerIsEscort(q) return (type(q) == "table" and (q.escort or (ns.PLANNER_ESCORTS and ns.PLANNER_ESCORTS[q.id]))) and true or false end
local IsEscort = ns.PlannerIsEscort

-- Lower what is still needed of each wanted faction (ctx.repLeft) by what a quest gives.
local function DrawRep(ctx, q)
    local goals = ctx.repGoals
    if type(goals) ~= "table" or type(q.reputation) ~= "table" then return end
    for _, e in ipairs(q.reputation) do
        local value = tonumber(e[2])
        if goals[e[1]] and value then
            local left = ns.PlannerRepLeft(ctx, e[1], goals[e[1]])      -- (the pool of this faction: the plan never credits more than is needed)
            if left then
                if type(ctx.repLeft) ~= "table" then ctx.repLeft = {} end
                ctx.repLeft[e[1]] = max(0, left - value)
            end
        end
    end
end

-- Is a quest handed in out of the hub's reach (every hand-in that can be placed lies on another continent)? Then it is
-- not this hub's: no hand-in step, and none of its experience or time (its accept and objectives may still be on
-- the way; a later plan takes you to where it is handed in). A quest with no hand-in that can be placed is not.
local function HandedInAway(q, hub) return Nearest(q.ends, hub) == nil and Nearest(q.ends) ~= nil end

-- A hub's loop, in order, with its time: accepts, dos and turnins as { rec, spot }. A quest with a clock
-- on it is a run of its own (accept if not yet, do, hand in) before anything else in the hub (hub.timed).
local function HubLoop(hub, ctx)
    local accepts, dos, turnins, timed, runs, rest = {}, {}, {}, {}, {}, {}
    local xp, t = 0, 0
    local wanted = type(ctx.repGoals) == "table" and next(ctx.repGoals) ~= nil
    local before = ctx.repLeft                       -- (two quests of one faction in a hub share what is still needed)
    if wanted then
        local copy = {}
        for k, v in pairs(type(before) == "table" and before or {}) do copy[k] = v end
        ctx.repLeft = copy
    end
    local away = {}
    for _, q in ipairs(hub.quests) do
        if HandedInAway(q, hub) then away[q.id] = true end
        if not away[q.id] then
            xp = xp + ns.PlannerQuestXP(q, ctx)
            if wanted then DrawRep(ctx, q) end
            t = t + ns.PlannerQuestTime(q, ctx)
        end
        if IsTimed(ctx, q) then timed[#timed + 1] = q else rest[#rest + 1] = q end
    end
    if wanted then ctx.repLeft = before end
    local base = hub
    for _, q in ipairs(timed) do
        local run = { rec = q }
        if hub.take[q.id] then
            run.accept = Nearest(q.starts, base)
            if run.accept then t = t + Walk(base, run.accept, ctx); base = run.accept end
            t = t + HANDLE
        end
        if #(q.objectives or {}) > 0 then
            run.spot = DoSpot(q, base)
            if run.spot then t = t + Walk(base, run.spot, ctx); base = run.spot end
        end
        run.turnin = Nearest(q.ends, base)
        if run.turnin then t = t + Walk(base, run.turnin, ctx); base = run.turnin end
        t = t + HANDLE
        runs[#runs + 1] = run
    end
    local held = {}                                  -- (an item in your bags starts it where you stand: that comes first)
    for _, q in ipairs(rest) do
        if hub.take[q.id] then
            local e = { rec = q, spot = Nearest(q.starts, hub) }
            if q.haveItem then held[#held + 1] = e else accepts[#accepts + 1] = e end
        end
    end
    accepts = Sweep(accepts, base)
    for i = #held, 1, -1 do table.insert(accepts, 1, held[i]) end
    local at = accepts[1] and accepts[1].spot or base
    for _, a in ipairs(accepts) do t = t + Walk(at, a.spot, ctx) + HANDLE; at = a.spot end
    for _, q in ipairs(rest) do
        if #(q.objectives or {}) > 0 then dos[#dos + 1] = { rec = q, spot = DoSpot(q, hub) } end
    end
    dos = Sweep(dos, at)
    for _, d in ipairs(dos) do
        if d.spot then t = t + Walk(at, d.spot, ctx); at = d.spot end
    end
    for _, q in ipairs(rest) do
        if not away[q.id] then turnins[#turnins + 1] = { rec = q, spot = Nearest(q.ends, at) } end
    end
    turnins = Sweep(turnins, at)
    for _, e in ipairs(turnins) do
        if e.spot then t = t + Walk(at, e.spot, ctx); at = e.spot end
        t = t + HANDLE
    end
    hub.accepts, hub.dos, hub.turnins, hub.timed, hub.last, hub.away = accepts, dos, turnins, runs, at, away
    hub.xp, hub.seconds = xp, max(t, 1)
end

-- The level you died at when two deaths at that level or the one before lie within a hub's radius of
-- it (in the world: a cave or town map over the hub counts too) and you are still below that level + 2; nil otherwise. ctx.deaths = { { level, map, x, y } }.
function ns.PlannerHubTooHard(hub, ctx)
    local deaths, level = type(ctx) == "table" and ctx.deaths, type(ctx) == "table" and tonumber(ctx.level)
    if type(deaths) ~= "table" or not level or type(hub) ~= "table" then return nil end
    local c, hx, hy = Pos(hub)
    if not c then return nil end
    local pos = ctx.deathPos
    if type(pos) ~= "table" then
        pos = {}
        for i, d in ipairs(deaths) do
            ns.PlannerYield()
            if type(d) == "table" then
                local dc, dx, dy = ns.PlannerWorldPos(d.map, d.x, d.y)
                if dc then pos[i] = { c = dc, x = dx, y = dy } end
            end
        end
        ctx.deathPos = pos
    end
    local r2, near = ns.PLANNER_HUB_YARDS * ns.PLANNER_HUB_YARDS, {}
    for i, d in ipairs(deaths) do
        ns.PlannerYield()
        local p = pos[i]
        local lv = type(d) == "table" and tonumber(d.level)
        if p and lv and p.c == c and (p.x - hx) ^ 2 + (p.y - hy) ^ 2 <= r2 then near[lv] = (near[lv] or 0) + 1 end
    end
    local best
    for lv, n in pairs(near) do
        if n + (near[lv - 1] or 0) >= 2 and level < lv + 2 and (not best or lv > best) then best = lv end
    end
    return best
end

-- Single-link clustering of givers and hand-ins within PLANNER_HUB_YARDS on the same map.
function ns.PlannerHubs(candidates, ctx)
    ctx = ctx or {}
    local pts, parent = {}, {}
    local function Find(i)
        while parent[i] ~= i do parent[i] = parent[parent[i]]; i = parent[i] end
        return i
    end
    local anchorOf = {}
    for _, rec in ipairs(candidates or {}) do
        ns.PlannerYield()
        local spot, take = Anchor(rec, ctx)
        local c, x, y = Pos(spot)
        if c then
            pts[#pts + 1] = { map = spot.map, c = c, x = x, y = y, spot = spot }
            parent[#pts] = #pts
            anchorOf[#anchorOf + 1] = { rec = rec, i = #pts, take = take, spot = spot }
            local fin = Nearest(rec.ends, spot)
            local c2, x2, y2 = Pos(fin)
            if c2 and fin.map == spot.map then
                pts[#pts + 1] = { map = fin.map, c = c2, x = x2, y = y2, spot = fin }
                parent[#pts] = #pts
            end
        end
    end
    local r2 = ns.PLANNER_HUB_YARDS * ns.PLANNER_HUB_YARDS
    for i = 1, #pts do
        ns.PlannerYield()
        local a = pts[i]
        for j = i + 1, #pts do
            local b = pts[j]
            if a.map == b.map then
                local dx, dy = a.x - b.x, a.y - b.y
                if dx * dx + dy * dy <= r2 then
                    local ri, rj = Find(i), Find(j)
                    if ri ~= rj then parent[ri] = rj end
                end
            end
        end
    end
    local byRoot, hubs = {}, {}
    for _, a in ipairs(anchorOf) do
        local root = Find(a.i)
        local hub = byRoot[root]
        if not hub then
            hub = { map = pts[a.i].map, quests = {}, take = {}, anchors = {}, sx = 0, sy = 0 }
            byRoot[root] = hub
            hubs[#hubs + 1] = hub
        end
        hub.quests[#hub.quests + 1] = a.rec
        hub.take[a.rec.id] = a.take or nil
        hub.anchors[a.rec.id] = a.spot
        hub.sx, hub.sy = hub.sx + pts[a.i].spot.x, hub.sy + pts[a.i].spot.y
    end
    for _, hub in ipairs(hubs) do
        ns.PlannerYield()
        hub.x, hub.y = hub.sx / #hub.quests, hub.sy / #hub.quests
        hub.sx, hub.sy = nil, nil
        HubLoop(hub, ctx)
    end
    if type(ctx.deaths) == "table" and #ctx.deaths > 0 then          -- (a hub where you died twice keeps only the quests already in your log, or is left out)
        local kept = {}
        ctx.movedByMap = ctx.movedByMap or {}
        for _, hub in ipairs(hubs) do
            local d = ns.PlannerHubTooHard(hub, ctx)
            if d then
                local logged = {}
                for _, r in ipairs(hub.quests) do if ctx.onQuest and ctx.onQuest(r.id) then logged[#logged + 1] = r end end
                if #logged < #hub.quests then
                    if not ctx.movedByMap[hub.map] or d + 2 > ctx.movedByMap[hub.map] then ctx.movedByMap[hub.map] = d + 2 end
                end
                if #logged > 0 then
                    hub.quests = logged
                    local sx, sy, n = 0, 0, 0                  -- (its place: where the quests it keeps are)
                    for _, r in ipairs(logged) do
                        local sp = hub.anchors[r.id]
                        if sp and sp.map == hub.map then sx, sy, n = sx + sp.x, sy + sp.y, n + 1 end
                    end
                    if n > 0 then hub.x, hub.y = sx / n, sy / n end
                    HubLoop(hub, ctx)
                    kept[#kept + 1] = hub
                end
            else
                kept[#kept + 1] = hub
            end
        end
        hubs = kept
    end
    local classMap = ns.PlannerClassMap(ctx)          -- (an "always" class quest, or a quest whose item you hold: its hub is planned first, never choosing the zone)
    for _, hub in ipairs(hubs) do
        for _, q in ipairs(hub.quests) do
            local e = classMap[q.id]
            if q.haveItem then hub.first = 2 elseif e and e.kind == "always" and not hub.first then hub.first = 1 end
        end
    end
    return hubs
end

-- The context with ctx.candidate filled in (a follow-up quest counts when it is itself a candidate).
local function WithCandidates(ctx, candidates)
    local byId = {}
    for _, r in ipairs(candidates) do byId[r.id] = r end
    local c = {}
    for k, v in pairs(ctx) do c[k] = v end
    c.candidate = function(id) return byId[id] end
    return c
end

local function Rate(h) return h.xp / h.seconds end

-- Each map's hubs, best first.
local function ByMap(hubs)
    local maps, order = {}, {}
    for _, h in ipairs(hubs) do
        if not maps[h.map] then maps[h.map] = {}; order[#order + 1] = h.map end
        local list = maps[h.map]
        list[#list + 1] = h
    end
    for _, m in ipairs(order) do table.sort(maps[m], function(a, b) return Rate(a) > Rate(b) end) end
    return maps, order
end

local function Here(ctx)
    local h = ctx.here
    if type(h) == "table" and h.map and h.x and h.y then return h end
end

-- map, newlyPicked, hubs. The best map by (xp of its best hubs) / (their seconds + travel there).
function ns.PlannerPickZone(candidates, ctx)
    ctx = ctx or {}
    local c = ctx.candidate and ctx or WithCandidates(ctx, candidates or {})
    local hubs = ns.PlannerHubs(candidates, c)
    local maps, order = ByMap(hubs)
    local last, here = ctx.lastZone, Here(ctx)       -- (a hub planned first never chooses the zone: Build takes it as a lead-in)
    for _, h in ipairs(ns.PlannerHooksFor(c, "zone")) do  -- (another file's choice: the first map it names that has hubs)
        local m = h.fn(maps, order, c)
        if m ~= nil and maps[m] and #maps[m] > 0 then return m, m ~= last, hubs end
    end
    if last and maps[last] and not (ctx.lastZoneLevel and (ctx.level or 0) >= ctx.lastZoneLevel + ns.PLANNER_REPICK_LEVELS)
        and (not here or ns.PlannerTravel(here, maps[last][1], c) < huge) then
        return last, false, hubs
    end
    local best, bestScore = nil, -1
    for _, m in ipairs(order) do
        ns.PlannerYield()
        local list, xp, t = maps[m], 0, 0
        for i = 1, min(ns.PLANNER_HORIZON, #list) do xp, t = xp + list[i].xp, t + list[i].seconds end
        local travel = 0
        if here then travel = ns.PlannerTravel(here, list[1], c) end
        if travel < huge then
            local score = xp / (t + travel)
            if score > bestScore then best, bestScore = m, score end
        end
    end
    return best, best ~= nil and best ~= last, hubs
end

------------------------------------------------------------------------------------------
-- The route as guide steps
------------------------------------------------------------------------------------------
local function R1(v) return floor(v * 10 + 0.5) / 10 end

-- Text that survives a guide line: no "|" (it starts the text) and no "@" (it starts the place).
local function Clean(s)
    if type(s) ~= "string" then return nil end
    s = ns.Trim((s:gsub("[|@\r\n]", " ")))
    return s ~= "" and s or nil
end

local function Place(step, s)
    if s then step.map, step.x, step.y = s.map, R1(s.x), R1(s.y) end
    return step
end

local function FlightName(state, node)
    for _, f in ipairs(state.flights) do if f.node == node then return Clean(f.name) end end
end

-- A map's details, or nil (the call is pcall'd: a bad id or a missing API gives nil).
local function MapInfo(map)
    local get = C_Map and C_Map.GetMapInfo
    if type(get) ~= "function" or type(map) ~= "number" then return nil end
    local ok, info = pcall(get, map)
    return (ok and type(info) == "table") and info or nil
end
local function Readable(s) if type(s) == "string" and not ns:IsSecret(s) then return Clean(s) end end
local function MapName(map) local info = MapInfo(map); return info and Readable(info.name) or nil end

-- The zone (a mapType 3 map) a spot lies in: on a continent map (where flight points are kept) the map at that
-- spot, then up through the parents (a city or a cave map to its zone). Nil when it can't be told.
function ns.PlannerZoneAt(map, x, y)
    map = tonumber(map)
    local info = MapInfo(map)
    if not info then return nil end
    if tonumber(info.mapType) == 2 then
        local at = C_Map and C_Map.GetMapInfoAtPosition
        x, y = tonumber(x), tonumber(y)
        if type(at) ~= "function" or not (x and y) then return nil end
        local ok, here = pcall(at, map, x / 100, y / 100)
        local id = ok and type(here) == "table" and here.mapID or nil
        map = (id ~= nil and not ns:IsSecret(id)) and tonumber(id) or nil
        if not map then return nil end
        info = MapInfo(map)
        if not info then return nil end
    end
    for _ = 1, 8 do
        local t = tonumber(info.mapType)
        if t == 3 then return map end
        local parent = tonumber(info.parentMapID)
        if not t or t < 3 or not parent or parent == 0 or parent == map then return nil end
        map = parent
        info = MapInfo(map)
        if not info then return nil end
    end
end

-- A flight's words: "Go to <zone>: fly to <point>" when it lands in another zone than it takes off from, else
-- the flight point's name. Nil (the panel's own "Take the flight") when there is nothing to say.
local function FlyText(state, from, leg)
    local name = FlightName(state, leg.node)
    local z1 = from and ns.PlannerZoneAt(from.map, from.x, from.y)
    local z2 = z1 and ns.PlannerZoneAt(leg.to.map, leg.to.x, leg.to.y)
    local zone = z2 and z2 ~= z1 and MapName(z2)
    if not zone then return name end
    if name then return Clean(format(ns:Tr("Go to %s: fly to %s"), zone, name)) end
    return Clean(format(ns:Tr("Go to %s: take the flight"), zone))
end

-- A dock's name: its area's, else its map's.
local function DockName(dock)
    if type(dock) ~= "table" then return nil end
    local get, area = C_Map and C_Map.GetAreaInfo, tonumber(dock.area)
    if area and type(get) == "function" then
        local ok, name = pcall(get, area)
        name = ok and Readable(name) or nil
        if name then return name end
    end
    return MapName(tonumber(dock.map))
end

-- A crossing's words: "Take the boat (zeppelin) from <dock> to <dock>". Nil (the panel's own words) when a name can't be read.
local function SailText(leg)
    local a, b = DockName(leg.from), DockName(leg.at)
    if not (a and b) then return nil end
    return Clean(format(ns:Tr(leg.ship == "zeppelin" and "Take the zeppelin from %s to %s" or "Take the boat from %s to %s"), a, b))
end
ns.PlannerSailText = SailText                    -- (the guide's arrow says it at the dock)

-- Seconds saved against running the same way, when running is possible at all.
local function Saves(from, to, seconds, ctx)
    local d = Yards(from, to)
    if d == huge then return nil end
    return floor(max(0, d / Speed(ctx) - seconds) + 0.5)
end

-- The travel from state.pos to `dest` as steps; the last run is left out (the next step carries the place).
-- Nil (and nothing added) when there is no way there.
local function Legs(state, dest, steps)
    local secs, legs = ns.PlannerTravel(state.pos, dest, state.tctx)
    if secs == huge then return nil end
    for i, l in ipairs(legs) do
        ns.PlannerYield()
        local nxt = legs[i + 1]
        if l.kind == "run" then
            if nxt and nxt.kind ~= "fly" and nxt.kind ~= "sail" then
                steps[#steps + 1] = Place({ kind = "goto", text = l.node and FlightName(state, l.node) or nil }, l.to)
            end
        elseif l.kind == "fly" then
            local s = Place({ kind = "fly", node = l.node, text = FlyText(state, state.pos, l) }, state.pos)
            local saved = Saves(state.pos, l.to, l.seconds, state.tctx)
            if saved then s.why = { saves = saved } end
            steps[#steps + 1] = s
        elseif l.kind == "hearth" then
            local s = { kind = "hearth" }
            local saved = Saves(state.pos, dest, secs, state.tctx)
            if saved then s.why = { saves = saved } end
            steps[#steps + 1] = s
            state.tctx.hearth = nil                      -- one use; it is on cooldown after
        elseif l.kind == "sail" then
            local s = Place({ kind = "sail", crossing = l.crossing, text = SailText(l) }, state.pos)
            local saved = Saves(state.pos, l.to, l.seconds, state.tctx)
            if saved then s.why = { saves = saved } end
            steps[#steps + 1] = s
        end
        state.pos = l.to
    end
    state.pos = dest
    return secs
end

-- An unknown flight point worth learning on the way from a to b: within the detour limit (only on the
-- way between hubs or zones), or one the trip would fly from if it were known (on any trip).
local function LearnOnWay(state, a, b, between)
    local direct = Yards(a, b)
    if direct == huge then return nil end
    local speed = Speed(state.tctx)
    local best, bestD
    for _, f in ipairs(state.flights) do
        ns.PlannerYield()
        if not f.known then
            local toF, fromF = Yards(a, f), Yards(f, b)
            if toF < huge and fromF < huge then
                local detour = (toF + fromF - direct) / speed
                local worth = between and detour < ns.PLANNER_LEARN_SECONDS
                if not worth and toF < direct then
                    f.known = true
                    local _, legs = ns.PlannerTravel(a, b, state.tctx)
                    f.known = false
                    for _, l in ipairs(legs) do if l.kind == "run" and l.node == f.node then worth = true end end
                end
                if worth and (not bestD or detour < bestD) then best, bestD = f, detour end
            end
        end
    end
    return best
end

-- Go from state.pos to dest, learning flight points on the way when that is on. Nil when dest
-- can't be reached (then nothing is added and state.pos stays).
local function Trip(state, dest, steps, between)
    if not dest then return 0 end
    if not state.pos then state.pos = dest; return 0 end
    if ns.PlannerTravel(state.pos, dest, state.tctx) == huge then return nil end
    local t, count, pos, hearth, learned = 0, #steps, state.pos, state.tctx.hearth, {}
    for _ = 1, 4 do
        local f = state.learn and LearnOnWay(state, state.pos, dest, between)
        if not f then break end
        local spot = { map = f.map, x = f.x, y = f.y }
        local legs = Legs(state, spot, steps)
        if not legs then break end
        t = t + legs + HANDLE
        steps[#steps + 1] = Place({ kind = "learnflight", node = f.node, text = Clean(f.name) }, spot)
        f.known = true
        learned[#learned + 1] = f
    end
    local last = Legs(state, dest, steps)
    if last then return t + last end
    -- (the end can't be reached from where the detours led: the trip is undone, as if never tried)
    for i = #steps, count + 1, -1 do steps[i] = nil end
    for _, f in ipairs(learned) do f.known = false end
    state.pos, state.tctx.hearth = pos, hearth
    return nil
end

local function QuestStep(kind, rec, spot)
    return Place({ kind = kind, quest = rec.id, title = Clean(rec.name) }, spot)
end

-- The innkeeper nearest a hub, within the hub's reach.
local function HubInn(ctx, hub)
    local src = ctx.source
    if type(src) ~= "table" or type(src.inns) ~= "function" then return nil end
    local list = src.inns()
    local best, bestD
    for _, inn in ipairs(type(list) == "table" and list or {}) do
        ns.PlannerYield()
        if type(inn) == "table" and inn.map == hub.map and Clean(inn.name) then
            local d = Yards(hub, inn)
            if d <= ns.PLANNER_HUB_YARDS and (not bestD or d < bestD) then best, bestD = inn, d end
        end
    end
    return best
end

-- Is this spot where a quest's kill objective is? And do you skin (a note "skin them" on such a step)?
local function KillSpot(rec, spot)
    for _, o in ipairs(rec.objectives or {}) do
        if o.kind == "kill" then
            for _, s in ipairs(o.spots or {}) do if s == spot then return true end end
        end
    end
    return false
end
local function Skinner(state)
    if state.skin == nil then
        state.skin = (ns.db and ns.db.plannerGather ~= false and ns.PlannerHasProfession and ns.PlannerHasProfession(ns.PLANNER_SKINNING_LINE or 393)) and true or false
    end
    return state.skin
end

-- A hub's steps; xp and seconds of what could be reached. A quest whose giver or objective can't be
-- reached is left out from there on. Each of its own steps carries step.hub = n (in memory only: the
-- stops pass puts a stop near a hub after the hub's last accept).
-- The wanted reputation a kept quest gives, added up for the panel line (state.ctx.repGoals: the wanted factions).
local function AddRep(state, q)
    local goals = state.ctx and state.ctx.repGoals
    if type(goals) ~= "table" or type(q.reputation) ~= "table" then return end
    for _, e in ipairs(q.reputation) do
        local value = tonumber(e[2])
        if goals[e[1]] and value then state.rep[e[1]] = (state.rep[e[1]] or 0) + value end
    end
    DrawRep(state.ctx, q)
end

local function HubSteps(state, hub, steps, inn, n)
    local t, xp, gone, first, kept = 0, 0, {}, true, 0
    local function Go(spot)                                   -- (the first trip that works is the way into the hub: `first` until then)
        local tt = Trip(state, spot, steps, first)
        if tt then t, first = t + tt, false end
        return tt ~= nil
    end
    local function Do(rec, spot)                              -- (an escort's step says so, and a kill spot you skin at)
        local s = QuestStep("do", rec, spot)
        steps[#steps + 1] = s
        s.hub = n
        if KillSpot(rec, spot) and Skinner(state) then s.why = { skin = true } end
        if IsEscort(rec) then
            s.text = (Clean(rec.name) and (Clean(rec.name) .. " - ") or "") .. ns:Tr("Escort: start it when you are ready; it fails if the NPC dies")
            s.escort = true
        end
        return s
    end
    local function Accept(rec, spot)                          -- (Show why: the real experience, never the bonus for upgrades or reputation)
        local s = QuestStep("accept", rec, spot)
        local _, _, real = ns.PlannerQuestXP(rec, state.ctx)
        s.why = { xp = floor(real + 0.5) }
        s.hub = n
        if type(rec.fromItem) == "table" and Clean(rec.fromItem.name) then
            s.text = format(ns:Tr(rec.haveItem and "Use the %s to start it" or "Keep the %s that drops here"), Clean(rec.fromItem.name))
        end
        steps[#steps + 1] = s
        t = t + HANDLE
        return s
    end
    local started = {}
    local runs = hub.timed or {}
    local function Held()                                     -- (an item in your bags: the first thing, where you stand)
        local at = #runs > 0 and state.pos or nil             -- (after a run with a clock on it: where the run ends)
        for _, a in ipairs(hub.accepts) do
            if a.rec.haveItem then
                local spot = at and { map = at.map, x = at.x, y = at.y } or a.spot
                if Go(spot) then
                    Accept(a.rec, spot)
                    started[a.rec.id] = true
                end
            end
        end
    end
    if #runs == 0 then Held() end
    for _, r in ipairs(runs) do                               -- (a quest with a clock on it: its own run, before anything else here)
        local ok = true                                       -- (its steps say so: nothing is put between them)
        if r.accept then
            if Go(r.accept) then Accept(r.rec, r.accept).timed = true else ok = false end
        end
        if ok and r.spot then
            if Go(r.spot) then Do(r.rec, r.spot).timed = true else ok = false end
        end
        if ok and r.turnin and Go(r.turnin) then
            local s = QuestStep("turnin", r.rec, r.turnin)
            s.hub, s.timed = n, true
            steps[#steps + 1] = s
            t = t + HANDLE
        elseif not ok or r.turnin then
            gone[r.rec.id] = true
        end
    end
    if #runs > 0 then Held() end
    for _, a in ipairs(hub.accepts) do
        if started[a.rec.id] then
            -- (done above)
        elseif Go(a.spot) then
            Accept(a.rec, a.spot)
        else
            gone[a.rec.id] = true
        end
    end
    if inn then
        local spot = { map = inn.map, x = inn.x, y = inn.y }
        if Go(spot) then
            t = t + HANDLE
            steps[#steps + 1] = Place({ kind = "bind", text = Clean(inn.name), hub = n }, spot)
        end
    end
    for _, d in ipairs(hub.dos) do
        if not gone[d.rec.id] then
            if Go(d.spot) then
                Do(d.rec, d.spot)
            else
                gone[d.rec.id] = true
            end
        end
    end
    for _, e in ipairs(hub.turnins) do
        if gone[e.rec.id] then
            -- (left out above)
        elseif Go(e.spot) then
            local s = QuestStep("turnin", e.rec, e.spot)
            s.hub = n
            steps[#steps + 1] = s
            t = t + HANDLE
        else
            gone[e.rec.id] = true                             -- (its hand-in can't be reached: its experience and time are not counted)
        end
    end
    for _, q in ipairs(hub.quests) do
        if not gone[q.id] and not (hub.away and hub.away[q.id]) then
            kept = kept + 1
            t = t + ns.PlannerQuestTime(q, state.ctx)
            local _, extra, real = ns.PlannerQuestXP(q, state.ctx)
            xp = xp + real                                   -- (the forecast is real experience: the bonus only scored the hubs)
            local left = tonumber(state.ctx.restedLeft)
            if left and left > 0 then state.ctx.restedLeft = max(0, left - extra) end
            AddRep(state, q)                                 -- (after its experience is counted: the pool of each faction goes down)
        end
    end
    return t, xp, kept
end

local function ToLevel(ctx, xp)
    local level, now, need = ctx.level or 1, tonumber(ctx.xp), tonumber(ctx.xpMax)
    if not (now and need and need > 0) then return level end
    return R1(level + (now + xp) / need)
end

-- Every hub that was worked out (all maps), best rate first, at most PLANNER_MAP_HUBS: summary.hubs, saved with
-- your guide state, so it keeps only what the world map's marks need: { map, x, y (to 0.1), rate (experience a
-- second, to 0.0001), quests }.
ns.PLANNER_MAP_HUBS = 80
ns.PLANNER_LEAD_FIRST = 2.5             -- a lead-in hub's `first` in the rank rounds: above a hub's own (1, 2), below "plan from here" (3)
local function Round(v, scale) v = tonumber(v); return v and floor(v * scale + 0.5) / scale or nil end   -- (scale 10: to 0.1)
local function HubList(hubs)
    local list = {}
    for _, h in ipairs(hubs or {}) do
        ns.PlannerYield()
        local secs = tonumber(h.seconds) or 0
        list[#list + 1] = { map = h.map, x = Round(h.x, 10), y = Round(h.y, 10), rate = Round(secs > 0 and (h.xp or 0) / secs or 0, 10000),
                            quests = #(h.quests or {}) }
    end
    table.sort(list, function(a, b) return a.rate > b.rate end)
    for i = #list, ns.PLANNER_MAP_HUBS + 1, -1 do list[i] = nil end
    return list
end

-- The end of every Build (the empty ones too): the "route" hooks, then whether the plan is empty.
local function Finish(hooks, guide, summary, ctx, c, taken, tctx)
    for _, h in ipairs(hooks.route or {}) do h.fn(guide, summary, ctx, c) end
    summary.empty = #guide.steps == 0
    return guide, summary, taken or {}, tctx
end

-- The maps from `map` up to its zone (mapType 3 or above it), nearest first: a city or a cave map, then its zone.
function ns.PlannerZoneMaps(map)
    local out = { map }
    local get = C_Map and C_Map.GetMapInfo
    for _ = 1, 8 do
        if type(get) ~= "function" or type(map) ~= "number" then break end
        local ok, info = pcall(get, map)
        if not (ok and type(info) == "table") then break end
        local t, parent = tonumber(info.mapType), tonumber(info.parentMapID)
        if (t and t <= 3) or not parent or parent == 0 or parent == map then break end
        map = parent
        out[#out + 1] = map
    end
    return out
end

-- guide, summary, the hubs it took and the travel context. `candidates` are the quests to plan.
-- summary.hubs: every hub worked out (HubList, cut to the best 80: a taken hub may be missing; use summary.taken);
-- summary.taken[n]: round n's hub { xp, seconds, travel, rate, score, map, x, y (to 0.1, as in summary.hubs), quests
-- (how many), first (when a rule put it first), parts (the style's story and safety terms), beat = the runner-up
-- { rate, name = its first quest, map, x, y, first, parts } or nil, lead = true for a lead-in }.
local function Build(ctx, candidates, skipped)
    local hooks = type(ctx.hooks) == "table" and ctx.hooks or nil    -- (ns.PlannerContext's copies; else the hooks as they are now, kept for this Build:
    if not hooks then                                                --  a hook added or removed meanwhile waits for the next plan)
        hooks = {}
        for _, point in ipairs(ns.PLANNER_HOOK_POINTS) do hooks[point] = ns.PlannerHookCopy(point) end
    end
    local guide = { name = ns.GUIDE_PLANNED, steps = {} }
    local summary = { fromLevel = ctx.level, toLevel = ctx.level, xp = 0, seconds = 0, skipped = skipped, empty = true, hubs = {}, taken = {} }
    if #candidates == 0 then return Finish(hooks, guide, summary, ctx, ctx) end
    local c = WithCandidates(ctx, candidates)
    c.hooks = hooks
    c.restedLeft = tonumber(ctx.rested)              -- the route uses this pool up as it lays hubs out (hub scoring before that deliberately sees all of it)
    c.rewardCache = {}                               -- quest id -> reward bonus, read once per plan
    c.repCache = {}                                  -- faction id -> reputation still needed, read once per plan
    local zone, newly, hubs = ns.PlannerPickZone(candidates, c)
    local here = Here(ctx)
    if not zone then                                 -- (nothing left to plan: what was left out where you are, "here" on the panel)
        if here and c.movedByMap then                -- (a city or cave map you stand on: its zone's)
            for _, m in ipairs(ns.PlannerZoneMaps(here.map)) do
                if c.movedByMap[m] then summary.moved = c.movedByMap[m]; break end
            end
        end
        summary.hubs = HubList(hubs)
        return Finish(hooks, guide, summary, ctx, c)
    end
    summary.moved = c.movedByMap and c.movedByMap[zone] or nil     -- the level a hub (in this zone) where you died twice is planned again at
    local left, zc = {}, nil
    for _, h in ipairs(hubs) do
        if h.map == zone then
            left[#left + 1] = h
            zc = zc or Pos(h)
        end
    end
    -- A hub planned first on another map (an "always" class quest, an item in your bags) is a lead-in: taken
    -- first, on top of the zone's hubs, when it is on the zone's continent and can be reached. It never
    -- chooses the zone, binds the hearthstone or is remembered as the zone.
    local lead, leadFirst, leadRate
    for _, h in ipairs(hubs) do
        ns.PlannerYield()
        if h.first and h.map ~= zone and zc and Pos(h) == zc
            and (not here or ns.PlannerTravel(here, h, c) < huge)
            and (not lead or h.first > leadFirst or (h.first == leadFirst and Rate(h) > leadRate)) then
            lead, leadFirst, leadRate = h, h.first, Rate(h)
        end
    end
    local flights = {}
    for _, f in ipairs(ctx.flights or {}) do
        local copy = {}
        for k, v in pairs(f) do copy[k] = v end
        flights[#flights + 1] = copy
    end
    local tctx = {}
    for k, v in pairs(c) do tctx[k] = v end
    tctx.flights = flights
    local state = { rep = {}, pos = here, flights = flights, tctx = tctx, ctx = c, learn = ctx.learnFlights and true or false }
    local xp, seconds, taken = 0, 0, {}
    local bound = false                              -- (the hearthstone is set at the zone's first hub, when the zone is new)
    local function Lay(hub, n)
        taken[#taken + 1] = hub
        local inn
        if newly and not bound and hub.map == zone then
            bound = true
            inn = HubInn(ctx, hub)
            if inn and type(ctx.bindSpot) == "table" and Yards(ctx.bindSpot, inn) <= ns.PLANNER_HUB_YARDS then inn = nil end
        end
        local t, gained = HubSteps(state, hub, guide.steps, inn, n)
        seconds, xp = seconds + t, xp + gained
    end
    local function Into(h) return h.accepts[1] and h.accepts[1].spot or h end
    -- Each round n = 1 .. horizon (a lead-in hub counts): every hub left as { hub, index, travel, rate, score,
    -- first }, plus, until it is taken, the lead-in as { hub, travel, rate, score, first = PLANNER_LEAD_FIRST,
    -- lead = true } (no index). The "rank" hooks may change score and first (a negative score leaves the entry
    -- out of that round); the highest first, then score, is taken. info = { n, round, seconds, xp, horizon, lead }.
    local rankHooks = hooks.rank or {}
    local function Better(e, than)
        local s, f = tonumber(e.score) or -1, tonumber(e.first) or 0
        if s < 0 then return false end
        if not than then return true end
        local ts, tf = tonumber(than.score) or -1, tonumber(than.first) or 0
        return f > tf or (f == tf and s > ts)
    end
    local horizon = tonumber(c.horizon) or ns.PLANNER_HORIZON
    local leadRound = false                          -- (the default plan: the zone's hubs, and the lead-in on top; a hook that sets ctx.horizonSet has its own, which counts it)
    if lead and not c.horizonSet and horizon == ns.PLANNER_HORIZON then horizon, leadRound = horizon + 1, true end
    local zoneTaken = 0
    for n = 1, horizon do
        if #left == 0 and not lead then break end
        if leadRound and lead and zoneTaken >= horizon - 1 then break end   -- (the extra round is the lead-in's alone: one a hook kept out, "plan from here", takes no third zone hub)
        local ranked = {}
        for i, h in ipairs(left) do
            ns.PlannerYield()
            local travel = state.pos and ns.PlannerTravel(state.pos, Into(h), tctx) or 0
            local rate = travel < huge and h.xp / (h.seconds + travel) or -1
            ranked[#ranked + 1] = { hub = h, index = i, travel = travel, rate = rate, score = rate, first = (h.first and travel < huge) and h.first or 0 }
        end
        if lead then
            local travel = state.pos and ns.PlannerTravel(state.pos, Into(lead), tctx) or 0
            local rate = travel < huge and lead.xp / (lead.seconds + travel) or -1
            ranked[#ranked + 1] = { hub = lead, travel = travel, rate = rate, score = rate, first = travel < huge and ns.PLANNER_LEAD_FIRST or 0, lead = true }
        end
        local info = { n = n, round = n, seconds = seconds, xp = xp, horizon = horizon, lead = lead ~= nil }
        for _, hk in ipairs(rankHooks) do hk.fn(ranked, c, info) end
        local best, runner
        for _, e in ipairs(ranked) do
            if Better(e, best) then best, runner = e, best elseif Better(e, runner) then runner = e end
        end
        if not best then break end
        local h = best.hub
        local beat
        if runner then
            local q1 = runner.hub.quests and runner.hub.quests[1]
            beat = { rate = runner.rate, name = q1 and Clean(q1.name) or nil, map = runner.hub.map, x = runner.hub.x, y = runner.hub.y,
                     first = (tonumber(runner.first) or 0) > 0 and runner.first or nil, parts = runner.parts }
        end
        summary.taken[n] = { xp = h.xp, seconds = h.seconds, travel = best.travel, rate = best.rate, score = best.score, beat = beat,
                             map = h.map, x = Round(h.x, 10), y = Round(h.y, 10), lead = best.lead and true or nil, quests = #(h.quests or {}),
                             first = (tonumber(best.first) or 0) > 0 and best.first or nil, parts = best.parts }
        if best.lead then
            lead = nil
        else
            zoneTaken = zoneTaken + 1
            for i, e in ipairs(left) do if e == h then table.remove(left, i); break end end
        end
        Lay(h, n)
    end
    summary.zone, summary.newZone = zone, newly
    summary.reputation = state.rep                   -- wanted reputation the plan gives: { [factionID] = amount }
    summary.xp, summary.seconds = floor(xp + 0.5), floor(seconds + 0.5)
    summary.toLevel = ToLevel(ctx, xp)
    if ns.PlannerAddStops then ns.PlannerAddStops(guide, summary, ctx) end   -- (stops on the way: PlannerStops.lua)
    if ns.PlannerHoldTurnins then ns.PlannerHoldTurnins(guide, summary, ctx) end   -- (hand-ins held for the trainer's town)
    if ns.PlannerPathExtras then ns.PlannerPathExtras(guide, summary, ctx) end     -- (unexplored spots and nodes on the way: PlannerPath.lua)
    summary.hubs = HubList(hubs)                     -- (every hub worked out, on every map: the world map's marks)
    return Finish(hooks, guide, summary, ctx, c, taken, tctx)
end

-- Does a "fit" class quest lie near the route: its start within a hub's radius of a hub taken, or within 300
-- seconds of travel of one; and are you still below its level + 1?
local FIT_SECONDS = 300
local function Fits(rec, entry, taken, tctx, ctx)
    if (ctx.level or 1) >= (tonumber(entry.level) or 0) + 1 then return false end
    for _, spot in ipairs(rec.starts or {}) do
        for _, hub in ipairs(taken) do
            ns.PlannerYield()
            if Yards(spot, hub) <= ns.PLANNER_HUB_YARDS then return true end
        end
    end
    for _, spot in ipairs(rec.starts or {}) do
        for _, hub in ipairs(taken) do
            ns.PlannerYield()
            local secs = ns.PlannerTravel(hub, spot, tctx)
            if type(secs) == "number" and secs <= FIT_SECONDS then return true end
        end
    end
    return false
end

-- Does an item quest's dropping NPC stand within a hub's radius of a spot of the route (the places its quest
-- steps go to; stops, unexplored spots and nodes on the way are no reason to be there, and neither are the
-- steps of the quests in `leave`)? `route` is { { c, x, y } } from RouteSpots.
local function RouteSpots(guide, leave)
    local out = {}
    for _, st in ipairs(guide.steps) do
        ns.PlannerYield()
        if st.quest and not (leave and leave[st.quest]) and st.x and st.y then
            local c, x, y = Pos(st)
            if c then out[#out + 1] = { c = c, x = x, y = y } end
        end
    end
    return out
end
local function NearRoute(rec, route)
    local r2 = ns.PLANNER_HUB_YARDS ^ 2
    for _, s in ipairs(rec.starts or {}) do
        local c, x, y = Pos(s)
        if c then
            for _, a in ipairs(route) do
                ns.PlannerYield()
                if a.c == c and (a.x - x) ^ 2 + (a.y - y) ^ 2 <= r2 then return true end
            end
        end
    end
    return false
end

-- Why a logged quest the plan does not take is worth dropping: { [questID] = "never planned" | "off the route" }.
-- "never planned": the planner's own filters would reject it (skipped, above the level window, a group or elite
-- quest the group setting leaves out) or its hand-in can't be reached. "off the route": every known spot of it lies
-- beyond a hub's radius of every step of the route. A quest that passes and lies near the route (it may just be
-- beyond the plan's two hubs) is never named. Nil while the advice is off.
-- The log has room for the whole plan (more than PLANNER_LOG_FREE places free, and its peak fits)? Then the
-- panel gives no advice and nothing is asked here. ctx.logCount, ctx.logMax: the log when the plan began.
local function LogFits(ctx, guide)
    local count, most = tonumber(ctx.logCount), tonumber(ctx.logMax)
    if not (count and most) or most - count <= (ns.PLANNER_LOG_FREE or 3) then return false end
    local occ, peak, inLog = count, count, {}
    for _, st in ipairs(guide.steps) do
        ns.PlannerYield()
        local q = st.quest
        if type(q) == "number" then
            local has = inLog[q]
            if has == nil then has = ctx.onQuest(q) and true or false end
            if st.kind == "accept" and not has then
                has, occ = true, occ + 1
                if occ > peak then peak = occ end
            elseif st.kind == "turnin" and has then
                has, occ = false, occ - 1
            end
            inLog[q] = has
        end
    end
    return peak <= most
end

local function LogReasons(ctx, candidates, guide)
    if not (ns.db and ns.db.plannerLogAdvice ~= false) or type(ctx.onQuest) ~= "function" then return nil end
    if LogFits(ctx, guide) then return {}, true end
    local planned, route = {}, {}
    for _, st in ipairs(guide.steps) do
        ns.PlannerYield()
        if st.quest then planned[st.quest] = true end
        if st.x and st.y then
            local c, x, y = Pos(st)
            if c then route[#route + 1] = { c = c, x = x, y = y } end
        end
    end
    local here, out = Here(ctx), {}
    local r2 = ns.PLANNER_HUB_YARDS ^ 2
    for _, rec in ipairs(candidates) do
        ns.PlannerYield()
        if not planned[rec.id] and ctx.onQuest(rec.id) then
            local never = ns.PlannerRejects(rec, ctx) ~= nil
            if not never and here then
                local fin = Nearest(rec.ends)
                if fin and ns.PlannerTravel(here, fin, ctx) == huge then never = true end
            end
            if never then
                out[rec.id] = "never planned"
            elseif #route > 0 then
                local known, near = false, false
                local function Check(list)
                    for _, sp in ipairs(type(list) == "table" and list or {}) do
                        local c, x, y = Pos(sp)
                        if c then
                            known = true
                            for _, a in ipairs(route) do
                                ns.PlannerYield()
                                if a.c == c and (a.x - x) ^ 2 + (a.y - y) ^ 2 <= r2 then near = true; return end
                            end
                        end
                    end
                end
                Check(rec.starts)
                if not near then Check(rec.ends) end
                for _, o in ipairs(type(rec.objectives) == "table" and rec.objectives or {}) do
                    if near then break end
                    Check(type(o) == "table" and o.spots)
                end
                if known and not near then out[rec.id] = "off the route" end
            end
        end
    end
    return out
end

-- guide, summary. Everything the planner needs comes in ctx (see ns.PlannerContext).
function ns.PlannerRoute(ctx)
    ctx = ctx or {}
    local candidates, skipped, items = ns.PlannerCandidates(ctx.source, ctx)
    local classMap = ns.PlannerClassMap(ctx)
    local main, fits = candidates, {}
    if next(classMap) then
        main = {}
        for _, r in ipairs(candidates) do
            local e = classMap[r.id]
            if e and e.kind == "fit" and not (ctx.onQuest and ctx.onQuest(r.id)) then fits[#fits + 1] = r else main[#main + 1] = r end
        end
    end
    local guide, summary, taken, tctx = Build(ctx, main, skipped)
    if (#fits > 0 or #(items or {}) > 0) and #taken > 0 then
        local plus = {}
        for _, r in ipairs(main) do plus[#plus + 1] = r end
        for _, r in ipairs(fits) do
            if Fits(r, classMap[r.id], taken, tctx, ctx) then plus[#plus + 1] = r end
        end
        local drops = {}
        if #(items or {}) > 0 then                   -- (a drop quest: only where the route already goes)
            local route = RouteSpots(guide)
            for _, r in ipairs(items) do
                if NearRoute(r, route) then plus[#plus + 1] = r; drops[#drops + 1] = r end
            end
        end
        if #plus > #main then
            guide, summary = Build(ctx, plus, skipped)
            -- the rebuilt route may go elsewhere: a drop quest stays only while the route (not its own steps) still
            -- passes its NPC; otherwise it is built again without it (twice at most)
            for _ = 1, 2 do
                if #drops == 0 then break end
                local leave = {}
                for _, r in ipairs(drops) do leave[r.id] = true end
                local route = RouteSpots(guide, leave)
                local keep, gone = {}, {}
                for _, r in ipairs(drops) do
                    if NearRoute(r, route) then keep[#keep + 1] = r else gone[r.id] = true end
                end
                if not next(gone) then break end
                local fewer = {}
                for _, r in ipairs(plus) do if not gone[r.id] then fewer[#fewer + 1] = r end end
                plus, drops = fewer, keep
                guide, summary = Build(ctx, plus, skipped)
            end
        end
    end
    summary.logReasons, summary.logFits = LogReasons(ctx, candidates, guide)   -- (the quest log advice: worked out here, in slices; the panel only reads it)
    if summary.empty and ns.PlannerDry then summary.dry = ns.PlannerDry(ctx) end    -- (nothing worth the trip: a dungeon or grinding, PlannerAdvice.lua)
    if next(classMap) then                           -- (a class quest you could start that the plan does not take: said on the panel)
        local planned = {}
        for _, st in ipairs(guide.steps) do if st.quest then planned[st.quest] = true end end
        for _, r in ipairs(candidates) do
            local e = classMap[r.id]
            if e and not planned[r.id] and not (ctx.onQuest and ctx.onQuest(r.id)) then
                local parts = max(1, floor(tonumber(e.parts) or 1))
                local ready = { name = Clean(r.name) or ("#" .. r.id), parts = parts }
                if parts > 1 then ready.minutes = max(1, floor(ns.PlannerQuestTime(r, ctx) * parts / 60 + 0.5)) end
                summary.classReady = ready
                break
            end
        end
    end
    return guide, summary
end



------------------------------------------------------------------------------------------
-- The live game as the planner's ctx
------------------------------------------------------------------------------------------
-- Quests you skipped a step of on the planned route, this session only (in memory: never the permanent
-- "never suggest"): left out of the plans made after it, a quest in your log too ("candidate" hook).
local sessionSkip = {}
function ns.PlannerSessionSkip(id)
    if type(id) == "number" then sessionSkip[id] = true end
end
function ns.PlannerSessionSkipped(id) return sessionSkip[id] == true end
function ns.PlannerSessionSkipReset() sessionSkip = {} end
ns.PlannerHook("candidate", "sessionSkip", function(rec)
    if type(rec) == "table" and sessionSkip[rec.id] then return false end
end)
local HEARTHSTONE = 6948

local function Num(v) if type(v) == "number" and not ns:IsSecret(v) then return v end end
local function Call(f, ...)
    if type(f) ~= "function" then return nil end
    local ok, a, b, c = pcall(f, ...)
    if ok then return a, b, c end
end

local function BindName()
    local v = Call(GetBindLocation)
    if type(v) == "string" and not ns:IsSecret(v) and v ~= "" then return v end
end

-- Where you are bound: the place you set the hearthstone at, while that is still where you are bound.
local function BindSpot()
    local d, name = PaceRecord(false), BindName()
    local at = d and d.bindAt
    if not (name and type(at) == "table" and at.name == name and at.map and at.x and at.y) then return nil end
    return { map = at.map, x = at.x, y = at.y }
end

-- Where the hearthstone takes you now: the bind place, when the stone is off cooldown.
local function HearthSpot()
    local at = BindSpot()
    if not at then return nil end
    local start, duration = Call(C_Container and C_Container.GetItemCooldown, HEARTHSTONE)
    start, duration = Num(start), Num(duration)
    if start and duration and start > 0 and duration > 0 and start + duration > GetTime() then return nil end
    return { map = at.map, x = at.x, y = at.y }
end

-- The quests in your log, and how many it holds (nil, nil when the game can't say).
local function LogCount()
    local QL = C_QuestLog
    if type(QL) ~= "table" or type(QL.GetNumQuestLogEntries) ~= "function" or type(QL.GetInfo) ~= "function" then return nil, nil end
    local num = Num(Call(QL.GetNumQuestLogEntries))
    if not num then return nil, nil end
    local n = 0
    for i = 1, math.min(num, 100) do
        local info = Call(QL.GetInfo, i)
        if type(info) == "table" and not info.isHeader and Num(info.questID) then n = n + 1 end
    end
    local most = Num(Call(QL.GetMaxNumQuestsCanAccept))
    return n, (most and most > 0) and most or ns.PLANNER_LOG_SIZE or 25
end

-- Run speed, or mounted speed once this character has been seen mounted.
local function RunSpeed()
    local _, run = Call(GetUnitSpeed, "player")
    run = Num(run)
    local mounted = Call(IsMounted) == true
    if mounted then
        local d = PaceRecord(true)
        local v = (run and run > ns.PLANNER_SPEED.run) and run or ns.PLANNER_SPEED.mount
        if d and (tonumber(d.mountSpeed) or 0) < v then d.mountSpeed = v end
    end
    local d = PaceRecord(false)
    local mount = d and tonumber(d.mountSpeed)
    if mount then return max(mount, run or 0) end
    return (run and run > 0) and run or ns.PLANNER_SPEED.run
end

function ns.PlannerContext()
    local QL = C_QuestLog or {}
    local src, why = ns.PlannerSource()
    if not src then src = ns.PlannerLogSource() end
    local map, x, y
    if ns.GuideHere then map, x, y = ns.GuideHere() end
    local times = type(ns.root) == "table" and type(ns.root.plannerFlightTimes) == "table" and ns.root.plannerFlightTimes or nil
    local d = PaceRecord(false)
    local db = ns.db or {}
    local ctx = {
        source = src, sourceWhy = why,
        level = Num(Call(UnitLevel, "player")) or 1,
        xp = Num(Call(UnitXP, "player")), xpMax = Num(Call(UnitXPMax, "player")),
        group = db.plannerGroup or "solo", inGroup = Call(IsInGroup) == true,
        done = function(id) return Call(QL.IsQuestFlaggedCompleted, id) == true end,
        onQuest = function(id) return Call(QL.IsOnQuest, id) == true end,
        here = (map and x and y) and { map = map, x = x, y = y } or nil,
        speed = RunSpeed(),
        faction = Call(UnitFactionGroup, "player"),
        flights = ns.PlannerFlightPoints(),
        flightTime = function(a, b) return times and tonumber(times[a .. "-" .. b]) or nil end,
        hearth = HearthSpot(), bind = BindName(), bindSpot = BindSpot(),
        crossings = ns.PLANNER_CROSSINGS,
        learnFlights = db.plannerLearnFlights ~= false,
        pace = ns.PlannerPace(),
        skip = next(ns.PlannerSkipList()) and ns.PlannerSkipList() or nil,
        class = ns.PlannerClassToken(), soloElites = db.plannerSoloElites ~= false,
        classQuests = (db.plannerClassQuests ~= false and type(ns.PLANNER_CLASS_QUESTS) == "table" and ns.PlannerClassToken()
            and type(ns.PLANNER_CLASS_QUESTS[ns.PlannerClassToken()]) == "table" and #ns.PLANNER_CLASS_QUESTS[ns.PlannerClassToken()] > 0)
            and ns.PLANNER_CLASS_QUESTS[ns.PlannerClassToken()] or nil,
        timed = function(id) local v = Num(Call(QL.GetTimeAllowed, id)); return v ~= nil and v > 0 end,   -- (a quest in the log with a clock on it)
        itemCount = function(id) return Num(Call(C_Item and C_Item.GetItemCount, id)) or 0 end,
        deaths = db.plannerDeaths ~= false and d and type(d.deaths) == "table" and #d.deaths > 0 and d.deaths or nil,
        repGoals = next(ns.PlannerRepGoals()) and ns.PlannerRepGoals() or nil,
        rested = (db.plannerRested ~= false) and Num(Call(GetXPExhaustion)) or nil,
        lastZone = d and tonumber(d.zone) or nil, lastZoneLevel = d and tonumber(d.zoneLevel) or nil,
        trainerLevel = d and tonumber(d.trainerLevel) or nil,   -- the level you last closed your class trainer's window at
    }
    ctx.logCount, ctx.logMax = LogCount()
    ctx.windowLo, ctx.windowHi = ctx.level - 4, ctx.level + 2    -- (the cheap pre-filter's bounds: "context" hooks may widen them)
    ctx.horizon = ns.PLANNER_HORIZON                             -- (hubs a plan takes: hooks may raise it)
    ctx.hooks = {}                                               -- (the hooks this plan uses, copied now: ns.PlannerHooksFor)
    for _, point in ipairs(ns.PLANNER_HOOK_POINTS) do ctx.hooks[point] = ns.PlannerHookCopy(point) end
    for _, h in ipairs(ctx.hooks.context) do h.fn(ctx) end
    ns.PlannerShiftWindow(ctx)                                   -- (a shift asked for by a hook: after all of them)
    return ctx
end

-- Remember the zone a route was planned in (Task 6 calls this when summary.newZone).
function ns.PlannerSetZone(zone, level)
    local d = PaceRecord(true)
    if d then d.zone, d.zoneLevel = zone, level end
end

-- The hearthstone was set: remember where, so the planner knows where it takes you.
do
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "HEARTHSTONE_BOUND")
    ev:SetScript("OnEvent", ns:Guard("Planner bind", function()
        if not ns:GuideUnlocked() then return end
        local name = BindName()
        local m, px, py
        if ns.GuideHere then m, px, py = ns.GuideHere() end
        if not (name and m and px and py) then return end
        local d = PaceRecord(true)
        if d then d.bindAt = { name = name, map = m, x = px, y = py } end
    end))
end
