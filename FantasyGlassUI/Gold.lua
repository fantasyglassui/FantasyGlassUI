local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Ways to make gold: the core. Sources (GoldSell, GoldFarm, GoldGather, GoldCraft) hand in ideas
-- through ns.GoldRegister; this file checks them, collects them a slice at a time (never in a fight),
-- ranks them by three sliders, keeps the goal, and knows what an item is worth and how fresh that is.
-- It exists only while the guide is unlocked: nothing here is built, translated or run before then.
--
-- An idea:
--   { id, kind, title, oneOff, perHour (per-hour ideas) | total and minutes (one-offs), ease, safety,
--     basis = "guess"|"measured"|"prices", priceDay, where = "window"|"auction"|"both",
--     go, steps = { { text, map, x, y } }, detail = { list lines }, tip = { strings }, map }
------------------------------------------------------------------------------------------
local floor, max, min, huge = math.floor, math.max, math.min, math.huge

ns.GOLD_BUDGET_MS = 4
ns.GOLD_KINDS = { sell = true, junk = true, vflip = true, aflip = true, flip = true, craft = true, gather = true, farm = true, dungeon = true }
-- How little effort, by kind (farm and gather lose 10 away from where you are: the sources do that).
ns.GOLD_EASE = { junk = 100, sell = 95, vflip = 70, aflip = 60, flip = 60, craft = 50, gather = 40, farm = 35, dungeon = 20 }
-- How sure the money is, by kind and basis, before the prices' freshness is counted.
ns.GOLD_SAFETY = {
    junk = { prices = 100 }, aflip = { prices = 90 }, sell = { prices = 75 }, vflip = { prices = 55 }, craft = { prices = 50 }, flip = { prices = 40 },
    farm = { guess = 50, measured = 80 }, gather = { guess = 45, measured = 80 }, dungeon = { guess = 35, measured = 60 },
}
-- The sliders' presets ({ gold, ease, safety }), in the order the preset button goes round them.
ns.GOLD_PRESETS = { most = { 100, 0, 0 }, easy = { 30, 70, 0 }, safe = { 30, 0, 70 } }
ns.GOLD_PRESET_ORDER = { "most", "easy", "safe" }
ns.GOLD_PRESET_NAMES = { most = "Most gold", easy = "Easy money", safe = "Safe", custom = "Custom" }
-- The named goals, in copper.
ns.GOLD_GOALS = { mount = 1000000, epic = 10000000 }

local BASIS = { guess = true, measured = true, prices = true }
local WHERE = { window = true, auction = true, both = true }

------------------------------------------------------------------------------------------
-- recorders (light; may stay in the main add-on when the folder moves)
-- The core keeps none: the merchant, loot, gathering and recipe recorders are in the groups' files.
-- The only thing watched here is whether a fight is on, and only once a job has been queued.
------------------------------------------------------------------------------------------
local fighting = false

------------------------------------------------------------------------------------------
-- Ideas and sources
------------------------------------------------------------------------------------------
-- Why a number is no good, or nil when it is a plain finite number of at least 0.
local function BadNumber(v, name)
    if v == nil then return "no " .. name end
    if Secret(v) then return "secret " .. name end
    if type(v) ~= "number" then return name .. " is not a number" end
    if v ~= v or v == huge or v == -huge then return name .. " is not finite" end
    if v < 0 then return "negative " .. name end
    return nil
end
local function BadString(v)
    return v == nil or Secret(v) or type(v) ~= "string" or v == ""
end
local OPTIONAL = { go = "function", steps = "table", detail = "table", tip = "table" }

-- Is this idea one the window can show? false and why when it is not.
function ns.GoldIdeaValid(idea)
    if type(idea) ~= "table" then return false, "not a table" end
    if BadString(idea.id) then return false, "no id" end
    if BadString(idea.title) then return false, "no title" end
    if BadString(idea.kind) or not ns.GOLD_KINDS[idea.kind] then return false, "unknown kind" end
    if BadString(idea.basis) or not BASIS[idea.basis] then return false, "unknown basis" end
    if BadString(idea.where) or not WHERE[idea.where] then return false, "unknown where" end
    for _, k in ipairs({ "ease", "safety" }) do
        local why = BadNumber(idea[k], k)
        if why then return false, why end
        if idea[k] > 100 then return false, k .. " above 100" end
    end
    if Secret(idea.oneOff) then return false, "secret oneOff" end
    if idea.oneOff == true then
        local why = BadNumber(idea.total, "total") or BadNumber(idea.minutes, "minutes")
        if why then return false, why end
        if idea.total < 100 then return false, "under 1 silver" end
    else
        local why = BadNumber(idea.perHour, "perHour")
        if why then return false, why end
        if idea.perHour < 100 then return false, "under 1 silver an hour" end
    end
    if idea.priceDay ~= nil then
        local why = BadNumber(idea.priceDay, "priceDay")
        if why then return false, why end
    end
    if idea.map ~= nil then
        local why = BadNumber(idea.map, "map")
        if why then return false, why end
    end
    for k, want in pairs(OPTIONAL) do
        if idea[k] ~= nil and type(idea[k]) ~= want then return false, k .. " is not a " .. want end
    end
    return true
