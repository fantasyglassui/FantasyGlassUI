local _, ns = ...

-- One window per container set: the bags, and the bank. Categories or plain grid, search, sort,
-- quality borders. Blizzard's own frames stay the "source of truth" for open/closed (so B, vendors,
-- the banker and the bag button all keep working); they are made invisible and ours mirror them.

local SIZE, GAP, COLS, PAD = 36, 4, 10, 12
local TOP, FOOT = 66, 30
local ORDER = { "Equipment", "Consumables", "Quest", "Trade Goods", "Other", "Junk" }

local function BagIndex(name, fallback)
    local E = Enum and Enum.BagIndex
    local v = type(E) == "table" and E[name]
    if type(v) == "number" then return v end
    return fallback
end

-- This client's bank is a row of purchasable tabs; each tab holds a bag, and each of those is a container.
local function BankBags()
    local list = {}
    local E = Enum and Enum.BagIndex
    if type(E) == "table" then
        for i = 1, 12 do
            local id = E["CharacterBankTab_" .. i]
            if type(id) == "number" then list[#list + 1] = id end
        end
        if #list == 0 and type(E.BankBag_1) == "number" then          -- older bank layout
            if type(E.Bank) == "number" then list[#list + 1] = E.Bank end
            for i = 1, 7 do
                local id = E["BankBag_" .. i]
                if type(id) == "number" then list[#list + 1] = id end
            end
        end
    end
    if #list == 0 then for i = 1, 9 do list[i] = 5 + i end end
    return list
end

ns.BankBagList = BankBags

local function NewWindow(cfg)
    local C = C_Container
    local th = ns.theme
    local BAGS = cfg.bags
    local GetInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant

    local win = CreateFrame("Frame", cfg.name, UIParent, ns.template)
    win:SetSize(PAD * 2 + COLS * SIZE + (COLS - 1) * GAP, 200)
    win:SetPoint(cfg.point[1], UIParent, cfg.point[1], cfg.point[2], cfg.point[3])
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
        ns.db.pos[cfg.key] = { point, relPoint, x, y }
    end)
    win:Hide()
    tinsert(UISpecialFrames, cfg.name)

    local title = ns:NewText(win, 18, "LEFT", true)
    title:SetPoint("TOPLEFT", PAD, -12)
    title:SetText(ns:AccentHex() .. cfg.title .. "|r")
    local freeText = ns:NewText(win, 11, "LEFT")
    freeText:SetPoint("LEFT", title, "RIGHT", 10, 0)
    ns:Paint(freeText, "SetTextColor", "dim")
    local money = ns:NewText(win, 12, "LEFT")
    money:SetPoint("BOTTOMLEFT", PAD, 10)
    local note = ns:NewText(win, 12, "LEFT")
    note:SetPoint("TOPLEFT", PAD, -TOP - 4)
    note:SetWidth(win:GetWidth() - PAD * 2)
    note:SetWordWrap(true)
    ns:Paint(note, "SetTextColor", "text")
    note:Hide()

    local dirty = true
    local query = ""
    local showSlots = false            -- the row of equipped bags, toggled by the Slots button
    local gridKey = cfg.key .. "Grid"

    local close = ns:CreateButton(win, "X", 22, 22, function() win:Hide() end)
    close:SetPoint("TOPRIGHT", -8, -8)
    local sortBtn = ns:CreateButton(win, "Sort", 54, 22, function() pcall(cfg.sort) end)
    sortBtn:SetPoint("RIGHT", close, "LEFT", -6, 0)
    local viewBtn
    viewBtn = ns:CreateButton(win, "", 92, 22, function()
        ns.db[gridKey] = not ns.db[gridKey]
        viewBtn.text:SetText(ns.db[gridKey] and "Grid" or "Categories")
        dirty = true
    end)
    viewBtn:SetPoint("RIGHT", sortBtn, "LEFT", -6, 0)
    viewBtn.text:SetText(ns.db[gridKey] and "Grid" or "Categories")
    local extraBtn
    if cfg.extra then
        extraBtn = ns:CreateButton(win, cfg.extra[1], 100, 22, cfg.extra[2])
        extraBtn:SetPoint("BOTTOMRIGHT", -8, 6)
    end

    local search = ns:CreateEditBox(win, 180, 22, "Search")
    search:SetPoint("TOPLEFT", PAD, -36)
    search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)

    -- extra buttons beside the search box (Slots / Bank / Guild / Chars on the bag window)
    local prev
    for _, d in ipairs(cfg.buttons or {}) do
        local b = ns:CreateButton(win, d[1], d[2], 22, d[3])
        if d[4] then ns:ButtonTip(b, d[4]) end
        ns:Font(b.text, 11)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("LEFT", search, "RIGHT", 8, 0) end
        prev = b
    end

    -- Slots ---------------------------------------------------------------------------------
    local slots, headers, overlay = {}, {}, nil

    local function ShowTip(b)
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetBagItem(b.bag, b.slot)
        GameTooltip:Show()
    end

    local OpenPicker                 -- defined further down: the "put this item in a category" list

    -- Using an item. The game lets add-ons do this only through a secure button, so one such button
    -- ("overlay") is kept on top of whichever slot the mouse is over, and it does the using. It can
    -- only be moved outside combat. A right-click that lands on a plain slot instead - the overlay
    -- was elsewhere, or a fight is on - must never try to use the item itself: for anything with a
    -- "Use:" effect the game refuses and shows its "blocked from an action" box.
    local Attach, RightClick, MakeUse, SlotEnter, SlotLeave
    local lastWarned = -100
    local function HasUseEffect(b)
        local link = b.info and b.info.hyperlink
        if not link then return false end
        local get = (C_Item and C_Item.GetItemSpell) or GetItemSpell
        if type(get) ~= "function" then return true end      -- can't tell: treat it as protected, which is always safe
        local ok, spell = pcall(get, link)
        return (not ok) or spell ~= nil
    end
    -- The roaming button must not stay fixed to a slot it is not being used on: whatever a secure
    -- button is anchored to, and whatever that is anchored to in turn (the slot, then this whole
    -- window), the game will not let an add-on show, hide or move during combat. Left attached, it
    -- would stop the bags opening and closing in a fight. So it lets go whenever it steps aside.
    local function LetGo()
        if not overlay or InCombatLockdown() then return false end
        overlay:Hide()
        overlay:ClearAllPoints()
        overlay.target = nil
        return true
    end
    Attach = function(b)
        if b.suiUse then                                        -- this slot has a secure button of its own
            LetGo()
            return true
        end
        if not overlay or InCombatLockdown() then return false end
        if overlay.target == b and overlay:IsShown() then return true end
        overlay.target = b
        overlay:SetAttribute("item", b.bag .. " " .. b.slot)
        overlay:ClearAllPoints()
        overlay:SetAllPoints(b)
        overlay:Show()
        return true
    end
    RightClick = function(b)
        if b.suiUse then return "secure" end                    -- (its own secure button takes the click, not this)
        if not HasUseEffect(b) then                          -- equip, sell, move to the bank: nothing protected about these
            C.UseContainerItem(b.bag, b.slot)
            return "used"
        end
        if InCombatLockdown() then
            if GetTime() - lastWarned > 30 then
                lastWarned = GetTime()
                ns:Print("The game doesn't let an add-on's bag window use an item during combat. Put it on an action bar, or use it before the fight.")
            end
            return "combat"
        end
        Attach(b)                                            -- the secure button is on this slot now: the next click uses the item
        return "attached"
    end
    ns.bagTest = ns.bagTest or {}
    ns.bagTest[cfg.name] = { RightClick = function(b) return RightClick(b) end, Attach = function(b) return Attach(b) end,
                             overlay = function() return overlay end, LetGo = function() return LetGo() end }

    local function LeftClick(b)
        local info = b.info
        local link = info and info.hyperlink
        if info and info.itemID and IsAltKeyDown and IsAltKeyDown() then       -- Alt-click: choose a category for this item
            OpenPicker(b)
            return
        end
        if link and IsModifiedClick and IsModifiedClick() and HandleModifiedItemClick and HandleModifiedItemClick(link) then return end
        -- shift-click a stack to split it: the game's own split box opens, and the split-off part lands on the cursor
        local n = info and info.stackCount
        if n and n > 1 and not info.isLocked and IsModifiedClick and IsModifiedClick("SPLITSTACK") and C.SplitContainerItem then
            b.SplitStack = function(_, amount) C.SplitContainerItem(b.bag, b.slot, amount) end
            if StackSplitFrame and StackSplitFrame.OpenStackSplitFrame then
                StackSplitFrame:OpenStackSplitFrame(n, b, "BOTTOMLEFT", "TOPLEFT")
                return
            elseif OpenStackSplitFrame then
                OpenStackSplitFrame(n, b, "BOTTOMLEFT", "TOPLEFT")
                return
            end
        end
        C.PickupContainerItem(b.bag, b.slot)
    end

    local function Matches(b)
        if query == "" then return true end
        local info = b.info
        if not info then return false end
        local name = type(info.hyperlink) == "string" and info.hyperlink:match("%[(.-)%]") or ""
        if name:lower():find(query, 1, true) then return true end
        if GetInstant and info.itemID then
            local _, itype, isub = GetInstant(info.itemID)
            if type(itype) == "string" and itype:lower():find(query, 1, true) then return true end
            if type(isub) == "string" and isub:lower():find(query, 1, true) then return true end
        end
        return false
    end

    SlotEnter = function(b)
        ShowTip(b)
        b.hl:Show()
        if b.isNew and C_NewItems and C_NewItems.RemoveNewItem then           -- looked at: no longer new
            pcall(C_NewItems.RemoveNewItem, b.bag, b.slot)
            b.isNew = false
            b.newDot:Hide()
        end
        Attach(b)                                            -- the roaming "use" button moves onto this slot
    end
    SlotLeave = function(b) GameTooltip:Hide(); b.hl:Hide() end

    -- Using items in combat (an option, off unless chosen) --------------------------------------------------
    -- The roaming button above cannot be moved during a fight, so in combat a slot has no way to use
    -- its item. With this option each slot instead carries a secure button of its own, fixed to it
    -- when the slot is made and never moved again, so it is there in combat too.
    --
    -- The price: the game does not let an add-on move, show or hide anything a secure button is fixed
    -- to during combat. So while you are fighting the bag window's arrangement is frozen: icons and
    -- counts keep up, but nothing changes place, and the window re-sorts itself when the fight ends.
    --
    -- And one check: on some clients, having secure buttons inside a window stops an add-on opening
    -- or closing that window in combat, which would be worse than what this fixes. If the game says
    -- the window has become protected, the buttons are taken off again and the roaming one is used.
    local secure, pendingLayout, abandoned = 0, false, nil
    local function CombatUse() return cfg.combatUse and ns.db.bagCombatUse and not abandoned and true or false end
    local function EachSlot(fn)
        for _, list in pairs(slots) do
            for _, b in pairs(list) do fn(b) end
        end
    end
    local function TakeOff(reason)                           -- out of combat only
        if InCombatLockdown() then return false end
        EachSlot(function(b)
            if b.suiUse then
                pcall(function() b.suiUse:Hide(); b.suiUse:ClearAllPoints(); b.suiUse:SetParent(ns.hidden or UIParent) end)
                b.suiUse = nil
            end
            b.suiNeedUse = nil
        end)
        secure = 0
        if reason then abandoned = reason end
        return true
    end
    MakeUse = function(b)
        if b.suiUse or not CombatUse() then return end
        if InCombatLockdown() then b.suiNeedUse = true; return end           -- made in a fight: gets its button afterwards
        local ok, u = pcall(CreateFrame, "Button", nil, b, "SecureActionButtonTemplate")
        if not ok or type(u) ~= "table" then abandoned = "this client would not make a secure button"; return end
        u:SetAllPoints(b)
        u:SetFrameLevel((b:GetFrameLevel() or 1) + 3)
        u:RegisterForClicks("AnyUp", "AnyDown")
        u:RegisterForDrag("LeftButton")
        u:SetAttribute("type2", "item")
        u:SetAttribute("item", tostring(b.bag) .. " " .. tostring(b.slot))      -- "bag slot": which item this button uses
        u.target = b
        u:SetScript("PostClick", function(self, button, down)
            if down or button ~= "LeftButton" then return end
            LeftClick(self.target)
        end)
        local function drag(self) C.PickupContainerItem(self.target.bag, self.target.slot) end
        u:SetScript("OnDragStart", drag)
        u:SetScript("OnReceiveDrag", drag)
        u:SetScript("OnEnter", function(self) SlotEnter(self.target) end)
        u:SetScript("OnLeave", function(self) SlotLeave(self.target) end)
        b.suiUse, b.suiNeedUse = u, nil
        secure = secure + 1
        if secure == 1 then                                  -- the check described above, once
            local okp, protected = pcall(win.IsProtected, win)
            if okp and protected then
                TakeOff("on this client a window holding secure buttons cannot be opened in combat, so the roaming button is used instead")
            end
        end
    end
    local function BagUseState()
        if not cfg.combatUse then return nil end
        if abandoned then return "not possible (" .. abandoned .. ")" end
        if not ns.db.bagCombatUse then return "off (switch on \"Bags: use items in combat\" on the Features tab to try it)" end
        return secure > 0 and ("on: " .. secure .. " slots each have their own secure button") or "on, waiting for the bags to be drawn"
    end
    if cfg.combatUse then ns.BagUseState = BagUseState end
    ns.bagTest[cfg.name].win = win
    ns.bagTest[cfg.name].secure = function() return secure end
    ns.bagTest[cfg.name].slots = function() return slots end

    local function GetSlot(bag, slot)
        slots[bag] = slots[bag] or {}
        local b = slots[bag][slot]
        if b then return b end
        b = CreateFrame("Button", nil, win)
        b:SetSize(SIZE, SIZE)
        b.bag, b.slot = bag, slot
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetTexture(ns.FLAT)
        ns:Paint(b.bg, "SetVertexColor", "bg3", 0.9)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 1, -1)
        b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.hl = b:CreateTexture(nil, "OVERLAY")
        b.hl:SetAllPoints()
        b.hl:SetTexture(ns.FLAT)
        b.hl:SetVertexColor(1, 1, 1, 0.2)
        b.hl:Hide()
        local ok, cd = pcall(CreateFrame, "Cooldown", nil, b, "CooldownFrameTemplate")
        if ok and cd then cd:SetAllPoints(b.icon); b.cd = cd end
        local layer = CreateFrame("Frame", nil, b)
        layer:SetAllPoints()
        layer:SetFrameLevel(b:GetFrameLevel() + 4)
        b.count = ns:NewText(layer, 11, "RIGHT")
        b.count:SetPoint("BOTTOMRIGHT", -2, 2)
        b.ilvl = ns:NewText(layer, 10, "LEFT")
        b.ilvl:SetPoint("TOPLEFT", 2, -2)
        b.ilvl:SetTextColor(1, 0.82, 0)
        b.bind = ns:NewText(layer, 9, "RIGHT")               -- "BoE": gear that will bind when worn, and has not yet
        b.bind:SetPoint("TOPRIGHT", -2, -2)                  -- (top right: the other three corners are taken)
        b.listLine = b:CreateTexture(nil, "OVERLAY")         -- a line along the bottom: gold = always sold, green = never sold
        b.listLine:SetTexture(ns.FLAT)
        b.listLine:SetHeight(2)
        b.listLine:SetPoint("BOTTOMLEFT", 1, 1)
        b.listLine:SetPoint("BOTTOMRIGHT", -1, 1)
        b.listLine:Hide()
        b.junk = layer:CreateTexture(nil, "OVERLAY")         -- a coin: "sell junk" would sell this
        b.junk:SetSize(12, 12)
        b.junk:SetPoint("TOPLEFT", 1, -1)
        b.junk:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
        b.junk:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.junk:Hide()
        b.bind:SetTextColor(0.45, 0.95, 0.55)
        if b.bind.SetShadowOffset then b.bind:SetShadowOffset(1, -1); b.bind:SetShadowColor(0, 0, 0, 1) end
        b.upgrade = ns:NewText(layer, 13, "LEFT")                            -- a green arrow on gear better than what you wear
        b.upgrade:SetPoint("BOTTOMLEFT", 1, 1)
        b.upgrade:SetText("|cff33ff55^|r")
        b.upgrade:Hide()
        b.newDot = layer:CreateTexture(nil, "OVERLAY")                      -- marks an item you just picked up
        b.newDot:SetSize(7, 7)
        b.newDot:SetPoint("TOPRIGHT", -2, -2)
        b.newDot:SetTexture(ns.FLAT)
        ns:Paint(b.newDot, "SetVertexColor", "@accent", 1)
        b.newDot:Hide()
        ns:AddBorder(b, 0, 0, 0, 1, 0)

        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:RegisterForDrag("LeftButton")
        b:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then LeftClick(self) else RightClick(self) end
        end)
        b:SetScript("OnDragStart", function(self) C.PickupContainerItem(self.bag, self.slot) end)
        b:SetScript("OnReceiveDrag", function(self) C.PickupContainerItem(self.bag, self.slot) end)
        b:SetScript("OnEnter", SlotEnter)
        b:SetScript("OnLeave", SlotLeave)
        slots[bag][slot] = b
        MakeUse(b)                                           -- (only when "use items in combat" is on)
        return b
    end

    pcall(function()
        overlay = CreateFrame("Button", cfg.name .. "Use", UIParent, "SecureActionButtonTemplate")
        overlay:SetFrameStrata("HIGH")
        overlay:SetFrameLevel(win:GetFrameLevel() + 30)
        overlay:RegisterForClicks("AnyUp", "AnyDown")
        overlay:RegisterForDrag("LeftButton")
        overlay:SetAttribute("type2", "item")
        overlay:Hide()
        overlay:SetScript("PostClick", function(self, button, down)
            if down or button ~= "LeftButton" or not self.target then return end
            LeftClick(self.target)
        end)
        local function drag(self) if self.target then C.PickupContainerItem(self.target.bag, self.target.slot) end end
        overlay:SetScript("OnDragStart", drag)
        overlay:SetScript("OnReceiveDrag", drag)
        overlay:SetScript("OnEnter", function(self) if self.target then ShowTip(self.target); self.target.hl:Show() end end)
        overlay:SetScript("OnLeave", function(self) GameTooltip:Hide(); if self.target then self.target.hl:Hide() end end)
    end)

    -- Row of bag slots. On the bag window these are your equipped bags; on the bank window they are the
    -- bank tabs (each tab holds one bag), with a "+" to buy the next tab. Hover one to light up its
    -- slots, click to pick the bag up, drop a bag on it to place or swap.
    local slotRow, slotBtns, buyBtn = nil, {}, nil
    local sock = cfg.sockets                          -- bank only: { container = id of the "tab sockets" container }
    local function InvID(bag)
        if bag == 0 or not C.ContainerIDToInventoryID then return nil end
        local ok, id = pcall(C.ContainerIDToInventoryID, bag)
        return ok and id or nil
    end
    local function BankType() return Enum and Enum.BankType and Enum.BankType.Character end
    local function Purchased()
        if C_Bank and C_Bank.FetchNumPurchasedBankTabs and BankType() ~= nil then
            local ok, n = pcall(C_Bank.FetchNumPurchasedBankTabs, BankType())
            if ok and type(n) == "number" then return n end
        end
        return #BAGS
    end
    local function BuildSlotRow()
        slotRow = CreateFrame("Frame", nil, win)
        slotRow:SetSize((#BAGS + 1) * 38, 36)
        slotRow:SetPoint("TOPLEFT", PAD, -TOP + 2)
        for i, bag in ipairs(BAGS) do
            local sb = CreateFrame("Button", nil, slotRow)
            sb:SetSize(34, 34)
            sb:SetPoint("LEFT", (i - 1) * 38, 0)
            sb.bag, sb.index = bag, i
            sb.bg = sb:CreateTexture(nil, "BACKGROUND")
            sb.bg:SetAllPoints()
            sb.bg:SetTexture(ns.FLAT)
            ns:Paint(sb.bg, "SetVertexColor", "bg3", 0.9)
            sb.icon = sb:CreateTexture(nil, "ARTWORK")
            sb.icon:SetPoint("TOPLEFT", 1, -1)
            sb.icon:SetPoint("BOTTOMRIGHT", -1, 1)
            sb.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            sb.count = ns:NewText(sb, 10, "RIGHT")
            sb.count:SetPoint("BOTTOMRIGHT", -2, 2)
            ns:AddBorder(sb, th.accent[1], th.accent[2], th.accent[3], 0.8, 0)
            local function swap(self)
                if sock then
                    pcall(C.PickupContainerItem, sock.container, self.index)      -- picks the tab's bag up, or places the bag you hold
                    dirty = true
                    return
                end
                local inv = InvID(self.bag)
                if not inv then return end
                if CursorHasItem and CursorHasItem() then
                    if PutItemInBag then PutItemInBag(inv) end
                elseif PickupBagFromSlot then
                    PickupBagFromSlot(inv)
                end
            end
            sb:SetScript("OnClick", swap)
            sb:SetScript("OnReceiveDrag", swap)
            sb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if sock then
                    if not (self.filled and pcall(GameTooltip.SetBagItem, GameTooltip, sock.container, self.index)) then
                        GameTooltip:SetText(format(ns:Tr(self.filled and "Bank tab %d" or "Bank tab %d (empty: drop a bag here)"), self.index))
                    end
                elseif self.bag == 0 then
                    GameTooltip:SetText(type(BACKPACK_TOOLTIP) == "string" and BACKPACK_TOOLTIP or "Backpack")
                else
                    local inv = InvID(self.bag)
                    if not (inv and pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", inv)) or not self.filled then
                        GameTooltip:SetText(self.bag == cfg.reagent and "Reagent bag slot (empty)" or "Bag slot (empty)")
                    end
                end
                GameTooltip:Show()
                for _, bagSlots in pairs(slots) do
                    for _, b in pairs(bagSlots) do b:SetAlpha(b.bag == self.bag and 1 or 0.2) end
                end
            end)
            sb:SetScript("OnLeave", function()
                GameTooltip:Hide()
                for _, bagSlots in pairs(slots) do
                    for _, b in pairs(bagSlots) do b:SetAlpha(Matches(b) and 1 or 0.2) end
                end
            end)
            slotBtns[i] = sb
        end
        if sock and C_Bank and C_Bank.PurchaseBankTab and BankType() ~= nil then
            local armed = 0
            buyBtn = ns:CreateButton(slotRow, "+", 34, 34, function(self)
                if GetTime() < armed then
                    armed = 0
                    pcall(C_Bank.PurchaseBankTab, BankType())
                    dirty = true
                    return
                end
                local cost
                if C_Bank.FetchNextPurchasableBankTabData then
                    local ok, data = pcall(C_Bank.FetchNextPurchasableBankTabData, BankType())
                    cost = ok and type(data) == "table" and data.tabCost
                end
                armed = GetTime() + 5
                if cost then ns:Print("Buy the next bank tab for %s? Click + again within 5 seconds to confirm.", ns:Coins(cost))
                else ns:Print("Buy the next bank tab? Click + again within 5 seconds to confirm.") end
            end)
            buyBtn:HookScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(ns:Tr("Buy another bank tab"))
                GameTooltip:AddLine(ns:Tr("Each tab holds one bag."), 1, 1, 1)
                GameTooltip:Show()
            end)
            buyBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
        end
    end
    local function RefreshSlotRow()
        if not slotRow then BuildSlotRow() end
        local owned = sock and Purchased() or #slotBtns
        for i, sb in ipairs(slotBtns) do
            if i > owned then
                sb:Hide()
            else
                local tex
                if sock then
                    local ok, info = pcall(C.GetContainerItemInfo, sock.container, i)
                    tex = ok and type(info) == "table" and info.iconFileID or nil
                elseif sb.bag == 0 then
                    tex = "Interface\\Buttons\\Button-Backpack-Up"
                else
                    local inv = InvID(sb.bag)
                    tex = inv and GetInventoryItemTexture and GetInventoryItemTexture("player", inv)
                end
                local n = tonumber(C.GetContainerNumSlots(sb.bag)) or 0
                sb.filled = (tex or n > 0) and true or false
                if tex then sb.icon:SetTexture(tex); sb.icon:Show() else sb.icon:Hide() end
                sb.count:SetText(n > 0 and n or "")
                sb:Show()
            end
        end
        if buyBtn then
            local can = true
            if C_Bank.CanPurchaseBankTab then
                local ok, v = pcall(C_Bank.CanPurchaseBankTab, BankType())
                can = ok and v and true or false
            end
            if can and owned < #slotBtns then
                buyBtn:ClearAllPoints()
                buyBtn:SetPoint("LEFT", slotRow, "LEFT", owned * 38, 0)
                buyBtn:Show()
            else
                buyBtn:Hide()
            end
        end
        slotRow:Show()
    end
    function win.ToggleSlots()
        showSlots = not showSlots
        if not showSlots and slotRow then slotRow:Hide() end
        dirty = true
    end

    local function Refresh(b)
        local info = C.GetContainerItemInfo(b.bag, b.slot)
        b.info = info
        b.ilvl:SetText("")
        b.bind:SetText(ns:BindTag(info))
        if info and ns.db.bagSetMark and ns.InGearSet and ns:InGearSet(info.itemID or info.hyperlink) then b.bind:SetText("|cff66ccff" .. ns:Tr("Set") .. "|r") end
        local listed = info and ns:ItemListState(info.itemID or info.hyperlink)
        if listed == "sell" then b.listLine:SetVertexColor(1, 0.82, 0.2, 1); b.listLine:Show()
        elseif listed == "keep" then b.listLine:SetVertexColor(0.35, 0.9, 0.45, 1); b.listLine:Show()
        else b.listLine:Hide() end
        local upgrade = false
        local r, g, bl = ns:T("border")
        if info then
            b.icon:SetTexture(info.iconFileID)
            b.icon:Show()
            if b.icon.SetDesaturated then b.icon:SetDesaturated(info.isLocked and true or false) end
            local n = info.stackCount
            b.count:SetText((n and n > 1) and n or "")
            local q = info.quality
            local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
            if c and q > 1 then r, g, bl = c.r, c.g, c.b elseif q == 0 then r, g, bl = 0.45, 0.45, 0.45 end
            if GetInstant and info.itemID then
                local _, _, _, _, _, classID = GetInstant(info.itemID)
                if (classID == 2 or classID == 4) and C_Item and C_Item.GetDetailedItemLevelInfo and info.hyperlink then
                    local lvl = C_Item.GetDetailedItemLevelInfo(info.hyperlink)
                    if lvl and lvl > 1 then b.ilvl:SetText(lvl) end
                    upgrade = ns.IsUpgrade and ns:IsUpgrade(info.hyperlink, lvl) or false
                end
            end
            if b.cd and C.GetContainerItemCooldown then
                local start, dur = C.GetContainerItemCooldown(b.bag, b.slot)
                pcall(b.cd.SetCooldown, b.cd, start, dur)
            end
        else
            b.icon:Hide()
            b.count:SetText("")
            if b.cd then b.cd:Hide() end
        end
        local junk = false
        if info and ns.db.bagJunkIcon and type(info.hyperlink) == "string" and not info.hasNoValue then
            local okJ, price = pcall(function() return (select(11, ns:GetItemInfo(info.hyperlink))) end)
            junk = okJ and ns:ShouldSell(info.hyperlink, info.quality, price) or false
        end
        if junk then
            b.junk:Show()
            b.ilvl:SetText("")                               -- (the coin takes that corner; the level of junk is no loss)
        else
            b.junk:Hide()
        end
        b.suiBorder:SetBackdropBorderColor(r, g, bl, 1)
        if upgrade then b.upgrade:Show() else b.upgrade:Hide() end
        b:SetAlpha(Matches(b) and 1 or 0.2)
        local isNew = false
        if info and C_NewItems and C_NewItems.IsNewItem then
            local ok, v = pcall(C_NewItems.IsNewItem, b.bag, b.slot)
            isNew = ok and v and true or false
        end
        b.isNew = isNew
        if isNew then b.newDot:Show() else b.newDot:Hide() end
    end

    local function Category(info)
        local custom = info.itemID and ns.db.bagAssign[info.itemID]
        if type(custom) == "string" and custom ~= "" then return custom, true end      -- your own category wins
        if ns.BagRuleFor then
            local okR, ruled = pcall(ns.BagRuleFor, ns, info)                            -- then your bag rules
            if okR and type(ruled) == "string" and ruled ~= "" then return ruled, true end
        end
        if info.quality == 0 then return "Junk" end
        local classID
        if GetInstant and info.itemID then classID = select(6, GetInstant(info.itemID)) end
        if classID == 2 or classID == 4 then return "Equipment" end
        if classID == 0 then return "Consumables" end
        if classID == 12 then return "Quest" end
        if classID == 7 or classID == 5 or classID == 3 or classID == 9 or classID == 8 then return "Trade Goods" end
        return "Other"
    end

    local function Header(i, text, y)
        local h = headers[i]
        if not h then
            h = ns:NewText(win, 11, "LEFT")
            ns:Paint(h, "SetTextColor", "@accent")
            headers[i] = h
        end
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, y)
        h:SetText(text)
        h:Show()
        return y - 16
    end

    local function Place(list, y)
        for i, b in ipairs(list) do
            local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", win, "TOPLEFT", PAD + col * (SIZE + GAP), y - row * (SIZE + GAP))
            b:Show()
        end
        return y - math.ceil(#list / COLS) * (SIZE + GAP) - 6
    end

    local function Layout()
        if InCombatLockdown() and (secure > 0 or ns:Locked(win)) then   -- frozen: keep what each slot shows up to date, move nothing
            pendingLayout = true
            EachSlot(function(b) if b:IsShown() then Refresh(b) end end)
            if cfg.money then money:SetText(ns:Coins(GetMoney())) end
            return
        end
        if secure > 0 and not CombatUse() then TakeOff() end                 -- the option was switched off
        local groups, all = {}, {}
        local customNames, customSeen = {}, {}
        for _, k in ipairs(ORDER) do groups[k] = {} end
        local total, used = 0, 0
        local freeN, freeR, firstN, firstR = 0, 0, nil, nil

        for _, bag in ipairs(BAGS) do
            local n = tonumber(C.GetContainerNumSlots(bag)) or 0
            for slot = 1, n do
                local b = GetSlot(bag, slot)
                if not b.suiUse then MakeUse(b) end             -- (a slot made during a fight, or the option just switched on)
                Refresh(b)
                b:Hide()
                total = total + 1
                all[#all + 1] = b
                if b.info then
                    used = used + 1
                    local name, isCustom = Category(b.info)
                    if not groups[name] then groups[name] = {} end
                    if isCustom and not customSeen[name] then customSeen[name] = true; customNames[#customNames + 1] = name end
                    table.insert(groups[name], b)
                elseif bag == cfg.reagent then
                    freeR = freeR + 1; firstR = firstR or b
                else
                    freeN = freeN + 1; firstN = firstN or b
                end
            end
            if slots[bag] then                      -- a bag was removed or swapped for a smaller one
                for s = n + 1, #slots[bag] do slots[bag][s]:Hide() end
            end
        end

        for _, h in ipairs(headers) do h:Hide() end
        if showSlots then RefreshSlotRow() end
        local y, hi = -TOP - (showSlots and 42 or 0), 0
        if total == 0 and cfg.emptyNote then
            note:SetText(cfg.emptyNote)
            note:Show()
            y = y - 44
        else
            note:Hide()
            if ns.db[gridKey] then
                y = Place(all, y)
            else
                table.sort(customNames, function(a, b)
                    local ra, rb = ns.BagRuleRank and ns.BagRuleRank(a) or 1000, ns.BagRuleRank and ns.BagRuleRank(b) or 1000
                    if ra ~= rb then return ra < rb end
                    return a < b
                end)
                local order = {}
                for _, k in ipairs(customNames) do order[#order + 1] = k end       -- your categories first: your rules' order, then A to Z
                for _, k in ipairs(ORDER) do
                    if not customSeen[k] then order[#order + 1] = k end
                end
                for _, k in ipairs(order) do
                    local list = groups[k]
                    if #list > 0 then
                        table.sort(list, function(a, b)
                            local qa, qb = a.info.quality or 0, b.info.quality or 0
                            if qa ~= qb then return qa > qb end
                            local ia, ib = a.info.itemID or 0, b.info.itemID or 0
                            if ia ~= ib then return ia < ib end
                            if a.bag ~= b.bag then return a.bag < b.bag end
                            return a.slot < b.slot
                        end)
                        hi = hi + 1
                        y = Header(hi, k .. "  |cff9c8c6c" .. #list .. "|r", y)
                        y = Place(list, y)
                    end
                end
                -- free space: one drop slot per bag type, showing how many are left
                local freeList = {}
                if firstN then firstN.count:SetText(freeN); freeList[#freeList + 1] = firstN end
                if firstR then firstR.count:SetText(freeR); freeList[#freeList + 1] = firstR end
                if #freeList > 0 then
                    hi = hi + 1
                    y = Header(hi, "Free  |cff9c8c6c" .. (freeN + freeR) .. "|r", y)
                    y = Place(freeList, y)
                end
            end
        end
        win:SetHeight(-y + FOOT)
        freeText:SetText(used .. " / " .. total)
        if extraBtn and cfg.extra.visible then                    -- e.g. "Sell junk" only while a vendor is open
            if cfg.extra.visible() then extraBtn:Show() else extraBtn:Hide() end
        end
        if cfg.money then
            money:SetText(ns:Coins(GetMoney()))
        end
    end

    search:HookScript("OnTextChanged", function(self)
        local t = self:GetText()
        query = type(t) == "string" and t:lower() or ""
        for _, bagSlots in pairs(slots) do
            for _, b in pairs(bagSlots) do b:SetAlpha(Matches(b) and 1 or 0.2) end
        end
    end)

    -- Category picker (Alt-click an item) ---------------------------------------------------------
    local picker
    OpenPicker = function(b)
        if not picker then
            picker = CreateFrame("Frame", nil, UIParent, ns.template)
            picker:SetFrameStrata("DIALOG")
            picker:SetBackdrop(ns.BACKDROP)
            ns:Paint(picker, "SetBackdropColor", "window", 0.97)
            ns:Paint(picker, "SetBackdropBorderColor", "@border", 1)
            ns:Dress(picker, true)
            picker:EnableMouse(true)
            picker.title = ns:NewText(picker, 11, "LEFT")
            picker.title:SetPoint("TOPLEFT", 8, -8)
            picker.title:SetWidth(184)
            ns:Paint(picker.title, "SetTextColor", "dim")
            picker.input = ns:CreateEditBox(picker, 184, 22, "New category name, then Enter")
            picker.input:SetPoint("TOPLEFT", 8, -26)
            picker.input:SetScript("OnEnterPressed", function(self)
                local name = self:GetText()
                name = type(name) == "string" and strtrim(name) or ""
                if name ~= "" and picker.itemID then
                    ns.db.bagAssign[picker.itemID] = name:sub(1, 24)
                    dirty = true
                end
                self:SetText("")
                picker:Hide()
            end)
            picker.input:SetScript("OnEscapePressed", function() picker:Hide() end)
            -- the two lists that correct "sell junk": each button switches this item on or off its list
            local function ListButton(kind, text, tip)
                local btn = ns:CreateButton(picker, text, 90, 20, function()
                    if not picker.itemID then return end
                    ns:SetItemList(picker.itemID, (ns:ItemListState(picker.itemID) ~= kind) and kind or nil)
                    picker.MarkLists()
                    dirty = true
                end)
                btn:HookScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                    GameTooltip:SetText(ns:Tr(text))
                    GameTooltip:AddLine(ns:Tr(tip), 1, 1, 1, true)
                    GameTooltip:Show()
                end)
                btn:HookScript("OnLeave", function() GameTooltip:Hide(); picker.MarkLists() end)
                return btn
            end
            picker.sell = ListButton("sell", "Always sell", "Sold whenever junk is sold, whatever its color. Click again to take it off the list.")
            picker.keep = ListButton("keep", "Never sell", "Never sold automatically, even if it is gray. Click again to take it off the list.")
            picker.sell:SetPoint("BOTTOMLEFT", 8, 8)
            picker.keep:SetPoint("BOTTOMRIGHT", -8, 8)
            function picker.MarkLists()
                local state = picker.itemID and ns:ItemListState(picker.itemID)
                ns:Paint(picker.sell, "SetBackdropBorderColor", state == "sell" and "@accent" or "@border", 1)
                ns:Paint(picker.keep, "SetBackdropBorderColor", state == "keep" and "@accent" or "@border", 1)
            end
            picker.rows = {}
        end
        picker.itemID = b.info.itemID
        local label = type(b.info.hyperlink) == "string" and b.info.hyperlink:match("%[(.-)%]") or "this item"
        picker.title:SetText(format(ns:Tr("Category for %s"), label))

        local names, seen = {}, {}
        for _, name in pairs(ns.db.bagAssign) do
            if type(name) == "string" and not seen[name] then seen[name] = true; names[#names + 1] = name end
        end
        table.sort(names)
        names[#names + 1] = false                         -- last row: back to automatic sorting
        for i, name in ipairs(names) do
            local r = picker.rows[i]
            if not r then
                r = ns:CreateButton(picker, "", 184, 20, function(self)
                    ns.db.bagAssign[picker.itemID] = self.category or nil
                    dirty = true
                    picker:Hide()
                end)
                r:SetPoint("TOPLEFT", 8, -54 - (i - 1) * 22)
                picker.rows[i] = r
            end
            r.category = name or nil
            r.text:SetText(name or "Automatic")
            r:Show()
        end
        for i = #names + 1, #picker.rows do picker.rows[i]:Hide() end
        picker:SetSize(200, 60 + #names * 22 + 30)
        picker.MarkLists()
        picker:ClearAllPoints()
        picker:SetPoint("TOPLEFT", b, "TOPRIGHT", 6, 0)
        picker:Show()
    end

    -- The slot under the mouse can change without the mouse moving (the bags re-sort after an item is
    -- used up, a fight ends), so look a few times a second rather than only when the mouse enters.
    ns:Every(0.15, cfg.name .. " use button", function()
        if not overlay or InCombatLockdown() or not win:IsShown() then return end
        local focus
        if GetMouseFoci then
            local ok, list = pcall(GetMouseFoci)
            focus = ok and type(list) == "table" and list[1] or nil
        elseif GetMouseFocus then
            focus = GetMouseFocus()
        end
        if not ns:Usable(focus) then return end
        if focus == overlay then
            local target = overlay.target
            if target and not (target:IsVisible() and target:IsMouseOver()) then LetGo() end      -- its slot moved away: step aside
        elseif focus.bag and focus.slot and slots[focus.bag] and slots[focus.bag][focus.slot] == focus then
            Attach(focus)
        end
    end)

    win:SetScript("OnShow", function() if cfg.onShow then cfg.onShow() end end)
    win:SetScript("OnHide", function()
        if picker then picker:Hide() end
        LetGo()
        if cfg.onHide then cfg.onHide() end
        if cfg.isOpen() then pcall(cfg.close) end
    end)

    ns.bagTest[cfg.name].Layout = Layout
    ns.bagRefreshers = ns.bagRefreshers or {}
    ns.bagRefreshers[#ns.bagRefreshers + 1] = function() dirty = true end

    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN", "PLAYER_MONEY", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    for _, e in ipairs(cfg.events or {}) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            -- The roaming button can't follow the mouse in combat, and must not be left fixed to a slot
            -- (see LetGo). This event arrives just before the game's combat rules begin, so it is still allowed.
            if overlay then overlay:Hide(); overlay:ClearAllPoints(); overlay.target = nil end
            -- With a secure button on every slot, nothing may move once the fight starts: so arrange the
            -- window now, while that is still allowed, whether or not it is open.
            if CombatUse() and not InCombatLockdown() then pcall(Layout) end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if pendingLayout or secure > 0 then pendingLayout = false; dirty = true end
        else
            dirty = true
        end
    end)

    local acc, macc = 0, 0
    ev:SetScript("OnUpdate", ns:Guard(cfg.title .. " window", function(_, e)
        macc = macc + e
        if macc >= 0.05 then
            macc = 0
            local want = cfg.isOpen() and true or false
            if want ~= (win:IsShown() and true or false) and not ns:Locked(win) then      -- (if the game has it locked for this fight: afterwards)
                if want then dirty = true; win:Show() else win:Hide() end
            end
        end
        acc = acc + e
        if acc < 0.1 then return end
        acc = 0
        if dirty and win:IsShown() then
            dirty = false
            Layout()
        end
    end))

    ns:RegisterMovable(win, cfg.key, cfg.title)
    return win
end

function ns:RefreshBagWindow()
    for _, f in ipairs(ns.bagRefreshers or {}) do f() end
end

local function HaveAPI()
    local C = C_Container
    return C and C.GetContainerNumSlots and C.GetContainerItemInfo and C.PickupContainerItem and C.UseContainerItem
end

ns:NewModule("bagWindow", function()
    if not HaveAPI() then
        ns:Print("Bag window: this client lacks the C_Container API, keeping Blizzard's bags.")
        return
    end
    local reagent = BagIndex("ReagentBag", 5)
    local bags = { 0, 1, 2, 3, 4 }
    if reagent then bags[#bags + 1] = reagent end

    ns.BagList = bags

    local function BlizzOpen()
        local combined = _G.ContainerFrameCombinedBags
        if type(combined) == "table" and combined.IsShown and combined:IsShown() then return true end
        if IsBagOpen then
            for _, bag in ipairs(bags) do if IsBagOpen(bag) then return true end end
        end
        return false
    end

    local function Storage(view)
        if ns.OpenStorage then ns:OpenStorage(view)
        else ns:Print("Turn on \"Remember bags & bank\" in /fgui to view storage from anywhere.") end
    end
    local win
    win = NewWindow({
        name = "FantasyGlassUIBags", title = "Bags", key = "bags", bags = bags, reagent = reagent, money = true, combatUse = true,
        buttons = {
            { "Slots", 50, function() win.ToggleSlots() end, "Show or hide your bag slots, to swap or buy bags." },
            { "Bank",  48, function() Storage("bank") end, "Your bank, as it was when you last opened it." },
            { "Guild", 50, function() Storage("guild") end, "The guild bank, as it was when you last opened it." },
            { "Chars", 52, function() Storage("bags") end, "What your other characters carry." },
            { "Equip best", 76, function() if ns.EquipBest then ns:EquipBest() end end, "Put on every piece in your bags with a higher item level than what you wear. Only gear already bound to you." },
        },
        point = { "BOTTOMRIGHT", -40, 120 },
        isOpen = BlizzOpen,
        close = function() if CloseAllBags then CloseAllBags() end end,
        sort = function() C_Container.SortBags() end,
        events = { "MERCHANT_SHOW", "MERCHANT_CLOSED" },
        extra = { "Sell junk", function() ns:SellJunk(true) end,
                  visible = function()
                      local m = _G.MerchantFrame
                      return type(m) == "table" and m.IsShown and m:IsShown() and true or false
                  end },
    })

    local blizz = { _G.ContainerFrameCombinedBags }
    for i = 1, 6 do blizz[#blizz + 1] = _G["ContainerFrame" .. i] end
    for _, f in pairs(blizz) do ns:Silence(f) end
end)

ns:NewModule("bankWindow", function()
    if not HaveAPI() then return end
    local bank = _G.BankFrame
    if type(bank) ~= "table" or not bank.IsShown then
        ns:Print("Bank window: no BankFrame on this client, keeping Blizzard's bank.")
        return
    end

    local managing = false       -- true while Blizzard's own bank window is shown as well
    local win
    win = NewWindow({
        name = "FantasyGlassUIBank", title = "Bank", key = "bank", bags = BankBags(),
        sockets = { container = BagIndex("Characterbanktab", -2) },
        buttons = { { "Tabs", 50, function() win.ToggleSlots() end },
                    { "Deposit", 64, function() if ns.DepositMaterials then ns:DepositMaterials() end end } },
        point = { "TOPLEFT", 60, -120 },
        isOpen = function() return bank:IsShown() end,
        close = function() if HideUIPanel then HideUIPanel(bank) else bank:Hide() end end,
        sort = function() if C_Container.SortBankBags then C_Container.SortBankBags() end end,
        events = { "PLAYERBANKSLOTS_CHANGED", "BANKFRAME_OPENED", "BANK_TABS_CHANGED", "BANK_TAB_SETTINGS_UPDATED" },
        emptyNote = "No bank space yet. Click \"Tabs\" above: buy a tab with +, then drop a bag onto it.",
        extra = { "Blizzard bank", function()
            managing = not managing
            if managing then ns:Unsilence(bank) else ns:Silence(bank) end
        end },
        onShow = function() if not managing then ns:Silence(bank) end end,
        onHide = function() managing = false end,
    })
    ns:Silence(bank)
end)
