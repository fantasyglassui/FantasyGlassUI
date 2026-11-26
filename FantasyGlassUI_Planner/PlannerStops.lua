local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end

------------------------------------------------------------------------------------------
-- Planner stops: things worth doing on the way (your class trainer, a vendor, the mailbox...).
-- Each stop is registered with ns.PlannerRegisterStop(def):
--     def = { id = "classTrainer", setting = "plannerTrainer", kind = "train" | "vendor" | "mail",
--             want = function(ctx, summary, guide) -> reason or nil,
--             places = function(ctx, reason) -> { { name, map, x, y, id }, ... },
--             text = function(place, reason) -> the step's words,
--             why = function(reason) -> a table for step.why, or nil,
--             key = function(reason) -> what makes this visit a new one (optional; the class trainer: its level),
--             maxDetour = seconds (optional: where the stop would add that much or more travel, it is left out) }
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

-- World positions. A place (from the source's session cache) keeps its own once worked out; any other
-- spot (a step, where you stand) is remembered per map, x and y for the plan (ns.PlannerPosReset
-- starts a plan afresh). A place is told from a step by its kind.
local memo = {}
local function MemoPos(map, x, y)
    map, x, y = tonumber(map), tonumber(x), tonumber(y)
    if not (map and x and y) then return nil end
    local k = map .. ":" .. x .. ":" .. y
    local v = memo[k]
    if v == nil then
        local c, wx, wy = ns.PlannerWorldPos(map, x, y)
        v = c and { c, wx, wy } or false
        memo[k] = v
    end
    if v then return v[1], v[2], v[3] end
end
ns.PlannerMemoPos = MemoPos
function ns.PlannerPosReset() memo = {} end

local function PlacePos(p)
    local k = p._wk
    local sig = tostring(p.map) .. ":" .. tostring(p.x) .. ":" .. tostring(p.y)
    if k ~= sig then
        local c, wx, wy = ns.PlannerWorldPos(p.map, p.x, p.y)
        p._wk, p._wc, p._wx, p._wy = sig, c or false, wx, wy
    end
    if p._wc then return p._wc, p._wx, p._wy end
end

local function Pos(s)
    if type(s) ~= "table" then return nil end
    if s.kind == nil then return PlacePos(s) end
    return MemoPos(s.map, s.x, s.y)
end

local function Yards(a, b)
    local c1, x1, y1 = Pos(a)
    local c2, x2, y2 = Pos(b)
    if not c1 or c1 ~= c2 then return huge end
    local dx, dy = x1 - x2, y1 - y2
    return sqrt(dx * dx + dy * dy)
end

local function Spot(s) return { map = s.map, x = s.x, y = s.y } end

-- The route's reach: per continent, the box around its placed steps (and where you stand).
ns.PLANNER_PLACE_YARDS = 2000           -- places farther than this from that box are not looked at (but see Near)
local function RouteBox(steps, here)
    local box = {}
    local function Add(c, wx, wy)
        local b = box[c]
        if not b then box[c] = { x0 = wx, x1 = wx, y0 = wy, y1 = wy }; return end
        if wx < b.x0 then b.x0 = wx elseif wx > b.x1 then b.x1 = wx end
        if wy < b.y0 then b.y0 = wy elseif wy > b.y1 then b.y1 = wy end
    end
    for _, s in ipairs(steps) do
        ns.PlannerYield()
        if type(s) == "table" then
            local c, wx, wy = MemoPos(s.map, s.x, s.y)
            if c then Add(c, wx, wy) end
        end
    end
    if type(here) == "table" then
        local c, wx, wy = MemoPos(here.map, here.x, here.y)
        if c then Add(c, wx, wy) end
    end
    return box
end

-- The places near the route: those within ns.PLANNER_PLACE_YARDS of its box; with none, the few nearest
-- to it on its continents; with none there either, any few (as the least-travel search tries them).
local function Near(list, box)
    local inside, others = {}, {}
    for _, p in ipairs(list) do
        ns.PlannerYield()
        local c, wx, wy = PlacePos(p)
        local b = c and box[c]
        if b then
            local dx = math.max(b.x0 - wx, 0, wx - b.x1)
            local dy = math.max(b.y0 - wy, 0, wy - b.y1)
            local d = sqrt(dx * dx + dy * dy)
            if d <= ns.PLANNER_PLACE_YARDS then inside[#inside + 1] = p else others[#others + 1] = { p = p, d = d } end
        end
    end
    if #inside > 0 then return inside end
    local out = {}
    if #others > 0 then
        for _ = 1, NEAREST do
            local bi
            for i, o in ipairs(others) do
                if not o.used and (not bi or o.d < others[bi].d) then bi = i end
            end
            if not bi then break end
            others[bi].used = true
            out[#out + 1] = others[bi].p
        end
        return out
    end
    for i = 1, math.min(NEAREST, #list) do out[i] = list[i] end
    return out
end

-- The places of a kind from the planner's source (not through pcall: the source yields as it reads).
-- While stops are put into a plan (ctx.routeBox), only those near the route.
function ns.PlannerPlaces(ctx, kind, arg)
    local src = type(ctx) == "table" and ctx.source
    if type(src) ~= "table" or type(src.places) ~= "function" then return {} end
    local list, out = src.places(kind, arg), {}
    for _, p in ipairs(type(list) == "table" and list or {}) do
        if type(p) == "table" and tonumber(p.map) and tonumber(p.x) and tonumber(p.y) then out[#out + 1] = p end
    end
    if type(ctx.routeBox) == "table" and #out > 0 then return Near(out, ctx.routeBox) end
    return out
end

-- A slot (insert before steps[k]) inside a timed run: a step with a clock on it on both sides. Nothing goes there.
local function InTimedRun(steps, k)
    local a, b = steps[k - 1], steps[k]
    return type(a) == "table" and type(b) == "table" and a.timed and b.timed and true or false
end

-- Where each step's hub takes a stop: after the hub's last accept, else before its first do; a step of
-- no hub takes it right after itself (a flight or a boat: before, where you stand before leaving).
-- The accepts and dos of a timed run are not counted (with only those: after the run's last hand-in), and a
-- slot inside a timed run moves on to the run's end.
local function HubSlots(steps)
    local lastAccept, firstDo, lastTimed = {}, {}, {}
    for i, t in ipairs(steps) do
        ns.PlannerYield()
        local h = t.hub
        if h ~= nil then
            if t.timed then
                if t.kind == "turnin" then lastTimed[h] = i end
            else
                if t.kind == "accept" then lastAccept[h] = i end
                if t.kind == "do" and not firstDo[h] then firstDo[h] = i end
            end
        end
    end
    local function Out(k)
        while InTimedRun(steps, k) do k = k + 1 end
        return k
    end
    return function(k)
        local s = steps[k]
        local h = s.hub
        if h == nil then return Out((s.kind == "fly" or s.kind == "sail") and k or k + 1) end
        if lastAccept[h] then return Out(lastAccept[h] + 1) end
        if firstDo[h] then return Out(firstDo[h]) end
        if lastTimed[h] then return Out(lastTimed[h] + 1) end
        return Out(k + 1)
    end
end

-- Slot (insert before steps[slot]), place and detour seconds (nil when it goes at a hub); nil when
-- no place can be reached. Only slots after step `after`.
local function Where(steps, places, ctx, tctx, after)
    local hubYards = ns.PLANNER_HUB_YARDS or 150
    -- each place's nearest step (of those it could go at), and the nearest hub match of all
    local slots, at = {}, {}            -- at: the steps it could go at, with their world positions
    local HubSlot = HubSlots(steps)
    for i, s in ipairs(steps) do
        ns.PlannerYield()
        if s.x and s.y then
            slots[i] = HubSlot(i)
            if slots[i] > after then
                local c, wx, wy = Pos(s)
                if c then at[#at + 1] = { i = i, c = c, x = wx, y = wy } end
            end
        end
    end
    -- the nearest step to each place; and of the hubs with a place in reach, the first on the route
    local near, best = {}, nil
    for pi, place in ipairs(places) do
        local d = huge
        local pc, px, py = Pos(place)
        for _, a in ipairs(pc and at or {}) do
            ns.PlannerYield()
            if a.c == pc then
                local i = a.i
                local dx, dy = a.x - px, a.y - py
                local y = sqrt(dx * dx + dy * dy)
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
            if slot > after and not InTimedRun(steps, slot) then
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
    ns.PlannerPosReset()
    ctx.routeBox = RouteBox(steps, ctx.here)
    for _, def in ipairs(ns.plannerStops) do
        ns.PlannerYield()
        local on = not (def.setting and ns.db and ns.db[def.setting] == false)
        local reason = on and def.want(ctx, summary, guide) or nil
        if reason then
            ctx.stopsWanted[def.id] = reason
            local places = type(def.places) == "function" and def.places(ctx, reason) or nil
            local after = type(reason) == "table" and tonumber(reason.after) or 0
            local slot, place, detour = Where(steps, type(places) == "table" and places or {}, ctx, tctx, after)
            local cap = tonumber(def.maxDetour)             -- (a stop that is only worth a short detour: none farther)
            if slot and detour and cap and detour >= cap then slot = nil end
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
        if s.kind == "turnin" and s.hub == steps[c].hub then
            if s.timed then return end                  -- (a quest with a clock on it is handed in at once, never held)
            group[#group + 1] = i
        end
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

------------------------------------------------------------------------------------------
-- The vendor: sell, repair and restock. Wanted when your bags are nearly full (3 free slots or
-- fewer), something you wear is worn (under 30%), or supplies run short for the plan. Any read
-- that fails, is nil or is secret means that reason is simply not wanted.
------------------------------------------------------------------------------------------
ns.PLANNER_VENDOR_SLOTS = 3
ns.PLANNER_VENDOR_DURABILITY = 0.30
ns.PLANNER_VENDOR_QUIET = 600          -- seconds after a visit before the same reason brings you back
ns.PLANNER_SUPPLIES = {
    ammo = { arrow = { { 1, 2512 }, { 10, 2515 }, { 25, 3030 }, { 40, 11285 } },
             bullet = { { 1, 2516 }, { 10, 2519 }, { 25, 3033 }, { 40, 11284 } } },
    drink = { { 1, 159 }, { 5, 1179 }, { 15, 1205 }, { 25, 1708 }, { 35, 1645 }, { 45, 8766 } },
    food = { { 1, 4540 }, { 5, 4541 }, { 15, 4542 }, { 25, 4544 }, { 35, 4601 }, { 45, 8950 } },
}
local SUPPLY_ORDER = { "arrow", "bullet", "drink", "food" }
local SUPPLY_RATE = { arrow = 600, bullet = 600, drink = 12, food = 8 }      -- per hour, until measured
local SUPPLY_STEP = { arrow = 200, bullet = 200, drink = 20, food = 20 }     -- buy in these
local SUPPLY_LIST = { arrow = "Ammo", bullet = "Ammo", drink = "Drink", food = "Food" }
local SUPPLY_PHRASE = { arrow = "buy %d arrows", bullet = "buy %d bullets", drink = "buy %d water", food = "buy %d food" }
local MANA_CLASSES = { MAGE = true, PRIEST = true, WARLOCK = true, PALADIN = true, DRUID = true, SHAMAN = true, HUNTER = true }
local SAMPLE_CAP = 3600                 -- seconds counted per sample
local SAMPLE_KEEP = 20                  -- hours of samples kept (older ones count half)

-- Free slots in your bags 0-4; nil if any read fails or is secret.
function ns.PlannerBagFree()
    if type(C_Container) ~= "table" or type(C_Container.GetContainerNumFreeSlots) ~= "function" then return nil end
    local total = 0
    for bag = 0, 4 do
        local ok, free = pcall(C_Container.GetContainerNumFreeSlots, bag)
        free = ok and Num(free) or nil
        if not free then return nil end
        total = total + free
    end
    return total
end

-- The lowest cur/max of what you wear (slots 1-19 that have durability); nil when none can be read.
function ns.PlannerLowestDurability()
    if type(GetInventoryItemDurability) ~= "function" then return nil end
    local lowest
    for slot = 1, 19 do
        local ok, cur, max = pcall(GetInventoryItemDurability, slot)
        if not ok then return nil end
        if ns:IsSecret(cur) or ns:IsSecret(max) then return nil end
        cur, max = Num(cur), Num(max)           -- (an empty slot or a worn-out-proof item has none: skipped)
        if cur and max and max > 0 then
            local r = cur / max
            if not lowest or r < lowest then lowest = r end
        end
    end
    return lowest
end

local function EnumValue(group, name, fallback)
    if type(Enum) ~= "table" then return fallback end
    local g = Enum[group]
    local v = type(g) == "table" and g[name] or nil
    return type(v) == "number" and v or fallback
end

-- "arrow", "bullet" or nil: what the ranged slot holds takes which ammunition.
local function AmmoKind()
    if type(C_Item) ~= "table" or type(C_Item.GetItemInfoInstant) ~= "function" or type(GetInventoryItemID) ~= "function" then return nil end
    local okI, id = pcall(GetInventoryItemID, "player", 18)
    id = okI and Num(id) or nil
    if not id then return nil end
    local ok, _, _, _, _, _, class, sub = pcall(C_Item.GetItemInfoInstant, id)
    class, sub = ok and Num(class) or nil, ok and Num(sub) or nil
    if not (class and sub) or class ~= EnumValue("ItemClass", "Weapon", 2) then return nil end
    if sub == EnumValue("ItemWeaponSubclass", "Bows", 2) or sub == EnumValue("ItemWeaponSubclass", "Crossbow", 18) then return "arrow" end
    if sub == EnumValue("ItemWeaponSubclass", "Guns", 3) then return "bullet" end
    return nil
end

local function ClassToken()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    return ok and type(token) == "string" and not ns:IsSecret(token) and token or nil
end

local function UsesMana()
    if type(UnitPowerType) == "function" then
        local ok, t = pcall(UnitPowerType, "player")
        t = ok and Num(t) or nil
        if t and t == EnumValue("PowerType", "Mana", 0) then return true end
    end
    if type(UnitClass) == "function" then
        local ok, _, token = pcall(UnitClass, "player")
        if ok and type(token) == "string" and not ns:IsSecret(token) and MANA_CLASSES[token] then return true end
    end
    return false
end

local function SupplyTiers(key)
    local t = ns.PLANNER_SUPPLIES
    return (key == "arrow" or key == "bullet") and t.ammo[key] or t[key]
end

-- The item to buy: the best of its table for your level.
local function SupplyItem(key, level)
    local best
    for _, e in ipairs(SupplyTiers(key)) do
        if e[1] <= level then best = e[2] end
    end
    return best
end

local function ItemCount(item)
    if type(C_Item) ~= "table" or type(C_Item.GetItemCount) ~= "function" then return nil end
    local ok, n = pcall(C_Item.GetItemCount, item)
    return ok and Num(n) or nil
end

-- What you carry of a supply: every tier of its table you can use (at or below your level); nil
-- when none of them can be read.
local function SupplyCount(key, level)
    local total
    for _, e in ipairs(SupplyTiers(key)) do
        if e[1] <= level then
            local n = ItemCount(e[2])
            if n then total = (total or 0) + n end
        end
    end
    return total
end

-- Use per hour, measured from the counts seen at each plan (only drops count, not what you bought;
-- the time between two samples is at most an hour). The default until there are 2 samples.
local MEASURE_HOURS = 0.25          -- hours of samples before the measured rate is used
local RATE_CLAMP = 4                    -- at most this many times the default
local function UseRate(key, count)
    local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(true)
    local okT, now = pcall(GetTime)
    now = okT and Num(now) or nil
    local default = SUPPLY_RATE[key]
    if type(rec) ~= "table" or not now then return default end
    if type(rec.supply) ~= "table" then rec.supply = {} end
    local s = rec.supply[key]
    if type(s) ~= "table" or not (tonumber(s.n) and tonumber(s.t)) then
        s = { n = count, t = now, samples = 1, drops = 0, hours = 0 }
        rec.supply[key] = s
        return default
    end
    local dt = now - s.t
    s.samples = (tonumber(s.samples) or 1) + 1
    if dt >= 0 and dt <= SAMPLE_CAP then          -- (a longer gap, or a clock that went back: a new baseline, nothing added)
        if count < s.n then s.drops = (tonumber(s.drops) or 0) + (s.n - count) end
        s.hours = (tonumber(s.hours) or 0) + dt / 3600
    end
    s.n, s.t = count, now
    if s.hours > SAMPLE_KEEP then s.hours, s.drops = s.hours / 2, s.drops / 2 end
    if s.samples >= 2 and s.hours >= MEASURE_HOURS then return math.min(s.drops / s.hours, default * RATE_CLAMP) end
    return default
end

-- What runs short for `hours` of play: { { key, item, count, buy }, ... }
local function SupplyNeeds(level, hours)
    local out = {}
    local ammo = AmmoKind()
    local mana = UsesMana() and ClassToken() ~= "MAGE"     -- (a mage conjures water)
    for _, key in ipairs(SUPPLY_ORDER) do
        if key == ammo or key == "food" or (key == "drink" and mana) then
            local item = SupplyItem(key, level)
            local count = item and SupplyCount(key, level)
            if count then
                local rate = UseRate(key, count)
                if count < rate * hours then
                    local step = SUPPLY_STEP[key]
                    local buy = math.max(step, math.ceil((rate - count) / step) * step)
                    out[#out + 1] = { key = key, item = item, count = count, buy = buy }
                end
            end
        end
    end
    return out
end

-- Places as a set: the same place is the same NPC (by id), the same map, x and y, or a spot within 10
-- yards (looked up in a 10-yard grid of world positions, so each place is looked at once).
local SAME_YARDS = 10
local function NewSet() return { ids = {}, spots = {}, cells = {} } end

local function CellKey(c, gx, gy) return c .. ":" .. gx .. ":" .. gy end

local function InSet(set, p)
    if p.id ~= nil and set.ids[p.id] then return true end
    if set.spots[tostring(p.map) .. ":" .. tostring(p.x) .. ":" .. tostring(p.y)] then return true end
    local c, wx, wy = Pos(p)
    if not c then return false end
    local gx, gy = floor(wx / SAME_YARDS), floor(wy / SAME_YARDS)
    for dx = -1, 1 do
        for dy = -1, 1 do
            local cell = set.cells[CellKey(c, gx + dx, gy + dy)]
            if cell then
                for _, q in ipairs(cell) do
                    local ex, ey = q[1] - wx, q[2] - wy
                    if ex * ex + ey * ey <= SAME_YARDS * SAME_YARDS then return true end
                end
            end
        end
    end
    return false
end

local function AddToSet(set, p)
    if p.id ~= nil then set.ids[p.id] = true end
    set.spots[tostring(p.map) .. ":" .. tostring(p.x) .. ":" .. tostring(p.y)] = true
    local c, wx, wy = Pos(p)
    if c then
        local k = CellKey(c, floor(wx / SAME_YARDS), floor(wy / SAME_YARDS))
        local cell = set.cells[k]
        if not cell then cell = {}; set.cells[k] = cell end
        cell[#cell + 1] = { wx, wy }
    end
end

local function SetOf(list)
    local set = NewSet()
    for _, p in ipairs(list) do
        ns.PlannerYield()
        AddToSet(set, p)
    end
    return set
end

local function Merge(...)
    local out, set = {}, NewSet()
    for n = 1, select("#", ...) do
        for _, p in ipairs((select(n, ...))) do
            ns.PlannerYield()
            if not InSet(set, p) then
                out[#out + 1] = p
                AddToSet(set, p)
            end
        end
    end
    return out
end

local function Both(a, b)
    local out, set = {}, SetOf(b)
    for _, p in ipairs(a) do
        ns.PlannerYield()
        if InSet(set, p) then out[#out + 1] = p end
    end
    return out
end

ns.PlannerRegisterStop({
    id = "vendor", kind = "vendor",     -- (its two settings are read below: supplies can be a stop alone)
    want = function(ctx, summary)
        local reason = { visit = 0, supplies = {} }
        local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(false)
        reason.visit = type(rec) == "table" and tonumber(rec.vendorVisits) or 0
        if not (ns.db and ns.db.plannerVendor == false) then
            local free, worn = ns.PlannerBagFree(), ns.PlannerLowestDurability()
            reason.repair = worn ~= nil and worn < ns.PLANNER_VENDOR_DURABILITY
            reason.sell = reason.repair or (free ~= nil and free <= ns.PLANNER_VENDOR_SLOTS)
        end
        if not (ns.db and ns.db.plannerSupplies == false) then
            local hours = math.max(0.5, (tonumber(summary and summary.seconds) or 0) / 3600)
            reason.supplies = SupplyNeeds(tonumber(ctx.level) or 1, hours)
        end
        if not reason.sell and #reason.supplies == 0 then return nil end
        -- a visit just ended: the same reason does not bring you back (unsellable items, no money to repair)
        -- for a while, unless it gained something new
        local last = { repair = reason.repair and true or false, sell = reason.sell and true or false, supplies = {} }
        for _, need in ipairs(reason.supplies) do last.supplies[need.key] = true end
        local q = type(rec) == "table" and rec.vendorQuiet
        local okT, now = pcall(GetTime)
        now = okT and Num(now) or nil
        if type(q) == "table" and type(q.seen) == "table" and now and tonumber(q.t) and now >= q.t and now - q.t < ns.PLANNER_VENDOR_QUIET then
            local fresh = (last.repair and not q.seen.repair) or (last.sell and not q.seen.sell)
            for key in pairs(last.supplies) do if not q.seen.supplies[key] then fresh = true end end
            if not fresh then return nil end
            q.seen = { repair = last.repair or q.seen.repair, sell = last.sell or q.seen.sell, supplies = q.seen.supplies }
            for key in pairs(last.supplies) do q.seen.supplies[key] = true end
        end
        local now2 = ns.PlannerCharRecord and ns.PlannerCharRecord(false)
        if type(now2) == "table" then now2.vendorLast = last end
        return reason
    end,
    places = function(ctx, reason)
        -- what sells each supply, and the places that sell all of them (else those of the first)
        reason.lists = {}
        local kept, first, all = {}, nil, nil
        for _, need in ipairs(reason.supplies) do
            local list = ns.PlannerPlaces(ctx, "vendor", SUPPLY_LIST[need.key])
            if #list > 0 then
                reason.lists[need.key] = SetOf(list)
                kept[#kept + 1] = need
                first = first or list
                all = all and Both(all, list) or list
            end
        end
        reason.supplies = kept
        local buy = all and (#all > 0 and all or first) or {}
        if not reason.sell then return buy end
        if not reason.repair then
            if #buy > 0 then return buy end                     -- (any vendor buys: the supplies vendor serves selling too)
            local sell = Merge(ns.PlannerPlaces(ctx, "repair"), ns.PlannerPlaces(ctx, "anyVendor"), ns.PlannerPlaces(ctx, "vendor", "Food"),
                ns.PlannerPlaces(ctx, "vendor", "Drink"), ns.PlannerPlaces(ctx, "vendor", "Ammo"))
            if #sell == 0 then reason.sell = false end
            return sell
        end
        local sell = ns.PlannerPlaces(ctx, "repair")
        if #sell == 0 then
            reason.sell, reason.repair = false, false
            return buy
        end
        local both = Both(sell, buy)
        if #both > 0 then return both end
        return sell
    end,
    text = function(place, reason)
        local name = place.name or ""
        local head
        if reason.sell then
            head = string.format(ns:Tr(reason.repair and "Sell and repair at %s" or "Sell at %s"), name)
        else
            head = string.format(ns:Tr("Buy supplies at %s"), name)
        end
        local parts = { head }
        for _, need in ipairs(reason.supplies) do
            local set = type(reason.lists) == "table" and reason.lists[need.key]
            if set and InSet(set, place) then parts[#parts + 1] = string.format(ns:Tr(SUPPLY_PHRASE[need.key]), need.buy) end
        end
        return table.concat(parts, "; ")
    end,
    key = function(reason) return reason.visit end,
})

------------------------------------------------------------------------------------------
-- Profession training (a capped profession below the game's top: its next trainer), and riding at
-- level 40 (the riding trainer, then your mount). Reads that fail, are nil or secret: not wanted.
------------------------------------------------------------------------------------------
ns.PLANNER_PROFESSION_TOP = 300         -- Forever's classic skills end here; a trainer may say otherwise
ns.PLANNER_RIDING_LEVEL = 40
ns.PLANNER_RIDING_LINE = 762
ns.PLANNER_RIDING_COPPER = 100 * 10000  -- Apprentice Riding
ns.PLANNER_MOUNT_COPPER = 20 * 10000    -- the mount (Paladins and Warlocks get theirs from class quests)
ns.PLANNER_PROFESSION_LINES = { 171, 164, 333, 202, 182, 165, 186, 393, 197, 185, 129, 356, 633 }
local NO_VENDOR_MOUNT = { PALADIN = true, WARLOCK = true }

-- { { line, name, rank, maxRank }, ... } of your professions; nil when the game can't say.
local function Professions()
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then return nil end
    local list = { pcall(GetProfessions) }
    if not list[1] then return nil end
    local out = {}
    for i = 2, 8 do
        local index = list[i]
        if type(index) == "number" and not ns:IsSecret(index) then
            local ok, name, _, rank, maxRank, _, _, line = pcall(GetProfessionInfo, index)
            if ok and not ns:IsSecret(name) then
                rank, maxRank, line = Num(rank), Num(maxRank), Num(line)
                if type(name) == "string" and rank and maxRank and line then out[#out + 1] = { line = line, name = name, rank = rank, maxRank = maxRank } end
            end
        end
    end
    return out
end

ns.PlannerProfessions = Professions

local function Copper()
    if type(GetMoney) ~= "function" then return nil end
    local ok, m = pcall(GetMoney)
    return ok and Num(m) or nil
end


-- Gold as the add-on writes it (its coin formatter, else "40g").
function ns.PlannerGoldText(copper)
    copper = floor(tonumber(copper) or 0)
    local ok, s = pcall(function() return ns:Coins(copper) end)
    if ok and type(s) == "string" and s ~= "" then return s end
    return floor(copper / 10000) .. "g"
end

-- Apprentice to Master riding (all ranks), Forever's modern spell book
ns.PLANNER_RIDING_SPELLS = { 33388, 33391, 34090, 34091, 90265, 33389, 33392 }
-- The level each profession rank needs: you can train the next rank from its cap (75 -> 150 at 10 ...)
ns.PLANNER_PROFESSION_LEVEL = { [75] = 10, [150] = 20, [225] = 35 }

-- (Have you been seen mounted? ns.PlannerMountSeen: in the main add-on, PlannerRecorders.lua.)

-- Do you ride? true / false, or nil when nothing can say. Once any sign is seen it is kept for the character.
function ns.PlannerRidingKnown(profs)
    local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(false)
    if type(rec) == "table" and rec.ridingKnown then return true end
    local readable, known = false, false
    if profs then
        readable = true
        for _, p in ipairs(profs) do
            if p.line == ns.PLANNER_RIDING_LINE and p.rank > 0 then known = true end
        end
    end
    if type(C_SpellBook) == "table" and type(C_SpellBook.IsSpellKnown) == "function" then
        for _, id in ipairs(ns.PLANNER_RIDING_SPELLS) do
            local ok, v = pcall(C_SpellBook.IsSpellKnown, id)
            if ok and type(v) == "boolean" and not ns:IsSecret(v) then
                readable = true
                if v then known = true end
            end
        end
    end
    local mounted = ns.PlannerMountSeen()
    if mounted ~= nil then
        readable = true
        if mounted then known = true end
    end
    if known then
        local r = ns.PlannerCharRecord and ns.PlannerCharRecord(true)
        if type(r) == "table" then r.ridingKnown = true end
        return true
    end
    if readable then return false end
    return nil
end

-- What riding still needs: nil when it is not asked for (below level 40, riding known or not
-- readable, the game can't say your gold); else { short = copper still to find (0: affordable), mount = a vendor mount is needed }.
function ns.PlannerRiding(level)
    level = tonumber(level)
    if not level or level < ns.PLANNER_RIDING_LEVEL then return nil end
    if ns.PlannerRidingKnown(Professions()) ~= false then return nil end
    local money = Copper()
    if not money then return nil end
    local class = ClassToken()
    local mount = not (class and NO_VENDOR_MOUNT[class])
    local need = ns.PLANNER_RIDING_COPPER + (mount and ns.PLANNER_MOUNT_COPPER or 0)
    return { short = math.max(0, need - money), mount = mount }
end

for _, line in ipairs(ns.PLANNER_PROFESSION_LINES) do
    ns.PlannerRegisterStop({
        id = "profession:" .. line, setting = "plannerProfession", kind = "train",
        want = function(ctx)
            for _, p in ipairs(Professions() or {}) do
                local need = ns.PLANNER_PROFESSION_LEVEL[p.maxRank] or 1
                if p.line == line and p.rank >= p.maxRank and p.maxRank < ns.PLANNER_PROFESSION_TOP and (tonumber(ctx.level) or 1) >= need then
                    return { line = line, name = p.name, maxRank = p.maxRank, after = 0 }
                end
            end
        end,
        places = function(ctx) return ns.PlannerPlaces(ctx, "professionTrainer", line) end,
        text = function(place, reason) return string.format(ns:Tr("Learn %s at %s"), reason.name, place.name or "") end,
        key = function(reason) return reason.maxRank end,
    })
end

ns.PlannerRegisterStop({
    id = "riding", setting = "plannerMount", kind = "train",
    want = function(ctx)
        local r = ns.PlannerRiding(ctx.level)
        if r and r.short <= 0 then return { mount = r.mount, after = 0 } end
    end,
    places = function(ctx) return ns.PlannerPlaces(ctx, "professionTrainer", ns.PLANNER_RIDING_LINE) end,
    text = function(place) return string.format(ns:Tr("Learn %s at %s"), ns:Tr("Riding"), place.name or "") end,
    key = function() return "riding" end,
})

-- The mount: a reason of its own (not only right after the riding trainer). Wanted at level 40 or
-- more when you ride (or this plan trains riding), no mount has been seen, your class buys its mount
-- (not a Paladin or Warlock) and your gold covers it.
ns.PlannerRegisterStop({
    id = "mount", setting = "plannerMount", kind = "vendor",
    want = function(ctx, _, guide)
        local level = tonumber(ctx.level)
        if not level or level < ns.PLANNER_RIDING_LEVEL then return nil end
        local class = ClassToken()
        if not class or NO_VENDOR_MOUNT[class] then return nil end
        if ns.PlannerMountSeen() ~= false then return nil end        -- (seen mounted, or the game can't say)
        local riding = ctx.stopsWanted and ctx.stopsWanted.riding
        if type(riding) == "table" then
            for i, s in ipairs(guide.steps) do  -- (after the riding trainer's step; the gold for both was counted there)
                if s.kind == "train" and type(s.stopKey) == "string" and s.stopKey:sub(1, 7) == "riding:" then
                    return { after = i }
                end
            end
            return nil
        end
        local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(false)
        if not (type(rec) == "table" and rec.ridingKnown) and ns.PlannerRidingKnown(Professions()) ~= true then return nil end
        local money = Copper()
        if not money or money < ns.PLANNER_MOUNT_COPPER then return nil end
        return { after = 0 }
    end,
    places = function(ctx) return ns.PlannerPlaces(ctx, "mountVendor") end,
    text = function(place) return string.format(ns:Tr("Buy your mount at %s"), place.name or "") end,
    key = function() return "mount" end,
})
ns.FolderFileDone("planner", "PlannerStops.lua")
