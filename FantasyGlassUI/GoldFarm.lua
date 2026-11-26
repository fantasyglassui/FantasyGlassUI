-- Ways to make gold: Monsters worth killing and dungeon drops (group B). Plugs into Gold.lua through ns.GoldRegister.
local _, ns = ...

------------------------------------------------------------------------------------------
-- Monsters: what each one you loot drops (for all your characters), how fast you kill (per
-- character), and from those, plus Questie's spawns and quest items, which monsters are worth
-- killing and the way round them. Your own farming by zone ("measured") beats any guess.
-- Everything here does nothing while the guide is locked.
------------------------------------------------------------------------------------------
local floor, max, min, huge = math.floor, math.max, math.min, math.huge
local MOB_CAP, ITEM_CAP = 400, 12          -- monsters kept, items kept per monster (the most looted)
local LEARNED = 10                         -- loots before a monster's own drops replace the default
local PACE_GAP, PACE_CAP, PACE_MIN = 120, 400, 20
local CANDIDATES, FARM_IDEAS, LOOP = 40, 8, 6
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
local function PlayerLevel()
    local lv = Num(Ask(UnitLevel, "player"))
    return lv or 1
end
local function MapName(map)
    if not Num(map) then return nil end
    local info = Ask(C_Map and C_Map.GetMapInfo, map)
    return type(info) == "table" and Str(info.name) or nil
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
local function Pace(charKey)
    local all = type(ns.root) == "table" and ns.root.goldChars
    local rec = type(all) == "table" and all[charKey]
    local pace = type(rec) == "table" and rec.pace
    return type(pace) == "table" and pace or nil
end

------------------------------------------------------------------------------------------
-- recorders (light; may stay in the main add-on when the folder moves)
-- LOOT_OPENED: each creature in the window is one loot of its kind, with what it gave. Coin is what
-- the money slot says each creature gave; failing that, with one creature in the window, your purse
-- at LOOT_CLOSED less your purse at LOOT_OPENED. Solo only (in a group, rolls and split coin are not
-- yours), never a window that follows Pick Pocket or a gathering cast, and never a living target.
------------------------------------------------------------------------------------------
-- Casts whose loot window is not a kill: Pick Pocket, and skinning, herbs and ore (the ids group C uses).
local NOT_A_KILL = { [921] = true,
    [2366] = true, [2368] = true, [3570] = true, [11993] = true,
    [2575] = true, [2576] = true, [3564] = true, [10248] = true,
    [8613] = true, [8617] = true, [8618] = true, [10768] = true }
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
    local gather = spellID and type(ns.GoldGatherSkill) == "function" and ns.GoldGatherSkill(spellID)
    if spellID and (NOT_A_KILL[spellID] or gather) then castAt = Clock() end
end

do
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "LOOT_OPENED")
    pcall(ev.RegisterEvent, ev, "LOOT_CLOSED")
    local ok = type(ev.RegisterUnitEvent) == "function" and pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_SUCCEEDED", "player")
    if not ok then pcall(ev.RegisterEvent, ev, "UNIT_SPELLCAST_SUCCEEDED") end
    ev:SetScript("OnEvent", ns:Guard("Gold loot", function(_, event, a1, _, a3)
        if event == "LOOT_OPENED" then LootOpened()
        elseif event == "LOOT_CLOSED" then LootClosed()
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then CastDone(a1, a3) end
    end))
end

------------------------------------------------------------------------------------------
-- What a monster is worth, and how long one takes
------------------------------------------------------------------------------------------
-- Vendor trash and cloth by level band (copper a loot): a guess, until a monster has taught better.
local DEFAULTS = { { 9, 30 }, { 19, 150 }, { 29, 400 }, { 39, 800 }, { 49, 1300 }, { 59, 2000 } }
function ns.GoldKillDefault(level)
    level = Num(level) or PlayerLevel()
    for _, band in ipairs(DEFAULTS) do if level <= band[1] then return band[2] end end
    return 2600
end

