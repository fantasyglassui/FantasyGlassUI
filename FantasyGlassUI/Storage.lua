local _, ns = ...

-- Storage: remembers what every character carries, keeps in the bank, and what is in the guild bank,
-- then shows any of it from anywhere. The game only lets add-ons read a bank while it is open, so each
-- one is recorded when you visit it. Saved account-wide (outside profiles).

local SIZE, GAP, COLS, PAD = 36, 4, 10, 12

local function Ago(t)
    if type(t) ~= "number" then return ns:Tr("never recorded") end
    return format(ns:Tr("recorded %s"), ns.Ago(time() - t))
end

local function Scan(bagList)
    local C, items = C_Container, {}
    for _, bag in ipairs(bagList) do
        local n = tonumber(C.GetContainerNumSlots(bag)) or 0
        for slot = 1, n do
            local info = C.GetContainerItemInfo(bag, slot)
            if info and type(info.hyperlink) == "string" then
                items[#items + 1] = { info.hyperlink, info.stackCount or 1, info.quality or 1, info.iconFileID }
            end
        end
    end
    return items
end

ns:NewModule("storage", function()
    local C = C_Container
    if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return end
    local th = ns.theme

    -- Saved data ------------------------------------------------------------------------------
    local root = ns.root
    if type(root.inventory) ~= "table" then root.inventory = {} end
    local inv = root.inventory
    if type(inv.chars) ~= "table" then inv.chars = {} end
    if type(inv.guilds) ~= "table" then inv.guilds = {} end

    local myKey = ns:CharKey()
    if type(inv.chars[myKey]) ~= "table" then inv.chars[myKey] = {} end
    local me = inv.chars[myKey]
    local _, class = UnitClass("player")
    me.class = class

    local bagList = ns.BagList or { 0, 1, 2, 3, 4 }
    local bankList = ns.BankBagList and ns.BankBagList() or {}

    local Refresh       -- viewer refresh, defined below

    local function SaveBags()
        me.bags, me.money, me.time = Scan(bagList), GetMoney(), time()
    end
    local function BankOpen()
        local bank = _G.BankFrame
        return type(bank) == "table" and bank.IsShown and bank:IsShown()
    end
    local function SaveBank()
        if not BankOpen() then return end
        me.bank, me.bankTime = Scan(bankList), time()
    end
    local function SaveGuild()
        if not (GetGuildInfo and GetCurrentGuildBankTab and GetGuildBankItemLink and GetGuildBankItemInfo) then return end
        local gname = GetGuildInfo("player")
        if type(gname) ~= "string" or gname == "" then return end
        local realm = GetRealmName and GetRealmName() or ""
        local gkey = gname .. " - " .. (type(realm) == "string" and realm or "")
        me.guild = gkey
        if type(inv.guilds[gkey]) ~= "table" then inv.guilds[gkey] = { tabs = {} } end
        local g = inv.guilds[gkey]
        if type(g.tabs) ~= "table" then g.tabs = {} end
        local tab = GetCurrentGuildBankTab()          -- the game only sends the tab you are looking at
        if type(tab) ~= "number" or tab < 1 then return end
        local items = {}
        for slot = 1, 98 do
            local link = GetGuildBankItemLink(tab, slot)
            if type(link) == "string" then
                local tex, count, _, _, quality = GetGuildBankItemInfo(tab, slot)
                items[#items + 1] = { link, count or 1, quality or 1, tex }
            end
        end
        local name = GetGuildBankTabInfo and GetGuildBankTabInfo(tab)
        g.tabs[tab] = { name = type(name) == "string" and name ~= "" and name or format(ns:Tr("Tab %d"), tab), items = items }
        g.time = time()
    end

    -- Item counts ---------------------------------------------------------------------------------
    -- index[itemID][owner] = { bags = n, bank = n, guild = n }; rebuilt lazily whenever something was saved.
    local index
    local function ItemID(link)
        return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
    end
    local function BuildIndex()
        index = {}
        local function add(list, owner, field)
            for _, it in ipairs(list or {}) do
                local id = ItemID(it[1])
                if id then
                    index[id] = index[id] or {}
                    local o = index[id][owner]
                    if not o then o = { bags = 0, bank = 0, guild = 0 }; index[id][owner] = o end
                    o[field] = o[field] + (tonumber(it[2]) or 1)
                end
            end
        end
        for key, c in pairs(inv.chars) do
            add(c.bags, key, "bags")
            add(c.bank, key, "bank")
        end
        for gkey, g in pairs(inv.guilds) do
            for _, tab in pairs(type(g.tabs) == "table" and g.tabs or {}) do add(tab.items, "guild:" .. gkey, "guild") end
        end
    end

    -- record a moment after things settle, not on every single event
    local pending = { bags = true }
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_MONEY", "PLAYER_ENTERING_WORLD", "PLAYERBANKSLOTS_CHANGED",
                         "BANKFRAME_OPENED", "GUILDBANKBAGSLOTS_CHANGED", "GUILDBANKFRAME_OPENED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", ns:Guard("Storage events", function(_, event)
        if event == "GUILDBANKBAGSLOTS_CHANGED" or event == "GUILDBANKFRAME_OPENED" then
            pending.guild = true
        elseif event == "PLAYERBANKSLOTS_CHANGED" or event == "BANKFRAME_OPENED" then
            pending.bank = true
        else
            pending.bags = true
            pending.bank = true          -- bank bags are containers too; only saved while the bank is open
        end
    end))
    local acc = 0
    ev:SetScript("OnUpdate", ns:Guard("Storage", function(_, e)
        acc = acc + e
        if acc < 1 then return end
        acc = 0
        local changed = false
        if pending.bags then pending.bags = nil; SaveBags(); changed = true end
        if pending.bank then pending.bank = nil; if BankOpen() then SaveBank(); changed = true end end
        if pending.guild then pending.guild = nil; SaveGuild(); changed = true end
        if changed then index = nil end                      -- counts are rebuilt the next time a tooltip asks
        if changed and Refresh then Refresh() end
    end))

    -- Viewer ------------------------------------------------------------------------------------------
    local win, sel, view = nil, myKey, "bags"
    local buttons, headers = {}, {}
    local query = ""

    -- What to call a stored character: just the name, unless your characters are on different realms.
    local function Label(key, chars)
        local name = type(key) == "string" and key:match("^(.-) %- .+$")
        if not name then return tostring(key) end
        local first
        for other in pairs(chars or inv.chars) do
            local realm = type(other) == "string" and other:match("^.- %- (.+)$")
            if realm then
                if first == nil then first = realm elseif realm ~= first then return key end
            end
        end
        return name
    end
    ns.StorageLabel = Label

    local function ClassHex(key)
        local r, g, b = ns:ClassRGB(inv.chars[key] and inv.chars[key].class)
        if r then return format("|cff%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5)) end
        return "|cffffffff"
    end

    local function Build()
        win = CreateFrame("Frame", "FantasyGlassUIStorage", UIParent, ns.template)
        win:SetSize(PAD * 2 + COLS * SIZE + (COLS - 1) * GAP, 220)
        win:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        win:SetFrameStrata("HIGH")
        win:SetBackdrop(ns.BACKDROP)
        ns:Paint(win, "SetBackdropColor", "window", 0.96)
        ns:Paint(win, "SetBackdropBorderColor", "@border", 1)
        ns:Dress(win)
        win:EnableMouse(true)
        win:SetMovable(true)
        win:SetClampedToScreen(true)
        win:RegisterForDrag("LeftButton")
        win:SetScript("OnDragStart", win.StartMoving)
        win:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local point, _, relPoint, x, y = self:GetPoint()
            ns.db.pos.storage = { point, relPoint, x, y }
        end)
        win:Hide()
        tinsert(UISpecialFrames, "FantasyGlassUIStorage")

        win.title = ns:NewText(win, 18, "LEFT", true)
        win.title:SetPoint("TOPLEFT", PAD, -12)
        win.title:SetText(ns:AccentHex() .. ns:Tr("Storage") .. "|r")
        local close = ns:CreateButton(win, "X", 22, 22, function() win:Hide() end)
        close:SetPoint("TOPRIGHT", -8, -8)

        -- character picker
        -- A character is kept as "Name - Realm". Realm names can be very long, and the realm only
        -- matters when your characters are on more than one, so it is only shown then. The full
        -- name is always in the tooltip.
        local list = CreateFrame("Frame", nil, win, ns.template)
        list:SetFrameStrata("DIALOG")
        list:SetBackdrop(ns.BACKDROP)
        ns:Paint(list, "SetBackdropColor", "window", 0.98)
        ns:Paint(list, "SetBackdropBorderColor", "@border", 1)
        list:Hide()
        local rows = {}
        win.who = ns:CreateButton(win, "", 190, 22, function()
            if list:IsShown() then list:Hide() return end
            local names = {}
            for key in pairs(inv.chars) do names[#names + 1] = key end
            table.sort(names, function(a, b)
                if a == myKey then return true end
                if b == myKey then return false end
                return a < b
            end)
            for i, key in ipairs(names) do
                local r = rows[i]
                if not r then
                    r = CreateFrame("Button", nil, list)
                    r:SetSize(200, 20)
                    r:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 20)
                    r.bg = r:CreateTexture(nil, "BACKGROUND")
                    r.bg:SetAllPoints()
                    r.bg:SetTexture(ns.FLAT)
                    r.bg:SetVertexColor(1, 1, 1, 0)
                    r.text = ns:NewText(r, 12, "LEFT")
                    r.text:SetPoint("LEFT", 6, 0)
                    r:SetScript("OnEnter", function(self) ns:Paint(self.bg, "SetVertexColor", "@accent", 0.3) end)
                    r:SetScript("OnLeave", function(self) self.bg:SetVertexColor(1, 1, 1, 0) end)
                    r:SetScript("OnClick", function(self) sel = self.key; list:Hide(); Refresh() end)
                    rows[i] = r
                end
                r.key = key
                r.text:SetText(ClassHex(key) .. Label(key) .. "|r" .. (key == myKey and ("  |cff9c8c6c(" .. ns:Tr("you") .. ")|r") or ""))
                r:Show()
            end
            for i = #names + 1, #rows do rows[i]:Hide() end
            local widest = 0                                 -- the list is as wide as its longest name
            for i = 1, #names do
                local w = rows[i].text:GetStringWidth()
                if type(w) == "number" and w > widest then widest = w end
            end
            local listW = math.max(212, widest + 30)
            for i = 1, #names do rows[i]:SetWidth(listW - 12) end
            list:SetSize(listW, #names * 20 + 12)
            list:Show()
        end)
        win.who:SetPoint("LEFT", win.title, "RIGHT", 12, 0)
        win.who.text:SetWordWrap(false)                      -- one line; cut short with "..." if it must be
        if win.who.text.SetNonSpaceWrap then win.who.text:SetNonSpaceWrap(false) end
        win.who:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(tostring(sel or myKey))
            GameTooltip:AddLine(ns:Tr("Click to look at another of your characters."), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        win.who:HookScript("OnLeave", function() GameTooltip:Hide() end)
        -- The box grows to fit the name, as far as the close button; a name longer than that is cut short.
        function win.FitWho()
            local text = win.who.text
            local natural = (text.GetUnboundedStringWidth and text:GetUnboundedStringWidth()) or text:GetStringWidth()
            if type(natural) ~= "number" then natural = 120 end
            local titleW, winW = win.title:GetStringWidth(), win:GetWidth()
            if type(titleW) ~= "number" then titleW = 80 end
            if type(winW) ~= "number" then winW = 500 end
            local room = winW - PAD - titleW - 12 - 40
            local w = math.max(110, math.min(room, natural + 26))
            win.who:SetWidth(w)
            text:SetWidth(w - 14)
            return w
        end
        list:SetPoint("TOPLEFT", win.who, "BOTTOMLEFT", 0, -2)

        -- view tabs
        win.tabs = {}
        local prev
        for _, d in ipairs({ { "bags", "Bags" }, { "bank", "Bank" }, { "guild", "Guild Bank" } }) do
            local b = ns:CreateButton(win, d[2], 84, 22, function() view = d[1]; Refresh() end)
            if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", PAD, -38) end
            win.tabs[d[1]] = b
            prev = b
        end
        local search = ns:CreateEditBox(win, 150, 22, "Search")
        search:SetPoint("LEFT", prev, "RIGHT", 10, 0)
        search:SetWidth(math.max(80, math.min(150, win:GetWidth() - PAD * 2 - 3 * 84 - 2 * 4 - 10)))   -- (ends inside the window)
        search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
        search:HookScript("OnTextChanged", function(self)
            local t = self:GetText()
            query = type(t) == "string" and t:lower() or ""
            Refresh()
        end)

        -- the items scroll: a guild bank's six tabs, or a large bank, would be far taller than the screen
        win.area, win.sheet = ns:ScrollArea(win, COLS * SIZE + (COLS - 1) * GAP, 100)
        win.area:SetPoint("TOPLEFT", PAD, -70)
        win.note = ns:NewText(win, 12, "LEFT")
        win.note:SetPoint("TOPLEFT", PAD, -74)
        win.note:SetWidth(win:GetWidth() - PAD * 2)
        win.note:SetWordWrap(true)
        ns:Paint(win.note, "SetTextColor", "text")
        win.foot = ns:NewText(win, 11, "LEFT")
        win.foot:SetPoint("BOTTOMLEFT", PAD, 9)
        ns:Paint(win.foot, "SetTextColor", "dim")
        win.money = ns:NewText(win, 12, "RIGHT")
        win.money:SetPoint("BOTTOMRIGHT", -PAD, 9)

        ns:RegisterMovable(win, "storage", "Storage")
    end

    local function Item(i)
        local b = buttons[i]
        if b then return b end
        b = CreateFrame("Button", nil, win.sheet)
        b:SetSize(SIZE, SIZE)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetTexture(ns.FLAT)
        ns:Paint(b.bg, "SetVertexColor", "bg3", 0.9)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 1, -1)
        b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.count = ns:NewText(b, 11, "RIGHT")
        b.count:SetPoint("BOTTOMRIGHT", -2, 2)
        ns:AddBorder(b, 0, 0, 0, 1, 0)
        b:EnableMouseWheel(true)                             -- (the wheel over an item scrolls the list)
        b:SetScript("OnMouseWheel", function(_, delta) win.area:Scroll(-(tonumber(delta) or 0) * 42) end)
        b:SetScript("OnEnter", function(self)
            if not self.link then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if not pcall(GameTooltip.SetHyperlink, GameTooltip, self.link) then GameTooltip:Hide() return end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnClick", function(self)            -- shift-click links it to chat, like any item
            if self.link and IsModifiedClick and IsModifiedClick() and HandleModifiedItemClick then HandleModifiedItemClick(self.link) end
        end)
        buttons[i] = b
        return b
    end

    function Refresh()
        if not win or not win:IsShown() then return end
        local who = inv.chars[sel]
        if not who then sel = myKey; who = me end
        win.who.text:SetWidth(0)                             -- (let it measure the whole name before fitting)
        win.who.text:SetText(ClassHex(sel) .. Label(sel) .. "|r")
        win.FitWho()
        for key, b in pairs(win.tabs) do
            if key == view then b:SetBackdropColor(th.accent[1] * 0.35, th.accent[2] * 0.35, th.accent[3] * 0.35, 1)
            else ns:Paint(b, "SetBackdropColor", "plate", 1) end
        end

        -- what to show
        local sections, stamp, empty = {}, nil, nil   -- luacheck: ignore
        if view == "bags" then
            sections[1] = { items = who.bags }
            stamp, empty = who.time, "Nothing recorded for this character yet. Log in on it once."
        elseif view == "bank" then
            sections[1] = { items = who.bank }
            stamp, empty = who.bankTime, "This character's bank hasn't been recorded. Visit a banker on it once."
        else
            local g = who.guild and inv.guilds[who.guild]
            if g and type(g.tabs) == "table" then
                local idx = {}
                for tab in pairs(g.tabs) do idx[#idx + 1] = tab end
                table.sort(idx)
                for _, tab in ipairs(idx) do sections[#sections + 1] = { title = g.tabs[tab].name, items = g.tabs[tab].items } end
                stamp = g.time
            end
            empty = "No guild bank recorded for this character. Open the guild bank and click through its tabs once."
        end

        for _, h in ipairs(headers) do h:Hide() end
        local n, hi, y, total = 0, 0, 0, 0                  -- (y: down from the top of the scrolling sheet)
        for _, sec in ipairs(sections) do
            local shown = {}
            for _, it in ipairs(sec.items or {}) do
                local name = type(it[1]) == "string" and it[1]:match("%[(.-)%]") or ""
                if query == "" or name:lower():find(query, 1, true) then shown[#shown + 1] = it end
            end
            if #shown > 0 then
                if sec.title then
                    hi = hi + 1
                    local h = headers[hi]
                    if not h then
                        h = ns:NewText(win.sheet, 11, "LEFT")
                        ns:Paint(h, "SetTextColor", "@accent")
                        headers[hi] = h
                    end
                    h:ClearAllPoints()
                    h:SetPoint("TOPLEFT", win.sheet, "TOPLEFT", 0, y)
                    h:SetText(sec.title .. "  |cff9c8c6c" .. #shown .. "|r")
                    h:Show()
                    y = y - 16
                end
                for i, it in ipairs(shown) do
                    n = n + 1
                    local b = Item(n)
                    local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", win.sheet, "TOPLEFT", col * (SIZE + GAP), y - row * (SIZE + GAP))
                    b.link = it[1]
                    b.icon:SetTexture(it[4])
                    b.count:SetText((type(it[2]) == "number" and it[2] > 1) and it[2] or "")
                    local q = it[3]
                    local c = type(q) == "number" and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
                    if c and q > 1 then b.suiBorder:SetBackdropBorderColor(c.r, c.g, c.b, 1)
                    elseif q == 0 then b.suiBorder:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
                    else ns:Paint(b.suiBorder, "SetBackdropBorderColor", "border", 1) end
                    b:Show()
                end
                y = y - math.ceil(#shown / COLS) * (SIZE + GAP) - 6
                total = total + #shown
            end
        end
        for i = n + 1, #buttons do buttons[i]:Hide() end

        local content = -y
        local screen = UIParent:GetHeight()
        if type(screen) ~= "number" or ns:IsSecret(screen) or screen <= 0 then screen = 768 end
        local shownH = math.min(content, math.max(200, screen * 0.8 - 110))   -- (taller than that, and it scrolls)
        win.area:SetHeight(math.max(1, shownH))
        win.area:SetContentHeight(content)
        win.area:ScrollTo(0)
        if total == 0 then
            win.note:SetText(ns:Tr(query ~= "" and "Nothing here matches your search." or empty))
            win.note:Show()
            shownH = 44
        else
            win.note:Hide()
        end
        win:SetHeight(70 + shownH + 30)
        win.foot:SetText(total .. (total == 1 and (" " .. ns:Tr("stack")) or (" " .. ns:Tr("stacks"))) .. "   |cff9c8c6c" .. Ago(stamp) .. "|r")
        win.money:SetText(view == "guild" and "" or ns:Coins(who.money))
    end

    -- Who has this item: { [owner] = { bags, bank, guild } }, and the key of the character being played.
    -- (12.4) A number item id is taken too, as "item:N": /fgui shop and the skill-up list pass one.
    function ns:ItemOwners(link)
        if type(link) == "number" and link == math.floor(link) then link = "item:" .. string.format("%d", link) end
        local id = ItemID(link)
        if not id then return nil, myKey end
        if not index then BuildIndex() end
        return index[id], myKey
    end
    -- Adds "who has how many" lines to an item tooltip. Returns true if it added anything.
    function ns:AddItemCounts(tip, link)
        local id = ItemID(link)
        if not id then return false end
        if not index then BuildIndex() end
        local owners = index[id]
        if not owners then return false end

        local names = {}
        for owner in pairs(owners) do names[#names + 1] = owner end
        table.sort(names, function(a, b)
            if a == myKey then return true end
            if b == myKey then return false end
            return a < b
        end)
        local total, lines = 0, 0
        for _, owner in ipairs(names) do
            local o = owners[owner]
            local sum = o.bags + o.bank + o.guild
            if sum > 0 then
                local left, right
                if o.guild > 0 then
                    left = "|cff66dd88" .. owner:gsub("^guild:", ""):gsub(" %- .*$", "") .. " (" .. ns:Tr("guild bank") .. ")|r"
                    right = tostring(o.guild)
                else
                    left = ClassHex(owner) .. owner:gsub(" %- .*$", "") .. "|r"
                    if o.bags > 0 and o.bank > 0 then
                        right = format("%d  |cff9aa4b4(" .. ns:Tr("bags %d, bank %d") .. ")|r", sum, o.bags, o.bank)
                    elseif o.bank > 0 then
                        right = format("%d  |cff9aa4b4(%s)|r", sum, ns:Tr("bank"))
                    else
                        right = tostring(sum)
                    end
                end
                if lines == 0 then tip:AddLine(" ") end
                tip:AddDoubleLine(left, right, 1, 1, 1, 1, 1, 1)
                total, lines = total + sum, lines + 1
            end
        end
        if lines > 1 then
            tip:AddDoubleLine(ns:Tr("Total"), tostring(total), th.accent[1], th.accent[2], th.accent[3], th.accent[1], th.accent[2], th.accent[3])
        end
        return lines > 0
    end

    -- Open the viewer: view is "bags", "bank" or "guild"; who defaults to this character
    function ns:OpenStorage(openView, who)
        if not win then Build() end
        if openView == "bags" or openView == "bank" or openView == "guild" then view = openView end
        sel = (who and inv.chars[who]) and who or sel
        win:Show()
        Refresh()
    end

    SLASH_FANTASYGLASSUISTORAGE1 = "/storage"
    SlashCmdList["FANTASYGLASSUISTORAGE"] = function() ns:OpenStorage() end
end)
