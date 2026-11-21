local _, ns = ...

------------------------------------------------------------------------------------------
-- Group practice (/fgui testgroup): the panels that only show in a group with other players who
-- have the add-on — group cooldowns, the interrupt rotation and buff coverage on raid frames — shown
-- alone, with made-up group mates, so they can be seen, placed and tried. The made-up players take
-- their turn to interrupt by themselves; on your turn use your own interrupt (or wait and it is
-- taken for you). Ends with the same command, when a fight starts, or after five minutes.
-- Nothing is sent to anyone: it is all on your screen.
------------------------------------------------------------------------------------------
ns.TEST_GROUP = {
    { name = "Aldric", class = "WARRIOR", kick = 6552,  spells = { 6552, 871 },    used = { [871] = 1500 } },
    { name = "Brenna", class = "ROGUE",   kick = 1766,  spells = { 1766 } },
    { name = "Corin",  class = "MAGE",    kick = 2139,  spells = { 2139, 11958 } },
    { name = "Dalia",  class = "DRUID",   spells = { 20484, 29166 },               used = { [20484] = 1240 } },
    { name = "Elric",  class = "PRIEST",  spells = { 10060, 6346 },                used = { [6346] = 18 } },
}
local LIMIT, TURN, MY_WAIT = 300, 4, 6

local function KickLength(id)
    local def = ns.GroupCDFor and ns.GroupCDFor(id)
    return def and def[3] or 10
end
local function MyKick(ids)
    for _, id in ipairs(ids or {}) do
        local def = ns.GroupCDFor and ns.GroupCDFor(id)
        if def and def[2] == "kick" then return id end
    end
end

