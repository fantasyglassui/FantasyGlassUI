local _, ns = ...

------------------------------------------------------------------------------------------
-- The gold advisor's recorders, in the main add-on (the folders plan, Task 5): the job runner they queue their
-- work on, merchant prices, monster loot, what gathering gave, the node fold and the recipes you know. They are
-- here, not in the FantasyGlassUI_Gold folder, so nothing goes deaf while that folder is not loaded. Each part
-- is its file's "recorders" block, moved without change (saved data, keys and Guard labels as before), in a
-- do ... end of its own with the small helpers it used there. As before, each records nothing while the guide
-- is locked, and a locked player's events return at once, so nothing named Gold is timed by /fgui perf.
------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------
-- From Gold.lua: the job runner (jobs, slices, the fight flag), what an item is worth, the vendor reader
------------------------------------------------------------------------------------------
do
local Secret = function(v) return ns:IsSecret(v) end
local floor, huge = math.floor, math.huge

ns.GOLD_BUDGET_MS = 4

------------------------------------------------------------------------------------------
-- recorders (light; may stay in the main add-on when the folder moves)
-- The core keeps none: the merchant, loot, gathering and recipe recorders are in the groups' files.
-- The only thing watched here is whether a fight is on, and only once a job has been queued.
------------------------------------------------------------------------------------------
local fighting = false

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
-- For the gold folder: is a fight on (the flag or the lockdown), and keep the tick going (a lock then hides
-- the window and the panel).
function ns.GoldInFight() return InFight() end
function ns.GoldTickOn() Start() end

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
end

------------------------------------------------------------------------------------------
-- From GoldSell.lua: what a merchant asks -> ns.root.goldVendor
------------------------------------------------------------------------------------------
do
local Secret = function(v) return ns:IsSecret(v) end
local floor, max, min, huge = math.floor, math.max, math.min, math.huge
local VENDOR_CAP = 3000                -- vendor prices kept; the oldest go first

local function Unlocked() return ns.GuideUnlocked ~= nil and ns:GuideUnlocked() == true end
local function Num(v)
    if Secret(v) or type(v) ~= "number" or v ~= v or v == huge or v == -huge then return nil end
    return v
end

------------------------------------------------------------------------------------------
-- recorders (light; may stay in the main add-on when the folder moves)
-- What a merchant asks, read half a second after the merchant window opens or changes.
------------------------------------------------------------------------------------------
local function Store(create)
    local root = ns.root
    if type(root) ~= "table" then return nil end
    local s = root.goldVendor
    if type(s) ~= "table" or type(s.items) ~= "table" then
        if not create then return nil end
        s = { v = 1, items = {} }
        root.goldVendor = s
    end
    return s.items
end

-- Keep what a merchant asks for item `id` (info from C_MerchantFrame.GetItemInfo). True when kept,
-- and whether the item is new to the store.
function ns.GoldVendorNote(id, info, today)
    if Num(id) == nil or type(info) ~= "table" then return false end
    local price, stack, avail = info.price, info.stackCount, info.numAvailable
    local ext, hasExt = info.extendedCost, info.hasExtendedCost   -- (either spelling: the dump does not name the fields)
    if Secret(price) or Secret(stack) or Secret(avail) or Secret(ext) or Secret(hasExt) then return false end
    if ext or hasExt then return false end                        -- (tokens or honour: no copper price)
    price, stack, avail = Num(price), Num(stack), Num(avail)
    if not price or price <= 0 then return false end
    stack = max(1, floor(stack or 1))
    local buy = floor(price / stack)
    if buy <= 0 then return false end
    local items = Store(true)
    if not items then return false end
    local fresh = items[id] == nil
    items[id] = { buy = buy, stack = stack, limited = (avail and avail >= 0) and floor(avail) or nil, day = Num(today) or ns.Today() }
    return true, fresh
end

