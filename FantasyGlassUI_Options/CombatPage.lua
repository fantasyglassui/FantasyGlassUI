-- Part of Fantasy Glass UI, kept in a second folder that the game loads only when it is needed (the
-- first time the options, the setup or the self-check is asked for). The main add-on shares its
-- table as the global FantasyGlassUI; everything here hangs off that.
local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end
local O = ns.optUI
local Header = function(...) return O.Header(...) end

-- Page 5: click-casting --------------------------------------------------------------------------------
local function BuildClickCast(page)
    local MODS = { "", "shift", "ctrl", "alt" }
    local MODNAME = { [""] = "No modifier", shift = "Shift", ctrl = "Ctrl", alt = "Alt" }
    local BTNNAME = { "Left click", "Right click", "Middle click", "Button 4", "Button 5" }
    local ROWS = 8

    local intro = page:CreateFontString(nil, "OVERLAY")
    ns:Font(intro, 12)
    intro:SetPoint("TOPLEFT", 0, 0)
    intro:SetWidth(730)
    intro:SetJustifyH("LEFT")
    if ns.raidMode == "ours" then
        intro:SetText(ns:Tr("Click a unit frame to cast on that player. Works on raid, party and all other Fantasy Glass UI unit frames. Type the spell's name exactly as in your spellbook. A plain left or right click replaces \"target\" or the right-click menu on those frames, so a modifier is usually the better choice."))
    else
        intro:SetText(ns:Tr("Click a unit frame to cast on that player. Works on party and the other Fantasy Glass UI unit frames; raid frames here are the game's own, which have their own click-casting in the game's options. Type the spell's name exactly as in your spellbook. A plain left or right click replaces \"target\" or the right-click menu, so a modifier is usually the better choice."))
    end
    ns:Paint(intro, "SetTextColor", "dim")

    local msg = page:CreateFontString(nil, "OVERLAY")
    ns:Font(msg, 12)
    msg:SetPoint("BOTTOMLEFT", 0, 0)

    local rows = {}
    local function Read()
        local list = {}
        for _, r in ipairs(rows) do
            local spell = r.spell:GetText()
            if type(spell) == "string" then
                spell = strtrim(spell)
                if spell ~= "" then list[#list + 1] = { mod = r.mod, button = r.button, spell = spell } end
            end
        end
        return list
    end

    for i = 1, ROWS do
        local saved = ns.db.clickCast[i]
        local r = { mod = saved and saved.mod or "shift", button = saved and saved.button or 1 }
        local y = -62 - (i - 1) * 30
        r.modBtn = ns:CreateButton(page, MODNAME[r.mod] or MODNAME[""], 120, 24, function()
            for k, m in ipairs(MODS) do if m == r.mod then r.mod = MODS[k % #MODS + 1]; break end end
            r.modBtn.text:SetText(ns:Tr(MODNAME[r.mod]))
        end)
        r.modBtn:SetPoint("TOPLEFT", 0, y)
        r.btnBtn = ns:CreateButton(page, BTNNAME[r.button] or BTNNAME[1], 120, 24, function()
            r.button = r.button % #BTNNAME + 1
            r.btnBtn.text:SetText(ns:Tr(BTNNAME[r.button]))
        end)
        r.btnBtn:SetPoint("LEFT", r.modBtn, "RIGHT", 8, 0)
        r.spell = ns:CreateEditBox(page, 300, 24, "Spell name")
        r.spell:SetPoint("LEFT", r.btnBtn, "RIGHT", 8, 0)
        if saved and type(saved.spell) == "string" then r.spell:SetText(saved.spell) end
        local clear = ns:CreateButton(page, "Clear", 60, 24, function() r.spell:SetText("") end)
        clear:SetPoint("LEFT", r.spell, "RIGHT", 8, 0)
        rows[i] = r
    end

    local apply = ns:CreateButton(page, "Apply bindings", 150, 26, function()
        ns.db.clickCast = Read()
        local done = ns:ApplyClickCast()
        msg:SetText(done and (ns:SignalHex("good") .. format(ns:Tr(#ns.db.clickCast == 1 and "%d binding active." or "%d bindings active."), #ns.db.clickCast) .. "|r") or ("|cffffd100" .. ns:Tr("Saved. They take effect when you leave combat.") .. "|r"))
    end)
    apply:SetPoint("TOPLEFT", 0, -62 - ROWS * 30 - 8)
end

-- Page 6: combat -----------------------------------------------------------------------------------------
local function BuildCombat(page)
    local msg = page:CreateFontString(nil, "OVERLAY")
    ns:Font(msg, 12)
    msg:SetPoint("BOTTOMLEFT", 0, 0)

    -- (12.0: the switches that were here are rows of their sections now: see Categories.lua)
    -- The AFK screen; then custom, spoken and buff alerts; then the cooldown tracker and click casting.
    -- Each is shown in its own section of the settings window.
    local B0 = 0
    Header(page, "AFK screen", 0, B0)
    local afkSlider = ns:CreateSlider(page, "Start after idle minutes  (0 = when the game marks you away)", 0, 30, 1,
        tonumber(ns.db.afkDelay) or 0, "%d", function(v) ns.db.afkDelay = v end, 360)
    afkSlider:SetPoint("TOPLEFT", 0, B0 - 24)
    local afkFlag = ns:CreateCheckbox(page, "Also mark my character as away then", ns.db.afkFlag, function(v) ns.db.afkFlag = v end)
    afkFlag:SetWidth(340)
    afkFlag:SetPoint("TOPLEFT", 392, B0 - 48)
    afkFlag:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ns:Tr("Also mark my character as away then"))
        GameTooltip:AddLine(ns:Tr("With an idle time set, the screen appears on Fantasy Glass UI's own clock. Ticking this also sets you to away at that moment, as /afk does. The game still marks you away by itself after about five minutes: no add-on can make that later."), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    afkFlag:HookScript("OnLeave", function() GameTooltip:Hide() end)
    local afkHint = page:CreateFontString(nil, "OVERLAY")
    ns:Font(afkHint, 11)
    afkHint:SetPoint("TOPLEFT", 392, B0 - 20)
    afkHint:SetWidth(340)
    afkHint:SetJustifyH("LEFT")
    ns:Paint(afkHint, "SetTextColor", "faint")
    local A0 = B0 - 84
    Header(page, "Custom alerts", 0, A0)
    local ab = CreateFrame("Frame", nil, page)
    ab:SetPoint("TOPLEFT", 0, A0 - 30)
    ab:SetSize(736, 300)
    local alertEditor = ns.BuildAlertEditor and ns.BuildAlertEditor(ab)
    local P0 = A0 - 30 - 300 - 10
    Header(page, "Spoken alerts", 0, P0, { sub = true })
    local sb = CreateFrame("Frame", nil, page)
    sb:SetPoint("TOPLEFT", 0, P0 - 30)
    sb:SetSize(736, 130)
    if ns.BuildSpeakEditor then ns.BuildSpeakEditor(sb) end
    local S = P0 - 30 - 130 - 16                             -- where the buff alerts start

    local function Boxes(title, note, y, count, saved)
        Header(page, title, 0, y)
        local n = page:CreateFontString(nil, "OVERLAY")
        ns:Font(n, 11)
        n:SetPoint("TOPLEFT", 0, y - 20)
        n:SetWidth(730)
        n:SetJustifyH("LEFT")
        n:SetText(ns:Tr(note))
        ns:Paint(n, "SetTextColor", "faint")
        local boxes = {}
        for i = 1, count do
            local eb = ns:CreateEditBox(page, 235, 22, "Spell name")
            eb:SetPoint("TOPLEFT", ((i - 1) % 3) * 245, y - 44 - math.floor((i - 1) / 3) * 28)
            if type(saved[i]) == "string" then eb:SetText(saved[i]) end
            boxes[i] = eb
        end
        return boxes
    end
    local function Read(boxes)
        local list = {}
        for _, eb in ipairs(boxes) do
            local t = eb:GetText()
            t = type(t) == "string" and strtrim(t) or ""
            if t ~= "" then list[#list + 1] = t end
        end
        return list
    end

    local alerts, cdTop
    if ns.aurasLocked then
        Header(page, "Buff alerts", 0, S)
        local gone = page:CreateFontString(nil, "OVERLAY")
        ns:Font(gone, 11)
        gone:SetPoint("TOPLEFT", 0, S - 24)
        gone:SetWidth(730)
        gone:SetJustifyH("LEFT")
        gone:SetText(ns:Tr("Not shown here: buff alerts and \"only my debuffs\". This game client hides buffs and debuffs from add-ons during combat, so they would have nothing to work with."))
        ns:Paint(gone, "SetTextColor", "faint")
        cdTop = S - 70
    else
        alerts = Boxes("Buff alerts", "When one of these buffs is on you, its icon pops up above the middle of the screen with its time left.", S, 6, ns.db.alertBuffs)
        local bmsg = page:CreateFontString(nil, "OVERLAY")
        ns:Font(bmsg, 12)
        local applyB = ns:CreateButton(page, "Apply", 150, 26, function()
            ns.db.alertBuffs = Read(alerts)
            if ns.RefreshAlerts then pcall(ns.RefreshAlerts) end
            bmsg:SetText(ns:SignalHex("good") .. format(ns:Tr(#ns.db.alertBuffs == 1 and "%d buff alert set." or "%d buff alerts set."), #ns.db.alertBuffs) .. "|r")
        end)
        applyB:SetPoint("TOPLEFT", 0, S - 44 - 2 * 28 - 6)
        bmsg:SetPoint("LEFT", applyB, "RIGHT", 14, 0)
        page.applyBuffs = applyB
        cdTop = S - 44 - 2 * 28 - 6 - 26 - 24
    end
    local cds = Boxes("Cooldown tracker", "A row of these abilities with their cooldowns. Type each spell's name exactly as in your spellbook. Spells you don't know are skipped.", cdTop, 9, ns.db.cooldownSpells)

    local apply = ns:CreateButton(page, "Apply", 150, 26, function()
        ns.db.cooldownSpells = Read(cds)
        if alerts then ns.db.alertBuffs = Read(alerts) end
        local found = ns.RebuildCooldowns and ns:RebuildCooldowns()
        if ns.RefreshAlerts then pcall(ns.RefreshAlerts) end
        if found then
            msg:SetText(ns:SignalHex("good") .. format(ns:Tr("%d of %d cooldown spells found."), found, #ns.db.cooldownSpells) .. "|r")
        else
            msg:SetText("|cffffd100" .. ns:Tr("Saved. Turn on the cooldown tracker and reload to see it.") .. "|r")
        end
    end)
    apply:SetPoint("TOPLEFT", 0, cdTop - 44 - 3 * 28 - 6)

    -- fill the cooldown list from what is on the action bars, then apply it
    local fill = ns:CreateButton(page, "Fill from action bars", 190, 26, function()
        local names = ns:CooldownCandidates(#cds)
        if #names == 0 then
            msg:SetText("|cffffd100" .. ns:Tr("No abilities with a cooldown were found on your action bars.") .. "|r")
            return
        end
        for i, eb in ipairs(cds) do eb:SetText(names[i] or "") end
        ns.db.cooldownSpells = Read(cds)
        local found = ns.RebuildCooldowns and ns:RebuildCooldowns()
        msg:SetText(format(ns:SignalHex("good") .. ns:TrN(#names, "%d ability taken from your action bars.", "%d abilities taken from your action bars.") .. "|r", #names)
            .. (found and "" or "  " .. ns:Tr("Turn on the cooldown tracker and reload to see it.")))
    end)
    fill:SetPoint("LEFT", apply, "RIGHT", 10, 0)
    msg:ClearAllPoints()
    msg:SetPoint("LEFT", fill, "RIGHT", 14, 0)
    msg:SetWidth(360)
    msg:SetJustifyH("LEFT")
    local cdBottom = cdTop - 44 - 3 * 28 - 6 - 26

    page.Refresh = function()
        -- the lists show what is saved now (the setup, or "Fill from action bars", may have changed it)
        for i, eb in ipairs(cds) do eb:SetText(type(ns.db.cooldownSpells) == "table" and ns.db.cooldownSpells[i] or "") end
        if alerts then for i, eb in ipairs(alerts) do eb:SetText(type(ns.db.alertBuffs) == "table" and ns.db.alertBuffs[i] or "") end end
        afkSlider:SetValue(tonumber(ns.db.afkDelay) or 0)
        afkFlag:SetChecked(ns.db.afkFlag)
        afkHint:SetText(ns:Tr(ns.db.afkScreen and "Idle means no moving, casting, targeting or mouse movement."
            or "The AFK screen is switched off, above, so these do nothing yet."))
    end
    -- Click casting is a section of this tab (it used to be a tab of its own).
    local ccTop = cdBottom - 24
    Header(page, "Click casting", 0, ccTop)
    local cc = CreateFrame("Frame", nil, page)
    cc:SetPoint("TOPLEFT", 0, ccTop - 30)
    cc:SetSize(736, 400)
    BuildClickCast(cc)
    page.clickCast = cc
    local combatRefresh = page.Refresh
    page.Refresh = function()
        if combatRefresh then combatRefresh() end
        if cc.Refresh then cc.Refresh() end
        if alertEditor then alertEditor.Refresh() end
    end
    page.contentHeight = -(ccTop - 30) + 400 + 10
    if page.area then page.area:SetContentHeight(page.contentHeight) end
    ns.combatPage = page
    page.cooldownBoxes, page.buffBoxes = cds, alerts           -- (for the tests)
    page.Refresh()
end

O.BuildCombat = BuildCombat
