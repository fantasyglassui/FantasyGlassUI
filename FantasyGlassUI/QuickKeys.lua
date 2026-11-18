local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Things that only a secure button may do (use an item, cast a spell), set up for you:
--   a key for your best healing potion, a key for your best food and drink, a mount key,
--   a button that opens the lockboxes and clams in your bags, and a travel bar.
-- What each button does can only be changed between fights, so everything here is laid out again
-- when a fight ends.
------------------------------------------------------------------------------------------
local function ItemInfo(id)
    local Instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local Info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local out = { id = id }
    if type(Instant) == "function" then
        local ok, _, _, _, _, icon, class, sub = pcall(Instant, id)
        if ok then out.icon, out.class, out.sub = icon, class, sub end
    end
    if type(Info) == "function" then
        local ok, name, _, _, level, minLevel = pcall(Info, id)
        if ok then
            out.name = type(name) == "string" and name or nil
            out.level = type(level) == "number" and level or 0
            out.minLevel = type(minLevel) == "number" and minLevel or 0
        end
    end
    return out
end
-- What using this item does, in the game's own words (lower case), or "".
local function UseText(id)
    local GetSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    if type(GetSpell) ~= "function" then return "" end
    local ok, _, spellID = pcall(GetSpell, id)
    if not (ok and type(spellID) == "number") then return "" end
    local Describe = (C_Spell and C_Spell.GetSpellDescription) or GetSpellDescription
    if type(Describe) ~= "function" then return "" end
    local ok2, text = pcall(Describe, spellID)
    return (ok2 and type(text) == "string" and not Secret(text)) and text:lower() or ""
end
local function Word(global, fallback)
    local w = _G[global]
    return (type(w) == "string" and w ~= "") and w:lower() or fallback
