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
--
-- 11.15: a wishlist - click an item in the browser to star it (again to let it go). A starred item
-- dropping, coming up in a roll, or a boss that drops it becoming your target is called out;
-- /fgui wish lists them with where each drops. And a boss's own tooltip lists what it drops that you
-- want or that would be an upgrade for you.
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
    local GetLoot = C_EncounterJournal.GetLootInfoByIndex
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
-- The wishlist: root.lootWish[id] = { link, at }.
------------------------------------------------------------------------------------------
local STAR = "|TInterface\\Common\\FavoritesIcon:14:14:0:0|t"
local function Wishes()
    if type(ns.root) ~= "table" then return {} end
    ns.root.lootWish = type(ns.root.lootWish) == "table" and ns.root.lootWish or {}
    return ns.root.lootWish
end
function ns.LootWished(id) return id ~= nil and Wishes()[id] ~= nil end
ns.LOOT_STAR = STAR
-- Star an item or let it go. Returns true when it is now on the list.
function ns.LootWishToggle(link)
    local id = ItemID(link)
    if not id then return nil end
    local w = Wishes()
    if w[id] then w[id] = nil; return false end
    w[id] = { link = link, at = time and time() or 0 }
    return true
end
-- Where an item drops, from the book: { { instance, boss, n, kills } }.
function ns.LootWhereFrom(id)
    local out = {}
    for inst, bosses in pairs(Book()) do
        for boss, rec in pairs(type(bosses) == "table" and bosses or {}) do
            if type(rec) == "table" and type(rec.items) == "table" and type(rec.items[id]) == "table" then
                out[#out + 1] = { instance = inst, boss = boss, n = tonumber(rec.items[id].n) or 0, kills = tonumber(rec.kills) or 0 }
            end
        end
    end
    local journal = ns.LootJournal() or {}
    for inst, bosses in pairs(journal) do
        for boss, links in pairs(bosses) do
            for _, l in ipairs(links) do
                if ItemID(l) == id then
                    local dup = false
                    for _, e in ipairs(out) do if e.instance == inst and e.boss == boss then dup = true end end
                    if not dup then out[#out + 1] = { instance = inst, boss = boss } end
                end
            end
        end
    end
    table.sort(out, function(a, b) return (a.n or -1) > (b.n or -1) end)
    return out
end
-- What a boss (by name) drops that you want or that is an upgrade: { { link, wish, up, n, kills } }.
function ns.LootForBoss(name, instance)
    if type(name) ~= "string" or Secret(name) then return {} end
    local out, seen = {}, {}
    local function Add(link, n, kills)
        local id = ItemID(link)
        if not id or seen[id] then return end
        seen[id] = true
        local wish = ns.LootWished(id)
        local up = ns.UpgradeAmount and ns.UpgradeAmount(link) or nil
        if wish or up then out[#out + 1] = { link = link, wish = wish, up = up, n = n, kills = kills } end
    end
    local book, journal = Book(), ns.LootJournal() or {}
    for _, src in ipairs({ { book, true }, { journal, false } }) do
        for inst, bosses in pairs(src[1]) do
            if not instance or inst == instance or instance == true then
                local b = type(bosses) == "table" and bosses[name]
                if src[2] and type(b) == "table" then
                    for _, e in pairs(type(b.items) == "table" and b.items or {}) do
                        if type(e) == "table" then Add(e.link, e.n, b.kills) end
                    end
                elseif not src[2] and type(b) == "table" then
                    for _, l in ipairs(b) do Add(l) end
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.wish ~= b.wish then return a.wish end
        return (a.up or 0) > (b.up or 0)
    end)
    return out
end

function ns:ShowWishlist()
    local lines = {}
    local list = {}
    for id, w in pairs(Wishes()) do list[#list + 1] = { id = id, w = w } end
    table.sort(list, function(a, b) return (a.w.at or 0) > (b.w.at or 0) end)
    for _, e in ipairs(list) do
        local where = ns.LootWhereFrom(e.id)[1]
        local right = where and (where.boss .. "  |cff9aa4b4" .. where.instance .. "|r") or ("|cff9aa4b4" .. ns:Tr("not seen drop yet") .. "|r")
        if where and where.n then right = right .. "  |cff9aa4b4" .. format(ns:Tr("%d of %d kills"), where.n, math.max(where.n, where.kills or 0)) .. "|r" end
        lines[#lines + 1] = { left = STAR .. " " .. tostring(e.w.link), right = right, link = e.w.link,
                              tip = ns:Tr("Click to take it off your wishlist."),
                              click = function() Wishes()[e.id] = nil; ns:ShowWishlist() end }
    end
    if #lines == 0 then lines[1] = { left = ns:Tr("Your wishlist is empty: click an item in the loot browser (/fgui drops) to star it.") } end
    ns:ShowList("LootWish", "Wishlist", lines, "Called out when one drops, comes up in a roll, or a boss that drops it is your target.", 560, math.min(420, 90 + #lines * 20))
    return #list
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
            local link = it.link
            lines[#lines + 1] = { left = (ns.LootWished(ItemID(link)) and (STAR .. " ") or "") .. link, right = right, link = link,
                                  tip = ns:Tr(ns.LootWished(ItemID(link)) and "Click to take it off your wishlist." or "Click to star it: you will be told when it drops."),
                                  click = function() ns.LootWishToggle(link); ns:ShowDrops() end }
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
    if view.level == 0 and next(Wishes()) then
        table.insert(lines, 1, { left = STAR .. " " .. ns:AccentHex() .. ns:Tr("Your wishlist") .. "|r", click = function() ns:ShowWishlist() end })
    end
    ns:ShowList("LootBook", title, lines, "What each boss dropped while you were there. Upgrades for you come first; click an item to star it.", 560, 440)
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
    -- A starred item: called out once per sighting (a drop or a roll), and a boss that drops one when it is your target.
    local called = {}
    local function CallOut(link, how)
        local id = ItemID(link)
        if not (id and ns.LootWished(id)) then return end
        local key = id .. how
        if called[key] and GetTime() - called[key] < 60 then return end
        called[key] = GetTime()
        local text = format(ns:Tr(how == "roll" and "On your wishlist, up for a roll: %s" or "On your wishlist, it dropped: %s"), link)
        ns:Print(text)
        if ns.Flash then pcall(ns.Flash, ns, ns:Tr("Wishlist item!"), 1, 0.82, 0.3) end
        if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.RAID_WARNING or 8959, "Master") end
    end
    ns.LootWishCallOut = CallOut
    local function Note(link)
        if type(link) == "string" and not Secret(link) then CallOut(link, "drop") end
        if not last or (GetTime() - last.at) > WINDOW or Instance() ~= last.instance then return end
        if type(link) ~= "string" or Secret(link) then return end
        local q = Quality(link)
        if q > 0 and q < MIN_QUALITY then return end
        ns.LootBookNote(last.record, link, last.seen)
    end
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "ENCOUNTER_END", "LOOT_OPENED", "START_LOOT_ROLL", "CHAT_MSG_LOOT", "PLAYER_TARGET_CHANGED" }) do pcall(ev.RegisterEvent, ev, e) end
    local targetSaid = {}
    ev:SetScript("OnEvent", ns:Guard("Loot browser", function(_, event, a, b, _, _, e)
        if event == "ENCOUNTER_END" then
            if e ~= 1 and e ~= true then return end                  -- (a wipe)
            local inst = Instance()
            if not inst or type(b) ~= "string" or Secret(b) then return end
            last = { instance = inst, boss = b, at = GetTime(), record = ns.LootBookKill(Book(), inst, b), seen = {} }
        elseif event == "PLAYER_TARGET_CHANGED" then
            -- a boss that drops something on your wishlist: said once a day per boss
            if not next(Wishes()) then return end
            local okN, name = pcall(UnitName, "target")
            if not okN or type(name) ~= "string" or Secret(name) then return end
            local okA, attackable = pcall(UnitCanAttack, "player", "target")
            if not (okA and attackable == true) then return end
            local wanted = {}
            for _, e in ipairs(ns.LootForBoss(name, true)) do if e.wish then wanted[#wanted + 1] = e.link end end
            if #wanted == 0 then return end
            local day = date and date("%Y%m%d") or ""
            if targetSaid[name] == day then return end
            targetSaid[name] = day
            ns:Print(format(ns:Tr("%s can drop from your wishlist: %s"), name, table.concat(wanted, ", ")))
        elseif event == "LOOT_OPENED" then
            for slot = 1, (GetNumLootItems and GetNumLootItems() or 0) do
                local ok, link = pcall(GetLootSlotLink, slot)
                if ok then Note(link) end
            end
        elseif event == "START_LOOT_ROLL" then
            local ok, link = pcall(GetLootRollItemLink, a)
            if ok then
                if type(link) == "string" and not Secret(link) then CallOut(link, "roll") end
                Note(link)
            end
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
    ns.lootBookTest = { Last = function() return last end, CallOut = CallOut }

    -- A boss's tooltip: what it drops that you want or that would be an upgrade for you (11.15).
    local function OnUnit(tip)
        if not (ns.db.lootBossTip ~= false and tip and tip.GetUnit) then return end
        local okU, _, unit = pcall(tip.GetUnit, tip)
        if not okU or type(unit) ~= "string" or Secret(unit) then return end
        local okN, name = pcall(UnitName, unit)
        if not okN or type(name) ~= "string" or Secret(name) then return end
        local okA, attackable = pcall(UnitCanAttack, "player", unit)
        if not (okA and attackable == true) then return end
        local list = ns.LootForBoss(name, true)
        if #list == 0 then return end
        tip:AddLine(ns:Tr("Drops for you:"), 1, 0.82, 0.3)
        for i, e in ipairs(list) do
            if i > 4 then tip:AddLine(format(ns:Tr("and %d more (/fgui drops)"), #list - 4), 0.6, 0.65, 0.75); break end
            local right = ""
            if e.up then right = "|cff33ff55+" .. math.floor(e.up + 0.5) .. "|r" end
            if e.n then right = right .. (right ~= "" and "  " or "") .. "|cff9aa4b4" .. format("%d/%d", e.n, math.max(e.n, e.kills or 0)) .. "|r" end
            tip:AddDoubleLine((e.wish and (STAR .. " ") or "") .. tostring(e.link), right)
        end
        tip:Show()
    end
    ns.lootBookTest.OnUnit = OnUnit
    local safe = ns:Guard("Boss drops tooltip", OnUnit)
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
        pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Unit, function(tip) if tip == GameTooltip then safe(tip) end end)
    elseif GameTooltip and GameTooltip.HookScript then
        pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", safe)
    end
end)
