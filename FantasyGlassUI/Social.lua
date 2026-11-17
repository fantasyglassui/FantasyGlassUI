local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- People: your own notes on players, the people you grouped with lately, who joined and left,
-- who is not here yet, a /roll tracker, raid lockouts, and a reset-instances button.
------------------------------------------------------------------------------------------
-- Everyone in your group but you: { { name = "Name" or "Name-Realm", class, unit, online, zone } ... }.
function ns:GroupMembers()
    local out = {}
    local n = (GetNumGroupMembers and GetNumGroupMembers()) or 0
    if type(n) ~= "number" or Secret(n) or n <= 0 then return out end
    local raid = ns.Yes(IsInRaid and IsInRaid())
    for i = 1, raid and n or (n - 1) do
        local unit = (raid and "raid" or "party") .. i
        if ns.Yes(UnitExists(unit)) and not ns.Yes(UnitIsUnit(unit, "player")) then
            local name, realm = UnitName(unit)
            if type(name) == "string" and not Secret(name) and name ~= "" and name ~= UNKNOWNOBJECT then
                if type(realm) == "string" and not Secret(realm) and realm ~= "" then name = name .. "-" .. realm end
                local _, class = UnitClass(unit)
                local zone
                if raid and GetRaidRosterInfo then local ok, _, _, _, _, _, _, z = pcall(GetRaidRosterInfo, i); if ok and type(z) == "string" and not Secret(z) then zone = z end end
                out[#out + 1] = { name = name, class = (type(class) == "string" and not Secret(class)) and class or nil, unit = unit,
                    online = not ns.Is(UnitIsConnected(unit), false), zone = zone }
            end
        end
    end
    return out