-- Copper a loot, the day of the oldest auction price in it (nil: none), and whether it is learned.
-- The items it no longer lists count as their `other` copper.
function ns.GoldMobValue(rec, today)
    if type(rec) ~= "table" then return 0, nil, false end
    local loots = Num(rec.loots) or 0
    if loots < LEARNED then return ns.GoldKillDefault(rec.level), nil, false end
    local sum, oldest = max(0, Num(rec.copper) or 0) + max(0, Num(rec.other) or 0), nil
    for id, n in pairs(type(rec.items) == "table" and rec.items or {}) do
        local okI, name = pcall(ns.GetItemInfo, ns, id)
        local value, _, day = 0, nil, nil
        if okI and Str(name) then value, _, day = ns.GoldItemValue(id, today) end      -- (not loaded yet: skipped until it is)
        if Num(n) and n > 0 then sum = sum + n * value end
        if day and (not oldest or day < oldest) then oldest = day end
    end
    return floor(sum / loots), oldest, true
end

-- Seconds a kill takes, from how many places Questie lists it in that zone (nil: no Questie).
function ns.GoldKillSeconds(spawns)
    spawns = Num(spawns)
    if not spawns or spawns <= 0 then return 40 end
    if spawns >= 30 then return 30 end
    if spawns >= 10 then return 40 end
    return 60
end

