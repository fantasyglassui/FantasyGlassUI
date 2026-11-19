local _, ns = ...

-- Our own loot-roll frames: item, Need / Greed / Pass, and a bar counting down.
-- (This game has no Disenchant roll, so there is no button for one.)
-- Blizzard's roll windows are told not to open (the two roll events are unregistered from UIParent).
ns:NewModule("lootRoll", function()
    if not (GetLootRollItemInfo and RollOnLoot and GetLootRollTimeLeft) then return end
    local th = ns.theme
    local W, H, MAX = 310, 46, 4

    local anchor = CreateFrame("Frame", "FantasyGlassUILootRolls", UIParent)
    anchor:SetSize(W, MAX * (H + 6))
    anchor:SetPoint("TOP", UIParent, "TOP", 0, -190)
    local rows = {}

    local function Row(i)
        if rows[i] then return rows[i] end
        local r = CreateFrame("Frame", nil, anchor, ns.template)
        r:SetSize(W, H)
        r:SetPoint("TOP", anchor, "TOP", 0, -(i - 1) * (H + 6))
        r:SetBackdrop(ns.BACKDROP)
        ns:Paint(r, "SetBackdropColor", "window", 0.92)
        ns:Paint(r, "SetBackdropBorderColor", "@border", 1)
        ns:Dress(r, true)
        r.iconBox = CreateFrame("Button", nil, r)
        r.iconBox:SetSize(34, 34)
        r.iconBox:SetPoint("LEFT", 6, 2)
        r.icon = r.iconBox:CreateTexture(nil, "ARTWORK")
        r.icon:SetAllPoints()
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        ns:AddBorder(r.iconBox, 0, 0, 0, 1)
        r.upgrade = ns:NewText(r.iconBox, 14, "LEFT")           -- a green arrow on gear better than what you wear
        r.upgrade:SetPoint("BOTTOMLEFT", 1, 1)
        r.upgrade:SetText("|cff33ff55^|r")
        r.upgrade:Hide()
        r.iconBox:SetScript("OnEnter", function(self)
            if not r.rollID or r.sample then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if pcall(GameTooltip.SetLootRollItem, GameTooltip, r.rollID) then GameTooltip:Show() else GameTooltip:Hide() end
        end)
        r.iconBox:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r.name = ns:NewText(r, 12, "LEFT")
        r.name:SetPoint("TOPLEFT", 48, -6)
        r.name:SetPoint("RIGHT", -8, 0)
        r.buttons = {}
        for k, d in ipairs({ { "Need", 1 }, { "Greed", 2 }, { "Pass", 0 } }) do
            local b = ns:CreateButton(r, d[1], 78, 18, function()
                if r.rollID and not r.sample then pcall(RollOnLoot, r.rollID, d[2]) end
                r:Hide()
                r.rollID = nil
            end)
            ns:Font(b.text, 10)
            b:SetPoint("BOTTOMLEFT", 48 + (k - 1) * 84, 7)
            r.buttons[d[2]] = b
        end
        r.timer = ns:NewStatusBar(r)
        r.timer:SetHeight(3)
        r.timer:SetPoint("BOTTOMLEFT", 1, 1)
        r.timer:SetPoint("BOTTOMRIGHT", -1, 1)
        ns:Paint(r.timer, "SetStatusBarColor", "@accent")
        r:Hide()
        rows[i] = r
        return r
    end

    local function Free()
        for i = 1, MAX do
            local r = Row(i)
            if not r:IsShown() then return r end
        end
    end

    local function Open(rollID, rollTime)
        local texture, name, count, quality, _, canNeed, canGreed = GetLootRollItemInfo(rollID)
        if not name then return end
        local r = Free()
        if not r then return end
        r.rollID, r.sample = rollID, nil
        r.icon:SetTexture(texture)
        r.name:SetText(((type(count) == "number" and count > 1) and (count .. "x ") or "") .. tostring(name))
        local c = type(quality) == "number" and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        if c then r.name:SetTextColor(c.r, c.g, c.b) else r.name:SetTextColor(1, 1, 1) end
        local link = GetLootRollItemLink and select(2, pcall(GetLootRollItemLink, rollID))
        if ns.db.upgradeArrows and ns.UpgradeAmount and type(link) == "string" and ns.UpgradeAmount(link) then r.upgrade:Show() else r.upgrade:Hide() end
        local function able(btn, ok) if ns.Is(ok, false) then btn:Hide() else btn:Show() end end
        able(r.buttons[1], canNeed); able(r.buttons[2], canGreed)
        r.total = (type(rollTime) == "number" and rollTime > 0) and rollTime or 60000
        r.timer:SetMinMaxValues(0, r.total)
        r.timer:SetValue(r.total)
        r:Show()
    end

    local QuietTheGames
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("START_LOOT_ROLL")
    ev:RegisterEvent("CANCEL_LOOT_ROLL")
    ev:SetScript("OnEvent", ns:Guard("Loot rolls", function(_, event, rollID, rollTime)
        if event == "START_LOOT_ROLL" then
            QuietTheGames()                                  -- (a roll frame the game has only just made)
            Open(rollID, rollTime)
        else
            for _, r in ipairs(rows) do
                if ns.Is(r.rollID, rollID) and not r.sample then r:Hide(); r.rollID = nil end
            end
        end
    end))

    ns:Every(0.1, "Loot rolls", function()
        for _, r in ipairs(rows) do
            if r:IsShown() and r.rollID and not r.sample then
                local left = GetLootRollTimeLeft(r.rollID)
                if type(left) == "number" then
                    r.timer:SetValue(left)
                    if left <= 0 then r:Hide(); r.rollID = nil end
                end
            end
        end
    end)

    -- The game's own roll windows stay out of the way. On older clients it is enough to stop the
    -- interface hearing about rolls. On newer ones the roll frames listen for themselves, so they are
    -- also made invisible and unclickable. They are never hidden or hooked: the game goes on running
    -- them exactly as it wants to (its timers, its tidying up), it just can't be seen or clicked.
    pcall(UIParent.UnregisterEvent, UIParent, "START_LOOT_ROLL")
    pcall(UIParent.UnregisterEvent, UIParent, "CANCEL_LOOT_ROLL")
    QuietTheGames = function()
        local names = { "GroupLootContainer" }
        for i = 1, 8 do names[#names + 1] = "GroupLootFrame" .. i end
        local n = 0
        for _, name in ipairs(names) do
            local f = _G[name]
            if type(f) == "table" and f.SetAlpha and not (f.IsForbidden and f:IsForbidden()) then
                if not f.suiKilled then
                    ns:Kill(f, true)                         -- kept clear every frame, so it never flashes up
                    ns:Silence(f)                            -- and nothing inside it can take a click
                end
                n = n + 1
            end
        end
        return n
    end
    ns.QuietGameRolls = QuietTheGames
    QuietTheGames()

    ns:RegisterPreview(function(on, mode)
        if on and mode == "showcase" then return end           -- (screenshot mode keeps the screen clear)
        local r = Row(1)
        if on and not r:IsShown() then
            r.sample, r.rollID = true, 0
            r.icon:SetTexture(135349)
            r.name:SetText(ns:Tr("Sample Sword of Testing"))
            r.name:SetTextColor(0.64, 0.21, 0.93)
            if ns.db.upgradeArrows then r.upgrade:Show() end
            for _, b in pairs(r.buttons) do b:Show() end
            r.timer:SetMinMaxValues(0, 1)
            r.timer:SetValue(0.6)
            r:Show()
        elseif not on and r.sample then
            r.sample, r.rollID = nil, nil
            r:Hide()
        end
    end)
    ns:RegisterMovable(anchor, "lootRoll", "Loot rolls")
end)
