local _, ns = ...

-- Notifications: small toasts for things worth a glance - an item you looted, a new level, new
-- mail, a whisper. One place, one look, stacked and gone after a few seconds.
-- ns:Toast(...) is the one way in, so any other part of the add-on can show one too.
ns:NewModule("toasts", function()
    local W, H, GAP, MAX = 290, 44, 6, 4
    local HOLD, FADE_IN, FADE_OUT = 4.5, 0.2, 0.5
    -- (12.1) Calm mode: one at a time, held for fifteen seconds, and a click puts it away
    local function Hold() return (ns.db and ns.db.calmMode) and 15 or HOLD end
    local function Room() return (ns.db and ns.db.calmMode) and 1 or MAX end

    local anchor = CreateFrame("Frame", "FantasyGlassUIToasts", UIParent)
    anchor:SetSize(W, MAX * (H + GAP))
    anchor:SetPoint("TOP", UIParent, "TOP", 0, -130)

    local rows, queue = {}, {}
    local function Row(i)
        if rows[i] then return rows[i] end
        local r = CreateFrame("Frame", nil, anchor, ns.template)
        r:SetSize(W, H)
        r:SetBackdrop(ns.BACKDROP)
        ns:Paint(r, "SetBackdropColor", "window", 0.92)
        ns:Paint(r, "SetBackdropBorderColor", "@border", 1)
        ns:Dress(r, true)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(34, 34)
        r.icon:SetPoint("LEFT", 5, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.plate = r:CreateTexture(nil, "ARTWORK")           -- when there is no icon: a plate with a few characters on it
        r.plate:SetAllPoints(r.icon)
        r.plate:SetTexture(ns.FLAT)
        ns:Paint(r.plate, "SetVertexColor", "@accent", 0.85)
        r.badge = ns:NewText(r, 16, "CENTER", true)
        r.badge:SetPoint("CENTER", r.icon, "CENTER", 0, 0)
        r.badge:SetTextColor(0.05, 0.05, 0.06)
        r.title = ns:NewText(r, 12, "LEFT", true)
        r.title:SetPoint("TOPLEFT", 46, -7)
        r.title:SetPoint("RIGHT", -8, 0)
        r.text = ns:NewText(r, 11, "LEFT")
        r.text:SetPoint("TOPLEFT", 46, -24)
        r.text:SetPoint("RIGHT", -8, 0)
        ns:Paint(r.text, "SetTextColor", "dim")
        r:EnableMouse(true)
        r:SetScript("OnMouseUp", function(self) self.started = GetTime() - FADE_IN - Hold() end)     -- (a click: it goes now)
        r:Hide()
        rows[i] = r
        return r
    end

    local function Fill(r, t)
        if t.icon then
            r.icon:SetTexture(t.icon); r.icon:Show(); r.plate:Hide(); r.badge:SetText("")
        else
            r.icon:Hide(); r.plate:Show(); r.badge:SetText(t.badge or "!")
        end
        r.title:SetText(t.title or "")
        r.text:SetText(t.text or "")
        r.started = GetTime()
        r:SetAlpha(ns:Motion() and 0 or 1)
        r:Show()
    end

    -- icon: a texture, or nil to show `badge` (a few characters) on an accent plate instead
    function ns:Toast(icon, title, text, badge)
        queue[#queue + 1] = { icon = icon, title = title, text = text, badge = badge }
        if #queue > 12 then table.remove(queue, 1) end       -- a flood (opening many bags of loot) keeps only the latest
    end

    ns:Every(0.05, "Notifications", function()
        -- (This runs twenty times a second. With nothing on screen and nothing waiting it must cost
        --  nothing, so it leaves before building anything.)
        local busy = #queue > 0
        if not busy then
            for i = 1, MAX do
                local r = rows[i]
                if r and r:IsShown() then busy = true; break end
            end
        end
        ns.toastsIdle = not busy
        if not busy then return end
        local now, shown = GetTime(), {}
        for i = 1, MAX do
            local r = rows[i]
            if r and r:IsShown() then
                local age = now - r.started
                if age >= FADE_IN + Hold() + FADE_OUT then
                    r:Hide()
                else
                    if ns:Motion() then
                        local a = 1
                        if age < FADE_IN then a = age / FADE_IN
                        elseif age > FADE_IN + Hold() then a = 1 - (age - FADE_IN - Hold()) / FADE_OUT end
                        r:SetAlpha(math.max(0, math.min(1, a)))
                    end
                    shown[#shown + 1] = r
                end
            end
        end
        while #queue > 0 and #shown < Room() do              -- room for another
            local free
            for i = 1, MAX do
                local r = Row(i)
                if not r:IsShown() then free = r; break end
            end
            if not free then break end
            Fill(free, table.remove(queue, 1))
            shown[#shown + 1] = free
        end
        table.sort(shown, function(a, b) return a.started < b.started end)
        for i, r in ipairs(shown) do                         -- oldest on top, no gaps
            r:ClearAllPoints()
            r:SetPoint("TOP", anchor, "TOP", 0, -(i - 1) * (H + GAP))
        end
    end)

    -- What sets them off --------------------------------------------------------------------------------
    -- Loot: the game announces it as a chat line built from a fixed sentence; turn those sentences into
    -- patterns so they work in any language.
    local lootPatterns = {}
    for _, name in ipairs({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF_MULTIPLE",
                            "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_CREATED_SELF" }) do
        local sentence = _G[name]
        if type(sentence) == "string" then
            -- escape the punctuation, then turn the placeholders into captures. Some languages number
            -- their placeholders ("%1$s"), which after escaping reads "%1%$s".
            local pattern = sentence:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
            pattern = pattern:gsub("%%%d%%%$s", "(.+)"):gsub("%%%d%%%$d", "(%%d+)")
            pattern = pattern:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
            lootPatterns[#lootPatterns + 1] = "^" .. pattern .. "$"
        end
    end
    local function Looted(message)
        for _, pattern in ipairs(lootPatterns) do
            local link, count = message:match(pattern)
            if link then return link, tonumber(count) or 1 end
        end
    end
    ns.ToastLootMatch = Looted                               -- (for tests)

    local hadMail = HasNewMail and HasNewMail() and true or false
    local lastWhisper = {}

    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "CHAT_MSG_LOOT", "PLAYER_LEVEL_UP", "UPDATE_PENDING_MAIL", "CHAT_MSG_WHISPER" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", ns:Guard("Notifications", function(_, event, a, b)
        if event == "CHAT_MSG_LOOT" then
            if type(a) ~= "string" or ns:IsSecret(a) then return end
            local link, count = Looted(a)
            if not link then return end
            local quality = select(3, ns:GetItemInfo(link))
            if type(quality) ~= "number" or quality < (tonumber(ns.db.toastQuality) or 2) then return end      -- uncommon and better
            local GetInstant = C_Item.GetItemInfoInstant
            local icon = GetInstant and select(5, GetInstant(link))
            ns:Toast(icon, link, count > 1 and format(ns:Tr("You received %d"), count) or ns:Tr("You received"))
        elseif event == "PLAYER_LEVEL_UP" then
            ns:Toast(nil, format(ns:Tr("Level %s"), tostring(a)), ns:Tr("You gained a level."), tostring(a))
        elseif event == "UPDATE_PENDING_MAIL" then
            local has = HasNewMail and HasNewMail() and true or false
            if has and not hadMail then ns:Toast(nil, ns:Tr("New mail"), ns:Tr("There is mail waiting for you."), "@") end
            hadMail = has
        elseif event == "CHAT_MSG_WHISPER" then
            if type(a) ~= "string" or type(b) ~= "string" or ns:IsSecret(a) or ns:IsSecret(b) then return end
            local who = b:gsub("%-.*$", "")
            local now = GetTime()
            if lastWhisper[who] and now - lastWhisper[who] < 10 then return end       -- a conversation is one toast, not twenty
            lastWhisper[who] = now
            ns:Toast(nil, format(ns:Tr("Whisper from %s"), who), #a > 70 and (a:sub(1, 67) .. "...") or a, who:sub(1, 1):upper())
        end
    end))

    -- Two things worth knowing before they become a problem. Each is said once, and not again until
    -- the situation has cleared and come back.
    local bagsWarned, repairWarned = false, false
    local function FreeSlots()
        local slots, freeOf = C_Container.GetContainerNumSlots, C_Container.GetContainerNumFreeSlots
        if not slots or not freeOf then return nil end
        local free, total = 0, 0
        for bag = 0, 4 do
            local ok, n = pcall(slots, bag)
            local ok2, f = pcall(freeOf, bag)
            if ok and type(n) == "number" then total = total + n end
            if ok2 and type(f) == "number" then free = free + f end
        end
        if total == 0 then return nil end
        return free
    end
    local function CheckSupplies()
        local free = FreeSlots()
        if free then
            if free <= 2 and not bagsWarned then
                bagsWarned = true
                ns:Toast(nil, ns:Tr("Bags almost full"), format(ns:Tr("%d free slots left."), free), "!")
            elseif free >= 5 then
                bagsWarned = false
            end
        end
        local lowest = ns.LowestDurability and ns:LowestDurability()
        if type(lowest) == "number" then
            if lowest < 20 and not repairWarned then
                repairWarned = true
                ns:Toast(nil, ns:Tr("Gear needs repair"), format(ns:Tr("Your most worn item is at %d%%."), math.floor(lowest)), "!")
            elseif lowest >= 50 then
                repairWarned = false
            end
        end
    end
    ns.ToastCheckSupplies = CheckSupplies
    local supplies = CreateFrame("Frame")
    for _, e in ipairs({ "BAG_UPDATE_DELAYED", "UPDATE_INVENTORY_DURABILITY", "PLAYER_ENTERING_WORLD" }) do
        pcall(supplies.RegisterEvent, supplies, e)
    end
    supplies:SetScript("OnEvent", ns:Guard("Notifications", function() CheckSupplies() end))

    ns:RegisterPreview(function(on, mode)
        if on and mode == "showcase" then return end           -- (screenshot mode keeps the screen clear)
        if on then ns:Toast(nil, ns:Tr("Notifications appear here"), ns:Tr("Loot, new levels, mail, whispers, full bags and worn gear."), "!") end
    end)
    ns:RegisterMovable(anchor, "toasts", "Notifications")
end)
