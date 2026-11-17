local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Enemy cooldowns (11.6): the PvP trinket, interrupt and dispel of the players you fight, as small
-- icons beside the arena enemy frames (and, with "Enemy cooldowns on target and focus", under the
-- target and focus frames, for battlegrounds and the open world). Each is seen when the enemy uses
-- it, so an icon appears the first time and then counts down; the trinket is assumed from the start.
-- Only watched inside arenas and battlegrounds, and only when the game says which spell was cast
-- (a spell it hides is skipped).
------------------------------------------------------------------------------------------
ns.ENEMY_CDS = {
    { 42292, "trinket", 120 }, { 59752, "trinket", 120 }, { 7744, "trinket", 120 },     -- PvP trinket, Every Man for Himself, Will of the Forsaken
    { 1766, "kick", 10 }, { 6552, "kick", 10 }, { 72, "kick", 12 }, { 2139, "kick", 24 }, { 15487, "kick", 45 },
    { 8042, "kick", 6 }, { 19647, "kick", 24 }, { 57994, "kick", 12 }, { 47528, "kick", 15 }, { 96231, "kick", 15 },
    { 106839, "kick", 15 }, { 147362, "kick", 24 }, { 116705, "kick", 15 }, { 183752, "kick", 15 },
    { 527, "dispel", 8 }, { 4987, "dispel", 8 }, { 2782, "dispel", 8 }, { 475, "dispel", 8 }, { 51886, "dispel", 8 },
    { 77130, "dispel", 8 }, { 115450, "dispel", 8 }, { 88423, "dispel", 8 },
}
ns.ENEMY_CD_ORDER = { "trinket", "kick", "dispel" }
local TRINKET_ICON = 133452
local byID, byName = {}, {}
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then local ok, n = pcall(C_Spell.GetSpellName, id); if ok and type(n) == "string" and not Secret(n) then return n end end
    return nil
end
local function SpellIcon(id)
    if C_Spell and C_Spell.GetSpellTexture then local ok, t = pcall(C_Spell.GetSpellTexture, id); if ok and t and not Secret(t) then return t end end
    return 134400
end
-- The tracked enemy spell a cast is (by id, or by name so any rank counts), or nil.
function ns.EnemyCDFor(spellID)
    if type(spellID) ~= "number" or Secret(spellID) then return nil end
    if not next(byID) then
        for _, def in ipairs(ns.ENEMY_CDS) do
            byID[def[1]] = def
            local n = SpellName(def[1])
            if n then byName[n] = def end
        end
    end
    if byID[spellID] then return byID[spellID] end
    local n = SpellName(spellID)
    return n and byName[n] or nil
end

-- seen[who] = { trinket = { id, ends }, kick = { id, ends }, dispel = { id, ends } }
local seen = {}
ns.enemyCDs = seen
function ns.EnemyCDUsed(who, spellID, now, length)
    local def = ns.EnemyCDFor(spellID)
    if not def or type(who) ~= "string" then return nil end
    seen[who] = seen[who] or {}
    seen[who][def[2]] = { id = def[1], ends = now + (tonumber(length) or def[3]) }
    return def[2]
