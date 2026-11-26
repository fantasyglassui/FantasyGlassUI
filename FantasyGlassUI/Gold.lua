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
-- The named goals, in copper: riding and a mount at 40 (Paladins and Warlocks get their mount from a
-- class quest, so only the riding), and epic riding at 60. The costs on Forever are not certain yet:
-- the in-game checklist verifies them, and this table is the one place to change them.
ns.GOLD_GOALS = {
    mount = { name = "Riding at 40", copper = 1200000, byClass = { PALADIN = 1000000, WARLOCK = 1000000 } },
    epic = { name = "Epic riding at 60", copper = 10000000 },
}

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
    if idea.oneOff ~= nil and type(idea.oneOff) ~= "boolean" then return false, "oneOff is not true or false" end
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
-- stays in the main add-on (when the folder moves): the recorders queue their work here.
-- Jobs: coroutines run one a frame, for at most ns.GOLD_BUDGET_MS, never in a fight, never while locked
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

local function UnlockedNow() return ns.GuideUnlocked ~= nil and ns:GuideUnlocked() == true end
-- One frame's slice, guarded (an error is noted). Called only from the tick below, only while unlocked,
-- so nothing named Gold is timed by /fgui perf for a locked player.
local GuardedSlice = ns:Guard("Gold", function() ns.GoldRunSlice() end)
local tick                             -- a plain frame: shown while there is work or something to keep hidden
local function Tick(self)
    if not UnlockedNow() then                                   -- (locked again: hide everything and stop)
        if type(ns.GoldLockedNow) == "function" then ns.GoldLockedNow() end   -- (an ns hook: it still reaches the window after the folder split)
        self:Hide()
        return
    end
    if queue[1] then GuardedSlice()
    else
        -- (kept going while the window or the panel is up, so a lock later still hides them)
        local w, p = ns.goldWindow, ns.goldPanel
        if not ((type(w) == "table" and w.suiGoldOn) or (type(p) == "table" and p.suiGoldOn)) then self:Hide() end
    end
end
local function Start()
    if not tick then
        tick = CreateFrame("Frame")
        tick:SetScript("OnUpdate", Tick)
        ns.goldTick = tick
    end
    tick:Show()
    if started then return end
    started = true
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_DISABLED")
    pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", function(_, event)                -- (plain: it only sets a flag, and is never timed by /fgui perf)
        if event == "PLAYER_REGEN_DISABLED" then fighting = true
        elseif event == "PLAYER_REGEN_ENABLED" then fighting = false end
    end)
end

