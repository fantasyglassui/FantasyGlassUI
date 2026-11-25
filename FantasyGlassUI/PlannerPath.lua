local _, ns = ...

------------------------------------------------------------------------------------------
-- Planner stops along the way: the mailbox when mail is waiting, unexplored spots near the path,
-- and the gathering nodes you have seen. A "leg" is the straight line between two successive
-- placed steps of the plan on one map (the route keeps no run legs of its own).
-- Runs inside the planning coroutine: ns.PlannerYield() in plain loops, never inside pcall.
------------------------------------------------------------------------------------------
local ipairs, pairs, type, tonumber, math = ipairs, pairs, type, tonumber, math
local floor, sqrt = math.floor, math.sqrt

ns.PLANNER_MAIL_SECONDS = 20            -- a mail stop only when it adds less than this (or the route passes a mailbox)
ns.PLANNER_MAIL_QUIET = 600             -- seconds after a visit before the same mail brings you back
ns.PLANNER_EXPLORE_SECONDS = 15         -- an unexplored spot only when it adds at most this much
ns.PLANNER_EXPLORE_MAX = 3              -- per plan
ns.PLANNER_EXPLORE_YARDS = 40           -- sample spacing along a leg, and how far either side of it
ns.PLANNER_GATHER_SECONDS = 20          -- a node only when it adds at most this much
ns.PLANNER_GATHER_MAX = 5               -- per plan
ns.PLANNER_NODE_YARDS = 10              -- two gatherings this close are one node
local NODE_CAP = 300                    -- nodes kept per map
local SAMPLE_CAP = 200                  -- samples along one leg
local APART = 2                         -- explore spots are this many sample spacings apart, at least

local function Num(v) if type(v) == "number" and not ns:IsSecret(v) then return v end end
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
local GATHER_SPELLS = {
    [2366] = HERBALISM, [2368] = HERBALISM, [3570] = HERBALISM, [11993] = HERBALISM,
    [2575] = MINING, [2576] = MINING, [3564] = MINING, [10248] = MINING,
    [8613] = SKINNING, [8617] = SKINNING, [8618] = SKINNING, [10768] = SKINNING,
}
local BASE_SPELLS = { [2366] = HERBALISM, [2575] = MINING, [8613] = SKINNING }   -- (their names, in your language, say the rest)

local function SpellName(id)
    if type(C_Spell) ~= "table" or type(C_Spell.GetSpellInfo) ~= "function" then return nil end
    local ok, info = pcall(C_Spell.GetSpellInfo, id)
    local name = ok and type(info) == "table" and info.name or nil
    return type(name) == "string" and not ns:IsSecret(name) and name or nil
end

-- The skill line (182, 186, 393) a spell gathers with, or nil.
function ns.PlannerGatherSkill(spellID)
    spellID = Num(spellID)
    if not spellID then return nil end
    if GATHER_SPELLS[spellID] then return GATHER_SPELLS[spellID] end
    local name = SpellName(spellID)
    if not name then return nil end
    for id, line in pairs(BASE_SPELLS) do
        if SpellName(id) == name then return line end
    end
end

local function NodeWorld(map, x, y)
    local c, wx, wy = ns.PlannerWorldPos(map, x, y)
    return c, wx, wy
end