-- Over the cap: the oldest days go first (a job: it walks the whole store).
local function Trim()
    local items = Store(false)
    if not items then return end
    local keys = {}
    for k in pairs(items) do keys[#keys + 1] = k end              -- (the keys first: the store may change between slices)
    local over = #keys - VENDOR_CAP
    if over <= 0 then return end
    local function Day(e) return type(e) == "table" and Num(e.day) or 0 end
    local perDay = {}
    for _, k in ipairs(keys) do
        local d = Day(items[k])
        perDay[d] = (perDay[d] or 0) + 1
        ns.GoldYield()
    end
    local days = {}
    for d in pairs(perDay) do days[#days + 1] = d end
    table.sort(days)
    local cut, extra = 0, 0                                       -- every day before `cut` goes, and `extra` from that day
    for _, d in ipairs(days) do
        if perDay[d] >= over then cut, extra = d, over; break end
        over = over - perDay[d]
    end
    for _, k in ipairs(keys) do
        local e = items[k]
        if e ~= nil then
            local d = Day(e)
            if d < cut then items[k] = nil
            elseif d == cut and extra > 0 then items[k] = nil; extra = extra - 1 end
        end
        ns.GoldYield()
    end
end

-- Does this slot cost anything besides copper (tokens, honour, items)?
local function CostsMore(i)
    if type(GetMerchantItemCostInfo) ~= "function" then return false end
    local ok, n = pcall(GetMerchantItemCostInfo, i)
    if not ok then return false end
    n = Num(n)
    return n ~= nil and n > 0
end

local function InFight()
    local ok, v = pcall(InCombatLockdown)
    return ok and ns.Yes(v)
end

-- One merchant's list, as a job (a slot a step; jobs never run in a fight).
local again = false
local function Record()
    ns.goldVendorPasses = (ns.goldVendorPasses or 0) + 1
    local M = C_MerchantFrame
    if type(M) ~= "table" or type(M.GetItemInfo) ~= "function" or type(GetMerchantNumItems) ~= "function" or type(GetMerchantItemID) ~= "function" then return end
    local ok, n = pcall(GetMerchantNumItems)
    n = ok and Num(n) or 0
    local today, added = ns.Today(), false
    for i = 1, min(n, 500) do
        local okId, id = pcall(GetMerchantItemID, i)
        local okInfo, info = pcall(M.GetItemInfo, i)
        if okId and okInfo and not CostsMore(i) then
            local kept, fresh = ns.GoldVendorNote(id, info, today)
            if kept and fresh then added = true end
        end
        ns.GoldYield()
    end
    if added then ns.GoldJob(Trim, "goldVendorTrim") end
end

local Queue
local function RecordJob()
    Record()
    if again then again = false; ns:After(0, Queue) end            -- (the merchant changed while this one ran)
end
function Queue()
    if not Unlocked() or InFight() then return end
    if not ns.GoldJob(RecordJob, "goldVendorRecord") then again = true end
end

do
    local gen = 0
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "MERCHANT_SHOW")
    pcall(ev.RegisterEvent, ev, "MERCHANT_UPDATE")
    -- (a plain handler first: while locked it returns at once, so nothing named Gold is timed by /fgui perf)
    local guarded = ns:Guard("Gold", function(_, event)
        if (event ~= "MERCHANT_SHOW" and event ~= "MERCHANT_UPDATE") or not Unlocked() then return end
        gen = gen + 1
        local mine = gen
        ns:After(0.5, function() if mine == gen then Queue() end end)
    end)
    ev:SetScript("OnEvent", function(...) if Unlocked() then guarded(...) end end)
end
end

------------------------------------------------------------------------------------------
-- From GoldFarm.lua: monster loot -> ns.root.goldMobs, and the pace in ns.root.goldChars
------------------------------------------------------------------------------------------
do
local floor, max, huge = math.floor, math.max, math.huge
local MOB_CAP, ITEM_CAP = 400, 12          -- monsters kept, items kept per monster (the most looted)
local PACE_GAP, PACE_CAP = 120, 400
local RECENT = 30                          -- corpses remembered, so opening one again is not a second loot

local function Secret(v) return ns:IsSecret(v) end
-- A plain finite number, or nil (hidden values are nil).
local function Num(v)
    if Secret(v) or type(v) ~= "number" or v ~= v or v == huge or v == -huge then return nil end
    return v
end
local function Str(v)
    if Secret(v) or type(v) ~= "string" or v == "" then return nil end
    return v
end
-- The first answer of a game call, through pcall; nil when it fails or is hidden.
local function Ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if ok and not Secret(v) then return v end
    return nil
end
local function Unlocked() return ns.GuideUnlocked ~= nil and ns:GuideUnlocked() == true end
local function Count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
local function ItemOf(link)
    link = Str(link)
    return link and tonumber(link:match("item:(%d+)")) or nil
end
-- The monster's id in a "Creature-0-server-instance-zone-npcID-spawn" guid; nil for any other kind.
local function NpcOf(guid)
    guid = Str(guid)
    if not guid then return nil end
    return tonumber(guid:match("^Creature%-[^%-]*%-[^%-]*%-[^%-]*%-[^%-]*%-(%d+)"))
end
-- Where you stand: { map, x, y } with x and y 0..100 to one decimal, or nil.
local function Here()
    local map = Num(Ask(C_Map and C_Map.GetBestMapForUnit, "player"))
    if not map then return nil end
    local here = { map = map }
    local pos = Ask(C_Map.GetPlayerMapPosition, map, "player")
    if type(pos) == "table" and type(pos.GetXY) == "function" then
        local ok, x, y = pcall(pos.GetXY, pos)
        x, y = ok and Num(x), ok and Num(y)
        if x and y and x > 0 and y > 0 then here.x, here.y = floor(x * 1000 + 0.5) / 10, floor(y * 1000 + 0.5) / 10 end
    end
    return here
end
local function CharRecord()
    if type(ns.root) ~= "table" then return nil end
    ns.root.goldChars = type(ns.root.goldChars) == "table" and ns.root.goldChars or {}
    local key = ns:CharKey()
    local rec = ns.root.goldChars[key]
    if type(rec) ~= "table" then rec = {}; ns.root.goldChars[key] = rec end
    return rec
end

------------------------------------------------------------------------------------------
-- recorders (light; may stay in the main add-on when the folder moves)
-- LOOT_OPENED: each creature in the window is one loot of its kind, with what it gave. Coin is what
-- the money slot says each creature gave; failing that, with one creature in the window, your purse
-- at LOOT_CLOSED less your purse at LOOT_OPENED. Solo only (in a group, rolls and split coin are not
-- yours), never a window that follows Pick Pocket or a gathering cast, and never a living target.
------------------------------------------------------------------------------------------
-- Casts whose loot window is not a kill: Pick Pocket here, and every gathering spell (skinning, herbs,
-- ore), which the planner's one skill function names: ns.PlannerGatherSkill (read when the cast comes).
local NOT_A_KILL = { [921] = true }
local CAST_WINDOW = 2                      -- seconds after such a cast in which a loot window is its
local castAt                               -- GetTime() of the last such cast

-- The worth of `n` of an item now (0 while its details are not loaded: then only a vendor price counts).
local function Worth(id, n, today)
    local okI, name = pcall(ns.GetItemInfo, ns, id)
    if not (okI and Str(name)) then return 0 end
    return n * ns.GoldItemValue(id, today)
end
-- Add `n` of item `id` to a monster's list. A full list takes a new item only when it is worth more a
-- loot than the least-looted one there; whatever is left out is kept as `other` (copper).
local function AddItem(rec, id, n, today)
    local items = rec.items
    if items[id] then items[id] = items[id] + n; return end
    if Count(items) < ITEM_CAP then items[id] = n; return end
    local low, ln
    for k, c in pairs(items) do
        if not low or c < ln or (c == ln and k > low) then low, ln = k, c end
    end
    local mine, theirs = Worth(id, n, today), Worth(low, ln, today)
    if mine > theirs then
        items[low] = nil
        items[id] = n
        rec.other = (Num(rec.other) or 0) + theirs
    else
        rec.other = (Num(rec.other) or 0) + mine
    end
end
-- Keep MOB_CAP monsters, letting the longest unseen go (a job: it walks the store).
local function TrimMobs()
    local store = type(ns.root) == "table" and ns.root.goldMobs
    if type(store) ~= "table" then return end
    local list = {}
    for id, rec in pairs(store) do
        list[#list + 1] = { id = id, last = type(rec) == "table" and Num(rec.last) or 0 }
        ns.GoldYield()
    end
    if #list <= MOB_CAP then return end
    table.sort(list, function(a, b) if a.last ~= b.last then return a.last < b.last end return tostring(a.id) < tostring(b.id) end)
    for i = 1, #list - MOB_CAP do
        store[list[i].id] = nil
        ns.GoldYield()
    end
end

-- One loot of a monster into ns.root.goldMobs. `now` is the day (yyyymmdd; today when nil).
-- `instance`: looted inside a dungeon or raid (such a monster is never a world farm idea).
function ns.GoldMobNote(npcID, name, level, map, zone, x, y, items, copper, now, instance)
    npcID = Num(npcID)
    if not npcID or npcID <= 0 or type(ns.root) ~= "table" then return false end
    local store = ns.root.goldMobs
    if type(store) ~= "table" then store = {}; ns.root.goldMobs = store end
    local rec = store[npcID]
    local new = type(rec) ~= "table"
    if new then rec = {}; store[npcID] = rec end
    local today = Num(now) or ns.Today()
    rec.name = Str(name) or Str(rec.name)
    rec.level = Num(level) or Num(rec.level)
    rec.map = Num(map) or Num(rec.map)
    rec.zone = Str(zone) or Str(rec.zone)
    if Num(x) and Num(y) then rec.x, rec.y = x, y end
    if instance == true then rec.instance = true end
    rec.loots = (Num(rec.loots) or 0) + 1
    rec.copper = (Num(rec.copper) or 0) + max(0, Num(copper) or 0)
    rec.items = type(rec.items) == "table" and rec.items or {}
    local ids = {}
    for id, n in pairs(type(items) == "table" and items or {}) do
        if Num(id) and Num(n) and n > 0 then ids[#ids + 1] = id end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do AddItem(rec, id, items[id], today) end
    rec.last = today
    if new then ns.GoldJob(TrimMobs, "farm:trim") end
    return true
end

local recent, recentAt = {}, 0             -- the last RECENT corpses looted (ring)
local pending                              -- { npc, money } while a one-creature window waits for its coin
local function Seen(guid)
    for i = 1, RECENT do if recent[i] == guid then return true end end
    return false
end
local function Remember(guid)
    recentAt = recentAt % RECENT + 1
    recent[recentAt] = guid
end
local function Pack(...) return { n = select("#", ...), ... } end
local function Clock() return Num(Ask(GetTime)) end

local function LootOpened()
    if not Unlocked() then return end
    if ns.Yes(Ask(IsInGroup)) then return end                                  -- (solo numbers only)
    local t = Clock()
    if castAt and t and t >= castAt and t - castAt <= CAST_WINDOW then return end  -- (Pick Pocket or gathering)
    local slots = Num(Ask(GetNumLootItems))
    if not slots or slots <= 0 then return end
    local moneyType = Enum and Enum.LootSlotType and Enum.LootSlotType.Money
    local found, order = {}, {}
    for slot = 1, floor(slots) do
        local r = Pack(pcall(GetLootSourceInfo, slot))
        if r[1] == true then
            local id
            local kind = Ask(GetLootSlotType, slot)
            local isMoney = moneyType ~= nil and kind ~= nil and kind == moneyType
            if not isMoney then id = ItemOf(Ask(GetLootSlotLink, slot)) end
            local slotQty
            if id then
                local okQ, _, _, q = pcall(GetLootSlotInfo, slot)
                slotQty = okQ and Num(q) or nil
            end
            local sources = floor((r.n - 1) / 2)
            for i = 2, r.n, 2 do
                local guid = r[i]
                local npc = NpcOf(guid)
                if npc and not Seen(guid) then
                    local src = found[guid]
                    if not src then src = { npc = npc, guid = guid, items = {}, coin = 0 }; found[guid] = src; order[#order + 1] = src end
                    if isMoney then
                        local c = Num(r[i + 1])
                        if c and c > 0 then src.coin, src.gaveCoin = src.coin + c, true end
                    elseif id then
                        local qty = Num(r[i + 1]) or (sources == 1 and slotQty) or 1
                        if qty > 0 then src.items[id] = (src.items[id] or 0) + qty end
                    end
                end
            end
        end
    end
    if #order == 0 then return end
    -- a living target in the window is a pickpocket's or someone else's business, not a kill
    local target = Str(Ask(UnitGUID, "target"))
    if target and found[target] and not ns.Yes(Ask(UnitIsDead, "target")) then return end
    local here = Here() or {}
    local zone = Str(Ask(GetRealZoneText))
    local inside = ns.Yes(Ask(IsInInstance))
    local today = ns.Today()
    local coinRead = false
    for _, src in ipairs(order) do
        local name, level
        if target and target == src.guid then
            name, level = Str(Ask(UnitName, "target")), Num(Ask(UnitLevel, "target"))
        end
        if src.gaveCoin then coinRead = true end
        ns.GoldMobNote(src.npc, name, level, here.map, zone, here.x, here.y, src.items, src.coin, today, inside)
        Remember(src.guid)
    end
    if #order == 1 and not coinRead then
        local money = Num(Ask(GetMoney))
        if money then pending = { npc = order[1].npc, money = money } end
    end
    -- the pace: a loot within PACE_GAP seconds of the last adds the gap (per character)
    local now = Num(Ask(time))
    local rec = now and CharRecord()
    if rec then
        local pace = type(rec.pace) == "table" and rec.pace or { loots = 0, secs = 0 }
        rec.pace = pace
        local last = Num(pace.last)
        if last and now >= last and now - last <= PACE_GAP then
            pace.loots = (Num(pace.loots) or 0) + #order
            pace.secs = (Num(pace.secs) or 0) + (now - last)
            if pace.loots > PACE_CAP then pace.loots, pace.secs = pace.loots / 2, pace.secs / 2 end
        end
        pace.last = now
    end
end
local function LootClosed()
    local p = pending
    pending = nil
    if not p or not Unlocked() then return end
    local money = Num(Ask(GetMoney))
    local rec = money and type(ns.root) == "table" and type(ns.root.goldMobs) == "table" and ns.root.goldMobs[p.npc]
    if type(rec) == "table" and money > p.money then rec.copper = (Num(rec.copper) or 0) + (money - p.money) end
end
local function CastDone(unit, spellID)
    if not Unlocked() or Secret(unit) or unit ~= "player" then return end
    spellID = Num(spellID)
    local gather = spellID and type(ns.PlannerGatherSkill) == "function" and ns.PlannerGatherSkill(spellID)
    if spellID and (NOT_A_KILL[spellID] or gather) then castAt = Clock() end
end

do
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "LOOT_OPENED")
    pcall(ev.RegisterEvent, ev, "LOOT_CLOSED")
    local ok = type(ev.RegisterUnitEvent) == "function" and pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_SUCCEEDED", "player")
    if not ok then pcall(ev.RegisterEvent, ev, "UNIT_SPELLCAST_SUCCEEDED") end
    -- (a plain handler first: while locked it returns at once, so nothing named Gold is timed by /fgui perf)
    local guarded = ns:Guard("Gold loot", function(_, event, a1, _, a3)
        if event == "LOOT_OPENED" then LootOpened()
        elseif event == "LOOT_CLOSED" then LootClosed()
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then CastDone(a1, a3) end
    end)
    ev:SetScript("OnEvent", function(...) if Unlocked() then guarded(...) end end)
end
end

------------------------------------------------------------------------------------------
-- From GoldGather.lua: what gathering gave -> ns.root.goldNodeItems, ns.root.goldGather; the node fold
------------------------------------------------------------------------------------------
do
local type, tonumber, pairs, ipairs = type, tonumber, pairs, ipairs
local floor, min, huge = math.floor, math.min, math.huge
local HERBALISM, MINING, SKINNING = 182, 186, 393
local NAME_CAP = 200                   -- node names whose loot is kept
local LOOT_SECONDS = 5                 -- a loot window this soon after a gathering is that gathering's
local GAP_SECONDS = 300                -- a longer pause between gatherings is not time spent gathering
local PER_GATHER = 30                  -- seconds each gathering counts on top of the walk (the cast, the loot)

local function Num(v) if type(v) == "number" and v == v and v ~= huge and v ~= -huge and not ns:IsSecret(v) then return v end end
local function Clean(s)
    if type(s) ~= "string" or ns:IsSecret(s) then return nil end
    s = ns.Trim((s:gsub("[|@\r\n]", " ")))
    return s ~= "" and s or nil
end
local function Unlocked() return ns.GuideUnlocked ~= nil and ns:GuideUnlocked() == true end
local function Root() return type(ns.root) == "table" and ns.root or nil end

------------------------------------------------------------------------------------------
-- recorders (light; may stay in the main add-on when the folder moves)
------------------------------------------------------------------------------------------
-- The gathering spells are the planner's (ns.PlannerGatherSkill, the one skill function), and so is the one
-- UNIT_SPELLCAST_SENT recorder: it records the node and hands each gathering here.
local function Skill(spellID)
    return type(ns.PlannerGatherSkill) == "function" and ns.PlannerGatherSkill(spellID) or nil
end

local function Ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c
end
-- Where you stand: map, and x, y in percent to one decimal (as the guide tells it); nil when unknown.
local function Here()
    local map = Num((Ask(C_Map and C_Map.GetBestMapForUnit, "player")))
    if not map then return nil end
    local pos = Ask(C_Map.GetPlayerMapPosition, map, "player")
    if type(pos) ~= "table" or ns:IsSecret(pos) then return map end
    local x, y
    if type(pos.GetXY) == "function" then x, y = Ask(pos.GetXY, pos) else x, y = pos.x, pos.y end
    x, y = Num(x), Num(y)
    if not (x and y) or (x == 0 and y == 0) then return map end
    return map, floor(x * 1000 + 0.5) / 10, floor(y * 1000 + 0.5) / 10
end
local function Now() return Num((Ask(GetTime))) end

local pending                          -- the gathering spell being cast: { name, skill }
local gathered                         -- the last gathering that worked: { name, skill, map, at }
local lastAt = {}                      -- map -> GetTime of the last gathering there (this session)

-- A gathering spell is being cast (the planner's UNIT_SPELLCAST_SENT recorder calls this, for herbs, ore and
-- skinning): what UNIT_SPELLCAST_SUCCEEDED and the loot window then count it as.
function ns.GoldGatherSent(name, skill, spellID)
    if not Unlocked() then return end
    if skill ~= HERBALISM and skill ~= MINING and skill ~= SKINNING then return end
    pending = { name = Clean(name), skill = skill }
end

local function ItemID(link)
    if type(link) ~= "string" or ns:IsSecret(link) then return nil end
    return tonumber(link:match("item:(%d+)"))
end

local function NoteLoot(g)
    local root = Root()
    local count = Num((Ask(GetNumLootItems)))
    if not (root and count and count > 0) then return end
    local got = {}
    for slot = 1, min(count, 20) do
        local id = ItemID((Ask(GetLootSlotLink, slot)))
        local _, _, qty = Ask(GetLootSlotInfo, slot)
        qty = Num(qty)
        if id and qty and qty > 0 then got[id] = (got[id] or 0) + qty end
    end
    if not next(got) then return end
    -- what this kind of node gives (herbs and ore; a skinned beast is not a node)
    if g.name and g.skill ~= SKINNING then
        if type(root.goldNodeItems) ~= "table" then root.goldNodeItems = {} end
        local e = root.goldNodeItems[g.name]
        if type(e) ~= "table" then
            local names = 0
            for _ in pairs(root.goldNodeItems) do names = names + 1 end
            if names < NAME_CAP then e = { n = 0, items = {} }; root.goldNodeItems[g.name] = e end
        end
        if type(e) == "table" then
            if type(e.items) ~= "table" then e.items = {} end
            e.n = (tonumber(e.n) or 0) + 1
            for id, q in pairs(got) do e.items[id] = (tonumber(e.items[id]) or 0) + q end
        end
    end
    -- what gathering on this map brings, and for how long
    if g.map then
        if type(root.goldGather) ~= "table" then root.goldGather = {} end
        local m = root.goldGather[g.map]
        if type(m) ~= "table" then m = { secs = 0, n = 0, items = {} }; root.goldGather[g.map] = m end
        if type(m.items) ~= "table" then m.items = {} end
        m.n = (tonumber(m.n) or 0) + 1
        m.secs = (tonumber(m.secs) or 0) + (g.gap or 0) + PER_GATHER
        m.day = ns.Today()
        for id, q in pairs(got) do m.items[id] = (tonumber(m.items[id]) or 0) + q end
    end
end

do
    local ev = CreateFrame("Frame")
    do                                                    -- (the player's casts only; the handler checks the unit too)
        local ok = type(ev.RegisterUnitEvent) == "function" and pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_SUCCEEDED", "player")
        if not ok then pcall(ev.RegisterEvent, ev, "UNIT_SPELLCAST_SUCCEEDED") end
    end
    pcall(ev.RegisterEvent, ev, "LOOT_OPENED")
    -- (a plain handler first: while locked it returns at once, so nothing named Gold is timed by /fgui perf)
    local guarded = ns:Guard("Gold gather", function(_, event, a1, a2, a3, a4)
        if event ~= "UNIT_SPELLCAST_SUCCEEDED" and event ~= "LOOT_OPENED" then return end
        if not Unlocked() then return end
        if event == "LOOT_OPENED" then
            local g = gathered
            gathered = nil
            local now = Now()
            if g and now and now >= g.at and now - g.at <= LOOT_SECONDS then NoteLoot(g) end
            return
        end
        if ns:IsSecret(a1) or a1 ~= "player" then return end
        do                                            -- UNIT_SPELLCAST_SUCCEEDED: unit, castGUID, spellID
            local skill = Skill(a3)
            if not skill then return end
            local now = Now()
            if not now then return end
            local map = Here()
            local p = (pending and pending.skill == skill) and pending or nil
            pending = nil
            local gap = 0
            if map and lastAt[map] and now - lastAt[map] >= 0 and now - lastAt[map] <= GAP_SECONDS then gap = now - lastAt[map] end
            if map then lastAt[map] = now end
            gathered = { name = p and p.name or nil, skill = skill, map = map, at = now, gap = gap }
        end
    end)
    ev:SetScript("OnEvent", function(...) if Unlocked() then guarded(...) end end)
end

------------------------------------------------------------------------------------------
-- The node fold: goldNodesSeen (from before the advisor and the planner met) moves into the planner's
-- plannerNodesSeen once, as a sliced job, and is then gone. Until it is done, both are read (Stores below).
------------------------------------------------------------------------------------------
local function SameNode(a, b)
    return type(a) == "table" and type(b) == "table" and a.name == b.name and a.skill == b.skill
        and tonumber(a.x) == tonumber(b.x) and tonumber(a.y) == tonumber(b.y)
end
local function FoldNodes()
    local root = Root()
    local gold = root and root.goldNodesSeen
    if type(gold) ~= "table" then return end
    local cap, totalCap = tonumber(ns.PLANNER_NODE_CAP) or 300, tonumber(ns.PLANNER_NODES_TOTAL) or 4000   -- (the planner's caps)
    local total = 0
    for _, l in pairs(type(root.plannerNodesSeen) == "table" and root.plannerNodesSeen or {}) do
        if type(l) == "table" then total = total + #l end
    end
    local maps = {}
    for map in pairs(gold) do maps[#maps + 1] = map end           -- (the keys first: the walk yields)
    for _, map in ipairs(maps) do
        local list = gold[map]
        for _, n in ipairs(type(list) == "table" and list or {}) do
            local mine = type(root.plannerNodesSeen) == "table" and root.plannerNodesSeen[map] or nil
            local skip = type(n) ~= "table" or (type(mine) == "table" and #mine >= cap) or total >= totalCap   -- (a full map, or all maps full: the planner's own nodes stay)
            if not skip and type(mine) == "table" then
                for _, m in ipairs(mine) do if SameNode(m, n) then skip = true; break end end   -- (folded before: an interrupted fold runs again)
            end
            if not skip and ns.PlannerRecordNode(map, Num(n.x), Num(n.y), n.name, n.skill) then total = total + 1 end   -- (its 10-yard rule)
            ns.GoldYield()
        end
        gold[map] = nil                                             -- (this map is moved, all of it)
    end
    if next(gold) == nil and root.goldNodesSeen == gold then root.goldNodesSeen = nil end
end
-- Queue the fold (true when it was queued): only while unlocked, with an old memory to fold, and with the
-- planner's node recorder and world positions (without them nothing could be recorded, and the nodes would be lost).
function ns.GoldFoldNodes()
    local root = Root()
    if not (Unlocked() and root and type(root.goldNodesSeen) == "table") then return false end
    if type(ns.PlannerRecordNode) ~= "function" or type(ns.PlannerWorldPos) ~= "function" then return false end
    return ns.GoldJob(FoldNodes, "nodeFold") == true
end
do
    local ev, folded = CreateFrame("Frame"), false
    pcall(ev.RegisterEvent, ev, "PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", function(_, event)                 -- (plain: it only queues the job, at a loading screen while unlocked, once a session)
        if event ~= "PLAYER_ENTERING_WORLD" or folded or not Unlocked() then return end
        folded = ns.GoldFoldNodes()                             -- (not queued, as with nothing to fold: asked again at the next one)
    end)
    -- (for the tests: a new session, so the next PLAYER_ENTERING_WORLD may fold again)
    ns.goldRecordersTest = { Reset = function() folded = false end }
end
end

------------------------------------------------------------------------------------------
-- From GoldCraft.lua: the recipes you know -> ns.root.goldChars[key].recipes
------------------------------------------------------------------------------------------
do
local Secret = function(v) return ns:IsSecret(v) end
local huge = math.huge
local RECIPE_CAP = 600

-- A plain finite number from the game or the store, else nil.
local function Num(v)
    if Secret(v) or type(v) ~= "number" or v ~= v or v == huge or v == -huge then return nil end
    return v
end
local function Str(v)
    if Secret(v) or type(v) ~= "string" or v == "" then return nil end
    return v
end
-- The first answer of a game function, or nil when it is missing, errors or hides its answer.
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if not ok or Secret(v) then return nil end
    return v
end
local function Unlocked() return ns.GuideUnlocked ~= nil and ns:GuideUnlocked() == true end
local function InFight()
    local ok, v = pcall(InCombatLockdown)
    return ok and ns.Yes(v)
end
-- This character's record in ns.root.goldChars; the tables are made only when `create` is set.
local function CharRecord(create, key)
    if type(ns.root) ~= "table" then return nil end
    local all = ns.root.goldChars
    if type(all) ~= "table" then
        if not create then return nil end
        all = {}
        ns.root.goldChars = all
    end
    key = key or ns:CharKey()
    local rec = all[key]
    if type(rec) ~= "table" then
        if not create then return nil end
        rec = {}
        all[key] = rec
    end
    return rec
end

------------------------------------------------------------------------------------------
-- recorders (light; may stay in the main add-on when the folder moves)
-- When a profession opens, one job walks its recipes (a second of quiet first, as the list fills).
------------------------------------------------------------------------------------------
-- Is your own profession window open and filled? Someone else's list (a link, a guild's or an NPC's
-- crafting) is not what you can make.
local function Ready()
    local T = C_TradeSkillUI
    if type(T) ~= "table" or not ns.Yes(Call(T.IsTradeSkillReady)) then return false end
    if ns.Yes(Call(T.IsTradeSkillLinked)) or ns.Yes(Call(T.IsTradeSkillGuild)) or ns.Yes(Call(T.IsNPCCrafting)) then return false end
    return true
end

-- The basic reagents of a schematic, as Economy's shopping list reads them: { { id, need } }, and
-- true when a slot that counts could not be read (its item, its count or its kind): such a recipe is
-- never priced, since the cost would be too low.
local function SchematicReagents(s)
    local out, incomplete = {}, false
    for _, slot in ipairs(type(s.reagentSlotSchematics) == "table" and s.reagentSlotSchematics or {}) do
        if type(slot) == "table" then
            local rt = slot.reagentType
            if Secret(rt) or Secret(slot.required) then
                incomplete = true
            elseif rt == nil or rt == 1 or ns.Is(slot.required, true) then
                local first = type(slot.reagents) == "table" and slot.reagents[1]
                local id = type(first) == "table" and Num(first.itemID)
                local need = Num(slot.quantityRequired)
                if not id or not need then incomplete = true
                elseif need > 0 then out[#out + 1] = { id = id, need = need } end
            end
        end
    end
    return out, incomplete
end

-- The open profession's name, or nil.
local function ProfessionName()
    local T = C_TradeSkillUI
    local base = type(T) == "table" and Call(T.GetBaseProfessionInfo)
    return type(base) == "table" and Str(base.professionName) or nil
end

local again = false                    -- another profession opened while one was being read: read again after
local function ReadRecipes()
    if not Unlocked() or not Ready() then return end
    local T = C_TradeSkillUI
    local prof = ProfessionName()
    local ids = Call(T.GetAllRecipeIDs)
    if not prof or type(ids) ~= "table" then return end           -- (whose recipes these are must be known to replace them)
    local today = ns.Today()
    local found, order = {}, {}
    for _, id in ipairs(ids) do
        id = Num(id)
        local info = id and Call(T.GetRecipeInfo, id)
        if type(info) == "table" and ns.Is(info.learned, true) then
            local s = Call(T.GetRecipeSchematic, id, false)
            local out = type(s) == "table" and Num(s.outputItemID)
            if out and out > 0 then
                local nMin = Num(s.quantityMin) or 1
                local nMax = Num(s.quantityMax) or nMin
                if nMin < 1 then nMin = 1 end
                if nMax < nMin then nMax = nMin end
                local reagents, incomplete = SchematicReagents(s)
                found[id] = { name = Str(info.name) or Str(s.name), out = out, nMin = nMin, nMax = nMax, reagents = reagents,
                              incomplete = incomplete or nil, prof = prof, day = today }
                order[#order + 1] = id
            end
        end
        ns.GoldYield()
    end
    -- the window closed or went to another profession between slices: this read is not kept
    if not Ready() then return end
    if ProfessionName() ~= prof then again = true; return end
    -- this profession's old recipes go; the others stay; at most RECIPE_CAP in all
    local rec = CharRecord(#order > 0)
    if not rec then return end
    local kept, n = {}, 0
    for id, r in pairs(type(rec.recipes) == "table" and rec.recipes or {}) do
        if type(r) == "table" and r.prof ~= prof then kept[id] = r; n = n + 1 end
    end
    table.sort(order)
    for _, id in ipairs(order) do
        if n >= RECIPE_CAP then break end
        kept[id] = found[id]
        n = n + 1
    end
    rec.recipes = kept
end
local function RecipesJob()
    ReadRecipes()
    if again then
        again = false
        ns:After(0, function() ns.GoldRecipesRead() end)          -- (next frame: this job is gone by then)
    end
end

-- Read the open profession's recipes, as a job. False when locked, in a fight or not ready. While a read
-- is already queued, the open profession is read again right after it (true).
function ns.GoldRecipesRead()
    if not Unlocked() or InFight() or not Ready() then return false end
    if ns.GoldBusy("recipes") then again = true; return true end
    return ns.GoldJob(RecipesJob, "recipes")
end

do
    local ev, gen = CreateFrame("Frame"), 0
    pcall(ev.RegisterEvent, ev, "TRADE_SKILL_SHOW")
    pcall(ev.RegisterEvent, ev, "TRADE_SKILL_LIST_UPDATE")
    -- (a plain handler first: while locked it returns at once, so nothing named Gold is timed by /fgui perf)
    local guarded = ns:Guard("Gold recipes", function(_, event)
        if (event ~= "TRADE_SKILL_SHOW" and event ~= "TRADE_SKILL_LIST_UPDATE") or not Unlocked() then return end
        gen = gen + 1
        local mine = gen
        ns:After(1, function() if mine == gen then ns.GoldRecipesRead() end end)
    end)
    ev:SetScript("OnEvent", function(...) if Unlocked() then guarded(...) end end)
end
end
