local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Player tooltips (11.10): every line of a player's tooltip is your choice. The game's own lines
-- (title and realm in the name, the guild, the level line, the faction, "PvP", the health bar) can
-- each be hidden; the add-on's lines (who they are targeting, their guild rank, your note on them)
-- can each be turned off; and there are new ones to turn on: their role in your group, whether they
-- are your friend or in your guild, and their health in numbers. Player tooltips can also be put
-- away during fights (hold Shift to see one anyway).
--
-- The game cannot take a line out of a tooltip, so when one of its lines is hidden the tooltip is
-- written again without it. Anything the game keeps hidden from add-ons is left exactly as it is.
------------------------------------------------------------------------------------------

-- The switches, in the order the options list them (also used by the tests).
ns.PLAYER_TIP_LINES = {
    { "tipTitle",     "Player tooltips: title in the name" },
    { "tipRealm",     "Player tooltips: realm in the name" },
    { "tipGuild",     "Player tooltips: guild" },
    { "tipGuildRank", "Player tooltips: guild rank" },
    { "tipLevel",     "Player tooltips: level, race and class" },
    { "tipFaction",   "Player tooltips: faction" },
    { "tipPvP",       "Player tooltips: PvP" },
    { "tipHealthBar", "Player tooltips: health bar" },
    { "tipTarget",    "Player tooltips: who they target" },
    { "tipRole",      "Player tooltips: role in your group" },
    { "tipFriend",    "Player tooltips: friend or guild mate" },
    { "tipHealth",    "Player tooltips: health in numbers" },
    { "tipCombatHide", "Player tooltips: hide during fights" },
}

