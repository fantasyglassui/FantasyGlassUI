local ADDON, ns = ...
local Secret = function(v) return ns:IsSecret(v) end
local PREFIX = "FGUI"

------------------------------------------------------------------------------------------
-- 11.3: a group cooldown tracker, sending a profile or layout to another player, and a totem bar
-- for Shamans.
------------------------------------------------------------------------------------------

-- The channel that reaches your whole group (or nil when alone).
function ns.GroupChannel()
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
    return nil
end
local function Send(msg, channel, target)
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false end
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, channel, target)
    return ok and result ~= false
end
ns.GroupSend = function(msg, channel, target) return Send(msg, channel, target) end
local function ShortName(name)
    if type(name) ~= "string" or Secret(name) then return nil end
    if Ambiguate then local ok, s = pcall(Ambiguate, name, "none"); if ok and type(s) == "string" then return s end end
    return (name:gsub("%-.*$", ""))
end
ns.GroupShortName = ShortName

------------------------------------------------------------------------------------------
-- Group cooldowns: who in your group has a battle resurrection, an interrupt or a big defensive or
-- raid cooldown ready. Group members with the add-on tell each other what they have and when they
-- use it, so nothing the game hides in a fight is needed. A panel lists it (switch on the Features
-- tab); telling the others goes on whether or not your own panel is shown.
------------------------------------------------------------------------------------------
-- { spell, kind, seconds }: the first rank's spell (any rank counts), what kind, the usual cooldown
ns.GROUP_CDS = {
    { 20484, "res", 1800 },  -- Rebirth
    { 20707, "res", 1800 },  -- Soulstone Resurrection
    { 19752, "res", 3600 },  -- Divine Intervention
    { 1766,  "kick", 10 },   -- Kick
    { 6552,  "kick", 10 },   -- Pummel
    { 72,    "kick", 12 },   -- Shield Bash
    { 2139,  "kick", 24 },   -- Counterspell
    { 15487, "kick", 45 },   -- Silence
    { 8042,  "kick", 6 },    -- Earth Shock
    { 871,   "def", 1800 },  -- Shield Wall
    { 12975, "def", 600 },   -- Last Stand
    { 642,   "def", 300 },   -- Divine Shield
    { 633,   "def", 3600 },  -- Lay on Hands
    { 1022,  "def", 300 },   -- Blessing of Protection
    { 11958, "def", 300 },   -- Ice Block
    { 45438, "def", 300 },   -- Ice Block
    { 6346,  "def", 30 },    -- Fear Ward
    { 1161,  "def", 600 },   -- Challenging Shout
    { 5209,  "def", 600 },   -- Challenging Roar
    { 29166, "raid", 360 },  -- Innervate
    { 740,   "raid", 300 },  -- Tranquility
    { 16190, "raid", 300 },  -- Mana Tide Totem
    { 10060, "raid", 180 },  -- Power Infusion
    { 2825,  "raid", 600 },  -- Bloodlust
    { 32182, "raid", 600 },  -- Heroism
}
ns.GROUP_CD_KINDS = { res = "Battle resurrection", kick = "Interrupts", def = "Defensives", raid = "Raid cooldowns" }
local KIND_ORDER = { res = 1, kick = 2, def = 3, raid = 4 }
local byName, byID = {}, {}
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then local ok, n = pcall(C_Spell.GetSpellName, id); if ok and type(n) == "string" then return n end end
    if GetSpellInfo then local ok, n = pcall(GetSpellInfo, id); if ok and type(n) == "string" then return n end end
    return nil
end
local function SpellIcon(id)
    if C_Spell and C_Spell.GetSpellTexture then local ok, t = pcall(C_Spell.GetSpellTexture, id); if ok and t then return t end end
    if GetSpellTexture then local ok, t = pcall(GetSpellTexture, id); if ok and t then return t end end
    return 134400
end
local function Index()
    if next(byID) then return end
    for _, def in ipairs(ns.GROUP_CDS) do
        byID[def[1]] = def
        local n = SpellName(def[1])
        if n then byName[n] = def end
    end
end
-- The tracked spell a cast is (by its id, or by name: any rank counts), or nil.
function ns.GroupCDFor(spellID)
    Index()
    if type(spellID) ~= "number" or Secret(spellID) then return nil end
    if byID[spellID] then return byID[spellID] end
    local n = SpellName(spellID)
    return n and byName[n] or nil
