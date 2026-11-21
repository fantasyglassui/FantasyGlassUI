local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Profession leveling helper (11.11): with a profession window open, "Skill-ups" (or /fgui skillups)
-- lists the recipes you know that still give skill points, best first:
--   * what you can make right now, with what is in your bags and bank;
--   * then what needs the fewest materials still, counting what your other characters hold;
--   * orange (a point every time) before yellow (usually) before green (sometimes).
-- Each line says how many you can make, or what is missing and whether another character has it.
-- Click one to bring it up in the profession window. Gray recipes give nothing more and are left out.
------------------------------------------------------------------------------------------
local ORANGE, YELLOW, GREEN, GRAY = 0, 1, 2, 3                      -- (the game's Enum.TradeskillRelativeDifficulty)
local CHANCE = { [ORANGE] = 3, [YELLOW] = 2, [GREEN] = 1 }
local COLOR = { [ORANGE] = "|cffff8040", [YELLOW] = "|cffffff00", [GREEN] = "|cff40c040", [GRAY] = "|cff808080" }
ns.SKILLUP_COLOR = COLOR

-- recipes: { { id, name, difficulty, skillUps, reagents = { { id, need } } } }; have(itemID) -> on you, on your others.
-- Returns the ones that still give points, best first, each with makeNow, short = { { id, missing, others } }, missing.
function ns.SkillUpPlan(recipes, have)
    local out = {}
    for _, r in ipairs(recipes or {}) do
        if CHANCE[r.difficulty] then
            local makeNow, missing, short = math.huge, 0, {}
            for _, g in ipairs(r.reagents or {}) do
                local mine, others = have(g.id)
                mine, others = tonumber(mine) or 0, tonumber(others) or 0
                makeNow = math.min(makeNow, math.floor(mine / math.max(1, g.need)))
                if mine < g.need then
                    local m = g.need - mine
                    missing = missing + m
                    short[#short + 1] = { id = g.id, missing = m, others = others }
                end
            end
            local free = makeNow == math.huge                    -- (no materials at all)
            if free then makeNow = 1 end
            out[#out + 1] = { id = r.id, name = r.name, difficulty = r.difficulty, skillUps = r.skillUps or 1,
                makeNow = makeNow, missing = missing, short = short, free = free }
        end
    end
    table.sort(out, function(a, b)
        if (a.makeNow > 0) ~= (b.makeNow > 0) then return a.makeNow > 0 end
        if a.missing ~= b.missing then return a.missing < b.missing end
        if a.difficulty ~= b.difficulty then return a.difficulty < b.difficulty end
        if a.skillUps ~= b.skillUps then return a.skillUps > b.skillUps end
        return tostring(a.name) < tostring(b.name)
    end)
    return out
end


-- The known recipes of the open profession, with their difficulty and materials.
local function KnownRecipes()
    local T = C_TradeSkillUI
    if not (T and T.GetAllRecipeIDs and T.GetRecipeInfo) then return nil end
    local okI, ids = pcall(T.GetAllRecipeIDs)
    if not okI or type(ids) ~= "table" or #ids == 0 then return nil end
    local list = {}
    for _, id in ipairs(ids) do
        local ok, info = pcall(T.GetRecipeInfo, id)
        if ok and type(info) == "table" and info.learned and type(info.name) == "string" and not Secret(info.name) then
            local diff = info.relativeDifficulty
            if type(diff) == "number" and not Secret(diff) then
                local reagents = {}
                if T.GetRecipeSchematic then
                    local okS, sch = pcall(T.GetRecipeSchematic, id, false)
                    for _, slot in ipairs(okS and type(sch) == "table" and type(sch.reagentSlotSchematics) == "table" and sch.reagentSlotSchematics or {}) do
                        local first = type(slot.reagents) == "table" and slot.reagents[1]
                        local basic = slot.reagentType == nil or slot.reagentType == 1 or ns.Is(slot.required, true)
                        if type(first) == "table" and type(first.itemID) == "number" and basic and (tonumber(slot.quantityRequired) or 0) > 0 then
                            reagents[#reagents + 1] = { id = first.itemID, need = slot.quantityRequired }
                        end
                    end
                end
                list[#list + 1] = { id = id, name = info.name, difficulty = diff, skillUps = tonumber(info.numSkillUps) or 1, reagents = reagents }
            end
        end
    end
    return list
end
local function Have(id)
    local mine = 0
    local GetCount = C_Item.GetItemCount
    if type(GetCount) == "function" then
        local ok, n = pcall(GetCount, id, true)                     -- (bags and bank)
        if ok and type(n) == "number" and not Secret(n) then mine = n end
    end
    local others = 0
    if ns.ItemOwners then
        local ok, owners, me = pcall(ns.ItemOwners, ns, id)
        for owner, o in pairs(ok and type(owners) == "table" and owners or {}) do
            if owner ~= me and type(o) == "table" then others = others + (o.bags or 0) + (o.bank or 0) end
        end
    end
    return mine, others
end
local function ItemName(id)
    local name = select(1, ns:GetItemInfo(id))
    return (type(name) == "string" and not Secret(name)) and name or (ns:Tr("Item") .. " " .. id)
end

-- The open profession and its skill, where the game says: "Tailoring 125/150".
local function SkillLine()
    local T = C_TradeSkillUI
    for _, getter in ipairs({ T and T.GetChildProfessionInfo, T and T.GetBaseProfessionInfo }) do
        if type(getter) == "function" then
            local ok, p = pcall(getter)
            if ok and type(p) == "table" and type(p.professionName) == "string" and p.professionName ~= "" and not Secret(p.professionName)
                and type(p.skillLevel) == "number" and type(p.maxSkillLevel) == "number" and p.maxSkillLevel > 0 then
                return format("%s %d/%d", p.professionName, p.skillLevel, p.maxSkillLevel)
            end
        end
    end
    return nil
end
ns.SkillUpLine = SkillLine

local shown
function ns:ShowSkillUps(quiet)
    local recipes = KnownRecipes()
    if not recipes then if not quiet then ns:Print("Open a profession window first.") end; return 0 end
    local plan = ns.SkillUpPlan(recipes, Have)
    local lines = {}
    for i, p in ipairs(plan) do
        if i > 25 then
            lines[#lines + 1] = { left = "|cff9aa4b4" .. format(ns:Tr("and %d more"), #plan - 25) .. "|r" }
            break
        end
        local right
        if p.free then
            right = ns:SignalHex("good") .. ns:Tr("no materials needed") .. "|r"
        elseif p.makeNow > 0 then
            right = ns:SignalHex("good") .. format(ns:Tr("can make %d now"), p.makeNow) .. "|r"
        else
            local parts = {}
            for _, s in ipairs(p.short) do
                local where = ""
                if s.others >= s.missing then where = " |cff9aa4b4(" .. ns:Tr("on another character") .. ")|r"
                elseif s.others > 0 then where = " |cff9aa4b4(" .. format(ns:Tr("%d on your other characters"), s.others) .. ")|r" end
                parts[#parts + 1] = format("%d %s", s.missing, ItemName(s.id)) .. where
            end
            right = "|cffff8080" .. ns:Tr("needs") .. "|r " .. table.concat(parts, ", ")
        end
        local tip = { p.name, ns:Tr(p.difficulty == ORANGE and "Orange: a skill point every time." or p.difficulty == YELLOW and "Yellow: usually a skill point."
            or "Green: sometimes a skill point.") }
        if p.skillUps > 1 then tip[#tip + 1] = format(ns:Tr("%d skill points each time."), p.skillUps) end
        tip[#tip + 1] = ns:Tr("Click to bring it up in the profession window.")
        lines[#lines + 1] = {
            left = (COLOR[p.difficulty] or "") .. p.name .. "|r" .. (p.skillUps > 1 and (" |cffffd100+" .. p.skillUps .. "|r") or ""),
            right = right,
            click = function()
                local T = C_TradeSkillUI
                if T and T.OpenRecipe then pcall(T.OpenRecipe, p.id)
                elseif T and T.SetRecipeItemNameFilter then pcall(T.SetRecipeItemNameFilter, p.name) end
            end,
            tip = tip,
        }
    end
    if #lines == 0 then lines[1] = { left = ns:Tr("Nothing you know gives skill points any more: time to learn new recipes from a trainer.") } end
    local line = SkillLine()
    shown = ns:ShowList("SkillUps", line and (ns:Tr("Skill-ups") .. ": " .. line) or "Skill-ups", lines,
        "Recipes that still give skill points, best first: what you can make now, then what needs the least. Click one to bring it up.", 620, math.min(440, 80 + #lines * 18))
    return #plan
end

ns:NewModule("skillUps", function()
    local done = {}
    local function Dress()
        for _, name in ipairs({ "ProfessionsFrame", "TradeSkillFrame" }) do
            local f = _G[name]
            if type(f) == "table" and not done[f] and f.CreateFontString then
                done[f] = true
                local b = ns:CreateButton(f, "Skill-ups", 90, 20, function() ns:ShowSkillUps() end)
                b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -60, -28)
                b:SetFrameLevel((f:GetFrameLevel() or 1) + 10)
                ns:ButtonTip(b, "Recipes that still give skill points, best first, with what each needs.")
            end
        end
    end
    ns.skillUpTest = { Dress = Dress }
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "TRADE_SKILL_SHOW", "ADDON_LOADED", "TRADE_SKILL_CLOSE", "BAG_UPDATE_DELAYED", "SKILL_LINES_CHANGED", "TRADE_SKILL_LIST_UPDATE" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    local pending
    ev:SetScript("OnEvent", ns:Guard("Skill-ups", function(_, event)
        if event == "TRADE_SKILL_SHOW" or event == "ADDON_LOADED" then pcall(Dress); return end
        if not (shown and shown.IsShown and shown:IsShown()) then return end
        if event == "TRADE_SKILL_CLOSE" then shown:Hide(); return end
        -- something was made, bought or learned: the list again, once things settle
        if pending then return end
        pending = true
        ns:After(0.5, function() pending = nil; if shown:IsShown() then pcall(ns.ShowSkillUps, ns, true) end end)
    end))
end)