end

local sources = {}
-- A source: fn(ctx, add), calling add(idea) for each idea. The same key again replaces it; nil removes it.
function ns.GoldRegister(key, fn)
    if type(key) ~= "string" or (fn ~= nil and type(fn) ~= "function") then return false end
    sources[key] = fn
    return true
end
function ns.GoldSources()
    local out = {}
    for key, fn in pairs(sources) do out[key] = fn end
    return out
end

local function Note(text)
    if type(ns.errors) == "table" and #ns.errors < 60 then ns.errors[#ns.errors + 1] = "Gold: " .. tostring(text) end
end

------------------------------------------------------------------------------------------
-- Jobs: coroutines run one a frame, for at most ns.GOLD_BUDGET_MS, never in a fight
------------------------------------------------------------------------------------------
local queue = {}                       -- { { co, key } }, the first one runs
local slicing, sliceStart = false, 0
local started = false

local function Clock()
    local v = debugprofilestop and debugprofilestop()
    return type(v) == "number" and v or 0
end
local function InFight()
    if fighting then return true end
    local ok, v = pcall(InCombatLockdown)
    return ok and ns.Yes(v)
end

-- Called in a job's plain loops (never inside pcall, a sort or a gsub): hands the frame back once
-- the slice has used its time. Outside a job it does nothing.
function ns.GoldYield()
    if not slicing then return end
    if fighting or Clock() - sliceStart >= (ns.GOLD_BUDGET_MS or 4) then coroutine.yield() end
end

-- One frame's work: the first job runs until it yields or ends. False when nothing ran.
function ns.GoldRunSlice()
    local job = queue[1]
    if not job or InFight() then return false end
    slicing, sliceStart = true, Clock()
    local ok, err = coroutine.resume(job.co)
    slicing = false
    if not ok then Note(err) end
    if not ok or coroutine.status(job.co) == "dead" then
        for i = 1, #queue do if queue[i] == job then table.remove(queue, i); break end end
    end
    return true
end

local function Start()
    if started then return end
    started = true
    ns:Every(0, "Gold", function() if queue[1] then ns.GoldRunSlice() end end)
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_DISABLED")
    pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", ns:Guard("Gold", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then fighting = true
        elseif event == "PLAYER_REGEN_ENABLED" then fighting = false end
    end))
end