end
local function Known(id)
    for _, fn in ipairs({ IsPlayerSpell, IsSpellKnown }) do
        if type(fn) == "function" then local ok, v = pcall(fn, id); if ok and v == true then return true end end
    end
    if C_SpellBook and C_SpellBook.IsSpellKnown then local ok, v = pcall(C_SpellBook.IsSpellKnown, id); if ok and v == true then return true end end
    return false
end
-- The tracked spells you have.
function ns.MyGroupCDs()
    local out = {}
    for _, def in ipairs(ns.GROUP_CDS) do if Known(def[1]) then out[#out + 1] = def[1] end end
    return out
end

-- who has what: roster[name] = { class, spells = { [id] = endsAt (0 when ready) } }
local roster = {}
ns.groupCDRoster = roster
function ns.GroupCDHave(name, class, ids, now)
    if type(name) ~= "string" then return end
    local r = roster[name] or { spells = {} }
    r.class = class or r.class
    r.seen = now
    local keep = {}
    for _, id in ipairs(ids) do keep[id] = true; if r.spells[id] == nil then r.spells[id] = 0 end end
    for id in pairs(r.spells) do if not keep[id] then r.spells[id] = nil end end
    roster[name] = r
end
function ns.GroupCDUsed(name, class, id, seconds, now)
    if type(name) ~= "string" or type(id) ~= "number" then return end
    local r = roster[name] or { spells = {} }
    r.class = class or r.class
    r.spells[id] = now + math.max(0, tonumber(seconds) or 0)
    roster[name] = r
    if ns.KickRotationUsed then pcall(ns.KickRotationUsed, ns, name, id) end
end
-- "GCH:20484,1766" (what someone has) / "GCD:1766:10" (used, seconds) -> kind, data
function ns.ParseGroupCD(text)
    if type(text) ~= "string" then return nil end
    local list = text:match("^GCH:([%d,]*)$")
    if list then
        local ids = {}
        for id in list:gmatch("%d+") do ids[#ids + 1] = tonumber(id) end
        return "have", ids
    end
    local id, s = text:match("^GCD:(%d+):(%d+)$")
    if id then return "used", tonumber(id), tonumber(s) end
    if text == "GCQ" then return "ask" end
    return nil
end
-- The lines the panel shows: { kind, id, name, class, left } sorted by kind, then ready first.
function ns.GroupCDLines(now, inGroup)
    local lines = {}
    for name, r in pairs(roster) do
        if not inGroup or inGroup[name] then
            for id, ends in pairs(r.spells) do
                local def = byID[id] or ns.GroupCDFor(id)
                if def then lines[#lines + 1] = { kind = def[2], id = id, name = name, class = r.class, left = math.max(0, ends - now) } end
            end
        end
    end
    table.sort(lines, function(a, b)
        if a.kind ~= b.kind then return (KIND_ORDER[a.kind] or 9) < (KIND_ORDER[b.kind] or 9) end
        if (a.left > 0) ~= (b.left > 0) then return a.left == 0 end
        if a.left ~= b.left then return a.left < b.left end
        return a.name < b.name
    end)
    return lines
end

local lastHave = 0
local function TellHave(force)
    local ch = ns.GroupChannel()
    if not ch or InCombatLockdown() then return false end
    if not force and GetTime() - lastHave < 5 then return false end
    lastHave = GetTime()
    local ids = ns.MyGroupCDs()
    local parts = {}
    for _, id in ipairs(ids) do parts[#parts + 1] = tostring(id) end
    Send("GCH:" .. table.concat(parts, ","), ch)
    local me, _ = UnitName("player")
    local _, class = UnitClass("player")
    ns.GroupCDHave(me, class, ids, GetTime())
    return true
end
ns.GroupCDTell = TellHave

-- after one of your tracked spells: its real cooldown when the game says, else the usual one
local function Used(spellID)
    local def = ns.GroupCDFor(spellID)
    if not def then return end
    local seconds = def[3]
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
        if ok and type(info) == "table" and type(info.duration) == "number" and not Secret(info.duration) and info.duration > 1.5 then seconds = info.duration end
    end
    seconds = math.floor(seconds + 0.5)
    local me = UnitName("player")
    local _, class = UnitClass("player")
    ns.GroupCDUsed(me, class, def[1], seconds, GetTime())
    local ch = ns.GroupChannel()
    if ch then Send("GCD:" .. def[1] .. ":" .. seconds, ch) end
end

do
    local ev = CreateFrame("Frame")
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
    for _, e in ipairs({ "CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED" }) do pcall(ev.RegisterEvent, ev, e) end
    pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_SUCCEEDED", "player")
    ev:SetScript("OnEvent", ns:Guard("Group cooldowns", function(_, event, a, b, c, d)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            local spellID = d or c
            if type(spellID) == "number" and not Secret(spellID) then ns:After(0.2, function() pcall(Used, spellID) end) end
        elseif event == "CHAT_MSG_ADDON" then
            if Secret(a) or Secret(b) or a ~= PREFIX or type(b) ~= "string" then return end
            local from = ShortName(d)
            if not from or from == UnitName("player") then return end
            local kind, x, y = ns.ParseGroupCD(b)
            if not kind then return end
            local class
            for _, m in ipairs(ns:GroupMembers()) do if ShortName(m.name) == from then class = m.class end end
            if kind == "have" then ns.GroupCDHave(from, class, x, GetTime())
            elseif kind == "used" then ns.GroupCDUsed(from, class, x, y, GetTime())
            elseif kind == "ask" then TellHave(true) end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if ns.groupCDPending then ns.groupCDPending = nil; TellHave(true) end
        else
            if InCombatLockdown() then ns.groupCDPending = true; return end
            ns:After(2, function()
                if TellHave(event ~= "GROUP_ROSTER_UPDATE") and event == "GROUP_ROSTER_UPDATE" then
                    local ch = ns.GroupChannel()
                    if ch and not ns.groupCDAsked then ns.groupCDAsked = true; Send("GCQ", ch) end
                end
                if not ns.GroupChannel() then ns.groupCDAsked = nil end
            end)
        end
    end))
end

ns:NewModule("groupCDs", function()
    local f = CreateFrame("Frame", "FantasyGlassUIGroupCooldowns", UIParent, ns.template)
    f:SetSize(220, 40)
    f:SetPoint("LEFT", UIParent, "LEFT", 30, 120)
    f:SetBackdrop(ns.BACKDROP)
    ns:Paint(f, "SetBackdropColor", "bg", 0.8)
    ns:Paint(f, "SetBackdropBorderColor", "@border", 1)
    ns:Dress(f, true)
    f.title = ns:NewText(f, 11, "LEFT", true)
    f.title:SetPoint("TOPLEFT", 8, -6)
    f.title:SetText(ns:Tr("Group cooldowns"))
    ns:Paint(f.title, "SetTextColor", "@accent")
    f.rows = {}
    local ROW, MAX = 18, 24
    local function Row(i)
        local r = f.rows[i]
        if r then return r end
        r = CreateFrame("Frame", nil, f)
        r:SetSize(204, ROW)
        r:SetPoint("TOPLEFT", 8, -22 - (i - 1) * ROW)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(ROW - 2, ROW - 2)
        r.icon:SetPoint("LEFT")
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = ns:NewText(r, 11, "LEFT")
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
        r.left = ns:NewText(r, 11, "RIGHT")
        r.left:SetPoint("RIGHT", -2, 0)
        f.rows[i] = r
        return r
    end
    local function Update()
        local ch = ns.GroupChannel()
        if not ch and not ns.moving and not ns.previewing and not ns.testGroup then f:Hide(); return 0 end
        local inGroup = {}
        inGroup[UnitName("player")] = true
        for _, m in ipairs(ns:GroupMembers()) do local s = ShortName(m.name); if s then inGroup[s] = true end end
        local lines = ns.GroupCDLines(GetTime(), ch and inGroup or nil)
        local n = math.min(#lines, MAX)
        for i = 1, n do
            local l = lines[i]
            local r = Row(i)
            r.icon:SetTexture(SpellIcon(l.id))
            local cr, cg, cb = ns:ClassRGB(l.class)
            r.name:SetText(l.name)
            r.name:SetTextColor(cr or 1, cg or 1, cb or 1)
            if l.left > 0 then
                r.left:SetText(ns.Clock and ns.Clock(l.left) or tostring(math.ceil(l.left)))
                r.left:SetTextColor(1, 0.45, 0.4)
                r.icon:SetDesaturated(true)
            else
                r.left:SetText(ns:Tr("ready"))
                r.left:SetTextColor(0.3, 1, 0.45)
                r.icon:SetDesaturated(false)
            end
            r:Show()
        end
        for i = n + 1, #f.rows do f.rows[i]:Hide() end
        if n == 0 then
            local r = Row(1)
            r.icon:SetTexture(nil)
            r.name:SetText(ns:Tr("Nobody with the add-on yet"))
            r.name:SetTextColor(0.6, 0.62, 0.68)
            r.left:SetText("")
            r:Show()
        end
        f:SetHeight(26 + math.max(1, n) * ROW)
        f:Show()
        return n
    end
    ns.groupCDTest = { Update = Update, frame = f }
    ns:Every(0.5, "Group cooldowns", Update)
    local entry = ns:RegisterMovable(f, "groupCDs", "Group cooldowns")
    if type(entry) == "table" then entry.offPage = true end
end)

------------------------------------------------------------------------------------------
-- Send a profile, layout or theme to another player: /fgui send <name> [layout|profile|theme], or
-- the Profiles tab. It goes in pieces as a whisper only add-ons see; the other player's add-on puts
-- it back together and opens the preview, where they choose whether to take it.
------------------------------------------------------------------------------------------
local CHUNK = 200
local outgoing, incoming = {}, {}
function ns.ShareChunks(text)
    local parts = {}
    for i = 1, #text, CHUNK do parts[#parts + 1] = text:sub(i, i + CHUNK - 1) end
    return parts
end
-- "SS:<id>:<i>:<n>:<kind>:<piece>" -> id, i, n, kind, piece
function ns.ParseSharePiece(msg)
    local id, i, n, kind, piece = tostring(msg or ""):match("^SS:(%w+):(%d+):(%d+):(%a+):(.*)$")
    if not id then return nil end
    return id, tonumber(i), tonumber(n), kind, piece
end
-- One piece in: returns the whole string once every piece is there.
function ns.ShareReceive(from, id, i, n, kind, piece, now)
    if n < 1 or n > 400 or i < 1 or i > n then return nil end
    local key = from .. ":" .. id
    local t = incoming[key]
    if not t or t.n ~= n then t = { n = n, got = 0, parts = {}, kind = kind }; incoming[key] = t end
    t.at = now
    if not t.parts[i] then t.parts[i] = piece; t.got = t.got + 1 end
    for k, other in pairs(incoming) do if now - (other.at or 0) > 120 then incoming[k] = nil end end
    if t.got < n then return nil end
    incoming[key] = nil
    return table.concat(t.parts), t.kind
end
function ns:SendSetup(target, kind, given)
    target = ns.Trim(target or "")
    kind = (kind == "profile" or kind == "theme" or kind == "pack" or (kind == "talents" and given)) and kind or "layout"
    if target == "" then ns:Print("Who to? /fgui send <name> [layout|profile|theme]"); return false end
    if target:lower() == tostring(UnitName("player")):lower() then ns:Print("That is you."); return false end
    local text = given or (kind == "profile" and ns:ExportProfile()) or (kind == "theme" and ns:ExportTheme()) or (kind == "pack" and ns:ExportPack()) or ns:ExportLayout()
    if type(text) ~= "string" or text == "" then return false end
    local parts = ns.ShareChunks(text)
    local id = format("%x", math.random(4096, 65535))
    outgoing[id] = { to = target, kind = kind, at = GetTime() }
    local i = 0
    local function Next()
        i = i + 1
        if i > #parts then
            ns:After(30, function()
                local o = outgoing[id]
                if o and not o.done then ns:Print("%s has not answered: they may be offline, or not have Fantasy Glass UI.", target) end
                outgoing[id] = nil
            end)
            return
        end
        if not Send(format("SS:%s:%d:%d:%s:%s", id, i, #parts, kind, parts[i]), "WHISPER", target) then
            ns:Print("The game would not send it to %s.", target); outgoing[id] = nil; return
        end
        ns:After(0.12, Next)
    end
    ns:Print("Sending your %s to %s (%d pieces)...", ns:Tr(kind), target, #parts)
    Next()
    return #parts
end
do
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "CHAT_MSG_ADDON")
    ev:SetScript("OnEvent", ns:Guard("Shared setups", function(_, _, prefix, msg, channel, sender)
        if Secret(prefix) or Secret(channel) or Secret(msg) or prefix ~= PREFIX or channel ~= "WHISPER" or type(msg) ~= "string" then return end
        local from = ShortName(sender)
        if not from then return end
        local ack = msg:match("^SSA:(%w+)$")
        if ack then
            local o = outgoing[ack]
            if o then o.done = true; ns:Print("%s has your %s.", from, ns:Tr(o.kind)) end
            return
        end
        local id, i, n, kind, piece = ns.ParseSharePiece(msg)
        if not id then return end
        if ns.db.acceptShared == false then return end
        local text = ns.ShareReceive(from, id, i, n, kind, piece, GetTime())
        if not text then return end
        Send("SSA:" .. id, "WHISPER", sender)
        if kind == "talents" then                         -- a talent build: kept with yours, never learned by itself
            if ns.ReceiveTalentBuild then ns:ReceiveTalentBuild(from, text) end
            return
        end
        ns:Print("%s sent you a %s. Look it over in the preview, then choose Use it or close it.", from, ns:Tr(kind))
        if ns.PreviewShared and not InCombatLockdown() then
            ns:PreviewShared(text)
        else
            ns.sharedWaiting = text
        end
    end))
    local later = CreateFrame("Frame")
    later:RegisterEvent("PLAYER_REGEN_ENABLED")
    later:SetScript("OnEvent", function()
        if ns.sharedWaiting and ns.PreviewShared then local t = ns.sharedWaiting; ns.sharedWaiting = nil; pcall(ns.PreviewShared, ns, t) end
    end)
end
function ns:SendCommand(text)
    local name, kind = ns.Trim(text):match("^(%S+)%s*(%a*)$")
    return ns:SendSetup(name or "", (kind or ""):lower())
end

------------------------------------------------------------------------------------------
-- Totem bar (Shamans): a button for each element. Left-click drops the totem chosen for it,
-- right-click takes the one that is down away, and the mouse wheel (out of a fight) chooses which
-- totem the button drops. The totem that is down shows with its time left.
------------------------------------------------------------------------------------------
-- slots as the game numbers them: 1 fire, 2 earth, 3 water, 4 air
ns.TOTEMS = {
    { slot = 2, key = "earth", label = "Earth", ids = { 8071, 2484, 5730, 8075, 8143 } },
    { slot = 1, key = "fire",  label = "Fire",  ids = { 3599, 1535, 8190, 8181, 8227 } },
    { slot = 3, key = "water", label = "Water", ids = { 5394, 5675, 8166, 8170, 8184, 16190 } },
    { slot = 4, key = "air",   label = "Air",   ids = { 8177, 10595, 8512, 8835, 15107, 25908, 6495, 3738 } },
}
-- The totems of an element you know: { { id, name } }.
function ns.KnownTotems(element, known)
    local out = {}
    for _, id in ipairs(element.ids) do
        if (known or Known)(id) then
            local n = SpellName(id)
            if n then out[#out + 1] = { id = id, name = n } end
        end
    end
    return out
end
-- The next choice after `now` (by name) in a list, round and round.
function ns.NextTotem(list, now, back)
    if #list == 0 then return nil end
    local at = 0
    for i, t in ipairs(list) do if t.name == now then at = i end end
    if at == 0 then return list[1] end
    return list[((at - 1) + (back and -1 or 1)) % #list + 1]
end
local function Choices()
    if type(ns.root) ~= "table" then return {} end
    ns.root.totemChoice = type(ns.root.totemChoice) == "table" and ns.root.totemChoice or {}
    local key = ns:CharKey()
    ns.root.totemChoice[key] = type(ns.root.totemChoice[key]) == "table" and ns.root.totemChoice[key] or {}
    return ns.root.totemChoice[key]
end
ns:NewModule("totemBar", function()
    local _, class = UnitClass("player")
    if class ~= "SHAMAN" then ns.totemBarState = "not a Shaman"; return end
    local SIZE, GAP = 34, 4
    local bar = CreateFrame("Frame", "FantasyGlassUITotemBar", UIParent)
    bar:SetSize(4 * SIZE + 3 * GAP, SIZE)
    bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 190)
    bar.buttons = {}
    local function Choose(b, back)
        if InCombatLockdown() then return false end
        local list = ns.KnownTotems(b.element)
        local now = Choices()[b.element.key]
        local pick = ns.NextTotem(list, now, back)
        if not pick then return false end
        Choices()[b.element.key] = pick.name
        b:SetAttribute("spell1", pick.name)
        b.chosenID = pick.id
        return pick.name
    end
    local function Draw(b)
        local id = b.chosenID
        local ok, have, name, start, duration, icon = pcall(GetTotemInfo, b.element.slot)
        local up = ok and not Secret(have) and have and type(name) == "string" and not Secret(name) and name ~= ""
        if up then
            pcall(b.icon.SetTexture, b.icon, icon)
            b.icon:SetDesaturated(false)
            local left = (not Secret(start) and not Secret(duration) and type(start) == "number" and type(duration) == "number") and (start + duration - GetTime()) or nil
            b.time:SetText(left and left > 0 and ns.Clock(left) or "")
            pcall(b.cd.SetCooldown, b.cd, start, duration)
            b.cd:Show()
        else
            b.icon:SetTexture(id and SpellIcon(id) or 136232)
            b.icon:SetDesaturated(true)
            b.time:SetText("")
            b.cd:Hide()
        end
        b.icon:SetAlpha(id and 1 or 0.35)
    end
    for i, element in ipairs(ns.TOTEMS) do
        local b = CreateFrame("Button", "FantasyGlassUITotem" .. i, bar, "SecureActionButtonTemplate")
        b:SetSize(SIZE, SIZE)
        b:SetPoint("LEFT", (i - 1) * (SIZE + GAP), 0)
        b:RegisterForClicks("AnyUp", "AnyDown")
        b.element = element
        b:SetAttribute("type1", "spell")
        b:SetAttribute("type2", "destroytotem")
        b:SetAttribute("totem-slot", element.slot)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local okC, cd = pcall(CreateFrame, "Cooldown", nil, b, "CooldownFrameTemplate")
        b.cd = okC and cd or { SetCooldown = function() end, Show = function() end, Hide = function() end }
        if okC and cd.SetReverse then cd:SetReverse(true); cd:SetAllPoints() end
        if okC and cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
        b.time = ns:NewText(b, 11, "CENTER", true)
        b.time:SetPoint("BOTTOM", 0, 2)
        ns:AddBorder(b, 0, 0, 0, 1)
        b:EnableMouseWheel(true)
        b:SetScript("OnMouseWheel", function(self, delta)
            if Choose(self, delta < 0) then Draw(self) end
            if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(ns:Tr(element.label) .. ": " .. tostring(Choices()[element.key] or ns:Tr("none known")))
            GameTooltip:AddLine(ns:Tr("Left-click: drop it. Right-click: take the one that is down away. Mouse wheel: choose another (not in a fight)."), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        bar.buttons[i] = b
        -- the chosen totem (or the first known)
        local list = ns.KnownTotems(element)
        local want = Choices()[element.key]
        local pick
        for _, t in ipairs(list) do if t.name == want then pick = t end end
        pick = pick or list[1]
        if pick then
            Choices()[element.key] = pick.name
            b:SetAttribute("spell1", pick.name)
            b.chosenID = pick.id
        end
        Draw(b)
    end
    local function DrawAll() for _, b in ipairs(bar.buttons) do pcall(Draw, b) end end
    ns.totemBarTest = { bar = bar, Choose = Choose, DrawAll = DrawAll }
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_TOTEM_UPDATE", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Totem bar", function(_, event)
        if event == "SPELLS_CHANGED" and not InCombatLockdown() then
            for _, b in ipairs(bar.buttons) do
                if not b.chosenID then local list = ns.KnownTotems(b.element); if list[1] then Choices()[b.element.key] = list[1].name; b:SetAttribute("spell1", list[1].name); b.chosenID = list[1].id end end
            end
        end
        DrawAll()
    end))
    ns:Every(1, "Totem bar", DrawAll)
    ns:RegisterMovable(bar, "totemBar", "Totem bar")
    ns.totemBarState = "on"
end)
