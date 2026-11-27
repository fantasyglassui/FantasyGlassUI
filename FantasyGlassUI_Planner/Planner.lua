local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end

------------------------------------------------------------------------------------------
-- Planner: what a quest is worth (experience with kills, time, learned pace), and which quests
-- are candidates at all. Works on plain records from PlannerSource; nothing here sees Questie.
------------------------------------------------------------------------------------------
ns.PLANNER_BUDGET_MS = 4
ns.plannerBusy, ns.plannerQueued, ns.plannerSteps = false, false, 0

local running, sliceStart            -- the planning coroutine, and when its slice began
local runReason                      -- ns.plannerReason when that coroutine was made
local startPending = false           -- ns:PlannerStart() asked, and no plan applied or failed since: that plan's reason is "start"
                                     -- (however late it lands: replans that replace the start run, or Questie still loading, keep it the start's)
local job                            -- a small job run in slices while the planner is idle (ns.PlannerJob)

local function Clock()
    local v = debugprofilestop and debugprofilestop()
    return type(v) == "number" and v or 0
end
ns.plannerSliceMax = 0                -- the longest slice (ms) since it was last set back to 0: the speed tests read it
local function SliceDone()
    local took = Clock() - sliceStart
    if took > ns.plannerSliceMax then ns.plannerSliceMax = took end
end

-- Called in the planner's loops: inside the planning coroutine it hands the frame back once this
-- slice has used its time; anywhere else it does nothing.
function ns.PlannerYield()
    local co = coroutine.running()
    if co and (co == running or co == job) and Clock() - sliceStart >= (ns.PLANNER_BUDGET_MS or 4) then
        coroutine.yield()
    end
end

local ipairs, type, tonumber, math = ipairs, type, tonumber, math
local floor, min, max, sqrt = math.floor, math.min, math.max, math.sqrt

------------------------------------------------------------------------------------------
-- Hooks: where other planner files add to the planning without changing it here. A hook inside
-- the planning is called directly, never through pcall: it runs inside the planning coroutine and may
-- call ns.PlannerYield() (only in plain loops). "applied" runs outside it, each hook through pcall (a
-- failure goes to ns.errors as "Planner hook <key>: <error>" and the next hook still runs). Each run
-- works on a copy of the lists taken when it starts (ns.PlannerHookCopy). Points and their call sites:
--   "context"  fn(ctx)                     end of ns.PlannerContext (may widen windowLo/windowHi, let quest ids past the
--                                          cheap pre-filter in ctx.windowPass = { [id] = true }, raise horizon)
--   "window"   fn(rec, ctx, lo, hi) -> lo, hi   ns.PlannerWindow (the level window of one quest)
--   "xp"       fn(rec, ctx) -> number      added to a quest's score in ns.PlannerQuestXP
--   "zone"     fn(maps, order, ctx) -> map|nil   ns.PlannerPickZone: the first map with hubs wins
--   "rank"     fn(ranked, c, info)         each round of the route's hubs (may change score and first)
--   "route"    fn(guide, summary, ctx, c)  end of the route's Build
--   "extra"    fn(c, state, zone) -> { pseudoHub, ... } | nil   the route's Build, once, after the zone pick: places
--              ranked with the zone's hubs (a dungeon run). pseudoHub = { xp = number, seconds = number, map, x, y,
--              into = spot|nil, quests = { rec, ... }, lay = function(state, hub, steps, n) -> seconds, xp, kept };
--              one without lay, a number xp and a number seconds is ignored. Its rank entry is { hub, travel, rate,
--              score = rate, first = 0, extra = true }, ranked only while zone hubs or the lead-in are left, or there
--              is no zone; taken, it is summary.taken[n].extra = true and lays its own steps (ns.PlannerTrip helps)
--   "applied"  fn(guide, summary, ctx, reason)   after a plan became the guide you follow
--   "candidate" fn(rec, ctx, logged) -> false|other   ns.PlannerCandidates, each record about to be kept (a logged
--              quest, a new quest that passed every test, before the group check, a class quest, a quest from an
--              item before it waits for the route): exactly false drops it
--   "replan"   fn(reason) -> false|other   ns:PlannerReplan (after the Following check) and ns:PlannerStart
--              (reason "start", after the GuideOn check): exactly false makes the call return false (PlannerReplan:
--              false, "refused") and change nothing
------------------------------------------------------------------------------------------
local hooks, NONE = {}, {}
-- Add a hook (a second fn with the same key replaces the first, in its place; fn nil removes it).
function ns.PlannerHook(point, key, fn)
    if type(point) ~= "string" or key == nil then return end
    local list = hooks[point]
    if not list then list = {}; hooks[point] = list end
    for i, h in ipairs(list) do
        if h.key == key then
            if type(fn) == "function" then h.fn = fn else table.remove(list, i) end
            return
        end
    end
    if type(fn) == "function" then list[#list + 1] = { key = key, fn = fn } end
end
-- The hooks of a point, in the order they were first added: { { key = k, fn = f } } (read only).
function ns.PlannerHookList(point)
    return hooks[point] or NONE
end
-- A copy of a point's hooks: a hook added or removed while a plan is being made (a time limit cleared
-- by a step) changes the next plan, never the one running.
function ns.PlannerHookCopy(point)
    local out = {}
    for i, h in ipairs(hooks[point] or NONE) do out[i] = h end
    return out
end
-- The hooks a plan uses: the copies ns.PlannerContext took (ctx.hooks), else the lists as they are now.
ns.PLANNER_HOOK_POINTS = { "context", "window", "xp", "zone", "rank", "route", "candidate", "extra" }
function ns.PlannerHooksFor(ctx, point)
    local own = type(ctx) == "table" and type(ctx.hooks) == "table" and ctx.hooks[point]
    return type(own) == "table" and own or hooks[point] or NONE
end

