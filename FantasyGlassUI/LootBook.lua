local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Loot browser (11.13): /fgui drops. What each boss drops, raid by raid and dungeon by dungeon, with the
-- upgrades for you marked and first.
--
-- It is written as you play: when a boss dies, what drops from it is noted - in your loot window, in
-- the loot rolls, and in the lines that say what anyone in your group looted - so a boss you have
-- killed five times knows which pieces came in how many of those kills. The book is shared by all your
-- characters. On a game client with the dungeon journal, the journal's loot lists are there as well,
-- for bosses you have never seen.
--
-- Click a raid or dungeon for its bosses, a boss for its loot. Hover an item for its tooltip.
------------------------------------------------------------------------------------------
local WINDOW = 300          -- seconds after a kill in which loot counts as the boss's
local MIN_QUALITY = 2       -- uncommon and better

local function Book()
    if type(ns.root) ~= "table" then return {} end
    ns.root.lootBook = type(ns.root.lootBook) == "table" and ns.root.lootBook or {}
    return ns.root.lootBook
end
local function ItemID(link)
    if type(link) ~= "string" or Secret(link) then return nil end
    return tonumber(link:match("|Hitem:(%d+)"))
end

-- A kill of `boss` in `instance`: the boss's kill count goes up. Returns the boss's record.
function ns.LootBookKill(book, instance, boss)
    if type(instance) ~= "string" or type(boss) ~= "string" then return nil end
    book[instance] = type(book[instance]) == "table" and book[instance] or {}
    local b = type(book[instance][boss]) == "table" and book[instance][boss] or { kills = 0, items = {} }
    b.items = type(b.items) == "table" and b.items or {}
    b.kills = (tonumber(b.kills) or 0) + 1
    book[instance][boss] = b
    return b
end
-- An item seen from that boss in this kill (once per kill however many places it shows up).
function ns.LootBookNote(record, link, seenThisKill)
    local id = ItemID(link)
    if not (record and id) or (seenThisKill and seenThisKill[id]) then return false end
    if seenThisKill then seenThisKill[id] = true end
    local e = type(record.items[id]) == "table" and record.items[id] or { n = 0 }
    e.n = (tonumber(e.n) or 0) + 1
    e.link = link
    e.last = time and time() or 0
    record.items[id] = e
    return true
end

