local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- 11.5: an interrupt rotation, a class resource display you design, a profession panel, a key
-- binding sheet, buff coverage on raid frames, and quiet mode.
------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------
-- Interrupt rotation: the order your group takes turns interrupting. The panel says who is next, and
-- tells you (on screen, and aloud if spoken alerts are on) when it is you. Set the order with
-- /fgui kicks <name> <name> ...; the group leader's order is shared with everyone who has the add-on.
-- With no order set, everyone with an interrupt is in it, alphabetically. Built on the group
-- cooldowns: an interrupt someone uses moves the turn on to the next person whose interrupt is ready.
------------------------------------------------------------------------------------------
local function KickDef(id) local def = ns.GroupCDFor and ns.GroupCDFor(id); return def and def[2] == "kick" end
-- Who has an interrupt: { name = endsAt } (0 when ready).
function ns.KickHolders(roster, now)
    local out = {}
    for name, r in pairs(roster or {}) do
        for id, ends in pairs(r.spells or {}) do
            if KickDef(id) then
                local left = math.max(0, (ends or 0) - now)
                if out[name] == nil or left < out[name] then out[name] = left end
            end
        end
    end
    return out
end
-- The rotation: the order set (only people with an interrupt), else everyone with one, A to Z.
function ns.KickOrder(set, holders)
    local order = {}
    if type(set) == "table" and #set > 0 then
        for _, name in ipairs(set) do if holders[name] ~= nil then order[#order + 1] = name end end
    end
    if #order == 0 then
        for name in pairs(holders) do order[#order + 1] = name end
        table.sort(order)
    end
    return order
end
-- Who is next: from the one after `last`, the first whose interrupt is ready (or the soonest).
function ns.KickNext(order, holders, last)
    if #order == 0 then return nil end
    local start = 1
    for i, name in ipairs(order) do if name == last then start = i + 1 end end
    local soonest, soonestLeft
    for k = 0, #order - 1 do
        local name = order[(start - 1 + k) % #order + 1]
        local left = holders[name] or 999
        if left <= 0 then return name, 0 end
        if not soonestLeft or left < soonestLeft then soonest, soonestLeft = name, left end
    end
    return soonest, soonestLeft
end
local kick = { last = nil }
ns.kickState = kick
function ns:KickRotationUsed(name, id)
    if not KickDef(id) then return end
    kick.last = name
    kick.changed = true
end
function ns:KickCommand(text)
    local names = {}
    for w in ns.Trim(text or ""):gmatch("%S+") do names[#names + 1] = (w:gsub("^%l", string.upper)) end
    ns.db.kickOrder = names
    if #names == 0 then ns:Print("Interrupt order cleared: everyone with an interrupt takes turns, A to Z.")
    else ns:Print("Interrupt order: %s.", table.concat(names, ", ")) end
    local ch = ns.GroupChannel and ns.GroupChannel()
    local lead = UnitIsGroupLeader and UnitIsGroupLeader("player")
    if ch and ns.Yes(lead) and ns.GroupSend then ns.GroupSend("GKO:" .. table.concat(names, ","), ch) end
    kick.changed = true
    return names
end
ns:NewModule("kickRotation", function()
    local f = CreateFrame("Frame", "FantasyGlassUIKickRotation", UIParent, ns.template)
    f:SetSize(200, 26)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 220)
    f:SetBackdrop(ns.BACKDROP)
    ns:Paint(f, "SetBackdropColor", "bg", 0.8)
    ns:Paint(f, "SetBackdropBorderColor", "@border", 1)
    f.text = ns:NewText(f, 12, "CENTER", true)
    f.text:SetPoint("CENTER")
    f:Hide()
    local wasMe = false
    local function Update()
        local ch = ns.GroupChannel and ns.GroupChannel()
        if not ch and not ns.moving and not ns.testGroup then f:Hide(); return nil end
        local holders = ns.KickHolders(ns.groupCDRoster, GetTime())
        local order = ns.KickOrder(ns.db.kickOrder, holders)
        local who, left = ns.KickNext(order, holders, kick.last)
        if not who then
            if ns.moving then f.text:SetText(ns:Tr("Next interrupt")); f:Show() else f:Hide() end
            return nil
        end
        local me = UnitName("player")
        local isMe = who == me
        f.text:SetText(isMe and ("|cffffd100" .. ns:Tr("You are next to interrupt") .. "|r")
            or (ns:Tr("Next interrupt") .. ": " .. who .. ((left and left > 0) and ("  |cff9aa4b4" .. ns.Clock(left) .. "|r") or "")))
        if isMe then ns:Paint(f, "SetBackdropBorderColor", "@accent", 1) else ns:Paint(f, "SetBackdropBorderColor", "@border", 1) end
        if isMe and not wasMe and #order > 1 then
            if ns.SpeakEvent then ns:SpeakEvent("custom", "You are next to interrupt") end
            if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.RAID_WARNING or 8959, "Master") end
        end
        wasMe = isMe
        f:Show()
        return who
    end
    ns.kickTest = { Update = Update, frame = f }
    ns:Every(0.25, "Interrupt rotation", Update)
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "CHAT_MSG_ADDON")
    ev:SetScript("OnEvent", ns:Guard("Interrupt rotation", function(_, _, prefix, msg, _, sender)
        if Secret(prefix) or Secret(msg) or prefix ~= "FGUI" or type(msg) ~= "string" then return end
        local list = msg:match("^GKO:(.*)$")
        if not list then return end
        local names = {}
        for n in list:gmatch("[^,]+") do names[#names + 1] = n end
        ns.db.kickOrder = names
        kick.changed = true
    end))
    local entry = ns:RegisterMovable(f, "kickRotation", "Interrupt rotation")
    if type(entry) == "table" then entry.offPage = true end
end)

------------------------------------------------------------------------------------------
-- Class resource: combo points, holy power, soul shards, chi, arcane charges, essence or death
-- knight runes, shown the way you design it on the Bars and frames tab: as dots, one bar, or a
-- number; how wide, how tall, how far apart. It can go anywhere (move mode).
------------------------------------------------------------------------------------------
ns.RESOURCE_DEFAULT = { style = "dots", width = 180, height = 12, gap = 4, font = 16 }
local RESOURCE_STYLES = { dots = true, bar = true, number = true }
function ns.ResourceDesign()
    local d = type(ns.db and ns.db.resourceDesign) == "table" and ns.db.resourceDesign or {}
    local out = {}
    for k, v in pairs(ns.RESOURCE_DEFAULT) do if d[k] == nil then out[k] = v else out[k] = d[k] end end
    if not RESOURCE_STYLES[out.style] then out.style = "dots" end
    out.width = math.max(60, math.min(400, tonumber(out.width) or 180))
    out.height = math.max(4, math.min(40, tonumber(out.height) or 12))
    out.gap = math.max(0, math.min(12, tonumber(out.gap) or 4))
    out.font = math.max(10, math.min(36, tonumber(out.font) or 16))
    return out
end
-- The power type a class shows here (or "runes"), and its color.
function ns.ClassResource(class)
    local PT = Enum and Enum.PowerType or {}
    local map = {
        ROGUE = { PT.ComboPoints or 4, { 1, 0.85, 0.3 } }, DRUID = { PT.ComboPoints or 4, { 1, 0.6, 0.2 } },
        PALADIN = { PT.HolyPower or 9, { 0.95, 0.85, 0.35 } }, WARLOCK = { PT.SoulShards or 7, { 0.62, 0.42, 0.9 } },
        MONK = { PT.Chi or 12, { 0.45, 0.95, 0.75 } }, MAGE = { PT.ArcaneCharges or 16, { 0.45, 0.65, 1 } },
        EVOKER = { PT.Essence or 19, { 0.35, 0.85, 0.8 } }, DEATHKNIGHT = { "runes", { 0.55, 0.8, 0.95 } },
    }
    return map[class]
end
-- Where the i-th of n dots sits, and how wide each is, in a row `width` wide.
function ns.DotLayout(i, n, width, gap)
    local each = (width - (n - 1) * gap) / n
    return (i - 1) * (each + gap), each
end
ns:NewModule("classResource", function()
    local _, class = UnitClass("player")
    local res = ns.ClassResource(class)
    local f = CreateFrame("Frame", "FantasyGlassUIResource", UIParent)
    f:SetSize(180, 12)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, -170)
    f.dots = {}
    local function Dot(i)
        local d = f.dots[i]
        if d then return d end
        d = CreateFrame("StatusBar", nil, f)
        d:SetStatusBarTexture(ns.BAR or ns.FLAT)
        d.bg = d:CreateTexture(nil, "BACKGROUND")
        d.bg:SetAllPoints(); d.bg:SetTexture(ns.FLAT)
        ns:Paint(d.bg, "SetVertexColor", "trough", 0.9)
        ns:AddBorder(d, 0, 0, 0, 1)
        d.scMaskFile = "diamond"                               -- Starcut: each dot a small diamond, like a cut gem
        ns:StarcutStyleBar(d, false)
        f.dots[i] = d
        return d
    end
    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetStatusBarTexture(ns.BAR or ns.FLAT)
    f.bar:SetAllPoints()
    f.bar.bg = f.bar:CreateTexture(nil, "BACKGROUND")
    f.bar.bg:SetAllPoints(); f.bar.bg:SetTexture(ns.FLAT)
    ns:Paint(f.bar.bg, "SetVertexColor", "trough", 0.9)
    ns:AddBorder(f.bar, 0, 0, 0, 1)
    ns:StarcutStyleBar(f.bar, true)                            -- (the bar style: cut to points, glowing)
    f.num = ns:NewText(f, 16, "CENTER", true)
    f.num:SetPoint("CENTER")
    local function Max()
        if not res then return 0 end
        if res[1] == "runes" then return (type(GetRuneCooldown) == "function") and 6 or 0 end
        local ok, m = pcall(UnitPowerMax, "player", res[1])
        if ok and type(m) == "number" and not Secret(m) then return m end
        return 0
    end
    local lastMax, lastStyle
    function f.Apply()
        local d = ns.ResourceDesign()
        f:SetSize(d.width, d.height)
        local max = Max()
        local c = res and res[2] or { 1, 1, 1 }
        lastStyle, lastMax = d.style, max
        f.bar:SetShown(d.style == "bar")
        f.bar:SetStatusBarColor(c[1], c[2], c[3])
        f.num:SetShown(d.style == "number")
        ns:Font(f.num, d.font, true)
        f.num:SetTextColor(c[1], c[2], c[3])
        for i, dot in ipairs(f.dots) do dot:Hide() end
        if d.style == "dots" then
            for i = 1, max do
                local dot = Dot(i)
                local x, w = ns.DotLayout(i, max, d.width, d.gap)
                dot:ClearAllPoints()
                dot:SetPoint("TOPLEFT", f, "TOPLEFT", x, 0)
                dot:SetSize(math.max(1, w), d.height)
                dot:SetMinMaxValues(i - 1, i)                   -- (full once the resource reaches i: works on a hidden value too)
                dot:SetStatusBarColor(c[1], c[2], c[3])
                dot:Show()
            end
        end
        return max
    end
    -- The design is read again only when its table changes (a profile switch, a reset) or every couple
    -- of seconds, rather than built afresh ten times a second.
    local design, designFrom, designAge = nil, nil, 0
    local function Design()
        local from = ns.db and ns.db.resourceDesign
        designAge = designAge + 1
        if not design or from ~= designFrom or designAge > 20 then
            local fresh = from ~= designFrom
            design, designFrom, designAge = ns.ResourceDesign(), from, 0
            return design, fresh
        end
        return design, false
    end
    local function Update()
        if not res then if not ns.moving then f:Hide() end; return end
        local max = Max()
        local d, fresh = Design()
        if fresh or max ~= lastMax or d.style ~= lastStyle then f.Apply() end     -- (fresh: another profile's design)
        if max <= 0 and not ns.moving then f:Hide(); return end
        f:Show()
        if res[1] == "runes" then
            local ready = 0
            for i = 1, 6 do
                local ok, _, _, isReady = pcall(GetRuneCooldown, i)
                if ok and isReady == true then ready = ready + 1 end
            end
            for i, dot in ipairs(f.dots) do dot:SetValue(ready) end
            f.bar:SetMinMaxValues(0, 6); f.bar:SetValue(ready)
            f.num:SetText(ready)
            return
        end
        local ok, v = pcall(UnitPower, "player", res[1])
        if not ok then return end
        for i = 1, max do if f.dots[i] then f.dots[i]:SetValue(v) end end        -- raw: a bar takes a hidden value
        f.bar:SetMinMaxValues(0, math.max(1, max)); f.bar:SetValue(v)
        pcall(f.num.SetText, f.num, v)
    end
    ns.resourceTest = { frame = f, Update = Update }
    ns.ApplyResourceDesign = function() design = nil; f.Apply(); Update() end
    -- Combo points, holy power and the rest change on an event; a slower look catches anything else.
    if res then
        local ev = CreateFrame("Frame")
        pcall(ev.RegisterUnitEvent, ev, "UNIT_POWER_FREQUENT", "player")
        pcall(ev.RegisterUnitEvent, ev, "UNIT_MAXPOWER", "player")
        pcall(ev.RegisterUnitEvent, ev, "UNIT_DISPLAYPOWER", "player")
        pcall(ev.RegisterEvent, ev, "RUNE_POWER_UPDATE")
        pcall(ev.RegisterEvent, ev, "PLAYER_TARGET_CHANGED")
        ev:SetScript("OnEvent", ns:Guard("Class resource", function() Update() end))
    end
    ns:Every(0.25, "Class resource", Update)
    local entry = ns:RegisterMovable(f, "classResource", "Class resource")
    if type(entry) == "table" then entry.noScale = "Sized in Frames and bars › Your frames (Class resource)." end
end)

------------------------------------------------------------------------------------------
-- Professions on all your characters (/fgui crafts [search]): what each can make, noted whenever a
-- profession window is open, searchable, and "Made by" on item tooltips.
------------------------------------------------------------------------------------------
local function CraftStore()
    if type(ns.root) ~= "table" then return {} end
    ns.root.crafts = type(ns.root.crafts) == "table" and ns.root.crafts or {}
    return ns.root.crafts
end
local madeBy                                                   -- itemID -> "Name (Profession), ..." (built when needed)
function ns:RecordRecipes()
    local T = C_TradeSkillUI
    if not (T and T.GetAllRecipeIDs and T.GetRecipeInfo and T.GetBaseProfessionInfo) then return 0 end
    if T.IsTradeSkillLinked and ns.Yes(T.IsTradeSkillLinked()) then return 0 end
    if T.IsTradeSkillGuild and ns.Yes(T.IsTradeSkillGuild()) then return 0 end
    local okP, prof = pcall(T.GetBaseProfessionInfo)
    local profName = okP and type(prof) == "table" and prof.professionName
    if type(profName) ~= "string" or profName == "" then return 0 end
    local okI, ids = pcall(T.GetAllRecipeIDs)
    if not okI or type(ids) ~= "table" then return 0 end
    local list, n = {}, 0
    for _, id in ipairs(ids) do
        local ok, info = pcall(T.GetRecipeInfo, id)
        if ok and type(info) == "table" and info.learned and type(info.name) == "string" then
            local item
            if T.GetRecipeSchematic then
                local okS, sch = pcall(T.GetRecipeSchematic, id, false)
                if okS and type(sch) == "table" then item = sch.outputItemID end
            end
            list[id] = { n = info.name, i = item }
            n = n + 1
        end
    end
    if n == 0 then return 0 end
    local key = ns:CharKey()
    local store = CraftStore()
    store[key] = type(store[key]) == "table" and store[key] or {}
    store[key][profName] = list
    madeBy = nil
    return n
end
-- Who can make an item: { "Name (Profession)" ... }
function ns.WhoMakes(store, itemID)
    local out = {}
    for char, profs in pairs(store) do
        for prof, list in pairs(profs) do
            for _, r in pairs(list) do
                if r.i == itemID then out[#out + 1] = tostring(char):gsub(" %- .*$", "") .. " (" .. prof .. ")"; break end
            end
        end
    end
    table.sort(out)
    return out
end
-- Recipes whose name has the search in it: { { name, char, prof } }
function ns.SearchCrafts(store, text)
    local want = tostring(text or ""):lower()
    local out = {}
    for char, profs in pairs(store) do
        for prof, list in pairs(profs) do
            for _, r in pairs(list) do
                if want == "" or r.n:lower():find(want, 1, true) then out[#out + 1] = { name = r.n, char = char, prof = prof } end
            end
        end
    end
    table.sort(out, function(a, b) if a.name ~= b.name then return a.name < b.name end return a.char < b.char end)
    return out
end
function ns:ShowCrafts(text)
    text = ns.Trim(text or "")
    local store = CraftStore()
    local lines = {}
    if text == "" then
        local chars = {}
        for char in pairs(store) do chars[#chars + 1] = char end
        table.sort(chars)
        for _, char in ipairs(chars) do
            local profs = {}
            for prof, list in pairs(store[char]) do
                local n = 0
                for _ in pairs(list) do n = n + 1 end
                profs[#profs + 1] = format("%s %d", prof, n)
            end
            table.sort(profs)
            lines[#lines + 1] = { left = tostring(char):gsub(" %- .*$", ""), right = table.concat(profs, ", ") }
        end
    else
        for i, r in ipairs(ns.SearchCrafts(store, text)) do
            if i > 200 then break end
            lines[#lines + 1] = { left = r.name, right = "|cff9aa4b4" .. tostring(r.char):gsub(" %- .*$", "") .. " (" .. r.prof .. ")|r" }
        end
    end
    if #lines == 0 then lines[1] = { left = ns:Tr(text == "" and "Nothing noted yet: open each profession's window once on each character." or "No recipe by that name.") } end
    return ns:ShowList("Crafts", text == "" and "Professions" or (ns:Tr("Recipes") .. ": " .. text), lines,
        "/fgui crafts <part of a name> searches every character's recipes.", 480, 420)
end
do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "NEW_RECIPE_LEARNED" }) do pcall(ev.RegisterEvent, ev, e) end
    local pending
    ev:SetScript("OnEvent", ns:Guard("Professions", function()
        if pending then return end
        pending = true
        ns:After(1, function() pending = nil; pcall(ns.RecordRecipes, ns) end)
    end))
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ns:Guard("Made by", function(tip, data)
            if not (ns.db and ns.db.madeByTip ~= false) or type(data) ~= "table" then return end
            local id = data.id
            if type(id) ~= "number" or Secret(id) then return end
            if not madeBy then madeBy = {} end
            local who = madeBy[id]
            if who == nil then
                local list = ns.WhoMakes(CraftStore(), id)
                who = (#list > 0) and table.concat(list, ", ") or false
                madeBy[id] = who
            end
            if who then tip:AddLine(ns:Tr("Made by") .. ": |cffffffff" .. who .. "|r", 0.6, 0.65, 0.75, true) end
        end))
    end
end

------------------------------------------------------------------------------------------
-- Key binding sheet: every action bar, with each button's key and what it does, on one screen.
-- Hold its key (Key Bindings, AddOns) or /fgui keys to open and close it.
------------------------------------------------------------------------------------------
local sheet
local GAME_BARS = { { "ActionButton", "ACTIONBUTTON" }, { "MultiBarBottomLeftButton", "MULTIACTIONBAR1BUTTON" },
    { "MultiBarBottomRightButton", "MULTIACTIONBAR2BUTTON" }, { "MultiBarRightButton", "MULTIACTIONBAR3BUTTON" },
    { "MultiBarLeftButton", "MULTIACTIONBAR4BUTTON" }, { "MultiBar5Button", "MULTIACTIONBAR5BUTTON" },
    { "MultiBar6Button", "MULTIACTIONBAR6BUTTON" }, { "MultiBar7Button", "MULTIACTIONBAR7BUTTON" } }
-- The bars to show: { label, { { action, command } x12 } }
function ns.KeySheetBars()
    local bars = {}
    if ns.engine and ns.engine.bars and ns.loaded and ns.loaded.barEngine then
        for _, bar in ipairs(ns.engine.bars) do
            local row = {}
            for i, b in ipairs(bar.buttons) do row[i] = { action = ns.engine.ActionOf(b), command = b.suiCommand } end
            bars[#bars + 1] = { label = bar.def.label, buttons = row }
        end
    else
        for k, g in ipairs(GAME_BARS) do
            local row = {}
            for i = 1, 12 do
                local b = _G[g[1] .. i]
                local a = b and (b.action or (b.GetAttribute and b:GetAttribute("action")))
                row[i] = { action = (type(a) == "number" and not Secret(a)) and a or ((k - 1) * 12 + i), command = g[2] .. i }
            end
            bars[#bars + 1] = { label = format(ns:Tr("Bar %d"), k), buttons = row }
        end
    end
    return bars
end
local function ActionLabel(a)
    if type(a) ~= "number" or not HasAction or not HasAction(a) then return nil end
    local okT, text = pcall(GetActionText, a)
    if okT and type(text) == "string" and not Secret(text) and text ~= "" then return text end
    local okI, kind, id = pcall(GetActionInfo, a)
    if okI and kind == "spell" and type(id) == "number" then
        local n = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
        if type(n) == "string" then return n end
    elseif okI and kind == "item" and type(id) == "number" then
        local n = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
        if type(n) == "string" then return n end
    elseif okI and kind == "macro" then
        return ns:Tr("Macro")
    end
    return nil
end
function ns:ShowKeySheet(show)
    if not sheet then
        sheet = CreateFrame("Frame", "FantasyGlassUIKeySheet", UIParent, ns.template)
        sheet:SetFrameStrata("FULLSCREEN_DIALOG")
        sheet:SetPoint("CENTER")
        sheet:SetBackdrop(ns.BACKDROP)
        ns:Paint(sheet, "SetBackdropColor", "window", 0.96)
        ns:Paint(sheet, "SetBackdropBorderColor", "@accent", 1)
        ns:Dress(sheet)
        sheet.title = ns:NewText(sheet, 14, "LEFT", true)
        sheet.title:SetPoint("TOPLEFT", 12, -10)
        sheet.title:SetText(ns:Tr("Key bindings"))
        ns:Paint(sheet.title, "SetTextColor", "@accent")
        sheet.rows = {}
        tinsert(UISpecialFrames, "FantasyGlassUIKeySheet")
    end
    if show == nil then show = not sheet:IsShown() end
    if not show then sheet:Hide(); return false end
    local CELL, GAP = 58, 4
    local bars = ns.KeySheetBars()
    local shownRows = 0
    for r, bar in ipairs(bars) do
        local row = sheet.rows[r]
        if not row then
            row = { label = ns:NewText(sheet, 11, "RIGHT"), cells = {} }
            row.label:SetWidth(84)                           -- (a long bar name in another language is cut short, not pushed off the sheet)
            if row.label.SetWordWrap then row.label:SetWordWrap(false) end
            for i = 1, 12 do
                local c = CreateFrame("Frame", nil, sheet)
                c:SetSize(CELL, CELL)
                c.icon = c:CreateTexture(nil, "ARTWORK")
                c.icon:SetPoint("TOP", 0, -2); c.icon:SetSize(30, 30)
                c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                c.key = ns:NewText(c, 12, "CENTER", true)
                c.key:SetPoint("TOP", c.icon, "BOTTOM", 0, -1)
                c.key:SetWidth(CELL); if c.key.SetWordWrap then c.key:SetWordWrap(false) end   -- (a long key such as a mouse wheel stays in its cell)
                c.name = ns:NewText(c, 9, "CENTER")
                c.name:SetPoint("TOP", c.key, "BOTTOM", 0, -1)
                c.name:SetWidth(CELL); if c.name.SetWordWrap then c.name:SetWordWrap(false) end
                row.cells[i] = c
            end
            sheet.rows[r] = row
        end
        local y = -36 - (r - 1) * (CELL + GAP)
        row.label:ClearAllPoints()
        row.label:SetPoint("TOPRIGHT", sheet, "TOPLEFT", 90, y - 18)
        row.label:SetText(ns:Tr(bar.label))
        row.label:Show()
        for i, c in ipairs(row.cells) do
            local info = bar.buttons[i] or {}
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", 100 + (i - 1) * (CELL + GAP), y)
            local tex = (type(info.action) == "number" and HasAction and HasAction(info.action)) and GetActionTexture(info.action) or nil
            c.icon:SetTexture(tex)
            c.icon:SetAlpha(tex and 1 or 0.15)
            local key = info.command and GetBindingKey(info.command)
            local keyText = (type(key) == "string" and key ~= "") and ((GetBindingText and GetBindingText(key, "KEY_", true)) or key) or ""
            c.key:SetText(keyText ~= "" and keyText or "|cff5a6070-|r")
            c.name:SetText(ActionLabel(info.action) or "")
            c:Show()
        end
        shownRows = r
    end
    for r = shownRows + 1, #sheet.rows do
        sheet.rows[r].label:Hide()
        for _, c in ipairs(sheet.rows[r].cells) do c:Hide() end
    end
    sheet:SetSize(100 + 12 * (CELL + GAP) + 8, 44 + shownRows * (CELL + GAP))
    sheet:Show()
    return shownRows
end

------------------------------------------------------------------------------------------
-- Buff coverage on raid frames: a small mark on anyone in your group missing a buff you can give
-- (Fortitude, Mark of the Wild, Arcane Intellect, Battle Shout). Checked out of fights; on the game's
-- own raid and party frames and on the add-on's.
------------------------------------------------------------------------------------------
ns.COVER_BUFFS = {
    PRIEST = { 1243, 21562 }, DRUID = { 1126, 21849 }, MAGE = { 1459, 23028 }, WARRIOR = { 6673 },
}
local coverMarks = setmetatable({}, { __mode = "k" })
-- The names of the buff (and its group version) this character can give, or nil.
function ns.CoverBuffNames(class, known)
    local ids = ns.COVER_BUFFS[class]
    if not ids or not (known or IsPlayerSpell)(ids[1]) then return nil end
    local names = {}
    for _, id in ipairs(ids) do
        local n = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
        if type(n) == "string" then names[#names + 1] = n end
    end
    return #names > 0 and names, ids[1] or nil
end
-- Is a unit missing the buff? true / false / nil (cannot tell: hidden, too far, not there).
function ns.MissingBuff(unit, names, find)
    find = find or (C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName)
    if not find or type(unit) ~= "string" or Secret(unit) then return nil end
    local okE, exists = pcall(UnitExists, unit)
    if not okE or not ns.Is(exists, true) then return nil end
    local okD, dead = pcall(UnitIsDeadOrGhost, unit)
    if okD and ns.Is(dead, true) then return nil end
    for _, n in ipairs(names) do
        local ok, a = pcall(find, unit, n, "HELPFUL")
        if not ok or Secret(a) then return nil end
        if a then return false end
    end
    return true
end
ns:NewModule("buffCoverage", function()
    local _, class = UnitClass("player")
    local function Frames()
        local out = {}
        for i = 1, 40 do local f = _G["CompactRaidFrame" .. i]; if f then out[#out + 1] = f end end
        for i = 1, 5 do local f = _G["CompactPartyFrameMember" .. i]; if f then out[#out + 1] = f end end
        for _, f in ipairs(ns.raidCellList or {}) do out[#out + 1] = f end
        return out
    end
    local function Mark(f, icon)
        local m = coverMarks[f]
        if not m then
            local okT, t = pcall(f.CreateTexture, f, nil, "OVERLAY", nil, 7)
            if not okT or not t then return nil end
            t:SetSize(12, 12)
            t:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
            t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            m = t
            coverMarks[f] = m
        end
        m:SetTexture(icon)
        return m
    end
    local function Update()
        if InCombatLockdown() then return end
        local names, id = ns.CoverBuffNames(class)
        local icon = id and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
        local n = 0
        if ns.testGroup then                                   -- practice: a few of the sample raid frames are missing it
            local tIcon = icon or (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(1243)) or 135987
            for i, f in ipairs(ns.raidSamples or {}) do
                local m = (i % 3 == 0) and Mark(f, tIcon)
                if m then m:Show(); n = n + 1 elseif coverMarks[f] then coverMarks[f]:Hide() end
            end
            ns.coverMissing = n
            return n
        end
        for _, f in ipairs(ns.raidSamples or {}) do if coverMarks[f] then coverMarks[f]:Hide() end end
        for _, f in ipairs(Frames()) do
            local unit = rawget(f, "unit") or f.unit
            local missing = names and f:IsVisible() and ns.MissingBuff(unit, names)
            if missing then
                local m = Mark(f, icon)
                if m then m:Show(); n = n + 1 end
            elseif coverMarks[f] and missing ~= nil then
                coverMarks[f]:Hide()
            elseif coverMarks[f] and not names then
                coverMarks[f]:Hide()
            end
        end
        ns.coverMissing = n
        return n
    end
    ns.coverTest = { Update = Update, Mark = function(f) return coverMarks[f] end }
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Buff coverage", function() ns:After(0.5, Update) end))
    ns:Every(2, "Buff coverage", Update)
end)

------------------------------------------------------------------------------------------
-- Quiet mode (/fgui quiet, or its key): hides chat, names over heads, the info bar, whispers and
-- notifications, for screenshots and streaming. Again to bring it all back as it was.
------------------------------------------------------------------------------------------
local QUIET_CVARS = { "UnitNameOwn", "UnitNamePlayerGuild", "UnitNamePlayerPVPTitle", "UnitNameFriendlyPlayerName",
    "UnitNameEnemyPlayerName", "UnitNameNPC", "UnitNameFriendlyPetName", "UnitNameEnemyPetName", "UnitNameGuildTitle" }
local function QuietFrames()
    local out = {}
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        for _, suffix in ipairs({ "", "Tab", "EditBox", "ButtonFrame" }) do
            local f = _G["ChatFrame" .. i .. suffix]
            if f then out[#out + 1] = f end
        end
    end
    for _, name in ipairs({ "GeneralDockManager", "ChatFrameMenuButton", "ChatFrameChannelButton", "QuickJoinToastButton",
        "FantasyGlassUIInfoBar", "FantasyGlassUIWhispers", "FantasyGlassUIToasts", "FantasyGlassUIMeter", "FantasyGlassUIMeterTab" }) do
        local f = _G[name]
        if f then out[#out + 1] = f end
    end
    return out
end
function ns:ToggleQuiet(on)
    if on == nil then on = not ns.quietOn end
    if InCombatLockdown() and on ~= ns.quietOn then                -- (asked for in a fight: as soon as it ends)
        local want = on
        if not (ns.AfterFight and ns:AfterFight("Quiet mode", function() ns:ToggleQuiet(want) end)) then ns:Print("Not during a fight.") end
        return ns.quietOn
    end
    local Get = (C_CVar and C_CVar.GetCVar) or GetCVar
    local Set = (C_CVar and C_CVar.SetCVar) or SetCVar
    if on and not ns.quietOn then
        ns.quietSaved = { cvars = {}, alpha = {} }
        for _, cv in ipairs(QUIET_CVARS) do
            local ok, v = pcall(Get, cv)
            if ok and v ~= nil then ns.quietSaved.cvars[cv] = v; pcall(Set, cv, "0") end
        end
        for _, f in ipairs(QuietFrames()) do
            local ok, a = pcall(f.GetAlpha, f)
            ns.quietSaved.alpha[f] = ok and a or 1
            pcall(f.SetAlpha, f, 0)
        end
        ns.quietOn = true
        if type(ns.root) == "table" then ns.root.quietCVars = ns.quietSaved.cvars end      -- (put back even after a reload)
        if UIErrorsFrame then pcall(UIErrorsFrame.SetAlpha, UIErrorsFrame, 0) end
    elseif not on and ns.quietOn then
        local saved = ns.quietSaved or { cvars = {}, alpha = {} }
        for cv, v in pairs(saved.cvars) do pcall(Set, cv, v) end
        for f, a in pairs(saved.alpha) do pcall(f.SetAlpha, f, a) end
        if UIErrorsFrame then pcall(UIErrorsFrame.SetAlpha, UIErrorsFrame, 1) end
        ns.quietOn, ns.quietSaved = false, nil
        if type(ns.root) == "table" then ns.root.quietCVars = nil end
        ns:Print("Quiet mode off: chat, names and the info bar are back.")       -- (on, there is no chat to say it in)
    end
    return ns.quietOn
end
-- names over heads switched off by quiet mode come back after a reload or a log out mid-way
do
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", ns:Guard("More events", function()
        if ns.quietOn or type(ns.root) ~= "table" or type(ns.root.quietCVars) ~= "table" then return end
        local Set = (C_CVar and C_CVar.SetCVar) or SetCVar
        for cv, v in pairs(ns.root.quietCVars) do pcall(Set, cv, v) end
        ns.root.quietCVars = nil
    end))
end
