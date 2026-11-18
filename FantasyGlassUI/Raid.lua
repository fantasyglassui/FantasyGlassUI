local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- 11.7: am I ready for the raid, boss notes, and a death recap.
------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------
-- Am I ready? (/fgui ready me): one panel with what you would want before a raid. Food, a flask or
-- elixir, something on your weapon, your gear's repair, your class's reagents, bag space, and
-- which talent set and gear set you are in. Out of fights only: the game hides buffs in them.
------------------------------------------------------------------------------------------
ns.CLASS_REAGENTS = {
    PRIEST = { 17028, 17029 },          -- Holy Candle, Sacred Candle
    MAGE = { 17020, 17031, 17032 },     -- Arcane Powder, Rune of Teleportation, Rune of Portals
    DRUID = { 17026, 17034, 17035, 17036, 17037, 17038 },   -- Wild Thornroot, seeds for Rebirth
    PALADIN = { 21177, 17033 },         -- Symbol of Kings, Symbol of Divinity
    SHAMAN = { 17030 },                 -- Ankh
    WARLOCK = { 6265 },                 -- Soul Shard
    ROGUE = { 5140, 5530 },             -- Flash Powder, Blinding Powder
}
local DIM = "|cff9aa4b4"    -- (good and bad use ns:SignalHex, so the color-blind setting counts)
local function ItemName(id)
    local n = ns.GetItemInfo and ns:GetItemInfo(id)
    return (type(n) == "string" and not Secret(n)) and n or (ns:Tr("Item") .. " " .. id)
end
local function Count(id)
    local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
    if type(fn) ~= "function" then return nil end
    local ok, n = pcall(fn, id)
    return (ok and type(n) == "number" and not Secret(n)) and n or nil
end
local function FreeSlots()
    local C = C_Container
    if not (C and C.GetContainerNumFreeSlots) then return nil end
    local free = 0
    for bag = 0, 4 do local ok, f = pcall(C.GetContainerNumFreeSlots, bag); if ok and type(f) == "number" and not Secret(f) then free = free + f end end
    return free
