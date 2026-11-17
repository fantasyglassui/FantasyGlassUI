local ADDON, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- 10.8: the session card, a cooldown timeline, quest rewards on the tracker, a ready-check report,
-- rare spawn memory on the map, theme by place, combat text in your lettering, a crafting queue,
-- a goals panel and a login splash.
------------------------------------------------------------------------------------------
local function Count(id, bank)
    local Get = (C_Item and C_Item.GetItemCount) or GetItemCount
    if type(Get) ~= "function" then return 0 end
    local ok, n = pcall(Get, id, bank and true or false)
    return (ok and type(n) == "number" and not Secret(n)) and n or 0
end
local function ItemName(id)
    local ok, name = pcall(function() return ns:GetItemInfo(id) end)
    return (ok and type(name) == "string") and name or ("item " .. tostring(id))
end
local function Short(n)
    n = tonumber(n) or 0
    if n >= 1000000 then return format("%.1fm", n / 1000000) end
    if n >= 10000 then return format("%dk", math.floor(n / 1000 + 0.5)) end
    if n >= 1000 then return format("%.1fk", n / 1000) end
    return tostring(math.floor(n))
end

------------------------------------------------------------------------------------------
-- Session card: /fgui session (or the Tools tab) shows this session as a card, with your last
-- session on this character under it.
------------------------------------------------------------------------------------------
function ns:ShowSession()
    local lines = {}
    for _, row in ipairs(ns.SessionStats and ns:SessionStats() or {}) do
        lines[#lines + 1] = { left = row[1], right = "|cffffffff" .. tostring(row[2]) .. "|r" }
    end
    local S = ns.session
    if S and (S.loot or 0) > 0 then lines[#lines + 1] = { left = ns:Tr("Items looted"), right = "|cffffffff" .. S.loot .. "|r" } end
    local last = type(ns.root) == "table" and type(ns.root.lastSession) == "table" and ns.root.lastSession[ns:CharKey()]
    if type(last) == "table" and type(last.rows) == "table" then
        lines[#lines + 1] = { left = " " }
        lines[#lines + 1] = { left = ns:AccentHex() .. ns:Tr("Last session") .. "|r", right = "|cff9aa4b4" .. tostring(last.when or "") .. "|r" }
        for _, row in ipairs(last.rows) do lines[#lines + 1] = { left = "|cff9aa4b4" .. tostring(row[1]) .. "|r", right = "|cffc8ccd6" .. tostring(row[2]) .. "|r" } end
    end
    return ns:ShowList("Session", "This session", lines, "Counted since you logged in on this character.", 380, 330)
end
do  -- the session is kept for next time when you log out (a /reload carries the session on instead)
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_LOGOUT")
    ev:RegisterEvent("CHAT_MSG_LOOT")
    local pattern
    ev:SetScript("OnEvent", function(_, event, msg)
        local S = ns.session
        if event == "CHAT_MSG_LOOT" then
            if type(msg) ~= "string" or Secret(msg) or not S then return end
            pattern = pattern or ns.GamePattern(_G.LOOT_ITEM_SELF)
            local pm = ns.GamePattern(_G.LOOT_ITEM_SELF_MULTIPLE)
            local item, n
            if pm then item, n = msg:match(pm) end                         -- (the item and how many)
            if item then S.loot = (S.loot or 0) + (tonumber(n) or 1)
            elseif pattern and msg:match(pattern) then S.loot = (S.loot or 0) + 1 end
            return
        end
        if type(ns.root) ~= "table" or not ns.SessionStats then return end
        local ok, rows = pcall(ns.SessionStats, ns)
        if not ok then return end
        if type(ns.root.lastSession) ~= "table" then ns.root.lastSession = {} end
        local okD, when = pcall(date, "%d %b %H:%M")
        ns.root.lastSession[ns:CharKey()] = { rows = rows, when = okD and when or "" }
    end)
end

------------------------------------------------------------------------------------------
-- Quest rewards on the tracker: the experience and money each quest gives, beside its name.
------------------------------------------------------------------------------------------
function ns.QuestRewardText(xp, money, complete)
    local parts = {}
    if type(xp) == "number" and xp > 0 then parts[#parts + 1] = Short(xp) .. " xp" end
    if type(money) == "number" and money >= 100 then
        local g, s = math.floor(money / 10000), math.floor(money % 10000 / 100)
        parts[#parts + 1] = (g > 0) and (g .. "g" .. (s > 0 and (" " .. s .. "s") or "")) or (s .. "s")
    end
    if #parts == 0 then return "" end
    return (complete and "  |cffffd100" or "  |cff8c93a3") .. table.concat(parts, ", ") .. "|r"
end
function ns:QuestRewards(questID)
    if not ns.db.questRewards or type(questID) ~= "number" then return nil end
    local xp, money
    if GetQuestLogRewardXP then local ok, v = pcall(GetQuestLogRewardXP, questID); if ok and type(v) == "number" and not Secret(v) then xp = v end end
    if GetQuestLogRewardMoney then local ok, v = pcall(GetQuestLogRewardMoney, questID); if ok and type(v) == "number" and not Secret(v) then money = v end end
    return xp, money
end

------------------------------------------------------------------------------------------
-- Cooldown timeline: the abilities on your cooldown tracker list, sliding along one slim bar towards
-- "ready" at its left end. The scale is stretched at the short end (1, 5, 30 seconds, 1, 5 minutes),
-- so the last seconds of a cooldown are easy to read. While the game hides cooldowns in a fight,
-- what it hides cannot be placed: those icons wait at the right end with the game's own sweep.
------------------------------------------------------------------------------------------
local TL_MAX = 300
function ns.TimelineX(remaining, width)
    remaining = math.max(0, math.min(TL_MAX, tonumber(remaining) or 0))
    return math.floor(math.log(1 + remaining) / math.log(1 + TL_MAX) * (tonumber(width) or 0) + 0.5)
end
ns:NewModule("cdTimeline", function()
    local W, H, SIZE = 320, 26, 22
    local f = CreateFrame("Frame", "FantasyGlassUICooldownTimeline", UIParent, ns.template)
    f:SetSize(W, H)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, -230)
    if f.SetBackdrop then f:SetBackdrop(ns.BACKDROP); ns:Paint(f, "SetBackdropColor", "bg", 0.75); ns:Paint(f, "SetBackdropBorderColor", "@border", 1) end
    for _, s in ipairs({ 1, 5, 30, 60, 300 }) do
        local tick = f:CreateTexture(nil, "ARTWORK")
        tick:SetTexture(ns.FLAT)
        ns:Paint(tick, "SetVertexColor", "@border", 0.8)
        tick:SetSize(1, H - 8)
        tick:SetPoint("LEFT", f, "LEFT", 4 + ns.TimelineX(s, W - 8), 0)
        local label = ns:NewText(f, 9, "CENTER")
        label:SetPoint("TOP", tick, "BOTTOM", 0, -1)
        label:SetText(s >= 60 and (s / 60 .. "m") or tostring(s))
        ns:Paint(label, "SetTextColor", "faint")
    end
    local icons = {}
    local function Icon(i)
        local b = CreateFrame("Frame", nil, f)
        b:SetSize(SIZE, SIZE)
        b:SetFrameLevel(f:GetFrameLevel() + 2 + i)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        ns:AddBorder(b, 0, 0, 0, 1)
        local ok, cd = pcall(CreateFrame, "Cooldown", nil, b, "CooldownFrameTemplate")
        if ok and cd then cd:SetAllPoints(); if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end; b.cd = cd end
        icons[i] = b
        return b
    end
    local function Info(name)
        local id, icon
        if C_Spell and C_Spell.GetSpellInfo then
            local ok, info = pcall(C_Spell.GetSpellInfo, name)
            if ok and type(info) == "table" then id, icon = info.spellID, info.iconID end
        end
        return id, icon
    end
    local function Cooldown(id)
        if not (C_Spell and C_Spell.GetSpellCooldown) then return nil end
        local ok, cd = pcall(C_Spell.GetSpellCooldown, id)
        if not (ok and type(cd) == "table") then return nil end
        return cd.startTime, cd.duration, cd
    end
    local function Update()
        local n = 0
        local now = GetTime()
        for _, name in ipairs(type(ns.db.cooldownSpells) == "table" and ns.db.cooldownSpells or {}) do
            local id, icon = Info(name)
            if id then
                local start, duration, raw = Cooldown(id)   -- luacheck: ignore
                local hidden = Secret(start) or Secret(duration)
                local remaining = (not hidden and type(start) == "number" and type(duration) == "number" and duration > 1.6) and (start + duration - now) or 0
                if hidden or remaining > 0 or ns.moving then
                    n = n + 1
                    local b = icons[n] or Icon(n)
                    b.tex:SetTexture(icon)
                    b:ClearAllPoints()
                    local x = hidden and (W - 8) or ns.TimelineX(ns.moving and (n * 7) or remaining, W - 8)
                    b:SetPoint("CENTER", f, "LEFT", 4 + x, 0)
                    if b.cd then pcall(b.cd.SetCooldown, b.cd, start, duration) end
                    b:SetAlpha(hidden and 0.6 or 1)
                    b:Show()
                end
            end
        end
        for i = n + 1, #icons do icons[i]:Hide() end
        f:SetAlpha((n > 0 or ns.moving) and 1 or 0.35)
        ns.cdTimelineCount = n
        return n
    end
    ns.cdTimelineTest = { Update = Update, icons = icons, frame = f }
    -- Twenty times a second while something is cooling down; with nothing on it, five times a second
    -- is enough to notice the next one.
    local idleTicks, lastCount = 0, 1
    ns:Every(0.05, "Cooldown timeline", function()
        if (lastCount or 0) == 0 and not ns.moving then
            idleTicks = idleTicks + 1
            if idleTicks < 4 then return end
        end
        idleTicks = 0
        lastCount = Update()
    end)
    local entry = ns:RegisterMovable(f, "cdTimeline", "Cooldown Timeline")
    if type(entry) == "table" then entry.offPage = true end        -- (scaled from its own right-click menu in move mode)
end)

------------------------------------------------------------------------------------------
-- Ready-check report: when a ready check starts (outside a fight), who in the group is missing food,
-- a flask or elixir, or a class buff that someone in the group can give.
------------------------------------------------------------------------------------------
ns.READY_WORDS = {                                           -- (in each client language the add-on speaks)
    food = { "Well Fed", "Satt", "Bien nourri", "Bien alimentado", "Bien Alimentado", "Сытость", "Bem Alimentado", "Ben Nutrito",
             "포만감", "进食充分" },
    flask = { "Flask", "Fläschchen", "Flacon", "Frasco", "Elixir", "Elixier", "Élixir", "Настой", "Эликсир", "Tonico", "Elisir",
              "영약", "비약", "合剂", "药剂" },
}
-- class buffs: the class that gives it, and spells whose names count (all ranks share a name)
ns.READY_BUFFS = {
    { class = "PRIEST", label = "Fortitude", spells = { 1243, 21562 } },
    { class = "DRUID", label = "Mark of the Wild", spells = { 1126, 21849 } },
    { class = "MAGE", label = "Intellect", spells = { 1459, 23028 } },
}
local function Has(names, words)
    for _, n in ipairs(names) do
        local low = n:lower()
        for _, w in ipairs(words) do if low:find(w:lower(), 1, true) then return true end end
    end
    return false
end
-- What one member is missing, from the names of their buffs and the classes in the group.
function ns.ReadyMissing(names, classes, buffNames)
    local out = {}
    if not Has(names, ns.READY_WORDS.food) then out[#out + 1] = "food" end
    if not Has(names, ns.READY_WORDS.flask) then out[#out + 1] = "flask" end
    for _, b in ipairs(ns.READY_BUFFS) do
        if classes[b.class] then
            local have = false
            for _, n in ipairs(names) do if buffNames[b.label] and buffNames[b.label][n] then have = true end end
            if not have then out[#out + 1] = b.label end
        end
    end
    return out
end
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then local ok, n = pcall(C_Spell.GetSpellName, id); if ok and type(n) == "string" then return n end end
    if GetSpellInfo then local ok, n = pcall(GetSpellInfo, id); if ok and type(n) == "string" then return n end end
end
local function BuffNamesOf(unit)
    local names = {}
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil end
    for i = 1, 40 do
        local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
        if not ok or type(a) ~= "table" then break end
        if Secret(a.name) then return nil end
        if type(a.name) == "string" then names[#names + 1] = a.name end
    end
    return names
end
function ns:ReadyReport(quiet)
    if ns.Yes(InCombatLockdown and InCombatLockdown()) then return false end
    local members = ns:GroupMembers()
    table.insert(members, 1, { name = UnitName("player"), unit = "player", class = select(2, UnitClass("player")), online = true })
    local classes = {}
    for _, m in ipairs(members) do if m.class then classes[m.class] = true end end
    local buffNames = {}
    for _, b in ipairs(ns.READY_BUFFS) do
        buffNames[b.label] = {}
        for _, id in ipairs(b.spells) do local n = SpellName(id); if n then buffNames[b.label][n] = true end end
    end
    local lines, short = {}, 0
    for _, m in ipairs(members) do
        local names = m.online and BuffNamesOf(m.unit)
        local r, g, b = 1, 1, 1
        if m.class then local ok, cr, cg, cb = pcall(function() return ns:ClassRGB(m.class) end); if ok and type(cr) == "number" then r, g, b = cr, cg, cb end end
        local right
        if not m.online then right = "|cff9aa4b4" .. ns:Tr("offline") .. "|r"
        elseif not names then right = "|cff9aa4b4" .. ns:Tr("could not be read") .. "|r"
        else
            local miss = ns.ReadyMissing(names, classes, buffNames)
            if #miss == 0 then right = "|cff33ff66" .. ns:Tr("all set") .. "|r"
            else
                short = short + 1
                for i, w in ipairs(miss) do miss[i] = ns:Tr(w) end
                right = "|cffff7766" .. ns:Tr("missing") .. ": " .. table.concat(miss, ", ") .. "|r"
            end
        end
        lines[#lines + 1] = { left = tostring(m.name), right = right, color = { r, g, b } }
    end
    ns.readyReportLast = short
    if quiet and short == 0 then return lines end
    ns:ShowList("ReadyCheck", "Ready check", lines, "Food, flask or elixir, and the class buffs your group can give.", 420, math.min(460, 80 + #lines * 18))
    return lines
end
ns:NewModule("readyReport", function()
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("READY_CHECK")
    ev:SetScript("OnEvent", ns:Guard("Ready-check report", function()
        if ns.Yes(IsInGroup and IsInGroup()) then ns:ReadyReport(true) end
    end))
end)

------------------------------------------------------------------------------------------
-- Rare spawn memory: each rare, treasure or event the rare alert spots is remembered where it was seen,
-- and shown as a mark on the world map. Only what you have found yourself. /fgui rares lists them.
------------------------------------------------------------------------------------------
local function RareStore()
    if type(ns.root) ~= "table" then return {} end
    if type(ns.root.rareSpots) ~= "table" then ns.root.rareSpots = {} end
    return ns.root.rareSpots
end
-- Add a sighting to a map's list; one near an earlier sighting of the same name is the same spot.
function ns.RareRemember(list, name, x, y, when, kind)
    for _, s in ipairs(list) do
        if s.name == name and math.abs(s.x - x) < 0.03 and math.abs(s.y - y) < 0.03 then
            s.seen, s.last = (s.seen or 1) + 1, when
            return s, false
        end
    end
    local s = { name = name, x = x, y = y, seen = 1, last = when, kind = kind }
    list[#list + 1] = s
    while #list > 200 do table.remove(list, 1) end
    return s, true
end
function ns:RareSighted(id, info)
    if not ns.db.rareMemory or type(info) ~= "table" then return end
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if type(mapID) ~= "number" or Secret(mapID) then return end
    local V = C_VignetteInfo
    local ok, pos = pcall(V.GetVignettePosition, id, mapID)
    if not ok or type(pos) ~= "table" then return end
    local x, y = pos.x, pos.y
    if pos.GetXY then local okXY, px, py = pcall(pos.GetXY, pos); if okXY then x, y = px, py end end
    if type(x) ~= "number" or type(y) ~= "number" or Secret(x) or x <= 0 then return end
    local store = RareStore()
    store[mapID] = store[mapID] or {}
    return ns.RareRemember(store[mapID], info.name, x, y, time and time() or 0, ns.VignetteKind and ns.VignetteKind(info.atlasName))
end
function ns:ShowRares()
    local lines = {}
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local store = RareStore()
    for id, list in pairs(store) do
        local okN, mapInfo = pcall(C_Map.GetMapInfo, id)
        local zone = (okN and type(mapInfo) == "table" and mapInfo.name) or ("map " .. tostring(id))
        for _, s in ipairs(list) do
            lines[#lines + 1] = { left = (id == mapID and "|cffffd100" or "") .. s.name .. (id == mapID and "|r" or ""),
                right = format("%s  %.1f, %.1f  |cff9aa4b4x%d|r", zone, s.x * 100, s.y * 100, s.seen or 1),
                click = function() if ns.SetWaypoint then ns:SetWaypoint(s.x * 100, s.y * 100, s.name) end end,
                tip = { s.name, ns:Tr("Click for a waypoint (in that zone).") }, sort = (id == mapID and "0" or "1") .. zone .. s.name }
        end
    end
    table.sort(lines, function(a, b) return a.sort < b.sort end)
    if #lines == 0 then lines[1] = { left = ns:Tr("None yet. Rares the alert spots are remembered here.") } end
    return ns:ShowList("Rares", "Rares you have seen", lines, "Yellow: in this zone. Click one for a waypoint.", 460, 320)
end
ns:NewModule("rareMemory", function()
    local map = _G.WorldMapFrame
    local canvas = type(map) == "table" and ((map.ScrollContainer and map.ScrollContainer.Child) or (map.GetCanvas and map:GetCanvas()))
    if type(canvas) ~= "table" or not canvas.GetWidth then ns.rareMemoryState = "remembered, but this world map has no canvas to mark them on"; return end
    ns.rareMemoryState = "on"
    local pins = {}
    local function Pin(i)
        local p = CreateFrame("Frame", nil, canvas)
        p:SetSize(16, 16)
        p:SetFrameLevel((canvas:GetFrameLevel() or 1) + 19)
        p.tex = p:CreateTexture(nil, "ARTWORK")
        p.tex:SetAllPoints()
        p.tex:SetTexture(ns.MEDIA .. "dot.tga")
        p.ring = p:CreateTexture(nil, "OVERLAY")
        p.ring:SetAllPoints()
        p.ring:SetTexture(ns.MEDIA .. "ring.tga")
        p.ring:SetVertexColor(0, 0, 0, 1)
        p:EnableMouse(true)
        p:SetScript("OnEnter", function(self)
            if not self.spot then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.spot.name, 1, 0.82, 0.2)
            GameTooltip:AddLine(format(ns:Tr("Seen %d times"), self.spot.seen or 1), 1, 1, 1)
            GameTooltip:Show()
        end)
        p:SetScript("OnLeave", function() GameTooltip:Hide() end)
        pins[i] = p
        return p
    end
    local lastMap   -- luacheck: ignore
    local function Update()
        local mapID = map.GetMapID and map:GetMapID()
        local n = 0
        if type(mapID) == "number" and not Secret(mapID) then
            local w, h = canvas:GetWidth(), canvas:GetHeight()
            local scale = canvas.GetScale and canvas:GetScale() or 1
            local size = (type(scale) == "number" and scale > 0) and (1 / scale) or 1
            for _, s in ipairs(RareStore()[mapID] or {}) do
                n = n + 1
                local p = pins[n] or Pin(n)
                p.spot = s
                p:SetScale(size)
                p:ClearAllPoints()
                local px, py = ns.MapDotOffset(s.x, s.y, w, h, size)
                p:SetPoint("CENTER", canvas, "TOPLEFT", px, py)
                if s.kind == "treasure" then p.tex:SetVertexColor(1, 0.82, 0.2) else ns:Paint(p.tex, "SetVertexColor", "@accent", 1) end
                p:Show()
            end
        end
        for i = n + 1, #pins do pins[i]:Hide() end
        lastMap = mapID
        return n
    end
    ns.rareMemoryTest = { Update = Update, pins = pins }
    ns:Every(0.5, "Rares on the map", function() if map.IsShown and ns.Yes(map:IsShown()) then Update() end end)
end)

------------------------------------------------------------------------------------------
-- Theme by place: a theme for cities and inns, dungeons, raids and everywhere else, switched to by
-- itself as you travel. Only between themes of the same family (glass or fantasy): changing family
-- takes a /reload, so a theme of the other family is skipped and said so in /fgui check.
------------------------------------------------------------------------------------------
ns.PLACES = { { "city", "Cities and inns" }, { "dungeon", "Dungeons" }, { "raid", "Raids" }, { "world", "Everywhere else" } }
function ns.PlaceNow(instanceType, resting)
    if instanceType == "raid" then return "raid" end
    if instanceType == "party" or instanceType == "scenario" then return "dungeon" end
    if resting then return "city" end
    return "world"
end
-- Which theme this place wants: its own, or the one you chose yourself (nil: leave it).
function ns.PlaceTheme(places, place, home)
    local want = type(places) == "table" and places[place] or nil
    return want or home
end
function ns:ApplyPlaceTheme(force)
    if not ns.db or not ns.db.themeByPlace then ns.placeState = "off"; return false end
    if ns.Yes(InCombatLockdown and InCombatLockdown()) then ns.placePending = true; return false end
    ns.placePending = nil
    local ok, kind = pcall(function() return select(2, IsInInstance()) end)
    local place = ns.PlaceNow(ok and not Secret(kind) and kind or nil, ns.Yes(IsResting and IsResting()))
    local places = type(ns.db.placeThemes) == "table" and ns.db.placeThemes or {}
    if not ns.db.themeHome then ns.db.themeHome = ns.db.theme end
    local want = ns.PlaceTheme(places, place, ns.db.themeHome)
    local t = want and ns.themes[want]
    ns.placeState = place .. ": " .. tostring(t and t.name or "your own choice")
    if not t or want == ns.db.theme then return false end
    if (t.style or "FANTASY") ~= (ns.style or "FANTASY") then
        ns.placeState = ns.placeState .. " (not switched: the other family needs a /reload)"
        return false
    end
    ns.placeSwitching = true
    ns.db.theme = want
    ns.db.accent = t.accent or ns.db.accent
    pcall(ns.Retheme, ns)
    ns.placeSwitching = nil
    return true
end
-- The theme you pick yourself is the one "everywhere else" falls back to.
function ns:NoteHomeTheme() if not ns.placeSwitching and ns.db then ns.db.themeHome = ns.db.theme end end
do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_UPDATE_RESTING", "PLAYER_REGEN_ENABLED" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Theme by place", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" and not ns.placePending then return end
        if ns.db and ns.db.themeByPlace then ns:ApplyPlaceTheme() end
    end))
end

------------------------------------------------------------------------------------------
-- Combat text in your lettering: the numbers that float up over enemies and you, in the add-on's
-- lettering. The game reads that font as the world loads, so a change shows after a relog.
------------------------------------------------------------------------------------------
function ns:CombatTextFontFile()
    local style = ns.fontStyles and ns.fontStyles[ns.db and ns.db.fontStyle or "GLASS"]
    if type(style) ~= "table" then return nil end
    local file = style.title or style.body
    return file and (ns.MEDIA .. file) or nil
end
do
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("ADDON_LOADED")
    ev:RegisterEvent("PLAYER_LOGIN")
    -- The numbers over heads take their font as the add-on loads, before settings are worked out, so the
    -- file chosen last time is kept with the account settings and set straight away.
    ev:SetScript("OnEvent", function(self, event, name)
        if event == "ADDON_LOADED" then
            if name ~= ADDON then return end
            local file = type(FantasyGlassUIDB) == "table" and FantasyGlassUIDB.combatTextFile
            if type(file) == "string" and file ~= "" then _G.DAMAGE_TEXT_FONT = file end
            return
        end
        self:UnregisterAllEvents()
        if type(ns.root) ~= "table" or not ns.db then return end
        local file = ns.db.combatTextFont and ns:CombatTextFontFile() or nil
        local before = ns.root.combatTextFile
        ns.root.combatTextFile = file
        if not file then ns.combatTextState = before and "off; the game's own font comes back after a relog" or "off"; return end
        _G.DAMAGE_TEXT_FONT = file                           -- the numbers over heads
        if _G.CombatTextFont and CombatTextFont.GetFont then  -- the game's scrolling combat text
            local _, size, flags = CombatTextFont:GetFont()
            pcall(CombatTextFont.SetFont, CombatTextFont, file, size or 25, flags or "")
        end
        ns.combatTextState = (before == file) and ("on (" .. tostring(ns.db.fontStyle or "GLASS") .. ")")
            or "on; the numbers over heads change after a relog"
    end)
end

------------------------------------------------------------------------------------------
-- Crafting queue: recipes to make, each with how many, and one shopping list for the lot.
--   /fgui queue         adds the recipe selected in your profession window (/fgui queue 5: five)
--   /fgui queue list    the queue: click a line to make it (profession window open), right-click to remove
------------------------------------------------------------------------------------------
local function Queue()
    if type(ns.root) ~= "table" then return {} end
    if type(ns.root.craftQueue) ~= "table" then ns.root.craftQueue = {} end
    local key = ns:CharKey()
    if type(ns.root.craftQueue[key]) ~= "table" then ns.root.craftQueue[key] = {} end
    return ns.root.craftQueue[key]
end
ns.CraftQueue = Queue
function ns.QueueAdd(queue, recipeID, name, times)
    times = math.max(1, math.floor(tonumber(times) or 1))
    for _, q in ipairs(queue) do
        if q.id == recipeID then q.times = q.times + times; return q end
    end
    local q = { id = recipeID, name = name, times = times }
    queue[#queue + 1] = q
    return q
end
-- Everything the queue needs, added up: { [itemID] = count }.
function ns.QueueNeeds(queue, reagentsOf)
    local need = {}
    for _, q in ipairs(queue) do
        for _, r in ipairs(reagentsOf(q.id) or {}) do need[r.id] = (need[r.id] or 0) + r.need * q.times end
    end
    return need
end
local function ReagentsOf(recipeID)
    local T = C_TradeSkillUI
    if type(T) ~= "table" or type(T.GetRecipeSchematic) ~= "function" then return {} end
    local ok, schematic = pcall(T.GetRecipeSchematic, recipeID, false)
    if not (ok and type(schematic) == "table" and type(schematic.reagentSlotSchematics) == "table") then return {} end
    local out = {}
    for _, slot in ipairs(schematic.reagentSlotSchematics) do
        local first = type(slot.reagents) == "table" and slot.reagents[1]
        local basic = slot.reagentType == nil or slot.reagentType == 1 or ns.Is(slot.required, true)
        if type(first) == "table" and type(first.itemID) == "number" and basic and (tonumber(slot.quantityRequired) or 0) > 0 then
            out[#out + 1] = { id = first.itemID, need = slot.quantityRequired }
        end
    end
    return out
end
function ns:ShowCraftQueue()
    local queue = Queue()
    local lines = {}
    for i, q in ipairs(queue) do
        lines[#lines + 1] = { left = format("%d x %s", q.times, tostring(q.name)), right = "|cff9aa4b4" .. ns:Tr("click: make  right-click: remove") .. "|r",
            click = function(button)
                if button == "RightButton" then table.remove(queue, i); ns:ShowCraftQueue(); return end
                local T = C_TradeSkillUI
                if not (T and T.CraftRecipe) then return end
                local ok = pcall(T.CraftRecipe, q.id, q.times)
                if ok then table.remove(queue, i); ns:ShowCraftQueue()
                else ns:Print("Open the profession window for this recipe first.") end
            end }
    end
    if #queue == 0 then
        lines[1] = { left = ns:Tr("Empty. Select a recipe in your profession window, then /fgui queue (or /fgui queue 5).") }
    else
        lines[#lines + 1] = { left = " " }
        lines[#lines + 1] = { left = ns:AccentHex() .. ns:Tr("Shopping list for the whole queue") .. "|r", click = function() ns:ShowQueueShopping() end }
    end
    return ns:ShowList("CraftQueue", "Crafting queue", lines, "Kept for this character.", 460, 300)
end
function ns:ShowQueueShopping()
    local need = ns.QueueNeeds(Queue(), ReagentsOf)
    local lines = {}
    for id, n in pairs(need) do
        local have = Count(id, true)
        local short = math.max(0, n - have)
        lines[#lines + 1] = { left = format("%d x %s  |cff9aa4b4(%d)|r", n, ItemName(id), have),
            right = short == 0 and ("|cff33ff66" .. ns:Tr("enough") .. "|r") or ("|cffff5555" .. format(ns:Tr("%d short"), short) .. "|r"), sort = ItemName(id) }
    end
    table.sort(lines, function(a, b) return a.sort < b.sort end)
    if #lines == 0 then lines[1] = { left = ns:Tr("Open the profession window once so the recipes can be read.") } end
    return ns:ShowList("Shopping", "Shopping list for the whole queue", lines, "Needed, with how many you have in brackets (bags and bank).", 460, 300)
end
function ns:QueueCommand(text)
    text = ns.Trim(text)
    local low = text:lower()
    if low == "list" or low == "" and not (ns.SelectedRecipe and ns:SelectedRecipe()) then return ns:ShowCraftQueue() end
    if low == "clear" then wipe(Queue()); ns:Print("The crafting queue is empty."); return end
    local name, _, recipeID = ns:SelectedRecipe()
    if not recipeID then ns:Print("Open a profession and select a recipe first, then type /fgui queue (or /fgui queue 5 to make five)."); return end
    local q = ns.QueueAdd(Queue(), recipeID, name, tonumber(text) or 1)
    ns:Print("Queued: %s (%d).", tostring(q.name), q.times)
    return q
end

------------------------------------------------------------------------------------------
-- Goals panel: reputations and items you are working towards, with a bar each.
--   /fgui goal rep <faction name>    /fgui goal [item] 20    /fgui goal remove 2    /fgui goal clear
------------------------------------------------------------------------------------------
local function Goals()
    if type(ns.db.goals) ~= "table" then ns.db.goals = {} end
    return ns.db.goals
end
local function Faction(id)
    local R = C_Reputation
    if R and R.GetFactionDataByID then
        local ok, d = pcall(R.GetFactionDataByID, id)
        if ok and type(d) == "table" then return d end
    end
end
local function FindFaction(name)
    local R = C_Reputation
    if not (R and R.GetNumFactions and R.GetFactionDataByIndex) then return nil end
    local want = name:lower()
    local okN, n = pcall(R.GetNumFactions)
    for i = 1, (okN and tonumber(n)) or 0 do
        local ok, d = pcall(R.GetFactionDataByIndex, i)
        if ok and type(d) == "table" and type(d.name) == "string" and d.name:lower():find(want, 1, true) and d.factionID then return d.factionID, d.name end
    end
end
-- How far along a goal is: done (0..1), the text on its bar.
function ns.GoalProgress(goal, read)
    if goal.kind == "item" then
        local have = read.count(goal.id)
        local need = math.max(1, tonumber(goal.need) or 1)
        return math.min(1, have / need), format("%d / %d", math.min(have, need), need)
    elseif goal.kind == "rep" then
        local d = read.faction(goal.id)
        if type(d) ~= "table" then return 0, "?" end
        local lo, hi, now = tonumber(d.currentReactionThreshold) or 0, tonumber(d.nextReactionThreshold) or 1, tonumber(d.currentStanding) or 0
        local span = math.max(1, hi - lo)
        local standing = _G["FACTION_STANDING_LABEL" .. tostring(d.reaction)]
        return math.max(0, math.min(1, (now - lo) / span)), format("%d / %d%s", now - lo, span, standing and ("  " .. standing) or "")
    elseif goal.kind == "own" then
        local need = math.max(1, tonumber(goal.need) or 1)
        local have = math.max(0, math.min(need, tonumber(goal.have) or 0))
        return have / need, format("%d / %d", have, need)
    elseif goal.kind == "ach" then
        local done, total, finished = (read.ach or ns.AchievementProgress)(goal.id)
        if finished then return 1, ns:Tr("done") end
        if not total or total <= 0 then return 0, "?" end
        return math.min(1, done / total), format("%d / %d", done, total)
    end
    return 0, ""
end
-- An achievement's progress: criteria done, criteria in all, whether it is finished. (nil where the
-- game has no achievements.)
function ns.AchievementProgress(id)
    if type(GetAchievementInfo) ~= "function" then return nil end
    local ok, _, _, _, completed = pcall(GetAchievementInfo, id)
    if not ok then return nil end
    if completed then return 1, 1, true end
    local okN, n = pcall(GetAchievementNumCriteria, id)
    n = okN and tonumber(n) or 0
    if n == 0 then return 0, 1, false end
    if n == 1 then                                          -- one criterion: its own count (kill 50, gather 200)
        local okC, _, _, done, quantity, reqQuantity = pcall(GetAchievementCriteriaInfo, id, 1)
        if okC and type(reqQuantity) == "number" and reqQuantity > 1 then return tonumber(quantity) or 0, reqQuantity, done and true or false end
        return (okC and done) and 1 or 0, 1, false
    end
    local got = 0
    for i = 1, n do
        local okC, _, _, done = pcall(GetAchievementCriteriaInfo, id, i)
        if okC and done then got = got + 1 end
    end
    return got, n, false
end
-- An achievement by number, or by (part of) its name.
local function FindAchievement(text)
    if type(GetAchievementInfo) ~= "function" then return nil end
    local id = tonumber(text)
    if id then local ok, _, name = pcall(GetAchievementInfo, id); if ok and type(name) == "string" then return id, name end; return nil end
    if type(GetCategoryList) ~= "function" or type(GetCategoryNumAchievements) ~= "function" then return nil end
    local want = text:lower()
    local okL, cats = pcall(GetCategoryList)
    for _, cat in ipairs(okL and cats or {}) do
        local okN, n = pcall(GetCategoryNumAchievements, cat, true)
        for i = 1, (okN and tonumber(n)) or 0 do
            local ok, aid, name = pcall(GetAchievementInfo, cat, i)
            if ok and type(name) == "string" and name:lower():find(want, 1, true) then return aid, name end
        end
    end
    return nil
end
function ns:GoalCommand(text)
    text = ns.Trim(text)
    local goals = Goals()
    local first, rest = text:match("^(%S+)%s*(.*)$")
    first = first and first:lower()
    if first == "rep" and rest ~= "" then
        local id, name = FindFaction(rest)
        if not id then ns:Print("No reputation called \"%s\" (open the reputation window once, then try again).", rest); return end
        goals[#goals + 1] = { kind = "rep", id = id, name = name }
        ns:Print("Goal added: %s.", name)
    elseif first == "add" and rest ~= "" then
        -- a goal of your own: /fgui goal add 50 Kill raptors   (click it on the panel to count)
        local need, what = rest:match("^(%d+)%s+(.+)$")
        if not need then need, what = 1, rest end
        goals[#goals + 1] = { kind = "own", name = what:sub(1, 40), need = math.max(1, math.min(100000, tonumber(need))), have = 0 }
        ns:Print("Goal added: %s. Click it on the panel to count it up (right-click: down).", goals[#goals].name)
    elseif (first == "ach" or first == "achievement") and rest ~= "" then
        local id, name = FindAchievement(rest)
        if not id then
            ns:Print(type(GetAchievementInfo) == "function" and "No achievement called \"%s\"." or "This game client has no achievements.", rest)
            return
        end
        goals[#goals + 1] = { kind = "ach", id = id, name = name }
        ns:Print("Goal added: %s.", name)
    elseif first == "+" or first == "-" or first == "set" then
        local i, n = rest:match("^(%d+)%s*(%d*)$")
        local g = goals[tonumber(i or 0)]
        if g and g.kind == "own" then
            local by = tonumber(n) or 1
            if first == "set" then g.have = by elseif first == "+" then g.have = (g.have or 0) + by else g.have = (g.have or 0) - by end
            g.have = math.max(0, math.min(g.need or 1, g.have))
        end
    elseif first == "remove" then
        local i = tonumber(rest)
        if i and goals[i] then table.remove(goals, i); ns:Print("Goal removed.") end
    elseif first == "clear" then
        wipe(goals); ns:Print("Goals cleared.")
    elseif text:find("|Hitem:", 1, true) then
        local id = tonumber(text:match("|Hitem:(%d+)"))
        local need = tonumber(text:match("|h|r%s*(%d+)%s*$")) or 1
        if id then goals[#goals + 1] = { kind = "item", id = id, need = need, name = ItemName(id) }; ns:Print("Goal added: %s x %d.", ItemName(id), need) end
    else
        if #goals == 0 then ns:Print("No goals yet: /fgui goal rep <faction name>, /fgui goal add 50 <your own goal>, /fgui goal ach <achievement>, or /fgui goal followed by a shift-clicked item and a number.") end
        for i, g in ipairs(goals) do ns:PrintRaw("  " .. i .. ". " .. tostring(g.name)) end
    end
    if ns.goalsTest then ns.goalsTest.Update() end
end
ns:NewModule("goalsPanel", function()
    local W, ROWH = 220, 30
    local f = CreateFrame("Frame", "FantasyGlassUIGoals", UIParent, ns.template)
    f:SetSize(W, 40)
    f:SetPoint("RIGHT", UIParent, "RIGHT", -240, 120)
    if f.SetBackdrop then f:SetBackdrop(ns.BACKDROP); ns:Paint(f, "SetBackdropColor", "bg", 0.8); ns:Paint(f, "SetBackdropBorderColor", "@border", 1) end
    f.title = ns:NewText(f, 12, "LEFT")
    f.title:SetPoint("TOPLEFT", 8, -6)
    ns:Paint(f.title, "SetTextColor", "@accent")
    f.title:SetText(ns:Tr("Goals"))
    local rows = {}
    local read = { count = function(id) return Count(id, true) end, faction = Faction }
    local function Row(i)
        local r = CreateFrame("Frame", nil, f)
        r:SetSize(W - 16, ROWH - 4)
        r.name = ns:NewText(r, 11, "LEFT")
        r.name:SetPoint("TOPLEFT", 0, 0)
        r.name:SetPoint("TOPRIGHT", 0, 0)
        if r.name.SetWordWrap then r.name:SetWordWrap(false) end
        r.bar = ns:NewStatusBar(r, true)
        r.bar:SetPoint("BOTTOMLEFT", 0, 0)
        r.bar:SetPoint("BOTTOMRIGHT", 0, 0)
        r.bar:SetHeight(10)
        r.bar:SetMinMaxValues(0, 1)
        r.value = ns:NewText(r.bar, 9, "CENTER")
        r.value:SetPoint("CENTER")
        r:EnableMouse(true)
        r:SetScript("OnMouseUp", function(self, button)        -- your own goals: count up (or down) with a click
            local g = Goals()[self.index or 0]
            if not (g and g.kind == "own") then return end
            g.have = math.max(0, math.min(g.need or 1, (g.have or 0) + (button == "RightButton" and -1 or 1)))
            if ns.goalsTest then ns.goalsTest.Update() end
        end)
        rows[i] = r
        return r
    end
    local function Update()
        local goals = Goals()
        local n = 0
        for i, g in ipairs(goals) do
            n = i
            local r = rows[i] or Row(i)
            r.index = i
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -22 - (i - 1) * ROWH)
            local done, label = ns.GoalProgress(g, read)
            r.name:SetText(tostring(g.name))
            r.bar:SetValue(done)
            if done >= 1 then r.bar:SetStatusBarColor(0.3, 0.85, 0.4) else r.bar:SetStatusBarColor(ns:Role("@accent")) end
            r.value:SetText(label)
            r:Show()
        end
        for i = n + 1, #rows do rows[i]:Hide() end
        f:SetHeight(26 + n * ROWH)
        if n > 0 or ns.moving then f:Show() else f:Hide() end
        return n
    end
    ns.goalsTest = { Update = Update, frame = f }
    ns:Every(2, "Goals", Update)
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "BAG_UPDATE_DELAYED", "UPDATE_FACTION", "PLAYER_ENTERING_WORLD" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Goals", function() Update() end))
    local entry = ns:RegisterMovable(f, "goals", "Goals")
    if type(entry) == "table" then entry.offPage = true end
end)

------------------------------------------------------------------------------------------
-- Login splash: as you come into the world, the add-on's emblem, your character and where you are, for
-- a moment. (The loading screen itself belongs to the game: add-ons cannot draw over it.)
------------------------------------------------------------------------------------------
ns:NewModule("loginSplash", function()
    local f = CreateFrame("Frame", "FantasyGlassUISplash", UIParent)
    f:SetAllPoints(UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(true)
    f:Hide()
    f.shade = f:CreateTexture(nil, "BACKGROUND")
    f.shade:SetAllPoints()
    f.shade:SetTexture(ns.FLAT)
    ns:Paint(f.shade, "SetVertexColor", "bg", 0.82)
    f.logo = f:CreateTexture(nil, "ARTWORK")
    f.logo:SetSize(112, 112)
    f.logo:SetPoint("CENTER", 0, 70)
    f.logo:SetTexture(ns.MEDIA .. "icon.tga")
    f.title = f:CreateFontString(nil, "OVERLAY")
    ns:Font(f.title, 26, true)
    f.title:SetPoint("TOP", f.logo, "BOTTOM", 0, -14)
    f.name = f:CreateFontString(nil, "OVERLAY")
    ns:Font(f.name, 18, true)
    f.name:SetPoint("TOP", f.title, "BOTTOM", 0, -10)
    f.place = f:CreateFontString(nil, "OVERLAY")
    ns:Font(f.place, 13)
    f.place:SetPoint("TOP", f.name, "BOTTOM", 0, -6)
    ns:Paint(f.place, "SetTextColor", "dim")
    local left = 0
    f:SetScript("OnMouseDown", function(self) left = math.min(left, 0.4) end)
    f:SetScript("OnUpdate", function(self, e)
        left = left - (e or 0)
        if left <= 0 then self:Hide(); return end
        self:SetAlpha(math.min(1, left / 0.6))
    end)
    local function Show()
        f.title:SetText(ns:AccentHex() .. "Fantasy Glass|r UI")
        local name, level = UnitName("player"), UnitLevel("player")
        local _, class = UnitClass("player")
        local r, g, b = ns:ClassRGB(class)
        f.name:SetText(tostring(name))
        f.name:SetTextColor(r or 1, g or 1, b or 1)
        local zone = GetZoneText and GetZoneText() or ""
        f.place:SetText(format("%s %s  -  %s", ns:Tr("Level"), tostring(level or ""), tostring(zone)))
        left = 2.6
        f:SetAlpha(1)
        f:Show()
        return true
    end
    ns.splashTest = { Show = Show, frame = f }
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", ns:Guard("Login splash", function(_, _, isLogin)
        if isLogin and not ns.Yes(InCombatLockdown()) then Show() end
    end))
end)
