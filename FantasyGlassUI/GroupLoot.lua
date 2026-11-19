local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end
local PREFIX = "FGUI"

------------------------------------------------------------------------------------------
-- Whose upgrade (11.14): when a boss drops something rare or better, the players in your group who
-- use Fantasy Glass UI each work out whether it is an upgrade for them and quietly tell the others.
-- A small panel then says, item by item, whose upgrade it is and by how many item levels, biggest
-- first - so the group knows before anyone rolls. Nothing is said in chat; players without the
-- add-on are simply not on the list.
--
-- Two ways an item is heard of: a loot roll (everyone sees it and answers for themselves), and a
-- loot window (whoever opens it asks the others about what is in it).
-- Messages: GLQ:<id>,<id>  "is any of these an upgrade for you?"   GLU:<id>:<levels>  "for me, by this much" (0: no)
------------------------------------------------------------------------------------------
local MIN_QUALITY, KEEP_FOR, ROWS = 3, 120, 4

-- What we have heard, item by item: heard[id] = { link, at, who = { [name] = levels } }.
local heard = {}
ns.groupLootHeard = heard

function ns.GroupLootParse(msg)
    if type(msg) ~= "string" then return nil end
    local list = msg:match("^GLQ:([%d,]+)$")
    if list then
        local ids = {}
        for id in list:gmatch("%d+") do ids[#ids + 1] = tonumber(id) end
        return "ask", ids
    end
    local id, lv = msg:match("^GLU:(%d+):(%d+)$")
    if id then return "answer", tonumber(id), tonumber(lv) end
    return nil
end
-- One answer in: `levels` 0 is "not for me".
function ns.GroupLootHear(id, link, who, levels, now)
    if type(id) ~= "number" or type(who) ~= "string" then return nil end
    local e = heard[id] or { who = {} }
    e.link = e.link or link
    e.at = now or GetTime()
    e.who[who] = tonumber(levels) or 0
    heard[id] = e
    return e
end
-- Who it is an upgrade for, biggest first: { { name, levels } }, and how many answered.
function ns.GroupLootWho(e)
    local list, answered = {}, 0
    for name, lv in pairs(type(e) == "table" and e.who or {}) do
        answered = answered + 1
        if lv > 0 then list[#list + 1] = { name = name, levels = lv } end
    end
    table.sort(list, function(a, b) if a.levels ~= b.levels then return a.levels > b.levels end return a.name < b.name end)
    return list, answered
end

local function LinkFor(id)
    local ok, _, link = pcall(ns.GetItemInfo, ns, id)
    if ok and type(link) == "string" then return link end
    return "item:" .. tostring(id)
end
local function Quality(link)
    local ok, _, _, q = pcall(ns.GetItemInfo, ns, link)
    return (ok and type(q) == "number" and not Secret(q)) and q or nil
end
local function ItemID(link) return type(link) == "string" and not Secret(link) and tonumber(link:match("item:(%d+)")) or nil end
-- How much of an upgrade an item is for me, in item levels (0: none, or not something I could use).
local function MyLevels(link)
    local ok, by = pcall(ns.UpgradeAmount, link)
    by = ok and tonumber(by) or nil
    return by and math.max(1, math.floor(by + 0.5)) or 0
end

ns:NewModule("groupLoot", function()
    local me = UnitName and UnitName("player")
    -- the panel
    local f = CreateFrame("Frame", "FantasyGlassUIGroupLoot", UIParent, ns.template)
    f:SetSize(300, 30)
    f:SetPoint("TOP", UIParent, "TOP", 0, -240)
    f:SetBackdrop(ns.BACKDROP)
    ns:Paint(f, "SetBackdropColor", "bg", 0.85)
    ns:Paint(f, "SetBackdropBorderColor", "@border", 1)
    f.title = ns:NewText(f, 11, "LEFT", true)
    f.title:SetPoint("TOPLEFT", 8, -6)
    f.title:SetText(ns:Tr("Whose upgrade"))
    ns:Paint(f.title, "SetTextColor", "@accent")
    f.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Frame", nil, f)
        r:SetSize(284, 32)
        r:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -22 - (i - 1) * 34)
        r.item = ns:NewText(r, 11, "LEFT")
        r.item:SetPoint("TOPLEFT"); r.item:SetPoint("TOPRIGHT")
        if r.item.SetWordWrap then r.item:SetWordWrap(false) end
        r.who = ns:NewText(r, 10, "LEFT")
        r.who:SetPoint("BOTTOMLEFT"); r.who:SetPoint("BOTTOMRIGHT")
        if r.who.SetWordWrap then r.who:SetWordWrap(false) end
        r:EnableMouse(true)
        r:SetScript("OnEnter", function(self)
            if not (self.link and GameTooltip) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        r:Hide()
        f.rows[i] = r
    end
    f:Hide()
    local entry = ns:RegisterMovable(f, "groupLoot", "Whose upgrade")
    if type(entry) == "table" then entry.offPage = true end        -- (scaled from its own right-click menu in move mode)

    local function ClassHex(name)
        for _, m in ipairs(ns.GroupMembers and ns:GroupMembers() or {}) do
            if ns.GroupShortName(m.name) == name and m.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class] then
                local c = RAID_CLASS_COLORS[m.class]
                return format("|cff%02x%02x%02x", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
            end
        end
        if name == me then local r, g, b = ns:ClassColor("player"); if r then return format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)) end end
        return "|cffffffff"
    end
    local function Draw()
        local now = GetTime()
        local items = {}
        for id, e in pairs(heard) do
            if now - (e.at or 0) > KEEP_FOR then heard[id] = nil else items[#items + 1] = { id = id, e = e } end
        end
        table.sort(items, function(a, b) return (a.e.at or 0) > (b.e.at or 0) end)
        local n = 0
        for i, row in ipairs(f.rows) do
            local it = items[i]
            if it then
                n = i
                row.link = it.e.link
                row.item:SetText(tostring(it.e.link or LinkFor(it.id)))
                local list, answered = ns.GroupLootWho(it.e)
                if #list == 0 then
                    row.who:SetText("|cff9aa4b4" .. format(ns:TrN(answered, "An upgrade for no one (%d player with the add-on).", "An upgrade for no one (%d players with the add-on)."), answered) .. "|r")
                else
                    local bits = {}
                    for _, w in ipairs(list) do bits[#bits + 1] = ClassHex(w.name) .. w.name .. "|r " .. ns:SignalHex("good") .. "+" .. w.levels .. "|r" end
                    row.who:SetText(table.concat(bits, ",  "))
                end
                row:Show()
            else
                row:Hide()
            end
        end
        f:SetHeight(26 + n * 34)
        f:SetShown(n > 0 or ns.moving)
        f.count = n
        return n
    end
    -- An item heard of: answer for myself, and show it.
    local function Consider(link, ask)
        local id = ItemID(link)
        if not id then return end
        local q = Quality(link)
        if q and q < MIN_QUALITY then return end
        local ch = ns.GroupChannel()
        if not ch then return end
        local mine = MyLevels(link)
        ns.GroupLootHear(id, link, me, mine)
        ns.GroupSend("GLU:" .. id .. ":" .. mine, ch)
        if ask then return id end
        Draw()
    end
    ns.groupLootTest = { Draw = Draw, Consider = Consider, frame = f }

    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "CHAT_MSG_ADDON", "START_LOOT_ROLL", "LOOT_OPENED" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Whose upgrade", function(_, event, a, b, _, d)
        if event == "START_LOOT_ROLL" then
            local ok, link = pcall(GetLootRollItemLink, a)
            if ok then Consider(link) end
        elseif event == "LOOT_OPENED" then
            local ids = {}
            for slot = 1, (GetNumLootItems and GetNumLootItems() or 0) do
                local ok, link = pcall(GetLootSlotLink, slot)
                if ok and link then local id = Consider(link, true); if id then ids[#ids + 1] = id end end
            end
            local ch = ns.GroupChannel()
            if ch and #ids > 0 then ns.GroupSend("GLQ:" .. table.concat(ids, ","), ch); Draw() end
        elseif event == "CHAT_MSG_ADDON" then
            if Secret(a) or Secret(b) or a ~= PREFIX or type(b) ~= "string" then return end
            local kind, x, y = ns.GroupLootParse(b)
            if not kind then return end
            local from = ns.GroupShortName(d)
            if not from or from == me then return end
            if kind == "ask" then
                local ch = ns.GroupChannel()
                for _, id in ipairs(x) do
                    local link = LinkFor(id)
                    local mine = MyLevels(link)
                    ns.GroupLootHear(id, link, me, mine)
                    if ch then ns.GroupSend("GLU:" .. id .. ":" .. mine, ch) end
                end
            else
                ns.GroupLootHear(x, LinkFor(x), from, y)
            end
            Draw()
        end
    end))
    ns:Every(5, "Whose upgrade", function() if f:IsShown() then Draw() end end)
    ns:RegisterPreview(function(on)
        if on then
            ns.GroupLootHear(18205, LinkFor(18205), "Kaelith", 12, GetTime())
            ns.GroupLootHear(18205, nil, "Sylvae", 4, GetTime())
            ns.GroupLootHear(18205, nil, "Brannoc", 0, GetTime())
        else
            heard[18205] = nil
        end
        Draw()
    end)
end)
