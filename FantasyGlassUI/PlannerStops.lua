local _, ns = ...

------------------------------------------------------------------------------------------
-- Planner stops: things worth doing on the way (your class trainer, a vendor, the mailbox...).
-- Each stop is registered with ns.PlannerRegisterStop(def):
--     def = { id = "classTrainer", setting = "plannerTrainer", kind = "train" | "vendor" | "mail",
--             want = function(ctx, summary, guide) -> reason or nil,
--             places = function(ctx, reason) -> { { name, map, x, y, id }, ... },
--             text = function(place, reason) -> the step's words,
--             why = function(reason) -> a table for step.why, or nil,
--             key = function(reason) -> what makes this visit a new one (optional; the class trainer: its level) }
-- A stop step carries step.stopKey = id .. ":" .. key (in memory, not in the guide's text): a tick you
-- gave one stop is kept in the next plan, but not given to the next visit (Guide.lua's StepKey).
-- After the route is made, ns.PlannerAddStops puts each wanted stop into it: at a hub when one of
-- its places is that close, else where it adds the least travel (that detour is added to the
-- plan's time). A reason may carry `after = n`: the stop goes after the route's step n.
-- Runs inside the planning coroutine: ns.PlannerYield() in the loops, never inside pcall.
------------------------------------------------------------------------------------------
local ipairs, pairs, type, tonumber, math = ipairs, pairs, type, tonumber, math
local floor, sqrt = math.floor, math.sqrt
local huge = math.huge
local NEAREST = 3                       -- places tried for the least-travel spot (the nearest to the route)

ns.plannerStops = ns.plannerStops or {}

-- Register a stop (a second one with the same id replaces the first). Only the stop kinds of Guide.lua.
function ns.PlannerRegisterStop(def)
    if type(def) ~= "table" or type(def.id) ~= "string" or type(def.want) ~= "function" or not ns.GUIDE_STOP_KINDS[def.kind] then return false end
    local list = ns.plannerStops
    for i, d in ipairs(list) do
        if d.id == def.id then list[i] = def; return true end
    end
    list[#list + 1] = def
    return true
end

local function R1(v) return floor(v * 10 + 0.5) / 10 end

-- Text that survives a guide line: no "|" (it starts the text) and no "@" (it starts the place).
local function Clean(s)
    if type(s) ~= "string" then return nil end
    s = ns.Trim((s:gsub("[|@\r\n]", " ")))
    return s ~= "" and s or nil
end

local function Pos(s)
    if type(s) ~= "table" then return nil end
    return ns.PlannerWorldPos(s.map, s.x, s.y)
end

local function Yards(a, b)
    local c1, x1, y1 = Pos(a)
    local c2, x2, y2 = Pos(b)
    if not c1 or c1 ~= c2 then return huge end
    local dx, dy = x1 - x2, y1 - y2
    return sqrt(dx * dx + dy * dy)
end

local function Spot(s) return { map = s.map, x = s.x, y = s.y } end

-- The places of a kind from the planner's source (not through pcall: the source yields as it reads).
function ns.PlannerPlaces(ctx, kind, arg)
    local src = type(ctx) == "table" and ctx.source
    if type(src) ~= "table" or type(src.places) ~= "function" then return {} end
    local list, out = src.places(kind, arg), {}
    for _, p in ipairs(type(list) == "table" and list or {}) do
        if type(p) == "table" and tonumber(p.map) and tonumber(p.x) and tonumber(p.y) then out[#out + 1] = p end
    end
    return out
end

-- Where step k's hub takes a stop: after the hub's last accept, else before its first do; a step of
-- no hub takes it right after itself (a flight or a boat: before, where you stand before leaving).
local function HubSlot(steps, k)
    local s = steps[k]
    local h = s.hub
    if h == nil then return (s.kind == "fly" or s.kind == "sail") and k or k + 1 end
    local lastAccept, firstDo
    for i, t in ipairs(steps) do
        if t.hub == h then
            if t.kind == "accept" then lastAccept = i end
            if t.kind == "do" and not firstDo then firstDo = i end
        end
    end
    if lastAccept then return lastAccept + 1 end
    if firstDo then return firstDo end
    return k + 1
end

-- Slot (insert before steps[slot]), place and detour seconds (nil when it goes at a hub); nil when
-- no place can be reached. Only slots after step `after`.
local function Where(steps, places, ctx, tctx, after)
    local hubYards = ns.PLANNER_HUB_YARDS or 150
    -- each place's nearest step (of those it could go at), and the nearest hub match of all
    local slots = {}
    for i, s in ipairs(steps) do
        ns.PlannerYield()
        if s.x and s.y then slots[i] = HubSlot(steps, i) end
    end
    -- the nearest step to each place; and of the hubs with a place in reach, the first on the route
    local near, best = {}, nil
    for pi, place in ipairs(places) do
        local d = huge
        for i, s in ipairs(steps) do
            ns.PlannerYield()
            if slots[i] and slots[i] > after then
                local y = Yards(place, s)
                if y < d then d = y end
                if y <= hubYards and (not best or slots[i] < slots[best.k] or (slots[i] == slots[best.k] and y < best.d)) then
                    best = { d = y, k = i, place = place }
                end
            end
        end
        near[pi] = d
    end
    if best then return slots[best.k], best.place, nil end
    -- else the least travel: the few places nearest the route (or any few, when none is on its continent)
    local tried, used = {}, {}
    for _ = 1, NEAREST do
        local bi, bd
        for pi in ipairs(places) do
            if not used[pi] and (not bd or near[pi] < bd) then bi, bd = pi, near[pi] end
        end
        if not bi then break end
        used[bi] = true
        tried[#tried + 1] = places[bi]
    end
    local here = type(ctx.here) == "table" and ctx.here.map and ctx.here or nil
    local placed = {}                   -- the placed steps, in order: { i, spot }
    for i, s in ipairs(steps) do if s.x and s.y then placed[#placed + 1] = { i = i, spot = Spot(s) } end end
    local function T(a, b)
        if not (a and b) then return 0 end
        local secs = ns.PlannerTravel(a, b, tctx)
        return tonumber(secs) or huge
    end
    local direct = {}                   -- direct[j]: placed[j-1] (or here) to placed[j]
    local function Direct(j)
        if direct[j] == nil then
            local from = j > 1 and placed[j - 1].spot or here
            direct[j] = from and T(from, placed[j].spot) or 0
        end
        return direct[j]
    end
    local bestSlot, bestPlace, bestCost
    for _, place in ipairs(tried) do
        local spot = Spot(place)
        local to, from = {}, {}         -- travel from placed[j] to the place, and from the place to placed[j]
        local j = 1                     -- the first placed step at or after the slot
        for slot = 1, #steps + 1 do
            ns.PlannerYield()
            while placed[j] and placed[j].i < slot do j = j + 1 end
            if slot > after then
                local prev = j > 1 and placed[j - 1].spot or here
                local toPlace = 0
                if prev then
                    if to[j - 1] == nil then to[j - 1] = T(prev, spot) end
                    toPlace = to[j - 1]
                end
                local cost = toPlace
                if placed[j] then
                    if from[j] == nil then from[j] = T(spot, placed[j].spot) end
                    local skip = prev and Direct(j) or 0
                    cost = skip < huge and cost + from[j] - skip or huge   -- (a leg the route can't make itself: no slot there)
                end
                if cost < huge and toPlace < huge and (not bestCost or cost < bestCost) then
                    bestSlot, bestPlace, bestCost = slot, place, cost
                end
            end
        end
    end
    if not bestSlot then return nil end
    return bestSlot, bestPlace, math.max(0, floor(bestCost + 0.5))
end

-- Put every wanted stop into the route (guide.steps), and add its detour to summary.seconds.
function ns.PlannerAddStops(guide, summary, ctx)
    ctx = ctx or {}
    ctx.stopsWanted = {}
    if type(guide) ~= "table" or type(guide.steps) ~= "table" then return end
    summary = summary or {}
    local tctx = {}
    for k, v in pairs(ctx) do tctx[k] = v end
    tctx.hearth = nil                   -- (a stop is no reason to use the hearthstone)
    local steps = guide.steps
    for _, def in ipairs(ns.plannerStops) do
        ns.PlannerYield()
        local on = not (def.setting and ns.db and ns.db[def.setting] == false)
        local reason = on and def.want(ctx, summary, guide) or nil
        if reason then
            ctx.stopsWanted[def.id] = reason
            local places = type(def.places) == "function" and def.places(ctx, reason) or nil
            local after = type(reason) == "table" and tonumber(reason.after) or 0
            local slot, place, detour = Where(steps, type(places) == "table" and places or {}, ctx, tctx, after)
            if slot then
                local text = Clean(type(def.text) == "function" and def.text(place, reason) or nil) or Clean(place.name)
                local step = { kind = def.kind, text = text, map = place.map, x = R1(place.x), y = R1(place.y) }
                local why = type(def.why) == "function" and def.why(reason) or nil
                if detour then
                    why = type(why) == "table" and why or {}
                    why.detour = detour
                    summary.seconds = (tonumber(summary.seconds) or 0) + detour
                end
                step.why = type(why) == "table" and why or nil
                step.stopKey = def.id .. ":" .. tostring(type(def.key) == "function" and def.key(reason) or "")
                table.insert(steps, slot, step)
            end
        end
    end
end

------------------------------------------------------------------------------------------
-- Your class trainer, every 2 levels
------------------------------------------------------------------------------------------
ns.PLANNER_TRAIN_EVERY = 2

-- The step after which the plan reaches `level`: hand-ins counted with what their accept said they
-- were worth. Nil when the plan can't tell.
local function ReachedAt(guide, ctx, level)
    local now, need = tonumber(ctx.xp), tonumber(ctx.xpMax)
    if not (now and need and need > 0) then return nil end
    local short = (level - (tonumber(ctx.level) or 1)) * need - now
    local worth, run = {}, 0
    for i, s in ipairs(guide.steps) do
        ns.PlannerYield()
        if s.quest and type(s.why) == "table" and s.kind == "accept" then worth[s.quest] = tonumber(s.why.xp) end
        if s.kind == "turnin" and s.quest and worth[s.quest] then
            run = run + worth[s.quest]
            if run >= short then return i end
        end
    end
end

ns.PlannerRegisterStop({
    id = "classTrainer", setting = "plannerTrainer", kind = "train",
    want = function(ctx, summary, guide)
        local level = tonumber(ctx.level) or 1
        if level < ns.PLANNER_TRAIN_EVERY then return nil end
        local every = ns.PLANNER_TRAIN_EVERY
        local reason
        if level % every == 0 and (tonumber(ctx.trainerLevel) or 0) < level then
            reason = { level = level, after = 0 }
        else
            local nextLevel = level + every - level % every
            if (tonumber(summary.toLevel) or level) >= nextLevel then
                reason = { level = nextLevel, after = ReachedAt(guide, ctx, nextLevel) or #guide.steps }
            end
        end
        if reason and #ns.PlannerPlaces(ctx, "classTrainer") > 0 then return reason end
    end,
    places = function(ctx) return ns.PlannerPlaces(ctx, "classTrainer") end,
    text = function(place) return place.name end,
    key = function(reason) return reason.level end,
})

------------------------------------------------------------------------------------------
-- Held hand-ins: a hand-in that would take you to the trainer's level waits for the trainer's town
-- (so you level where you train), when that town comes up soon, is visited anyway, and the hand-in
-- NPC is close to it: holding costs no extra trip. Runs right after ns.PlannerAddStops.
------------------------------------------------------------------------------------------
ns.PLANNER_HOLD_SECONDS = 300
local HANDLE = 5                        -- seconds to talk to an NPC (as PlannerRoute.lua counts it)

function ns.PlannerHoldTurnins(guide, summary, ctx)
    if type(guide) ~= "table" or type(guide.steps) ~= "table" or type(ctx) ~= "table" then return end
    if ns.db and ns.db.plannerHold == false then return end
    local steps = guide.steps
    local wanted = type(ctx.stopsWanted) == "table" and ctx.stopsWanted.classTrainer
    local level = type(wanted) == "table" and tonumber(wanted.level)
    if not level or level <= (tonumber(ctx.level) or 1) then return end
    -- the train step of that level, at a hub (a trainer that is a trip of its own is not visited anyway)
    local key, t = "classTrainer:" .. level, nil
    for i, s in ipairs(steps) do
        ns.PlannerYield()
        if s.kind == "train" and s.stopKey == key then t = i; break end
    end
    local train = t and steps[t]
    if not train or (type(train.why) == "table" and train.why.detour) then return end
    local c = ReachedAt(guide, ctx, level)              -- the hand-in that gets there
    if not c or c >= t or steps[c].kind ~= "turnin" or steps[c].hub == nil then return end
    local th = (steps[t - 1] and steps[t - 1].hub) or (steps[t + 1] and steps[t + 1].hub)
    if th == nil then return end
    -- it, and the later hand-ins of its hub (they would cross too): all or none
    local group = {}
    for i = c, t - 1 do
        ns.PlannerYield()
        local s = steps[i]
        if s.kind == "do" then return end               -- (time spent on quests in between: not worth holding for)
        if s.kind == "turnin" and s.hub == steps[c].hub then group[#group + 1] = i end
    end
    local hubYards = ns.PLANNER_HUB_YARDS or 150
    for _, i in ipairs(group) do
        ns.PlannerYield()
        local s = steps[i]
        local near = s.hub == th or Yards(s, train) <= hubYards
        if not near then
            for _, h in ipairs(steps) do
                if h.hub == th and Yards(s, h) <= hubYards then near = true; break end
            end
        end
        if not near then return end
    end
    -- the plan's time from the first hand-in to the trainer
    local tctx = {}
    for k, v in pairs(ctx) do tctx[k] = v end
    tctx.hearth = nil
    local secs, prev = 0, steps[c]
    for i = c + 1, t do
        ns.PlannerYield()
        local s = steps[i]
        if s.x and s.y then
            local d = tonumber((ns.PlannerTravel(prev, s, tctx))) or huge
            if d == huge then return end
            secs, prev = secs + d, s
        end
        if i < t and (s.kind == "accept" or s.kind == "turnin") then secs = secs + HANDLE end
    end
    if secs > ns.PLANNER_HOLD_SECONDS then return end
    -- move them: just before the train step, in their order
    local moved = {}
    for n = #group, 1, -1 do moved[n] = table.remove(steps, group[n]) end
    local at = t - #group
    for n, s in ipairs(moved) do
        s.why = { held = true }
        s.hub = th
        table.insert(steps, at + n - 1, s)
    end
end

------------------------------------------------------------------------------------------
-- Talent points waiting (Forever's modern talent API); nil when the game can't say
------------------------------------------------------------------------------------------
local function Num(v) if type(v) == "number" and not ns:IsSecret(v) then return v end end

function ns.PlannerUnspentTalents()
    if type(C_ClassTalents) ~= "table" or type(C_ClassTalents.GetActiveConfigID) ~= "function"
        or type(C_Traits) ~= "table" or type(C_Traits.GetConfigInfo) ~= "function" or type(C_Traits.GetTreeCurrencyInfo) ~= "function" then return nil end
    local okC, config = pcall(C_ClassTalents.GetActiveConfigID)
    config = okC and Num(config) or nil
    if not config then return nil end
    local okI, info = pcall(C_Traits.GetConfigInfo, config)
    local tree = okI and type(info) == "table" and type(info.treeIDs) == "table" and Num(info.treeIDs[1]) or nil
    if not tree then return nil end
    local okL, list = pcall(C_Traits.GetTreeCurrencyInfo, config, tree, false)
    if not (okL and type(list) == "table") then return nil end
    local total = 0
    for _, cur in ipairs(list) do
        local q = type(cur) == "table" and Num(cur.quantity) or nil
        if q and q > 0 then total = total + floor(q) end
    end
    return total
end
