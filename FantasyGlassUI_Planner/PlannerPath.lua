local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end

------------------------------------------------------------------------------------------
-- Planner stops along the way: the mailbox when mail is waiting, unexplored spots near the path,
-- and the gathering nodes you have seen. A "leg" is the straight line between two successive
-- placed steps of the plan on one map (the route keeps no run legs of its own).
-- Runs inside the planning coroutine: ns.PlannerYield() in plain loops, never inside pcall.
------------------------------------------------------------------------------------------
local ipairs, type, tonumber, math = ipairs, type, tonumber, math
local floor, sqrt = math.floor, math.sqrt

ns.PLANNER_MAIL_SECONDS = 20            -- a mail stop only when it adds less than this (or the route passes a mailbox)
ns.PLANNER_MAIL_QUIET = 600             -- seconds after a visit before the same mail brings you back
ns.PLANNER_EXPLORE_SECONDS = 15         -- an unexplored spot only when it adds at most this much
ns.PLANNER_EXPLORE_MAX = 3              -- per plan
ns.PLANNER_EXPLORE_YARDS = 40           -- sample spacing along a leg, and how far either side of it
ns.PLANNER_EXPLORE_SAMPLES = 600        -- samples asked of the game per plan, at most
ns.PLANNER_EXPLORE_REACHED = 40         -- a spot this close to one you reached is not asked again
ns.PLANNER_GATHER_SECONDS = 20          -- a node only when it adds at most this much
ns.PLANNER_GATHER_MAX = 5               -- per plan
-- (ns.PLANNER_NODE_YARDS, ns.PLANNER_NODE_CAP and ns.PLANNER_NODES_TOTAL: with the node recorder, PlannerRecorders.lua)
local SAMPLE_CAP = 200                  -- samples along one leg
local APART = 2                         -- explore spots are this many sample spacings apart, at least
local REACHED_CAP = 200                 -- reached explore spots kept per map
local GRID = 5                          -- a map with no texture answer: GRID x GRID samples say if it reports exploration

local function Num(v) if type(v) == "number" and not ns:IsSecret(v) then return v end end
-- A world position, remembered for the plan when PlannerStops.lua is there.
local function Pos(map, x, y)
    if ns.PlannerMemoPos then return ns.PlannerMemoPos(map, x, y) end
    return ns.PlannerWorldPos(map, x, y)
end
local function R1(v) return floor(v * 10 + 0.5) / 10 end

local function Clean(s)
    if type(s) ~= "string" or ns:IsSecret(s) then return nil end
    s = ns.Trim((s:gsub("[|@\r\n]", " ")))
    return s ~= "" and s or nil
end

------------------------------------------------------------------------------------------
-- The mailbox: wanted while mail waits; a hub the route passes, or a detour under 20 seconds
------------------------------------------------------------------------------------------
ns.PlannerRegisterStop({
    id = "mail", setting = "plannerMail", kind = "mail", maxDetour = ns.PLANNER_MAIL_SECONDS,
    want = function()
        if type(HasNewMail) ~= "function" then return nil end
        local ok, has = pcall(HasNewMail)
        if ok and has == false then
            local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(false)
            if type(rec) == "table" and type(rec.mailQuiet) == "table" then rec.mailQuiet.gone = true end
        end
        if not (ok and has == true and not ns:IsSecret(has)) then return nil end
        local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(false)
        local q = type(rec) == "table" and rec.mailQuiet
        if type(q) == "table" then              -- (a visit just ended: again only once the mail has gone and come anew, or 10 minutes on)
            local okT, now = pcall(GetTime)
            now = okT and Num(now) or nil
            if now and tonumber(q.t) and now >= q.t and now - q.t < ns.PLANNER_MAIL_QUIET and not q.gone then return nil end
            rec.mailQuiet = nil
        end
        return { visit = type(rec) == "table" and tonumber(rec.mailVisits) or 0, after = 0 }
    end,
    places = function(ctx) return ns.PlannerPlaces(ctx, "mailbox") end,
    text = function(place) return place.name end,
    key = function(reason) return reason.visit end,
})