end
-- Every distinct item in the bags.
function ns:BagItemIDs()
    local ids, seen = {}, {}
    local C = C_Container
    if not (type(C) == "table" and type(C.GetContainerNumSlots) == "function" and type(C.GetContainerItemID) == "function") then return ids end
    for bag = 0, 4 do
        local okN, slots = pcall(C.GetContainerNumSlots, bag)
        for slot = 1, (okN and type(slots) == "number") and slots or 0 do
            local ok, id = pcall(C.GetContainerItemID, bag, slot)
            if ok and type(id) == "number" and not Secret(id) and not seen[id] then seen[id] = true; ids[#ids + 1] = id end
        end
    end
    return ids
end

local STONES = {}                                             -- healthstones: free, so used before a potion
for _, id in ipairs({ 5512, 5511, 5509, 5510, 9421, 19004, 19005, 19006, 19007, 19008, 19009, 19010, 19011, 19012, 19013, 22103, 22104, 22105, 36889, 36890, 36891, 36892, 36893, 36894 }) do STONES[id] = true end

-- Which of these to drink: a healthstone before a potion, then the best potion you are high enough for.
-- items: { { id, stone, heals, level, minLevel } ... }
function ns.BestHealItem(items, myLevel)
    local best
    for _, item in ipairs(items or {}) do
        if (item.stone or item.heals) and (item.minLevel or 0) <= (myLevel or 999) then
            local a, b = item.stone and 1 or 0, best and (best.stone and 1 or 0) or -1
            if a > b or (a == b and ((item.level or 0) > (best.level or 0) or ((item.level or 0) == (best.level or 0) and item.id < best.id))) then best = item end
        end
    end
    return best
end
-- The best food (restores health) and drink (restores mana) you are high enough for. One item may be both.
function ns.BestFoodDrink(items, myLevel)
    local food, drink
    for _, item in ipairs(items or {}) do
        if (item.minLevel or 0) <= (myLevel or 999) then
            if item.food and (not food or (item.level or 0) > (food.level or 0)) then food = item end
            if item.drink and (not drink or (item.level or 0) > (drink.level or 0)) then drink = item end
        end
    end
    return food, drink
end

local function MyLevel()
    local level = UnitLevel and UnitLevel("player")
    return (type(level) == "number" and not Secret(level)) and level or 999
end
function ns:FindHealItem()
    local health = Word("HEALTH", "health")
    local list = {}
    for _, id in ipairs(ns:BagItemIDs()) do
        local item = ItemInfo(id)
        if STONES[id] then item.stone = true; list[#list + 1] = item
        elseif item.class == 0 and item.sub == 1 and UseText(id):find(health, 1, true) then item.heals = true; list[#list + 1] = item end
    end
    return ns.BestHealItem(list, MyLevel())
end
function ns:FindFoodDrink()
    local health, mana = Word("HEALTH", "health"), Word("MANA", "mana")
    local list = {}
    for _, id in ipairs(ns:BagItemIDs()) do
        local item = ItemInfo(id)
        if item.class == 0 and item.sub == 5 then
            local text = UseText(id)
            item.food = text:find(health, 1, true) and true or false
            item.drink = text:find(mana, 1, true) and true or false
            if item.food or item.drink then list[#list + 1] = item end
        end
    end
    return ns.BestFoodDrink(list, MyLevel())
end

-- A secure button nobody sees, for a key binding to press.
local function HiddenButton(name)
    local ok, b = pcall(CreateFrame, "Button", name, UIParent, "SecureActionButtonTemplate")
    if not (ok and b and b.SetAttribute) then return nil end
    b:SetSize(1, 1)
    b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -50, 50)
    b:RegisterForClicks("AnyUp", "AnyDown")
    return b
end

_G["BINDING_NAME_CLICK FantasyGlassUIHealKey:LeftButton"] = "Use my best healing potion"
_G["BINDING_NAME_CLICK FantasyGlassUIFoodKey:LeftButton"] = "Eat and drink my best food"
ns:NewModule("quickKeys", function()
    local heal, food = HiddenButton("FantasyGlassUIHealKey"), HiddenButton("FantasyGlassUIFoodKey")
    if not (heal and food) then ns.quickKeysState = "this game client has no secure buttons for add-ons"; return end
    local dirty = true
    local function Assign()
        if InCombatLockdown() then return false end
        dirty = false
        local potion = ns:FindHealItem()
        heal:SetAttribute("type", "item")
        heal:SetAttribute("item", potion and ("item:" .. potion.id) or nil)
        local eat, drink = ns:FindFoodDrink()
        local lines = {}
        if eat then lines[#lines + 1] = "/use item:" .. eat.id end
        if drink and (not eat or drink.id ~= eat.id) then lines[#lines + 1] = "/use item:" .. drink.id end
        food:SetAttribute("type", "macro")
        food:SetAttribute("macrotext", table.concat(lines, "\n"))
        ns.quickKeysNow = { potion = potion and potion.id, food = eat and eat.id, drink = drink and drink.id }
        ns.quickKeysState = format("on; healing: %s; food: %s; drink: %s", potion and (potion.name or ("item " .. potion.id)) or "none in your bags",
            eat and (eat.name or ("item " .. eat.id)) or "none", drink and (drink.name or ("item " .. drink.id)) or "none")
        return true
    end
    ns.quickKeysTest = { Assign = Assign, heal = heal, food = food }
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_LEVEL_UP", "GET_ITEM_INFO_RECEIVED" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("QuickKeys events", function() dirty = true end))
    ns:Every(1, "Quick keys", function() if dirty and not InCombatLockdown() then pcall(Assign) end end)
end)

------------------------------------------------------------------------------------------
-- Mount key: a random favorite mount (the game picks one that works where you are); pressed
-- again, it gets you off. Bind it in the game's key bindings, or type /fgui mount.
------------------------------------------------------------------------------------------
function ns:MountUp()
    if InCombatLockdown() then ns:Print("Not during a fight."); return false end
    if ns.Yes(IsMounted and IsMounted()) then
        if Dismount then pcall(Dismount) end
        return "dismounted"
    end
    local M = C_MountJournal
    if not (type(M) == "table" and type(M.SummonByID) == "function") then
        ns:Print("This game client has no mount collection an add-on can use.")
        return false
    end
    return pcall(M.SummonByID, 0) and "summoned" or false
end

------------------------------------------------------------------------------------------
-- A row of secure buttons that is given a list: { { kind = "item"|"spell"|"macro", value, icon, id, tip } ... }.
------------------------------------------------------------------------------------------
function ns:SecureRow(name, size, gap, max)
    local holder = CreateFrame("Frame", name, UIParent)
    holder:SetSize(size, size)
    holder.buttons, holder.pending = {}, false
    local function Button(i)
        local ok, b = pcall(CreateFrame, "Button", name .. i, holder, "SecureActionButtonTemplate")
        if not (ok and b and b.SetAttribute) then return nil end
        b:SetSize(size, size)
        b:SetPoint("LEFT", holder, "LEFT", (i - 1) * (size + gap), 0)
        b:RegisterForClicks("AnyUp", "AnyDown")
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.hl = b:CreateTexture(nil, "HIGHLIGHT")
        b.hl:SetAllPoints()
        b.hl:SetTexture(ns.FLAT)
        b.hl:SetVertexColor(1, 1, 1, 0.18)
        local okC, cd = pcall(CreateFrame, "Cooldown", nil, b, "CooldownFrameTemplate")
        if okC and cd then cd:SetAllPoints(); b.cd = cd end
        b.count = ns:NewText(b, 11, "RIGHT")
        b.count:SetPoint("BOTTOMRIGHT", -1, 2)
        ns:AddBorder(b, 0, 0, 0, 1)
        b:HookScript("OnEnter", function(self)
            local e = self.entry
            if not e then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            local shown = false
            if e.kind == "spell" and GameTooltip.SetSpellByID then shown = pcall(GameTooltip.SetSpellByID, GameTooltip, e.id) end
            if e.kind ~= "spell" and e.id and GameTooltip.SetItemByID then shown = pcall(GameTooltip.SetItemByID, GameTooltip, e.id) end
            if not shown then GameTooltip:AddLine(tostring(e.tip or e.value or "")) end
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function() GameTooltip:Hide() end)
        b:Hide()
        holder.buttons[i] = b
        return b
    end
    -- Returns how many are shown, or false when it has to wait for the fight to end.
    function holder:Set(list)
        if InCombatLockdown() then self.pending = list; return false end
        self.pending = false
        local n = math.min(#list, max or 12)
        for i = 1, math.max(n, #self.buttons) do
            local e, b = list[i], self.buttons[i]
            if e and i <= n then
                b = b or Button(i)
                if b then
                    b.entry = e
                    b:SetAttribute("type", e.kind)
                    b:SetAttribute("item", e.kind == "item" and e.value or nil)
                    b:SetAttribute("spell", e.kind == "spell" and e.value or nil)
                    b:SetAttribute("macrotext", e.kind == "macro" and e.value or nil)
                    pcall(b.icon.SetTexture, b.icon, e.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                    b.count:SetText(e.count and e.count > 1 and tostring(e.count) or "")
                    b:Show()
                end
            elseif b then
                b.entry = nil
                b:Hide()
            end
        end
        self:SetWidth(math.max(1, n) * (size + gap) - gap)
        self.shown = n
        return n
    end
    return holder
end

------------------------------------------------------------------------------------------
-- Open-all button: shows while something in your bags can be opened (a lockbox you can open, a
-- clam, a bag of loot). Each click opens one.
------------------------------------------------------------------------------------------
-- The things in the bags that hold loot: { bag, slot, id, icon }.
function ns:Openables()
    local out = {}
    local C = C_Container
    if not (type(C) == "table" and type(C.GetContainerNumSlots) == "function" and type(C.GetContainerItemInfo) == "function") then return out end
    for bag = 0, 4 do
        local okN, slots = pcall(C.GetContainerNumSlots, bag)
        for slot = 1, (okN and type(slots) == "number") and slots or 0 do
            local ok, info = pcall(C.GetContainerItemInfo, bag, slot)
            if ok and type(info) == "table" and ns.Is(info.hasLoot, true) and not ns.Is(info.isLocked, true) then
                out[#out + 1] = { bag = bag, slot = slot, id = info.itemID, icon = info.iconFileID }
            end
        end
    end
    return out
end
ns:NewModule("openAll", function()
    local row = ns:SecureRow("FantasyGlassUIOpenAll", 34, 4, 1)
    row:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -260, 240)
    local dirty = true
    local function Assign()
        if InCombatLockdown() then return false end
        dirty = false
        local list = ns:Openables()
        local first = list[1]
        local shown = row:Set(first and { { kind = "item", value = first.bag .. " " .. first.slot, icon = first.icon, id = first.id, count = #list } } or {})
        ns.openAllState = format("on; %d to open", #list)
        return shown, #list
    end
    ns.openAllTest = { Assign = Assign, row = row }
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("QuickKeys events", function() dirty = true end))
    ns:Every(0.5, "Open-all button", function() if dirty and not InCombatLockdown() then pcall(Assign) end end)
    local entry = ns:RegisterMovable(row, "openAll", "Open all")
    if type(entry) == "table" then entry.offPage = true end        -- (scaled from its own right-click menu in move mode)
end)

------------------------------------------------------------------------------------------
-- Travel bar: your hearthstone and every teleport or portal you know, with their cooldowns.
------------------------------------------------------------------------------------------
ns.travelItems = { 6948, 110560, 140192, 141605, 64488, 54452, 93672, 142542, 162973, 163045, 165669, 165670, 165802, 166746, 166747, 168907, 172179 }
ns.travelSpells = { 556,                                                              -- Astral Recall
    3561, 3562, 3563, 3565, 3566, 3567, 32271, 32272, 33690, 35715, 49358, 49359, 53140, 88342, 88344, 120145, 132621, 132627, 176242, 176248, 193759, 224869, 281403, 281404, 344587, 395277,
    10059, 11416, 11417, 11418, 11419, 11420, 32266, 32267, 33691, 35717, 49360, 49361, 53142, 88345, 88346, 120146, 132620, 132626, 176244, 176246, 224871, 281400, 281402, 344597, 395289,
    18960, 193753, 50977, 126892, 126895 }
local function Knows(spell)
    for _, probe in ipairs({ C_SpellBook and C_SpellBook.IsSpellKnown, _G.IsPlayerSpell, _G.IsSpellKnown }) do
        if type(probe) == "function" then
            local ok, yes = pcall(probe, spell)
            if ok then return ns.Is(yes, true) end
        end
    end
    return false
end
function ns:TravelList()
    local list = {}
    local Count = (C_Item and C_Item.GetItemCount) or GetItemCount
    for _, id in ipairs(ns.travelItems) do
        local ok, n = pcall(Count, id)
        if ok and type(n) == "number" and not Secret(n) and n > 0 then
            local item = ItemInfo(id)
            list[#list + 1] = { kind = "item", value = "item:" .. id, id = id, icon = item.icon }
        end
    end
    for _, id in ipairs(ns.travelSpells) do
        if Knows(id) then
            local icon
            if C_Spell and C_Spell.GetSpellTexture then local ok, t = pcall(C_Spell.GetSpellTexture, id); if ok then icon = t end
            elseif GetSpellTexture then local ok, t = pcall(GetSpellTexture, id); if ok then icon = t end end
            list[#list + 1] = { kind = "spell", value = id, id = id, icon = icon }
        end
    end
    return list
end
ns:NewModule("travelBar", function()
    local row = ns:SecureRow("FantasyGlassUITravel", 30, 4, 16)
    row:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 230)
    local dirty = true
    local function Assign()
        if InCombatLockdown() then return false end
        dirty = false
        local n = row:Set(ns:TravelList())
        ns.travelState = format("on; %d ways to travel", n or 0)
        return n
    end
    local function Tick()
        for _, b in ipairs(row.buttons) do
            local e = b.entry
            if e and b.cd then
                pcall(function()
                    local start, duration
                    if e.kind == "spell" then
                        if C_Spell and C_Spell.GetSpellCooldown then local cd = C_Spell.GetSpellCooldown(e.id); start, duration = cd.startTime, cd.duration
                        else start, duration = GetSpellCooldown(e.id) end
                    else
                        local Get = (C_Container and C_Container.GetItemCooldown) or (C_Item and C_Item.GetItemCooldown) or GetItemCooldown
                        start, duration = Get(e.id)
                    end
                    b.cd:SetCooldown(start, duration)
                end)
            end
        end
    end
    ns.travelTest = { Assign = Assign, row = row }
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "SPELLS_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("QuickKeys events", function() dirty = true end))
    ns:Every(1, "Travel bar", function()
        if dirty and not InCombatLockdown() then pcall(Assign) end
        Tick()
    end)
    local entry = ns:RegisterMovable(row, "travel", "Travel")
    if type(entry) == "table" then entry.offPage = true end        -- (scaled from its own right-click menu in move mode)
end)

------------------------------------------------------------------------------------------
-- Home key (11.7): one key for the best way home that is ready now. Your hearthstone (or a
-- hearthstone toy) first, then Astral Recall, then a class teleport; when nothing is ready, the
-- hearthstone anyway, so the game says how long is left. Bind it in Key Bindings, AddOns, or
-- /fgui home says what it would use.
------------------------------------------------------------------------------------------
_G["BINDING_NAME_CLICK FantasyGlassUIHomeKey:LeftButton"] = "Best way home (hearthstone, Astral Recall, teleport)"
local HEARTHS = { [6948] = true, [64488] = true, [54452] = true, [93672] = true, [142542] = true, [162973] = true, [163045] = true,
    [165669] = true, [165670] = true, [165802] = true, [166746] = true, [166747] = true, [168907] = true, [172179] = true }
local function Ready(e)
    local ok, start, duration = pcall(function()
        if e.kind == "spell" then
            if C_Spell and C_Spell.GetSpellCooldown then local cd = C_Spell.GetSpellCooldown(e.id); return cd and cd.startTime, cd and cd.duration end
            return GetSpellCooldown(e.id)
        end
        local Get = (C_Container and C_Container.GetItemCooldown) or (C_Item and C_Item.GetItemCooldown) or GetItemCooldown
        return Get(e.id)
    end)
    if not ok or Secret(start) or Secret(duration) then return nil end
    return not (type(duration) == "number" and duration > 1.5)
end
-- The choice, from the ways you have: hearthstones first, then Astral Recall, then the rest.
function ns.BestWayHome(list, ready)
    ready = ready or Ready
    local function rank(e)
        if e.kind == "item" and HEARTHS[e.id] then return (e.id == 6948) and 1 or 2 end
        if e.kind == "spell" and e.id == 556 then return 3 end
        return 4
    end
    local sorted = {}
    for _, e in ipairs(list) do sorted[#sorted + 1] = e end
    table.sort(sorted, function(a, b) if rank(a) ~= rank(b) then return rank(a) < rank(b) end return a.id < b.id end)
    for _, e in ipairs(sorted) do if ready(e) then return e, true end end
    return sorted[1], false
end
function ns:HomeCommand()
    local e, ready = ns.BestWayHome(ns:TravelList())
    if not e then ns:Print("You have no hearthstone, Astral Recall or teleport."); return nil end
    local name = (e.kind == "spell") and (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(e.id)) or ns:GetItemInfo(e.id)
    ns:Print(ready and "The home key uses %s." or "Nothing is ready: the home key uses %s, which is still cooling down.", tostring(name or e.id))
    return e, ready
end
ns:NewModule("homeKey", function()
    local key = HiddenButton("FantasyGlassUIHomeKey")
    if not key then ns.homeKeyState = "this game client has no secure buttons for add-ons"; return end
    local dirty = true
    local function Assign()
        if InCombatLockdown() then return false end
        dirty = false
        local e = ns.BestWayHome(ns:TravelList())
        if not e then key:SetAttribute("type", nil); ns.homeKeyState = "on; no way home known"; return false end
        if e.kind == "spell" then
            key:SetAttribute("type", "spell"); key:SetAttribute("spell", e.id); key:SetAttribute("item", nil)
        else
            key:SetAttribute("type", "item"); key:SetAttribute("item", "item:" .. e.id); key:SetAttribute("spell", nil)
        end
        ns.homeKeyState = "on; " .. e.kind .. " " .. e.id
        return e
    end
    ns.homeKeyTest = { Assign = Assign, key = key }
    -- New spells or items: choose again at once. Cooldowns tick with every spell cast, so for those
    -- choose again at most every ten seconds (a hearthstone's cooldown is counted in minutes).
    local ev = CreateFrame("Frame")
    local cooled, last = false, 0
    for _, e in ipairs({ "SPELLS_CHANGED", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("QuickKeys events", function(_, event)
        if event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" then cooled = true else dirty = true end
    end))
    ns:Every(2, "Home key", function()
        if InCombatLockdown() then return end
        local now = GetTime()
        if dirty or (cooled and now - last >= 10) then
            cooled, last = false, now
            pcall(Assign)
        end
    end)
end)
