local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end
-- Ways to make gold: Gathering (group C). Plugs into Gold.lua through ns.GoldRegister.

------------------------------------------------------------------------------------------
-- Gathering: the herb and ore nodes you have gathered (one memory with the planner's shape), what
-- each kind of node gave you, and how much an hour of gathering on a map brought. From these, a loop
-- of the nodes you know, a guess at where to try next for your skill, or what you measured.
--
-- Saved (account-wide, made only when something is written):
--   (the nodes themselves are the planner's plannerNodesSeen: one memory. An older goldNodesSeen, from
--    before the two met, is folded into it once by ns.GoldFoldNodes, and read until then.)
--   goldNodeItems[name] = { n, items = { [id] = count } }
--   goldGather[map] = { secs, n, items = { [id] = count }, day }
------------------------------------------------------------------------------------------
local type, tonumber, pairs, ipairs = type, tonumber, pairs, ipairs
local floor, max, min, sqrt, huge = math.floor, math.max, math.min, math.sqrt, math.huge

local HERBALISM, MINING, SKINNING = 182, 186, 393
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
-- Rare spawns: kept above for the skill labels, left out of the built-in guess (one would make every
-- zone of its band look rich, where most of the time it does not grow at all).
ns.GOLD_GATHER_RARE = { [13468] = true }   -- Black Lotus
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
local function Root() return type(ns.root) == "table" and ns.root or nil end
-- (the recorders are in the main add-on's GoldRecorders.lua: merchant prices, loot, gathering and the node fold)
local function World(map, x, y)
    if type(ns.PlannerWorldPos) ~= "function" then return nil end
    return ns.PlannerWorldPos(map, x, y)
end
local function Ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c
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

local function PerNode(skill) return (skill == HERBALISM) and 1.5 or 2 end   -- (more than one herb a node; ore x 2)
-- The built-in worth of a node in this zone at your skill: the median of what grows there that you
-- can gather (rare spawns left out; an unpriced item counts 0), x 1.5 for herbs or x 2 for ore.
local function BuiltIn(map, skill, level, ctx, days)
    local band = ns.GOLD_GATHER_ZONES[map] or WHOLE
    local worths = {}
    for id, need in pairs(ns.GOLD_GATHER_ITEMS[skill] or {}) do
        if need <= level and need >= band[1] and need <= band[2] and not ns.GOLD_GATHER_RARE[id] then
            worths[#worths + 1] = Worth(id, ctx, days)
        end
    end
    local n = #worths
    if n == 0 then return 0 end
    table.sort(worths)
    local mid = (n % 2 == 1) and worths[(n + 1) / 2] or (worths[n / 2] + worths[n / 2 + 1]) / 2
    return mid * PerNode(skill)
end
-- The listed item of this skill whose name is a node's name ("Peacebloom"), or nil (names from the
-- item details, so only once they are loaded). `cache` keeps the names for one collection.
local function ItemNamed(name, skill, cache)
    local byName = cache[skill]
    if not byName then
        byName = {}
        for id in pairs(ns.GOLD_GATHER_ITEMS[skill] or {}) do
            local ok, n = pcall(ns.GetItemInfo, ns, id)
            if ok and type(n) == "string" and not ns:IsSecret(n) and n ~= "" then byName[n] = id end
        end
        cache[skill] = byName
    end
    return byName[name]
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
    local names = {}                                 -- skill -> { item name -> id }, for this collection
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
            local last = Num(m.day) and ns.AuctionSeenText and ns.AuctionSeenText({ price = 0, day = m.day }, ctx.today or ns.Today())
            if last then idea.detail[#idea.detail + 1] = { left = format(ns:Tr("Last gathered %s"), last) } end
            if other then idea.detail[#idea.detail + 1] = { left = format(ns:Tr("Also gathered here, and counted in this: %s"), ns:Tr(SKILL_WORD[other])) } end
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
                                local own = (v == nil) and ItemNamed(node.name, skill, names) or nil
                                if own then v = Worth(own, ctx, days) * PerNode(skill) end   -- (the node's own item)
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
ns.FolderFileDone("gold", "GoldGather.lua")