end
-- Who is new and who has gone, between two lists of names.
function ns.RosterDiff(before, after)
    local joined, left = {}, {}
    for name in pairs(after) do if not before[name] then joined[#joined + 1] = name end end
    for name in pairs(before) do if not after[name] then left[#left + 1] = name end end
    table.sort(joined); table.sort(left)
    return joined, left
end

-- Notes on players -------------------------------------------------------------------------
local function Notes()
    if type(ns.root) ~= "table" then return {} end
    if type(ns.root.playerNotes) ~= "table" then ns.root.playerNotes = {} end
    return ns.root.playerNotes
end
function ns:PlayerNote(name)
    if type(name) ~= "string" or Secret(name) then return nil end
    local notes = Notes()
    return notes[name] or notes[(name:gsub("%-.*$", ""))]
end
function ns:SetPlayerNote(name, text)
    if type(name) ~= "string" or name == "" then return false end
    text = ns.Trim(text)
    Notes()[name] = (text ~= "" and text:lower() ~= "clear") and text or nil
    return true
end
local function TargetPlayer()
    if not (ns.Yes(UnitExists("target")) and ns.Yes(UnitIsPlayer("target"))) then return nil end
    local name, realm = UnitName("target")
    if type(name) ~= "string" or Secret(name) then return nil end
    if type(realm) == "string" and not Secret(realm) and realm ~= "" then name = name .. "-" .. realm end
    return name
end
-- /fgui note good tank          a note on the player you have targeted
-- /fgui note Bob good tank      without a target: the first word is the name
-- /fgui note clear              removes it          /fgui note list     all of them
function ns:NoteCommand(text)
    text = ns.Trim(text)
    if text:lower() == "list" or (text == "" and not TargetPlayer()) then
        local lines = {}
        for name, note in pairs(Notes()) do
            lines[#lines + 1] = { left = name .. ":  |cffcccccc" .. note .. "|r", name = name,
                click = function(button) if button == "RightButton" then ns:SetPlayerNote(name, ""); ns:NoteCommand("list") end end }
        end
        table.sort(lines, function(a, b) return a.name < b.name end)
        return ns:ShowList("Notes", "Notes on players", lines, "Right-click a line to remove that note.")
    end
    local name = TargetPlayer()
    if not name then
        local first, rest = text:match("^(%S+)%s*(.*)$")
        name, text = first, rest or ""
    end
    if text == "" then
        local note = ns:PlayerNote(name)
        if note then ns:Print("Note on %s: %s", name, note) else ns:Print("No note on %s. Add one with /fgui note <text>.", name) end
        return
    end
    ns:SetPlayerNote(name, text)
    if ns:PlayerNote(name) then ns:Print("Note on %s: %s", name, ns:PlayerNote(name)) else ns:Print("Note on %s removed.", name) end
end

-- Recent group mates ------------------------------------------------------------------------
ns.RECENT_MAX = 40
-- Put these people at the top of the list (newest first, each once, no more than the limit).
function ns.RecentAdd(list, people, now, where)
    for _, p in ipairs(people) do
        for i = #list, 1, -1 do if list[i].name == p.name then table.remove(list, i) end end
        table.insert(list, 1, { name = p.name, class = p.class, at = now, where = where })
    end
    while #list > ns.RECENT_MAX do table.remove(list) end
    return list
end
local function Invite(name)
    local go = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
    if type(go) == "function" then pcall(go, name) end
end
ns.InvitePlayer = Invite
function ns:ShowRecent()
    local list = (type(ns.root) == "table" and type(ns.root.recentMates) == "table") and ns.root.recentMates or {}
    local lines = {}
    local now = time and time() or 0
    for _, p in ipairs(list) do
        local r, g, b = 1, 1, 1
        if p.class then local ok, cr, cg, cb = pcall(function() return ns:ClassRGB(p.class) end); if ok and type(cr) == "number" then r, g, b = cr, cg, cb end end
        local ago = math.max(0, now - (p.at or now))
        local when = (ago < 3600) and format("%d min", math.floor(ago / 60)) or (ago < 86400) and format("%d h", math.floor(ago / 3600)) or format("%d d", math.floor(ago / 86400))
        local note = ns:PlayerNote(p.name)
        lines[#lines + 1] = { left = p.name .. (note and ("  |cff999999" .. note .. "|r") or ""), right = when, color = { r, g, b },
            tip = { p.name, p.where or "", note or "" },
            click = function(button)
                if button == "RightButton" then Invite(p.name); ns:Print("Invited %s.", p.name)
                elseif ChatFrame_SendTell then pcall(ChatFrame_SendTell, p.name) end
            end }
    end
    return ns:ShowList("Recent", "Recent group mates", lines, "Click a name to whisper. Right-click to invite.")
end

-- The roster watcher: feeds the recent list, the notes and the join/leave notices ------------
ns:NewModule("groupWatch", function()
    if type(ns.root) ~= "table" then return end
    if type(ns.root.recentMates) ~= "table" then ns.root.recentMates = {} end
    local known, first = {}, true
    local function Scan()
        local members = ns:GroupMembers()
        local now, byName = {}, {}
        for _, m in ipairs(members) do now[m.name] = true; byName[m.name] = m end
        local joined, left = ns.RosterDiff(known, now)
        local wasAlone = next(known) == nil
        known = now
        if #joined > 0 and ns.db.recentMates then
            local people = {}
            for _, name in ipairs(joined) do people[#people + 1] = byName[name] end
            local where = GetRealZoneText and GetRealZoneText() or nil
            ns.RecentAdd(ns.root.recentMates, people, time and time() or 0, (type(where) == "string" and not Secret(where)) and where or nil)
        end
        if first then first = false; return joined, left end                        -- (at login: nobody "joined")
        for _, name in ipairs(joined) do
            local note = ns.db.playerNotes and ns:PlayerNote(name)
            if note then ns:Print("Note on %s: %s", name, note) end
        end
        if ns.db.groupNotices and not wasAlone then
            for _, name in ipairs(joined) do ns:Print("%s joined the group.", name) end
            for _, name in ipairs(left) do ns:Print("%s left the group.", name) end
            if (#joined > 0 or #left > 0) and PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.IG_PLAYER_INVITE or 880) end
            if #joined > 0 and #members == 4 and not ns.Yes(IsInRaid and IsInRaid()) then ns:Print("The group is full.") end
        end
        return joined, left
    end
    ns.groupWatchTest = { Scan = Scan, Forget = function() known, first = {}, false end }
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do pcall(ev.RegisterEvent, ev, e) end
    local queued = false
    ev:SetScript("OnEvent", function()
        if queued then return end
        queued = true
        ns:After(1, function() queued = false; pcall(Scan) end)                   -- (the game sends several at once)
    end)
end)

-- A note in a player's tooltip.
ns:NewModule("playerNotes", function()
    local function Add(tooltip)
        if tooltip ~= GameTooltip or not tooltip.GetUnit then return end
        local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
        if not ok or type(unit) ~= "string" or Secret(unit) or not ns.Yes(UnitIsPlayer(unit)) then return end
        local name, realm = UnitName(unit)
        if type(name) ~= "string" or Secret(name) then return end
        local note = ns:PlayerNote((type(realm) == "string" and not Secret(realm) and realm ~= "") and (name .. "-" .. realm) or name)
        if note then tooltip:AddLine(ns:Tr("Note") .. ": " .. note, 1, 0.82, 0.3, true); tooltip:Show() end
    end
    local safe = ns:Guard("Player notes", Add)
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
        pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Unit, safe)
    elseif GameTooltip and GameTooltip.HookScript then
        pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", safe)
    end
    ns.playerNoteTip = Add
end)

-- Who is missing ---------------------------------------------------------------------------
-- members: { name, zone, online }. Returns lines for those not in `myZone`.
function ns.MissingFrom(members, myZone)
    local out = {}
    for _, m in ipairs(members or {}) do
        if not m.online then out[#out + 1] = { name = m.name, why = "offline" }
        elseif m.zone and myZone and m.zone ~= myZone then out[#out + 1] = { name = m.name, why = m.zone }
        elseif m.far then out[#out + 1] = { name = m.name, why = "not nearby" } end
    end
    return out
end
function ns:ShowMissing()
    local members = ns:GroupMembers()
    if #members == 0 then ns:Print("You are not in a group."); return end
    local zone = GetRealZoneText and GetRealZoneText() or nil
    if type(zone) ~= "string" or Secret(zone) then zone = nil end
    for _, m in ipairs(members) do
        if not m.zone and UnitIsVisible then m.far = ns.Is(UnitIsVisible(m.unit), false) end      -- (a party tells no zones: near enough to see?)
    end
    local lines = {}
    for _, m in ipairs(ns.MissingFrom(members, zone)) do
        lines[#lines + 1] = { left = m.name, right = ns:Tr(m.why), click = function() if ChatFrame_SendTell then pcall(ChatFrame_SendTell, m.name) end end }
    end
    if #lines == 0 then ns:Print("Everyone is here."); return lines end
    ns:ShowList("Missing", "Not here yet", lines, "Click a name to whisper.")
    return lines
end

-- Roll tracker -----------------------------------------------------------------------------
-- The game's "%s rolls %d (%d-%d)" as a pattern.
function ns.RollPattern(template)
    local p = (template or "%s rolls %d (%d-%d)"):gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)")
    p = p:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
    return "^" .. p .. "$"
end
function ns.ParseRoll(message, pattern)
    if type(message) ~= "string" then return nil end
    local name, roll, low, high = message:match(pattern or ns.RollPattern())
    if not name then return nil end
    return name, tonumber(roll), tonumber(low), tonumber(high)
end
-- Rolls in order, highest first. Only 1-100 counts, and only a player's first roll.
function ns.SortRolls(rolls)
    local seen, out = {}, {}
    for _, r in ipairs(rolls or {}) do
        local entry = { name = r.name, roll = r.roll, low = r.low, high = r.high }
        if r.low ~= 1 or r.high ~= 100 then entry.void = "not 1-100"
        elseif seen[r.name] then entry.void = "rolled again"
        else seen[r.name] = true end
        out[#out + 1] = entry
    end
    table.sort(out, function(a, b)
        if (a.void and 1 or 0) ~= (b.void and 1 or 0) then return not a.void end
        return a.roll > b.roll
    end)
    return out
end
ns.rolls = {}
function ns:ShowRolls(text)
    if ns.Trim(text):lower() == "clear" then
        for i = #ns.rolls, 1, -1 do ns.rolls[i] = nil end
        ns:Print("Rolls cleared.")
        return
    end
    local lines = {}
    for i, r in ipairs(ns.SortRolls(ns.rolls)) do
        lines[#lines + 1] = { left = (i == 1 and not r.void) and (r.name .. "  |cffffd100" .. ns:Tr("wins") .. "|r") or r.name,
            right = r.void and ("|cff888888" .. r.roll .. " (" .. ns:Tr(r.void) .. ")|r") or tostring(r.roll) }
    end
    return ns:ShowList("Rolls", "Rolls", lines, "/fgui rolls clear starts a new round.")
end
ns:NewModule("rollTracker", function()
    local pattern = ns.RollPattern(type(RANDOM_ROLL_RESULT) == "string" and RANDOM_ROLL_RESULT or nil)
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "CHAT_MSG_SYSTEM")
    ev:SetScript("OnEvent", ns:Guard("Roll tracker", function(_, _, message)
        if type(message) ~= "string" or Secret(message) then return end
        local name, roll, low, high = ns.ParseRoll(message, pattern)
        if not name then return end
        ns.rolls[#ns.rolls + 1] = { name = name, roll = roll, low = low, high = high }
        while #ns.rolls > 80 do table.remove(ns.rolls, 1) end
        local w = _G.FantasyGlassUIListRolls
        if type(w) == "table" and w.IsShown and ns.Yes(w:IsShown()) then ns:ShowRolls("") end
    end))
end)

-- Raid lockouts ----------------------------------------------------------------------------
function ns:RecordLockouts()
    if type(GetNumSavedInstances) ~= "function" or type(GetSavedInstanceInfo) ~= "function" then return nil end
    local list = {}
    local ok, count = pcall(GetNumSavedInstances)
    local now = time and time() or 0
    for i = 1, (ok and type(count) == "number") and count or 0 do
        local okI, name, _, reset, _, locked, _, _, isRaid, _, difficulty, bosses, done = pcall(GetSavedInstanceInfo, i)
        if okI and type(name) == "string" and ns.Is(locked, true) and type(reset) == "number" and reset > 0 then
            list[#list + 1] = { name = name, difficulty = type(difficulty) == "string" and difficulty or "", ends = now + reset,
                raid = ns.Is(isRaid, true), bosses = tonumber(bosses) or 0, done = tonumber(done) or 0 }
        end
    end
    local me = ns.RecordCharacter and ns:RecordCharacter()
    if type(me) == "table" then me.lockouts = list end
    return list
end
-- Lines for every character's lockouts that have not run out.
function ns.LockoutLines(alts, now)
    local lines = {}
    local names = {}
    for key in pairs(alts or {}) do names[#names + 1] = key end
    table.sort(names)
    for _, key in ipairs(names) do
        local c = alts[key]
        local any = false
        for _, l in ipairs(type(c.lockouts) == "table" and c.lockouts or {}) do
            if (l.ends or 0) > now then
                if not any then any = true; lines[#lines + 1] = { left = c.name or key, header = true, class = c.class } end
                local left = l.ends - now
                lines[#lines + 1] = { left = "    " .. l.name .. ((l.difficulty or "") ~= "" and (" (" .. l.difficulty .. ")") or "") .. format("  %d/%d", l.done or 0, l.bosses or 0),
                    right = (left >= 86400) and format("%d d %d h", math.floor(left / 86400), math.floor(left % 86400 / 3600)) or format("%d h %d min", math.floor(left / 3600), math.floor(left % 3600 / 60)) }
            end
        end
    end
    return lines
end
function ns:ShowLockouts()
    if RequestRaidInfo then pcall(RequestRaidInfo) end
    if not ns:RecordLockouts() then ns:Print("This game client does not tell add-ons about raid lockouts."); return end
    local lines = ns.LockoutLines(type(ns.root) == "table" and ns.root.alts or {}, time and time() or 0)
    for _, line in ipairs(lines) do
        if line.header then
            line.color = { 1, 0.82, 0.3 }
            local ok, r, g, b = pcall(function() return ns:ClassRGB(line.class) end)
            if ok and type(r) == "number" then line.color = { r, g, b } end
        end
    end
    if #lines == 0 then lines[1] = { left = ns:Tr("None of your characters is saved to anything.") } end
    return ns:ShowList("Lockouts", "Raid and dungeon lockouts", lines, "A character's lockouts are read when you log in with it.")
end
do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "UPDATE_INSTANCE_INFO", "PLAYER_LOGIN" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Lockouts", function(_, event)
        if event == "PLAYER_LOGIN" then if RequestRaidInfo then pcall(RequestRaidInfo) end return end
        ns:RecordLockouts()
    end))
end

-- Reset instances --------------------------------------------------------------------------
function ns:ResetInstancesNow()
    if type(ResetInstances) ~= "function" then return false end
    if ns.Yes(IsInInstance and (IsInInstance())) then ns:Print("Leave the instance first."); return false end
    if ns.Yes(IsInGroup and IsInGroup()) and not ns.Yes(UnitIsGroupLeader and UnitIsGroupLeader("player")) then
        ns:Print("Only the group leader can reset instances.")
        return false
    end
    pcall(ResetInstances)
    ns:Print("Instances reset.")
    if ns.Yes(IsInGroup and IsInGroup()) then
        local Send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
        if type(Send) == "function" then pcall(Send, "Instances have been reset.", ns.Yes(IsInRaid and IsInRaid()) and "RAID" or "PARTY") end
    end
    return true
end

-- Raid frame order -------------------------------------------------------------------------
-- /fgui raidsort group | role | name
ns.raidSorts = {
    group = { groupBy = "GROUP", groupingOrder = "1,2,3,4,5,6,7,8", sortMethod = "INDEX" },
    role  = { groupBy = "ASSIGNEDROLE", groupingOrder = "TANK,HEALER,DAMAGER,NONE", sortMethod = "NAME" },
    name  = { groupBy = nil, groupingOrder = nil, sortMethod = "NAME" },
}
function ns:ApplyRaidSort()
    local header, sort = ns.raidHeader, ns.raidSorts[ns.db.raidSort or "group"] or ns.raidSorts.group
    if type(header) ~= "table" or not header.SetAttribute then return false, "the raid frames are not running" end
    if InCombatLockdown() then ns.raidSortPending = true; return false, "in combat: it changes when the fight ends" end
    ns.raidSortPending = nil
    header:SetAttribute("groupBy", sort.groupBy)
    header:SetAttribute("groupingOrder", sort.groupingOrder)
    header:SetAttribute("sortMethod", sort.sortMethod)
    return true
end
function ns:RaidSortCommand(text)
    local want = ns.Trim(text):lower()
    if ns.raidSorts[want] then ns.db.raidSort = want end
    local ok, why = ns:ApplyRaidSort()
    ns:Print("Raid frames are ordered by %s.", ns:Tr(ns.db.raidSort or "group"))
    if not ok and why then ns:Print("Not applied yet: %s.", why) end
    if want ~= "" and not ns.raidSorts[want] then ns:Print("Choose one of: /fgui raidsort group, /fgui raidsort role, /fgui raidsort name.") end
end
do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Raid frame order", function(_, event)
        if event == "PLAYER_LOGIN" then ns:After(3, function() if ns.db and (ns.db.raidSort or "group") ~= "group" then pcall(ns.ApplyRaidSort, ns) end end)
        elseif ns.raidSortPending then ns:ApplyRaidSort() end
    end))
end