-- Which of the game's lines to drop, and what the first line should say.
-- lines: the tooltip's left texts (nil where the game keeps one hidden); info: what is known of the
-- player ({ name, realm, pvpName, guild, faction, class, level }); db: the switches.
-- Returns drop (a set of line numbers) and the new first line, or nil to leave it.
function ns.PlayerTipPlan(lines, info, db)
    local drop = {}
    for i = 2, (lines.n or #lines) do                             -- (n: the count, when some lines are hidden)
        local t = lines[i]
        if type(t) == "string" and t ~= "" then
            if not db.tipGuild and i == 2 and type(info.guild) == "string" and info.guild ~= "" and t:find(info.guild, 1, true) then
                drop[i] = true
            elseif not db.tipPvP and type(info.pvp) == "string" and t == info.pvp then
                drop[i] = true
            elseif not db.tipFaction and type(info.faction) == "string" and info.faction ~= "" and t == info.faction then
                drop[i] = true
            elseif not db.tipLevel and type(info.levelWord) == "string" and info.level and t:find(info.levelWord, 1, true)
                and t:find(tostring(info.level), 1, true) then
                drop[i] = true                                          -- "Level 16 Dwarf (Player)", with or without the class
            elseif not db.tipLevel and type(info.class) == "string" and info.class ~= "" and t == info.class then
                drop[i] = true                                          -- (some clients put the class on a line of its own)
            end
        end
    end
    local first
    local line1 = lines[1]
    if type(line1) == "string" and type(info.name) == "string" and info.name ~= "" and (not db.tipTitle or not db.tipRealm) then
        local tag = line1:match("(%s*<[^>]+>)%s*$") or ""                      -- (<Away> and the like stay)
        local name = (db.tipTitle and type(info.pvpName) == "string" and info.pvpName ~= "") and info.pvpName or info.name
        local realm = (db.tipRealm and type(info.realm) == "string" and info.realm ~= "") and ("-" .. info.realm) or ""
        first = name .. realm .. tag
        if first == line1 then first = nil end
    end
    return drop, first
end

-- Health in numbers: "12,345 / 20,000 (62%)".
function ns.PlayerTipHealth(cur, max)
    if type(cur) ~= "number" or type(max) ~= "number" or max <= 0 then return nil end
    local function N(v) return (type(BreakUpLargeNumbers) == "function" and BreakUpLargeNumbers(v)) or tostring(v) end
    return format("%s / %s (%d%%)", N(cur), N(max), math.floor(cur / max * 100 + 0.5))
end

ns:NewModule("playerTips", function()
    local function Safe(fn, ...) local ok, a, b, c = pcall(fn, ...); if ok then return a, b, c end end
    local function Clean(v) if v ~= nil and not Secret(v) then return v end end

    -- the tooltip's lines as they are now: { left, right, colors }
    local function ReadLines(tip)
        local base = tip.GetName and tip:GetName()
        if type(base) ~= "string" then return nil end
        local out = {}
        for i = 1, (tonumber(tip:NumLines()) or 0) do
            local L, R = _G[base .. "TextLeft" .. i], _G[base .. "TextRight" .. i]
            local lt = type(L) == "table" and L.GetText and L:GetText()
            if Secret(lt) then return nil end                        -- (something the game keeps to itself: leave it all)
            local rt = type(R) == "table" and R.IsShown and R:IsShown() and R.GetText and R:GetText() or nil
            if Secret(rt) then return nil end
            local lr, lg, lb = 1, 1, 1
            if L and L.GetTextColor then lr, lg, lb = L:GetTextColor() end
            local rr, rg, rb = 1, 1, 1
            if R and R.GetTextColor then rr, rg, rb = R:GetTextColor() end
            out[i] = { left = lt, right = rt, lc = { lr, lg, lb }, rc = { rr, rg, rb } }
        end
        return out
    end
    local function Rewrite(tip, rows, drop, first)
        tip:ClearLines()
        for i, row in ipairs(rows) do
            if not drop[i] then
                local left = (i == 1 and first) or row.left or " "
                if row.right and row.right ~= "" then
                    tip:AddDoubleLine(left, row.right, row.lc[1], row.lc[2], row.lc[3], row.rc[1], row.rc[2], row.rc[3])
                else
                    tip:AddLine(left, row.lc[1], row.lc[2], row.lc[3], i > 1 and #tostring(left) > 48)
                end
            end
        end
        tip:Show()
    end

    local function OnUnit(tip)
        if tip ~= GameTooltip or not tip.GetUnit then return end
        local _, unit = tip:GetUnit()
        if not unit or Secret(unit) then return end
        local isPlayer = Safe(UnitIsPlayer, unit)
        if not ns.Is(isPlayer, true) then return end
        local db = ns.db
        if db.tipCombatHide and InCombatLockdown() and not (IsShiftKeyDown and IsShiftKeyDown()) then tip:Hide(); return end

        -- the game's lines
        local info = {}
        local name, realm = Safe(UnitName, unit)
        info.name, info.realm = Clean(name), Clean(realm)
        info.pvpName = Clean(type(UnitPVPName) == "function" and Safe(UnitPVPName, unit) or nil)
        info.guild = Clean(type(GetGuildInfo) == "function" and Safe(GetGuildInfo, unit) or nil)
        local _, factionName = Safe(UnitFactionGroup, unit)
        info.faction = Clean(factionName)
        info.class = Clean((Safe(UnitClass, unit)))
        info.level = Clean(Safe(UnitLevel, unit))
        info.levelWord = type(LEVEL) == "string" and LEVEL or "Level"
        info.pvp = type(PVP) == "string" and PVP or "PvP"
        local rows = ReadLines(tip)
        if rows then
            local texts = {}
            for i, row in ipairs(rows) do texts[i] = row.left end
            local drop, first = ns.PlayerTipPlan(texts, info, db)
            if next(drop) then
                Rewrite(tip, rows, drop, first)
            elseif first then
                local L = _G[tip:GetName() .. "TextLeft1"]
                if L and L.SetText then L:SetText(first) end
            end
        end
        local bar = _G.GameTooltipStatusBar
        if type(bar) == "table" and bar.Hide and not db.tipHealthBar then bar:Hide() end

        -- the add-on's new lines
        local added = false
        if db.tipRole and IsInGroup and IsInGroup() and type(UnitGroupRolesAssigned) == "function" then
            local role = Clean(Safe(UnitGroupRolesAssigned, unit))
            local word = role == "TANK" and (TANK or "Tank") or role == "HEALER" and (HEALER or "Healer") or role == "DAMAGER" and (DAMAGER or "Damage") or nil
            if word then tip:AddLine(ns:Tr("Role:") .. " " .. word, 0.72, 0.74, 0.80); added = true end
        end
        if db.tipFriend then
            local guid = Clean(Safe(UnitGUID, unit))
            local friend = guid and C_FriendList and C_FriendList.IsFriend and Clean(Safe(C_FriendList.IsFriend, guid))
            local mate = type(UnitIsInMyGuild) == "function" and Clean(Safe(UnitIsInMyGuild, unit))
            local me = ns.Is(Safe(UnitIsUnit, unit, "player"), true)
            if not me and friend == true then tip:AddLine(ns:Tr("Your friend"), 0.4, 0.85, 1); added = true
            elseif not me and mate == true then tip:AddLine(ns:Tr("In your guild"), 0.25, 1, 0.25); added = true end
        end
        if db.tipHealth then
            local text = ns.PlayerTipHealth(Clean(Safe(UnitHealth, unit)), Clean(Safe(UnitHealthMax, unit)))
            if text then tip:AddDoubleLine(ns:Tr("Health"), text, 0.72, 0.74, 0.80, 1, 1, 1); added = true end
        end
        if added then tip:Show() end
    end
    ns.PlayerTipTest = { OnUnit = OnUnit, ReadLines = ReadLines }
    local safe = ns:Guard("Player tooltips", OnUnit)
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
        pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Unit, safe)
    elseif GameTooltip and GameTooltip.HookScript then
        pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", safe)
    end
end)
