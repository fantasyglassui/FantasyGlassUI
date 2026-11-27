local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end

------------------------------------------------------------------------------------------
-- Planner source: where the route planner learns which quests exist. Questie (when it is loaded,
-- ready and still speaks the contract this was written for) is read through pcall; otherwise the
-- quest log alone is used. Either way the planner receives plain records and never sees Questie.
------------------------------------------------------------------------------------------
ns.PLANNER_CONTRACT = "4"

local pcall, type, pairs, ipairs, tonumber = pcall, type, pairs, ipairs, tonumber
local format = string.format
local waiting = false

-- Run f; true plus its results, or false.
local function Try(f, ...) return pcall(f, ...) end

local function Import(name)
    local L = _G.QuestieLoader
    if not (L and L.ImportModule) then return nil end
    local ok, mod = Try(L.ImportModule, L, name)
    if ok and type(mod) == "table" then return mod end
end

local function IsLoaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Questie") and true or false
end

local function Spots(db, zones, npcId, object)
    local out = {}
    local spawns = (object and db.QueryObjectSingle or db.QueryNPCSingle)(npcId, "spawns")
    if type(spawns) ~= "table" then return out end
    for area, list in pairs(spawns) do
        local map = zones:GetUiMapIdByAreaId(area)
        if map and type(list) == "table" then
            for _, p in ipairs(list) do
                if type(p) == "table" and tonumber(p[1]) and tonumber(p[2]) and not (p[1] == -1 and p[2] == -1) then
                    out[#out + 1] = { map = map, x = p[1], y = p[2] }
                end
            end
        end
    end
    return out
end

local function Merge(into, from) for _, s in ipairs(from) do into[#into + 1] = s end end

local function Level(db, id)
    local lv = db.QueryNPCSingle(id, "maxLevel") or db.QueryNPCSingle(id, "minLevel")
    return tonumber(lv)
end

-- One objective from an NPC list (kill credit) or the NPCs that drop an item.
local function NpcObjective(db, zones, ids, state)
    local o = { kind = "kill", spots = {} }
    for _, npc in ipairs(ids) do
        Merge(o.spots, Spots(db, zones, npc))
        local lv = Level(db, npc)
        if lv and (not o.mobLevel or lv > o.mobLevel) then o.mobLevel = lv end
        local rank = tonumber(db.QueryNPCSingle(npc, "rank"))
        if rank == 1 or rank == 2 then state.elite = true end
    end
    return o
end

local ServerId                    -- (below: the id the game knows a quest by in your log)
local function Objectives(db, zones, quest, state, id)
    local out, raw = {}, quest.objectives
    if type(raw) == "table" then
        for _, e in ipairs(type(raw[1]) == "table" and raw[1] or {}) do
            out[#out + 1] = NpcObjective(db, zones, { e[1] }, state)
        end
        for _, e in ipairs(type(raw[5]) == "table" and raw[5] or {}) do
            local ids = type(e[1]) == "table" and e[1] or { e[2] }
            out[#out + 1] = NpcObjective(db, zones, ids, state)
        end
        for _, e in ipairs(type(raw[3]) == "table" and raw[3] or {}) do
            local drops = db.QueryItemSingle and db.QueryItemSingle(e[1], "npcDrops")
            local o = NpcObjective(db, zones, type(drops) == "table" and drops or {}, state)
            o.kind = "item"
            out[#out + 1] = o
        end
        for _, e in ipairs(type(raw[2]) == "table" and raw[2] or {}) do
            out[#out + 1] = { kind = "other", spots = {} }
        end
    end
    local trig = quest.triggerEnd
    if type(trig) == "table" then
        local o = { kind = "place", count = 1, countKnown = true, spots = {} }
        for area, list in pairs(type(trig[2]) == "table" and trig[2] or {}) do
            local map = zones:GetUiMapIdByAreaId(area)
            if map and type(list) == "table" then
                for _, p in ipairs(list) do
                    if type(p) == "table" and tonumber(p[1]) and tonumber(p[2]) and not (p[1] == -1 and p[2] == -1) then
                        o.spots[#o.spots + 1] = { map = map, x = p[1], y = p[2] }
                    end
                end
            end
        end
        out[#out + 1] = o
    end
    -- Questie has no kill counts: the quest log has them, for a quest being worked on (by the id the game knows it by).
    local sid = ServerId(id or quest.Id)
    local logged = sid and C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(sid)
        and C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(sid)
    if ns:IsSecret(logged) then logged = nil end
    for i, o in ipairs(out) do
        local need = o.kind ~= "place" and type(logged) == "table" and type(logged[i]) == "table" and logged[i].numRequired
        local n = type(need) == "number" and not ns:IsSecret(need) and need
        if n and n > 0 then o.count, o.countKnown = n, true
        elseif o.kind ~= "place" then o.count, o.countKnown = nil, false end
    end
    return out
end

local function Ids(list) return type(list) == "table" and list or {} end

-- Questie's reputationReward: { { factionID, value }, ... } as a plain list (anything else: none).
local function Reputation(list)
    local out = {}
    if type(list) ~= "table" then return out end
    for _, e in ipairs(list) do
        local id, value = type(e) == "table" and tonumber(e[1]), type(e) == "table" and tonumber(e[2])
        if id and value and value > 0 then out[#out + 1] = { id, value } end
    end
    return out
end

-- Group and dungeon from a quest-log tag (Enum.QuestTag names; the client supplies the numbers).
local function TagKinds(tagID)
    local T = Enum and Enum.QuestTag
    if type(T) ~= "table" or tagID == nil then return false, false end
    local group = tagID == T.Group or tagID == T.Raid or tagID == T.Raid10 or tagID == T.Raid25
    return group and true or false, (T.Dungeon ~= nil and tagID == T.Dungeon) or false
end

local function Tags(id, quest, db, zones, state)
    local elite, group, dungeon = state.elite
    local sid = ServerId(id) or id
    local info = C_QuestLog and C_QuestLog.GetQuestTagInfo and C_QuestLog.GetLogIndexForQuestID
        and C_QuestLog.GetLogIndexForQuestID(sid) and C_QuestLog.GetQuestTagInfo(sid)
    if type(info) == "table" then
        elite = elite or ns.Yes(info.isElite)
        group, dungeon = TagKinds(not ns:IsSecret(info.tagID) and info.tagID or nil)
    else
        local function Ask(name)
            if type(db[name]) ~= "function" then return false end
            local ok, v = Try(db[name], id)
            return ok and v and true or false
        end
        group = Ask("IsGroupQuest") or Ask("IsRaidQuest")
        dungeon = Ask("IsDungeonQuest")
        local sort = tonumber(quest.zoneOrSort)
        if not dungeon and sort and sort > 0 and zones.IsDungeonZone then
            local ok, d = Try(zones.IsDungeonZone, sort)
            dungeon = ok and d and true or false
        end
    end
    return elite and true or false, group, dungeon
end

-- Escort quests: the data does not mark them, so this is our own list { [questID] = true }.
-- A small starter set from memory; CHECK THESE IN THE GAME and add the rest.
ns.PLANNER_ESCORTS = {
    [219] = true,     -- Missing In Action (Corporal Keeshan, Redridge Mountains)
    [1222] = true,    -- Stinky's Escape (Dustwallow Marsh)
}

-- Class quests: { [classFile] = { { id = questID, level = n, kind = "always"|"fit", parts = n }, ... } }.
-- "always": its hub is planned first; "fit": only when it lies near the route. parts: quests in its chain.
-- A starter set from memory (ids, levels and parts are all to be checked): the class path needs rec.doable
-- (Questie's IsDoable knows class and race), so a wrong id is never planned for the wrong class.
ns.PLANNER_CLASS_QUESTS = {
    -- check in game
    WARRIOR = { { id = 1638, level = 10, kind = "always", parts = 3 }, { id = 1718, level = 30, kind = "fit", parts = 1 } },
    -- check in game
    HUNTER = { { id = 6063, level = 10, kind = "always", parts = 3 }, { id = 6064, level = 20, kind = "fit", parts = 2 } },
    -- check in game
    MAGE = { { id = 1860, level = 10, kind = "always", parts = 2 } },
    -- check in game
    PRIEST = { { id = 5623, level = 10, kind = "always", parts = 2 } },
    -- check in game
    ROGUE = { { id = 2218, level = 10, kind = "always", parts = 2 } },
    -- check in game
    WARLOCK = { { id = 1685, level = 10, kind = "always", parts = 3 } },
    -- check in game
    PALADIN = { { id = 1642, level = 12, kind = "always", parts = 3 } },
    -- check in game
    SHAMAN = { { id = 1516, level = 4, kind = "always", parts = 4 } },
    -- check in game
    DRUID = { { id = 5921, level = 10, kind = "always", parts = 2 }, { id = 5061, level = 16, kind = "fit", parts = 1 } },
}

-- Classic dungeons: { name, minLevel, maxLevel, map, x, y, zone = Questie's area id, instance = the game's instance id
-- (GetInstanceInfo's 8th value), bosses, stone = its meeting stone's object id }. The dry-spell advice (PlannerAdvice.lua)
-- and the dungeon runs (PlannerDungeons.lua, through src.dungeons, which takes Questie's entrance and Questie's level
-- range, from its meeting stones, when it has them). The levels are the Classic-era recommended ranges (13.5 fix I3);
-- the boss counts the main bosses. CHECK IN GAME: entrances, area ids, instance ids, boss counts.
ns.PLANNER_DUNGEONS = {
    -- check in game (the entrance: inside Orgrimmar, the Cleft of Shadow, map 1454; Questie's entrance corrects it)
    { name = "Ragefire Chasm", minLevel = 13, maxLevel = 18, map = 1411, x = 52, y = 11, zone = 2437, instance = 389, bosses = 4, stone = 179596 },
    { name = "Wailing Caverns", minLevel = 17, maxLevel = 24, map = 1413, x = 46, y = 36, zone = 718, instance = 43, bosses = 8, stone = 178884 },
    { name = "The Deadmines", minLevel = 17, maxLevel = 26, map = 1436, x = 43, y = 72, zone = 1581, instance = 36, bosses = 6, stone = 178834 },
    { name = "Shadowfang Keep", minLevel = 22, maxLevel = 30, map = 1421, x = 44, y = 67, zone = 209, instance = 33, bosses = 8, stone = 178845 },
    { name = "Blackfathom Deeps", minLevel = 24, maxLevel = 32, map = 1440, x = 14, y = 14, zone = 719, instance = 48, bosses = 8, stone = 178828 },
    { name = "The Stockade", minLevel = 24, maxLevel = 32, map = 1453, x = 41, y = 57, zone = 717, instance = 34, bosses = 5, stone = 179595 },
    { name = "Gnomeregan", minLevel = 29, maxLevel = 38, map = 1426, x = 24, y = 38, zone = 721, instance = 90, bosses = 6, stone = 179555 },
    { name = "Razorfen Kraul", minLevel = 29, maxLevel = 38, map = 1413, x = 42, y = 90, zone = 491, instance = 47, bosses = 6, stone = 178825 },
    -- (four wings under one area id and one instance id: a run is one wing, its quests may span more)
    { name = "Scarlet Monastery", minLevel = 26, maxLevel = 45, map = 1420, x = 84, y = 35, zone = 796, instance = 189, bosses = 4, stone = 178844 },
    { name = "Razorfen Downs", minLevel = 37, maxLevel = 46, map = 1413, x = 50, y = 93, zone = 722, instance = 129, bosses = 5, stone = 178824 },
    { name = "Uldaman", minLevel = 41, maxLevel = 51, map = 1418, x = 42, y = 12, zone = 1337, instance = 70, bosses = 9, stone = 178833 },
    { name = "Zul'Farrak", minLevel = 44, maxLevel = 54, map = 1446, x = 39, y = 21, zone = 1176, instance = 209, bosses = 8, stone = 178829 },
    { name = "Maraudon", minLevel = 46, maxLevel = 55, map = 1443, x = 29, y = 62, zone = 2100, instance = 349, bosses = 7, stone = 178827 },
    { name = "The Temple of Atal'Hakkar", minLevel = 50, maxLevel = 60, map = 1435, x = 70, y = 54, zone = 1477, instance = 109, bosses = 8, stone = 179554 },
}

-- The id the game knows a quest by in your log: its own, or the one it was matched to (PlannerRecorders.lua); nil when
-- it is not in your log. (A quest matched by its title, ns.PlannerCandidates, is in your log from then on.)
ServerId = function(id)
    if ns.PlannerServerId then return ns.PlannerServerId(id) end
    local QL = C_QuestLog
    if not (QL and QL.IsOnQuest) then return nil end
    local ok, v = Try(QL.IsOnQuest, id)
    return (ok and ns.Yes(v)) and id or nil
end
local function InLog(id) return ServerId(id) ~= nil end

-- A Questie quest as a plain record, or nil when it cannot be placed on a known map (a quest in the
-- log is kept even then: an item, object or drop started it, but its objectives and hand-in count).
local function Record(env, id)
    local db, zones, xpMod = env.db, env.zones, env.xp
    local quest = db.GetQuest(id)
    if type(quest) ~= "table" then return nil end
    local by = type(quest.startedBy) == "table" and quest.startedBy or {}
    local fin = type(quest.finishedBy) == "table" and quest.finishedBy or {}
    local starts, ends = {}, {}
    for _, npc in ipairs(Ids(by[1])) do Merge(starts, Spots(db, zones, npc)) end
    -- Started by an item that an NPC drops: the start is where that NPC stands (the planner decides whether it is near the route).
    local fromItem
    if #starts == 0 and type(db.QueryItemSingle) == "function" then
        for _, item in ipairs(Ids(by[3])) do
            if type(item) == "number" and not fromItem then
                local drops = db.QueryItemSingle(item, "npcDrops")
                local spots = {}
                for _, npc in ipairs(type(drops) == "table" and drops or {}) do Merge(spots, Spots(db, zones, npc)) end
                if #spots > 0 then
                    local name = db.QueryItemSingle(item, "name")
                    fromItem = { id = item, name = type(name) == "string" and name or format(ns:Tr("Item %d"), item) }
                    starts = spots
                end
            end
        end
    end
    if #starts == 0 and not InLog(id) then return nil end
    for _, npc in ipairs(Ids(fin[1])) do Merge(ends, Spots(db, zones, npc)) end
    local state = {}
    local objectives = Objectives(db, zones, quest, state, id)
    local elite, group, dungeon = Tags(id, quest, db, zones, state)
    local repeatable = tonumber(quest.specialFlags) and tonumber(quest.specialFlags) % 2 == 1 or false
    return {
        id = id, name = type(quest.name) == "string" and quest.name or format(ns:Tr("Quest %d"), id), sort = tonumber(quest.zoneOrSort),
        level = tonumber(quest.level) or tonumber(quest.questLevel) or 1,
        minLevel = tonumber(quest.requiredLevel) or 1,
        xp = tonumber(xpMod:GetQuestLogRewardXP(id)) or 0,
        starts = starts, ends = ends, objectives = objectives,
        pre = Ids(quest.preQuestGroup), preAny = Ids(quest.preQuestSingle), exclusive = Ids(quest.exclusiveTo),
        nextQuest = (tonumber(quest.nextQuestInChain) or 0) > 0 and tonumber(quest.nextQuestInChain) or nil,
        elite = elite, group = group, dungeon = dungeon, repeatable = repeatable,
        reputation = Reputation(quest.reputationReward),
        fromItem = fromItem, escort = ns.PLANNER_ESCORTS[id] == true,
        doable = db.IsDoable(id) and true or false,
    }
end

local mapCache = nil              -- quest ids by zone map (one scan of every quest a session; a reset empties it)
ns.PLANNER_GATHER_MAPS = 6       -- maps whose Questie gathering nodes are kept at once (the least recently asked go first)
local gatherCache, gatherOrder, gatherAreas = {}, {}, {}   -- nodes by map, the maps kept (oldest first), area -> map (a reset empties them)
local zoneCache, grindCache = {}, {}   -- dungeon quest ids by area, grinding spots by level and continent (static data: a reset empties them)
local dungeonCache = nil               -- src.dungeons(): the list, made once a session (a reset empties it)
local recCache, cacheLevel = {}, nil   -- built records by quest id (not those in the log); emptied on a new level and by a reset
local logToken, logRecs = nil, {}      -- the records of logged quests, for the one plan being made (ns.PlannerPlanToken)
local failed = {}                      -- quests whose record failed: told once a session (ns.errors)
local builtSource                      -- the Questie source last built, and the modules it was built on

-- Has `flags` the single bit `mask`? (bit.band when the client has it, else plain arithmetic.)
local function HasFlag(flags, mask)
    flags, mask = tonumber(flags), tonumber(mask)
    if not (flags and mask and mask > 0) then return false end
    local band = type(bit) == "table" and bit.band
    if type(band) == "function" then
        local ok, r = pcall(band, flags, mask)
        if ok and type(r) == "number" then return r == mask end
    end
    return math.floor(flags / mask) % 2 == 1
end

-- The ids in one of Questie's pointer tables. They are maps keyed by id (the values may be offsets
-- into its data, not ids); only a plain sequence of numbers is read as a list of ids.
local function PointerIds(t)
    local out, n = {}, #t
    if n > 0 and t[1] ~= nil then
        local count, numbers = 0, true
        for _, v in pairs(t) do
            count = count + 1
            if type(v) ~= "number" then numbers = false end
        end
        if count == n and numbers then
            for i = 1, n do out[i] = t[i] end
            return out
        end
    end
    for k in pairs(t) do if type(k) == "number" then out[#out + 1] = k end end
    return out
end

-- Questie's two big id tables (QuestPointers, NPCPointers), read once per table a slice at a time: one
-- pass collects the keys and values (yielding every 64 steps, outside the pcall), and a plain sequence of
-- numbers gives its values, as PointerIds reads them. Kept for the session against that table (Questie
-- replaces the table when it rebinds, and a new one is read again). nil means "not ready yet": the table
-- is missing, a step failed or saw a key twice (it changed under the walk), or it was replaced meanwhile.
-- How sure that is: a replaced table is always caught; a table grown in place is caught almost always
-- (a rehash reorders the walk, so keys come back twice), not always: no guarantee rests on it.
-- The list returned is shared (kept for the session): do not modify it; src.ids() hands out a copy.
local ID_SLICE = 64
local IdSet                       -- (below)
local idLists = {}                -- by name: { t = the table read, ids = its ids }
local function IdTable(name)
    local db = Import("QuestieDB")
    if not db then return nil end
    local ok, t = Try(function() return db[name] end)
    if ok and type(t) == "table" then return t end
end
local function IdList(name)
    local t = IdTable(name)
    if not t then return nil end
    local hit = idLists[name]
    if hit and hit.t == t then return hit.ids end
    local seen, keys, count, numbers, size = {}, {}, 0, true, #t
    local k
    while true do
        local ok, nk, nv = pcall(next, t, k)
        if not ok then return nil end
        if nk == nil then break end
        if seen[nk] ~= nil then return nil end
        seen[nk] = nv
        count = count + 1
        if type(nk) == "number" then keys[#keys + 1] = nk end
        if type(nv) ~= "number" then numbers = false end
        k = nk
        if count % ID_SLICE == 0 then ns.PlannerYield() end
    end
    if #t ~= size or IdTable(name) ~= t then return nil end
    local ids = keys
    if numbers and count > 0 and #keys == count then
        local list = {}
        for i = 1, count do
            if i % ID_SLICE == 0 then ns.PlannerYield() end
            local id = seen[i]
            if id == nil then list = nil; break end
            list[i] = id
        end
        if list then ids = list end
    end
    idLists[name] = { t = t, ids = ids, values = ids ~= keys }
    return ids
end
-- Is an id in that list? fn(id) -> true/false, for a list IdList has read (nil otherwise). A table keyed by id
-- is asked directly; a plain sequence of ids gets a set, made once.
IdSet = function(name)
    local hit = idLists[name]
    if not hit then return nil end
    if not hit.values then
        local t = hit.t
        return function(id) local ok, v = Try(function() return t[id] end); return ok and v ~= nil end
    end
    if not hit.set then
        hit.set = {}
        for _, id in ipairs(hit.ids) do hit.set[id] = true end
    end
    local set = hit.set
    return function(id) return set[id] == true end
end

-- Gathering nodes in Questie's object data. Questie has no "herb" or "ore" flag, so the objects are named
-- here: { [objectID] = { skill = 182 (Herbalism) or 186 (Mining), min = the skill rank needed } }.
-- From memory: CHECK THEM IN THE GAME (the ids, and the rank each needs) before trusting them.
ns.PLANNER_GATHER_OBJECTS = {
    [1617] = { skill = 182, min = 1 },      -- Silverleaf
    [1618] = { skill = 182, min = 1 },      -- Peacebloom
    [1619] = { skill = 182, min = 15 },     -- Earthroot
    [1620] = { skill = 182, min = 50 },     -- Mageroyal
    [1621] = { skill = 182, min = 70 },     -- Briarthorn
    [2045] = { skill = 182, min = 85 },     -- Stranglekelp
    [1622] = { skill = 182, min = 100 },    -- Bruiseweed
    [1623] = { skill = 182, min = 115 },    -- Wild Steelbloom
    [1628] = { skill = 182, min = 120 },    -- Grave Moss
    [1624] = { skill = 182, min = 125 },    -- Kingsblood
    [2041] = { skill = 182, min = 150 },    -- Liferoot
    [2042] = { skill = 182, min = 160 },    -- Fadeleaf
    [2046] = { skill = 182, min = 170 },    -- Goldthorn
    [2043] = { skill = 182, min = 185 },    -- Khadgar's Whisker
    [2044] = { skill = 182, min = 195 },    -- Wintersbite
    [2866] = { skill = 182, min = 205 },    -- Firebloom
    [142140] = { skill = 182, min = 210 },  -- Purple Lotus
    [142141] = { skill = 182, min = 220 },  -- Arthas' Tears
    [142142] = { skill = 182, min = 230 },  -- Sungrass
    [142143] = { skill = 182, min = 235 },  -- Blindweed
    [142144] = { skill = 182, min = 245 },  -- Ghost Mushroom
    [142145] = { skill = 182, min = 250 },  -- Gromsblood
    [176583] = { skill = 182, min = 260 },  -- Golden Sansam
    [176584] = { skill = 182, min = 270 },  -- Dreamfoil
    [176586] = { skill = 182, min = 280 },  -- Mountain Silversage
    [176587] = { skill = 182, min = 285 },  -- Plaguebloom
    [176588] = { skill = 182, min = 290 },  -- Icecap
    [176589] = { skill = 182, min = 300 },  -- Black Lotus
    [1731] = { skill = 186, min = 1 },      -- Copper Vein
    [1610] = { skill = 186, min = 65 },     -- Incendicite Mineral Vein
    [1732] = { skill = 186, min = 65 },     -- Tin Vein
    [2653] = { skill = 186, min = 75 },     -- Lesser Bloodstone Deposit
    [1733] = { skill = 186, min = 75 },     -- Silver Vein
    [1735] = { skill = 186, min = 125 },    -- Iron Deposit
    [1734] = { skill = 186, min = 155 },    -- Gold Vein
    [2040] = { skill = 186, min = 175 },    -- Mithril Deposit
    [165658] = { skill = 186, min = 230 },  -- Dark Iron Deposit
    [2047] = { skill = 186, min = 230 },    -- Truesilver Deposit
    [324] = { skill = 186, min = 245 },     -- Small Thorium Vein
    [175404] = { skill = 186, min = 275 },  -- Rich Thorium Vein
    -- other object ids of the same nodes in some zones (from memory, CHECK THEM IN THE GAME or in Questie's objectDB)
    [3763] = { skill = 186, min = 1 },      -- Copper Vein
    [103713] = { skill = 186, min = 1 },    -- Copper Vein
    [2055] = { skill = 186, min = 1 },      -- Copper Vein
    [103711] = { skill = 186, min = 65 },   -- Tin Vein
    [105569] = { skill = 186, min = 75 },   -- Silver Vein
    [150080] = { skill = 186, min = 155 },  -- Gold Vein
    [150079] = { skill = 186, min = 175 },  -- Mithril Deposit
    [176645] = { skill = 186, min = 175 },  -- Mithril Deposit
    [150081] = { skill = 186, min = 230 },  -- Truesilver Deposit
    [150082] = { skill = 186, min = 245 },  -- Small Thorium Vein
    [176643] = { skill = 186, min = 245 },  -- Small Thorium Vein
    [73940] = { skill = 186, min = 75 },    -- Ooze Covered Silver Vein
    [73941] = { skill = 186, min = 155 },   -- Ooze Covered Gold Vein
    [123308] = { skill = 186, min = 230 },  -- Ooze Covered Truesilver Deposit
    [123309] = { skill = 186, min = 175 },  -- Ooze Covered Mithril Deposit
    [123310] = { skill = 186, min = 175 },  -- Ooze Covered Mithril Deposit (which ooze vein each of 123308-123310 is: check)
    [123848] = { skill = 186, min = 245 },  -- Ooze Covered Thorium Vein
    [177388] = { skill = 186, min = 275 },  -- Ooze Covered Rich Thorium Vein
}

-- One gathering object's spawns as a flat list { area, x, y } and its name (read through Try by the caller).
local function ObjectSpawns(db, id)
    if db.ObjectPointers[id] == nil then return nil end
    local spawns, name = db.QueryObjectSingle(id, "spawns"), db.QueryObjectSingle(id, "name")
    if type(spawns) ~= "table" or type(name) ~= "string" or name == "" then return nil end
    local out = {}
    for area, list in pairs(spawns) do
        if type(list) == "table" then
            for _, p in ipairs(list) do
                if type(p) == "table" and tonumber(p[1]) and tonumber(p[2]) and not (p[1] == -1 and p[2] == -1) then
                    out[#out + 1] = { area, tonumber(p[1]), tonumber(p[2]) }
                end
            end
        end
    end
    return out, name
end

-- Where the places of one kind are. Kinds: innkeeper, repair, classTrainer, mailbox, vendor (arg
-- Food, Drink or Ammo), professionTrainer (arg a skill line id) and mountVendor. Each is a list of
-- { name, map, x, y, id }, one per spawn; gathered once per session per (kind, arg).
-- Mount vendors: best-known classic NPC ids per race file; CHECK THEM IN THE GAME before trusting them.
ns.PLANNER_MOUNT_VENDORS = {
    Human = { 384 },       -- Katie Hunter, Elwynn Forest (horses)
    Dwarf = { 1261 },      -- Ultham Ironhorn, Dun Morogh (rams)
    Gnome = { 7955 },      -- Binjy Featherwhistle, Dun Morogh (mechanostriders)
    NightElf = { 4730 },   -- Lelanai, Darnassus (nightsabers)
    Orc = { 3362 },        -- Ogunaro Wolfrunner, Orgrimmar (wolves)
    Troll = { 7952 },      -- Zjolnir, Durotar (raptors)
    Tauren = { 3685 },     -- Harb Clawhoof, Mulgore (kodos)
    Scourge = { 4731 },    -- Zachariah Post, Tirisfal Glades (skeletal horses)
    ["High Order Skyborne"] = {},   -- TODO: Forever's new races: fill in once the vendors are known
    ["Windshaper Skyborne"] = {},   -- TODO
}

-- (no scan for class trainers: the flag finds every trainer of every class and profession)
local FLAG_NAMES = { innkeeper = "INNKEEPER", repair = "REPAIR" }
local TOWNSFOLK_KEY = { innkeeper = "Innkeeper", repair = "Repair", classTrainer = "Class Trainer", mailbox = "Mailbox" }
local placeCaches = { questie = {}, log = {}, questieScan = {}, logScan = {} }   -- one per source: the log source never sees Questie's places

local function Plain(v) return type(v) == "table" and v or nil end

-- Read a field through pcall; nil when anything goes wrong.
local function Dig(f)
    local ok, v = Try(f)
    if ok then return v end
end

-- Is this NPC one the player may deal with? friendlyToFaction: nil, "AH", or the player's letter.
local function Friendly(f)
    if f == nil or f == "AH" then return true end
    local ok, faction = Try(UnitFactionGroup, "player")
    if not ok then return false end
    local mine = ns.Is(faction, "Alliance") and "A" or ns.Is(faction, "Horde") and "H" or nil
    return mine ~= nil and f == mine
end

-- The ids of a kind from Questie's saved townsfolk tables and Townsfolk module, or nil if none are there.
local function KnownIds(kind, arg)
    local char = Dig(function() return _G.Questie.db.char end)
    if kind == "vendor" then
        local list = Plain(char) and Plain(char.vendorList) and Plain(char.vendorList[arg])
        return list and PointerIds(list) or nil
    elseif kind == "professionTrainer" then
        local mod = Import("Townsfolk")
        local list = mod and Plain(mod.professionTrainers) and Plain(mod.professionTrainers[arg])
        return list and PointerIds(list) or nil
    elseif kind == "mountVendor" then
        local ok, _, file = Try(UnitRace, "player")
        local list = ok and type(file) == "string" and Plain(ns.PLANNER_MOUNT_VENDORS[file])
        return list and PointerIds(list) or nil
    end
    local key = TOWNSFOLK_KEY[kind]
    local list = key and Plain(char) and Plain(char.townsfolk) and Plain(char.townsfolk[key])
    if not list then
        local mod = Import("Townsfolk")
        list = key and mod and Plain(mod.townsfolk) and Plain(mod.townsfolk[key])
    end
    return list and PointerIds(list) or nil
end

-- Every id carrying a flag, by scanning Questie's NPC table (the fallback when no list is saved);
-- nil while Questie has no flags or no NPC table yet (not ready: the scan is not kept).
local function FlagIds(env, flagName)
    local db, out = env.db, {}
    local flagsOk, flags = Try(function() return db.npcFlags end)
    local mask = flagsOk and type(flags) == "table" and tonumber(flags[flagName])
    if not mask then return nil end
    local ids = IdList("NPCPointers")
    if not ids then return nil end
    for _, id in ipairs(ids) do
        ns.PlannerYield()
        local ok, f = Try(db.QueryNPCSingle, id, "npcFlags")
        if ok and HasFlag(f, mask) then
            local okN, name = Try(db.QueryNPCSingle, id, "name")
            if not (okN and type(name) == "string" and name:sub(1, 5) == "[DND]") then out[#out + 1] = id end
        end
    end
    return out
end

local function Resolve(env, ids, object, fallbackName)
    local db, zones, out = env.db, env.zones, {}
    for _, id in ipairs(ids) do
        ns.PlannerYield()
        if type(id) == "number" then
            local query = object and db.QueryObjectSingle or db.QueryNPCSingle
            local okF, friendly = true, nil
            if not object then okF, friendly = Try(query, id, "friendlyToFaction") end
            if okF and Friendly(friendly) then
                local okN, name = Try(query, id, "name")
                local okS, spots = Try(Spots, db, zones, id, object)
                if not (okN and type(name) == "string") then name = fallbackName end
                if type(name) == "string" and okS then
                    for _, sp in ipairs(spots) do out[#out + 1] = { name = name, map = sp.map, x = sp.x, y = sp.y, id = id } end
                end
            end
        end
    end
    return out
end

local function MyFaction()
    local ok, faction = Try(UnitFactionGroup, "player")
    if ok and type(faction) == "string" and not ns:IsSecret(faction) and faction ~= "" then return faction end
end

-- Places you have used, of your faction (an entry with no faction is not used). For vendors,
-- `repairOnly` keeps those that could repair. Each saved entry keeps one copy for the session (the
-- planner caches a place's world position on it; nothing is added to the saved entry).
local seenCopies = setmetatable({}, { __mode = "k" })
local function SeenPlaces(kind, repairOnly)
    local root = ns.root
    local list = type(root) == "table" and type(root.plannerSeen) == "table" and root.plannerSeen[kind]
    local out, faction = {}, MyFaction()
    if not faction then return out end
    for _, p in ipairs(type(list) == "table" and list or {}) do
        if type(p) == "table" and p.faction == faction and type(p.name) == "string" and tonumber(p.map) and tonumber(p.x) and tonumber(p.y)
            and (not repairOnly or p.repair == true) then
            local copy = seenCopies[p]
            if not copy or copy.name ~= p.name or copy.map ~= p.map or copy.x ~= p.x or copy.y ~= p.y then
                copy = { name = p.name, map = p.map, x = p.x, y = p.y }
                seenCopies[p] = copy
            end
            out[#out + 1] = copy
        end
    end
    return out
end

-- Seen places that join a kind's list. Merchants you opened are not food, drink or ammo vendors:
-- they join "repair" only when they could repair, and "anyVendor" (to sell to) is all of them.
local function SeenFor(kind, arg)
    if kind == "mailbox" then return SeenPlaces("mailbox") end
    if kind == "repair" then return SeenPlaces("vendor", true) end
    if kind == "anyVendor" then return SeenPlaces("vendor") end
    return {}
end

local function Places(which, env, kind, arg)
    local cache, scans = placeCaches[which], placeCaches[which .. "Scan"]
    local key = tostring(kind) .. "\0" .. tostring(arg)
    local hit = cache[key]
    if not hit then
        hit = {}
        if env and kind ~= "anyVendor" then
            local ids = KnownIds(kind, arg)
            if ids ~= nil then
                if kind ~= "mailbox" or type(env.db.QueryObjectSingle) == "function" then
                    hit = Resolve(env, ids, kind == "mailbox", kind == "mailbox" and ns:Tr("Mailbox") or nil)
                end
                cache[key] = hit
            elseif FLAG_NAMES[kind] then
                -- No saved list (Questie may not have built it yet: it is looked at again each call).
                -- The NPC scan is costly and is done once per session per kind, even when it finds nothing.
                hit = scans[kind]
                if not hit then
                    local ids = FlagIds(env, FLAG_NAMES[kind])
                    hit = ids and Resolve(env, ids, false) or {}
                    if ids then scans[kind] = hit end          -- (not ready: asked again next time)
                end
            end
        else
            cache[key] = hit
        end
    end
    local seen = SeenFor(kind, arg)
    if #seen == 0 then return hit end
    local out = {}
    for _, p in ipairs(hit) do out[#out + 1] = p end
    for _, p in ipairs(seen) do out[#out + 1] = p end
    return out
end

-- Questie as a source, or nil and why: "missing", "waiting" (not ready yet), "changed".
function ns.PlannerSource()
    if not IsLoaded() then return nil, "missing" end
    local Q = _G.Questie
    local api = type(Q) == "table" and Q.API
    if type(api) ~= "table" or type(api.RegisterOnReady) ~= "function" then return nil, "changed" end
    if api.isReady then waiting = false else
        if not waiting then
            waiting = true
            local ok = Try(api.RegisterOnReady, function()
                waiting = false
                if ns.PlannerReplan then ns.PlannerReplan(ns, "questie") end
            end)
            if not ok then waiting = false; return nil, "changed" end
        end
        return nil, "waiting"
    end
    local meta = C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("Questie", "X-QuestieDB-Contract")
    if meta ~= ns.PLANNER_CONTRACT then return nil, "changed" end
    local env = { db = Import("QuestieDB"), xp = Import("QuestXP"), zones = Import("ZoneDB") }
    if not (env.db and env.xp and env.zones) then return nil, "changed" end
    if type(env.db.QuestPointers) ~= "table" or type(env.db.GetQuest) ~= "function"
        or type(env.db.IsDoable) ~= "function" or type(env.db.QueryNPCSingle) ~= "function"
        or type(env.xp.GetQuestLogRewardXP) ~= "function" or type(env.zones.GetUiMapIdByAreaId) ~= "function" then
        return nil, "changed"
    end
    -- (the same Questie modules: the source already built is handed out again, not a new one each call)
    local kept = builtSource
    if kept and kept.db == env.db and kept.xp == env.xp and kept.zones == env.zones then return kept.src end
    local src = { kind = "questie" }
    builtSource = { db = env.db, xp = env.xp, zones = env.zones, src = src }
    -- Has Questie's quest list been read? (Not yet: the plan waits for it, PlannerSource's "waiting".)
    function src.ready() return IdList("QuestPointers") ~= nil end
    -- A copy of the shared list, so a caller may sort or change it (not ready yet: none this time), and the
    -- quests in your log that Questie does not list (src.quest gives them from the log).
    function src.ids()
        local ids, out = IdList("QuestPointers"), {}
        for i, id in ipairs(ids or {}) do
            if i % ID_SLICE == 0 then ns.PlannerYield() end
            out[i] = id
        end
        local listed = ids and IdSet("QuestPointers") or nil
        for _, id in ipairs(ns.PlannerLogSource().ids()) do
            if not (listed and listed(id)) and InLog(id) then out[#out + 1] = id end
        end
        return out
    end
    -- Is this quest repeatable (Questie's flags)? Cheap: no record is built. (A hand-in kept never makes one done.)
    function src.repeatable(id)
        if type(env.db.QueryQuestSingle) ~= "function" then return false end
        local ok, v = Try(env.db.QueryQuestSingle, id, "specialFlags")
        v = ok and tonumber(v)
        return v ~= nil and v % 2 == 1
    end
    -- A new level empties the record cache (the level window moved).
    function src.begin(level)
        if level ~= cacheLevel then recCache, cacheLevel = {}, level end
    end
    -- Cheap: could this quest be inside the level window? (Questie's level, without building a record.)
    -- lo, hi: the window's bounds (level - 4 and level + 2 when not given).
    function src.inRange(id, level, lo, hi)
        if InLog(id) then return true end
        local lv
        if type(env.db.QueryQuestSingle) == "function" then
            local ok, v = Try(env.db.QueryQuestSingle, id, "questLevel")
            if ok then lv = tonumber(v) end
        end
        if lv == nil then
            local ok, q = Try(env.db.GetQuest, id)
            if ok and type(q) == "table" then lv = tonumber(q.level) or tonumber(q.questLevel) end
        end
        if not lv or lv <= 0 then return true end        -- unknown or scaling: the record decides
        return lv >= (tonumber(lo) or level - 4) and lv <= (tonumber(hi) or level + 2)
    end
    -- A quest as a record. One in your log is built again for each plan (its progress changes), once per plan;
    -- one Questie can't give (not listed, or its record fails) comes from the quest log. A record that fails is
    -- left out for the session and written to ns.errors once: it never turns the whole source to the log.
    function src.quest(id)
        local logged = InLog(id)
        local hit, token
        if logged then
            token = ns.PlannerPlanToken and ns.PlannerPlanToken() or nil
            if token then
                if token ~= logToken then logToken, logRecs = token, {} end
                hit = logRecs[id]
                if hit ~= nil then return hit or nil end
            end
        else
            hit = recCache[id]
        end
        if hit ~= nil and hit ~= false then
            local okD, doable = Try(env.db.IsDoable, id)    -- (a hand-in can open a follow-up)
            if okD then hit.doable = doable and true or false end
            return hit
        end
        if hit == false then return nil end
        local ok, rec = Try(Record, env, id)
        if not ok then
            if not failed[id] then
                failed[id] = true
                if type(ns.errors) == "table" and #ns.errors < 60 then ns.errors[#ns.errors + 1] = "Planner source: quest " .. tostring(id) .. ": " .. tostring(rec) end
            end
            rec = nil
        end
        if not rec and logged then rec = ns.PlannerLogSource().quest(id) end
        if logged then
            if token then logRecs[id] = rec or false end
        else
            recCache[id] = rec or false
        end
        return rec
    end
    -- The ids of the quests Questie files under one area (a dungeon's): read once a session per area.
    function src.zoneQuests(zone)
        if type(zone) ~= "number" then return {} end
        local hit = zoneCache[zone]
        if hit then return hit end
        hit = {}
        if type(env.db.QueryQuestSingle) == "function" then
            local ids = IdList("QuestPointers")
            if not ids then return {} end                   -- (not ready yet: not kept)
            for _, id in ipairs(ids) do
                ns.PlannerYield()
                local ok, v = Try(env.db.QueryQuestSingle, id, "zoneOrSort")
                if ok and tonumber(v) == zone then hit[#hit + 1] = id end
            end
        end
        zoneCache[zone] = hit
        return hit
    end
    -- The dungeons as { name, minLevel, maxLevel, map, x, y, zone, instance, bosses } (copies of ns.PLANNER_DUNGEONS):
    -- the entrance is Questie's (ZoneDB:GetDungeonLocation(area)[1] = { area, x, y }, its area through
    -- GetUiMapIdByAreaId) when Questie has that function and an entry, else the table's; the level range is Questie's
    -- (its meeting stone's, MeetingStones:GetLocalizedDungeonNameAndLevelRangeByObjectId(stone) = name, "(lo-hi)") when
    -- it has one that reads, else the table's. Made once a session. (Boss counts are the table's. The contract stays
    -- "4": the functions are probed.)
    function src.dungeons()
        if dungeonCache then return dungeonCache end
        local list = {}
        local where = env.zones.GetDungeonLocation
        local stones = Import("MeetingStones")
        local range = type(stones) == "table" and stones.GetLocalizedDungeonNameAndLevelRangeByObjectId or nil
        for _, d in ipairs(ns.PLANNER_DUNGEONS) do
            local e = {}
            for k, v in pairs(d) do e[k] = v end
            if type(range) == "function" and type(d.stone) == "number" then
                local ok, _, text = Try(range, stones, d.stone)
                local lo, hi
                if ok and type(text) == "string" and not ns:IsSecret(text) then lo, hi = text:match("^%((%d+)%-(%d+)%)$") end
                lo, hi = tonumber(lo), tonumber(hi)
                if lo and hi and lo >= 1 and lo <= hi and hi <= 100 then e.minLevel, e.maxLevel = lo, hi end
            end
            if type(where) == "function" and type(d.zone) == "number" then
                local ok, at = Try(where, env.zones, d.zone)
                local first = ok and type(at) == "table" and at[1] or nil
                local area, x, y
                if type(first) == "table" then area, x, y = tonumber(first[1]), tonumber(first[2]), tonumber(first[3]) end
                if area and x and y then
                    local okM, map = Try(env.zones.GetUiMapIdByAreaId, env.zones, area)
                    map = okM and tonumber(map) or nil
                    if map then e.map, e.x, e.y = map, x, y end
                end
            end
            list[#list + 1] = e
        end
        dungeonCache = list
        return list
    end
    -- The ids of the quests Questie files under an area that maps to this zone map (zoneOrSort, through the
    -- zone database): one scan of every quest per session, then read from the cache.
    function src.mapQuests(map)
        if type(map) ~= "number" or type(env.db.QueryQuestSingle) ~= "function" then return {} end
        if not mapCache then
            local scan, areas, ids = {}, {}, IdList("QuestPointers") or {}   -- (Questie's own list: the log's extra quests are not filed by zone)
            for _, id in ipairs(ids) do
                ns.PlannerYield()
                local ok, v = Try(env.db.QueryQuestSingle, id, "zoneOrSort")
                local area = ok and tonumber(v) or nil
                if area and area > 0 then
                    local m = areas[area]
                    if m == nil then
                        local okM, value = Try(env.zones.GetUiMapIdByAreaId, env.zones, area)
                        m = okM and tonumber(value) or false
                        areas[area] = m
                    end
                    if m then
                        scan[m] = scan[m] or {}
                        scan[m][#scan[m] + 1] = id
                    end
                end
            end
            if #ids == 0 then return {} end                 -- (Questie knows nothing yet: ask again later)
            mapCache = scan
        end
        return mapCache[map] or {}
    end
    -- Where to grind at this level: { { map, x, y, count, name, mobLevel } }, best first (at most 3). Hostile,
    -- non-elite monsters 0 to 2 levels above you, their spawns on a 200-yard grid on your continent. Read once per
    -- level per session (the scan is long: it goes a slice at a time).
    function src.grindSpots(level)
        level = tonumber(level)
        if not level then return {} end
        local here = ns.GuideHere and { ns.GuideHere() } or {}
        local hc = here[1] and ns.PlannerWorldPos(here[1], here[2], here[3])
        if not hc then return {} end
        local key = level .. ":" .. tostring(hc)
        if grindCache[key] then return grindCache[key] end
        local okF, faction = Try(UnitFactionGroup, "player")
        local mine = okF and (ns.Is(faction, "Alliance") and "A" or ns.Is(faction, "Horde") and "H") or nil
        local cells = {}
        local ids = IdList("NPCPointers")
        if not ids then return {} end                       -- (not ready yet: not kept)
        for _, id in ipairs(ids) do
            ns.PlannerYield()
            local okL, lo = Try(env.db.QueryNPCSingle, id, "minLevel")
            local okH, hi = Try(env.db.QueryNPCSingle, id, "maxLevel")
            lo, hi = tonumber(okL and lo), tonumber(okH and hi)
            if lo and hi and lo <= level + 2 and hi >= level then
                local okR, rank = Try(env.db.QueryNPCSingle, id, "rank")
                local okFr, friendly = Try(env.db.QueryNPCSingle, id, "friendlyToFaction")
                local okN, name = Try(env.db.QueryNPCSingle, id, "name")
                local okS, spots = Try(Spots, env.db, env.zones, id)
                if okR and okFr and okN and okS and (tonumber(rank) or 0) == 0 and friendly ~= "AH" and (friendly == nil or friendly ~= mine)
                    and type(name) == "string" and name ~= "" and name:sub(1, 5) ~= "[DND]" then
                    local mob = math.max(level, math.min(hi, level + 2))
                    for _, sp in ipairs(spots) do
                        local c, wx, wy = ns.PlannerWorldPos(sp.map, sp.x, sp.y)
                        if c == hc then
                            local ck = math.floor(wx / 200) .. ":" .. math.floor(wy / 200)
                            local cell = cells[ck]
                            if not cell then cell = { map = sp.map, x = sp.x, y = sp.y, count = 0, names = {}, mobs = 0 }; cells[ck] = cell end
                            cell.count, cell.mobs = cell.count + 1, cell.mobs + mob
                            cell.names[name] = (cell.names[name] or 0) + 1
                        end
                    end
                end
            end
        end
        -- the best 3 cells, in one pass (most monsters first; then by map, x and y)
        local function Better(a, b)
            if a.count ~= b.count then return a.count > b.count end
            if a.map ~= b.map then return a.map < b.map end
            if a.x ~= b.x then return a.x < b.x end
            return a.y < b.y
        end
        local list = {}
        for _, cell in pairs(cells) do
            ns.PlannerYield()
            if #list < 3 or Better(cell, list[#list]) then
                local i = #list + 1
                while i > 1 and Better(cell, list[i - 1]) do list[i] = list[i - 1]; i = i - 1 end
                list[i] = cell
                if #list > 3 then list[4] = nil end
            end
        end
        for i, cell in ipairs(list) do
            local best, bestN
            for name, n in pairs(cell.names) do
                if not bestN or n > bestN or (n == bestN and name < best) then best, bestN = name, n end
            end
            list[i] = { map = cell.map, x = cell.x, y = cell.y, count = cell.count, name = best, mobLevel = math.floor(cell.mobs / cell.count + 0.5) }
        end
        grindCache[key] = list
        return list
    end
    -- Questie's gathering nodes on a map: { { name, map, x, y, skill, min } }. Every object in
    -- ns.PLANNER_GATHER_OBJECTS is read for a map the first time it is asked (a failed read: that object
    -- has none there); the nodes of ns.PLANNER_GATHER_MAPS maps are kept, the least recently asked go first.
    function src.gatherNodes(map)
        if type(map) ~= "number" then return {} end
        local hit = gatherCache[map]
        if not hit then
            local db = env.db
            local okP, pointers = Try(function() return db.ObjectPointers end)
            if not (okP and type(pointers) == "table" and type(db.QueryObjectSingle) == "function") then return {} end
            hit = {}
            for id, def in pairs(ns.PLANNER_GATHER_OBJECTS) do
                ns.PlannerYield()
                local ok, spawns, name = Try(ObjectSpawns, db, id)
                if ok and spawns then
                    for _, p in ipairs(spawns) do
                        ns.PlannerYield()
                        local m = gatherAreas[p[1]]
                        if m == nil then
                            local okM, value = Try(env.zones.GetUiMapIdByAreaId, env.zones, p[1])
                            m = okM and tonumber(value) or false
                            gatherAreas[p[1]] = m
                        end
                        if m == map then hit[#hit + 1] = { name = name, map = m, x = p[2], y = p[3], skill = def.skill, min = def.min } end
                    end
                end
            end
            gatherCache[map] = hit
        end
        for i = #gatherOrder, 1, -1 do if gatherOrder[i] == map then table.remove(gatherOrder, i) end end
        gatherOrder[#gatherOrder + 1] = map
        while #gatherOrder > ns.PLANNER_GATHER_MAPS do gatherCache[table.remove(gatherOrder, 1)] = nil end
        return hit
    end
    function src.places(kind, arg) return Places("questie", env, kind, arg) end
    function src.inns() return Places("questie", env, "innkeeper") end
    return src
end

-- The quest log alone: only quests being worked on, with where each ends. (Every value the game gives is read
-- through pcall and checked before it is looked at: a hidden one counts as missing.)
local function LogNum(v) if type(v) == "number" and not ns:IsSecret(v) then return v end end
local function LogStr(v) if type(v) == "string" and not ns:IsSecret(v) and v ~= "" then return v end end
function ns.PlannerLogSource()
    local src = { kind = "log" }
    function src.ids()
        local out = {}
        local QL = C_QuestLog
        if not (QL and QL.GetNumQuestLogEntries and QL.GetInfo) then return out end
        local okN, n = Try(QL.GetNumQuestLogEntries)
        for i = 1, math.min(okN and LogNum(n) or 0, 200) do
            local ok, info = Try(QL.GetInfo, i)
            local id = ok and type(info) == "table" and not ns.Yes(info.isHeader) and LogNum(info.questID)
            if id then out[#out + 1] = id end
        end
        return out
    end
    function src.quest(id)
        local QL = C_QuestLog
        if not (QL and QL.GetLogIndexForQuestID) then return nil end
        local okI, index = Try(QL.GetLogIndexForQuestID, id)
        index = okI and LogNum(index)
        if not index then return nil end
        local info
        if QL.GetInfo then
            local ok, v = Try(QL.GetInfo, index)
            info = ok and type(v) == "table" and v or nil
        end
        local ends = {}
        if QL.GetNextWaypoint then
            local ok, map, x, y = Try(QL.GetNextWaypoint, id)
            map, x, y = ok and LogNum(map), ok and LogNum(x), ok and LogNum(y)
            if map and x and y then ends[1] = { map = map, x = x * 100, y = y * 100 } end
        end
        local tag
        if QL.GetQuestTagInfo then
            local ok, v = Try(QL.GetQuestTagInfo, id)
            tag = ok and type(v) == "table" and v or nil
        end
        local group, dungeon = TagKinds(tag and LogNum(tag.tagID) or nil)
        local title
        if QL.GetTitleForQuestID then
            local ok, v = Try(QL.GetTitleForQuestID, id)
            title = ok and LogStr(v)
        end
        return {
            id = id, name = title or (info and LogStr(info.title)) or format(ns:Tr("Quest %d"), id),
            level = info and LogNum(info.questLevel) or 1, minLevel = 1, xp = 0,
            starts = {}, ends = ends, objectives = {}, pre = {}, preAny = {}, exclusive = {},
            elite = tag and ns.Yes(tag.isElite) or false, group = group,
            dungeon = dungeon,
            repeatable = false, doable = true, reputation = {}, escort = ns.PLANNER_ESCORTS[id] == true,
        }
    end
    -- The logged quests whose next waypoint is on this map.
    function src.mapQuests(map)
        local out = {}
        local QL = C_QuestLog
        if type(map) ~= "number" or not (QL and QL.GetNextWaypoint) then return out end
        for _, id in ipairs(src.ids()) do
            local ok, m = Try(QL.GetNextWaypoint, id)
            if ok and tonumber(m) == map then out[#out + 1] = id end
        end
        return out
    end
    function src.places(kind, arg) return Places("log", nil, kind, arg) end
    function src.inns() return {} end
    function src.gatherNodes() return {} end
    return src
end

function ns.PlannerSourceReset()
    waiting, placeCaches, recCache, cacheLevel = false, { questie = {}, log = {}, questieScan = {}, logScan = {} }, {}, nil
    logToken, logRecs, failed, builtSource = nil, {}, {}, nil
    ns.plannerInns = nil                        -- (PlannerAdvice.lua: the innkeepers, read again from the new source)
    zoneCache, grindCache, mapCache, idLists = {}, {}, nil, {}
    dungeonCache = nil                          -- (src.dungeons: Questie's entrances read again)
    gatherCache, gatherOrder, gatherAreas = {}, {}, {}
    ns.plannerExploreMaps = {}                  -- (PlannerPath.lua: the maps known to report exploration)
end

-- (Places you have used, ns.PlannerSeen at a mailbox or a vendor, and ns.PLANNER_SEEN_CAP: in the main add-on,
-- PlannerRecorders.lua.)

------------------------------------------------------------------------------------------
-- Timed quests known before you take them. Questie has no timer data, so there are two sources of
-- our own: ns.PLANNER_TIMED (written by hand) and a per-account memory of every quest any of your
-- characters accepted with a clock on it (ns.root.plannerTimed[questID] = { secs = seconds, seen = day };
-- an older plain number reads as { secs = n }; at most
-- ns.PLANNER_TIMED_CAP, the oldest `seen` go first). The route plans such a quest as a timed run before you take it.
------------------------------------------------------------------------------------------
ns.PLANNER_TIMED = {}             -- { [questID] = seconds }: fill from the in-game checks

local function Seconds(v) if type(v) == "number" and not ns:IsSecret(v) and v > 0 then return v end end

-- How long a quest gives you, in seconds, when it is known to be timed; else nil.
function ns.PlannerTimedQuest(id)
    id = tonumber(id)
    if not id then return nil end
    local s = Seconds(ns.PLANNER_TIMED[id])
    if s then return s end
    local root = ns.root
    local mem = type(root) == "table" and type(root.plannerTimed) == "table" and root.plannerTimed or nil
    local e = mem and mem[id]
    if type(e) == "table" then e = e.secs end
    return Seconds(e)
end

-- (The memory is written by ns.PlannerRecordTimed, at QUEST_ACCEPTED, in the main add-on: PlannerRecorders.lua.)
ns.FolderFileDone("planner", "PlannerSource.lua")