-- Queue a job. A key already queued or running is refused.
function ns.GoldJob(fn, key)
    if type(fn) ~= "function" then return false end
    key = (key ~= nil) and tostring(key) or tostring(fn)
    for i = 1, #queue do if queue[i].key == key then return false end end
    queue[#queue + 1] = { co = coroutine.create(fn), key = key }
    Start()
    return true
end
-- Is a job queued or running (this one, with a key)?
function ns.GoldBusy(key)
    if key == nil then return queue[1] ~= nil end
    for i = 1, #queue do if queue[i].key == key then return true end end
    return false
end

------------------------------------------------------------------------------------------
-- Collecting: every source in turn, each in a coroutine of its own
------------------------------------------------------------------------------------------
local function Ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if ok and not Secret(v) then return v end
    return nil
end
function ns.GoldContext(where)
    local level, money, now = Ask(UnitLevel, "player"), Ask(GetMoney), Ask(time)
    local map = Ask(C_Map and C_Map.GetBestMapForUnit, "player")
    local zone = Ask(GetRealZoneText)
    return {
        today = ns.Today(), now = type(now) == "number" and now or nil,
        level = type(level) == "number" and level or nil, money = type(money) == "number" and money or nil,
        charKey = ns:CharKey(), map = type(map) == "number" and map or nil, zone = type(zone) == "string" and zone or nil,
        houseKey = ns.PriceHouseKey and ns.PriceHouseKey() or nil, house = ns.PriceHouse and ns.PriceHouse() or nil,
        where = (where == "auction") and "auction" or "window",
    }
end

local told = {}                        -- sources whose error has been noted this session
-- `pausing`: inside a job, where a source that yields hands the frame back.
local function Collect(ctx, pausing)
    local keys = {}
    for key in pairs(sources) do keys[#keys + 1] = key end
    table.sort(keys)
    local ideas, seen, dropped = {}, {}, 0
    for _, key in ipairs(keys) do
        local fn = sources[key]
        if fn then
            local mine = {}
            local function add(idea)
                if ns.GoldIdeaValid(idea) then mine[#mine + 1] = idea else dropped = dropped + 1 end
            end
            local co = coroutine.create(fn)
            local ok, err = coroutine.resume(co, ctx, add)
            while ok and coroutine.status(co) == "suspended" do
                if pausing then coroutine.yield() end
                ok, err = coroutine.resume(co)
            end
            if ok then
                for _, idea in ipairs(mine) do
                    if seen[idea.id] then dropped = dropped + 1 else seen[idea.id] = true; ideas[#ideas + 1] = idea end
                end
            elseif not told[key] then
                told[key] = true
                Note(key .. ": " .. tostring(err))
            end
            if pausing then ns.GoldYield() end
        end
    end
    ns.goldDropped = dropped
    return ideas
end
-- Collect as a job; done(ideas) when every source has answered. False when one is already running here.
function ns.GoldCollect(ctx, done)
    ctx = type(ctx) == "table" and ctx or ns.GoldContext("window")
    return ns.GoldJob(function()
        local ideas = Collect(ctx, true)
        if done then done(ideas) end
    end, "collect:" .. tostring(ctx.where))
end
-- The same in one go (for the tests).
function ns.GoldCollectNow(ctx)
    return Collect(type(ctx) == "table" and ctx or ns.GoldContext("window"), false)
end

------------------------------------------------------------------------------------------
-- What an item is worth, and how fresh that is
------------------------------------------------------------------------------------------
local function VendorPrice(id)
    local ok, _, _, _, _, _, _, _, _, _, _, vendor = pcall(ns.GetItemInfo, ns, id)
    if not ok or Secret(vendor) or type(vendor) ~= "number" or vendor ~= vendor or vendor <= 0 or vendor == huge then return 0 end
    return vendor
end
-- The better of the auction house (after its 5% cut) and a vendor: copper, "ah"|"vendor"|nil, and the
-- day of the auction price when that wins.
function ns.GoldItemValue(id, today)
    if Secret(id) or type(id) ~= "number" then return 0, nil, nil end
    today = today or ns.Today()
    local ah, day = 0, nil
    local e = ns.PriceEntry(id)
    if type(e) == "table" and type(e.price) == "number" then
        local p = e.price
        if e.day ~= today then p = ns.AuctionUsual(e) or e.price end
        if type(p) == "number" and p == p and p > 0 and p < huge then
            ah, day = floor(p * 0.95), (type(e.day) == "number") and e.day or nil
        end
    end
    local vendor = VendorPrice(id)
    if ah > 0 and ah > vendor then return ah, "ah", day end
    if vendor > 0 then return vendor, "vendor", nil end
    return 0, nil, nil
end

-- How much an idea's safety still counts with prices this old (nil: no auction price, so 1).
function ns.GoldFreshFactor(priceDay, today)
    if type(priceDay) ~= "number" then return 1 end
    local age = ns.DaysBetween(priceDay, today or ns.Today())
    if age <= 1 then return 1 end
    if age <= 3 then return 0.85 end
    if age <= 7 then return 0.6 end
    return 0.4
end

local BASIS_WORD = { guess = "guess", measured = "measured", prices = "from prices" }
-- "guess · prices from 2 days ago": whether it is a guess, and how old its prices are.
function ns.GoldFreshText(idea, today)
    idea = type(idea) == "table" and idea or {}
    local basis = ns:Tr(BASIS_WORD[idea.basis] or "guess")
    local age
    if type(idea.priceDay) ~= "number" then
        age = ns:Tr("vendor prices")
    else
        local days = max(0, ns.DaysBetween(idea.priceDay, today or ns.Today()))
        if days == 0 then age = ns:Tr("prices from today")
        elseif days == 1 then age = ns:Tr("prices from yesterday")
        else age = format(ns:Tr("prices from %d days ago"), days) end
    end
    return basis .. " · " .. age
end

------------------------------------------------------------------------------------------
-- Ranking: the sliders, "Right now", and one list by time to the goal
------------------------------------------------------------------------------------------
local function Step10(v)
    v = tonumber(v)
    if not v or v ~= v then return nil end
    return max(0, min(100, floor(v / 10 + 0.5) * 10))
end
function ns.GoldPresetOf(g, e, s)
    for _, key in ipairs(ns.GOLD_PRESET_ORDER) do
        local p = ns.GOLD_PRESETS[key]
        if p[1] == g and p[2] == e and p[3] == s then return key end
    end
    return "custom"
end
function ns.GoldWeights()
    local w = type(ns.root) == "table" and ns.root.goldWeights
    if type(w) ~= "table" then return 100, 0, 0 end
    local g, e, s = Step10(w.gold), Step10(w.ease), Step10(w.safety)
    if not (g and e and s) then return 100, 0, 0 end
    return g, e, s
end
local WHICH = { gold = true, ease = true, safety = true }
function ns.GoldSetWeight(which, v)
    v = Step10(v)
    if not WHICH[which] or not v or type(ns.root) ~= "table" then return false end
    local g, e, s = ns.GoldWeights()
    local w = { gold = g, ease = e, safety = s }
    w[which] = v
    ns.root.goldWeights = w
    return true
end
function ns.GoldSetPreset(key)
    local p = ns.GOLD_PRESETS[key]
    if not p or type(ns.root) ~= "table" then return false end
    ns.root.goldWeights = { gold = p[1], ease = p[2], safety = p[3] }
    return true
end

-- "Right now": the most gold first, then the quickest.
local function NowOrder(a, b)
    if a.total ~= b.total then return a.total > b.total end
    if a.minutes ~= b.minutes then return a.minutes < b.minutes end
    return tostring(a.id) < tostring(b.id)
end
local function ScoreOrder(a, b)
    if a.score ~= b.score then return a.score > b.score end
    if a.perHour ~= b.perHour then return a.perHour > b.perHour end
    return tostring(a.id) < tostring(b.id)
end
local function GoalOrder(a, b)
    if a.toGoal ~= b.toGoal then return a.toGoal < b.toGoal end
    local ga, gb = a.oneOff and a.total or a.perHour, b.oneOff and b.total or b.perHour
    if ga ~= gb then return ga > gb end
    return tostring(a.id) < tostring(b.id)
end

-- Rank checked ideas. weights = { gold, ease, safety }; goalLeft = copper still to save, or nil.
-- Each idea gets .safetyNow, .score (per-hour ideas) and .toGoal (minutes, with a goal still to reach).
function ns.GoldRank(ideas, weights, goalLeft, today)
    today = today or ns.Today()
    weights = type(weights) == "table" and weights or {}
    local wg, we, ws = max(0, tonumber(weights[1]) or 0), max(0, tonumber(weights[2]) or 0), max(0, tonumber(weights[3]) or 0)
    if wg + we + ws <= 0 then wg, we, ws = 100, 0, 0 end
    local now, ranked, most = {}, {}, 0
    for _, idea in ipairs(type(ideas) == "table" and ideas or {}) do
        idea.safetyNow = floor((tonumber(idea.safety) or 0) * ns.GoldFreshFactor(idea.priceDay, today) + 0.5)
        idea.score, idea.toGoal = nil, nil
        if idea.oneOff == true then now[#now + 1] = idea
        else
            ranked[#ranked + 1] = idea
            most = max(most, tonumber(idea.perHour) or 0)
        end
    end
    for _, idea in ipairs(ranked) do
        local g = (most > 0) and (100 * idea.perHour / most) or 0
        idea.score = (wg * g + we * (tonumber(idea.ease) or 0) + ws * idea.safetyNow) / (wg + we + ws)
    end
    table.sort(ranked, ScoreOrder)
    table.sort(now, NowOrder)
    local merged
    goalLeft = tonumber(goalLeft)
    if goalLeft and goalLeft == goalLeft and goalLeft > 0 and goalLeft < huge then
        local best = ranked[1] and ranked[1].perHour or 0
        local within, rest = {}, {}
        for _, idea in ipairs(now) do
            if idea.total >= goalLeft then idea.toGoal = idea.minutes
            elseif best > 0 then idea.toGoal = idea.minutes + (goalLeft - idea.total) * 60 / best
            else idea.toGoal = huge end
            within[#within + 1] = idea
        end
        local top = ranked[1] and ranked[1].score or 0
        for _, idea in ipairs(ranked) do
            idea.toGoal = (idea.perHour > 0) and (goalLeft * 60 / idea.perHour) or huge
            if idea.score >= 0.5 * top then within[#within + 1] = idea else rest[#rest + 1] = idea end
        end
        table.sort(within, GoalOrder)
        merged = within
        for _, idea in ipairs(rest) do merged[#merged + 1] = idea end
    end
    return { now = now, ranked = ranked, merged = merged }
end

-- Words ---------------------------------------------------------------------------------------
function ns.GoldEaseWord(n)
    n = tonumber(n) or 0
    if n >= 70 then return ns:Tr("Easy") end
    if n >= 40 then return ns:Tr("Some effort") end
    return ns:Tr("Hard")
end
function ns.GoldSafetyWord(n)
    n = tonumber(n) or 0
    if n >= 75 then return ns:Tr("Sure") end
    if n >= 45 then return ns:Tr("Fairly sure") end
    return ns:Tr("A gamble")
end
-- Minutes in words; "—" when there is no telling.
function ns.GoldTimeText(minutes)
    minutes = tonumber(minutes)
    if not minutes or minutes ~= minutes or minutes < 0 or minutes == huge then return "—" end
    if minutes < 1 then return ns:Tr("under a minute") end
    if minutes < 60 then return format(ns:Tr("%d min"), floor(minutes)) end
    if minutes < 48 * 60 then
        local m = floor(minutes)
        return format(ns:Tr("%d h %d min"), floor(m / 60), m % 60)
    end
    return format(ns:Tr("%d days"), floor(minutes / 1440))
end

------------------------------------------------------------------------------------------
-- The goal (per character) and the vendor prices (written by GoldSell.lua)
------------------------------------------------------------------------------------------
local function CharRecord(create)
    if type(ns.root) ~= "table" then return nil end
    local all = ns.root.goldChars
    if type(all) ~= "table" then
        if not create then return nil end
        all = {}
        ns.root.goldChars = all
    end
    local key = ns:CharKey()
    local rec = all[key]
    if type(rec) ~= "table" then
        if not create then return nil end
        rec = {}
        all[key] = rec
    end
    return rec
end
-- The goal in copper and its name ("mount", "epic" or nil); nil with no goal.
function ns.GoldGoal()
    local rec = CharRecord(false)
    local goal = rec and rec.goal
    if type(goal) ~= "number" or goal ~= goal or goal < 0 or goal == huge then return nil, nil end
    local name = (rec.goalName == "mount" or rec.goalName == "epic") and rec.goalName or nil
    return goal, name
end
function ns.GoldSetGoal(copper, name)
    copper = tonumber(copper)
    if copper and (copper ~= copper or copper < 0 or copper == huge) then copper = nil end
    if name ~= "mount" and name ~= "epic" then name = nil end
    if copper == nil then
        local rec = CharRecord(false)
        if rec then rec.goal, rec.goalName = nil, nil end
        return true
    end
    local rec = CharRecord(true)
    if not rec then return false end
    rec.goal, rec.goalName = floor(copper), name
    return true
end

-- What a vendor asks for one, the day it was seen, and the entry; nil when unknown or 180 days old.
function ns.GoldVendorBuy(id)
    if Secret(id) or type(id) ~= "number" or type(ns.root) ~= "table" then return nil end
    local store = ns.root.goldVendor
    local items = type(store) == "table" and type(store.items) == "table" and store.items or nil
    local e = items and items[id]
    if type(e) ~= "table" or type(e.buy) ~= "number" or e.buy <= 0 or type(e.day) ~= "number" then return nil end
    if ns.DaysBetween(e.day, ns.Today()) > 180 then return nil end
    return e.buy, e.day, e
end

------------------------------------------------------------------------------------------
-- Go: the planner's travel when it is in (ns.GoldTravel), otherwise the steps in a list
------------------------------------------------------------------------------------------
local function ZoneName(map)
    if Secret(map) or type(map) ~= "number" then return nil end
    local info = Ask(C_Map and C_Map.GetMapInfo, map)
    local name = type(info) == "table" and info.name or nil
    if Secret(name) or type(name) ~= "string" then return nil end
    return name
end
function ns.GoldGo(idea)
    if type(idea) ~= "table" then return false end
    if InFight() then ns:Print("Not during a fight."); return false end
    if type(ns.GoldTravel) == "function" then ns.GoldTravel(idea); return "travel" end
    if type(idea.go) == "function" then idea.go(idea); return "travel" end
    ns:Print("Going there needs the planner's travel, which is not in yet. Here are the steps.")
    local lines = {}
    for i, step in ipairs(type(idea.steps) == "table" and idea.steps or {}) do
        if type(step) == "table" and type(step.text) == "string" then
            local right = {}
            right[#right + 1] = ZoneName(step.map)
            if type(step.x) == "number" and type(step.y) == "number" then right[#right + 1] = format("%.1f, %.1f", step.x, step.y) end
            lines[#lines + 1] = { left = format("%d. %s", i, step.text), right = table.concat(right, "  ") }
        end
    end
    ns:ShowList("GoldSteps", type(idea.title) == "string" and idea.title or "Go", lines)
    return "list"
end
