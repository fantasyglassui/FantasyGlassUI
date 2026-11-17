local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- The crafting bar.
--
-- While you craft, the game shows a progress bar of its own in the profession window, in its own
-- look and - on this client - with a placeholder picture where an icon should be. With this switch:
--   * that bar is replaced, in the same place, by one in our style;
--   * its icon is the profession's own (leatherworking, alchemy, cooking...), and so is the icon on
--     our ordinary cast bar while you craft.
-- The game's bar is found when a craft starts: by its usual name, or else by its shape (a status
-- bar with an icon and a label) inside the profession window or directly on the screen.
------------------------------------------------------------------------------------------

-- Icons by the profession's skill-line number, which is the same in every language.
local I = "Interface\\Icons\\"
local BY_LINE = {
    [129] = I .. "Spell_Holy_SealOfSacrifice",   -- First Aid
    [164] = I .. "Trade_BlackSmithing",
    [165] = I .. "Trade_LeatherWorking",
    [171] = I .. "Trade_Alchemy",
    [182] = I .. "Trade_Herbalism",
    [185] = I .. "INV_Misc_Food_15",             -- Cooking
    [186] = I .. "Trade_Mining",
    [197] = I .. "Trade_Tailoring",
    [202] = I .. "Trade_Engineering",
    [333] = I .. "Trade_Engraving",              -- Enchanting
    [356] = I .. "Trade_Fishing",
    [393] = I .. "INV_Misc_Pelt_Wolf_01",        -- Skinning
    [755] = I .. "INV_Misc_Gem_01",              -- Jewelcrafting
    [773] = I .. "INV_Inscription_Tradeskill01",
    [794] = I .. "Trade_Archaeology",
}
-- ...and by the game's own name for it in its list of professions, where that list exists.
local BY_ENUM = {
    FirstAid = 129, Blacksmithing = 164, Leatherworking = 165, Alchemy = 171, Herbalism = 182, Cooking = 185, Mining = 186,
    Tailoring = 197, Engineering = 202, Enchanting = 333, Fishing = 356, Skinning = 393, Jewelcrafting = 755, Inscription = 773,
    Archaeology = 794,
}
ns.professionIcons = BY_LINE

-- English names, for clients that give a profession's name and no number. (In another language the
-- name is matched against your own list of professions instead, which carries the icons.)
local BY_NAME = {
    ["first aid"] = 129, blacksmithing = 164, leatherworking = 165, alchemy = 171, herbalism = 182, cooking = 185, mining = 186,
    smelting = 186, tailoring = 197, engineering = 202, enchanting = 333, fishing = 356, skinning = 393, jewelcrafting = 755,
    inscription = 773, archaeology = 794,
}
local function plain(v) if Secret(v) then return nil end return v end

-- Is this skill line a profession? Every spell belongs to a skill line (a mage's fire spells to "Fire",
-- say), and the game answers "which line is this recipe in" for any spell at all, so the answer has
-- to be checked against the lines that are professions: the ones in the table above, and whatever
-- the game itself lists.
local professionLines
local function IsProfessionLine(id)
    if type(id) ~= "number" then return false end
    if BY_LINE[id] then return true end
    if not professionLines then
        professionLines = {}
        local T = C_TradeSkillUI
        if type(T) == "table" and type(T.GetAllProfessionTradeSkillLines) == "function" then
            local ok, list = pcall(T.GetAllProfessionTradeSkillLines)
            for _, line in ipairs((ok and type(list) == "table") and list or {}) do
                if type(line) == "number" and not Secret(line) then professionLines[line] = true end
            end
        end
    end
    return professionLines[id] == true
end
local function IsProfession(prof)
    return type(prof) == "table" and (IsProfessionLine(prof.line) or IsProfessionLine(prof.parent) or prof.kind ~= nil)
end
ns.IsProfessionLine = IsProfessionLine
local function known(prof) return type(prof) == "table" and ((type(prof.line) == "number" and prof.line > 0) or (type(prof.name) == "string" and prof.name ~= "")) end