end
local function MyBuffNames()
    local names = {}
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil end
    for i = 1, 40 do
        local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok or type(a) ~= "table" then break end
        if Secret(a.name) then return nil end
        if type(a.name) == "string" then names[#names + 1] = a.name end
    end
    return names
end
local function HasWord(names, words)
    for _, n in ipairs(names) do
        local low = n:lower()
        for _, w in ipairs(words) do if low:find(w:lower(), 1, true) then return true end end
    end
    return false
end
-- The checks, from what is known: facts = { buffs, weapon, durability, reagents = { {id, n} }, free,
-- talentSet, talentName, gearSet }. Returns { { label, ok, text } }.
function ns.ReadyMeLines(f)
    local out = {}
    local function add(label, ok, text) out[#out + 1] = { label = label, ok = ok, text = text } end
    if f.buffs then
        add("Food", HasWord(f.buffs, ns.READY_WORDS.food), nil)
        add("Flask or elixir", HasWord(f.buffs, ns.READY_WORDS.flask), nil)
    else
        add("Food", nil, "could not be read"); add("Flask or elixir", nil, "could not be read")
    end
    if f.weapon ~= nil then add("Weapon oil, stone or imbue", f.weapon and true or false, nil) end
    if type(f.durability) == "number" then add("Repair", f.durability >= 50, format("%d%%", math.floor(f.durability + 0.5))) end
    for _, r in ipairs(f.reagents or {}) do add(r.name, (r.n or 0) > 0, tostring(r.n or 0)) end
    if type(f.free) == "number" then add("Bag space", f.free >= 5, format(ns:Tr("%d free"), f.free)) end
    if f.talentSet then add("Talent set", true, tostring(f.talentSet) .. (f.talentName and ("  " .. f.talentName) or "")) end
    if f.gearSet ~= nil then add("Gear set", f.gearSet and true or nil, f.gearSet or ns:Tr("none fully on")) end
    return out
end
function ns:ReadyMeFacts()
    local _, class = UnitClass("player")
    local f = { buffs = MyBuffNames(), reagents = {} }
    if GetWeaponEnchantInfo then
        local ok, mh = pcall(GetWeaponEnchantInfo)
        if ok and not Secret(mh) then f.weapon = mh and true or false end
    end
    if ns.LowestDurability then local ok, d = pcall(ns.LowestDurability, ns); if ok then f.durability = d end end
    for _, id in ipairs(ns.CLASS_REAGENTS[class] or {}) do
        local n = Count(id)
        if n and n > 0 then f.reagents[#f.reagents + 1] = { id = id, name = ItemName(id), n = n } end
    end
    if #f.reagents == 0 and ns.CLASS_REAGENTS[class] then      -- none of them at all: say so for the first
        local id = ns.CLASS_REAGENTS[class][1]
        f.reagents[1] = { id = id, name = ItemName(id), n = 0 }
    end
    f.free = FreeSlots()
    if ns.TalentSet then f.talentSet = ns:TalentSet() end
    if ns.EquipmentSets then
        f.gearSet = false
        local ok, sets = pcall(ns.EquipmentSets, ns)
        for _, s in ipairs(ok and sets or {}) do if s.worn then f.gearSet = s.name end end
    end
    return f
end
function ns:ReadyMe()
    if ns.Yes(InCombatLockdown and InCombatLockdown()) then ns:Print("Not during a fight: the game hides buffs from add-ons until it is over."); return false end
    local lines, short = {}, 0
    for _, l in ipairs(ns.ReadyMeLines(ns:ReadyMeFacts())) do
        local right
        if l.ok == true then right = ns:SignalHex("good") .. (l.text or ns:Tr("yes")) .. "|r"
        elseif l.ok == false then right = ns:SignalHex("bad") .. (l.text or ns:Tr("missing")) .. "|r"; short = short + 1
        else right = DIM .. ns:Tr(l.text or "?") .. "|r" end
        lines[#lines + 1] = { left = ns:Tr(l.label), right = right }
    end
    ns:ShowList("ReadyMe", short == 0 and "Ready for the raid" or "Not quite ready", lines,
        "Food, flask, weapon, repairs, reagents, bag space, talents and gear. Again before the pull to check.", 380, math.min(420, 80 + #lines * 18))
    return short
end

------------------------------------------------------------------------------------------
-- Boss notes: a note of your own for each boss (a tactic, who soaks, when to use a cooldown).
-- It opens when you target that boss, when the fight starts, or when a pull timer starts with
-- it targeted. The group's leader (or an assistant) can send theirs to everyone in the group who
-- has the add-on; a note sent to you is kept beside your own, never over it.
--   /fgui bossnote               your target's note, to read or write
--   /fgui bossnote <boss>        that boss's note
--   /fgui bossnote send          send your target's note to the group
--   /fgui bossnote list          every boss with a note
------------------------------------------------------------------------------------------
local function NoteStore()
    if type(ns.root) ~= "table" then return {}, {} end
    ns.root.bossNotes = type(ns.root.bossNotes) == "table" and ns.root.bossNotes or {}
    ns.root.bossNotesSent = type(ns.root.bossNotesSent) == "table" and ns.root.bossNotesSent or {}
    return ns.root.bossNotes, ns.root.bossNotesSent
end
function ns.BossKey(name)
    if type(name) ~= "string" or Secret(name) then return nil end
    local k = ns.Trim(name):lower()
    return k ~= "" and k or nil
end
function ns:BossNote(name)
    local mine, sent = NoteStore()
    local key = ns.BossKey(name)
    if not key then return nil end
    return mine[key], sent[key]
end
function ns:SetBossNote(name, text)
    local mine = NoteStore()
    local key = ns.BossKey(name)
    if not key then return false end
    text = type(text) == "string" and ns.Trim(text) or ""
    mine[key] = (text ~= "") and { name = ns.Trim(name), text = text, t = time and time() or 0 } or nil
    return true
end
-- Is the target a boss? Its name, or nil.
function ns.TargetBoss()
    if not ns.Yes(UnitExists("target")) or ns.Yes(UnitIsPlayer("target")) then return nil end
    local isBoss = false
    local okC, c = pcall(UnitClassification, "target")
    if okC and not Secret(c) and c == "worldboss" then isBoss = true end
    local okL, lvl = pcall(UnitLevel, "target")
    if okL and type(lvl) == "number" and not Secret(lvl) and lvl == -1 then isBoss = true end
    for i = 1, 5 do if ns.Yes(UnitIsUnit and UnitIsUnit("target", "boss" .. i)) then isBoss = true end end
    if not isBoss then return nil end
    local okN, name = pcall(UnitName, "target")
    return (okN and type(name) == "string" and not Secret(name)) and name or nil
end

local panel, editor
local function Panel()
    if panel then return panel end
    panel = CreateFrame("Frame", "FantasyGlassUIBossNote", UIParent, ns.template)
    panel:SetSize(320, 120)
    panel:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -260, -220)
    panel:SetBackdrop(ns.BACKDROP)
    ns:Paint(panel, "SetBackdropColor", "window", 0.94)
    ns:Paint(panel, "SetBackdropBorderColor", "@accent", 1)
    ns:Dress(panel, true)
    panel.title = ns:NewText(panel, 13, "LEFT", true)
    panel.title:SetPoint("TOPLEFT", 10, -8)
    ns:Paint(panel.title, "SetTextColor", "@accent")
    panel.text = ns:NewText(panel, 12, "LEFT")
    panel.text:SetPoint("TOPLEFT", 10, -28)
    panel.text:SetWidth(300)
    if panel.text.SetJustifyV then panel.text:SetJustifyV("TOP") end
    local close = ns:CreateButton(panel, "X", 20, 18, function() panel:Hide() end)
    close:SetPoint("TOPRIGHT", -6, -6)
    local edit = ns:SizeToLabel(ns:CreateButton(panel, "Edit", 200, 18, function() ns:EditBossNote(panel.boss) end), 50)
    ns:ButtonTip(edit, "Change this boss's note. It shows again each time you fight the boss.")
    edit:SetPoint("RIGHT", close, "LEFT", -4, 0)
    panel:Hide()
    if type(UISpecialFrames) == "table" then tinsert(UISpecialFrames, "FantasyGlassUIBossNote") end      -- (Escape puts it away)
    local entry = ns:RegisterMovable(panel, "bossNote", "Boss note")
    if type(entry) == "table" then entry.offPage = true end
    return panel
end
function ns:ShowBossNote(name, quietIfNone)
    local mine, sent = ns:BossNote(name)
    if not mine and not sent then
        if not quietIfNone then ns:Print("No note for %s yet: |cffffff00/fgui bossnote|r with it targeted writes one.", tostring(name)) end
        return false
    end
    local p = Panel()
    p.boss = name
    p.title:SetText((mine and mine.name) or (sent and sent.name) or tostring(name))
    local parts = {}
    if mine then parts[#parts + 1] = mine.text end
    if sent then parts[#parts + 1] = "|cff9aa4b4" .. format(ns:Tr("From %s:"), tostring(sent.from)) .. "|r " .. sent.text end
    p.text:SetText(table.concat(parts, "\n\n"))
    local h = p.text.GetStringHeight and p.text:GetStringHeight()
    p:SetHeight(math.max(60, math.min(400, ((type(h) == "number" and not Secret(h)) and h or 60) + 40)))
    p:Show()
    return true
end
function ns:EditBossNote(name)
    if type(name) ~= "string" or name == "" then ns:Print("Target the boss first, or type its name: /fgui bossnote Ragnaros"); return false end
    if not editor then
        local w = CreateFrame("Frame", "FantasyGlassUIBossNoteEditor", UIParent, ns.template)
        w:SetSize(420, 260)
        w:SetPoint("CENTER")
        w:SetFrameStrata("DIALOG")
        w:SetBackdrop(ns.BACKDROP)
        ns:Paint(w, "SetBackdropColor", "window", 0.97)
        ns:Paint(w, "SetBackdropBorderColor", "@border", 1)
        ns:Dress(w)
        w:EnableMouse(true); w:SetMovable(true); if w.SetClampedToScreen then w:SetClampedToScreen(true) end; w:RegisterForDrag("LeftButton")
        w:SetScript("OnDragStart", function(self) self:StartMoving() end)
        ns:KeepPlace(w, "BossNoteEdit")
        if type(UISpecialFrames) == "table" then tinsert(UISpecialFrames, "FantasyGlassUIBossNoteEditor") end
        w.title = ns:NewText(w, 14, "LEFT", true)
        w.title:SetPoint("TOPLEFT", 14, -12)
        ns:Paint(w.title, "SetTextColor", "@accent")
        local close = ns:CreateButton(w, "X", 22, 20, function() w:Hide() end)
        close:SetPoint("TOPRIGHT", -8, -8)
        local scroll = CreateFrame("ScrollFrame", "FantasyGlassUIBossNoteScroll", w, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 14, -40)
        scroll:SetPoint("BOTTOMRIGHT", -32, 44)
        local box = CreateFrame("EditBox", nil, scroll)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:SetWidth(360)
        box:SetMaxLetters(1000)
        if box.SetFontObject and _G.ChatFontNormal then box:SetFontObject(_G.ChatFontNormal) end
        box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scroll:SetScrollChild(box)
        w.box = box
        -- the writing area looks like the add-on's other text boxes, and a click anywhere in it puts the
        -- cursor in the note (an empty note is only one line tall, so it would be hard to hit)
        local field = CreateFrame("Frame", nil, w, ns.template)
        field:SetPoint("TOPLEFT", scroll, "TOPLEFT", -4, 4)
        field:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 4, -4)
        field:SetFrameLevel(math.max(0, (scroll:GetFrameLevel() or 1) - 1))
        if field.SetBackdrop then
            field:SetBackdrop(ns.BACKDROP)
            ns:Paint(field, "SetBackdropColor", "field", 1)
            ns:Paint(field, "SetBackdropBorderColor", "@border", 1)
        end
        box:SetHeight(180)
        scroll:EnableMouse(true)
        scroll:SetScript("OnMouseDown", function() box:SetFocus() end)
        local save = ns:CreateButton(w, "Save", 80, 22, function()
            ns:SetBossNote(w.boss, box:GetText())
            ns:Print("Note for %s saved.", tostring(w.boss))
            w:Hide()
        end)
        save:SetPoint("BOTTOMLEFT", 14, 12)
        local send = ns:CreateButton(w, "Send to my group", 140, 22, function()
            ns:SetBossNote(w.boss, box:GetText())
            ns:SendBossNote(w.boss)
        end)
        send:SetPoint("LEFT", save, "RIGHT", 8, 0)
        ns:ButtonTip(send, "Everyone in your group with Fantasy Glass UI gets this note for the boss, and sees it when the fight starts.")
        editor = w
    end
    local mine = ns:BossNote(name)
    editor.boss = name
    editor.title:SetText(format(ns:Tr("Note for %s"), name))
    editor.box:SetText(mine and mine.text or "")
    editor:Show()
    editor.box:SetFocus()                                    -- (ready to type)
    return editor
end
function ns:SendBossNote(name)
    local mine = ns:BossNote(name)
    if not mine then ns:Print("No note for %s to send.", tostring(name)); return false end
    local ch = ns.GroupChannel and ns.GroupChannel()
    if not ch then ns:Print("You are not in a group."); return false end
    local lead = ns.Yes(UnitIsGroupLeader and UnitIsGroupLeader("player")) or ns.Yes(UnitIsGroupAssistant and UnitIsGroupAssistant("player"))
    if not lead then ns:Print("Only the group's leader or an assistant can send boss notes."); return false end
    local whole = (mine.name .. "\n" .. mine.text):gsub("\n", "~n~")     -- (no line breaks in an add-on message)
    local parts = ns.ShareChunks(whole)
    local id = format("%x", math.random(4096, 65535))
    for i, piece in ipairs(parts) do
        ns:After((i - 1) * 0.15, function() ns.GroupSend(format("BN:%s:%d:%d:%s", id, i, #parts, piece), ch) end)
    end
    ns:Print("Sending your note for %s to the group.", mine.name)
    return #parts
end
-- A note from the group's leader, put back together: kept beside yours.
function ns:ReceiveBossNote(from, whole)
    if type(whole) ~= "string" then return false end
    whole = whole:gsub("~n~", "\n")
    local name, text = whole:match("^([^\n]+)\n(.*)$")
    local key = ns.BossKey(name)
    if not key or not text or text == "" then return false end
    local _, sent = NoteStore()
    sent[key] = { name = name, text = text, from = from, t = time and time() or 0 }
    ns:Print("%s sent the group a note for %s.", tostring(from), name)
    return true
end
function ns:BossNoteCommand(text)
    text = ns.Trim(text or "")
    local low = text:lower()
    if low == "list" then
        local mine, sent = NoteStore()
        local lines = {}
        local seen = {}
        local armed                                          -- (right-click twice to delete: a note can't be brought back)
        local function Click(n, store, key)
            return function(button)
                if button == "RightButton" then
                    if armed == key then
                        store[key] = nil; armed = nil
                        ns:Print("Note for %s deleted.", n.name)
                        ns:BossNoteCommand("list")
                    else
                        armed = key
                        ns:Print("Right-click %s again to delete its note.", n.name)
                    end
                else
                    ns:ShowBossNote(n.name)
                end
            end
        end
        for key, n in pairs(mine) do seen[key] = true; lines[#lines + 1] = { left = n.name, right = DIM .. ns:Tr("yours") .. "|r", click = Click(n, mine, key) } end
        for key, n in pairs(sent) do if not seen[key] then lines[#lines + 1] = { left = n.name, right = DIM .. format(ns:Tr("from %s"), tostring(n.from)) .. "|r", click = Click(n, sent, key) } end end
        table.sort(lines, function(a, b) return a.left < b.left end)
        if #lines == 0 then lines[1] = { left = ns:Tr("No boss notes yet. Target a boss and type /fgui bossnote.") } end
        ns:ShowList("BossNotes", "Boss notes", lines, "Click one to read it. Right-click twice to delete it.", 360, math.min(420, 80 + #lines * 18))
        return #lines
    end
    local boss = ns.TargetBoss() or (ns.Yes(UnitExists("target")) and select(2, pcall(UnitName, "target"))) or nil
    if type(boss) ~= "string" or Secret(boss) then boss = nil end
    if low == "send" then return ns:SendBossNote(boss) end
    local name = (text ~= "") and text or boss
    if not name then ns:Print("Target the boss first, or type its name: /fgui bossnote Ragnaros"); return false end
    if not ns:ShowBossNote(name, true) then ns:EditBossNote(name) end
    return name
end
ns:NewModule("bossNotes", function()
    local incoming = {}
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "ENCOUNTER_START", "ENCOUNTER_END", "CHAT_MSG_ADDON" }) do pcall(ev.RegisterEvent, ev, e) end
    local shownFor
    ev:SetScript("OnEvent", ns:Guard("Boss notes", function(_, event, a, b, c, d)
        if event == "PLAYER_TARGET_CHANGED" then
            local boss = ns.TargetBoss()
            if boss and boss ~= shownFor then shownFor = boss; ns:ShowBossNote(boss, true) end
        elseif event == "ENCOUNTER_START" then
            if type(b) == "string" and not Secret(b) then ns:ShowBossNote(b, true) end
        elseif event == "ENCOUNTER_END" then                   -- the fight is over: the note has done its job
            shownFor = nil
            if panel and panel.Hide then panel:Hide() end
        elseif event == "CHAT_MSG_ADDON" then
            if Secret(a) or Secret(b) or a ~= "FGUI" or type(b) ~= "string" then return end
            local id, i, n, piece = b:match("^BN:(%w+):(%d+):(%d+):(.*)$")
            if not id then return end
            local from = ns.GroupShortName and ns.GroupShortName(d) or d
            if from == UnitName("player") then return end
            i, n = tonumber(i), tonumber(n)
            local now = GetTime()
            for oldId, old in pairs(incoming) do                -- (a note that never finished arriving is let go)
                if now - (old.at or now) > 60 then incoming[oldId] = nil end
            end
            local t = incoming[id] or { parts = {}, got = 0, n = n, at = now }
            if not t.parts[i] then t.parts[i] = piece; t.got = t.got + 1 end
            incoming[id] = t
            if t.got >= t.n then incoming[id] = nil; ns:ReceiveBossNote(from, table.concat(t.parts)) end
        end
    end))
    ns.bossNoteTest = { Panel = Panel }
end)

------------------------------------------------------------------------------------------
-- Death recap: the last hits and heals you took before you died, from what the game tells your
-- own frame (no combat log is needed). Amounts the game hides during a fight are shown as the
-- game gives them. "You died" in chat says to type /fgui death; /fgui death shows it again.
------------------------------------------------------------------------------------------
local KEEP = 20
local recap = { list = {}, last = nil }
ns.deathRecap = recap
local KINDS = { WOUND = "Hit", HEAL = "Heal", DODGE = "Dodged", PARRY = "Parried", MISS = "Missed", BLOCK = "Blocked",
    RESIST = "Resisted", IMMUNE = "Immune", ABSORB = "Absorbed", ENERGIZE = nil }
-- the kind of damage (the game's own words where it has them)
local SCHOOLS = { [1] = { "STRING_SCHOOL_PHYSICAL", "Physical" }, [2] = { "STRING_SCHOOL_HOLY", "Holy" }, [4] = { "STRING_SCHOOL_FIRE", "Fire" },
    [8] = { "STRING_SCHOOL_NATURE", "Nature" }, [16] = { "STRING_SCHOOL_FROST", "Frost" }, [32] = { "STRING_SCHOOL_SHADOW", "Shadow" },
    [64] = { "STRING_SCHOOL_ARCANE", "Arcane" } }
function ns.DamageSchool(mask)
    if type(mask) ~= "number" or Secret(mask) then return nil end
    local s = SCHOOLS[mask]
    if not s then return nil end
    local word = _G[s[1]]
    return (type(word) == "string" and word ~= "") and word or s[2]
end
function ns.DeathRecapNote(list, action, flag, amount, now, school)
    if Secret(action) then action = "WOUND" end
    local kind = KINDS[action]
    if not kind then return false end
    local crit = not Secret(flag) and flag == "CRITICAL"
    list[#list + 1] = { kind = kind, crit = crit, amount = amount, t = now, school = (kind == "Hit") and ns.DamageSchool(school) or nil }
    while #list > KEEP do table.remove(list, 1) end
    return true
end
-- The lines for the window: the last ones before `deathAt`, newest last.
function ns.DeathRecapLines(list, deathAt, within)
    within = within or 12
    local out = {}
    for _, e in ipairs(list) do
        if e.t <= deathAt + 0.5 and e.t >= deathAt - within then out[#out + 1] = e end
    end
    return out
end
function ns:ShowDeathRecap()
    local d = recap.last
    if not d then ns:Print("Nothing to show yet: you have not died this session."); return false end
    local lines = {}
    for _, e in ipairs(d.events) do
        local when = format("-%.1fs", math.max(0, d.at - e.t))
        local label = DIM .. when .. "|r  " .. ns:Tr(e.kind) .. (e.school and (" (" .. e.school .. ")") or "") .. (e.crit and (" |cffffd100" .. ns:Tr("critical") .. "|r") or "")
        local line = { left = label, color = (e.kind == "Heal") and { 0.4, 1, 0.5 } or { 1, 0.8, 0.75 } }
        if Secret(e.amount) then line.secretRight, line.hasSecret = e.amount, true
        elseif type(e.amount) == "number" and e.amount > 0 then
            line.right = (type(BreakUpLargeNumbers) == "function" and BreakUpLargeNumbers(e.amount)) or tostring(e.amount)     -- (12,345)
        end
        lines[#lines + 1] = line
    end
    if #lines == 0 then lines[1] = { left = ns:Tr("Nothing hit you in the last few seconds.") }
    else
        local taken, first = 0, nil                                  -- (on top: what it all came to; hidden amounts are left out)
        for _, e in ipairs(d.events) do
            if e.kind == "Hit" and not Secret(e.amount) and type(e.amount) == "number" then taken = taken + e.amount; first = first or e.t end
        end
        if taken > 0 then
            local n = (type(BreakUpLargeNumbers) == "function" and BreakUpLargeNumbers(taken)) or tostring(taken)
            table.insert(lines, 1, { left = ns:AccentHex() .. format(ns:Tr("Damage taken in the last %.1f seconds"), math.max(0, d.at - first)) .. "|r", right = n })
        end
    end
    ns:ShowList("DeathRecap", "What happened", lines, "Your last moments, oldest first.", 340, math.min(420, 80 + #lines * 18))
    return #d.events
end
ns:NewModule("deathRecap", function()
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterUnitEvent, ev, "UNIT_COMBAT", "player")
    pcall(ev.RegisterEvent, ev, "PLAYER_DEAD")
    ev:SetScript("OnEvent", ns:Guard("Death recap", function(_, event, _, action, flag, amount, school)
        if event == "UNIT_COMBAT" then
            ns.DeathRecapNote(recap.list, action, flag, amount, GetTime(), school)
        else
            local now = GetTime()
            recap.last = { at = now, events = ns.DeathRecapLines(recap.list, now) }
            recap.list = {}
            ns:Print("You died. |cffffff00/fgui death|r shows what hit you.")
        end
    end))
end)
