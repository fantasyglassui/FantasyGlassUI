local _, ns = ...

------------------------------------------------------------------------------------------
-- Your characters: /fgui alts lists every character this add-on has seen on the account, with level
-- and gold, and the total. Each is recorded as you play it (at login, and whenever its gold or level
-- changes). Right-click a line to forget a character you have deleted.
------------------------------------------------------------------------------------------
function ns:RecordCharacter()
    local root = ns.root
    if type(root) ~= "table" then return nil end
    if type(root.alts) ~= "table" then root.alts = {} end
    local name = UnitName and UnitName("player") or nil
    if type(name) ~= "string" or ns:IsSecret(name) or name == "" then return nil end
    local key = ns:CharKey()
    local entry = type(root.alts[key]) == "table" and root.alts[key] or {}
    entry.name = name
    entry.realm = GetRealmName and GetRealmName() or entry.realm
    local okC, _, class = pcall(UnitClass, "player")
    if okC and type(class) == "string" and not ns:IsSecret(class) then entry.class = class end
    local okL, level = pcall(UnitLevel, "player")
    if okL and type(level) == "number" and not ns:IsSecret(level) then entry.level = level end
    local okG, gold = pcall(GetMoney)
    if okG and type(gold) == "number" and not ns:IsSecret(gold) then entry.gold = gold end
    entry.at = time and time() or 0
    -- more to tell about it: item level, rested experience, professions, mail waiting
    pcall(function()
        if GetAverageItemLevel then local _, worn = GetAverageItemLevel(); if type(worn) == "number" and not ns:IsSecret(worn) then entry.ilvl = math.floor(worn + 0.5) end end
        local rested = GetXPExhaustion and GetXPExhaustion()
        local max = UnitXPMax and UnitXPMax("player")
        if type(max) == "number" and not ns:IsSecret(max) and max > 0 then
            entry.rested = (type(rested) == "number" and not ns:IsSecret(rested)) and math.floor(rested / max * 100 + 0.5) or 0
        end
        if HasNewMail then entry.mail = ns.Yes(HasNewMail()) end
        if GetProfessions and GetProfessionInfo then
            local list = {}
            for _, index in ipairs({ GetProfessions() }) do
                if type(index) == "number" then
                    local pname, _, skill, maxSkill = GetProfessionInfo(index)
                    if type(pname) == "string" and type(skill) == "number" then list[#list + 1] = { name = pname, skill = skill, max = tonumber(maxSkill) or 0 } end
                end
            end
            entry.professions = list
        end
    end)
    root.alts[key] = entry
    return entry
end

-- The characters, richest first, and the total: { { key, name, realm, class, level, gold, current } ... }, total.
function ns:Characters()
    local list, total = {}, 0
    local mine = ns:CharKey()
    for key, e in pairs(type(ns.root) == "table" and type(ns.root.alts) == "table" and ns.root.alts or {}) do
        if type(e) == "table" and type(e.name) == "string" then
            local gold = tonumber(e.gold) or 0
            total = total + gold
            list[#list + 1] = { key = key, name = e.name, realm = e.realm, class = e.class, level = tonumber(e.level), gold = gold, current = (key == mine),
                ilvl = e.ilvl, rested = e.rested, mail = e.mail, professions = e.professions, at = e.at, lockouts = e.lockouts }
        end
    end
    table.sort(list, function(a, b) if a.gold ~= b.gold then return a.gold > b.gold end return a.name < b.name end)
    return list, total
end
function ns:ForgetCharacter(key)
    if key == ns:CharKey() then return false end              -- (not the one you are playing)
    if type(ns.root) == "table" and type(ns.root.alts) == "table" and ns.root.alts[key] then
        ns.root.alts[key] = nil
        return true
    end
    return false
end

-- What the list says about a character when you point at its line.
function ns.AltTip(c, now)
    local lines = { c.name .. (c.realm and (" - " .. c.realm) or "") }
    if c.level then lines[#lines + 1] = format("%s %d", ns:Tr("Level"), c.level) .. (c.ilvl and format("   %s %d", ns:Tr("Item level"), c.ilvl) or "") end
    if c.rested and c.rested > 0 then lines[#lines + 1] = format(ns:Tr("Rested: %d%% of a level"), c.rested) end
    for _, p in ipairs(type(c.professions) == "table" and c.professions or {}) do lines[#lines + 1] = format("%s  %d/%d", p.name, p.skill, p.max) end
    if c.mail then lines[#lines + 1] = ns:Tr("Mail waiting") end
    if c.at and now and not c.current then
        local days = math.floor(math.max(0, now - c.at) / 86400)
        lines[#lines + 1] = (days == 0) and ns:Tr("Played today") or format(ns:TrN(days, "Last played %d day ago", "Last played %d days ago"), days)
    end
    return lines
end

local window
local ROW = 20
function ns:ShowCharacters()
    ns:RecordCharacter()
    if not window then
        window = CreateFrame("Frame", "FantasyGlassUIAlts", UIParent, ns.template)
        window:SetSize(360, 300)
        window:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
        window:SetFrameStrata("DIALOG")
        window:SetBackdrop(ns.BACKDROP)
        ns:Paint(window, "SetBackdropColor", "window", 0.97)
        ns:Paint(window, "SetBackdropBorderColor", "@border", 1)
        ns:Dress(window)
        window:EnableMouse(true)
        window:SetMovable(true)                                  -- (dragged by its edge, and kept where you leave it)
        window:SetClampedToScreen(true)
        window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart", function(self) self:StartMoving() end)
        ns:KeepPlace(window, "Alts")
        if type(UISpecialFrames) == "table" then tinsert(UISpecialFrames, "FantasyGlassUIAlts") end
        window.title = ns:NewText(window, 14, "LEFT")
        window.title:SetPoint("TOPLEFT", 14, -12)
        ns:Paint(window.title, "SetTextColor", "@accent")
        window.title:SetText(ns:Tr("Your characters"))
        local close = ns:CreateButton(window, "X", 22, 20, function() window:Hide() end)
        close:SetPoint("TOPRIGHT", -8, -8)
        window.area, window.sheet = ns:ScrollArea(window, 332, 300 - 40 - 48)
        window.area:SetPoint("TOPLEFT", 14, -40)
        window.total = ns:NewText(window, 12, "RIGHT")
        window.total:SetPoint("BOTTOMRIGHT", -16, 26)
        window.note = ns:NewText(window, 10, "LEFT")
        window.note:SetPoint("BOTTOMLEFT", 14, 9)
        window.note:SetPoint("RIGHT", window, "RIGHT", -14, 0)    -- (kept inside the window in every language)
        window.note:SetTextColor(0.6, 0.6, 0.6)
        window.note:SetText(ns:Tr("Right-click a line twice to forget that character."))
        window.rows = {}
    end
    local list, total = ns:Characters()
    for i, c in ipairs(list) do
        local row = window.rows[i]
        if not row then
            row = CreateFrame("Button", nil, window.sheet)
            row:SetSize(326, ROW)
            row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW)
            row.name = ns:NewText(row, 12, "LEFT")
            row.name:SetPoint("LEFT", 2, 0)
            row.gold = ns:NewText(row, 12, "RIGHT")
            row.gold:SetPoint("RIGHT", -4, 0)
            row.level = ns:NewText(row, 12, "RIGHT")
            row.level:SetPoint("RIGHT", row, "RIGHT", -150, 0)
            row.level:SetTextColor(0.8, 0.8, 0.8)
            row.hl = row:CreateTexture(nil, "HIGHLIGHT")
            row.hl:SetAllPoints()
            row.hl:SetTexture(ns.FLAT)
            row.hl:SetVertexColor(1, 1, 1, 0.08)
            row:SetScript("OnEnter", function(self)
                if not self.c then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                for n, text in ipairs(ns.AltTip(self.c, time and time() or 0)) do
                    if n == 1 then GameTooltip:AddLine(ns:AccentHex() .. text .. "|r") else GameTooltip:AddLine(text, 1, 1, 1) end
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row:RegisterForClicks("RightButtonUp")
            row:SetScript("OnClick", function(self)
                if not self.key then return end
                if self.key == ns:CharKey() then ns:Print("That is the character you are playing."); return end
                -- twice, so a stray click does not lose a character's bags, bank and lockouts
                local now = GetTime()
                if self.armedKey ~= self.key or now - (self.armedAt or 0) > 4 then
                    self.armedKey, self.armedAt = self.key, now
                    ns:Print("Right-click %s again to forget that character.", self.c and self.c.name or self.key)
                    return
                end
                self.armedKey = nil
                if ns:ForgetCharacter(self.key) then
                    ns:Print("Forgot %s.", self.c and self.c.name or self.key)
                    ns:ShowCharacters()
                end
            end)
            window.rows[i] = row
        end
        row.key, row.c = c.key, c
        row.name:SetText(c.name .. (c.current and "  *" or "") .. (c.mail and "  |TInterface\\Minimap\\Tracking\\Mailbox:14:14|t" or ""))
        local ok, r, g, b = pcall(function() return ns:ClassRGB(c.class) end)
        if ok and type(r) == "number" then row.name:SetTextColor(r, g, b) else row.name:SetTextColor(1, 1, 1) end
        row.level:SetText(c.level and tostring(c.level) or "")
        row.gold:SetText(ns:Coins(c.gold))
        row:Show()
    end
    for i = #list + 1, #window.rows do window.rows[i]:Hide() end
    if window.area.SetContentHeight then window.area:SetContentHeight(#list * ROW) end
    window.total:SetText(ns:Tr("Total") .. ":  " .. ns:Coins(total))
    window:Show()
    return window, list, total
end

do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_MONEY", "PLAYER_LEVEL_UP", "PLAYER_LOGOUT" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Characters", function(_, event)
        if event == "PLAYER_LOGIN" then ns:After(3, function() pcall(ns.RecordCharacter, ns) end)
        else ns:RecordCharacter() end
    end))
end
