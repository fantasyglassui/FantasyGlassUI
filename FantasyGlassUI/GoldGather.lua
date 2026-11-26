-- Ways to make gold: Gathering (group C). Plugs into Gold.lua through ns.GoldRegister.
local _, ns = ...

------------------------------------------------------------------------------------------
-- Gathering: the herb and ore nodes you have gathered (one memory with the planner's shape), what
-- each kind of node gave you, and how much an hour of gathering on a map brought. From these, a loop
-- of the nodes you know, a guess at where to try next for your skill, or what you measured.
--
-- Saved (account-wide, made only when something is written):
--   goldNodesSeen[map] = { { name, x, y, skill } }        (the planner's plannerNodesSeen shape)
--   goldNodeItems[name] = { n, items = { [id] = count } }
--   goldGather[map] = { secs, n, items = { [id] = count }, day }
------------------------------------------------------------------------------------------
local type, tonumber, pairs, ipairs = type, tonumber, pairs, ipairs
local floor, max, min, sqrt, huge = math.floor, math.max, math.min, math.sqrt, math.huge

local HERBALISM, MINING, SKINNING = 182, 186, 393
local function NodeYards()             -- two gatherings this close are one node (the planner's)
    local v = ns.PLANNER_NODE_YARDS
    return (type(v) == "number" and v > 0) and v or 10
end
local NODE_CAP = 300                   -- nodes kept per map (the planner's)
local NAME_CAP = 200                   -- node names whose loot is kept
local LOOT_SECONDS = 5                 -- a loot window this soon after a gathering is that gathering's
local GAP_SECONDS = 300                -- a longer pause between gatherings is not time spent gathering
local PER_GATHER = 30                  -- seconds each gathering counts on top of the walk (the cast, the loot)
local MAX_IDEAS = 6
local STEP_CAP = 30

-- The skill needed for each herb and ore, by the skill that gathers it.
ns.GOLD_GATHER_ITEMS = {
    [HERBALISM] = {
        [2447] = 1, [765] = 1, [2449] = 15, [785] = 50, [2450] = 70, [3820] = 85, [2453] = 100, [3355] = 115,
        [3369] = 120, [3356] = 125, [3357] = 150, [3818] = 160, [3821] = 170, [3358] = 185, [3819] = 195,
        [4625] = 205, [8831] = 210, [8836] = 220, [8838] = 230, [8839] = 235, [8845] = 245, [8846] = 250,
        [13464] = 260, [13463] = 270, [13465] = 280, [13466] = 285, [13467] = 290, [13468] = 300,
    },
    [MINING] = {
        [2770] = 1, [2771] = 65, [2775] = 75, [2772] = 125, [2776] = 155, [3858] = 175, [7911] = 230, [10620] = 245,
    },
}
-- uiMapID -> { lowest skill, highest skill } that zone suits.
ns.GOLD_GATHER_ZONES = {}
do
    local bands = {
        { 1, 70, { 1429, 1411, 1412, 1438, 1426, 1420 } },
        { 1, 115, { 1436, 1432, 1413, 1439, 1421 } },
        { 50, 170, { 1433, 1431, 1437, 1440, 1442, 1424 } },
        { 115, 230, { 1441, 1416, 1417, 1443, 1434 } },
        { 160, 260, { 1445, 1418, 1435, 1444, 1425, 1446 } },
        { 205, 300, { 1427, 1447, 1419, 1449, 1448, 1428, 1422 } },
        { 245, 300, { 1423, 1452, 1451 } },
    }
    for _, b in ipairs(bands) do
        for _, map in ipairs(b[3]) do ns.GOLD_GATHER_ZONES[map] = { b[1], b[2] } end
    end
end
local WHOLE = { 1, 300 }               -- a map not in the list: everything your skill can gather

local function Num(v) if type(v) == "number" and v == v and v ~= huge and v ~= -huge and not ns:IsSecret(v) then return v end end
local function R1(v) return floor(v * 10 + 0.5) / 10 end
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
-- The gathering spells, by skill line. The one table: GoldFarm.lua reads it through ns.GoldGatherSkill
-- (a loot window after one of these is not a kill), and it is shared as ns.GOLD_GATHER_SPELLS.
local GATHER_SPELLS = {
    [2366] = HERBALISM, [2368] = HERBALISM, [3570] = HERBALISM, [11993] = HERBALISM,
    [2575] = MINING, [2576] = MINING, [3564] = MINING, [10248] = MINING,
    [8613] = SKINNING, [8617] = SKINNING, [8618] = SKINNING, [10768] = SKINNING,
}
ns.GOLD_GATHER_SPELLS = GATHER_SPELLS
local BASE_SPELLS = { [2366] = HERBALISM, [2575] = MINING, [8613] = SKINNING }   -- (their names, in your language, say the rest)

local function SpellName(id)
    if type(C_Spell) ~= "table" or type(C_Spell.GetSpellInfo) ~= "function" then return nil end
    local ok, info = pcall(C_Spell.GetSpellInfo, id)
    local name = ok and type(info) == "table" and not ns:IsSecret(info) and info.name or nil
    return type(name) == "string" and not ns:IsSecret(name) and name or nil
end

-- The skill line (182, 186, 393) a spell gathers with, or nil.
function ns.GoldGatherSkill(spellID)
    spellID = Num(spellID)
    if not spellID then return nil end
    if GATHER_SPELLS[spellID] then return GATHER_SPELLS[spellID] end
    local name = SpellName(spellID)
    if not name then return nil end
    for id, line in pairs(BASE_SPELLS) do
        if SpellName(id) == name then return line end
    end
    return nil
end

local function World(map, x, y)
    if type(ns.PlannerWorldPos) ~= "function" then return nil end
    return ns.PlannerWorldPos(map, x, y)
end

-- Record a node (once per 10 yards, per skill and name), as the planner's ns.PlannerRecordNode does.
function ns.GoldRecordNode(map, x, y, name, skill)
    map, x, y = Num(map), Num(x), Num(y)
    name = Clean(name)
    local root = Root()
    if not (map and x and y and name and root) then return false end
    if skill ~= HERBALISM and skill ~= MINING then return false end
    local list = type(root.goldNodesSeen) == "table" and type(root.goldNodesSeen[map]) == "table" and root.goldNodesSeen[map] or nil
    local c1, x1, y1 = World(map, x, y)
    if not c1 then return false end                 -- (no world scale on this map: nothing is recorded)
    if list then
        for _, n in ipairs(list) do
            if type(n) == "table" and n.skill == skill and n.name == name then
                local c2, x2, y2 = World(map, tonumber(n.x), tonumber(n.y))
                if c2 == c1 and sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2) <= NodeYards() then return false end
            end
        end
        if #list >= NODE_CAP then return false end
    end
    if type(root.goldNodesSeen) ~= "table" then root.goldNodesSeen = {} end
    if type(root.goldNodesSeen[map]) ~= "table" then root.goldNodesSeen[map] = {} end
    local out = root.goldNodesSeen[map]
    out[#out + 1] = { name = name, x = R1(x), y = R1(y), skill = skill }
    return true
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
    for _, e in ipairs({ "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED" }) do      -- (the player's casts only; the handler checks the unit too)
        local ok = type(ev.RegisterUnitEvent) == "function" and pcall(ev.RegisterUnitEvent, ev, e, "player")
        if not ok then pcall(ev.RegisterEvent, ev, e) end
    end
    pcall(ev.RegisterEvent, ev, "LOOT_OPENED")
    -- (a plain handler first: while locked it returns at once, so nothing named Gold is timed by /fgui perf)
    local guarded = ns:Guard("Gold gather", function(_, event, a1, a2, a3, a4)
        if event ~= "UNIT_SPELLCAST_SENT" and event ~= "UNIT_SPELLCAST_SUCCEEDED" and event ~= "LOOT_OPENED" then return end
        if not Unlocked() then return end
        if event == "LOOT_OPENED" then
            local g = gathered
            gathered = nil
            local now = Now()
            if g and now and now >= g.at and now - g.at <= LOOT_SECONDS then NoteLoot(g) end
            return
        end
        if ns:IsSecret(a1) or a1 ~= "player" then return end
        if event == "UNIT_SPELLCAST_SENT" then        -- unit, target, castGUID, spellID
            local skill = ns.GoldGatherSkill(a4)
            if not skill then return end
            local name = Clean(a2)
            pending = { name = name, skill = skill }
            if name and skill ~= SKINNING and not (type(ns.db) == "table" and ns.db.plannerGather == false) then
                local map, x, y = Here()
                if map and x and y then ns.GoldRecordNode(map, x, y, name, skill) end
            end
        else                                          -- unit, castGUID, spellID
            local skill = ns.GoldGatherSkill(a3)
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
-- The route: a nearest-neighbour loop through the nodes
------------------------------------------------------------------------------------------
-- nodes = { { map, x, y } } (x, y in percent). Returns the visiting order (indices, from the first)
-- and the loop's length in yards: world yards when every node has a world position, otherwise
-- map percent x 10.
function ns.GoldGatherRoute(nodes)
    if type(nodes) ~= "table" or #nodes == 0 then return {}, 0 end
    local px, py, world = {}, {}, true
    for i, n in ipairs(nodes) do
        local _, wx, wy = World(n.map, n.x, n.y)
        wx, wy = Num(wx), Num(wy)
        if not (wx and wy) then world = false end
        px[i], py[i] = wx, wy
        ns.GoldYield()
    end
    if not world then
        for i, n in ipairs(nodes) do px[i], py[i] = (tonumber(n.x) or 0) * 10, (tonumber(n.y) or 0) * 10 end
    end
    local count = #nodes
    local used, order, yards = { [1] = true }, { 1 }, 0
    local at = 1
    for _ = 2, count do
        local best, bestD = nil, huge
        for j = 1, count do
            if not used[j] then
                local d = sqrt((px[at] - px[j]) ^ 2 + (py[at] - py[j]) ^ 2)
                if d < bestD then best, bestD = j, d end         -- (strictly less: a tie keeps the lower index)
            end
        end
        ns.GoldYield()
        used[best] = true
        order[#order + 1] = best
        yards = yards + bestD
        at = best
    end
    yards = yards + sqrt((px[at] - px[1]) ^ 2 + (py[at] - py[1]) ^ 2)
    return order, yards
end

------------------------------------------------------------------------------------------
-- Ideas
------------------------------------------------------------------------------------------
-- Does this zone suit this skill (182 or 186) at this level?
function ns.GoldGatherFits(map, skill, level)
    local band = ns.GOLD_GATHER_ZONES[map]
    level = Num(level)
    return band ~= nil and ns.GOLD_GATHER_ITEMS[skill] ~= nil and level ~= nil and band[1] <= level and level <= band[2]
end

local function ZoneName(ctx, map)
    local info = Ask(C_Map and C_Map.GetMapInfo, map)
    local name = type(info) == "table" and not ns:IsSecret(info) and info.name or nil
    if type(name) == "string" and not ns:IsSecret(name) and name ~= "" then return name end
    if map == ctx.map and type(ctx.zone) == "string" then return ctx.zone end
    return tostring(map)
end

-- The worth of one item, keeping the oldest auction price day used.
local function Worth(id, ctx, days)
    local v, from, day = ns.GoldItemValue(id, ctx.today)
    v = Num(v) or 0
    if from == "ah" and Num(day) then days.oldest = days.oldest and min(days.oldest, day) or day end
    return v
end

-- The built-in worth of a node in this zone at your skill: the average of what grows there that you
-- can gather, x 1.5 for herbs (more than one a node) or x 2 for ore.
local function BuiltIn(map, skill, level, ctx, days)
    local band = ns.GOLD_GATHER_ZONES[map] or WHOLE
    local sum, count = 0, 0
    for id, need in pairs(ns.GOLD_GATHER_ITEMS[skill] or {}) do
        if need <= level and need >= band[1] and need <= band[2] then
            sum, count = sum + Worth(id, ctx, days), count + 1
        end
    end
    if count == 0 then return 0 end
    return sum / count * (skill == HERBALISM and 1.5 or 2)
end

-- What one node of this name gives, once it has been looted 3 times; nil before.
local function Learned(name, ctx, days)
    local root = Root()
    local e = root and type(root.goldNodeItems) == "table" and root.goldNodeItems[name]
    local n = type(e) == "table" and Num(e.n)
    if not (n and n >= 3 and type(e.items) == "table") then return nil end
    local sum = 0
    for id, count in pairs(e.items) do
        if Num(id) and Num(count) then sum = sum + count * Worth(id, ctx, days) end
    end
    return sum / n
end

-- The node memories there are: the gold advisor's and the planner's (either may be missing).
local function Stores()
    local root, out = Root(), {}
    if not root then return out end
    if type(root.goldNodesSeen) == "table" then out[#out + 1] = root.goldNodesSeen end
    if type(root.plannerNodesSeen) == "table" then out[#out + 1] = root.plannerNodesSeen end
    return out
end

-- The nodes of this skill on a map, from both memories (the gold advisor's and the planner's),
-- each spot once.
local function Nodes(map, skill)
    local root, out, seen = Root(), {}, {}
    if not root then return out end
    for _, store in ipairs(Stores()) do
        local list = store[map]
        for _, n in ipairs(type(list) == "table" and list or {}) do
            if type(n) == "table" and n.skill == skill and Clean(n.name) and Num(n.x) and Num(n.y) then
                local key = n.name .. "@" .. R1(n.x) .. "," .. R1(n.y)
                if not seen[key] then
                    seen[key] = true
                    out[#out + 1] = { name = n.name, map = map, x = n.x, y = n.y }
                end
            end
            ns.GoldYield()
        end
    end
    return out
end

local SKILL_WORD = { [HERBALISM] = "herbs", [MINING] = "ore" }
local function Ease(map, ctx, long)
    local e = (ns.GOLD_EASE and ns.GOLD_EASE.gather) or 40
    if map ~= ctx.map then e = e - 10 end
    if long then e = e - 10 end
    return max(0, min(100, e))
end
local function Safety(basis)
    local s = ns.GOLD_SAFETY and ns.GOLD_SAFETY.gather and ns.GOLD_SAFETY.gather[basis]
    return s or (basis == "measured" and 80 or 45)
end
local function Idea(ctx, map, skill, basis, perHour, title, days, long)
    return {
        id = "gather:" .. map .. ":" .. skill, kind = "gather", title = title, oneOff = false, perHour = perHour,
        ease = Ease(map, ctx, long), safety = Safety(basis), basis = basis, priceDay = days.oldest, where = "window", map = map,
    }
end

-- The skill a map's measure is mostly of, by the listed herbs and ores it holds (an item not on the
-- list says nothing either way). A map with neither is skinning, the only other gathering measured.
-- Also the other skill when the map holds some of both, for the detail.
local function MeasuredSkill(items)
    local herbs, ores = 0, 0
    for id, count in pairs(items) do
        local c = Num(count) or 0
        if ns.GOLD_GATHER_ITEMS[HERBALISM][id] then herbs = herbs + c
        elseif ns.GOLD_GATHER_ITEMS[MINING][id] then ores = ores + c end
    end
    if herbs == 0 and ores == 0 then return SKINNING, nil end
    if herbs >= ores then return HERBALISM, (ores > 0) and MINING or nil end
    return MINING, (herbs > 0) and HERBALISM or nil
end

-- Every gathering idea for these skills ({ [182|186|393] = level }), at most 6, by gold an hour.
-- Reads only the saved memories and the prices: the skills are handed in.
function ns.GoldGatherIdeas(ctx, add, skills)
    if type(ctx) ~= "table" or type(add) ~= "function" then return end
    skills = type(skills) == "table" and skills or {}
    local root = Root()
    local speed = ((Num(ctx.level) or 0) >= 40) and 11.2 or 7
    local found = {}                                 -- id -> idea
    -- measured: what an hour of gathering on a map really brought (skinning only this way)
    -- (the keys first: a gathering may add a map between slices)
    local measured = root and type(root.goldGather) == "table" and root.goldGather or {}
    local mapKeys = {}
    for map in pairs(measured) do mapKeys[#mapKeys + 1] = map end
    for _, map in ipairs(mapKeys) do
        local m = measured[map]
        local n, secs = type(m) == "table" and Num(m.n), type(m) == "table" and Num(m.secs)
        if Num(map) and n and secs and n >= 20 and secs >= 600 and type(m.items) == "table" then
            local days, sum = {}, 0
            for id, count in pairs(m.items) do          -- (no yield in here: the loot may add an item)
                if Num(id) and Num(count) then sum = sum + count * Worth(id, ctx, days) end
            end
            ns.GoldYield()
            local perHour = floor(sum / secs * 3600)
            local skill, other = MeasuredSkill(m.items)
            local zone = ZoneName(ctx, map)
            local title = (skill == SKINNING) and format(ns:Tr("Skin beasts in %s"), zone)
                or format(ns:Tr("Gather %s in %s"), ns:Tr(SKILL_WORD[skill]), zone)
            local idea = Idea(ctx, map, skill, "measured", perHour, title, days, false)
            idea.steps = { { text = format(ns:Tr("Go to %s"), zone), map = map } }
            idea.detail = { { left = format(ns:Tr("Measured: %d gatherings in %s"), n, ns.GoldTimeText(secs / 60)) } }
            if other then idea.detail[2] = { left = format(ns:Tr("Also gathered here, and counted in this: %s"), ns:Tr(SKILL_WORD[other])) } end
            found[idea.id] = idea
        end
    end
    -- herbs and ore: a loop of the nodes you know, or a guess where to try
    for _, skill in ipairs({ HERBALISM, MINING }) do
        local level = Num(skills[skill])
        if level and level > 0 then
            local maps = {}
            for map in pairs(ns.GOLD_GATHER_ZONES) do
                if ns.GoldGatherFits(map, skill, level) then maps[map] = true end
            end
            for _, store in ipairs(Stores()) do
                for map in pairs(store) do if Num(map) then maps[map] = true end end
            end
            for map in pairs(maps) do
                local id = "gather:" .. map .. ":" .. skill
                if not found[id] then
                    local days = {}
                    local nodes = Nodes(map, skill)
                    local zone = ZoneName(ctx, map)
                    if #nodes >= 5 then
                        local base, sum, cache = nil, 0, {}
                        for _, node in ipairs(nodes) do
                            local v = cache[node.name]
                            if v == nil then
                                v = Learned(node.name, ctx, days)
                                if v == nil then
                                    base = base or BuiltIn(map, skill, level, ctx, days)
                                    v = base
                                end
                                cache[node.name] = v
                            end
                            sum = sum + v
                            ns.GoldYield()
                        end
                        local value = sum / #nodes
                        local order, yards = ns.GoldGatherRoute(nodes)
                        local loop = yards / speed + #nodes * 5
                        local perHour = floor(#nodes * 3600 / max(loop, 300) * 0.6 * value)
                        local idea = Idea(ctx, map, skill, "guess", perHour, format(ns:Tr("Gather %s in %s"), ns:Tr(SKILL_WORD[skill]), zone), days, yards > 3000)
                        idea.steps = {}
                        for i = 1, min(#order, STEP_CAP) do
                            local node = nodes[order[i]]
                            idea.steps[i] = { text = node.name, map = map, x = node.x, y = node.y }
                        end
                        idea.detail = { { left = format(ns:Tr("%d nodes, a loop of about %d yards"), #nodes, floor(yards + 0.5)) } }
                        found[id] = idea
                    elseif ns.GoldGatherFits(map, skill, level) then
                        local perHour = floor(30 * BuiltIn(map, skill, level, ctx, days))
                        local idea = Idea(ctx, map, skill, "guess", perHour, format(ns:Tr("Try gathering in %s"), zone), days, false)
                        idea.steps = { { text = format(ns:Tr("Go to %s"), zone), map = map } }
                        idea.detail = { { left = ns:Tr("No nodes recorded here yet: a guess from what grows here at your skill.") } }
                        found[id] = idea
                    end
                end
                ns.GoldYield()
            end
        end
    end
    -- the best 6 (equal ones: where you stand first, then by id)
    local list = {}
    for _, idea in pairs(found) do
        if idea.perHour >= 100 then list[#list + 1] = idea end
    end
    table.sort(list, function(a, b)
        if a.perHour ~= b.perHour then return a.perHour > b.perHour end
        local ha, hb = a.map == ctx.map, b.map == ctx.map
        if ha ~= hb then return ha end
        return a.id < b.id
    end)
    for i = 1, min(#list, MAX_IDEAS) do add(list[i]) end
end

-- Your gathering skills from the game: { [182|186|393] = level }.
local function Skills()
    local out = {}
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then return out end
    local ok, p1, p2 = pcall(GetProfessions)
    if not ok then return out end
    for _, index in ipairs({ Num(p1) or false, Num(p2) or false }) do
        if index then
            local ok2, _, _, level, _, _, _, line = pcall(GetProfessionInfo, index)
            level, line = ok2 and Num(level), ok2 and Num(line)
            if level and line and (line == HERBALISM or line == MINING or line == SKINNING) then out[line] = level end
        end
    end
    return out
end

ns.GoldRegister("gather", function(ctx, add) ns.GoldGatherIdeas(ctx, add, Skills()) end)