------------------------------------------------------------------------------------------
-- Gathering nodes you have seen: recorded per account when you cast a gathering spell on one
------------------------------------------------------------------------------------------
local HERBALISM, MINING, SKINNING = 182, 186, 393
-- (The gathering recorder: ns.PlannerGatherSkill, ns.PlannerRecordNode and the one UNIT_SPELLCAST_SENT handler are in
-- the main add-on, PlannerRecorders.lua, so nodes are learned while this folder is not loaded.)

------------------------------------------------------------------------------------------
-- Legs, and what lies near them
------------------------------------------------------------------------------------------
-- A map's frame: world yards of a point in percent, and back (nil when the map has no usable scale).
local function Geo(map, cache)
    local g = cache[map]
    if g ~= nil then return g or nil end
    cache[map] = false
    local c, x0, y0 = ns.PlannerWorldPos(map, 0, 0)
    local c1, x1, y1 = ns.PlannerWorldPos(map, 100, 0)
    local c2, x2, y2 = ns.PlannerWorldPos(map, 0, 100)
    if not (c and c == c1 and c == c2) then return nil end
    local m11, m21, m12, m22 = (x1 - x0) / 100, (y1 - y0) / 100, (x2 - x0) / 100, (y2 - y0) / 100
    local det = m11 * m22 - m12 * m21
    if math.abs(det) < 1e-9 then return nil end
    g = { c = c, x0 = x0, y0 = y0, m11 = m11, m12 = m12, m21 = m21, m22 = m22, det = det }
    cache[map] = g
    return g
end

local function ToPercent(g, wx, wy)
    local dx, dy = wx - g.x0, wy - g.y0
    return (g.m22 * dx - g.m12 * dy) / g.det, (g.m11 * dy - g.m21 * dx) / g.det
end

local NOT_FROM = { fly = true, sail = true, hearth = true }