------------------------------------------------------------------------------------------
-- Questie, read-only through pcall (the same calls PlannerSource.lua makes)
------------------------------------------------------------------------------------------
-- The quests in your log not yet complete: { id, title, money, needs = { numRequired of each item
-- objective }, done = { whether each of those is finished } }.
local function LogQuests()
    local QL = C_QuestLog
    local out = {}
    if type(QL) ~= "table" then return out end
    local n = Num(Ask(QL.GetNumQuestLogEntries)) or 0
    for i = 1, min(floor(n), 100) do
        local info = Ask(QL.GetInfo, i)
        local id = type(info) == "table" and not ns.Yes(info.isHeader) and Num(info.questID)
        if id and not ns.Yes(Ask(QL.IsComplete, id)) then
            local needs, done = {}, {}
            local objectives = Ask(QL.GetQuestObjectives, id)
            for _, o in ipairs(type(objectives) == "table" and objectives or {}) do
                if type(o) == "table" and Str(o.type) == "item" then
                    needs[#needs + 1] = Num(o.numRequired) or 1
                    done[#needs] = ns.Yes(o.finished)
                end
            end
            out[#out + 1] = { id = id, title = Str(info.title) or tostring(id), money = max(0, Num(Ask(GetQuestLogRewardMoney, id)) or 0), needs = needs, done = done }
        end
        ns.GoldYield()
    end
    return out
end

local function Import(L, name)
    local ok, mod = pcall(L.ImportModule, L, name)
    if ok and type(mod) == "table" then return mod end
    return nil
end
-- Questie as a reader, with your log's open quests; nil when it is not loaded, not ready or changed.
function ns.GoldFarmQuestie()
    if not ns.Yes(Ask(C_AddOns and C_AddOns.IsAddOnLoaded, "Questie")) then return nil end
    local Q = _G.Questie
    local api = type(Q) == "table" and type(Q.API) == "table" and Q.API or nil
    if api and api.isReady == false then return nil end
    local L = _G.QuestieLoader
    if type(L) ~= "table" or type(L.ImportModule) ~= "function" then return nil end
    local db, zones = Import(L, "QuestieDB"), Import(L, "ZoneDB")
    if not (db and zones) or type(db.QueryNPCSingle) ~= "function" or type(zones.GetUiMapIdByAreaId) ~= "function" then return nil end
    local function Try(f, ...)
        if type(f) ~= "function" then return nil end
        local ok, v = pcall(f, ...)
        if ok then return v end
        return nil
    end
    return {
        npc = function(id, key) return Try(db.QueryNPCSingle, id, key) end,
        item = function(id, key) return Try(db.QueryItemSingle, id, key) end,
        quest = function(id, key) return Try(db.QueryQuestSingle, id, key) end,
        map = function(area) return Try(zones.GetUiMapIdByAreaId, zones, area) end,
        quests = LogQuests(),
    }
end

-- A monster's spawns by map: { [uiMapID] = { { x, y }, ... } }.
local function SpawnsByMap(q, npc)
    local out = {}
    local spawns = q.npc(npc, "spawns")
    if type(spawns) ~= "table" then return out end
    for area, list in pairs(spawns) do
        local map = Num(q.map(area))
        if map and type(list) == "table" then
            for _, p in ipairs(list) do
                local x, y = type(p) == "table" and Num(p[1]), type(p) == "table" and Num(p[2])
                if x and y and not (x == -1 and y == -1) then
                    out[map] = out[map] or {}
                    out[map][#out[map] + 1] = { x, y }
                end
            end
        end
        ns.GoldYield()
    end
    return out
end
local function MostSpawns(byMap)
    local best, bn = nil, 0
    for map, list in pairs(byMap) do
        if #list > bn or (#list == bn and best and map < best) then best, bn = map, #list end
    end
    return best
end
local function Dist2(ax, ay, bx, by) return (ax - bx) * (ax - bx) + (ay - by) * (ay - by) end
-- The spawn with the most others within 8 (map units of 0..100).
local function Densest(pts)
    local best, bn = nil, -1
    for i, p in ipairs(pts) do
        local c = 0
        for j, o in ipairs(pts) do if i ~= j and Dist2(p[1], p[2], o[1], o[2]) <= 64 then c = c + 1 end end
        if c > bn then best, bn = p, c end
        ns.GoldYield()
    end
    return best
end
-- Up to LOOP spawns, nearest first from (sx, sy), then each time the nearest not yet visited.
local function Loop(pts, sx, sy)
    local out, used = {}, {}
    if not (sx and sy) then
        local d = Densest(pts)
        if not d then return out end
        sx, sy = d[1], d[2]
    end
    for _ = 1, min(LOOP, #pts) do
        local bi, bd
        for i, p in ipairs(pts) do
            if not used[i] then
                local d = Dist2(sx, sy, p[1], p[2])
                if not bd or d < bd then bi, bd = i, d end
            end
        end
        if not bi then break end
        used[bi] = true
        out[#out + 1] = { x = pts[bi][1], y = pts[bi][2] }
        sx, sy = pts[bi][1], pts[bi][2]
        ns.GoldYield()
    end
    return out
end

------------------------------------------------------------------------------------------
-- The ideas (pure: everything comes in as arguments; Questie only through the reader)
------------------------------------------------------------------------------------------
local function ByValue(a, b)
    if a.perLoot ~= b.perLoot then return a.perLoot > b.perLoot end
    return a.npc < b.npc
end
local function ByHour(a, b)
    local ga, gb = a.perHour or a.total or 0, b.perHour or b.total or 0                  -- (a one-off by its total)
    if ga ~= gb then return ga > gb end
    return a.id < b.id
end
local function ItemName(id)
    local ok, name = pcall(ns.GetItemInfo, ns, id)
    return ok and Str(name) or format(ns:Tr("Item %d"), id)
end

-- The quest money a monster's drops bring: { [npc] = { per = copper a loot, money = the rewards still
-- to earn (each quest once), need = items still wanted } }, and the quests' names. Finished objectives
-- are left out.
local function QuestDrops(questie)
    local bonus, names = {}, {}
    if type(questie) ~= "table" then return bonus, names end
    for _, quest in ipairs(type(questie.quests) == "table" and questie.quests or {}) do
        local objectives = questie.quest(quest.id, "objectives")
        local items = type(objectives) == "table" and type(objectives[3]) == "table" and objectives[3] or {}
        for k, e in ipairs(items) do
            local item = type(e) == "table" and Num(e[1])
            if item and not (quest.done and quest.done[k]) then
                local need = Num(e[2]) or (quest.needs and quest.needs[k]) or 1
                local per = floor((quest.money or 0) / max(1, need) * 0.5)
                local drops = questie.item(item, "npcDrops")
                for _, npc in ipairs(type(drops) == "table" and drops or {}) do
                    npc = Num(npc)
                    if npc then
                        local b = bonus[npc] or { per = 0, money = 0, need = 0, quests = {} }
                        bonus[npc] = b
                        b.per, b.need = b.per + per, b.need + max(1, need)
                        if not b.quests[quest.id] then b.quests[quest.id] = true; b.money = b.money + (quest.money or 0) end
                        if per > 0 then
                            names[npc] = names[npc] or {}
                            names[npc][#names[npc] + 1] = quest.title
                        end
                    end
                end
            end
        end
        ns.GoldYield()
    end
    return bonus, names
end

-- Farm ideas from the monsters you have looted (`mobs`, as ns.root.goldMobs), Questie's droppers of
-- your quests' items, and your farming by zone (`zones`, as ns.FarmZoneRanking gives it). `questie`
-- is ns.GoldFarmQuestie() or nil; `here` is { map, x, y } or nil. Calls add(idea) for at most 8
-- ideas, and returns them. It writes nothing. Besides its arguments it reads: your kill pace
-- (ns.root.goldChars[ctx.charKey].pace), what items are worth (ns.GoldItemValue, ns:GetItemInfo) and
-- zone names (C_Map.GetMapInfo).
function ns.GoldFarmIdeas(ctx, add, mobs, zones, questie, here)
    ctx = type(ctx) == "table" and ctx or {}
    mobs = type(mobs) == "table" and mobs or {}
    questie = type(questie) == "table" and questie or nil
    here = type(here) == "table" and here or {}
    local today = ctx.today or ns.Today()
    local level = Num(ctx.level) or PlayerLevel()
    local bonus, questNames = QuestDrops(questie)
    -- the candidates
    local cands = {}
    for npc, rec in pairs(mobs) do
        if Num(npc) and type(rec) == "table" then
            local lv = Num(rec.level) or level
            if lv <= level + 2 and rec.instance ~= true then                      -- (dungeon monsters are not world farming)
                local value, day, learned = ns.GoldMobValue(rec, today)
                cands[#cands + 1] = { npc = npc, recorded = true, name = Str(rec.name), level = lv, map = Num(rec.map), zone = Str(rec.zone), x = Num(rec.x), y = Num(rec.y),
                                      value = value, day = day, learned = learned, loots = Num(rec.loots) or 0, items = rec.items }
            end
        end
        ns.GoldYield()
    end
    local spawnCache = {}
    if questie then
        for npc in pairs(bonus) do
            if type(mobs[npc]) ~= "table" then
                local lv = Num(tonumber(questie.npc(npc, "maxLevel"))) or Num(tonumber(questie.npc(npc, "minLevel")))
                if (lv or level) <= level + 2 then
                    spawnCache[npc] = SpawnsByMap(questie, npc)
                    local map = MostSpawns(spawnCache[npc])
                    cands[#cands + 1] = { npc = npc, name = Str(questie.npc(npc, "name")), level = lv or level, map = map,
                                          value = ns.GoldKillDefault(lv or level), learned = false, loots = 0 }
                end
            end
            ns.GoldYield()
        end
    end
    for _, c in ipairs(cands) do c.perLoot = c.value + (bonus[c.npc] and bonus[c.npc].per or 0) end
    table.sort(cands, ByValue)
    -- the measured zones (ten minutes or more of your own farming)
    local measured = {}
    for _, z in ipairs(type(zones) == "table" and zones or {}) do
        if type(z) == "table" and Str(z.zone) and Num(z.secs) and z.secs >= 600 and Num(z.perHour) then
            measured[z.zone] = { z = z, lines = {} }
        end
    end
    local pace = Pace(ctx.charKey)
    local paceSecs = pace and Num(pace.loots) and pace.loots >= PACE_MIN and Num(pace.secs)
        and max(10, min(120, pace.secs / pace.loots)) or nil
    local ideas = {}
    for i = 1, min(CANDIDATES, #cands) do
        local c = cands[i]
        local byMap = questie and (spawnCache[c.npc] or SpawnsByMap(questie, c.npc)) or {}
        local map = c.map or MostSpawns(byMap)
        local pts = map and byMap[map] or {}
        local secs = paceSecs or ns.GoldKillSeconds(questie and #pts or nil)
        -- the quest part is one-time money: an hour of it is at most what the quests still pay
        local b = bonus[c.npc]
        local quest = b and b.per > 0 and min(b.per * 3600 / secs, b.money) or 0
        local perHour = floor(3600 / secs * c.value + quest)
        local oneOff = b and b.per > 0 and (not c.recorded or c.value <= 0) or false   -- (the quest is the only real reason)
        local zone = c.zone or MapName(map) or ns:Tr("an unknown place")
        local name = c.name or format(ns:Tr("Monster %d"), c.npc)
        -- the way: there, then round its spawns (nearest you first), or the one spot known
        local route
        if #pts > 0 then
            local sx, sy
            if here.map == map and here.x and here.y then sx, sy = here.x, here.y
            elseif c.x and c.y then sx, sy = c.x, c.y end
            route = Loop(pts, sx, sy)
        elseif c.x and c.y then
            route = { { x = c.x, y = c.y } }
        else
            route = {}
        end
        local steps = { { text = format(ns:Tr("Go to %s"), zone), map = map } }
        for k, p in ipairs(route) do
            local text = (k == 1) and format(ns:Tr("Kill %s around here"), name) or ns:Tr("Then here")
            steps[#steps + 1] = { text = text, map = map, x = p.x, y = p.y }
        end
        local ease = ns.GOLD_EASE.farm or 35
        if c.level <= level - 5 then ease = ease + 15 end
        if c.level >= level + 1 then ease = ease - 15 end
        if map ~= ctx.map then ease = ease - 10 end
        local tip
        if questNames[c.npc] then tip = { format(ns:Tr("Includes the reward of %s."), table.concat(questNames[c.npc], ", ")) } end
        local detail = {
            { left = ns:Tr("Worth a kill"), right = ns:Coins(c.perLoot), copper = c.perLoot },
            { left = ns:Tr("Time a kill"), right = format(ns:Tr("%d s"), floor(secs + 0.5)) },
            { left = c.learned and format(ns:Tr("Learned from %d of your kills."), c.loots)
                or ns:Tr("A guess for its level, until you have looted it 10 times.") },
        }
        if tip then detail[#detail + 1] = { left = format(ns:Tr("Includes a one-time quest reward of %s"), ns:Coins(b.money)), right = tip[1], copper = b.money } end
        if c.learned and type(c.items) == "table" then
            local list = {}
            for id, n in pairs(c.items) do if Num(id) and Num(n) and n > 0 then list[#list + 1] = { id = id, n = n } end end
            table.sort(list, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.id < b.id end)
            for _, e in ipairs(list) do detail[#detail + 1] = { left = ItemName(e.id), right = format("x%d", e.n) } end
        end
        if #route > 0 then
            detail[#detail + 1] = { left = ns:Tr("The way round") }
            local stop = 0
            for _, step in ipairs(steps) do
                if step.x then
                    stop = stop + 1
                    detail[#detail + 1] = { left = format("%d. %s", stop, step.text), right = format("%.1f, %.1f", step.x, step.y) }
                end
            end
        end
        local idea = {
            id = "farm:" .. tostring(map or 0) .. ":" .. tostring(c.npc), kind = "farm", oneOff = false,
            title = format(ns:Tr("Kill %s in %s"), name, zone), perHour = perHour,
            ease = max(0, min(100, ease)), safety = ns.GOLD_SAFETY.farm.guess, basis = "guess", priceDay = c.day,
            where = "window", map = map, steps = steps, detail = detail, tip = tip,
            npc = c.npc, perLoot = c.perLoot, killSeconds = secs, zone = zone,
        }
        if oneOff then
            idea.oneOff, idea.perHour = true, nil
            idea.total, idea.minutes = b.money, b.need * secs / 60
        end
        local m = not oneOff and measured[c.zone or zone]
        if oneOff then
            if idea.total >= 100 then ideas[#ideas + 1] = idea end
        elseif m then
            m.map = m.map or map
            m.lines[#m.lines + 1] = { left = idea.title, right = format(ns:Tr("%s an hour"), ns:Coins(perHour)) .. " (" .. ns:Tr("guess") .. ")" }
        elseif perHour >= 100 then
            ideas[#ideas + 1] = idea
        end
        ns.GoldYield()
    end
    for name, m in pairs(measured) do
        local z = m.z
        local ease = (ns.GOLD_EASE.farm or 35) - ((ctx.zone ~= name) and 10 or 0)
        local detail = { { left = ns:Tr("Your own farming here, all your times together"), right = format(ns:Tr("%s an hour"), ns:Coins(floor(z.perHour))) } }
        for _, line in ipairs(m.lines) do detail[#detail + 1] = line end
        local perHour = floor(z.perHour)
        if perHour >= 100 then
            ideas[#ideas + 1] = {
                id = "farm:zone:" .. name, kind = "farm", oneOff = false, title = format(ns:Tr("Farm in %s (your own times)"), name),
                perHour = perHour, ease = max(0, min(100, ease)), safety = ns.GOLD_SAFETY.farm.measured, basis = "measured",
                where = "window", map = m.map, steps = { { text = format(ns:Tr("Go to %s"), name), map = m.map } }, detail = detail,
            }
        end
    end
    table.sort(ideas, ByHour)
    local out = {}
    for i = 1, min(FARM_IDEAS, #ideas) do
        out[i] = ideas[i]
        if add then add(ideas[i]) end
    end
    return out
end

ns.GoldRegister("farm", function(ctx, add)
    if type(ctx) ~= "table" or ctx.where == "auction" then return end           -- (farm ideas live in the window)
    local root = type(ns.root) == "table" and ns.root or {}
    local zones = {}
    if type(ns.FarmZoneRanking) == "function" and type(root.farmZones) == "table" then zones = ns.FarmZoneRanking(root.farmZones) end
    ns.GoldFarmIdeas(ctx, add, root.goldMobs, zones, ns.GoldFarmQuestie(), Here())
end)

------------------------------------------------------------------------------------------
-- Dungeons: which runs pay best, and what their drops are worth (the run log and the loot book)
------------------------------------------------------------------------------------------
local DUNGEON_DAYS, DUNGEON_MIN_SECS, DUNGEON_IDEAS = 90, 300, 5

-- What one drop is worth: an item bound when picked up (bind type 1) only to a vendor; an item whose
-- details are not loaded yet, nothing (its vendor price and bind type are not known either).
local function DropWorth(link, today)
    local id = ItemOf(link)
    if not id then return 0, nil, nil end
    local ok, name, _, _, _, _, _, _, _, _, _, vendor, _, _, bind = pcall(ns.GetItemInfo, ns, link)
    if not (ok and Str(name)) then return 0, nil, id end                        -- (not loaded yet: counted once it is)
    if Num(bind) == 1 then return max(0, Num(vendor) or 0), nil, id end
    local value, _, day = ns.GoldItemValue(id, today)
    return value, day, id
end

-- A run's drops: copper, and the day of the oldest auction price in it (nil: none).
function ns.GoldRunValue(run, today)
    if type(run) ~= "table" then return 0, nil end
    local sum, oldest = 0, nil
    for _, link in ipairs(type(run.loot) == "table" and run.loot or {}) do
        local value, day = DropWorth(link, today)
        sum = sum + value
        if day and (not oldest or day < oldest) then oldest = day end
    end
    return sum, oldest
end

local function DungeonIdeas(ctx, add)
    local log = type(ns.RunLogged) == "function" and ns.RunLogged() or {}
    local today, now = ctx.today or ns.Today(), Num(ctx.now) or Num(Ask(time)) or 0
    local by, order = {}, {}
    for _, r in ipairs(type(log) == "table" and log or {}) do
        local inst = type(r) == "table" and Str(r.instance)
        local start = inst and Num(r.start)
        local secs = start and ns.RunLength(r) or 0
        if start and now - start <= DUNGEON_DAYS * 86400 and secs >= DUNGEON_MIN_SECS then
            local p = by[inst]
            if not p then p = { instance = inst, runs = 0, value = 0, secs = 0, items = {}, list = {} }; by[inst] = p; order[#order + 1] = p end
            p.runs, p.secs = p.runs + 1, p.secs + secs
            for _, link in ipairs(type(r.loot) == "table" and r.loot or {}) do
                local value, day, id = DropWorth(link, today)
                p.value = p.value + value
                if day and (not p.day or day < p.day) then p.day = day end
                if id then
                    local e = p.items[id]
                    if not e then e = { link = link, n = 0, value = value }; p.items[id] = e; p.list[#p.list + 1] = e end
                    e.n = e.n + 1
                end
            end
        end
        ns.GoldYield()
    end
    local book = type(ns.root) == "table" and type(ns.root.lootBook) == "table" and ns.root.lootBook or {}
    local ideas = {}
    for _, p in ipairs(order) do
        local perHour = floor(p.value / p.secs * 3600)
        local basis = (p.runs >= 2) and "measured" or "guess"
        local detail = {}
        local bosses = type(book[p.instance]) == "table" and book[p.instance] or {}
        local names = {}
        for boss, b in pairs(bosses) do if Str(boss) and type(b) == "table" and (Num(b.kills) or 0) > 0 then names[#names + 1] = boss end end
        table.sort(names)
        if #names > 0 then detail[#detail + 1] = { left = ns:Tr("One kill of each boss is worth") } end
        for _, boss in ipairs(names) do
            local b = bosses[boss]
            local worth = 0
            for id, e in pairs(type(b.items) == "table" and b.items or {}) do
                local n = type(e) == "table" and Num(e.n)
                if n and n > 0 then
                    local value = DropWorth(Str(e.link) or ("item:" .. tostring(id)), today)
                    worth = worth + n / b.kills * value
                end
            end
            worth = floor(worth)
            detail[#detail + 1] = { left = "  " .. boss, right = ns:Coins(worth), copper = worth }
            ns.GoldYield()
        end
        if #p.list > 0 then
            detail[#detail + 1] = { left = ns:Tr("Your drops from these runs") }
            table.sort(p.list, function(a, b) if a.value ~= b.value then return a.value > b.value end return a.link < b.link end)
            for _, e in ipairs(p.list) do
                detail[#detail + 1] = { left = e.link, right = ns:Coins(e.value) .. ((e.n > 1) and format(" x%d", e.n) or ""), copper = e.value }
            end
        end
        ideas[#ideas + 1] = {
            id = "dungeon:" .. p.instance, kind = "dungeon", oneOff = false, title = format(ns:Tr("Run %s (rare drops)"), p.instance),
            perHour = perHour, ease = ns.GOLD_EASE.dungeon or 20, safety = ns.GOLD_SAFETY.dungeon[basis], basis = basis, priceDay = p.day,
            where = "window", steps = { { text = format(ns:Tr("Go to %s"), p.instance) } }, detail = detail,
            tip = { ns:Tr("Counts rare and better drops only; coin and trash are not in it.") }, runs = p.runs,
        }
    end
    table.sort(ideas, ByHour)
    for i = 1, min(DUNGEON_IDEAS, #ideas) do add(ideas[i]) end
end

ns.GoldRegister("dungeon", function(ctx, add)
    if type(ctx) ~= "table" or ctx.where == "auction" then return end
    DungeonIdeas(ctx, add)
end)