end
-- What the icons show for someone: { { kind, icon, left } } in trinket, kick, dispel order.
function ns.EnemyCDLine(who, now, assumeTrinket)
    local out, s = {}, seen[who] or {}
    for _, kind in ipairs(ns.ENEMY_CD_ORDER) do
        local e = s[kind]
        if e then out[#out + 1] = { kind = kind, id = e.id, icon = SpellIcon(e.id), left = math.max(0, e.ends - now), ends = e.ends }
        elseif kind == "trinket" and assumeTrinket then out[#out + 1] = { kind = kind, icon = TRINKET_ICON, left = 0 } end
    end
    return out
end
function ns.EnemyCDReset() for k in pairs(seen) do seen[k] = nil end end

-- who a unit is, for the list: the arena slot for arena enemies, else the name (nil when hidden)
local function Who(unit)
    if type(unit) ~= "string" or Secret(unit) then return nil end
    if unit:match("^arena%d$") then return unit end
    local ok, name = pcall(UnitName, unit)
    if not ok or type(name) ~= "string" or Secret(name) then return nil end
    return name
end
ns.EnemyWho = Who

-- The icons sit on the game's locked (secure) unit frames, so they are never shown or hidden during
-- a fight: they stay shown and are faded in and out instead, which the game allows at any time.
local function Icons(parent, point, rel, x, y)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(3 * 22, 20)
    row:SetPoint(point, parent, rel, x, y)
    row.icons = {}
    for i = 1, 3 do
        local b = CreateFrame("Frame", nil, row)
        b:SetSize(20, 20)
        b:SetPoint("LEFT", (i - 1) * 22, 0)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        ns:AddBorder(b, 0, 0, 0, 1)
        local okC, cd = pcall(CreateFrame, "Cooldown", nil, b, "CooldownFrameTemplate")
        if okC and cd then cd:SetAllPoints(); b.cd = cd end
        b:SetAlpha(0)
        row.icons[i] = b
    end
    row:SetAlpha(0)
    return row
end
local function Draw(row, line, now)
    for i, b in ipairs(row.icons) do
        local l = line[i]
        if l then
            b.tex:SetTexture(l.icon)
            if b.tex.SetDesaturated then b.tex:SetDesaturated(l.left > 0) end
            if b.cd then
                if l.left > 0 and rawget(b, "suiEnds") ~= l.ends then
                    local def = l.id and ns.EnemyCDFor(l.id)
                    local length = def and def[3] or l.left
                    pcall(b.cd.SetCooldown, b.cd, now + l.left - length, length)
                    b.suiEnds = l.ends
                elseif l.left <= 0 and rawget(b, "suiEnds") then
                    pcall(b.cd.Clear, b.cd)
                    b.suiEnds = nil
                end
            end
            b:SetAlpha(1)
        else
            b:SetAlpha(0)
        end
    end
end

ns:NewModule("enemyCDs", function()
    local rows = {}
    local function Rows()
        for i, f in ipairs(ns.arenaFrames or {}) do
            if not rows["arena" .. i] then rows["arena" .. i] = { row = Icons(f, "LEFT", "RIGHT", 6, 0), unit = "arena" .. i, frame = f } end
        end
        do
            for _, def in ipairs({ { "target", _G.FantasyGlassUI_Target }, { "focus", _G.FantasyGlassUI_Focus } }) do
                if type(def[2]) == "table" and def[2].GetObjectType and not rows[def[1]] then
                    rows[def[1]] = { row = Icons(def[2], "TOPLEFT", "BOTTOMLEFT", 0, -22), unit = def[1], frame = def[2] }
                end
            end
        end
        return rows
    end
    local watching, faded = false, false
    local function Update()
        local now = GetTime()
        if not watching and not ns.previewing then             -- (nothing to show outside arenas and battlegrounds)
            if not faded then for _, r in pairs(Rows()) do r.row:SetAlpha(0) end; faded = true end
            return 0
        end
        faded = false
        local n = 0
        for _, r in pairs(Rows()) do
            local isArena = r.unit:match("^arena") ~= nil
            local who
            if ns.previewing and isArena then
                who = "preview"
                if not seen.preview then
                    seen.preview = { kick = { id = 2139, ends = now + 14 }, dispel = { id = 527, ends = now - 1 } }
                end
            elseif isArena or (watching and ns.Yes(UnitExists(r.unit)) and ns.Yes(UnitIsPlayer(r.unit)) and ns.Yes(UnitCanAttack("player", r.unit))) then
                who = Who(r.unit)
            end
            if who and (isArena or seen[who]) and (ns.previewing or ns.Yes(UnitExists(r.unit))) then
                Draw(r.row, ns.EnemyCDLine(who, now, isArena), now)
                r.row:SetAlpha(1)
                n = n + 1
            else
                r.row:SetAlpha(0)
            end
        end
        return n
    end
    ns.arenaTest = { Update = Update, rows = rows }
    ns:Every(0.5, "Enemy cooldowns", Update)

    local ev = CreateFrame("Frame")
    local function Zone()
        local kind
        if IsInInstance then local ok, _, k = pcall(IsInInstance); if ok and not Secret(k) then kind = k end end
        local want = kind == "arena" or kind == "pvp"
        if want ~= watching then
            watching = want
            if want then pcall(ev.RegisterEvent, ev, "UNIT_SPELLCAST_SUCCEEDED") else pcall(ev.UnregisterEvent, ev, "UNIT_SPELLCAST_SUCCEEDED") end
        end
        ns.enemyCDState = watching and ("watching (" .. tostring(kind) .. ")") or "waiting for an arena or battleground"
    end
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ARENA_PREP_OPPONENT_SPECIALIZATIONS" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Enemy cooldowns", function(_, event, unit, _, spellID)
        if event ~= "UNIT_SPELLCAST_SUCCEEDED" then
            if event == "PLAYER_ENTERING_WORLD" then ns.EnemyCDReset() end
            Zone()
            return
        end
        if type(unit) ~= "string" or Secret(unit) then return end
        if not (unit:match("^arena%d$") or unit:match("^nameplate%d+$") or unit == "target" or unit == "focus") then return end
        if not unit:match("^arena") and not (ns.Yes(UnitIsPlayer(unit)) and ns.Yes(UnitCanAttack("player", unit))) then return end
        local who = Who(unit)
        if who and ns.EnemyCDUsed(who, spellID, GetTime()) then Update() end
    end))
    Zone()
    if not ns.EnemyCDFor(42292) then ns.EnemyCDFor(0) end            -- (build the name index while nothing is happening)
end)