-- The profession a craft belongs to: { line, parent, kind, name, via }, or nil. Asked several ways,
-- because game clients differ: by the recipe being made, then by the profession window that is open.
function ns:CraftProfession(spellID)
    local T = C_TradeSkillUI
    local function try(via, fn, ...)
        if type(fn) ~= "function" then return nil end
        local r = { pcall(fn, ...) }
        if not r[1] then return nil end
        local prof
        if type(r[2]) == "table" then
            local info = r[2]
            prof = { line = plain(info.professionID), parent = plain(info.parentProfessionID), kind = plain(info.profession), name = plain(info.professionName) }
        elseif via == "GetTradeSkillLineForRecipe" then
            prof = { line = plain(r[2]), name = plain(r[3]), parent = plain(r[4]) }
        elseif via == "C_TradeSkillUI.GetTradeSkillLine" then
            prof = { line = plain(r[2]), name = plain(r[3]), parent = plain(r[7]) }
        else
            prof = { name = plain(r[2]) }
        end
        if type(prof.name) ~= "string" or prof.name == "UNKNOWN" then prof.name = nil end
        if type(prof.line) ~= "number" then prof.line = nil end
        if type(prof.parent) ~= "number" or prof.parent == 0 then prof.parent = nil end
        if not known(prof) then return nil end
        prof.via = via
        return prof
    end
    if type(T) == "table" then
        if spellID ~= nil and not Secret(spellID) then
            local prof = try("GetProfessionInfoByRecipeID", T.GetProfessionInfoByRecipeID, spellID)
            if not IsProfession(prof) then prof = try("GetTradeSkillLineForRecipe", T.GetTradeSkillLineForRecipe, spellID) end
            if IsProfession(prof) then return prof end           -- (an ordinary spell has a line too, but not a profession's)
        end
        local prof = try("GetChildProfessionInfo", T.GetChildProfessionInfo) or try("GetBaseProfessionInfo", T.GetBaseProfessionInfo)
                  or try("C_TradeSkillUI.GetTradeSkillLine", T.GetTradeSkillLine)
        if prof then return prof end
    end
    return try("GetTradeSkillLine", GetTradeSkillLine)
end
ns.OpenProfession = function(self) return ns:CraftProfession(nil) end

-- The icon for a profession. In order: what the game itself says, the icon in your own list of
-- professions, then the table above. Second result: where it came from (for the self-check).
function ns:ProfessionIcon(prof)
    prof = prof or ns:CraftProfession(nil)
    if type(prof) ~= "table" then return nil end
    local T = C_TradeSkillUI
    if type(T) == "table" and type(T.GetTradeSkillTexture) == "function" then
        for _, id in ipairs({ prof.parent or false, prof.line or false }) do
            if id then
                local ok, tex = pcall(T.GetTradeSkillTexture, id)
                if ok and tex ~= nil and not Secret(tex) and tex ~= 0 and tex ~= "" then return tex, "the game's icon for the profession" end
            end
        end
    end
    if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
        local list = { pcall(GetProfessions) }
        for i = 2, 8 do
            local index = list[i]
            if type(index) == "number" then
                local ok, name, icon, _, _, _, _, line = pcall(GetProfessionInfo, index)
                if ok and icon ~= nil and not Secret(icon) and not Secret(name) and not Secret(line) then
                    if (line ~= nil and (line == prof.line or line == prof.parent)) or (name ~= nil and name == prof.name) then
                        return icon, "your list of professions"
                    end
                end
            end
        end
    end
    for _, id in ipairs({ prof.parent or false, prof.line or false }) do
        if id and BY_LINE[id] then return BY_LINE[id], "the add-on's own table" end
    end
    if prof.kind ~= nil and type(Enum) == "table" and type(Enum.Profession) == "table" then
        for label, line in pairs(BY_ENUM) do
            if Enum.Profession[label] ~= nil and Enum.Profession[label] == prof.kind then return BY_LINE[line], "the add-on's own table" end
        end
    end
    if type(prof.name) == "string" then
        local lower = prof.name:lower()
        for label, line in pairs(BY_NAME) do
            if lower:find(label, 1, true) then return BY_LINE[line], "the add-on's own table, by name" end
        end
    end
    return nil
end

-- Is a profession window on screen?
local function ProfessionWindowOpen()
    for _, name in ipairs({ "ProfessionsFrame", "TradeSkillFrame", "CraftFrame" }) do
        local win = _G[name]
        if type(win) == "table" and ns:Usable(win) and win.IsVisible then
            local ok, v = pcall(win.IsVisible, win)
            if ok and v then return name end
        end
    end
    return nil
end

-- Is this cast a craft? Second result: how that is known. Asked three ways, most certain first: the
-- game says so; the spell belongs to a profession's skill line; or the game does not say either way
-- and a profession window is open.
function ns:IsCraft(isTradeSkill, spellID)
    if ns.Is(isTradeSkill, true) then return true, "the game marks the cast as a craft" end
    local T = C_TradeSkillUI
    if spellID ~= nil and not Secret(spellID) and type(T) == "table" then
        local function line(fn, ...)
            if type(fn) ~= "function" then return nil end
            local r = { pcall(fn, ...) }
            if not r[1] then return nil end
            if type(r[2]) == "table" then return { line = plain(r[2].professionID), parent = plain(r[2].parentProfessionID), kind = plain(r[2].profession) } end
            return { line = plain(r[2]), parent = plain(r[4]) }
        end
        if IsProfession(line(T.GetProfessionInfoByRecipeID, spellID)) or IsProfession(line(T.GetTradeSkillLineForRecipe, spellID)) then
            return true, "the spell belongs to a profession"
        end
    end
    if isTradeSkill == nil and not Secret(isTradeSkill) then
        local win = ProfessionWindowOpen()
        if win then return true, "the game does not say, and " .. win .. " is open" end
    end
    return false
end

-- The icon a cast should show: the profession's while crafting, otherwise the cast's own.
function ns:CraftIcon(isTradeSkill, texture, spellID)
    if not (ns.db and ns.db.craftBar) then return texture end
    local craft = ns:IsCraft(isTradeSkill, spellID)
    if not craft then return texture end
    local icon, from = ns:ProfessionIcon(ns:CraftProfession(spellID))
    if not icon then                                       -- no profession to be found: the recipe's own picture, if it has one
        local T = C_TradeSkillUI
        if spellID ~= nil and not Secret(spellID) and type(T) == "table" and type(T.GetRecipeInfo) == "function" then
            local ok, info = pcall(T.GetRecipeInfo, spellID)
            if ok and type(info) == "table" and info.icon ~= nil and not Secret(info.icon) then icon, from = info.icon, "the recipe's own icon" end
        end
    end
    if icon then ns.craftIconFrom = from end
    return icon or texture
end

-- What the last craft looked like to the add-on, in words, for the self-check: this is how a fault
-- in any of the above is found without guessing.
local function say(v)
    if Secret(v) then return "hidden" end
    if type(v) == "string" then return "\"" .. v .. "\"" end
    return tostring(v)
end
function ns:CraftFacts()
    local r = { UnitCastingInfo("player") }
    local n = select("#", UnitCastingInfo("player"))
    local spell, texture, isTradeSkill, spellID = r[1], r[3], r[6], r[9]
    local win = ProfessionWindowOpen()
    local craft, why = ns:IsCraft(isTradeSkill, spellID)
    if not craft and not win then return nil end           -- an ordinary spell, nowhere near a profession: not recorded
    local lines = {}
    lines[#lines + 1] = "cast " .. say(spell) .. ": the game gave " .. n .. " details; picture " .. say(texture) .. ", craft flag " .. say(isTradeSkill) .. ", spell number " .. say(spellID)
    lines[#lines + 1] = "taken as a craft: " .. (craft and ("yes (" .. tostring(why) .. ")") or "no") .. "; profession window: " .. tostring(win or "none open")
    local prof = ns:CraftProfession(spellID)
    if prof then
        lines[#lines + 1] = "profession: number " .. say(prof.line) .. ", parent " .. say(prof.parent) .. ", kind " .. say(prof.kind) .. ", name " .. say(prof.name) .. " (from " .. tostring(prof.via) .. ")"
        local icon, from = ns:ProfessionIcon(prof)
        lines[#lines + 1] = "icon: " .. say(icon) .. (from and (" (from " .. from .. ")") or " (none found)")
    else
        lines[#lines + 1] = "profession: could not be told"
    end
    -- which bars were on screen: ours, and anything of the game's shaped like a cast bar
    local ours = {}
    for label, f in pairs({ ["our cast bar"] = ns.castBarFrame, ["our crafting bar"] = ns.craftTest and ns.craftTest.bar }) do
        if type(f) == "table" and f.IsVisible then
            local ok, v = pcall(f.IsVisible, f)
            ours[#ours + 1] = label .. (ok and v and " showing" or " not showing")
        end
    end
    table.sort(ours)
    lines[#lines + 1] = table.concat(ours, "; ")
    local overlay = _G.OverlayPlayerCastingBarFrame
    if type(overlay) == "table" and ns:Usable(overlay) and overlay.IsVisible then
        local okV, vis = pcall(overlay.IsVisible, overlay)
        local okP, parent = pcall(function() local p = overlay:GetParent(); return p and p:GetName() or "no name" end)
        lines[#lines + 1] = "OverlayPlayerCastingBarFrame: " .. ((okV and vis) and "on screen" or "not on screen") .. ", inside " .. tostring(okP and parent or "?")
    end
    ns.craftLast = lines
    return lines
end

-- Does this frame look like a cast bar of the game's? (A status bar with an icon and a label.)
local function Shaped(f)
    if type(f) ~= "table" or not ns:Usable(f) or type(f.GetObjectType) ~= "function" then return false end
    local ok, kind = pcall(f.GetObjectType, f)
    if not ok or kind ~= "StatusBar" then return false end
    if type(f.Icon) ~= "table" or type(f.Text) ~= "table" then return false end
    local okN, name = pcall(f.GetName, f)
    if okN and type(name) == "string" and name:find("^FantasyGlassUI") then return false end
    return f ~= _G.PlayerCastingBarFrame and f ~= _G.CastingBarFrame and f ~= _G.PetCastingBarFrame
end
local function Visible(f)
    local ok, v = pcall(f.IsVisible, f)
    return ok and v and true or false
end
-- The game's crafting bar, if one is on screen right now. Second result: how it was found.
function ns:FindCraftBar()
    for _, name in ipairs({ "OverlayPlayerCastingBarFrame", "TradeSkillCastingBarFrame", "ProfessionsCastingBarFrame" }) do
        local f = _G[name]
        if type(f) == "table" and ns:Usable(f) and f.GetObjectType and Visible(f) then return f, name end
    end
    local budget = 1500
    local function walk(f, depth)
        if budget <= 0 or depth > 7 or type(f) ~= "table" or not ns:Usable(f) or not f.GetChildren then return nil end
        for _, child in ipairs({ f:GetChildren() }) do
            budget = budget - 1
            if Shaped(child) and Visible(child) then return child end
            local found = walk(child, depth + 1)
            if found then return found end
        end
        return nil
    end
    for _, name in ipairs({ "ProfessionsFrame", "TradeSkillFrame", "CraftFrame" }) do
        local win = _G[name]
        if type(win) == "table" and ns:Usable(win) and win.IsShown and win:IsShown() then
            local found = walk(win, 0)
            if found then return found, "inside " .. name end
        end
    end
    if type(UIParent) == "table" and UIParent.GetChildren then
        for _, child in ipairs({ UIParent:GetChildren() }) do
            if Shaped(child) and Visible(child) then
                local okN, name = pcall(child.GetName, child)
                return child, "on the screen" .. ((okN and type(name) == "string") and (" (" .. name .. ")") or "")
            end
        end
    end
    return nil
end

ns:NewModule("craftBar", function()
    local H = 20
    ns.craftState = "waiting for a craft"

    local bar = ns:NewStatusBar(UIParent, true)
    bar:SetHeight(H)
    bar:Hide()
    local iconBox = CreateFrame("Frame", nil, bar)
    iconBox:SetSize(H, H)
    iconBox:SetPoint("RIGHT", bar, "LEFT", -3, 0)
    ns:AddBorder(iconBox, 0, 0, 0, 1)
    local icon = iconBox:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture(ns.FLAT)
    spark:SetVertexColor(1, 1, 1, 0.9)
    spark:SetSize(2, H)
    spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
    local name = ns:NewText(bar, 12, "LEFT")
    name:SetPoint("LEFT", 6, 0)
    local timer = ns:NewText(bar, 12, "RIGHT")
    timer:SetPoint("RIGHT", -6, 0)
    name:SetPoint("RIGHT", timer, "LEFT", -6, 0)

    local host, how                                   -- the game's crafting bar, once found, and how
    local casting, covering = false, false
    local startS, endS, raw = nil, nil, false
    local tries, nextTry = 0, 0

    local function Place()
        bar:ClearAllPoints()
        bar:SetPoint("LEFT", host, "LEFT", H + 3, 0)
        bar:SetPoint("RIGHT", host, "RIGHT", 0, 0)
        local okS, strata = pcall(host.GetFrameStrata, host)
        if okS and type(strata) == "string" then pcall(bar.SetFrameStrata, bar, strata) end
        local okL, level = pcall(host.GetFrameLevel, host)
        if okL and type(level) == "number" then pcall(bar.SetFrameLevel, bar, level + 5) end
    end
    local function Cover()
        if not host then
            local found, where = ns:FindCraftBar()
            if not found then return false end
            host, how = found, where
            ns:Kill(host, true)                           -- the game's own bar goes; ours stands in its place
        end
        if not Visible(host) then return false end
        Place()
        covering = true
        ns.craftCovering = true
        ns.craftState = "replacing the game's crafting bar (found " .. tostring(how) .. ")"
        bar:SetAlpha(1)
        bar:Show()
        return true
    end
    local function Stop()
        casting, covering = false, false
        ns.craftCovering = nil
        bar:Hide()
    end

    local function Begin()
        local spell, _, texture, startMS, endMS, isTradeSkill, _, _, spellID = UnitCastingInfo("player")
        if (not Secret(spell) and spell == nil) or not ns:IsCraft(isTradeSkill, spellID) then
            if casting then Stop() end
            return false
        end
        casting = true
        if Secret(startMS) or Secret(endMS) or not startMS or not endMS then
            raw, startS, endS = true, nil, nil
            pcall(function() bar:SetMinMaxValues(startMS, endMS) end)
        else
            raw = false
            startS, endS = startMS / 1000, endMS / 1000
            bar:SetMinMaxValues(0, math.max(endS - startS, 0.01))
        end
        pcall(name.SetText, name, spell)
        pcall(icon.SetTexture, icon, ns:CraftIcon(isTradeSkill, texture, spellID))
        ns:Paint(bar, "SetStatusBarColor", "@accent")
        tries, nextTry = 0, 0
        if not Cover() then
            covering = false
            if not host then ns.craftState = "the game's crafting bar was not found during the last craft (your cast bar still shows the craft)" end
        end
        return true
    end

    local driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", ns:Guard("Crafting bar", function()
        if not casting then return end
        local now = GetTime()
        if not covering then
            -- the game may put its bar up a moment after the craft starts: look a few more times
            if tries < 4 and now >= nextTry then
                tries, nextTry = tries + 1, now + 0.1
                Cover()
            end
            if not covering then return end
        end
        if raw then
            bar:SetValue(now * 1000)
            timer:SetText("")
        else
            local left = endS - now
            bar:SetValue(now - startS)
            timer:SetFormattedText("%.1f", math.max(left, 0))
            if left < -0.5 then Stop() end                -- (if the "stopped" event never arrives)
        end
    end))

    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED" }) do
        pcall(ev.RegisterUnitEvent, ev, e, "player")
    end
    ev:SetScript("OnEvent", ns:Guard("Crafting bar", function(_, event)
        if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_DELAYED" then
            Begin()
            if event == "UNIT_SPELLCAST_START" then
                -- (a moment later, so that every bar that is going to appear has appeared)
                ns:After(0.2, function() pcall(ns.CraftFacts, ns); if ns.craftLast then ns.craftLast[#ns.craftLast + 1] = "the game's crafting bar: " .. (host and ("found " .. tostring(how)) or "none found") end end)
            end
        elseif casting then
            if not Begin() then Stop() end                -- (making several: the next one may already have begun)
        end
    end))

    ns.craftTest = { bar = bar, name = name, icon = icon, IsCovering = function() return covering end, IsCasting = function() return casting end,
                     Host = function() return host end, Forget = function() host, how = nil, nil end }
end)