-- Record a node (once per 10 yards, per skill). Saved tables are made only here.
function ns.PlannerRecordNode(map, x, y, name, skill)
    map, x, y = Num(map), Num(x), Num(y)
    name = Clean(name)
    if not (map and x and y and name and type(ns.root) == "table") then return false end
    if skill ~= HERBALISM and skill ~= MINING then return false end
    local list = type(ns.root.plannerNodesSeen) == "table" and type(ns.root.plannerNodesSeen[map]) == "table" and ns.root.plannerNodesSeen[map] or nil
    local c1, x1, y1 = NodeWorld(map, x, y)
    if not c1 then return false end                 -- (no world scale on this map: nothing is recorded)
    if list then
        for _, n in ipairs(list) do
            if type(n) == "table" and n.skill == skill and n.name == name then
                local c2, x2, y2 = NodeWorld(map, tonumber(n.x), tonumber(n.y))
                if c2 == c1 and sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2) <= ns.PLANNER_NODE_YARDS then return false end
            end
        end
        if #list >= NODE_CAP then return false end
    end
    if type(ns.root.plannerNodesSeen) ~= "table" then ns.root.plannerNodesSeen = {} end
    if type(ns.root.plannerNodesSeen[map]) ~= "table" then ns.root.plannerNodesSeen[map] = {} end
    local out = ns.root.plannerNodesSeen[map]
    out[#out + 1] = { name = name, x = R1(x), y = R1(y), skill = skill }
    return true
end

do
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_SENT", "player")
    ev:SetScript("OnEvent", ns:Guard("Planner gather", function(_, _, unit, target, _, spellID)
        if ns:IsSecret(unit) or unit ~= "player" or not ns:GuideUnlocked() or (ns.db and ns.db.plannerGather == false) then return end
        if type(target) ~= "string" or ns:IsSecret(target) or target == "" then return end
        local skill = ns.PlannerGatherSkill(spellID)
        if not skill or skill == SKINNING or not ns.GuideHere then return end   -- (skinning only drives the "skin them" note)
        local map, x, y = ns.GuideHere()
        if map and x and y then ns.PlannerRecordNode(map, x, y, target, skill) end
    end))
end

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
                local _, ax, ay = ns.PlannerWorldPos(map, a.x, a.y)
                local _, bx, by = ns.PlannerWorldPos(map, b.x, b.y)
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

local function ExploreSteps(legs, speed, add)
    local yards = ns.PLANNER_EXPLORE_YARDS
    -- sample every leg
    local supports, samples = {}, {}
    for li, leg in ipairs(legs) do
        local list = {}
        local n = math.min(SAMPLE_CAP, floor(leg.len / yards) + 1)
        for si = 0, n do
            local s = math.min(leg.len, si * yards)
            for _, off in ipairs({ 0, yards, -yards }) do
                ns.PlannerYield()
                local wx, wy = leg.ax + leg.ux * s - leg.uy * off, leg.ay + leg.uy * s + leg.ux * off
                local px, py = ToPercent(leg.geo, wx, wy)
                if px >= 0 and px <= 100 and py >= 0 and py <= 100 then
                    local seen = Explored(leg.map, px, py)
                    if seen then supports[leg.map] = true end
                    list[#list + 1] = { wx = wx, wy = wy, px = px, py = py, seen = seen }
                end
            end
        end
        samples[li] = list
    end
    -- the unexplored ones on maps that report exploration, nearest to the path first
    local cands = {}
    for li, leg in ipairs(legs) do
        if supports[leg.map] then
            for _, p in ipairs(samples[li]) do
                ns.PlannerYield()
                if p.seen == false then
                    local d = Detour(leg, p.wx, p.wy, speed)
                    if d <= ns.PLANNER_EXPLORE_SECONDS then cands[#cands + 1] = { leg = li, p = p, d = d } end
                end
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

local function GatherSteps(legs, speed, add)
    local mine = {}
    for _, p in ipairs(ns.PlannerProfessions and ns.PlannerProfessions() or {}) do
        if p.line == HERBALISM or p.line == MINING then mine[p.line] = true end
    end
    local seen = type(ns.root) == "table" and ns.root.plannerNodesSeen
    if not (next(mine) and type(seen) == "table") then return end
    local cands = {}
    for li, leg in ipairs(legs) do
        local list = seen[leg.map]
        if type(list) == "table" then
            for _, n in ipairs(list) do
                ns.PlannerYield()
                local name = type(n) == "table" and Clean(n.name)
                if name and mine[n.skill] and tonumber(n.x) and tonumber(n.y) then
                    local _, wx, wy = ns.PlannerWorldPos(leg.map, n.x, n.y)
                    if wx then
                        local d = Detour(leg, wx, wy, speed)
                        if d <= ns.PLANNER_GATHER_SECONDS then
                            cands[#cands + 1] = { leg = li, n = n, name = name, wx = wx, wy = wy, d = d }
                        end
                    end
                end
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
    local legs = Legs(steps, {})
    if #legs == 0 then return end
    local pending, extra = {}, 0
    local function add(leg, along, step, secs)
        local list = pending[leg.b]
        if not list then list = {}; pending[leg.b] = list end
        list[#list + 1] = { t = along, step = step }
        extra = extra + secs
    end
    if explore then ExploreSteps(legs, speed, add) end
    if gather then GatherSteps(legs, speed, add) end
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