-- The legs: { a, b (step indexes), map, geo, ax, ay, bx, by (world), len, ux, uy }
local function Legs(steps, cache)
    local placed = {}
    for i, s in ipairs(steps) do
        ns.PlannerYield()
        if type(s) == "table" and tonumber(s.map) and tonumber(s.x) and tonumber(s.y) then placed[#placed + 1] = i end
    end
    local legs = {}
    for k = 1, #placed - 1 do
        ns.PlannerYield()
        local a, b = steps[placed[k]], steps[placed[k + 1]]
        if tonumber(a.map) == tonumber(b.map) and not NOT_FROM[a.kind] and b.kind ~= "hearth" then
            local map = tonumber(a.map)
            local g = Geo(map, cache)
            if g then
                local _, ax, ay = Pos(map, a.x, a.y)
                local _, bx, by = Pos(map, b.x, b.y)
                if ax and bx then
                    local len = sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
                    local ux, uy = 1, 0
                    if len >= 1 then ux, uy = (bx - ax) / len, (by - ay) / len end
                    legs[#legs + 1] = { a = placed[k], b = placed[k + 1], map = map, geo = g, ax = ax, ay = ay, bx = bx, by = by, len = len, ux = ux, uy = uy }
                end
            end
        end
    end
    return legs
end

-- Seconds a stop at world point (wx, wy) adds to a leg, at `speed` yards a second.
local function Detour(leg, wx, wy, speed)
    local d1 = sqrt((wx - leg.ax) ^ 2 + (wy - leg.ay) ^ 2)
    local d2 = sqrt((wx - leg.bx) ^ 2 + (wy - leg.by) ^ 2)
    return math.max(0, (d1 + d2 - leg.len) / speed)
end

-- How far along the leg (yards) the point's nearest part of the leg is.
local function Along(leg, wx, wy)
    local t = (wx - leg.ax) * leg.ux + (wy - leg.ay) * leg.uy
    return math.max(0, math.min(leg.len, t))
end

-- Is anything explored at this spot? true / false, or nil when the game can't say.
local function Explored(map, px, py)
    if type(C_MapExplorationInfo) ~= "table" or type(C_MapExplorationInfo.GetExploredAreaIDsAtPosition) ~= "function" or type(CreateVector2D) ~= "function" then return nil end
    local ok, list = pcall(function() return C_MapExplorationInfo.GetExploredAreaIDsAtPosition(map, CreateVector2D(px / 100, py / 100)) end)
    if not ok or ns:IsSecret(list) then return nil end
    if type(list) == "table" then return #list > 0 end
    if list == nil then return false end
    return nil
end

-- Does the map report exploration? Learned once a session per map (a "no" is asked again next plan,
-- so a new zone counts once you explore its first area): its explored textures, else a coarse grid of
-- samples (each counted in `budget`).
ns.plannerExploreMaps = ns.plannerExploreMaps or {}
local function Supports(map, budget)
    if ns.plannerExploreMaps[map] then return true end
    local api = type(C_MapExplorationInfo) == "table" and C_MapExplorationInfo or nil
    local answer
    if api and type(api.GetExploredMapTextures) == "function" then
        local ok, list = pcall(api.GetExploredMapTextures, map)
        if ok and not ns:IsSecret(list) and type(list) == "table" then answer = #list > 0 end
    end
    if answer == nil then
        answer = false
        for gx = 1, GRID do
            for gy = 1, GRID do
                ns.PlannerYield()
                if budget.left <= 0 then return false end
                budget.left = budget.left - 1
                if Explored(map, gx * 100 / (GRID + 1), gy * 100 / (GRID + 1)) then answer = true; break end
            end
            if answer then break end
        end
    end
    if answer then ns.plannerExploreMaps[map] = true end
    return answer
end

-- The explore spots you reached (per character, by map): { { x, y }, ... }
local function ReachedList(map, create)
    local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(create)
    if type(rec) ~= "table" then return nil end
    if type(rec.exploreReached) ~= "table" then
        if not create then return nil end
        rec.exploreReached = {}
    end
    local list = rec.exploreReached[map]
    if type(list) ~= "table" then
        if not create then return nil end
        list = {}
        rec.exploreReached[map] = list
    end
    return list
end

-- An explore step was reached (Guide.lua, when it ticks by being there): that spot is not asked again
-- (the game may never call it explored: the edge of a map, a spot outside every area).
function ns.PlannerExploreReached(step)
    if type(step) ~= "table" or step.kind ~= "explore" then return false end
    local map, x, y = Num(tonumber(step.map)), Num(tonumber(step.x)), Num(tonumber(step.y))
    if not (map and x and y) then return false end
    local list = ReachedList(map, true)
    if not list then return false end
    list[#list + 1] = { x = R1(x), y = R1(y) }
    while #list > REACHED_CAP do table.remove(list, 1) end
    return true
end

-- The world positions of the reached spots on a map (once per plan per map).
local function Reached(map, cache)
    local hit = cache[map]
    if hit then return hit end
    hit = {}
    for _, p in ipairs(ReachedList(map, false) or {}) do
        ns.PlannerYield()
        if type(p) == "table" and tonumber(p.x) and tonumber(p.y) then
            local c, wx, wy = Pos(map, p.x, p.y)
            if c then hit[#hit + 1] = { wx, wy } end
        end
    end
    cache[map] = hit
    return hit
end

local function NearReached(list, wx, wy)
    local r = ns.PLANNER_EXPLORE_REACHED
    for _, q in ipairs(list) do
        local dx, dy = q[1] - wx, q[2] - wy
        if dx * dx + dy * dy <= r * r then return true end
    end
    return false
end

local function ExploreSteps(legs, speed, add)
    local yards = ns.PLANNER_EXPLORE_YARDS
    local budget = { left = ns.PLANNER_EXPLORE_SAMPLES }
    -- sample every leg on a map that reports exploration, away from the spots you reached
    local supports, samples, reached = {}, {}, {}
    for li, leg in ipairs(legs) do
        local list = {}
        if supports[leg.map] == nil then supports[leg.map] = Supports(leg.map, budget) end
        if supports[leg.map] then
            local near = Reached(leg.map, reached)
            local n = math.min(SAMPLE_CAP, floor(leg.len / yards) + 1)
            for si = 0, n do
                local s = math.min(leg.len, si * yards)
                for _, off in ipairs({ 0, yards, -yards }) do
                    ns.PlannerYield()
                    if budget.left > 0 then
                        local wx, wy = leg.ax + leg.ux * s - leg.uy * off, leg.ay + leg.uy * s + leg.ux * off
                        local px, py = ToPercent(leg.geo, wx, wy)
                        if px >= 0 and px <= 100 and py >= 0 and py <= 100 and not NearReached(near, wx, wy) then
                            budget.left = budget.left - 1
                            list[#list + 1] = { wx = wx, wy = wy, px = px, py = py, seen = Explored(leg.map, px, py) }
                        end
                    end
                end
            end
        end
        samples[li] = list
    end
    -- the unexplored ones, nearest to the path first
    local cands = {}
    for li, leg in ipairs(legs) do
        for _, p in ipairs(samples[li]) do
            ns.PlannerYield()
            if p.seen == false then
                local d = Detour(leg, p.wx, p.wy, speed)
                if d <= ns.PLANNER_EXPLORE_SECONDS then cands[#cands + 1] = { leg = li, p = p, d = d } end
            end
        end
    end
    table.sort(cands, function(x, y) return x.d < y.d end)
    local chosen = {}
    for _, c in ipairs(cands) do
        ns.PlannerYield()
        if #chosen >= ns.PLANNER_EXPLORE_MAX then break end
        local apart = true
        for _, o in ipairs(chosen) do
            if legs[o.leg].map == legs[c.leg].map and sqrt((o.p.wx - c.p.wx) ^ 2 + (o.p.wy - c.p.wy) ^ 2) < yards * APART then
                apart = false; break
            end
        end
        if apart then chosen[#chosen + 1] = c end
    end
    for _, c in ipairs(chosen) do
        local leg = legs[c.leg]
        local x, y = R1(c.p.px), R1(c.p.py)
        add(leg, Along(leg, c.p.wx, c.p.wy), {
            kind = "explore", text = ns:Tr("Unexplored area"), map = leg.map, x = x, y = y,
            why = { detour = floor(c.d + 0.5) }, stopKey = "explore:" .. leg.map .. ":" .. x .. "," .. y,
        }, c.d)
    end
end

local function GatherSteps(legs, speed, add, ctx)
    local mine = {}                                         -- your rank by skill line
    for _, p in ipairs(ns.PlannerProfessions and ns.PlannerProfessions() or {}) do
        if p.line == HERBALISM or p.line == MINING then mine[p.line] = tonumber(p.rank) or 0 end
    end
    if not next(mine) then return end
    local seen = type(ns.root) == "table" and type(ns.root.plannerNodesSeen) == "table" and ns.root.plannerNodesSeen or {}
    local src = type(ctx) == "table" and type(ctx.source) == "table" and ctx.source or nil
    local questie = src and type(src.gatherNodes) == "function" and src.gatherNodes or nil
    -- each map's nodes of your skills, with their world positions: once per plan. Yours first; then
    -- Questie's that your rank allows, unless one of yours of the same skill is within PLANNER_NODE_YARDS.
    local byMap = {}
    local function Nodes(map)
        local hit = byMap[map]
        if hit then return hit end
        hit = {}
        local list = seen[map]
        for _, n in ipairs(type(list) == "table" and list or {}) do
            ns.PlannerYield()
            local name = type(n) == "table" and Clean(n.name)
            if name and mine[n.skill] and tonumber(n.x) and tonumber(n.y) then
                local _, wx, wy = Pos(map, n.x, n.y)
                if wx then hit[#hit + 1] = { n = n, name = name, wx = wx, wy = wy, skill = n.skill } end
            end
        end
        local recorded = #hit
        local nodes = questie and questie(map) or {}
        for _, n in ipairs(type(nodes) == "table" and nodes or {}) do
            ns.PlannerYield()
            local name = type(n) == "table" and Clean(n.name)
            local rank = name and mine[n.skill]
            if rank and tonumber(n.min) and rank >= n.min and tonumber(n.x) and tonumber(n.y) then
                local _, wx, wy = Pos(map, n.x, n.y)
                local same = not wx
                for i = 1, recorded do
                    if same then break end
                    local e = hit[i]
                    if e.skill == n.skill and sqrt((e.wx - wx) ^ 2 + (e.wy - wy) ^ 2) <= ns.PLANNER_NODE_YARDS then same = true end
                end
                if not same then hit[#hit + 1] = { n = n, name = name, wx = wx, wy = wy, skill = n.skill } end
            end
        end
        byMap[map] = hit
        return hit
    end
    local cands = {}
    for li, leg in ipairs(legs) do
        for _, e in ipairs(Nodes(leg.map)) do
            ns.PlannerYield()
            local d = Detour(leg, e.wx, e.wy, speed)
            if d <= ns.PLANNER_GATHER_SECONDS then
                cands[#cands + 1] = { leg = li, n = e.n, name = e.name, wx = e.wx, wy = e.wy, d = d }
            end
        end
    end
    table.sort(cands, function(x, y) return x.d < y.d end)
    local used, count = {}, 0
    for _, c in ipairs(cands) do
        if count >= ns.PLANNER_GATHER_MAX then break end
        if not used[c.n] then
            used[c.n] = true
            count = count + 1
            local leg = legs[c.leg]
            local x, y = R1(tonumber(c.n.x)), R1(tonumber(c.n.y))
            add(leg, Along(leg, c.wx, c.wy), {
                kind = "gather", text = c.name, map = leg.map, x = x, y = y,
                why = { detour = floor(c.d + 0.5) }, stopKey = "gather:" .. c.name .. ":" .. leg.map .. ":" .. x .. "," .. y,
            }, c.d)
        end
    end
end

-- Unexplored spots and gathering nodes near the plan's legs, put before each leg's destination.
function ns.PlannerPathExtras(guide, summary, ctx)
    if type(guide) ~= "table" or type(guide.steps) ~= "table" then return end
    ctx = type(ctx) == "table" and ctx or {}
    local explore = not (ns.db and ns.db.plannerExplore == false)
    local gather = not (ns.db and ns.db.plannerGather == false)
    if not (explore or gather) then return end
    local steps = guide.steps
    local speed = Num(ctx.speed) or (ns.PLANNER_SPEED and ns.PLANNER_SPEED.run) or 7
    if speed <= 0 then return end
    local legs = {}
    for _, leg in ipairs(Legs(steps, {})) do                 -- (a quest with a clock on it: nothing on the way to or between its steps)
        if not steps[leg.b].timed then legs[#legs + 1] = leg end
    end
    if #legs == 0 then return end
    local pending, extra = {}, 0
    local function add(leg, along, step, secs)
        local list = pending[leg.b]
        if not list then list = {}; pending[leg.b] = list end
        list[#list + 1] = { t = along, step = step }
        extra = extra + secs
    end
    if explore then ExploreSteps(legs, speed, add) end
    if gather then GatherSteps(legs, speed, add, ctx) end
    if not next(pending) then return end
    local out = {}
    for i, s in ipairs(steps) do
        ns.PlannerYield()
        local list = pending[i]
        if list then
            table.sort(list, function(x, y) return x.t < y.t end)
            for _, e in ipairs(list) do out[#out + 1] = e.step end
        end
        out[#out + 1] = s
    end
    for i = #steps, 1, -1 do steps[i] = nil end
    for i, s in ipairs(out) do steps[i] = s end
    if type(summary) == "table" then summary.seconds = (tonumber(summary.seconds) or 0) + floor(extra + 0.5) end
end

-- Do you have the profession? (by its skill line); false when the game can't say.
function ns.PlannerHasProfession(line)
    for _, p in ipairs(ns.PlannerProfessions and ns.PlannerProfessions() or {}) do
        if p.line == line then return true end
    end
    return false
end
ns.PLANNER_SKINNING_LINE = SKINNING
ns.FolderFileDone("planner", "PlannerPath.lua")