-- Queue a job. A key already queued or running is refused.
function ns.GoldJob(fn, key)
    if type(fn) ~= "function" then return false end
    key = (key ~= nil) and tostring(key) or tostring(fn)
    Start()                                                     -- (first: a job left from before a lock runs again once asked for)
    for i = 1, #queue do if queue[i].key == key then return false end end
    queue[#queue + 1] = { co = coroutine.create(fn), key = key }
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
-- (a source may leave notes on ctx for the sources after it, in key order: the craft source leaves
-- ctx.craftUses = { [itemID] = idea title }, which the sell source reads)
function ns.GoldContext(where)
    local level, money, now = Ask(UnitLevel, "player"), Ask(GetMoney), Ask(time)
    -- (this character was seen: its record in goldChars is kept another 180 days)
    local chars = type(ns.root) == "table" and ns.root.goldChars
    local mine = type(chars) == "table" and chars[ns:CharKey()]
    if type(mine) == "table" then mine.seen = ns.Today() end
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
-- stays in the main add-on (when the folder moves): VendorPrice and GoldItemValue, which the loot
-- recorder calls. What an item is worth, and how fresh that is
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

------------------------------------------------------------------------------------------
-- (the rest of this file can move with the folder)
------------------------------------------------------------------------------------------
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
    local auction = idea.priceWord == "auction"            -- (a measure valued at the auction prices seen then)
    if type(idea.priceDay) ~= "number" then
        age = ns:Tr(idea.builtIn and "default values" or "vendor prices")   -- (builtIn: a default for its level, no price at all)
    else
        local days = max(0, ns.DaysBetween(idea.priceDay, today or ns.Today()))
        if days == 0 then age = ns:Tr(auction and "auction prices from today" or "prices from today")
        elseif days == 1 then age = ns:Tr(auction and "auction prices from yesterday" or "prices from yesterday")
        else age = format(ns:Tr(auction and "auction prices from %d days ago" or "prices from %d days ago"), days) end
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

-- How much an idea counts for ordering only (its amounts stay true): a guess 80%, prices more than
-- 7 days old 90%, under any preset.
function ns.GoldOrderFactor(idea, today)
    local f = (idea.basis == "guess") and 0.8 or 1
    if type(idea.priceDay) == "number" and ns.DaysBetween(idea.priceDay, today or ns.Today()) > 7 then f = f * 0.9 end
    return f
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
            idea.orderFactor = ns.GoldOrderFactor(idea, today)
            most = max(most, (tonumber(idea.perHour) or 0) * idea.orderFactor)
        end
    end
    for _, idea in ipairs(ranked) do
        local f = idea.orderFactor
        local g = (most > 0) and (100 * idea.perHour * f / most) or 0
        idea.score = (wg * g + (we * (tonumber(idea.ease) or 0) + ws * idea.safetyNow) * f) / (wg + we + ws)
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

-- What a named goal costs this character (by class), or nil.
function ns.GoldGoalAmount(name)
    local g = ns.GOLD_GOALS[name]
    if not g then return nil end
    local ok, _, file = pcall(UnitClass, "player")
    if ok and not Secret(file) and type(file) == "string" and type(g.byClass) == "table" and g.byClass[file] then return g.byClass[file] end
    return g.copper
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
    ns:ShowList("GoldSteps", type(idea.title) == "string" and idea.title or ns:Tr("Go"), lines, nil, nil, nil, { rawTitle = true })
    return "list"
end

------------------------------------------------------------------------------------------
-- Forgetting old records: once a session, when the window first opens (a job)
------------------------------------------------------------------------------------------
local function ForgetOld()
    local root = ns.root
    if type(root) ~= "table" then return end
    local today = ns.Today()
    local function Walk(t, field, days)
        if type(t) ~= "table" then return end
        local keys = {}
        for k in pairs(t) do keys[#keys + 1] = k end              -- (the keys first: the table may change between slices)
        for _, k in ipairs(keys) do
            local e = t[k]
            if e ~= nil and not (type(e) == "table" and type(e[field]) == "number" and ns.DaysBetween(e[field], today) <= days) then t[k] = nil end
            ns.GoldYield()
        end
    end
    Walk(type(root.goldVendor) == "table" and root.goldVendor.items, "day", 180)
    Walk(root.goldMobs, "last", 90)
    Walk(root.goldGather, "day", 90)
    -- characters not seen for 180 days (a record from before the stamp is stamped now, not dropped;
    -- the one being played is always kept)
    local chars = root.goldChars
    if type(chars) == "table" then
        local me, keys = ns:CharKey(), {}
        for k in pairs(chars) do keys[#keys + 1] = k end
        for _, k in ipairs(keys) do
            local rec = chars[k]
            if k == me and type(rec) == "table" then rec.seen = today
            elseif type(rec) ~= "table" then chars[k] = nil
            elseif type(rec.seen) ~= "number" then rec.seen = today
            elseif ns.DaysBetween(rec.seen, today) > 180 then chars[k] = nil end
            ns.GoldYield()
        end
    end
end

------------------------------------------------------------------------------------------
-- The window: "Right now", the sliders, the goal, and the ranked list
------------------------------------------------------------------------------------------
local function Unlocked() return ns.GuideUnlocked ~= nil and ns:GuideUnlocked() == true end
-- Show or hide, and remember which (frames are asked through suiGoldOn, never IsShown).
local function Shown(f, on)
    if type(f) ~= "table" then return end
    f.suiGoldOn = on and true or false
    if on then f:Show() else f:Hide() end
end
local function Painted(fs, role) ns:Paint(fs, "SetTextColor", role or "text"); return fs end

local W                                -- the window
local win = { ideas = nil, waiting = false, again = false, gen = 0, drawn = { now = {}, ranked = {} } }
local syncing = false                  -- (the sliders being set from the saved weights: not a move)
local forgotten = false
local NOW_ROWS, ROW_H, MAX_ROWS = 4, 40, 50
local GOAL_ORDER = { "own", "mount", "epic" }

local function Amount(idea)
    if idea.oneOff == true then return format(ns:Tr("%s in about %s"), ns:Coins(idea.total), ns.GoldTimeText(idea.minutes)) end
    return format(ns:Tr("%s an hour"), ns:Coins(idea.perHour))
end
local function Words(idea, today, withGoal)
    local t = ns.GoldEaseWord(idea.ease) .. " · " .. ns.GoldSafetyWord(idea.safetyNow or idea.safety) .. " · " .. ns.GoldFreshText(idea, today)
    if withGoal and idea.toGoal then t = t .. format(ns:Tr(" · goal in %s"), ns.GoldTimeText(idea.toGoal)) end
    return t
end
local function OpenDetail(idea)
    if type(idea) ~= "table" then return end
    local lines = {}
    if type(idea.detail) == "table" then lines = idea.detail
    elseif type(idea.tip) == "table" then for _, t in ipairs(idea.tip) do lines[#lines + 1] = { left = tostring(t) } end end
    ns:ShowList("GoldDetail", idea.title, lines, ns.GoldFreshText(idea), nil, nil, { rawTitle = true, rawNote = true })
end
local function RowTip(row)
    local idea = row.suiIdea
    if type(idea) ~= "table" then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(ns:AccentHex() .. idea.title .. "|r")
    GameTooltip:AddLine(Amount(idea), 1, 1, 1)
    GameTooltip:AddLine(Words(idea, ns.Today(), false), 0.7, 0.7, 0.7, true)
    for _, t in ipairs(type(idea.tip) == "table" and idea.tip or {}) do GameTooltip:AddLine(tostring(t), 1, 1, 1, true) end
    GameTooltip:Show()
end
local function Wire(row)
    row:SetScript("OnClick", ns:Guard("Gold", function(self) OpenDetail(self.suiIdea) end))
    row:SetScript("OnEnter", ns:Guard("Gold", RowTip))
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture(ns.FLAT)
    hl:SetVertexColor(1, 1, 1, 0.05)
end
local function GoButton(row)
    local go = ns:CreateButton(row, "Go", 44, 20, function() ns.GoldGo(row.suiIdea) end)
    go:SetPoint("RIGHT", -4, 0)
    return go
end
local function HasSteps(idea) return type(idea) == "table" and ((type(idea.steps) == "table" and #idea.steps > 0) or type(idea.go) == "function") end

local function ListRow(i)
    local r = W.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, W.sheet)
    r:SetSize(556, ROW_H)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    r.title = Painted(ns:NewText(r, 12, "LEFT"))
    r.title:SetPoint("TOPLEFT", 4, -5)
    r.title:SetWidth(320)
    r.amount = Painted(ns:NewText(r, 12, "RIGHT"))
    r.amount:SetPoint("TOPRIGHT", -54, -5)
    r.amount:SetWidth(176)
    r.sub = Painted(ns:NewText(r, 10, "LEFT"), "faint")
    r.sub:SetPoint("TOPLEFT", 4, -23)
    r.sub:SetWidth(496)
    r.go = GoButton(r)
    Wire(r)
    W.rows[i] = r
    return r
end
-- A row: an idea, or a line of text (idea nil). Returns the text drawn, for the tests.
local function FillRow(r, idea, text, sub, amount)
    r.suiIdea = idea
    r.title:SetText(text or "")
    r.amount:SetText(amount or "")
    if r.sub then r.sub:SetText(sub or "") end
    if r.words then r.words:SetText(sub or "") end
    Shown(r.go, HasSteps(idea))
    Shown(r, true)
    local parts = { text or "" }
    if sub and sub ~= "" then parts[#parts + 1] = sub end
    if amount and amount ~= "" then parts[#parts + 1] = amount end
    return table.concat(parts, "  ")
end

local function ForWindow(ideas)
    local out = {}
    for _, idea in ipairs(ideas or {}) do if idea.where ~= "auction" then out[#out + 1] = idea end end
    return out
end
local function GoldText(copper)
    if type(copper) ~= "number" then return "" end
    if copper % 10000 == 0 then return tostring(copper / 10000) end
    return format("%.2f", copper / 10000)
end
local function Money()
    local m = Ask(GetMoney)
    return type(m) == "number" and m or 0
end

local function Draw()
    if not W then return end
    if not Unlocked() then Shown(W, false); return end       -- (locked again since it opened)
    local today = ns.Today()
    local drawn = { now = {}, ranked = {} }
    -- the mix
    local g, e, s = ns.GoldWeights()
    syncing = true
    W.sliders.gold:SetValue(g); W.sliders.ease:SetValue(e); W.sliders.safety:SetValue(s)
    syncing = false
    drawn.preset = ns:Tr(ns.GOLD_PRESET_NAMES[ns.GoldPresetOf(g, e, s)])
    W.presetButton.text:SetText(drawn.preset)
    -- the goal
    local goal, goalName = ns.GoldGoal()
    local money = Money()
    local left = goal and (goal - money) or nil
    local named = goalName and ns.GOLD_GOALS[goalName]
    drawn.goalName = ns:Tr(named and named.name or "Your own amount")
    W.goalCycle.text:SetText(drawn.goalName)
    if not ns.Yes(W.goalBox:HasFocus()) then W.goalBox:SetText(GoldText(goal)) end
    local r = ns.GoldRank(ForWindow(win.ideas), { g, e, s }, (left and left > 0) and left or nil, today)
    if goal then
        local frac = (left <= 0 or goal <= 0) and 1 or max(0, min(1, money / goal))
        W.bar:SetValue(frac)
        Shown(W.bar, true)
        drawn.bar = frac
        if left <= 0 then drawn.goal = ns:Tr("Goal reached")
        else
            drawn.goal = format(ns:Tr("%s of %s"), ns:Coins(money), ns:Coins(goal))
            local top = r.merged and r.merged[1]
            if top then drawn.goal = drawn.goal .. "  " .. format(ns:Tr("about %s with the top idea"), ns.GoldTimeText(top.toGoal)) end
        end
        W.goalText:SetText(drawn.goal)
    else
        Shown(W.bar, false)
        W.goalText:SetText("")
    end
    -- "Right now"
    local nowList = r.merged and {} or r.now
    if win.waiting or win.ideas == nil then nowList = {} end
    for i = 1, NOW_ROWS do
        local row, idea = W.nowRows[i], nowList[i]
        if idea then drawn.now[i] = FillRow(row, idea, idea.title, Words(idea, today, false), Amount(idea))
        elseif i == 1 then
            local text = (win.waiting or win.ideas == nil) and "" or r.merged and ns:Tr("With a goal, everything is in one list below, by time to it.") or ns:Tr("Nothing right now.")
            local shown = FillRow(row, nil, text)
            if text ~= "" then drawn.now[1] = shown end
        else row.suiIdea = nil; Shown(row, false) end
    end
    W.suiMore = nowList
    if #nowList > NOW_ROWS then
        drawn.more = format(ns:Tr("%d more"), #nowList - NOW_ROWS)
        W.more.text:SetText(drawn.more)
        Shown(W.more, true)
    else Shown(W.more, false) end
    -- the list
    local list = r.merged or r.ranked
    local message
    if win.waiting then message = ns:Tr("Waiting for the fight to end.")
    elseif win.ideas == nil then message = ns:Tr("Looking for ways to make gold...")
    elseif #list == 0 then message = ns:Tr("No ideas yet. Scan prices at the auction house, farm or gather a while, or open your professions, and ideas show up here.") end
    local n = 0
    if message then
        n = 1
        drawn.ranked[1] = FillRow(ListRow(1), nil, message)
    else
        for i = 1, min(#list, MAX_ROWS) do
            local idea = list[i]
            drawn.ranked[i] = FillRow(ListRow(i), idea, idea.title, Words(idea, today, r.merged ~= nil), Amount(idea))
            n = i
        end
    end
    for i = n + 1, #W.rows do W.rows[i].suiIdea = nil; Shown(W.rows[i], false) end
    W.area:SetContentHeight(n * ROW_H)
    W.footer:SetText(ns.PriceFreshText(ns.PriceHouse(), Ask(time)))
    win.drawn.now, win.drawn.ranked, win.drawn.preset = drawn.now, drawn.ranked, drawn.preset
    win.drawn.goal, win.drawn.bar, win.drawn.goalName, win.drawn.more = drawn.goal, drawn.bar, drawn.goalName, drawn.more
end

-- (drawn on the next frame, guarded: an error is noted, never handed to the game)
-- (plain wrappers first: a call scheduled before a lock does nothing after it, and is never timed)
local GuardedDraw = ns:Guard("Gold", function() Draw() end)
local function DrawLater() if Unlocked() then GuardedDraw() end end
local CollectWindow
local GuardedCollect = ns:Guard("Gold", function() CollectWindow() end)
local function CollectLater() if Unlocked() then GuardedCollect() end end
function CollectWindow()
    if not W or not Unlocked() then return end
    win.waiting = InFight()
    local queued = ns.GoldCollect(ns.GoldContext("window"), function(ideas)
        win.ideas, win.waiting = ideas, false                 -- (drawn on the next frame, outside the job's slice)
        ns:After(0, DrawLater)
        if win.again then win.again = false; ns:After(0, CollectLater) end
    end)
    if not queued then win.again = true end
    Draw()
end

local function ShowMoreNow()
    if not W then return end
    local lines, today = {}, ns.Today()
    for i = NOW_ROWS + 1, #(W.suiMore or {}) do
        local idea = W.suiMore[i]
        lines[#lines + 1] = { left = idea.title, right = Amount(idea), tip = { idea.title, Words(idea, today, false) }, click = function() OpenDetail(idea) end }
    end
    ns:ShowList("GoldNow", "Right now", lines)
end
local function CyclePreset()
    if not W then return end                                  -- (a window let go of: its buttons do nothing)
    local cur, nextKey = ns.GoldPresetOf(ns.GoldWeights()), "most"
    local order = ns.GOLD_PRESET_ORDER
    for i, key in ipairs(order) do if key == cur then nextKey = order[i % #order + 1] end end
    ns.GoldSetPreset(nextKey)
    Draw()
end
local function CycleGoal()
    if not W then return end                                  -- (a window let go of: its buttons do nothing)
    local goal, name = ns.GoldGoal()
    local cur, nextKey = name or "own", "own"
    for i, key in ipairs(GOAL_ORDER) do if key == cur then nextKey = GOAL_ORDER[i % #GOAL_ORDER + 1] end end
    if nextKey == "own" then ns.GoldSetGoal(goal, nil) else ns.GoldSetGoal(ns.GoldGoalAmount(nextKey), nextKey) end
    if W then W.goalBox:SetText(GoldText((ns.GoldGoal()))) end
    Draw()
end
-- The amount typed into "Save for:", in gold. Empty: no goal.
local function Typed(text)
    if not W then return end                                  -- (a window let go of: its buttons do nothing)
    if Secret(text) or type(text) ~= "string" then return end
    text = text:gsub("%s", ""):gsub(",", ".")
    if text == "" then ns.GoldSetGoal(nil); Draw(); return end
    local n = tonumber(text)
    if not n or n ~= n or n < 0 or n == huge then return end
    ns.GoldSetGoal(floor(n * 10000 + 0.5), nil)
    Draw()
end

local function Build()
    if W then return W end
    local f = CreateFrame("Frame", "FantasyGlassUIGold", UIParent, ns.template)
    ns:SetLook(f, "settings")
    f:SetSize(600, 640)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop(ns.BACKDROP)
    ns:Paint(f, "SetBackdropColor", "window", 1)
    ns:Paint(f, "SetBackdropBorderColor", "@rim", 1)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    ns:KeepPlace(f, "Gold")
    local listed = false
    for _, name in ipairs(UISpecialFrames) do if name == "FantasyGlassUIGold" then listed = true end end
    if not listed then tinsert(UISpecialFrames, "FantasyGlassUIGold") end
    if ns.After then ns:After(0, function() if ns.StarcutWindow then pcall(ns.StarcutWindow, f) end end) end   -- (the Starcut corner cut, as the settings window)
    f:SetScript("OnHide", function(self) self.suiGoldOn = false end)
    W = f
    ns.goldWindow = f
    -- the header
    local title = Painted(ns:NewText(f, 16, "LEFT", true))
    title:SetPoint("TOPLEFT", 18, -18)
    title:SetText(ns:Tr("Ways to make gold"))
    local close = ns:CreateButton(f, "X", 28, 28, function() f:Hide() end)
    close:SetPoint("TOPRIGHT", -16, -16)
    f.refresh = ns:CreateButton(f, "Refresh", 80, 24, function() ns:GoldRefresh() end)
    f.refresh:SetPoint("RIGHT", close, "LEFT", -8, 0)
    local function Heading(text, y)
        local h = Painted(ns:NewText(f, 13, "LEFT", true))
        h:SetPoint("TOPLEFT", 18, y)
        h:SetText(ns:Tr(text))
        return h
    end
    -- "Right now"
    Heading("Right now", -64)
    f.more = ns:CreateButton(f, "", 90, 18, function() ShowMoreNow() end)
    f.more:SetPoint("TOPRIGHT", -18, -62)
    Shown(f.more, false)
    f.nowRows = {}
    for i = 1, NOW_ROWS do
        local r = CreateFrame("Button", nil, f)
        r:SetSize(564, 22)
        r:SetPoint("TOPLEFT", 18, -84 - (i - 1) * 22)
        r.title = Painted(ns:NewText(r, 12, "LEFT"))
        r.title:SetPoint("LEFT", 4, 0)
        r.title:SetWidth(210)
        r.words = Painted(ns:NewText(r, 10, "LEFT"), "faint")
        r.words:SetPoint("LEFT", 220, 0)
        r.words:SetWidth(180)
        r.amount = Painted(ns:NewText(r, 12, "RIGHT"))
        r.amount:SetPoint("RIGHT", -54, 0)
        r.amount:SetWidth(110)
        r.go = GoButton(r)
        Wire(r)
        f.nowRows[i] = r
    end
    -- the mix: a preset and three sliders
    f.presetButton = ns:CreateButton(f, "", 130, 24, CyclePreset)
    f.presetButton:SetPoint("TOPLEFT", 18, -192)
    f.sliders = {}
    local g, e, s = ns.GoldWeights()
    for i, def in ipairs({ { "gold", "Gold an hour", g }, { "ease", "Ease", e }, { "safety", "Safety", s } }) do
        local which = def[1]
        local c = ns:CreateSlider(f, def[2], 0, 100, 10, def[3], "%d", function(v)
            if syncing or not W then return end
            ns.GoldSetWeight(which, v)
            Draw()
        end, 130)
        c:SetPoint("TOPLEFT", 150 + (i - 1) * 140, -186)
        f.sliders[which] = c
    end
    -- the goal
    local save = Painted(ns:NewText(f, 12, "LEFT"))
    save:SetPoint("TOPLEFT", 18, -241)
    save:SetText(ns:Tr("Save for:"))
    f.goalBox = ns:CreateEditBox(f, 90, 22)
    f.goalBox:SetPoint("TOPLEFT", 84, -236)
    f.goalBox:HookScript("OnTextChanged", ns:Guard("Gold", function(self, user) if user then Typed(self:GetText()) end end))
    local unit = ns:NewText(f, 12, "LEFT")
    unit:SetPoint("LEFT", f.goalBox, "RIGHT", 4, 0)
    unit:SetText("|cffffd700g|r")
    f.goalCycle = ns:CreateButton(f, "", 130, 24, CycleGoal)
    f.goalCycle:SetPoint("TOPLEFT", 196, -235)
    f.bar = ns:NewStatusBar(f)
    f.bar:SetSize(200, 10)
    f.bar:SetPoint("TOPLEFT", 340, -238)
    ns:Paint(f.bar, "SetStatusBarColor", "@accent")
    f.goalText = Painted(ns:NewText(f, 10, "LEFT"), "dim")
    f.goalText:SetPoint("TOPLEFT", 340, -254)
    f.goalText:SetWidth(240)
    -- the list
    Heading("Ways to make gold now", -286)
    f.area, f.sheet = ns:ScrollArea(f, 556, 640 - 306 - 40)
    f.area:SetPoint("TOPLEFT", 18, -306)
    f.rows = {}
    for i = 1, MAX_ROWS do ListRow(i); Shown(f.rows[i], false) end   -- (all made now, never inside a job's slice)
    f.footer = Painted(ns:NewText(f, 10, "LEFT"), "faint")
    f.footer:SetPoint("BOTTOMLEFT", 18, 14)
    -- collect again 2 s after the bags or the money last changed, while it is open
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "BAG_UPDATE_DELAYED")
    pcall(ev.RegisterEvent, ev, "PLAYER_MONEY")
    ev:SetScript("OnEvent", function(_, event)                -- (plain: cheap, and never timed by /fgui perf)
        if (event ~= "BAG_UPDATE_DELAYED" and event ~= "PLAYER_MONEY") or not f.suiGoldOn or W ~= f or not Unlocked() then return end
        win.gen = win.gen + 1
        local mine = win.gen
        ns:After(2, function() if mine == win.gen and f.suiGoldOn and W == f then CollectLater() end end)
    end)
    Start()
    return f
end

-- Open the window (nil while the guide is locked) and collect.
function ns:GoldOpen()
    if not Unlocked() then return nil end
    Build()
    Shown(W, true)
    ns.goldOpens = (ns.goldOpens or 0) + 1
    if not forgotten then forgotten = true; ns.GoldJob(ForgetOld, "forget") end
    CollectWindow()
    return W
end
-- Collect again (Refresh).
function ns:GoldRefresh()
    if W and Unlocked() then CollectWindow() end
end

------------------------------------------------------------------------------------------
-- The auction house panel: the ideas that live there
------------------------------------------------------------------------------------------
local P
local panel = { ideas = nil, scanAt = nil, acc = 0, again = false, drawn = {} }
local PANEL_ROWS, PANEL_ROW_H = 10, 34

local function ScanAt()
    local h = ns.PriceHouse()
    local at = type(h) == "table" and h.scanAt or nil
    if Secret(at) or type(at) ~= "number" then return nil end
    return at
end
local function DrawPanel()
    if not P then return end
    local list = {}
    for _, idea in ipairs(panel.ideas or {}) do if idea.where == "auction" or idea.where == "both" then list[#list + 1] = idea end end
    local r = ns.GoldRank(list, { ns.GoldWeights() }, nil, ns.Today())
    local perHour = {}
    for _, idea in ipairs(r.ranked) do perHour[#perHour + 1] = idea end
    table.sort(perHour, function(a, b) if a.perHour ~= b.perHour then return a.perHour > b.perHour end return tostring(a.id) < tostring(b.id) end)
    list = r.now
    for _, idea in ipairs(perHour) do list[#list + 1] = idea end
    local drawn = {}
    for i = 1, PANEL_ROWS do
        local row, idea = P.rows[i], list[i]
        row.suiIdea = idea
        if idea then
            local words = Words(idea, ns.Today(), false)
            row.title:SetText(idea.title)
            row.amount:SetText(Amount(idea))
            row.sub:SetText(words)
            drawn[i] = idea.title .. "  " .. words .. "  " .. Amount(idea)
            Shown(row, true)
        elseif i == 1 then
            local text = (panel.ideas == nil) and ns:Tr("Looking for ways to make gold...") or ns:Tr("Nothing to do here right now.")
            row.title:SetText(text)
            row.amount:SetText("")
            row.sub:SetText("")
            drawn[1] = text
            Shown(row, true)
        else Shown(row, false) end
    end
    P.footer:SetText(ns.PriceFreshText(ns.PriceHouse(), Ask(time)))
    panel.drawn = drawn
end
local GuardedDrawPanel = ns:Guard("Gold", function() DrawPanel() end)
local function DrawPanelLater() if Unlocked() then GuardedDrawPanel() end end
local CollectPanel
local GuardedCollectPanel = ns:Guard("Gold", function() CollectPanel() end)
local function CollectPanelLater() if Unlocked() then GuardedCollectPanel() end end
function CollectPanel()
    if not Unlocked() then return end
    local queued = ns.GoldCollect(ns.GoldContext("auction"), function(ideas)
        panel.ideas = ideas                                    -- (drawn on the next frame, outside the job's slice)
        ns:After(0, DrawPanelLater)
        if panel.again then panel.again = false; ns:After(0, CollectPanelLater) end
    end)
    if not queued then panel.again = true; return end
    DrawPanel()
end
local function BuildPanel()
    if P then return P end
    local ahf = _G.AuctionHouseFrame
    if type(ahf) ~= "table" then return nil end
    local f = CreateFrame("Frame", "FantasyGlassUIGoldAH", ahf, ns.template)
    ns:SetLook(f, "settings")
    f:SetSize(280, 440)
    f:SetPoint("TOPLEFT", ahf, "TOPRIGHT", 6, 0)
    f:SetBackdrop(ns.BACKDROP)
    ns:Paint(f, "SetBackdropColor", "window", 1)
    ns:Paint(f, "SetBackdropBorderColor", "@rim", 1)
    f:EnableMouse(true)
    if ns.After then ns:After(0, function() if ns.StarcutWindow then pcall(ns.StarcutWindow, f) end end) end   -- (the Starcut corner cut, as the settings window)
    P = f
    ns.goldPanel = f
    local title = Painted(ns:NewText(f, 14, "LEFT", true))
    title:SetPoint("TOPLEFT", 14, -14)
    title:SetText(ns:Tr("Gold ideas here"))
    f.rows = {}
    for i = 1, PANEL_ROWS do
        local r = CreateFrame("Button", nil, f)
        r:SetSize(252, PANEL_ROW_H)
        r:SetPoint("TOPLEFT", 14, -42 - (i - 1) * PANEL_ROW_H)
        r.amount = Painted(ns:NewText(r, 11, "RIGHT"))
        r.amount:SetPoint("TOPRIGHT", -2, -4)
        r.title = Painted(ns:NewText(r, 11, "LEFT"))
        r.title:SetPoint("TOPLEFT", 2, -4)
        r.title:SetPoint("RIGHT", r.amount, "LEFT", -6, 0)
        r.sub = Painted(ns:NewText(r, 9, "LEFT"), "faint")         -- (ease · how sure · how fresh, as the window's rows)
        r.sub:SetPoint("TOPLEFT", 2, -19)
        r.sub:SetWidth(248)
        Wire(r)
        f.rows[i] = r
    end
    f.footer = Painted(ns:NewText(f, 10, "LEFT"), "faint")
    f.footer:SetPoint("BOTTOMLEFT", 14, 12)
    -- a new scan: collect again (looked at every 5 s while it is open)
    local guardedTick = ns:Guard("Gold", function(self, elapsed)
        if self ~= P then return end                           -- (a panel let go of)
        panel.acc = panel.acc + (tonumber(elapsed) or 0)
        if panel.acc < 5 then return end
        panel.acc = 0
        local at = ScanAt()
        if at ~= panel.scanAt then panel.scanAt = at; CollectPanel() end
    end)
    f:SetScript("OnUpdate", function(self, elapsed)            -- (plain first: locked again, it hides untimed)
        if not Unlocked() then Shown(self, false); return end
        guardedTick(self, elapsed)
    end)
    Start()
    return f
end
-- Show the panel on the open auction house and collect (nil while locked, or with no auction house).
function ns:GoldAuctionShow()
    if not Unlocked() then return nil end
    if not BuildPanel() then return nil end
    Shown(P, true)
    panel.acc, panel.scanAt = 0, ScanAt()
    CollectPanel()
    return P
end

-- Locked again: the window and the panel hide (the tick calls this, and then stops).
function ns.GoldLockedNow()
    if W and W.suiGoldOn then Shown(W, false) end
    if P and P.suiGoldOn then Shown(P, false) end
end

-- For the tests: let the window and the panel go, as at login (their frames stay, unused).
ns.goldTest = {
    Reset = function()
        if W then Shown(W, false) end
        if P then Shown(P, false) end
        W, P, ns.goldWindow, ns.goldPanel, ns.goldOpens = nil, nil, nil, nil, nil
        win.ideas, win.waiting, win.again, win.drawn = nil, false, false, { now = {}, ranked = {} }
        panel.ideas, panel.scanAt, panel.acc, panel.again, panel.drawn = nil, nil, 0, false, {}
        forgotten = false
    end,
}
-- The texts drawn, for the tests.
function ns.GoldWindowLines()
    local d = win.drawn
    return { now = d.now, ranked = d.ranked, preset = d.preset, goal = d.goal, bar = d.bar, goalName = d.goalName, more = d.more, auction = panel.drawn }
end

------------------------------------------------------------------------------------------
-- entry points (stay in the main add-on when the folder moves)
-- Each does nothing while the guide is locked: the launcher's tooltip line and Ctrl-click, the guide
-- panel's Gold button, /fgui guide gold, and the auction house panel.
------------------------------------------------------------------------------------------
do
    local prevTip, prevClick = ns.LauncherTipExtra, ns.LauncherClickExtra
    function ns.LauncherTipExtra(tooltip)
        if prevTip then prevTip(tooltip) end
        if Unlocked() and type(tooltip) == "table" and tooltip.AddLine then tooltip:AddLine(ns:Tr("Ctrl-click: ways to make gold"), 1, 1, 1) end
    end
    function ns.LauncherClickExtra(button)
        if prevClick and prevClick(button) then return true end
        if not Unlocked() then return false end
        if not (IsControlKeyDown and ns.Yes(IsControlKeyDown())) then return false end
        ns:GoldOpen()
        return true
    end

    local GuidePanel, GuideCmd = ns.GuideShowPanel, ns.GuideCommand
    if type(GuidePanel) == "function" then
        function ns:GuideShowPanel(...)
            local p = GuidePanel(self, ...)
            if type(p) == "table" and Unlocked() then
                local b = p.suiGoldButton
                if not b then
                    b = ns:CreateButton(p, "Gold", 48, 18, function() ns:GoldOpen() end)
                    b:SetPoint("BOTTOMRIGHT", -76, 6)
                    p.suiGoldButton = b
                end
                Shown(b, true)
            elseif type(p) == "table" and p.suiGoldButton then
                Shown(p.suiGoldButton, false)
            end
            return p
        end
    end
    if type(GuideCmd) == "function" then
        function ns:GuideCommand(text, ...)
            if Unlocked() and type(text) == "string" and not Secret(text) and ns.Trim(text):lower() == "gold" then
                ns:GoldOpen()
                return true
            end
            return GuideCmd(self, text, ...)
        end
    end

    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "AUCTION_HOUSE_SHOW")
    pcall(ev.RegisterEvent, ev, "AUCTION_HOUSE_CLOSED")
    -- (a plain handler: while locked it returns at once, so nothing named Gold is timed by /fgui perf)
    local guarded
    ev:SetScript("OnEvent", function(_, event)
        if event ~= "AUCTION_HOUSE_SHOW" and event ~= "AUCTION_HOUSE_CLOSED" then return end
        -- (only ns.goldPanel and plain frame calls here: this block stays in the main add-on when the folder moves)
        local p = ns.goldPanel
        if not Unlocked() then
            if type(p) == "table" and event == "AUCTION_HOUSE_CLOSED" then p.suiGoldOn = false; p:Hide() end
            return
        end
        guarded = guarded or ns:Guard("Gold", function(e)
            local panelNow = ns.goldPanel
            if e == "AUCTION_HOUSE_SHOW" then ns:GoldAuctionShow()
            elseif type(panelNow) == "table" then panelNow.suiGoldOn = false; panelNow:Hide() end
        end)
        guarded(event)
    end)
end
