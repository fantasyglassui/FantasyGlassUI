local _, ns = ...

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
ns.PLANNER_HOOK_POINTS = { "context", "window", "xp", "zone", "rank", "route", "candidate" }
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

------------------------------------------------------------------------------------------
-- Kill experience (the classic formula)
------------------------------------------------------------------------------------------
local function GrayLevel(p)
    if p <= 5 then return 0 end
    if p <= 39 then return p - floor(p / 10) - 5 end
    if p <= 59 then return p - floor(p / 5) - 1 end
    return p - 9
end

local ZD_STEPS = { { 8, 5 }, { 10, 6 }, { 12, 7 }, { 16, 8 }, { 20, 9 }, { 30, 11 }, { 40, 12 }, { 45, 13 }, { 50, 14 }, { 55, 15 }, { 60, 16 } }
local function ZeroDifference(p)
    for _, s in ipairs(ZD_STEPS) do if p < s[1] then return s[2] end end
    return 17
end

function ns.PlannerKillXP(playerLevel, mobLevel, elite)
    playerLevel, mobLevel = tonumber(playerLevel), tonumber(mobLevel)
    if not (playerLevel and mobLevel) then return 0 end
    local base = playerLevel * 5 + 45
    local xp
    if mobLevel >= playerLevel then
        xp = base * (1 + 0.05 * min(mobLevel - playerLevel, 4))
    elseif mobLevel <= GrayLevel(playerLevel) then
        return 0
    else
        xp = base * (1 - (playerLevel - mobLevel) / ZeroDifference(playerLevel))
    end
    if elite then xp = xp * 2 end
    return floor(xp)
end

------------------------------------------------------------------------------------------
-- Candidates
------------------------------------------------------------------------------------------
local function AllDone(list, done)
    for _, id in ipairs(list or {}) do if not done(id) then return false end end
    return true
end

local function AnyDone(list, done)
    if not list or #list == 0 then return true end
    for _, id in ipairs(list) do if done(id) then return true end end
    return false
end

local function InWindow(rec, ctx)
    local lo, hi = ns.PlannerWindow(rec, ctx)
    return rec.level >= lo and rec.level <= hi
end

local function NeedsGroup(rec) return (rec.elite or rec.group or rec.dungeon) and true or false end

