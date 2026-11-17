local _, ns = ...

-- Mailbox helpers: "Collect gold" takes the money from every letter; "Open all" also takes the items
-- (skipping cash-on-delivery mail). Letters are handled one at a time with a short pause, which is how
-- the mail server wants it.
ns:NewModule("mailTools", function()
    if not (GetInboxNumItems and GetInboxHeaderInfo and TakeInboxMoney and AutoLootMailItem) then return end
    local mail = _G.MailFrame
    if type(mail) ~= "table" then return end

    local bar = CreateFrame("Frame", "FantasyGlassUIMailTools", UIParent)
    bar:SetSize(230, 24)
    bar:SetPoint("BOTTOMLEFT", mail, "TOPLEFT", 60, 2)
    bar:SetFrameStrata("HIGH")
    bar:Hide()

    local running, mode, index, gold, taken = false, nil, 0, 0, 0

    local function Finish(reason)
        running = false
        local parts = {}
        if gold > 0 then parts[#parts + 1] = ns:Coins(gold) end
        if taken > 0 then parts[#parts + 1] = format(ns:Tr(taken == 1 and "%d letter emptied" or "%d letters emptied"), taken) end
        ns:PrintRaw(ns:Tr(reason or "Mail done.") .. " " .. (#parts > 0 and table.concat(parts, ", ") .. "." or ns:Tr("Nothing to collect.")))
    end

    local function Step()
        if not running then return end
        if not (mail.IsShown and mail:IsShown()) then return Finish("Mailbox closed.") end
        while index >= 1 do
            local _, _, _, _, money, cod, _, hasItem = GetInboxHeaderInfo(index)
            money, cod = tonumber(money) or 0, tonumber(cod) or 0
            local i = index
            index = index - 1
            if mode == "gold" then
                if money > 0 then
                    gold = gold + money
                    TakeInboxMoney(i)
                    return ns:After(0.5, Step)
                end
            elseif cod == 0 and (money > 0 or hasItem) then
                gold, taken = gold + money, taken + 1
                AutoLootMailItem(i)
                return ns:After(0.6, Step)
            end
        end
        Finish()
    end

    local function Start(which)
        if running then return end
        running, mode, gold, taken = true, which, 0, 0
        index = tonumber(GetInboxNumItems()) or 0        -- last to first, so earlier letters keep their place
        Step()
    end

    local goldBtn = ns:CreateButton(bar, "Collect gold", 110, 22, function() Start("gold") end)
    goldBtn:SetPoint("LEFT", 0, 0)
    ns:ButtonTip(goldBtn, "Take the gold out of every letter, leaving the items where they are.")
    if type(_G.OpenAllMail) ~= "table" then                -- newer clients already have their own "Open All"
        local all = ns:CreateButton(bar, "Open all", 110, 22, function() Start("all") end)
        all:SetPoint("LEFT", goldBtn, "RIGHT", 6, 0)
        ns:ButtonTip(all, "Take the gold and items out of every letter. Stops when your bags are full.")
    end

    -- full bags: stop instead of hammering the server
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("UI_ERROR_MESSAGE")
    ev:SetScript("OnEvent", ns:Guard("Mail events", function(_, _, a, b)
        local msg = type(b) == "string" and b or a
        if running and type(msg) == "string" and type(ERR_INV_FULL) == "string" and msg == ERR_INV_FULL then
            Finish("Bags are full.")
        end
    end))

    ns:Every(0.2, "Mail tools", function()
        local inbox = _G.InboxFrame
        local show = mail.IsShown and mail:IsShown() and (type(inbox) ~= "table" or not inbox.IsShown or inbox:IsShown())
        if show then bar:Show() else bar:Hide() end
    end)
end)

-- Your other characters, beside the mail window while you are writing a letter. Click one and the
-- letter is addressed to it. The list is the characters the add-on has seen you log in on (the same
-- ones the Storage window knows), without the one you are on now. A character on another realm is
-- written the way the game wants it, Name-Realm.
function ns:MailAlts()
    local list = {}
    local chars = type(ns.root) == "table" and type(ns.root.inventory) == "table" and ns.root.inventory.chars
    if type(chars) ~= "table" then return list end
    local me = ns:CharKey()
    local myRealm = me:match(" %- (.+)$")
    for key, c in pairs(chars) do
        if key ~= me and type(key) == "string" then
            local name, realm = key:match("^(.-) %- (.+)$")
            if name and name ~= "" and name ~= "Unknown" then
                local target = (realm == myRealm) and name or (name .. "-" .. realm:gsub("[%s%-']", ""))
                list[#list + 1] = { name = name, target = target, realm = realm, class = type(c) == "table" and c.class or nil, other = realm ~= myRealm }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.other ~= b.other then return not a.other end    -- this realm first
        return a.name < b.name
    end)
    return list
end

ns:NewModule("mailAlts", function()
    local mail = _G.MailFrame
    if type(mail) ~= "table" or not ns:Usable(mail) then return end
    local panel = CreateFrame("Frame", "FantasyGlassUIMailAlts", UIParent, ns.template)
    panel:SetFrameStrata("HIGH")
    panel:SetBackdrop(ns.BACKDROP)
    ns:Paint(panel, "SetBackdropColor", "window", 0.95)
    ns:Paint(panel, "SetBackdropBorderColor", "@border", 1)
    panel:SetPoint("TOPLEFT", mail, "TOPRIGHT", 4, -24)
    panel:Hide()
    local title = ns:NewText(panel, 11, "LEFT", true)
    title:SetPoint("TOPLEFT", 8, -7)
    title:SetText(ns:Tr("Send to"))
    ns:Paint(title, "SetTextColor", "@accent")
    local rows = {}
    local function Fill()
        local alts = ns:MailAlts()
        for n, alt in ipairs(alts) do
            if n > 12 then break end
            local row = rows[n]
            if not row then
                row = ns:CreateButton(panel, "", 124, 20, function(self)
                    local box = _G.SendMailNameEditBox
                    if type(box) == "table" and box.SetText and self.target then
                        box:SetText(self.target)
                        local subject = _G.SendMailSubjectEditBox
                        if type(subject) == "table" and subject.SetFocus then subject:SetFocus() end
                    end
                end)
                row:SetPoint("TOPLEFT", 6, -24 - (n - 1) * 22)
                row.text:ClearAllPoints()
                row.text:SetPoint("LEFT", 6, 0)
                row.text:SetPoint("RIGHT", -6, 0)
                row.text:SetJustifyH("LEFT")
                row.text:SetWordWrap(false)
                rows[n] = row
            end
            row.target = alt.target
            row.text:SetText(alt.other and (alt.name .. " *") or alt.name)
            local r, g, b = ns:ClassRGB(alt.class)
            if r then row.text:SetTextColor(r, g, b) end
            row:Show()
        end
        local shown = math.min(#alts, 12)
        for n = shown + 1, #rows do rows[n]:Hide() end
        panel:SetSize(136, 30 + shown * 22)
        return shown
    end
    ns.FillMailAlts = Fill
    local wasWriting = false
    ns:Every(0.2, "Mail: your characters", function()
        local send = _G.SendMailFrame
        local writing = mail.IsShown and mail:IsShown() and type(send) == "table" and send.IsShown and send:IsShown() and true or false
        if writing and not wasWriting then
            if Fill() > 0 then panel:Show() else panel:Hide() end
        elseif not writing and wasWriting then
            panel:Hide()
        end
        wasWriting = writing
    end)
end)
