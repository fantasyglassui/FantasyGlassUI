local _, ns = ...

------------------------------------------------------------------------------------------
-- Planner route: hubs, the zone to go to, and the route as guide steps; the live game as the
-- planner's ctx. Scoring (experience, time, candidates) is in Planner.lua.
------------------------------------------------------------------------------------------
local ipairs, pairs, type, tonumber, math = ipairs, pairs, type, tonumber, math
local floor, min, max, sqrt = math.floor, math.min, math.max, math.sqrt
local PaceRecord = function(create) return ns.PlannerCharRecord(create) end

------------------------------------------------------------------------------------------
-- Hubs: givers and hand-ins close together on one map. A hub's loop is: pick up, do the objectives
-- in a sweep (nearest next), hand in. Inside a hub the walking is counted at run speed in a straight
-- line; the full travel (flights, the hearthstone, boats) is only worked out between hubs.
------------------------------------------------------------------------------------------
ns.GUIDE_PLANNED = "\1planned"          -- a name no saved guide can have (guide names come from a line of text)
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

-- A hub's loop, in order, with its time: accepts, dos and turnins as { rec, spot }.
local function HubLoop(hub, ctx)
    local accepts, dos, turnins = {}, {}, {}
    local xp, t = 0, 0
    for _, q in ipairs(hub.quests) do
        xp = xp + ns.PlannerQuestXP(q, ctx)
        t = t + ns.PlannerQuestTime(q, ctx)
        if hub.take[q.id] then accepts[#accepts + 1] = { rec = q, spot = Nearest(q.starts, hub) } end
    end
    accepts = Sweep(accepts, hub)
    local at = accepts[1] and accepts[1].spot or hub
    for _, a in ipairs(accepts) do t = t + Walk(at, a.spot, ctx) + HANDLE; at = a.spot end
    for _, q in ipairs(hub.quests) do
        if #(q.objectives or {}) > 0 then dos[#dos + 1] = { rec = q, spot = DoSpot(q, hub) } end
    end
    dos = Sweep(dos, at)
    for _, d in ipairs(dos) do
        if d.spot then t = t + Walk(at, d.spot, ctx); at = d.spot end
    end
    for _, q in ipairs(hub.quests) do turnins[#turnins + 1] = { rec = q, spot = Nearest(q.ends, at) } end
    turnins = Sweep(turnins, at)
    for _, e in ipairs(turnins) do
        if e.spot then t = t + Walk(at, e.spot, ctx); at = e.spot end
        t = t + HANDLE
    end
    hub.accepts, hub.dos, hub.turnins, hub.last = accepts, dos, turnins, at
    hub.xp, hub.seconds = xp, max(t, 1)
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
            anchorOf[#anchorOf + 1] = { rec = rec, i = #pts, take = take }
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
            hub = { map = pts[a.i].map, quests = {}, take = {}, sx = 0, sy = 0 }
            byRoot[root] = hub
            hubs[#hubs + 1] = hub
        end
        hub.quests[#hub.quests + 1] = a.rec
        hub.take[a.rec.id] = a.take or nil
        hub.sx, hub.sy = hub.sx + pts[a.i].spot.x, hub.sy + pts[a.i].spot.y
    end
    for _, hub in ipairs(hubs) do
        ns.PlannerYield()
        hub.x, hub.y = hub.sx / #hub.quests, hub.sy / #hub.quests
        hub.sx, hub.sy = nil, nil
        HubLoop(hub, ctx)
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
    local last, here = ctx.lastZone, Here(ctx)
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
            local s = Place({ kind = "fly", node = l.node, text = FlightName(state, l.node) }, state.pos)
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
            local s = Place({ kind = "sail", crossing = l.crossing }, state.pos)
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
    local t = 0
    for _ = 1, 4 do
        local f = state.learn and LearnOnWay(state, state.pos, dest, between)
        if not f then break end
        local spot = { map = f.map, x = f.x, y = f.y }
        local legs = Legs(state, spot, steps)
        if not legs then break end
        t = t + legs + HANDLE
        steps[#steps + 1] = Place({ kind = "learnflight", node = f.node, text = Clean(f.name) }, spot)
        f.known = true
    end
    local last = Legs(state, dest, steps)
    return last and t + last or nil
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
        if goals[e[1]] and tonumber(e[2]) then state.rep[e[1]] = (state.rep[e[1]] or 0) + e[2] end
    end
end

local function HubSteps(state, hub, steps, inn, n)
    local t, xp, gone, first, kept = 0, 0, {}, true, 0
    local function Go(spot)
        local tt = Trip(state, spot, steps, first)
        first = false
        if tt then t = t + tt end
        return tt ~= nil
    end
    for _, a in ipairs(hub.accepts) do
        if Go(a.spot) then
            local s = QuestStep("accept", a.rec, a.spot)
            s.why = { xp = floor(ns.PlannerQuestXP(a.rec, state.ctx) + 0.5) }
            s.hub = n
            steps[#steps + 1] = s
            t = t + HANDLE
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
                local s = QuestStep("do", d.rec, d.spot)
                s.hub = n
                if KillSpot(d.rec, d.spot) and Skinner(state) then s.why = { skin = true } end
                steps[#steps + 1] = s
            else
                gone[d.rec.id] = true
            end
        end
    end
    for _, e in ipairs(hub.turnins) do
        if not gone[e.rec.id] and Go(e.spot) then
            local s = QuestStep("turnin", e.rec, e.spot)
            s.hub = n
            steps[#steps + 1] = s
            t = t + HANDLE
        end
    end
    for _, q in ipairs(hub.quests) do
        if not gone[q.id] then
            kept = kept + 1
            AddRep(state, q)
            t = t + ns.PlannerQuestTime(q, state.ctx)
            local qxp, extra = ns.PlannerQuestXP(q, state.ctx)
            xp = xp + qxp
            local left = tonumber(state.ctx.restedLeft)
            if left and left > 0 then state.ctx.restedLeft = max(0, left - extra) end
        end
    end
    return t, xp, kept
end

local function ToLevel(ctx, xp)
    local level, now, need = ctx.level or 1, tonumber(ctx.xp), tonumber(ctx.xpMax)
    if not (now and need and need > 0) then return level end
    return R1(level + (now + xp) / need)
end

-- guide, summary. Everything the planner needs comes in ctx (see ns.PlannerContext).
function ns.PlannerRoute(ctx)
    ctx = ctx or {}
    local guide = { name = ns.GUIDE_PLANNED, steps = {} }
    local candidates, skipped = ns.PlannerCandidates(ctx.source, ctx)
    local summary = { fromLevel = ctx.level, toLevel = ctx.level, xp = 0, seconds = 0, skipped = skipped, empty = true }
    if #candidates == 0 then return guide, summary end
    local c = WithCandidates(ctx, candidates)
    c.restedLeft = tonumber(ctx.rested)              -- the route uses this pool up as it lays hubs out (hub scoring before that deliberately sees all of it)
    c.rewardCache = {}                               -- quest id -> reward bonus, read once per plan
    c.repCache = {}                                  -- faction id -> reputation still needed, read once per plan
    local zone, newly, hubs = ns.PlannerPickZone(candidates, c)
    if not zone then return guide, summary end
    local left = {}
    for _, h in ipairs(hubs) do if h.map == zone then left[#left + 1] = h end end
    local flights = {}
    for _, f in ipairs(ctx.flights or {}) do
        local copy = {}
        for k, v in pairs(f) do copy[k] = v end
        flights[#flights + 1] = copy
    end
    local tctx = {}
    for k, v in pairs(c) do tctx[k] = v end
    tctx.flights = flights
    local state = { rep = {}, pos = Here(ctx), flights = flights, tctx = tctx, ctx = c, learn = ctx.learnFlights and true or false }
    local xp, seconds = 0, 0
    for n = 1, ns.PLANNER_HORIZON do
        if #left == 0 then break end
        local bi, bs = nil, -1
        for i, h in ipairs(left) do
            ns.PlannerYield()
            local travel = state.pos and ns.PlannerTravel(state.pos, h.accepts[1] and h.accepts[1].spot or h, tctx) or 0
            local score = travel < huge and h.xp / (h.seconds + travel) or -1
            if score > bs then bi, bs = i, score end
        end
        if not bi or bs < 0 then break end
        local hub = table.remove(left, bi)
        local inn
        if n == 1 and newly then
            inn = HubInn(ctx, hub)
            if inn and type(ctx.bindSpot) == "table" and Yards(ctx.bindSpot, inn) <= ns.PLANNER_HUB_YARDS then inn = nil end
        end
        local t, gained = HubSteps(state, hub, guide.steps, inn, n)
        seconds, xp = seconds + t, xp + gained
    end
    summary.zone, summary.newZone = zone, newly
    summary.reputation = state.rep                   -- wanted reputation the plan gives: { [factionID] = amount }
    summary.xp, summary.seconds = floor(xp + 0.5), floor(seconds + 0.5)
    summary.toLevel = ToLevel(ctx, xp)
    if ns.PlannerAddStops then ns.PlannerAddStops(guide, summary, ctx) end   -- (stops on the way: PlannerStops.lua)
    if ns.PlannerHoldTurnins then ns.PlannerHoldTurnins(guide, summary, ctx) end   -- (hand-ins held for the trainer's town)
    if ns.PlannerPathExtras then ns.PlannerPathExtras(guide, summary, ctx) end     -- (unexplored spots and nodes on the way: PlannerPath.lua)
    summary.empty = #guide.steps == 0
    return guide, summary
end

------------------------------------------------------------------------------------------
-- The live game as the planner's ctx
------------------------------------------------------------------------------------------
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
    return {
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
        repGoals = next(ns.PlannerRepGoals()) and ns.PlannerRepGoals() or nil,
        rested = (db.plannerRested ~= false) and Num(Call(GetXPExhaustion)) or nil,
        lastZone = d and tonumber(d.zone) or nil, lastZoneLevel = d and tonumber(d.zoneLevel) or nil,
        trainerLevel = d and tonumber(d.trainerLevel) or nil,   -- the level you last closed your class trainer's window at
    }
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