-- Does every "candidate" hook let this record be kept? (Any hook returning exactly false drops it.)
local function Keep(rec, ctx, logged)
    for _, h in ipairs(ns.PlannerHooksFor(ctx, "candidate")) do    -- (the run's own copy, like every hook inside a plan)
        if h.fn(rec, ctx, logged) == false then return false end
    end
    return true
end

-- May this replan (or start) go ahead? (Any "replan" hook returning exactly false refuses it.)
local function ReplanOK(reason)
    for _, h in ipairs(hooks.replan or NONE) do
        if h.fn(reason) == false then return false end
    end
    return true
end

-- A shift of the level window that a "context" hook asked for (ctx.windowShift = { lo, hi }, the duo's: up by lo,
-- down by hi). It is applied after every hook, so it narrows whatever the hooks made, in whatever order they run.
local function Shift(ctx)
    local s = type(ctx) == "table" and type(ctx.windowShift) == "table" and ctx.windowShift or nil
    return s and tonumber(s.lo) or 0, s and tonumber(s.hi) or 0
end
-- The cheap pre-filter's bounds, shifted once (ns.PlannerContext calls it after the "context" hooks).
function ns.PlannerShiftWindow(ctx)
    if type(ctx) ~= "table" or ctx.windowShifted then return end
    local dlo, dhi = Shift(ctx)
    local level = tonumber(ctx.level) or 1
    ctx.windowLo, ctx.windowHi = (tonumber(ctx.windowLo) or (level - 4)) + dlo, (tonumber(ctx.windowHi) or (level + 2)) + dhi
    ctx.windowShifted = true
end

-- The level window of a quest: level - 4 to level + 2, then every "window" hook, then the context's shift.
function ns.PlannerWindow(rec, ctx)
    local level = type(ctx) == "table" and tonumber(ctx.level) or 1
    local lo, hi = level - 4, level + 2
    for _, h in ipairs(ns.PlannerHooksFor(ctx, "window")) do
        local a, b = h.fn(rec, ctx, lo, hi)
        lo, hi = tonumber(a) or lo, tonumber(b) or hi
    end
    local dlo, dhi = Shift(ctx)
    return lo + dlo, hi + dhi
end

local UNKNOWN_COUNT = 8 -- Questie gives no kill counts; the quest log does, once a quest is taken

-- (Kill experience, the classic formula ns.PlannerKillXP: in the main add-on, PlannerRecorders.lua.)

------------------------------------------------------------------------------------------
-- Candidates
------------------------------------------------------------------------------------------
-- (Questie writes "this quest done" as -id in a pre list)
local function PreId(id) return type(id) == "number" and math.abs(id) or id end

local function AllDone(list, done)
    for _, id in ipairs(list or {}) do if not done(PreId(id)) then return false end end
    return true
end

local function AnyDone(list, done)
    if not list or #list == 0 then return true end
    for _, id in ipairs(list) do if done(PreId(id)) then return true end end
    return false
end

local function InWindow(rec, ctx)
    if not tonumber(rec.level) then return false end   -- (a record with no level: left out)
    local lo, hi = ns.PlannerWindow(rec, ctx)
    return rec.level >= lo and rec.level <= hi
end

local function NeedsGroup(rec) return (rec.elite or rec.group or rec.dungeon) and true or false end

-- Does the group setting let this quest through (an elite your class has soloed counts as solo)?
local function GroupOK(rec, ctx, level)
    if not NeedsGroup(rec) or ctx.group == "all" or (ctx.group == "grouped" and ctx.inGroup) then return true end
    return (ctx.soloElites and rec.elite and not rec.group and not rec.dungeon and tonumber(rec.level) and ns.PlannerSoloEliteOK(ctx.class, rec.level - level)) and true or false
end

-- Quests that exclude each other (Questie's exclusiveTo): of the records given, the ids that stay, { [id] = true }.
-- The lists are read both ways (two quests are in one set when either names the other) and sets join through
-- shared ids, also ids that are not among the records. From each set one stays: a quest in your log (every
-- logged one, and nothing else of its set); else, of the members that can still be taken (a record whose own
-- list names a done quest cannot), a class quest; else the most real experience (ns.PlannerQuestXP's third
-- value), then the lower id. A member joined only through another quest's list is not dropped by a done id it
-- never names. `blockers` (optional): logged records left out (a hook dropped them): they join sets and block
-- their partners as a logged quest does, and are never kept. ctx.allExclusive: every member that can be taken
-- stays (no pick of one). Runs inside the planning coroutine.
function ns.PlannerExclusiveKeep(recs, ctx, blockers)
    local keep = {}
    if type(recs) ~= "table" then return keep end
    ctx = type(ctx) == "table" and ctx or {}
    local done = type(ctx.done) == "function" and ctx.done or function() return false end
    local onQuest = type(ctx.onQuest) == "function" and ctx.onQuest or function() return false end
    local up, nodes = {}, {}
    local function Root(a)
        local r = a
        while up[r] ~= r do r = up[r] end
        while a ~= r do
            local nxt = up[a]
            up[a] = r
            a = nxt
        end
        return r
    end
    local function Add(id) if up[id] == nil then up[id] = id; nodes[#nodes + 1] = id end end
    local own, blocked = {}, {}
    local list = {}
    for _, rec in ipairs(recs) do list[#list + 1] = { rec = rec, own = true } end
    for _, rec in ipairs(type(blockers) == "table" and blockers or NONE) do list[#list + 1] = { rec = rec } end
    for _, e in ipairs(list) do
        ns.PlannerYield()
        local rec = e.rec
        if type(rec) == "table" and type(rec.id) == "number" then
            if e.own then own[#own + 1] = rec end
            Add(rec.id)
            if done(rec.id) then blocked[rec.id] = true end
            for _, other in ipairs(type(rec.exclusive) == "table" and rec.exclusive or NONE) do
                other = tonumber(other)
                if other and other ~= rec.id then
                    if done(other) then blocked[rec.id] = true end   -- (its own list names a done quest: it cannot be taken)
                    Add(other)
                    local a, b = Root(rec.id), Root(other)
                    if a ~= b then up[max(a, b)] = min(a, b) end
                end
            end
        end
    end
    local size, logged = {}, {}
    for _, id in ipairs(nodes) do
        ns.PlannerYield()
        local r = Root(id)
        size[r] = (size[r] or 0) + 1
        if onQuest(id) then logged[r] = true end
    end
    local class = ns.PlannerClassMap(ctx)
    local best = {}
    for _, rec in ipairs(own) do
        ns.PlannerYield()
        local r = Root(rec.id)
        if size[r] == 1 then
            keep[rec.id] = true
        elseif logged[r] then
            if onQuest(rec.id) then keep[rec.id] = true end
        elseif not blocked[rec.id] and ctx.allExclusive then
            keep[rec.id] = true                              -- (every member you could take: a duo friend's list, the leader picks)
        elseif not blocked[rec.id] then
            local tier = class[rec.id] and 1 or 0
            local _, _, real = ns.PlannerQuestXP(rec, ctx)
            real = tonumber(real) or 0
            local b = best[r]
            if not b or tier > b.tier or (tier == b.tier and (real > b.xp or (real == b.xp and rec.id < b.id))) then
                best[r] = { id = rec.id, tier = tier, xp = real }
            end
        end
    end
    for _, b in pairs(best) do keep[b.id] = true end
    return keep
end

-- Why the planner would never pick this quest by its own filters, whatever the log says: "skipped",
-- "hard" (above the level window) or "group" (needs a group the setting leaves out); nil when it would.
-- (Whether you can take it is not asked: a quest in your log is taken.)
function ns.PlannerRejects(rec, ctx)
    if type(rec) ~= "table" or type(ctx) ~= "table" then return nil end
    local level = ctx.level or 1
    if type(ctx.skip) == "table" and ctx.skip[rec.id] then return "skipped" end
    if tonumber(rec.level) and rec.level > select(2, ns.PlannerWindow(rec, ctx)) then return "hard" end
    if not GroupOK(rec, ctx, level) then return "group" end
    return nil
end

-- The class quests of this character, by id: { [questID] = { id, level, kind, parts } } (ctx.classQuests is the list).
function ns.PlannerClassMap(ctx)
    local map = {}
    for _, e in ipairs(type(ctx) == "table" and type(ctx.classQuests) == "table" and ctx.classQuests or {}) do
        if type(e) == "table" and type(e.id) == "number" and tonumber(e.level) then map[e.id] = e end
    end
    return map
end

-- list of records worth considering, skipped = { group = n } (left out only by the group setting), and
-- the item-started quests the route has yet to judge (PlannerRoute: is the dropping NPC near a spot of the route?).
-- ctx.skip: quests never suggested (kept while they are in the log); ctx.soloElites + ctx.class: an elite
-- your class has soloed at this level difference is let through (and is not counted as skipped).
-- ctx.classQuests: class quests at or below your level are candidates whatever the level window says (the skip
-- list still applies). A quest an item starts, that an NPC drops: a candidate at once (starting where you are) when the
-- item is in your bags; otherwise left to the route (third result), which takes it when that NPC stands within a
-- hub's radius of a spot of the route.
function ns.PlannerCandidates(source, ctx)
    local list, skipped = {}, { group = 0 }
    if type(source) ~= "table" or type(ctx) ~= "table" then return list, skipped end
    local level, done, onQuest = ctx.level or 1, ctx.done or function() return false end, ctx.onQuest or function() return false end
    local never = type(ctx.skip) == "table" and ctx.skip or nil
    local items, groupOnly, dropped = {}, {}, {}
    local maybe = {}                                     -- (not in your log under its own id: matched by its title below)
    if source.begin then source.begin(level) end
    for _, id in ipairs(source.ids()) do
        ns.PlannerYield()
        local logged = onQuest(id)
        local rec = (logged or not (never and never[id])) and (logged or not source.inRange or (type(ctx.windowPass) == "table" and ctx.windowPass[id]) or source.inRange(id, level, ctx.windowLo, ctx.windowHi)) and source.quest(id) or nil
        if rec and not logged and type(ctx.matchLog) == "function" and rec.doable and not rec.repeatable and not done(id) then
            maybe[#maybe + 1] = rec                      -- (one you could take: once every candidate is known, below)
        end
        if rec then
            if logged then
                if Keep(rec, ctx, true) then list[#list + 1] = rec else dropped[#dropped + 1] = rec end   -- (dropped: still blocks its partners)
            elseif rec.doable and not rec.repeatable and not done(id)
                and InWindow(rec, ctx)
                and AllDone(rec.pre, done) and AnyDone(rec.preAny, done) then
                if Keep(rec, ctx, false) then            -- (one a hook drops is not counted as skipped)
                    if not GroupOK(rec, ctx, level) then
                        groupOnly[#groupOnly + 1] = rec   -- (counted below, once per set of exclusive quests)
                    elseif rec.fromItem then
                        items[#items + 1] = rec
                    else
                        list[#list + 1] = rec
                    end
                end
            end
        end
    end
    -- in your log under another id, by its title (and level), when no other candidate has that title: taken, with the
    -- log's progress, instead of offered (a quest you could not take, or a repeatable one, is never matched)
    if #maybe > 0 then
        local function Without(t, r)
            for i = #t, 1, -1 do if t[i] == r then table.remove(t, i) end end
        end
        for _, r in ipairs(maybe) do
            ns.PlannerYield()
            if ctx.matchLog(r, maybe) and onQuest(r.id) then
                Without(list, r); Without(items, r); Without(groupOnly, r)
                local rec = source.quest(r.id) or r
                if Keep(rec, ctx, true) then list[#list + 1] = rec else dropped[#dropped + 1] = rec end
            end
        end
    end
    -- a quest Questie numbers otherwise, kept by its own record: the log's entry for it is the same quest, and goes
    if type(ctx.mappedId) == "function" then
        local same = {}
        for _, r in ipairs(list) do
            local m = ctx.mappedId(r.id)
            if type(m) == "number" and m ~= r.id then same[m] = true end
        end
        if next(same) then
            local function Drop(t)
                local o = {}
                for _, r in ipairs(t) do if not same[r.id] then o[#o + 1] = r end end
                return o
            end
            list, dropped = Drop(list), Drop(dropped)
        end
    end
    local have = {}
    for _, r in ipairs(list) do have[r.id] = true end
    for _, e in ipairs(type(ctx.classQuests) == "table" and ctx.classQuests or {}) do
        ns.PlannerYield()
        local id = type(e) == "table" and e.id
        if type(id) == "number" and not have[id] and tonumber(e.level) and e.level <= level and not done(id) and not (never and never[id]) then
            local rec = source.quest(id)
            if rec and not onQuest(id) and rec.doable and not rec.repeatable and GroupOK(rec, ctx, level)
                and AllDone(rec.pre, done) and AnyDone(rec.preAny, done) and Keep(rec, ctx, false) then
                have[id] = true
                list[#list + 1] = rec
            end
        end
    end
    local later = {}                                  -- (item quests judged against the route, once it is laid out)
    local here = type(ctx.here) == "table" and ctx.here.map and ctx.here.x and ctx.here.y and ctx.here or nil
    for _, rec in ipairs(items) do
        ns.PlannerYield()
        if not have[rec.id] then
            local held = type(ctx.itemCount) == "function" and (tonumber(ctx.itemCount(rec.fromItem.id)) or 0) > 0
            if held and here then
                local copy = {}
                for k, v in pairs(rec) do copy[k] = v end
                copy.starts, copy.haveItem = { { map = here.map, x = here.x, y = here.y } }, true
                have[rec.id] = true
                list[#list + 1] = copy
            else
                later[#later + 1] = rec
            end
        end
    end
    -- quests that exclude each other: one of each set, across the three lists (and the skipped count)
    local all = {}
    for _, r in ipairs(list) do all[#all + 1] = r end
    for _, r in ipairs(later) do all[#all + 1] = r end
    local keep = ns.PlannerExclusiveKeep(all, ctx, dropped)
    local kept, waiting = {}, {}
    for _, r in ipairs(list) do if keep[r.id] then kept[#kept + 1] = r end end
    for _, r in ipairs(later) do if keep[r.id] then waiting[#waiting + 1] = r end end
    -- (the logged partners' lists are read too: a group-only quest that a logged quest names cannot be taken;
    -- only group-only ids are counted, once per set)
    local counted, isGroupOnly = {}, {}
    for _, r in ipairs(groupOnly) do counted[#counted + 1] = r; isGroupOnly[r.id] = true end
    for _, r in ipairs(list) do if onQuest(r.id) then counted[#counted + 1] = r end end
    for id in pairs(ns.PlannerExclusiveKeep(counted, ctx, dropped)) do
        if isGroupOnly[id] then skipped.group = skipped.group + 1 end
    end
    return kept, skipped, waiting
end

------------------------------------------------------------------------------------------
-- Time
------------------------------------------------------------------------------------------
-- The farthest two spots of an objective, in yards (0 when they can't be placed). Kept on the objective
-- (o.spread) the first time: the time and the monsters on the way both read it, and the spots don't move.
-- Up to SPREAD_EXACT spots on a continent every pair is measured; past that (an NPC with hundreds of spawns)
-- two sweeps find it: the spot farthest from any one, then the spot farthest from that (at least half the
-- true spread, and nearly always all of it), so the work grows with the spots, not with their square.
local SPREAD_EXACT = 48
local function Spread(o)
    if type(o.spread) == "number" then return o.spread end
    local byC, order, n = {}, {}, 0
    for _, s in ipairs(o.spots or {}) do
        ns.PlannerYield()
        local c, x, y
        if ns.PlannerSpotPos then c, x, y = ns.PlannerSpotPos(s) else c, x, y = ns.PlannerWorldPos(s.map, s.x, s.y) end
        if c then
            local list = byC[c]
            if not list then list = {}; byC[c] = list; order[#order + 1] = c end
            list[#list + 1] = { x = x, y = y }
            n = n + 1
        end
    end
    local function D(a, b) local dx, dy = a.x - b.x, a.y - b.y; return sqrt(dx * dx + dy * dy) end
    local function Farthest(pts, from)
        local best, bestD = from, -1
        for i = 1, #pts do
            if i % 64 == 0 then ns.PlannerYield() end
            local d = D(pts[i], from)
            if d > bestD then best, bestD = pts[i], d end
        end
        return best, bestD
    end
    local far = 0
    for _, c in ipairs(order) do
        local pts = byC[c]
        if #pts <= SPREAD_EXACT then
            for i = 1, #pts do
                for j = i + 1, #pts do far = max(far, D(pts[i], pts[j])) end
            end
        else
            local a = Farthest(pts, pts[1])
            local _, d = Farthest(pts, a)
            far = max(far, d)
        end
    end
    if n > 0 or #(o.spots or {}) == 0 then o.spread = far end   -- (spots that can't be placed yet are tried again)
    return far
end

local function Count(o) return o.count or UNKNOWN_COUNT end

function ns.PlannerQuestTime(rec, ctx)
    ctx = ctx or {}
    local speed = tonumber(ctx.speed) or 0
    local t = 0
    for _, o in ipairs(rec.objectives or {}) do
        if o.kind == "kill" then t = t + Count(o) * 25
        elseif o.kind == "item" then t = t + Count(o) * 25 / 0.5
        elseif o.kind == "place" then t = t + 0
        else t = t + 60 end
        if speed > 0 then t = t + Spread(o) / speed end
    end
    t = t * (ctx.pace or 1)
    if ctx.noAlts then return t end                  -- (the formula alone: the pace is measured against it)
    -- what your other characters took for this quest (per account): the formula counts once, they up to three times
    local times = type(ns.root) == "table" and type(ns.root.plannerQuestTimes) == "table" and ns.root.plannerQuestTimes[rec.id]
    if type(times) == "table" and tonumber(times.n) and tonumber(times.avg) and times.n > 0 then
        local n = min(times.n, 3)
        t = (t + times.avg * n) / (1 + n)
    end
    return t
end

-- (Quest times, ns.PlannerRecordQuestTime: in the main add-on, PlannerRecorders.lua.)

------------------------------------------------------------------------------------------
-- Choices: the skip list, deaths and elites your class has soloed
------------------------------------------------------------------------------------------
-- Never suggest this quest (on), or suggest it again (off); plans again at once.
-- `name`: the quest's name to keep with it (the skip list shows it once the quest is gone from your log);
-- else the game's title for it, when it can read one. The entry is the name, or true.
local function SkipName(questID, name)
    if type(name) == "string" and not ns:IsSecret(name) then
        name = ns.Trim(name)
        if name ~= "" and name:sub(1, 1) ~= "#" then return name:sub(1, 120) end
    end
    local QL = C_QuestLog
    local ok, t = pcall(function() return QL and QL.GetTitleForQuestID and QL.GetTitleForQuestID(questID) end)
    if ok and type(t) == "string" and not ns:IsSecret(t) and t ~= "" then return t:sub(1, 120) end
    return true
end
function ns.PlannerSkip(questID, on, name)
    if type(questID) ~= "number" then return end
    if not on and ns.PlannerSessionUnskip then ns.PlannerSessionUnskip(questID) end   -- (suggested again: this session's plans too)
    local rec = ns.PlannerCharRecord(on and true or false)
    if not rec then return end
    if on then
        if type(rec.skip) ~= "table" then rec.skip = {} end
        rec.skip[questID] = SkipName(questID, name)
        -- (a quest in your log stays in the plan as long as it is there: left out of this session's plans too, and said so)
        if ns.PlannerSessionSkip then ns.PlannerSessionSkip(questID) end
        local QL = C_QuestLog
        local okQ, logged = pcall(function()
            if ns.PlannerServerId then return ns.PlannerServerId(questID) ~= nil end      -- (its own id, or the one it was matched to)
            return QL and QL.IsOnQuest and QL.IsOnQuest(questID)
        end)
        if okQ and ns.Is(logged, true) then ns:Print("Left out of your plans; it stays in your quest log until you abandon it.") end
    else
        if type(rec.skip) == "table" then rec.skip[questID] = nil end
    end
    if ns.PlannerReplan then ns:PlannerReplan("settings") end
end

-- The quests this character never wants suggested: { [questID] = true } (empty when there are none).
function ns.PlannerSkipList()
    local rec = ns.PlannerCharRecord(false)
    return rec and type(rec.skip) == "table" and rec.skip or {}
end

-- (Deaths, the class token and soloed elites are recorded in the main add-on, PlannerRecorders.lua.)

-- Has this class soloed an elite quest that many levels above (or more)?
function ns.PlannerSoloEliteOK(class, diff)
    local t = type(ns.root) == "table" and ns.root.plannerSoloElites
    local best = type(t) == "table" and type(class) == "string" and t[class]
    diff = tonumber(diff)
    return type(best) == "number" and diff ~= nil and best >= diff
end

------------------------------------------------------------------------------------------
-- Experience
------------------------------------------------------------------------------------------
-- The monsters met while walking between a kill objective's spots (the walk PlannerQuestTime times), a minute.
ns.PLANNER_WAY_KILLS = 0.5

-- What a quest's kills give: each kill objective's count, and the monsters on the way, at the formula
-- times what your kills at that level difference really give (PlannerKills.lua).
local function KillPart(rec, ctx)
    local level, speed = ctx.level or 1, tonumber(ctx.speed) or 0
    local xp = 0
    for _, o in ipairs(rec.objectives or {}) do
        if o.kind == "kill" then
            local mob = o.mobLevel or rec.level
            local each = ns.PlannerKillXP(level, mob, rec.elite)
            if each > 0 and ns.PlannerKillRatio and tonumber(mob) then each = each * ns.PlannerKillRatio(mob - level, rec.elite) end
            local kills = Count(o)
            if speed > 0 then kills = kills + Spread(o) / speed / 60 * ns.PLANNER_WAY_KILLS end
            xp = xp + kills * each
        end
    end
    return xp
end

-- Kills earn double while rested: the extra is the kill experience, up to what is left of the pool
-- (ctx.restedLeft, which the route lowers as it lays hubs out; ctx.rested when the route is not).
function ns.PlannerRestedExtra(rec, ctx)
    ctx = ctx or {}
    local left = tonumber(ctx.restedLeft)
    if left == nil then left = tonumber(ctx.rested) end
    if not left or left <= 0 then return 0 end
    return min(left, KillPart(rec, ctx))
end

-- Experience from a better item among the rewards of a quest in the log: 2% of a level per item level
-- gained, at most a quarter of a level. Unreadable or not loaded yet: 0.
function ns.PlannerRewardBonus(rec, ctx)
    ctx = ctx or {}
    if not (ns.db and ns.db.plannerRewards ~= false) or type(rec) ~= "table" or type(rec.id) ~= "number" then return 0 end
    if ctx.onQuest and not ctx.onQuest(rec.id) then return 0 end
    local cache = type(ctx.rewardCache) == "table" and ctx.rewardCache or nil   -- (per plan: links are read once)
    if cache and cache[rec.id] then return cache[rec.id] end
    local need = tonumber(ctx.xpMax)
    if not need then
        local okM, v = pcall(UnitXPMax, "player")
        need = okM and tonumber(v) or nil
    end
    if not need or need <= 0 or ns:IsSecret(need) then return 0 end
    local best = 0
    local function Scan(count, kind)
        local okN, n = pcall(count, rec.id)
        n = okN and type(n) == "number" and not ns:IsSecret(n) and n or 0
        for i = 1, min(n, 10) do
            local okL, link = pcall(GetQuestLogItemLink, kind, i, rec.id)
            if okL and type(link) == "string" and not ns:IsSecret(link) then
                local okU, by = pcall(ns.UpgradeAmount, link)
                by = okU and tonumber(by) or nil
                if by and by > best then best = by end
            end
        end
    end
    if type(GetQuestLogItemLink) == "function" then
        if type(GetNumQuestLogChoices) == "function" then Scan(GetNumQuestLogChoices, "choice") end
        if type(GetNumQuestLogRewards) == "function" then Scan(GetNumQuestLogRewards, "reward") end
    end
    local bonus = min(best * 0.02, 0.25) * need
    if cache then cache[rec.id] = bonus end
    return bonus
end

------------------------------------------------------------------------------------------
-- Reputation you want: per character rec.repGoals = { [factionID] = standing } (the game's own ids:
-- 6 Honored, 7 Revered, 8 Exalted). A quest that gives such reputation earns bonus experience: the reputation it gives (at most
-- what is still needed) x 0.0002 x a level.
------------------------------------------------------------------------------------------
-- Where each standing starts: only a fallback, for when the game gives no threshold for the next standing.
local REP_START = { [6] = 9000, [7] = 21000, [8] = 42000 }
local REP_FALLBACK = { [6] = "Honored", [7] = "Revered", [8] = "Exalted" }
ns.PLANNER_REP_STANDINGS = { 6, 7, 8 }

function ns.PlannerRepStandingName(standing)
    local word = REP_FALLBACK[standing]
    if not word then return nil end
    local label = _G["FACTION_STANDING_LABEL" .. standing]
    if type(label) == "string" and label ~= "" and not ns:IsSecret(label) then return label end
    return ns:Tr(word)
end

local function RepData(factionID)
    local C = C_Reputation
    if type(factionID) ~= "number" or not (C and C.GetFactionDataByID) then return nil end
    local ok, data = pcall(C.GetFactionDataByID, factionID)
    return (ok and type(data) == "table") and data or nil
end

function ns.PlannerRepName(factionID)
    local data = RepData(factionID)
    local name = data and data.name
    if type(name) ~= "string" or ns:IsSecret(name) then return nil end
    return name
end

-- Reputation still needed to reach the standing, or nil (unreadable, or already there).
function ns.PlannerRepNeeded(factionID, standing)
    local start = REP_START[standing]
    local data = start and RepData(factionID)
    if not data then return nil end
    local reaction, now = data.reaction, data.currentStanding
    if type(reaction) ~= "number" or type(now) ~= "number" or ns:IsSecret(reaction) or ns:IsSecret(now) then return nil end
    if reaction >= standing then return nil end
    local nextAt = tonumber(data.nextReactionThreshold)
    if reaction == standing - 1 and nextAt and not ns:IsSecret(nextAt) and nextAt > now then start = nextAt end   -- (the game's own threshold)
    local need = start - now
    return need > 0 and need or nil
end

-- The goals of this character (a plain table; empty when there are none).
function ns.PlannerRepGoals()
    local rec = ns.PlannerCharRecord(false)
    local goals = rec and rec.repGoals
    return type(goals) == "table" and goals or {}
end

-- Set one goal (standing nil: none) and plan again.
function ns.PlannerSetRepGoal(factionID, standing)
    if type(factionID) ~= "number" or (standing ~= nil and not REP_START[standing]) then return end
    local rec = ns.PlannerCharRecord(true)
    if not rec then return end
    if type(rec.repGoals) ~= "table" then rec.repGoals = {} end
    rec.repGoals[factionID] = standing
    if ns.PlannerReplan then ns:PlannerReplan("settings") end
end

-- The factions this character knows: { { id, name } }, headers left out.
function ns.PlannerKnownFactions()
    local out, seen = {}, {}
    local C = C_Reputation
    if not (C and C.GetNumFactions and C.GetFactionDataByIndex) then return out end
    local okN, n = pcall(C.GetNumFactions)
    n = okN and tonumber(n) or 0
    for i = 1, min(n, 300) do
        local ok, d = pcall(C.GetFactionDataByIndex, i)
        if ok and type(d) == "table" and not ns.Yes(d.isHeader) and type(d.factionID) == "number" and not ns:IsSecret(d.factionID) and d.factionID > 0
            and type(d.name) == "string" and not ns:IsSecret(d.name) and not seen[d.factionID] then
            seen[d.factionID] = true
            out[#out + 1] = { id = d.factionID, name = d.name }
        end
    end
    return out
end

-- Reputation still needed with a wanted faction, or false: ctx.repLeft (which the route lowers as it lays
-- hubs out) when it has the faction, else read once per plan (ctx.repCache).
function ns.PlannerRepLeft(ctx, id, standing)
    local lowered = nil
    if type(ctx.repLeft) == "table" then lowered = ctx.repLeft[id] end
    if lowered ~= nil then return lowered end
    local cache = type(ctx.repCache) == "table" and ctx.repCache or nil
    local left = cache and cache[id]
    if left == nil then
        left = ns.PlannerRepNeeded(id, standing) or false
        if cache then cache[id] = left end
    end
    return left
end

-- Bonus experience for the wanted reputation a quest gives.
function ns.PlannerRepBonus(rec, ctx)
    ctx = ctx or {}
    local goals = ctx.repGoals
    if type(goals) ~= "table" or type(rec) ~= "table" or type(rec.reputation) ~= "table" or next(goals) == nil then return 0 end
    local need = tonumber(ctx.xpMax)
    if not need then
        local okM, v = pcall(UnitXPMax, "player")
        need = okM and tonumber(v) or nil
    end
    if not need or need <= 0 or ns:IsSecret(need) then return 0 end
    local bonus = 0
    for _, e in ipairs(rec.reputation) do
        local id, value = e[1], tonumber(e[2])
        local standing = goals[id]
        if standing and value and value > 0 then
            local left = ns.PlannerRepLeft(ctx, id, standing)
            if left then bonus = bonus + min(value, left) * 0.0002 * need end
        end
    end
    return bonus
end

-- ctx.candidate(id) -> record, when that quest is itself a candidate (its follow-up counts half).
-- Three values: what the quest is worth for scoring (with the bonus for upgrades and wanted reputation,
-- and half its follow-up), the rested part (the route takes it off the pool), and the real experience
-- it gives (reward, kills, rested): forecasts, Show why and the trainer use only that.
function ns.PlannerQuestXP(rec, ctx)
    ctx = ctx or {}
    local extra = ns.PlannerRestedExtra(rec, ctx)
    local real = (rec.xp or 0) + KillPart(rec, ctx) + extra
    local xp = real + ns.PlannerRewardBonus(rec, ctx) + ns.PlannerRepBonus(rec, ctx)
    for _, h in ipairs(ns.PlannerHooksFor(ctx, "xp")) do xp = xp + (tonumber(h.fn(rec, ctx)) or 0) end
    if rec.nextQuest and ctx.candidate then
        local nxt = ctx.candidate(rec.nextQuest)
        if nxt then xp = xp + (nxt.xp or 0) / 2 end
    end
    return xp, extra, real
end

------------------------------------------------------------------------------------------
-- Pace: how long you really take against the estimate (average of the last 10, 0.5 to 3)
------------------------------------------------------------------------------------------
local PACE_SAMPLES, PACE_MIN, PACE_MAX = 10, 0.5, 3

local function PaceRecord(create) return ns.PlannerCharRecord(create) end   -- (the record: in the main add-on, PlannerRecorders.lua)

function ns.PlannerPace()
    local rec = PaceRecord(false)
    local p = rec and rec.pace
    return type(p) == "table" and tonumber(p.value) or 1
end

function ns.PlannerRecordPace(actualSeconds, estimatedSeconds)
    actualSeconds, estimatedSeconds = tonumber(actualSeconds), tonumber(estimatedSeconds)
    if not (actualSeconds and estimatedSeconds) or actualSeconds <= 0 or estimatedSeconds <= 0 then return end
    local rec = PaceRecord(true)
    local p = type(rec.pace) == "table" and rec.pace or {}
    rec.pace = p
    p.samples = p.samples or {}
    p.samples[#p.samples + 1] = actualSeconds / estimatedSeconds
    while #p.samples > PACE_SAMPLES do table.remove(p.samples, 1) end
    local sum = 0
    for _, v in ipairs(p.samples) do sum = sum + v end
    p.value = max(PACE_MIN, min(PACE_MAX, sum / #p.samples))
end

------------------------------------------------------------------------------------------
-- Running it: a slice per frame (ns.PLANNER_BUDGET_MS), never in a fight or without a place in the
-- world, and again after each hand-in, level, lost quest, new flight point and set hearthstone.
-- The plan becomes the guide you follow (Guide.lua keeps it with your place in it).
------------------------------------------------------------------------------------------
local fighting = false
local told = {}                      -- the Questie lines, once a session each
local SOURCE_LINES = { missing = "Install Questie to plan new quests too.",
    changed = "Questie's data has changed in a way the planner can't read yet, so only quests in your log are planned. Updating Fantasy Glass UI or Questie usually fixes this." }
ns.PLANNER_QUESTIE_WAIT = 30         -- seconds Questie may take to load before the plan is made from your quest log for now
ns.PLANNER_SETTLE = 0.75             -- a plan thrown away by a new request waits this long (or SETTLE_FRAMES frames) for the burst to end
local SETTLE_FRAMES = 120
local PLACE_RECHECK = 30             -- frames between looks at your place while a plan waits for one (or a second)

-- Pace, measured between marks: a route takes a hub's quests together (accept all, do all, hand in
-- all), so one quest's own accept-to-hand-in time says little. The time from the mark to a run of
-- hand-ins is set against the estimates of the quests handed in (and their share of the travel).
local PACE_BATCH = 60                -- seconds without another hand-in that end a run of hand-ins (nothing else does)
local PACE_AFK = 1800                -- more than this since the mark: away, no sample
local PACE_LOW, PACE_HIGH = 0.5, 3
local mark                           -- { time = seconds }; in memory only (a /reload starts afresh)
local batch                          -- { estimate = seconds, last = time of its last hand-in }

local function Flush(now)
    if not (batch and mark) then batch = nil; return end
    if now and now - batch.last < PACE_BATCH then return end
    local actual = batch.last - mark.time
    if batch.estimate > 0 and actual > 0 then
        local r = max(PACE_LOW, min(PACE_HIGH, actual / batch.estimate))
        ns.PlannerRecordPace(r * batch.estimate, batch.estimate)
    end
    mark, batch = { time = batch.last }, nil
end

local function HandedIn(id, plan)
    local now = GetTime()
    Flush(now)
    if not mark then mark = { time = now }; return end
    if not batch and now - mark.time > PACE_AFK then mark = { time = now }; return end
    local est = type(plan.estimates) == "table" and tonumber(plan.estimates[id]) or nil
    if not est or est <= 0 then return end
    est = est * (1 + (tonumber(plan.travelShare) or 0))
    batch = batch or { estimate = 0 }
    batch.estimate, batch.last = batch.estimate + est, now
end

local function Following()
    if not ns:GuideOn() then return false, nil end           -- (asked first: with the guide off, the state is never read, so never made)
    local st = ns.GuideState and ns.GuideState()
    return (type(st) == "table" and st.name == ns.GUIDE_PLANNED) and true or false, st
end

local function Flag(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, v = pcall(fn, ...)
    return ok and ns.Is(v, true)
end
local function Now()
    local okT, now = pcall(GetTime)
    if okT and type(now) == "number" and not ns:IsSecret(now) then return now end
end

-- Can a plan start from where you are? false and why: "taxi" (in the air: it plans once you land), "dead"
-- (a ghost on a corpse run), "away" (no place in the outdoor world: an instance, a battleground, a map the
-- planner can't place).
local function Placed()
    if not ns.GuideHere then return false, "away" end
    if Flag(UnitOnTaxi, "player") then return false, "taxi" end
    if Flag(UnitIsDeadOrGhost, "player") then return false, "dead" end
    local map, x, y = ns.GuideHere()
    if ns.PlannerWorldPos(map, x, y) == nil then return false, "away" end
    return true
end
ns.PlannerPlaced = Placed

-- Each planned quest's time at a pace of 1 (what hand-ins are measured against), and the travel
-- between them as a share of that.
local function Estimates(guide, summary, ctx)
    local out, src, paced, total = {}, ctx.source, 0, 0
    for _, s in ipairs(guide.steps) do
        ns.PlannerYield()
        local id = s.quest
        if id and out[id] == nil and type(src) == "table" then
            local rec = src.quest(id)
            out[id] = rec and floor(ns.PlannerQuestTime(rec, { speed = ctx.speed, noAlts = true }) + 0.5) or 0
            if rec then paced, total = paced + ns.PlannerQuestTime(rec, ctx), total + out[id] end
        end
    end
    local share = nil
    if paced > 0 and total > 0 and tonumber(summary.seconds) then
        share = max(0, (summary.seconds - paced) / paced)
    end
    return out, share
end

-- Questie still loading: since when (uptime), and when to look again; nil when it is not. waitAsked: the plan waiting
-- is one you asked for (Plan my route, Plan again, Plan from here), so Keep my route lets Questie's two retries through.
local waitingSince, waitRetryAt
local waitAsked = false
local KEPT_REPLANS = { again = true, ["from here"] = true }   -- (asked for: Plan again, and the map's Plan from here; Keep my route, below)
local QUESTIE_RETRIES = { questie = true, ["questie wait"] = true }
local WAIT_RETRY = 5

-- The coroutine's body: guide, summary, ctx; nil and "waiting" while Questie is still loading (it asks again,
-- and after ns.PLANNER_QUESTIE_WAIT seconds the plan is made from your quest log, ctx.sourceWhy "loading").
local function Plan()
    local ctx = ns.PlannerContext()
    local src = ctx.source
    local notReady = ctx.sourceWhy == nil and type(src) == "table" and type(src.ready) == "function" and not src.ready()
    if ctx.sourceWhy == "waiting" or notReady then
        local now = Now()
        waitingSince = waitingSince or now
        if not (now and waitingSince and now - waitingSince >= ns.PLANNER_QUESTIE_WAIT) then return nil, "waiting" end
        ctx.source, ctx.sourceWhy = ns.PlannerLogSource(), "loading"
    else
        waitingSince = nil
    end
    local line = SOURCE_LINES[ctx.sourceWhy]
    if line and not told[ctx.sourceWhy] then
        told[ctx.sourceWhy] = true
        ns:Print(line)
    end
    local guide, summary = ns.PlannerRoute(ctx)
    summary.sourceWhy = ctx.sourceWhy                        -- (summary.source: set by the route, PlannerRoute.lua; here too for a route that did not)
    if summary.source == nil and type(ctx.source) == "table" then summary.source = ctx.source.kind end
    local d = ns.PlannerCharRecord(false)                    -- (what this character has yet to show the planner: PlannerTravel.lua's lines)
    summary.noFlights = not (type(d) == "table" and type(d.flights) == "table") or nil
    summary.noBind = not (type(d) == "table" and type(d.bindAt) == "table") or nil
    guide.estimates, guide.travelShare = Estimates(guide, summary, ctx)
    return guide, summary, ctx
end

local function Apply(guide, summary, ctx, reason)
    if not mark then mark = { time = GetTime() } end
    if summary.newZone and summary.zone then ns.PlannerSetZone(summary.zone, ctx.level) end
    ns:GuideSetPlan(guide, summary)
    for _, h in ipairs(ns.PlannerHookCopy("applied")) do
        local ok, err = pcall(h.fn, guide, summary, ctx, reason)
        if not ok and type(ns.errors) == "table" and #ns.errors < 60 then
            ns.errors[#ns.errors + 1] = "Planner hook " .. tostring(h.key) .. ": " .. tostring(err)
        end
    end
end

-- Small jobs (the inn suggestion): one at a time, a slice per frame, never in a fight, only while
-- the planner itself has nothing to do. ns.PlannerJob(fn, key): a job with the same key waits only once.
local jobs = {}
function ns.PlannerJob(fn, key)
    if type(fn) ~= "function" then return false end
    for _, j in ipairs(jobs) do if key ~= nil and j.key == key then return false end end
    if key ~= nil and job and ns.plannerJobKey == key then return false end
    jobs[#jobs + 1] = { fn = fn, key = key }
    return true
end
local function RunJob()
    if fighting or InCombatLockdown() then return end
    if not job then
        local j = table.remove(jobs, 1)
        if not j then return end
        job, ns.plannerJobKey = coroutine.create(j.fn), j.key
    end
    sliceStart = Clock()
    local ok, err = coroutine.resume(job)
    SliceDone()
    if not ok then
        if #ns.errors < 60 then ns.errors[#ns.errors + 1] = "Planner job: " .. tostring(err) end
        job, ns.plannerJobKey = nil, nil
    elseif coroutine.status(job) == "dead" then
        job, ns.plannerJobKey = nil, nil
    end
end

-- A token for the plan being made: the same table for every call inside one run of the planning coroutine,
-- nil anywhere else (PlannerSource keeps the records of logged quests for one plan by it).
local planToken
function ns.PlannerPlanToken()
    local co = coroutine.running()
    if co and co == running then return planToken end
end

local burst                          -- a run thrown away by a new request: { t, frames } until the requests settle
local placeWait, placeWaitAt, placeWhy = 0, nil, nil   -- (not placed: frames until the next look, when it was, and why)
local function Settled(w)
    w.frames = w.frames + 1
    local now = Now()
    return (now and w.t and now - w.t >= ns.PLANNER_SETTLE) or w.frames >= SETTLE_FRAMES
end
local function PlaceOK()
    if placeWait > 0 then
        placeWait = placeWait - 1
        local now = Now()
        if not (now and placeWaitAt and now - placeWaitAt >= 1) then return false end
    end
    local ok, why = Placed()
    if ok then placeWait, placeWaitAt, placeWhy = 0, nil, nil; return true end
    placeWait, placeWaitAt, placeWhy = PLACE_RECHECK, Now(), why
    return false
end

local function Tick()
    if batch then Flush(GetTime()) end
    if not (ns.plannerBusy or ns.plannerQueued) then
        if waitRetryAt then                                   -- (Questie still loading: look again now and then)
            local now = Now()
            if now and now >= waitRetryAt then waitRetryAt = nil; ns:PlannerReplan("questie wait") end
        end
        RunJob(); return
    end
    if not Following() then ns:PlannerStop(); return end
    if fighting or InCombatLockdown() or not PlaceOK() then return end
    if running and ns.plannerQueued then                     -- a replan asked for mid-run: that run's context is stale
        running, burst = nil, { t = Now(), frames = 0 }      -- (and more may follow: a run of hand-ins plans once)
    end
    if not running then
        if burst then
            if not Settled(burst) then return end
            burst = nil
        end
        ns.plannerQueued, ns.plannerBusy = false, true
        running, runReason, planToken = coroutine.create(Plan), ns.plannerReason, {}
    end
    sliceStart = Clock()
    ns.plannerSteps = ns.plannerSteps + 1
    local ok, guide, summary, ctx = coroutine.resume(running)
    SliceDone()
    if ok and coroutine.status(running) ~= "dead" then return end
    running, ns.plannerBusy, planToken = nil, false, nil
    if ns.plannerQueued then return end                      -- queued meanwhile: never apply a stale result
    if ok and guide == nil and summary == "waiting" then     -- (Questie still loading: the old plan stays; look again in a while)
        waitAsked = waitAsked or startPending or KEPT_REPLANS[runReason] == true
        local now = Now()
        waitRetryAt = now and now + WAIT_RETRY or nil
        if ns.GuideRedraw then ns:GuideRedraw() end
        return
    end
    waitAsked = false                                        -- (that run is over: Questie's retries are automatic again)
    if not ok then
        -- keep the last good plan; the panel says so (every time, not only the first), /fgui check lists it.
        -- The start's plan failed: a later plan is not that start's (no preview for it, its own reason).
        startPending = false
        if #ns.errors < 60 then ns.errors[#ns.errors + 1] = "Planner: " .. tostring(guide) end
        if ns.GuidePlanFailed then ns:GuidePlanFailed() end
        return
    end
    if guide then
        local reason = startPending and "start" or runReason   -- (a replan that replaced the start run is still the start)
        startPending = false
        Apply(guide, summary, ctx, reason)
    end
end
ns:Every(0, "Planner", Tick)

-- Keep my route (ns.db.plannerKeepRoute): the reasons that still plan again, the ones you ask for yourself (Plan my
-- route is ns:PlannerStart; Plan again; Plan from here on the map). Every other one is refused: a level, a hand-in, a
-- loading screen, a quest taken or lost, the hearthstone, a new flight point, a death, a closed window, a setting, the
-- time, the zone goal, Questie ready, the duo, the route's end, a skip, a failed quest, a hearth. Questie's two retries
-- ("questie", "questie wait") pass only while a plan you asked for waits on Questie (waitAsked): they bring that plan.
function ns.PlannerKeepsRoute(reason)
    if waitAsked and QUESTIE_RETRIES[reason] then return false end
    return type(ns.db) == "table" and ns.db.plannerKeepRoute == true and not KEPT_REPLANS[reason]
end
-- Plan again (soon, a slice at a time). `reason` is only for debugging. Returns false when you are not
-- following the planned guide, and false, "refused" when a "replan" hook refused it or the route is kept.
function ns:PlannerReplan(reason)
    if not Following() then return false end
    if ns.PlannerKeepsRoute(reason) then return false, "refused" end
    if not ReplanOK(reason) then return false, "refused" end
    ns.plannerQueued, ns.plannerReason = true, reason
    if burst then burst.t, burst.frames = Now(), 0 end      -- (still coming: the burst goes on)
    placeWait = 0                                           -- (look at your place again at once)
    return true
end

-- Follow the planned route, and plan it from scratch.
function ns:PlannerStart()
    if not ns:GuideOn() then
        ns:Print("Quest guides are switched off. Switch them on under Guide in /fgui, or in the setup.")
        return false
    end
    if not ReplanOK("start") then return false end
    if ns.PlannerSessionSkipReset then ns.PlannerSessionSkipReset() end   -- (a fresh plan: the steps skipped this session count again)
    if ns.PlannerApplyPlayDefault then ns.PlannerApplyPlayDefault() end   -- (the Guide tab's "How long can you play?", PlannerPace.lua)
    if not Following() then ns:GuideSetPlan(nil) end
    ns:GuideShowPanel()
    mark, batch = nil, nil
    waitRetryAt, burst, placeWait = nil, nil, 0
    ns.plannerQueued, ns.plannerReason, startPending = true, "start", true
    return true
end

function ns:PlannerStop()
    running, ns.plannerBusy, ns.plannerQueued, startPending, planToken = nil, false, false, false, nil
    waitAsked = false
    waitRetryAt, burst, placeWait = nil, nil, 0
end

-- What the panel says while a plan waits or comes from your quest log (the planned route only).
local function PlannedState(st) return type(st) == "table" and st.name == ns.GUIDE_PLANNED end
local WAIT_WORDS = { taxi = "Waiting until you land to plan", dead = "Waiting until you are back on your feet to plan",
    away = "Waiting until you are outdoors to plan" }
ns.GuideRegisterLine("plannerWait", function(st)
    if not PlannedState(st) then return nil end
    local s = type(st.summary) == "table" and st.summary or nil
    if (ns.plannerQueued or ns.plannerBusy) and placeWhy and WAIT_WORDS[placeWhy] then return ns:Tr(WAIT_WORDS[placeWhy]) end
    if (waitingSince or waitRetryAt) and not (s and s.sourceWhy == "loading") then
        return ns:Tr("Questie is still loading: your route is planned once it is ready")
    end
    if not s or s.source ~= "log" then return nil end
    if s.empty and s.sourceWhy == "missing" then return ns:Tr("Install Questie to plan new quests; your quest log has none to plan") end
    if s.sourceWhy == "loading" then return ns:Tr("Questie is still loading: planning from your quest log for now") end
    if s.sourceWhy == "missing" then return ns:Tr("Install Questie to plan new quests too.") end
    if s.sourceWhy == "changed" then return ns:Tr("Questie can't be read: only quests in your log are planned") end
end)
ns.GuideRegisterTitle("plannerBusy", function(st)
    if PlannedState(st) and (ns.plannerQueued or ns.plannerBusy) and type(st.summary) == "table" then return ns:Tr("planning…") end
end)

-- (Trainer visits, being seen mounted, quest times, soloed elites and deaths are recorded in the main add-on,
-- PlannerRecorders.lua, while this folder is not loaded too. Here: what they change in the plan.)
do
    local ev = CreateFrame("Frame")
    local deathCheck
    -- Forever can send QUEST_REMOVED before QUEST_TURNED_IN (or no QUEST_TURNED_IN at all); a quest handed in
    -- is flagged completed by then, an abandoned one is not.
    local function Completed(id)
        local QL = C_QuestLog
        if type(QL) ~= "table" or type(QL.IsQuestFlaggedCompleted) ~= "function" then return false end
        local ok, v = pcall(QL.IsQuestFlaggedCompleted, id)
        return ok and ns.Is(v, true)
    end
    -- A hand-in is counted for the pace once, by whichever of QUEST_TURNED_IN and QUEST_REMOVED (of a quest
    -- flagged completed) comes first; the other one only clears the mark. questID -> when it was counted.
    local counted = {}
    local function CountHandIn(id, plan, now)
        for k, t in pairs(counted) do
            if now and (t > now or now - t > 600) then counted[k] = nil end   -- (a pair is seconds or a minute apart)
        end
        if counted[id] then counted[id] = nil; return false end
        counted[id] = now or 0
        HandedIn(id, plan)
        return true
    end
    deathCheck = ns:Guard("Planner", function()
        local d = ns.PlannerCharRecord(false)
        local level = UnitLevel and UnitLevel("player")
        if type(d) == "table" and type(d.deaths) == "table" and type(level) == "number" and not ns:IsSecret(level) and ns.GuideHere and Following() then
            local map, x, y = ns.GuideHere()
            if map and x and y and ns.PlannerHubTooHard({ map = map, x = x, y = y }, { deaths = d.deaths, level = level }) then
                ns:PlannerReplan("death")
            end
        end
    end)
    local closes = {}                                -- window-closed event -> the stop kind it ticks (Guide.lua)
    for kind, e in pairs(ns.GUIDE_WINDOW_KINDS or {}) do closes[e] = kind end
    for _, e in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "PLAYER_LEVEL_UP", "HEARTHSTONE_BOUND",
                         "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
                         "TRAINER_CLOSED", "MERCHANT_CLOSED", "MAIL_CLOSED", "PLAYER_DEAD" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Planner", function(_, event, a, b)
        if event == "PLAYER_REGEN_DISABLED" then fighting = true; return end
        if event == "PLAYER_REGEN_ENABLED" then fighting = false; return end
        if event == "PLAYER_DEAD" then                -- (the second death here: plan again now, once you are back on your feet, not at the next hand-in)
            -- (a moment later: the main add-on's recorder has written the death down by then, whichever frame hears it first)
            if not (C_Timer and C_Timer.After and pcall(C_Timer.After, 0, deathCheck)) then deathCheck() end
            return
        end
        if event == "QUEST_ACCEPTED" then
            local id = (type(b) == "number") and b or a
            if type(id) == "number" and ns.PlannerSessionRetaken then ns.PlannerSessionRetaken(id) end   -- (abandoned, then taken again: planned again)
        end
        local on, st = Following()
        if not on then return end
        local plan = type(st.plan) == "table" and st.plan or {}
        if closes[event] then
            -- a stop's window closed: it ticks only while it is the step you are on (visited early, it stays)
            -- (and plans again only when the plan has a stop of that window)
            local steps = type(plan.steps) == "table" and plan.steps or {}
            local step = steps[st.at or 1]
            if type(step) == "table" and step.kind == closes[event] then
                -- a vendor visit is over: the next vendor stop is a new one (it is not ticked by this one)
                if step.kind == "mail" and type(step.stopKey) == "string" and step.stopKey:sub(1, 5) == "mail:" then
                    local d = PaceRecord(true)
                    if d then
                        d.mailVisits = (tonumber(d.mailVisits) or 0) + 1
                        local okT, now = pcall(GetTime)
                        if okT and type(now) == "number" and not ns:IsSecret(now) then d.mailQuiet = { t = now } end
                    end
                end
                if step.kind == "vendor" and type(step.stopKey) == "string" and step.stopKey:sub(1, 7) == "vendor:" then
                    local d = PaceRecord(true)
                    if d then
                        d.vendorVisits = (tonumber(d.vendorVisits) or 0) + 1
                        local okT, now = pcall(GetTime)
                        if okT and type(now) == "number" and type(d.vendorLast) == "table" then d.vendorQuiet = { t = now, seen = d.vendorLast } end
                    end
                end
                ns:GuideSkip(false); ns:PlannerReplan("window closed"); return
            end
            for _, s in ipairs(steps) do
                if type(s) == "table" and s.kind == closes[event] then ns:PlannerReplan("window closed"); return end
            end
            return
        end
        -- (an accept does not end a run of hand-ins: a chain's follow-up is offered at the hand-in)
        if event == "QUEST_ACCEPTED" then
            local id = (type(b) == "number") and b or a                -- (the quest id comes second or first, by client)
            if type(id) == "number" then counted[id] = nil end          -- (taken again: a new hand-in to come)
            -- (a quest taken outside the plan, shared by a party member or picked up on the way: the plan takes it in)
            if type(id) == "number" then
                local inPlan = false
                local steps = type(plan.steps) == "table" and plan.steps or {}
                for _, s in ipairs(steps) do
                    if type(s) == "table" and (s.quest == id or (ns.PlannerMappedId and ns.PlannerMappedId(s.quest) == id)) then inPlan = true; break end
                end
                -- (a planned quest Questie numbers otherwise, taken: its title says so, and the pair is learned)
                if not inPlan and ns.PlannerLearnAccepted and ns.PlannerLearnAccepted(id, steps) then inPlan = true end
                if not inPlan then ns:PlannerReplan("log") end
            end
            return
        end
        if event == "QUEST_TURNED_IN" then
            if type(a) == "number" then CountHandIn(a, plan, Now()) end
            ns:PlannerReplan("hand-in")
        elseif event == "HEARTHSTONE_BOUND" then
            local step = type(plan.steps) == "table" and plan.steps[st.at or 1]
            if type(step) == "table" and step.kind == "bind" then ns:GuideSkip(false) end   -- (bound by place, not by the innkeeper's name)
            ns:PlannerReplan("bind")
        elseif event == "PLAYER_ENTERING_WORLD" then
            ns:PlannerReplan("loading screen")                       -- (every login, /reload and loading screen: a saved plan may be stale; the runner waits for a place and for Questie)
        elseif event == "PLAYER_LEVEL_UP" then
            ns:PlannerReplan("level")
        elseif event == "QUEST_REMOVED" then
            if type(a) == "number" then
                local done = Completed(a)
                if done then CountHandIn(a, plan, Now())
                elseif ns.PlannerWasFailed and ns.PlannerWasFailed(a) then  -- (a failed quest abandoned: to be taken again, F9)
                    if ns.PlannerFailedReset then ns.PlannerFailedReset(a) end
                elseif ns.PlannerSessionSkip then ns.PlannerSessionSkip(a, true) end   -- (abandoned: not planned again this session, unless taken again)
            end
            ns:PlannerReplan("quest removed")
        end
    end))
end
ns.FolderFileDone("planner", "Planner.lua")