-- The game's dungeon journal, where the client has one: { [instance] = { [boss] = { link, ... } } }
-- for the instances of the current expansion. Nil without a journal.
local journalCache
function ns.LootJournal()
    if journalCache then return journalCache end
    if type(EJ_GetInstanceByIndex) ~= "function" or type(EJ_SelectInstance) ~= "function" or type(EJ_GetEncounterInfoByIndex) ~= "function"
        or type(EJ_SelectEncounter) ~= "function" or type(EJ_GetNumLoot) ~= "function" then
        return nil
    end
    local out = {}
    local GetLoot = (C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex) or EJ_GetLootInfoByIndex
    pcall(function()
        if EJ_SelectTier and EJ_GetCurrentTier then EJ_SelectTier(EJ_GetCurrentTier()) end
        for _, raid in ipairs({ false, true }) do
            for i = 1, 60 do
                local id, name = EJ_GetInstanceByIndex(i, raid)
                if not id then break end
                EJ_SelectInstance(id)
                local bosses = {}
                for j = 1, 30 do
                    local bossName, _, encounterID = EJ_GetEncounterInfoByIndex(j, id)
                    if not bossName then break end
                    EJ_SelectEncounter(encounterID)
                    local items = {}
                    for k = 1, EJ_GetNumLoot() or 0 do
                        local info = { GetLoot(k) }
                        local link = type(info[1]) == "table" and (info[1].link or info[1].itemLink) or info[7]
                        if type(link) == "string" then items[#items + 1] = link end
                    end
                    bosses[bossName] = items
                end
                out[name] = bosses
            end
        end
    end)
    if next(out) then journalCache = out end
    return journalCache
end

------------------------------------------------------------------------------------------
-- The browser: three levels in one list window.
------------------------------------------------------------------------------------------
local view = { level = 0, onlyUpgrades = false }

local function Sorted(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end
local function Quality(link)
    local _, _, q = ns:GetItemInfo(link)
    return (type(q) == "number" and not Secret(q)) and q or 0
end

-- The lines for where the browser is. (Exposed for the tests.)
function ns.LootBookLines(state)
    state = state or view
    local book, journal = Book(), ns.LootJournal() or {}
    local lines = {}
    local function Back(to)
        lines[#lines + 1] = { left = ns:AccentHex() .. "<  " .. ns:Tr("Back") .. "|r", click = function() view.level = to; ns:ShowDrops() end }
    end
    if state.level == 0 then
        local names = {}
        for n in pairs(book) do names[n] = true end
        for n in pairs(journal) do names[n] = true end
        for _, inst in ipairs(Sorted(names)) do
            local bosses, items = 0, 0
            for _, b in pairs(type(book[inst]) == "table" and book[inst] or {}) do
                bosses = bosses + 1
                for _ in pairs(type(b.items) == "table" and b.items or {}) do items = items + 1 end
            end
            local right
            if bosses > 0 then right = format(ns:Tr("%d bosses, %d items seen"), bosses, items)
            else right = "|cff9aa4b4" .. ns:Tr("from the journal") .. "|r" end
            lines[#lines + 1] = { left = inst, right = right, click = function() view.level, view.instance = 1, inst; ns:ShowDrops() end }
        end
        return lines
    end
    local inst = state.instance
    if state.level == 1 then
        Back(0)
        local names = {}
        for n in pairs(type(book[inst]) == "table" and book[inst] or {}) do names[n] = true end
        for n in pairs(type(journal[inst]) == "table" and journal[inst] or {}) do names[n] = true end
        for _, boss in ipairs(Sorted(names)) do
            local rec = book[inst] and book[inst][boss]
            local right = rec and format(ns:TrN(rec.kills or 0, "seen over %d kill", "seen over %d kills"), rec.kills or 0)
                          or ("|cff9aa4b4" .. ns:Tr("from the journal") .. "|r")
            lines[#lines + 1] = { left = boss, right = right, click = function() view.level, view.boss = 2, boss; ns:ShowDrops() end }
        end
        return lines
    end
    -- level 2: one boss's loot
    Back(1)
    local boss = state.boss
    lines[#lines + 1] = { left = state.onlyUpgrades and ns:Tr("Showing upgrades for you. Click to show everything.") or ns:Tr("Showing everything. Click to show only upgrades for you."),
                          color = { 0.62, 0.68, 0.78 }, click = function() view.onlyUpgrades = not view.onlyUpgrades; ns:ShowDrops() end }
    local rec = book[inst] and book[inst][boss]
    local items, seen = {}, {}
    for id, e in pairs(rec and rec.items or {}) do
        if type(e) == "table" and type(e.link) == "string" then
            items[#items + 1] = { link = e.link, n = e.n, kills = rec.kills }
            seen[id] = true
        end
    end
    for _, link in ipairs(journal[inst] and journal[inst][boss] or {}) do
        local id = ItemID(link)
        if id and not seen[id] then items[#items + 1] = { link = link }; seen[id] = true end
    end
    for _, it in ipairs(items) do it.up = ns.UpgradeAmount and ns.UpgradeAmount(it.link) or nil; it.q = Quality(it.link) end
    table.sort(items, function(a, b)
        if (a.up ~= nil) ~= (b.up ~= nil) then return a.up ~= nil end
        if a.q ~= b.q then return a.q > b.q end
        return (a.n or 0) > (b.n or 0)
    end)
    local shown = 0
    for _, it in ipairs(items) do
        if not state.onlyUpgrades or it.up then
            local right = ""
            if it.up then right = "|cff33ff55" .. format(ns:Tr("upgrade +%d"), it.up) .. "|r  " end
            if it.n then right = right .. format(ns:Tr("%d of %d kills"), it.n, math.max(it.n, it.kills or it.n))
            else right = right .. "|cff9aa4b4" .. ns:Tr("journal") .. "|r" end
            lines[#lines + 1] = { left = it.link, right = right, link = it.link }
            shown = shown + 1
        end
    end
    if shown == 0 then
        lines[#lines + 1] = { left = "|cff9aa4b4" .. ns:Tr(state.onlyUpgrades and "No upgrades for you from this boss." or "Nothing seen from this boss yet.") .. "|r" }
    end
    return lines
end

function ns:ShowDrops(text)
    local want = ns.Trim(text or "")
    if want ~= "" then                                       -- /fgui drops <part of a name>: straight there
        local book, journal = Book(), ns.LootJournal() or {}
        local low = want:lower()
        for _, src in ipairs({ book, journal }) do
            for inst in pairs(src) do
                if tostring(inst):lower():find(low, 1, true) then view.level, view.instance = 1, inst; break end
            end
            if view.level == 1 then break end
        end
    end
    local title = "Loot browser"
    if view.level == 1 then title = view.instance elseif view.level == 2 then title = view.boss end
    local lines = ns.LootBookLines(view)
    if #lines == 0 then
        lines[1] = { left = ns:Tr("Nothing yet: what bosses drop is noted as you kill them, in raids and dungeons.") }
    end
    ns:ShowList("LootBook", title, lines, "What each boss dropped while you were there. Upgrades for you come first.", 560, 440)
    return #lines
end

ns:NewModule("lootBook", function()
    local last                                             -- the latest kill: { instance, boss, at, record, seen }
    local selfPatterns = ns.LootPatterns({ LOOT_ITEM_SELF_MULTIPLE or "You receive loot: %sx%d.", LOOT_ITEM_SELF or "You receive loot: %s." })
    local otherPatterns = ns.LootPatterns({ LOOT_ITEM_MULTIPLE or "%s receives loot: %sx%d.", LOOT_ITEM or "%s receives loot: %s." })
    local function Instance()
        local ok, name, kind = pcall(GetInstanceInfo)
        if ok and type(name) == "string" and not Secret(name) and (kind == "party" or kind == "raid") then return name end
    end
    local function Note(link)
        if not last or (GetTime() - last.at) > WINDOW or Instance() ~= last.instance then return end
        if type(link) ~= "string" or Secret(link) then return end
        local q = Quality(link)
        if q > 0 and q < MIN_QUALITY then return end
        ns.LootBookNote(last.record, link, last.seen)
    end
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "ENCOUNTER_END", "LOOT_OPENED", "START_LOOT_ROLL", "CHAT_MSG_LOOT" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Loot browser", function(_, event, a, b, _, _, e)
        if event == "ENCOUNTER_END" then
            if e ~= 1 and e ~= true then return end                  -- (a wipe)
            local inst = Instance()
            if not inst or type(b) ~= "string" or Secret(b) then return end
            last = { instance = inst, boss = b, at = GetTime(), record = ns.LootBookKill(Book(), inst, b), seen = {} }
        elseif event == "LOOT_OPENED" then
            for slot = 1, (GetNumLootItems and GetNumLootItems() or 0) do
                local ok, link = pcall(GetLootSlotLink, slot)
                if ok then Note(link) end
            end
        elseif event == "START_LOOT_ROLL" then
            local ok, link = pcall(GetLootRollItemLink, a)
            if ok then Note(link) end
        elseif event == "CHAT_MSG_LOOT" then
            if type(a) ~= "string" or Secret(a) then return end
            local link = ns.ParseLoot(a, selfPatterns)
            if not link then
                for _, p in ipairs(otherPatterns) do
                    local _, l = a:match(p)
                    if type(l) == "string" and l:find("|Hitem:", 1, true) then link = l; break end
                end
            end
            if link then Note(link) end
        end
    end))
    ns.lootBookTest = { Last = function() return last end }
end)