-- Fill the cooldown list with the made-up group (and you). Returns the names put in.
function ns.TestGroupFill(roster, now, me, myClass, myIDs)
    local names = {}
    for _, m in ipairs(ns.TEST_GROUP) do
        local spells = {}
        for _, id in ipairs(m.spells) do spells[id] = (m.used and m.used[id]) and (now + m.used[id]) or 0 end
        roster[m.name] = { class = m.class, spells = spells, seen = now, fake = true }
        names[#names + 1] = m.name
    end
    if me and not roster[me] then
        local spells = {}
        for _, id in ipairs(myIDs or {}) do spells[id] = 0 end
        roster[me] = { class = myClass, spells = spells, seen = now, fake = true }
        names[#names + 1] = me
    end
    return names
end
-- One step of the practice: if a made-up player is next and ready, they interrupt. If you are next
-- and have not for a while, it is taken for you. Returns who interrupted, or nil.
function ns.TestGroupStep(t, now)
    if now - (t.lastTurn or 0) < TURN then return nil end
    local holders = ns.KickHolders(ns.groupCDRoster, now)
    local order = ns.KickOrder(ns.db.kickOrder, holders)
    local who, left = ns.KickNext(order, holders, ns.kickState.last)
    if not who or (left or 0) > 0 then return nil end
    local id
    if who == t.me then
        t.myTurnSince = t.myTurnSince or now
        if now - t.myTurnSince < MY_WAIT then return nil end
        id = t.myKick
    else
        for _, m in ipairs(ns.TEST_GROUP) do if m.name == who then id = m.kick end end
    end
    if not id then return nil end
    t.myTurnSince = nil
    t.lastTurn = now
    local r = ns.groupCDRoster[who]
    ns.GroupCDUsed(who, r and r.class, id, KickLength(id), now)
    return who
end

-- A small banner while it runs, so made-up group mates are never taken for real ones.
local banner
local function Banner(show, left)
    if not show then if banner then banner:Hide() end return end
    if not banner then
        banner = CreateFrame("Button", nil, UIParent, ns.template)
        banner:SetSize(300, 26)
        banner:SetPoint("TOP", UIParent, "TOP", 0, -90)
        banner:SetFrameStrata("HIGH")
        banner:SetBackdrop(ns.BACKDROP)
        ns:Paint(banner, "SetBackdropColor", "window", 0.92)
        ns:Paint(banner, "SetBackdropBorderColor", "@accent", 1)
        banner.text = ns:NewText(banner, 12, "CENTER")
        banner.text:SetPoint("CENTER")
        banner:SetScript("OnClick", function() ns:ToggleTestGroup(false) end)
    end
    banner.text:SetText(format(ns:Tr("Group practice: %d:%02d left. Click to end."), math.floor(left / 60), math.floor(left % 60)))
    banner:Show()
end
ns.TestGroupBanner = Banner

local ticker
function ns:ToggleTestGroup(on)
    if on == nil then on = not ns.testGroup end
    if on and InCombatLockdown() then ns:Print("Not during a fight."); return false end
    if on and ns.GroupChannel and ns.GroupChannel() then
        ns:Print("You are in a group: the real panels are already showing. Group practice is for when you are on your own.")
        return false
    end
    if on and not ns.testGroup then
        local me = UnitName("player")
        local _, myClass = UnitClass("player")
        local myIDs = ns.MyGroupCDs and ns.MyGroupCDs() or {}
        local t = { started = GetTime(), me = me, myKick = MyKick(myIDs), lastTurn = GetTime() }
        t.names = ns.TestGroupFill(ns.groupCDRoster, GetTime(), me, myClass, myIDs)
        ns.kickState.last = nil
        ns.testGroup = t
        if not ns.previewing and ns.TogglePreview then ns:TogglePreview(); t.startedPreview = ns.previewing end
        if not ticker then
            ticker = true
            ns:Every(1, "Group practice", function()
                local g = ns.testGroup
                if not g then return end
                if GetTime() - g.started > LIMIT then ns:ToggleTestGroup(false); return end
                Banner(true, LIMIT - (GetTime() - g.started))
                ns.TestGroupStep(g, GetTime())
            end)
        end
        local off = {}
        for _, def in ipairs({ { "groupCDs", "Group cooldowns" }, { "kickRotation", "Interrupt rotation" }, { "buffCoverage", "Buff coverage on raid frames" } }) do
            if not ns.db[def[1]] then off[#off + 1] = ns:Tr(def[2]) end
        end
        ns:Print("Group practice on: five made-up group mates for five minutes. |cffffff00/fgui testgroup|r again to end it.")
        if not t.myKick then ns:Print("You have no interrupt the rotation knows, so the others take turns without you.") end
        if #off > 0 then ns:Print("Switched off in the settings, so not shown: %s.", table.concat(off, ", ")) end
        if ns.coverTest then pcall(ns.coverTest.Update) end
        if ns.groupCDTest then pcall(ns.groupCDTest.Update) end
        if ns.kickTest then pcall(ns.kickTest.Update) end
        return true
    elseif not on and ns.testGroup then
        local t = ns.testGroup
        ns.testGroup = nil
        for _, name in ipairs(t.names or {}) do
            local r = ns.groupCDRoster[name]
            if r and r.fake then ns.groupCDRoster[name] = nil end
        end
        ns.kickState.last = nil
        if t.startedPreview and ns.previewing then ns:TogglePreview(true) end
        if ns.coverTest then pcall(ns.coverTest.Update) end
        if ns.groupCDTest then pcall(ns.groupCDTest.Update) end
        if ns.kickTest then pcall(ns.kickTest.Update) end
        Banner(false)
        ns:Print("Group practice off.")
        return false
    end
    return ns.testGroup and true or false
end

do  -- a fight, or joining a real group, ends it
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_DISABLED")
    pcall(ev.RegisterEvent, ev, "GROUP_ROSTER_UPDATE")
    ev:SetScript("OnEvent", ns:Guard("GroupTest events", function(_, event)
        if not ns.testGroup then return end
        if event == "GROUP_ROSTER_UPDATE" and not (ns.GroupChannel and ns.GroupChannel()) then return end
        ns:ToggleTestGroup(false)
    end))
end
