local _, ns = ...

------------------------------------------------------------------------------------------
-- Login briefing (11.11): a few seconds after you log in, one small window says what is waiting:
--   * once-a-day crafts that are ready, on any of your characters;
--   * mail waiting on your other characters;
--   * this character's raid and dungeon lockouts that have reset since you last played it;
--   * this character's rested experience, while it can still level;
--   * the daily and weekly jobs on your checklist that are not done yet;
--   * your weekly recap, when a new one is ready.
-- Click a line to open the window it comes from. Nothing waiting, no briefing; and only once in
-- a quarter of an hour, so a /reload does not bring it back. /fgui briefing shows it at any time.
------------------------------------------------------------------------------------------

-- The lines, from what is known. d = { me, now, alts, profCD, lastSeen, oldLockouts, rested, maxLevel,
-- level, checklist = { done = { daily = { d, t }, weekly = { d, t } } }, recapReady }.
-- Returns { { left, right, open = "what to open" } }.
function ns.BriefingLines(d)
    local lines = {}
    local now = d.now or 0
    -- crafts ready
    if ns.ProfCDLines and type(d.profCD) == "table" then
        for _, l in ipairs(ns.ProfCDLines(d.profCD, now)) do
            if l.left <= 0 then
                lines[#lines + 1] = { left = format(ns:Tr("Ready to craft: %s"), tostring(l.name)), right = tostring(l.char):gsub(" %- .*$", ""), open = "profcd" }
            end
        end
    end
    -- mail on the others
    local mail = {}
    for key, c in pairs(type(d.alts) == "table" and d.alts or {}) do
        if key ~= d.me and type(c) == "table" and c.mail == true and type(c.name) == "string" then mail[#mail + 1] = c.name end
    end
    table.sort(mail)
    if #mail > 0 then lines[#lines + 1] = { left = format(ns:Tr("Mail waiting for %s"), table.concat(mail, ", ")), open = "alts" } end
    -- lockouts that have reset since last time
    local reset, seen = {}, {}
    for _, l in ipairs(type(d.oldLockouts) == "table" and d.oldLockouts or {}) do
        if type(l) == "table" and type(l.name) == "string" and not seen[l.name] and type(l.ends) == "number" and l.ends <= now
            and (not d.lastSeen or l.ends > d.lastSeen) then
            seen[l.name] = true                                  -- (one name, however many difficulties)
            reset[#reset + 1] = l.name
        end
    end
    table.sort(reset)
    if #reset > 0 then lines[#lines + 1] = { left = format(ns:Tr("Reset since you last played: %s"), table.concat(reset, ", ")), open = "lockouts" } end
    -- rested experience
    if type(d.rested) == "number" and d.rested > 0 and (not d.maxLevel or not d.level or d.level < d.maxLevel) then
        lines[#lines + 1] = { left = format(ns:Tr("Rested: %d%% of a level"), d.rested) }
    end
    -- the checklist
    local cl = type(d.checklist) == "table" and d.checklist.done or {}
    for _, period in ipairs({ "daily", "weekly" }) do
        local c = cl[period]
        if type(c) == "table" and (c[2] or 0) > 0 and (c[1] or 0) < c[2] then
            lines[#lines + 1] = { left = format(ns:Tr(period == "daily" and "Daily jobs: %d of %d done" or "Weekly jobs: %d of %d done"), c[1], c[2]), open = "checklist" }
        end
    end
    -- before you set out: gear that needs a repair, bags nearly full
    if type(d.durability) == "number" and d.durability < 30 then
        lines[#lines + 1] = { left = format(ns:Tr("Your gear is at %d%%: time for a repair."), math.floor(d.durability)) }
    end
    if type(d.freeSlots) == "number" and d.freeSlots < 5 then
        lines[#lines + 1] = { left = format(ns:TrN(d.freeSlots, "Only %d bag slot free.", "Only %d bag slots free."), d.freeSlots), open = "bags" }
    end
    if d.recapReady then lines[#lines + 1] = { left = ns:Tr("Your weekly recap is ready."), open = "recap" } end
    return lines
end

local OPEN = {
    profcd = function() if ns.ShowProfCooldowns then ns:ShowProfCooldowns() end end,
    alts = function() if ns.ShowCharacters then ns:ShowCharacters() end end,
    lockouts = function() if ns.ShowLockouts then ns:ShowLockouts() end end,
    checklist = function() if ns.ShowChecklist then ns:ShowChecklist() end end,
    recap = function() if ns.ShowRecap then ns:ShowRecap() end end,
    bags = function() if type(ToggleAllBags) == "function" then ToggleAllBags() elseif type(OpenAllBags) == "function" then OpenAllBags() end end,
}

local snapshot                                                   -- (what was known at login, before it is updated)
local function Gather()
    local root = type(ns.root) == "table" and ns.root or {}
    local me = ns:CharKey()
    local d = { me = me, now = time and time() or 0, alts = root.alts, profCD = root.profCD }
    if snapshot then d.lastSeen, d.oldLockouts = snapshot.lastSeen, snapshot.lockouts end
    local okL, level = pcall(UnitLevel, "player")
    if okL and type(level) == "number" and not ns:IsSecret(level) then d.level = level end
    if type(GetMaxPlayerLevel) == "function" then local ok, m = pcall(GetMaxPlayerLevel); if ok and type(m) == "number" then d.maxLevel = m end end
    local okR, rested = pcall(GetXPExhaustion)
    local okM, max = pcall(UnitXPMax, "player")
    if okR and okM and type(rested) == "number" and type(max) == "number" and not ns:IsSecret(rested) and not ns:IsSecret(max) and max > 0 then
        d.rested = math.floor(rested / max * 100 + 0.5)
    end
    if ns.ChecklistStore and ns.ChecklistCount and ns.ChecklistStamps then
        local store = ns.ChecklistStore()
        local stamps = ns.ChecklistStamps()
        d.checklist = { done = {} }
        for _, period in ipairs({ "daily", "weekly" }) do
            local done, total = ns.ChecklistCount(store, me, period, stamps)
            d.checklist.done[period] = { done, total }
        end
    end
    d.recapReady = ns.RecapReady and ns:RecapReady() or false
    if ns.LowestDurability and type(GetInventoryItemDurability) == "function" then
        local ok, v = pcall(ns.LowestDurability, ns)
        if ok and type(v) == "number" and not ns:IsSecret(v) then d.durability = v end
    end
    local C = C_Container or _G
    if C.GetContainerNumFreeSlots then
        local free, any = 0, false
        for bag = 0, 4 do
            local ok, f, kind = pcall(C.GetContainerNumFreeSlots, bag)
            if ok and type(f) == "number" and not ns:IsSecret(f) and (kind == nil or kind == 0) then free = free + f; any = true end
        end
        if any then d.freeSlots = free end
    end
    return d
end

function ns:ShowBriefing(quietIfEmpty)
    local lines = ns.BriefingLines(Gather())
    if #lines == 0 then
        if quietIfEmpty then return 0 end
        lines[1] = { left = ns:Tr("Nothing is waiting for you.") }
    end
    for _, l in ipairs(lines) do
        if l.open and OPEN[l.open] then
            local open = OPEN[l.open]
            l.click = function() pcall(open) end
            l.left = l.left .. "  |cff9aa4b4>|r"
        end
    end
    local name = UnitName and UnitName("player")
    local title = (type(name) == "string" and not ns:IsSecret(name)) and format(ns:Tr("Welcome back, %s"), name) or ns:Tr("Welcome back")
    ns:ShowList("Briefing", title, lines, "Click a line to open it. /fgui briefing shows this again; Quests and map › Progress can turn it off.", 460, math.min(360, 80 + #lines * 18))
    return #lines
end

ns:NewModule("loginBriefing", function()
    -- before the lockouts and this character's record are brought up to date
    local root = type(ns.root) == "table" and ns.root or {}
    local mine = type(root.alts) == "table" and root.alts[ns:CharKey()]
    snapshot = { lastSeen = type(mine) == "table" and tonumber(mine.at) or nil, lockouts = {} }
    for _, l in ipairs(type(mine) == "table" and type(mine.lockouts) == "table" and mine.lockouts or {}) do
        snapshot.lockouts[#snapshot.lockouts + 1] = { name = l.name, ends = l.ends }
    end
    local tries = 0
    local function Busy()                                       -- (What's new, the splash or the setup is up: after them)
        for _, name in ipairs({ "FantasyGlassUIText", "FantasyGlassUISplash", "FantasyGlassUISetup" }) do
            local f = _G[name]
            if type(f) == "table" and f.IsShown and f:IsShown() then return true end
        end
        return false
    end
    local function Brief()
        if InCombatLockdown() or ns.moving or Busy() then    -- (in a fight, moving frames or reading: a little later)
            tries = tries + 1
            if tries < 60 then ns:After(5, Brief) end
            return
        end
        root = type(ns.root) == "table" and ns.root or {}
        local t = time and time() or 0
        root.briefedAt = type(root.briefedAt) == "table" and root.briefedAt or {}
        local me = ns:CharKey()
        if (tonumber(root.briefedAt[me]) or 0) > t - 900 then return end
        root.briefedAt[me] = t
        pcall(ns.ShowBriefing, ns, true)
    end
    ns:After(7, Brief)                                          -- (after What's new, and once the game has settled)
    -- a fight starting puts the briefing away
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_DISABLED")
    ev:SetScript("OnEvent", ns:Guard("Login briefing", function()
        local w = _G.FantasyGlassUIListBriefing
        if w and w.IsShown and w:IsShown() then w:Hide() end
    end))
end)
