local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Group gear check (11.16): /fgui gear. Everyone in your party or raid with their item level, the
-- lowest first, and the group's average. The game sends another player's gear only when asked, one
-- player at a time and only within reach, so the list fills in a player every second or so while it
-- is open; anyone too far away shows as "out of reach" until they come closer. Levels are kept for
-- ten minutes, so opening it again is quick. It never asks during a fight, or while your own
-- inspect window is open.
------------------------------------------------------------------------------------------
local KEEP, WAIT, GAP = 600, 4, 1.2
local SLOT_IDS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }      -- (no shirt or tabard)

local known = {}                    -- guid -> { level, at }
ns.gearKnown = known

-- The average item level worn by `unit`, from what the game has sent; nil if nothing yet.
function ns.GearLevelOf(unit)
    local levels = {}
    for _, id in ipairs(SLOT_IDS) do
        local l = ns.InspectSlotLevel and ns.InspectSlotLevel(unit, id)
        if l then levels[#levels + 1] = l end
    end
    if #levels < 6 then return nil end                     -- (only part of the gear has arrived)
    -- a two-handed weapon counts for both hands, as the game's own average does
    local okM, main = pcall(GetInventoryItemLink, unit, 16)
    local okO, off = pcall(GetInventoryItemLink, unit, 17)
    if okM and type(main) == "string" and not Secret(main) and not (okO and type(off) == "string") then
        local GetInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
        local okI, _, _, _, loc = pcall(GetInstant or error, main)
        if okI and loc == "INVTYPE_2HWEAPON" then levels[#levels + 1] = ns.InspectSlotLevel(unit, 16) end
    end
    return ns.AverageItemLevel(levels)
end

-- The lines for the window: { name, class, level or nil, state }, lowest first; and the average.
function ns.GearLines(members, now)
    local out, sum, n = {}, 0, 0
    for _, m in ipairs(members) do
        local e = m.guid and known[m.guid]
        local level = m.level or (e and (now - e.at) <= KEEP and e.level) or nil
        if level then sum = sum + level; n = n + 1 end
        out[#out + 1] = { name = m.name, class = m.class, level = level, state = m.state }
    end
    table.sort(out, function(a, b)
        if (a.level ~= nil) ~= (b.level ~= nil) then return a.level ~= nil end
        if a.level and b.level and a.level ~= b.level then return a.level < b.level end
        return tostring(a.name) < tostring(b.name)
    end)
    return out, n > 0 and (sum / n) or nil, n
end

local function Guid(unit)
    local ok, g = pcall(UnitGUID, unit)
    return ok and type(g) == "string" and not Secret(g) and g or nil
end
local function ClassHex(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not c then return "|cffffffff" end
    return format("|cff%02x%02x%02x", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
end

local open, queue, asking = false, {}, nil
local farAt = {}                    -- guid -> when they were last out of reach (asked again after 20 seconds)
local FAR_AGAIN = 20
local function Members()
    local list = {}
    local okN, myName = pcall(UnitName, "player")
    local _, myClass = UnitClass("player")
    local mine = ns.GearLevelOf("player")
    if not mine and GetAverageItemLevel then local ok, _, eq = pcall(GetAverageItemLevel); if ok and type(eq) == "number" then mine = eq end end
    list[1] = { name = okN and myName or "", class = myClass, unit = "player", level = mine, guid = Guid("player") }
    for _, m in ipairs(ns.GroupMembers and ns:GroupMembers() or {}) do
        local state
        local guid = Guid(m.unit)
        if not m.online then state = "offline"
        elseif guid and farAt[guid] and GetTime() - farAt[guid] < FAR_AGAIN then state = "far" end
        list[#list + 1] = { name = ns.GroupShortName and ns.GroupShortName(m.name) or m.name, class = m.class, unit = m.unit, guid = guid, state = state }
    end
    return list
end

function ns:ShowGear()
    open = true
    local members = Members()
    local now = GetTime()
    -- who still needs asking
    queue = {}
    for _, m in ipairs(members) do
        if m.unit ~= "player" and m.guid and not m.state and not (known[m.guid] and now - known[m.guid].at <= KEEP) then queue[#queue + 1] = m end
    end
    local rows, avg, n = ns.GearLines(members, now)
    local lines = {}
    lines[1] = { left = ns:AccentHex() .. ns:Tr("Group average") .. "|r", right = avg and format("%.1f", avg) or "-",
                 color = { 1, 0.82, 0.3 } }
    for _, r in ipairs(rows) do
        local right
        if r.level then right = format("%.1f", r.level)
        elseif r.state == "offline" then right = "|cff9aa4b4" .. ns:Tr("offline") .. "|r"
        elseif r.state == "far" then right = "|cff9aa4b4" .. ns:Tr("out of reach") .. "|r"
        else right = "|cff9aa4b4" .. ns:Tr("asking...") .. "|r" end
        lines[#lines + 1] = { left = ClassHex(r.class) .. tostring(r.name) .. "|r", right = right }
    end
    local note = format(ns:Tr("%d of %d known. Players fill in as the game sends their gear; anyone far away shows when they come closer."), n, #rows)
    ns:ShowList("GearCheck", "Group gear", lines, note, 360, math.min(460, 90 + #lines * 18))
    return lines, avg
end

ns:NewModule("gearCheck", function()
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "INSPECT_READY")
    pcall(ev.RegisterEvent, ev, "GROUP_ROSTER_UPDATE")
    local function Done(redraw)
        if asking and ClearInspectPlayer then pcall(ClearInspectPlayer) end
        asking = nil
        if redraw and open then ns:ShowGear() end
    end
    ev:SetScript("OnEvent", ns:Guard("Group gear", function(_, event, guid)
        if event == "INSPECT_READY" and asking and guid == asking.guid then farAt[guid] = nil end
        if event == "GROUP_ROSTER_UPDATE" then if open then ns:After(1, function() if open then ns:ShowGear() end end) end return end
        if not asking or guid ~= asking.guid then return end
        local level = ns.GearLevelOf(asking.unit)
        if level then known[asking.guid] = { level = level, at = GetTime() } end
        Done(true)
    end))
    local last = 0
    ns:Every(0.3, "Group gear", function()
        if not open then return end
        local win = _G.FantasyGlassUIListGearCheck
        if win and win.IsShown and not win:IsShown() then open = false; queue = {}; return end
        local now = GetTime()
        if asking then
            if now - asking.at > WAIT then farAt[asking.guid] = now; Done(true) end        -- (no answer: too far, or the game was busy)
            return
        end
        if now - last < GAP or InCombatLockdown() then return end
        local insp = _G.InspectFrame
        if type(insp) == "table" and insp.IsShown and insp:IsShown() then return end   -- (your own inspect window)
        local m = table.remove(queue, 1)
        if not m then return end
        local okC, can = pcall(CanInspect, m.unit)
        if not (okC and can == true) then farAt[m.guid] = now; ns:ShowGear(); return end
        if type(NotifyInspect) ~= "function" then return end
        last = now
        asking = { guid = m.guid, unit = m.unit, at = now, m = m }
        pcall(NotifyInspect, m.unit)
    end)
    ns.gearTest = { Members = Members, Queue = function() return queue end, Open = function(v) open = v end }
end)