-- Does the group setting let this quest through (an elite your class has soloed counts as solo)?
local function GroupOK(rec, ctx, level)
    if not NeedsGroup(rec) or ctx.group == "all" or (ctx.group == "grouped" and ctx.inGroup) then return true end
    return (ctx.soloElites and rec.elite and not rec.group and not rec.dungeon and ns.PlannerSoloEliteOK(ctx.class, rec.level - level)) and true or false
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
    local items = {}
    if source.begin then source.begin(level) end
    for _, id in ipairs(source.ids()) do
        ns.PlannerYield()
        local logged = onQuest(id)
        local rec = (logged or not (never and never[id])) and (logged or not source.inRange or (type(ctx.windowPass) == "table" and ctx.windowPass[id]) or source.inRange(id, level, ctx.windowLo, ctx.windowHi)) and source.quest(id) or nil
        if rec then
            if logged then
                if Keep(rec, ctx, true) then list[#list + 1] = rec end
            elseif rec.doable and not rec.repeatable and not done(id)
                and InWindow(rec, ctx)
                and AllDone(rec.pre, done) and AnyDone(rec.preAny, done) then
                if Keep(rec, ctx, false) then            -- (one a hook drops is not counted as skipped)
                    if not GroupOK(rec, ctx, level) then
                        skipped.group = skipped.group + 1
                    elseif rec.fromItem then
                        items[#items + 1] = rec
                    else
                        list[#list + 1] = rec
                    end
                end
            end
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
    return list, skipped, later
end

------------------------------------------------------------------------------------------
-- Time
------------------------------------------------------------------------------------------
-- The farthest two spots of an objective, in yards (0 when they can't be placed).
local function Spread(spots)
    local pts = {}
    for _, s in ipairs(spots or {}) do
        local c, x, y = ns.PlannerWorldPos(s.map, s.x, s.y)
        if c then pts[#pts + 1] = { c = c, x = x, y = y } end
    end
    local far = 0
    for i = 1, #pts do
        for j = i + 1, #pts do
            if pts[i].c == pts[j].c then
                local dx, dy = pts[i].x - pts[j].x, pts[i].y - pts[j].y
                far = max(far, sqrt(dx * dx + dy * dy))
            end
        end
    end
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
        if speed > 0 then t = t + Spread(o.spots) / speed end
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

-- A sample of how long a quest took from accept to hand-in (while following the plan); over 2 hours is away.
local QUEST_TIME_MAX = 7200
function ns.PlannerRecordQuestTime(questID, seconds)
    seconds = tonumber(seconds)
    if type(questID) ~= "number" or not seconds or seconds <= 0 or seconds > QUEST_TIME_MAX or not ns.root then return end
    local root = ns.root
    if type(root.plannerQuestTimes) ~= "table" then root.plannerQuestTimes = {} end
    local e = root.plannerQuestTimes[questID]
    if type(e) ~= "table" or not tonumber(e.n) or not tonumber(e.avg) then e = { n = 0, avg = 0 }; root.plannerQuestTimes[questID] = e end
    e.avg = (e.avg * e.n + seconds) / (e.n + 1)
    e.n = e.n + 1
end

------------------------------------------------------------------------------------------
-- Choices: the skip list, deaths and elites your class has soloed
------------------------------------------------------------------------------------------
local DEATHS_MAX = 50

-- Never suggest this quest (on), or suggest it again (off); plans again at once.
function ns.PlannerSkip(questID, on)
    if type(questID) ~= "number" then return end
    local rec = ns.PlannerCharRecord(on and true or false)
    if not rec then return end
    if on then
        if type(rec.skip) ~= "table" then rec.skip = {} end
        rec.skip[questID] = true
    elseif type(rec.skip) == "table" then
        rec.skip[questID] = nil
    end
    if ns.PlannerReplan then ns:PlannerReplan("settings") end
end

-- The quests this character never wants suggested: { [questID] = true } (empty when there are none).
function ns.PlannerSkipList()
    local rec = ns.PlannerCharRecord(false)
    return rec and type(rec.skip) == "table" and rec.skip or {}
end

-- Where you died: remembered per character (the last 50), with the level you were.
function ns.PlannerRecordDeath()
    local level = UnitLevel and UnitLevel("player")
    if type(level) ~= "number" or ns:IsSecret(level) or not ns.GuideHere then return end
    local map, x, y = ns.GuideHere()
    if not (map and x and y and ns.PlannerWorldPos(map, x, y)) then return end        -- (no place in the outdoor world: a dungeon or a battleground)
    local rec = ns.PlannerCharRecord(true)
    if not rec then return end
    if type(rec.deaths) ~= "table" then rec.deaths = {} end
    rec.deaths[#rec.deaths + 1] = { level = level, map = map, x = x, y = y }
    while #rec.deaths > DEATHS_MAX do table.remove(rec.deaths, 1) end
end

-- The class token of this character ("WARRIOR"), or nil.
function ns.PlannerClassToken()
    local ok, c = pcall(function() return (UnitClassBase and UnitClassBase("player")) or select(2, UnitClass("player")) end)
    if ok and type(c) == "string" and not ns:IsSecret(c) and c ~= "" then return c end
end

-- An elite quest handed in alone: remember, per class, the biggest quest level over yours.
function ns.PlannerRecordSoloElite(class, diff)
    diff = tonumber(diff)
    if type(class) ~= "string" or not diff or not ns.root then return end
    if type(ns.root.plannerSoloElites) ~= "table" then ns.root.plannerSoloElites = {} end
    local t = ns.root.plannerSoloElites
    if type(t[class]) ~= "number" or t[class] < diff then t[class] = diff end
end

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
local function KillPart(rec, level)
    local xp = 0
    for _, o in ipairs(rec.objectives or {}) do
        if o.kind == "kill" then
            xp = xp + Count(o) * ns.PlannerKillXP(level, o.mobLevel or rec.level, rec.elite)
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
    return min(left, KillPart(rec, ctx.level or 1))
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
        n = okN and tonumber(n) or 0
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
        if ok and type(d) == "table" and not d.isHeader and type(d.factionID) == "number" and d.factionID > 0
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
    local real = (rec.xp or 0) + KillPart(rec, ctx.level or 1) + extra
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

local function PaceRecord(create)
    local root = ns.root
    if not root then return nil end
    local key = ns:CharKey()
    if create then
        root.planner = root.planner or {}
        root.planner[key] = root.planner[key] or {}
        return root.planner[key]
    end
    return root.planner and root.planner[key]
end

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

-- The saved per-character planner record (PlannerRoute.lua keeps the bind place and the zone there).
ns.PlannerCharRecord = PaceRecord

------------------------------------------------------------------------------------------
-- Running it: a slice per frame (ns.PLANNER_BUDGET_MS), never in a fight or without a place in the
-- world, and again after each hand-in, level, lost quest, new flight point and set hearthstone.
-- The plan becomes the guide you follow (Guide.lua keeps it with your place in it).
------------------------------------------------------------------------------------------
local fighting = false
local told = {}                      -- the Questie lines, once a session each
local SOURCE_LINES = { missing = "Install Questie to plan new quests too.", changed = "Questie changed; planning from your quest log only." }

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
    local st = ns.GuideState and ns.GuideState()
    return (ns:GuideOn() and type(st) == "table" and st.name == ns.GUIDE_PLANNED) and true or false, st
end

local function Placed()
    if not ns.GuideHere then return false end
    local map, x, y = ns.GuideHere()
    return ns.PlannerWorldPos(map, x, y) ~= nil
end

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

-- The coroutine's body: guide, summary, ctx; nothing while Questie is still loading (it asks again).
local function Plan()
    local ctx = ns.PlannerContext()
    if ctx.sourceWhy == "waiting" then return nil end
    local line = SOURCE_LINES[ctx.sourceWhy]
    if line and not told[ctx.sourceWhy] then
        told[ctx.sourceWhy] = true
        ns:Print(line)
    end
    local guide, summary = ns.PlannerRoute(ctx)
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
    if not ok then
        if #ns.errors < 60 then ns.errors[#ns.errors + 1] = "Planner job: " .. tostring(err) end
        job, ns.plannerJobKey = nil, nil
    elseif coroutine.status(job) == "dead" then
        job, ns.plannerJobKey = nil, nil
    end
end

local function Tick()
    if batch then Flush(GetTime()) end
    if not (ns.plannerBusy or ns.plannerQueued) then RunJob(); return end
    if not Following() then ns:PlannerStop(); return end
    if fighting or InCombatLockdown() or not Placed() then return end
    if running and ns.plannerQueued then running = nil end   -- a replan asked for mid-run: that run's context is stale
    if not running then
        ns.plannerQueued, ns.plannerBusy = false, true
        running, runReason = coroutine.create(Plan), ns.plannerReason
    end
    sliceStart = Clock()
    ns.plannerSteps = ns.plannerSteps + 1
    local ok, guide, summary, ctx = coroutine.resume(running)
    if ok and coroutine.status(running) ~= "dead" then return end
    running, ns.plannerBusy = nil, false
    if ns.plannerQueued then return end                      -- queued meanwhile: never apply a stale result
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

-- Plan again (soon, a slice at a time). `reason` is only for debugging. Returns false when you are not
-- following the planned guide, and false, "refused" when a "replan" hook refused it.
function ns:PlannerReplan(reason)
    if not Following() then return false end
    if not ReplanOK(reason) then return false, "refused" end
    ns.plannerQueued, ns.plannerReason = true, reason
    return true
end

-- Follow the planned route, and plan it from scratch.
function ns:PlannerStart()
    if not ns:GuideOn() then return false end
    if not ReplanOK("start") then return false end
    if not Following() then ns:GuideSetPlan(nil) end
    ns:GuideShowPanel()
    mark, batch = nil, nil
    ns.plannerQueued, ns.plannerReason, startPending = true, "start", true
    return true
end

function ns:PlannerStop()
    running, ns.plannerBusy, ns.plannerQueued, startPending = nil, false, false, false
end

-- The level of your last class trainer visit. The trainer whose window opened is yours when it is no
-- profession trainer and, where your class trainers are known, it is one of them (by its id, or
-- standing within 10 yards of one); with none known, any trainer but a profession one counts.
local CLASS_TRAINER_YARDS = 10
local classTrainer = false
local ridingTrainer = false
local function IsClassTrainer()
    ridingTrainer = false
    local ok, trade = pcall(IsTradeskillTrainer)
    if ok and trade == true then return false end
    local src = ns.PlannerSource and ns.PlannerSource() or nil
    local places = (src and ns.PlannerPlaces) and ns.PlannerPlaces({ source = src }, "classTrainer") or {}
    local riding = (src and ns.PlannerPlaces) and ns.PlannerPlaces({ source = src }, "professionTrainer", ns.PLANNER_RIDING_LINE or 762) or {}
    if #places == 0 and #riding == 0 then return true end
    local okG, guid = pcall(UnitGUID, "npc")
    local id = okG and type(guid) == "string" and not ns:IsSecret(guid) and tonumber(guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")) or nil
    local c, x, y
    if ns.GuideHere then
        local map, px, py = ns.GuideHere()
        c, x, y = ns.PlannerWorldPos(map, px, py)
    end
    local function At(list, byId)
        for _, p in ipairs(list) do
            if id and p.id == id then return true end
            if not byId then
                local pc, ppx, ppy = ns.PlannerWorldPos(p.map, p.x, p.y)
                if c and pc == c and sqrt((ppx - x) ^ 2 + (ppy - y) ^ 2) <= CLASS_TRAINER_YARDS then return true end
            end
        end
        return false
    end
    if At(places, true) then return true end          -- (a class trainer by its id, even next to the riding trainer)
    if At(riding) then ridingTrainer = true; return false end   -- (the riding trainer is no class trainer)
    if #places == 0 then return true end
    return At(places)
end
local function TrainerClosed()
    if ridingTrainer and ns:GuideUnlocked() then           -- (you were at the riding trainer: you ride from now on)
        local r = PaceRecord(true)
        if r then r.ridingKnown = true end
    end
    if not classTrainer or not ns:GuideUnlocked() then return end
    local level = UnitLevel and UnitLevel("player")
    if type(level) ~= "number" or ns:IsSecret(level) then return end
    local d = PaceRecord(true)
    if d then d.trainerLevel = level end
end

do
    local ev = CreateFrame("Frame")
    -- Quest times: each quest accepted while following gathers its share of the time that passes, the
    -- time split evenly among the quests open at once (a hub's quests are done together). Memory only.
    -- (a quest carried longer than a sample may be, 2 hours, gives none and stops taking a share)
    local open, openN, openAt, since = {}, 0, nil, {}  -- questID -> seconds so far; how many; the last time shared out; accepted at
    local function Share(now)
        for id, t0 in pairs(since) do
            if t0 > now or now - t0 > QUEST_TIME_MAX then
                if open[id] then open[id], openN = nil, openN - 1 end
                since[id] = nil
            end
        end
        if openN == 0 then openAt = nil end
        if openAt and openN > 0 and now > openAt then
            local part = (now - openAt) / openN
            for id, t in pairs(open) do open[id] = t + part end
        end
        openAt = now
    end
    local function Close(id, now)
        Share(now)
        local t = open[id]
        if t then open[id], openN = nil, openN - 1 end
        since[id] = nil
        if openN == 0 then openAt = nil end
        return t
    end
    -- Forever can send QUEST_REMOVED before QUEST_TURNED_IN (or no QUEST_TURNED_IN at all); a quest handed in
    -- is flagged completed by then, an abandoned one is not.
    local function Completed(id)
        local QL = C_QuestLog
        if type(QL) ~= "table" or type(QL.IsQuestFlaggedCompleted) ~= "function" then return false end
        local ok, v = pcall(QL.IsQuestFlaggedCompleted, id)
        return ok and v == true
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
    local function Now()
        local okT, now = pcall(GetTime)
        if okT and type(now) == "number" and not ns:IsSecret(now) then return now end
    end
    -- A QUEST_REMOVED of a quest not (yet) flagged completed: abandoned, unless QUEST_TURNED_IN for it follows
    -- within a second (then it was a hand-in, counted once). questID -> { t, level = a soloed elite's, took = its time }.
    local removed = {}
    local function Removed(id, now)
        for k, e in pairs(removed) do
            if now and (e.t > now or now - e.t > 600) then removed[k] = nil end
        end
        local e = removed[id] or {}
        e.t = now or 0
        removed[id] = e
        return e
    end
    local function JustRemoved(id, now)
        local e = removed[id]
        removed[id] = nil
        if e and now and now >= e.t and now - e.t <= 1 then return e end
    end
    -- elite questID -> its quest level, accepted while not in a group: kept per character, so a /reload
    -- or a new session in between still counts (cleared at hand-in or when the quest leaves the log)
    local function SoloAt(create)
        local r = ns.PlannerCharRecord(create)
        if type(r) ~= "table" then return nil end
        if type(r.soloAt) ~= "table" then
            if not create then return nil end
            r.soloAt = {}
        end
        return r.soloAt
    end
    local closes = {}                                -- window-closed event -> the stop kind it ticks (Guide.lua)
    for kind, e in pairs(ns.GUIDE_WINDOW_KINDS or {}) do closes[e] = kind end
    for _, e in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "PLAYER_LEVEL_UP", "HEARTHSTONE_BOUND",
                         "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
                         "TRAINER_SHOW", "TRAINER_CLOSED", "MERCHANT_CLOSED", "MAIL_CLOSED", "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_DEAD" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Planner", function(_, event, a, b)
        if event == "PLAYER_REGEN_DISABLED" then fighting = true; return end
        if event == "PLAYER_REGEN_ENABLED" then fighting = false; return end
        if event == "TRAINER_SHOW" then               -- (a locked guide: nothing is looked up)
            classTrainer, ridingTrainer = false, false
            if ns:GuideUnlocked() then classTrainer = IsClassTrainer() == true end
            return
        end
        if event == "TRAINER_CLOSED" then TrainerClosed() end
        if event == "PLAYER_MOUNT_DISPLAY_CHANGED" then          -- (seen mounted: you have a mount and ride; kept for the character)
            if ns:GuideUnlocked() and ns.PlannerMountSeen then ns.PlannerMountSeen() end
            return
        end
        if event == "PLAYER_DEAD" then                -- (where you died: a hub that took you twice is left alone for two levels)
            if ns:GuideUnlocked() then ns.PlannerRecordDeath() end
            return
        end
        local recent = (event == "QUEST_TURNED_IN" and type(a) == "number") and JustRemoved(a, Now()) or nil   -- (removed a moment ago: a hand-in)
        if (event == "QUEST_ACCEPTED" or event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED") and ns:GuideUnlocked() then
            local id = (event == "QUEST_ACCEPTED" and type(b) == "number") and b or a
            if type(id) == "number" then
                local okG, grouped = pcall(IsInGroup)
                grouped = not okG or grouped ~= false
                if event == "QUEST_ACCEPTED" then
                    local list = SoloAt(false)
                    if list then list[id] = nil end
                    if not grouped then
                        local okQ, q = pcall(function() return ns.PlannerLogSource().quest(id) end)
                        if okQ and type(q) == "table" and q.elite == true and type(q.level) == "number" then
                            list = SoloAt(true)
                            if list then list[id] = q.level end
                        end
                    end
                elseif event == "QUEST_REMOVED" and not Completed(id) then         -- (abandoned, unless QUEST_TURNED_IN follows at once)
                    local list = SoloAt(false)
                    local e = Removed(id, Now())
                    if list then e.level = list[id]; list[id] = nil end
                else                                                         -- (handed in: Forever may say so by QUEST_REMOVED first)
                    local list = SoloAt(false)
                    local questLevel = list and tonumber(list[id])
                    if list then list[id] = nil end
                    if not questLevel and recent then questLevel = tonumber(recent.level) end
                    local level = UnitLevel and UnitLevel("player")
                    local class = ns.PlannerClassToken()
                    if questLevel and not grouped and class and type(level) == "number" and not ns:IsSecret(level) then
                        ns.PlannerRecordSoloElite(class, questLevel - level)
                    end
                end
            end
        end
        local on, st = Following()
        if not on then
            if (event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED") and type(a) == "number" and open[a] then   -- (not followed to the end: no sample)
                local now = Now()
                if now then Close(a, now) else open[a], openN, since[a] = nil, openN - 1, nil end
            end
            return
        end
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
            local now = Now()
            if type(id) == "number" then counted[id] = nil end          -- (taken again: a new hand-in to come)
            if type(id) == "number" and now and not open[id] then
                Share(now)
                open[id], openN, since[id] = 0, openN + 1, now
            end
            -- (a plan made while the log had room asked nothing about it: a quest taken outside the plan may fill it)
            if type(id) == "number" and type(st.summary) == "table" and st.summary.logFits then
                local inPlan = false
                for _, s in ipairs(type(plan.steps) == "table" and plan.steps or {}) do
                    if type(s) == "table" and s.quest == id then inPlan = true; break end
                end
                if not inPlan then ns:PlannerReplan("log") end
            end
            return
        end
        if event == "QUEST_TURNED_IN" then
            if type(a) == "number" then
                local now = Now()
                local took = now and open[a] and Close(a, now)
                if not took and recent then took = recent.took end
                if took then ns.PlannerRecordQuestTime(a, took) end
                CountHandIn(a, plan, now)
            end
            ns:PlannerReplan("hand-in")
        elseif event == "HEARTHSTONE_BOUND" then
            local step = type(plan.steps) == "table" and plan.steps[st.at or 1]
            if type(step) == "table" and step.kind == "bind" then ns:GuideSkip(false) end   -- (bound by place, not by the innkeeper's name)
            ns:PlannerReplan("bind")
        elseif event == "PLAYER_ENTERING_WORLD" then
            ns:PlannerReplan("loading screen")                       -- (every login, /reload and loading screen: a saved plan may be stale; the runner waits for a place and for Questie)
        elseif event == "PLAYER_LEVEL_UP" then
            ns:PlannerReplan("level")
        else
            if event == "QUEST_REMOVED" and type(a) == "number" then
                local now, done = Now(), Completed(a)              -- (handed in, said by QUEST_REMOVED first: a sample and the pace; abandoned: none)
                if open[a] then
                    local took
                    if now then took = Close(a, now) else open[a], openN, since[a] = nil, openN - 1, nil end
                    if took and done then ns.PlannerRecordQuestTime(a, took) end
                    if took and not done then Removed(a, now).took = took end    -- (kept a second, for a QUEST_TURNED_IN to come)
                end
                if done then CountHandIn(a, plan, now) end
            end
            ns:PlannerReplan("quest removed")
        end
    end))
end
