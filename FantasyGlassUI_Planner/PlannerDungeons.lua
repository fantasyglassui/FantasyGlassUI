local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end

------------------------------------------------------------------------------------------
-- 13.5 A: dungeon runs in the route. A dungeon is a pseudo-hub (the "extra" hook, PlannerRoute's Build): ranked with
-- the quest hubs near you on experience an hour, travel counted, and planned only when it beats them. Its steps: the
-- pick-ups of its quests, "Find a group for <dungeon>" at the entrance, "Run <dungeon>" (it ticks when you are out
-- in the open world, alive, after being inside: Guide.lua), then the hand-ins. For everyone, solo players too.
-- The rulings: R1 run time, R2 the run log by id, R3 the wait for a group, R4 the monsters, R5 the quests belong to
-- the run, R6 one dungeon a plan, R7 the data (src.dungeons, the Questie source only), R10 Skip this dungeon.
-- Everything here runs inside the planning coroutine except the guide's hooks (actions, lines, the advance hook).
------------------------------------------------------------------------------------------
local format, max, min, huge = string.format, math.max, math.min, math.huge
local ipairs, type, tonumber, sort = ipairs, type, tonumber, table.sort

ns.PLANNER_DUNGEON_BASE = 600           -- seconds of a run before its bosses (R1)
ns.PLANNER_DUNGEON_PER_BOSS = 360       -- seconds a boss, with the pulls before it (R1)
ns.PLANNER_DUNGEON_KILLS = 15           -- monsters before each boss (R4)
ns.PLANNER_DUNGEON_SHARE = 0.28         -- your share of a kill in a group of five: the classic group bonus 1.4 / 5 (R4)
ns.PLANNER_GROUP_WAIT = 900             -- seconds to find four others (R3)
ns.PLANNER_GROUP_SKIP_AFTER = 900       -- seconds on the group step before Skip this dungeon is offered on the panel (R10)
local HANDLE = 5                        -- seconds to talk to a giver (as PlannerRoute's)

local function On() return not (type(ns.db) == "table" and ns.db.plannerDungeons == false) end
local function Num(v) if type(v) == "number" and not ns:IsSecret(v) then return v end end
local function Clean(s) if type(s) == "string" and not ns:IsSecret(s) and s ~= "" then return s end end

-- How many are in your group (0 when it can't be read).
local function GroupSize()
    if type(GetNumGroupMembers) ~= "function" then return 0 end
    local ok, n = pcall(GetNumGroupMembers)
    return ok and Num(n) or 0
end

------------------------------------------------------------------------------------------
-- This session's runs and skips, by the dungeon's area id. Kept in the character's record with the session's start
-- (ns.plannerSessionStart, which a /reload keeps), so a /reload keeps them and a new session starts with none. A
-- dungeon run this session is never planned again this session, Plan my route or not; Plan my route clears the skips.
------------------------------------------------------------------------------------------
local loose                                   -- (no saved record yet: this session's, in memory)
local function Session(create)
    local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(create) or nil
    local at = ns.plannerSessionStart
    local s = type(rec) == "table" and rec.dungeonSession or loose
    if type(s) == "table" and s.at == at and type(s.ran) == "table" and type(s.skipped) == "table" then return s end
    if not create then return nil end
    s = { at = at, ran = {}, skipped = {} }
    if type(rec) == "table" then rec.dungeonSession = s else loose = s end
    return s
end
local function MarkRan(zone) if zone ~= nil then local s = Session(true); if s then s.ran[zone] = true end end end
function ns.PlannerDungeonRan(zone)
    local s = zone ~= nil and Session(false)
    return s and s.ran[zone] == true or false
end
function ns.PlannerDungeonSkip(zone) if zone ~= nil then local s = Session(true); if s then s.skipped[zone] = true end end end
function ns.PlannerDungeonSkipped(zone)
    local s = zone ~= nil and Session(false)
    return s and s.skipped[zone] == true or false
end
function ns.PlannerDungeonSessionReset()
    loose = nil
    local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(false)
    if type(rec) == "table" then rec.dungeonSession = nil end
end
-- You came out of the instance `instance` alive after being inside (Guide.lua's inside mark): that dungeon was run.
-- By the run steps of `steps` with that instance, and by the dungeon table's.
function ns.PlannerDungeonLeft(instance, steps)
    instance = Num(instance)
    if not instance then return end
    for _, s in ipairs(type(steps) == "table" and steps or {}) do
        if type(s) == "table" and ns.GUIDE_RUN_KINDS[s.kind] and s.instance == instance and s.zone ~= nil then MarkRan(s.zone) end
    end
    for _, d in ipairs(type(ns.PLANNER_DUNGEONS) == "table" and ns.PLANNER_DUNGEONS or {}) do
        if type(d) == "table" and d.instance == instance and d.zone ~= nil then MarkRan(d.zone) end
    end
end
-- (the skips go where the session's quest skips are cleared: Plan my route, ns:PlannerStart; a new session needs
-- nothing, its start is a new stamp)
do
    local reset = ns.PlannerSessionSkipReset
    if type(reset) == "function" then
        ns.PlannerSessionSkipReset = function(...)
            local s = Session(false)
            if s then s.skipped = {} end
            return reset(...)
        end
    end
end

------------------------------------------------------------------------------------------
-- The run's time (R1, R2) and the wait for a group (R3)
------------------------------------------------------------------------------------------
local function Default(d)
    local bosses = Num(tonumber(d.bosses)) or 0
    local level = Num(tonumber(d.minLevel)) or 15
    return (ns.PLANNER_DUNGEON_BASE + ns.PLANNER_DUNGEON_PER_BOSS * bosses) * (1 + max(0, level - 15) / 60)
end
-- Is this logged run one of this dungeon? By the instance id; a run from before 13.5 (no id) by its name.
local function Same(r, d)
    if r.id ~= nil then return d.instance ~= nil and r.id == d.instance end
    return d.name ~= nil and r.instance == d.name
end
-- Was it run at a level the dungeon is for? Its character's level when it began (RunLog.lua); a run with no level
-- (from before 13.5) only when it is your own. (A level 60 alt farming it says nothing of your time.)
local function InRange(r, d)
    local level = Num(tonumber(r.level))
    if level then
        local lo, hi = Num(tonumber(d.minLevel)), Num(tonumber(d.maxLevel))
        return lo ~= nil and hi ~= nil and level >= lo and level <= hi
    end
    return r.char ~= nil and r.char == ns:CharKey()
end
local function Median(list)
    local copy = {}
    for i, v in ipairs(list) do copy[i] = v end
    sort(copy)
    local n = #copy
    if n % 2 == 1 then return copy[(n + 1) / 2] end
    return (copy[n / 2] + copy[n / 2 + 1]) / 2
end
-- Seconds a run of `d` takes: the default from its level and size, sharpened by runs of it that killed a boss, by a
-- character within its level range (1 or 2: the average of the default and their mean; 3 or more: the median of the last 5).
function ns.PlannerDungeonSeconds(d)
    if type(d) ~= "table" then return 0 end
    local def = Default(d)
    local log = ns.RunLogged and ns.RunLogged() or nil
    local runs = {}
    for _, r in ipairs(type(log) == "table" and log or {}) do
        ns.PlannerYield()
        if type(r) == "table" and Same(r, d) and InRange(r, d) and ns.RunKills and ns.RunKills(r) > 0 then
            local length = ns.RunLength and tonumber(ns.RunLength(r)) or 0
            if length > 0 then runs[#runs + 1] = length end
        end
    end
    if #runs == 0 then return def end
    if #runs <= 2 then
        local sum = 0
        for _, v in ipairs(runs) do sum = sum + v end
        return (def + sum / #runs) / 2
    end
    local last = {}
    for i = max(1, #runs - 4), #runs do last[#last + 1] = runs[i] end
    return Median(last)
end
-- Seconds to find a group: 900 * need / 4, need = 5 - have, have = your group (a duo friend: 2; at least you);
-- none in a group of 3 or more. ctx.groupSize from the "context" hook, else the game's.
function ns.PlannerDungeonWait(ctx)
    ctx = type(ctx) == "table" and ctx or {}
    local members = Num(ctx.groupSize) or GroupSize()
    if members >= 3 then return 0 end
    local have = max(members, ctx.duo and 2 or 0, 1)
    return ns.PLANNER_GROUP_WAIT * max(0, 5 - have) / 4
end

------------------------------------------------------------------------------------------
-- A dungeon as a pseudo-hub
------------------------------------------------------------------------------------------
-- Is this quest in your log ready to hand in? (ctx.ready from the "context" hook, else the quest log.)
local function LogReady(id)
    local QL = C_QuestLog
    if type(QL) ~= "table" or type(id) ~= "number" then return false end
    local sid = ns.PlannerServerId and ns.PlannerServerId(id) or id
    for _, fn in ipairs({ QL.IsComplete, QL.ReadyForTurnIn }) do
        if type(fn) == "function" then
            local ok, v = pcall(fn, sid)
            if ok and ns.Is(v, true) then return true end
        end
    end
    return false
end
local function Ready(ctx, id)
    if type(ctx) == "table" and type(ctx.ready) == "function" then return ctx.ready(id) == true end
    return LogReady(id)
end
local function Travel(a, b, tctx)
    if not (a and b) then return 0 end
    return tonumber((ns.PlannerTravel(a, b, tctx))) or huge
end
local function Spot(s)
    if type(s) == "table" and Num(s.map) and Num(s.x) and Num(s.y) then return { map = s.map, x = s.x, y = s.y } end
end
-- The spot of `list` quickest to reach from `from`, and the seconds (nil when none can be reached).
local function Nearest(list, from, tctx)
    local best, bestS
    for _, s in ipairs(type(list) == "table" and list or {}) do
        local spot = Spot(s)
        if spot then
            local secs = Travel(from, spot, tctx)
            if secs < huge and (not bestS or secs < bestS) then best, bestS = spot, secs end
        end
    end
    return best, bestS
end

-- The dungeon's quests: those you could take now (as the dry-spell advice picks them, without the group test) and
-- those already in your log that are not done yet (their hand-ins come after the run; a ready one is an ordinary
-- quest of the route, R5). Skipped quests are left out.
local function Quests(d, c)
    local src = c.source
    if type(src) ~= "table" or type(src.zoneQuests) ~= "function" or type(src.quest) ~= "function" then return {}, {} end
    local level = tonumber(c.level) or 1
    local done = type(c.done) == "function" and c.done or function() return false end
    local onQuest = type(c.onQuest) == "function" and c.onQuest or function() return false end
    local never = type(c.skip) == "table" and c.skip or {}
    local function Done(q) return done(type(q) == "number" and math.abs(q) or q) end   -- (Questie's -id: that quest done)
    local function AllDone(list) for _, q in ipairs(type(list) == "table" and list or {}) do if not Done(q) then return false end end return true end
    local function AnyDone(list)
        if type(list) ~= "table" or #list == 0 then return true end
        for _, q in ipairs(list) do if Done(q) then return true end end
        return false
    end
    local open, logged = {}, {}
    for _, id in ipairs(src.zoneQuests(d.zone) or {}) do
        ns.PlannerYield()
        if not never[id] and not (ns.PlannerSessionSkipped and ns.PlannerSessionSkipped(id)) then
            if onQuest(id) then
                local rec = not Ready(c, id) and src.quest(id) or nil
                if type(rec) == "table" then logged[#logged + 1] = rec end
            elseif not done(id) then
                local rec = src.quest(id)
                if type(rec) == "table" and rec.doable and not rec.repeatable and (tonumber(rec.minLevel) or 1) <= level
                    and AllDone(rec.pre) and AnyDone(rec.preAny) then
                    open[#open + 1] = rec
                end
            end
        end
    end
    local keep = ns.PlannerExclusiveKeep and ns.PlannerExclusiveKeep(open, c) or nil   -- (one of quests that exclude each other)
    if keep then
        local kept = {}
        for _, rec in ipairs(open) do
            ns.PlannerYield()
            if keep[rec.id] then kept[#kept + 1] = rec end
        end
        open = kept
    end
    return open, logged
end

-- The experience of the run's monsters (R4): bosses * (15 + 1) elite kills a little above you, your share of five.
local function Monsters(d, c)
    local level = tonumber(c.level) or 1
    local lo, hi = tonumber(d.minLevel) or level, tonumber(d.maxLevel) or level
    local mob = max(lo + 2, min(level + 1, hi))
    local kills = (tonumber(d.bosses) or 0) * (ns.PLANNER_DUNGEON_KILLS + 1)
    local each = ns.PlannerKillXP and tonumber(ns.PlannerKillXP(level, mob, true)) or 0
    return kills * each * ns.PLANNER_DUNGEON_SHARE
end

local function QuestStep(kind, rec, spot, n, d)
    local name = Clean(rec.name)
    return { kind = kind, quest = rec.id, title = name and name:gsub("|", "") or nil, qlevel = tonumber(rec.level),
             map = spot.map, x = spot.x, y = spot.y, hub = n, dungeonZone = d.zone }
end
local STOP_PART = { group = "group", dungeon = "run" }   -- (the stopKey's last part: "dungeon:<zone>:group" / "dungeon:<zone>:run")
local function RunStep(kind, d, n)
    local name = Clean(d.name) or "?"
    local text = kind == "group" and format(ns:Tr("Find a group for %s"), name) or format(ns:Tr("Run %s"), name)
    return { kind = kind, instance = d.instance, zone = d.zone, dungeon = name, text = text, hub = n,
             stopKey = "dungeon:" .. tostring(d.zone) .. ":" .. STOP_PART[kind],
             map = d.map, x = d.x, y = d.y }
end

-- Its steps (Build's lay): the pick-ups, the group step, the run step, the hand-ins, each reached through ns.PlannerTrip.
-- seconds, real experience, quests kept.
local function Lay(state, hub, steps, n)
    local d = hub.dungeon
    local t, xp, kept, first, got = 0, 0, 0, true, {}
    local function Go(spot)                                   -- (the first trip that works is the way in: as a hub's)
        local tt = ns.PlannerTrip(state, spot, steps, first)
        if tt then t, first = t + tt, false end
        return tt ~= nil
    end
    for _, a in ipairs(hub.accepts) do
        if Go(a.spot) then
            steps[#steps + 1] = QuestStep("accept", a.rec, a.spot, n, d)
            t = t + HANDLE
            got[a.rec.id] = true
        end
    end
    if not Go(hub.entrance) then return t, 0, 0 end          -- (the entrance can't be reached after all: no run, no hand-ins)
    steps[#steps + 1] = RunStep("group", d, n)
    steps[#steps + 1] = RunStep("dungeon", d, n)
    t = t + hub.wait + hub.run
    xp = xp + hub.monsters
    for _, e in ipairs(hub.turnins) do
        if (got[e.rec.id] or e.logged) and Go(e.spot) then
            steps[#steps + 1] = QuestStep("turnin", e.rec, e.spot, n, d)
            t = t + HANDLE
            local _, _, real = ns.PlannerQuestXP(e.rec, state.ctx)
            xp, kept = xp + (tonumber(real) or 0), kept + 1
        end
    end
    return t, xp, kept
end

-- The dungeon `d` as a pseudo-hub for the route (the "extra" hook's entry), or nil when its entrance can't be reached.
-- quests: the ones you could take (and those in your log not done yet); xp: their ns.PlannerQuestXP and the monsters;
-- seconds: the pick-ups (5 s each), the way to the entrance, the wait, the run and the hand-ins; into: the first giver,
-- else the entrance (Build adds the way there).
function ns.PlannerDungeonHub(d, c, state)
    if type(d) ~= "table" or type(c) ~= "table" then return nil end
    local entrance = Spot(d)
    if not entrance then return nil end
    local tctx = type(state) == "table" and state.tctx or c
    local pos = type(state) == "table" and state.pos or nil
    local open, logged = Quests(d, c)
    -- a quest whose hand-in can't be reached from the entrance is left out
    local ends = {}
    local function Ends(list, isLogged)                       -- (the ones kept, each with its hand-in in `ends`)
        local out = {}
        for _, rec in ipairs(list) do
            ns.PlannerYield()
            local spot = Nearest(rec.ends, entrance, tctx)
            if spot then out[#out + 1] = rec; ends[#ends + 1] = { rec = rec, spot = spot, logged = isLogged } end
        end
        return out
    end
    open = Ends(open, false)
    Ends(logged, true)                                        -- (in your log already: only their hand-ins)
    -- the pick-ups, the nearest giver first from where you stand
    local accepts, at, t, left = {}, pos, 0, {}
    for i, rec in ipairs(open) do left[i] = rec end
    while #left > 0 do
        ns.PlannerYield()
        local bi, bspot, bs
        for i, rec in ipairs(left) do
            local spot, secs = Nearest(rec.starts, at, tctx)
            if spot and (not bs or secs < bs) then bi, bspot, bs = i, spot, secs end
        end
        if not bi then break end
        if #accepts > 0 then t = t + bs end                  -- (the way to the first giver is the route's: it is `into`)
        t = t + HANDLE
        accepts[#accepts + 1] = { rec = left[bi], spot = bspot }
        at = bspot
        table.remove(left, bi)
    end
    local taken = {}
    for _, a in ipairs(accepts) do taken[a.rec.id] = true end
    local door = #accepts > 0 and Travel(at, entrance, tctx) or 0
    if door == huge then return nil end
    local wait, run = ns.PlannerDungeonWait(c), ns.PlannerDungeonSeconds(d)
    t = t + door + wait + run
    -- the hand-ins, the nearest first from the entrance
    local turnins, todo = {}, {}
    for _, e in ipairs(ends) do if e.logged or taken[e.rec.id] then todo[#todo + 1] = e end end
    at = entrance
    while #todo > 0 do
        ns.PlannerYield()
        local bi, bs
        for i, e in ipairs(todo) do
            local secs = Travel(at, e.spot, tctx)
            if secs < huge and (not bs or secs < bs) then bi, bs = i, secs end
        end
        if not bi then break end
        t = t + bs + HANDLE
        turnins[#turnins + 1] = todo[bi]
        at = todo[bi].spot
        table.remove(todo, bi)
    end
    local quests, xp = {}, 0
    for _, e in ipairs(turnins) do
        quests[#quests + 1] = e.rec
        xp = xp + (tonumber((ns.PlannerQuestXP(e.rec, c))) or 0)
    end
    local monsters = Monsters(d, c)
    return { xp = xp + monsters, seconds = max(1, t), map = entrance.map, x = entrance.x, y = entrance.y,
             into = accepts[1] and accepts[1].spot or entrance, quests = quests, lay = Lay,
             dungeon = d, entrance = entrance, accepts = accepts, turnins = turnins, wait = wait, run = run, monsters = monsters }
end

------------------------------------------------------------------------------------------
-- The planner's hooks
------------------------------------------------------------------------------------------
-- The dungeons' area ids of a source's list (kept by the list: the Questie source hands out the same one a session).
local zonesOf = setmetatable({}, { __mode = "k" })
local function Zones(src)
    local list = src.dungeons()
    if type(list) ~= "table" then return {} end
    local z = zonesOf[list]
    if not z then
        z = {}
        for _, d in ipairs(list) do if type(d) == "table" and d.zone ~= nil then z[d.zone] = true end end
        zonesOf[list] = z
    end
    return z
end
local function Active(src) return On() and type(src) == "table" and type(src.dungeons) == "function" end

-- The best dungeon by rate (R6: Build offers it while a quest hub or the lead-in is left, or with no quest zone).
ns.PlannerHook("extra", "dungeons", function(c, state)
    if type(c) ~= "table" or not Active(c.source) then return nil end
    local level = tonumber(c.level) or 1
    local best, bestRate
    for _, d in ipairs(c.source.dungeons() or {}) do
        ns.PlannerYield()
        if type(d) == "table" and Num(d.minLevel) and Num(d.maxLevel) and d.minLevel <= level and level <= d.maxLevel
            and not ns.PlannerDungeonRan(d.zone) and not ns.PlannerDungeonSkipped(d.zone) then
            local hub = ns.PlannerDungeonHub(d, c, state)
            if hub then
                local travel = type(state) == "table" and state.pos and Travel(state.pos, hub.into, state.tctx) or 0
                local total = hub.seconds + travel
                local rate = (travel < huge and total > 0) and hub.xp / total or -1
                if rate > 0 and (not best or rate > bestRate) then best, bestRate = hub, rate end
            end
        end
    end
    return best and { best } or nil
end)

-- R5: a quest filed under a dungeon's area belongs to its run, never to a quest hub; one in your log comes back as an
-- ordinary quest once it is ready to hand in. (A dungeon-tagged quest of a dungeon the list does not have stays as in 13.0.)
ns.PlannerHook("candidate", "dungeons", function(rec, ctx, logged)
    if type(rec) ~= "table" or type(ctx) ~= "table" or not Active(ctx.source) then return nil end
    local area = Num(rec.sort)
    if not (area and Zones(ctx.source)[area]) then return nil end
    if logged and Ready(ctx, rec.id) then return nil end
    return false
end)

-- The plan's view of your group and your log.
ns.PlannerHook("context", "dungeons", function(ctx)
    if type(ctx) ~= "table" then return end
    local left = ns.GuideLeftDungeon and ns.GuideLeftDungeon()   -- (out of a dungeon you were in: run, before this plan is made)
    if left then ns.PlannerDungeonLeft(left) end
    ctx.groupSize = GroupSize()
    ctx.ready = LogReady
end)

------------------------------------------------------------------------------------------
-- The guide: the run step done, Skip this dungeon, and the wait line
------------------------------------------------------------------------------------------
local function Planned(st) return type(st) == "table" and st.name ~= nil and st.name == ns.GUIDE_PLANNED end
local function Now() return type(GetTime) == "function" and Num(GetTime()) or 0 end
local function Current()
    local st = ns.GuideState and ns.GuideState()
    if not Planned(st) then return nil end
    local guide = ns:GuideGet(st.name)
    return st, type(guide) == "table" and type(guide.steps) == "table" and guide.steps or nil
end
-- How long you have been on this group step (seconds; the advance hook marks when it came up, saved with the state).
local function Waited(st, step)
    if not (Planned(st) and type(step) == "table" and step.kind == "group" and step.stopKey) then return 0 end
    local now = Now()
    local mark = type(st.dungeonWait) == "table" and st.dungeonWait or nil
    if not mark or mark.key ~= step.stopKey or type(mark.at) ~= "number" or mark.at > now then   -- (a new step, or the clock went back: a new start)
        mark = { key = step.stopKey, at = now }
        st.dungeonWait = mark
    end
    return now - mark.at
end
local function LongWait(st, step) return Waited(st, step) >= ns.PLANNER_GROUP_SKIP_AFTER end

-- After the run, a hand-in of its quests that is not ready (a drop that never came) is passed over: the run is done,
-- and it would hold the route (a kept one for good).
local function Yes(fn, ...) return type(fn) == "function" and fn(...) == true end
local function PassOver(st, steps, at, runDone)
    local w = type(ns.GuideWorld) == "function" and ns:GuideWorld() or {}
    local pass = false
    for i = at, #steps do
        local s = steps[i]
        if type(s) == "table" and s.kind == "turnin" and type(s.quest) == "number" and s.dungeonZone ~= nil and runDone[s.dungeonZone]
            and not (type(st.skipped) == "table" and st.skipped[i]) and not (Yes(w.ready, s.quest, s) or Yes(w.completed, s.quest, s)) then
            st.skipped = type(st.skipped) == "table" and st.skipped or {}
            st.skipped[i], pass = true, true
        end
    end
    if pass then ns:After(0, function() pcall(ns.GuideAdvance, ns) end) end   -- (not from inside the advance that called this)
end
ns.GuideRegisterAdvance("dungeon", function(st, guide, step, at)
    if not Planned(st) or type(guide) ~= "table" or type(guide.steps) ~= "table" then return end
    local skippedSteps = type(st.skipped) == "table" and st.skipped or {}
    at = tonumber(at) or 1
    local runDone
    for i = 1, at - 1 do                                      -- (a run step behind you, done and not skipped: the dungeon was run)
        local s = guide.steps[i]
        if type(s) == "table" and s.kind == "dungeon" and s.zone ~= nil and not skippedSteps[i] then
            MarkRan(s.zone)
            runDone = runDone or {}
            runDone[s.zone] = true
        end
    end
    if runDone then PassOver(st, guide.steps, at, runDone) end
    if type(step) == "table" and step.kind == "group" then Waited(st, step) end
end)

-- Skip this dungeon: for the session, then plan again; on a kept route, its steps and its quests' steps are skipped.
function ns.PlannerDungeonSkipNow(step)
    if type(step) ~= "table" or step.zone == nil then return false end
    local zone = step.zone
    ns.PlannerDungeonSkip(zone)
    local st, steps = Current()
    if not (st and steps) then return false end
    if not ns.GuideKeepRoute() then
        ns:PlannerReplan("skip dungeon")
        return true
    end
    st.skipped = type(st.skipped) == "table" and st.skipped or {}
    local quests = {}
    for i = tonumber(st.at) or 1, #steps do
        local s = steps[i]
        if type(s) == "table" then
            if ns.GUIDE_RUN_KINDS[s.kind] and s.zone == zone then st.skipped[i] = true end
            if s.dungeonZone == zone and type(s.quest) == "number" then quests[#quests + 1] = s.quest end
        end
    end
    for _, q in ipairs(quests) do ns.GuideSkipQuest(q) end
    ns:GuideAdvance()
    return true
end
local function RunStepShown(step)
    local st = Current()
    return st ~= nil and type(step) == "table" and ns.GUIDE_RUN_KINDS[step.kind] == true and step.zone ~= nil
end
ns.GuideRegisterAction("panel", "skipDungeon", "Skip this dungeon", function(step) ns.PlannerDungeonSkipNow(step) end, function(step)
    local st, steps = Current()
    if not (st and steps and step ~= nil and steps[tonumber(st.at) or 1] == step and step.zone ~= nil) then return false end
    return LongWait(st, step)
end)
ns.GuideRegisterAction("step", "skipDungeon", "Skip this dungeon", function(step) ns.PlannerDungeonSkipNow(step) end, RunStepShown)
-- The panel's line once the wait is long (the same time the panel's menu offers the skip).
function ns.PlannerDungeonWaitLine(st, steps, at)
    if not Planned(st) or type(steps) ~= "table" then return nil end
    local step = steps[tonumber(at) or 1]
    if not (type(step) == "table" and step.kind == "group" and step.zone ~= nil and LongWait(st, step)) then return nil end
    return ns:Tr("No group yet? You can skip this dungeon in the ... menu.")
end
ns.GuideRegisterLine("dungeonWait", function(st, steps, at) return ns.PlannerDungeonWaitLine(st, steps, at) end)

ns.FolderFileDone("planner", "PlannerDungeons.lua")
