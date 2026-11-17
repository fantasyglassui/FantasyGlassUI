-- Part of Fantasy Glass UI, kept in a second folder that the game loads only when it is needed (the
-- first time the options, the setup or the self-check is asked for). The main add-on shares its
-- table as the global FantasyGlassUI; everything here hangs off that.
local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end
local O = ns.optUI
local groups, SECTIONS, DESC, INSTANT = ns.featureGroups, ns.featureSections, ns.featureDesc, ns.featureInstant
local LOCKED_HIDE, LOCKED_LABEL = O.LOCKED_HIDE, O.LOCKED_LABEL

-- Some sections of the Features tab have more under their switches than switches: built once,
-- shown with their section. Each returns a frame and its height.
local EXTRAS = {}
local function OpenRules(which)                              -- the Tools tab, at Your rules
    ns:ToggleConfig("tools")
    if ns.toolsPage and ns.toolsPage.rules then ns.toolsPage.rules.Set(which) end
end
EXTRAS["Bags and bag rules"] = function(page)
    local f = CreateFrame("Frame", nil, page)
    f:SetSize(736, 60)
    local note = f:CreateFontString(nil, "OVERLAY")
    ns:Font(note, 11)
    note:SetPoint("TOPLEFT", 0, 0)
    note:SetWidth(560)
    note:SetJustifyH("LEFT")
    ns:Paint(note, "SetTextColor", "dim")
    note:SetText(ns:Tr("Your own rules come first, then the sections switched on here, in the order shown. Everything else stays in the usual sections. Needs the one-window bags."))
    local b = ns:CreateButton(f, "Edit my own bag rules", 170, 22, function() OpenRules(1) end)
    b:SetPoint("TOPLEFT", 0, -34)
    f.button = b
    return f, 60
end
EXTRAS["Vendors, trainers and mail"] = function(page)
    local f = CreateFrame("Frame", nil, page)
    local title = f:CreateFontString(nil, "OVERLAY")
    ns:Font(title, 12, true)
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText(ns:Tr("Send to"))
    ns:Paint(title, "SetTextColor", "@accent")
    local LABEL = { cloth = "Cloth", leather = "Leather", ore = "Ore and stone", herbs = "Herbs", cooking = "Cooking ingredients",
        elemental = "Elemental", enchanting = "Enchanting materials", gems = "Gems", potions = "Potions and food" }
    f.boxes = {}
    local targets = ns.MailTargets and ns.MailTargets() or {}
    for i, sw in ipairs(ns.MAIL_SWITCHES or {}) do
        local kind = sw[2]
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        local x, y = col * 245, -22 - row * 46
        local label = f:CreateFontString(nil, "OVERLAY")
        ns:Font(label, 11)
        label:SetPoint("TOPLEFT", x, y)
        label:SetText(ns:Tr(LABEL[kind]))
        ns:Paint(label, "SetTextColor", "dim")
        local box = ns:CreateEditBox(f, 230, 22, "a character's name")
        box:SetPoint("TOPLEFT", x, y - 16)
        box:SetText(targets[kind] or "")
        local function Save()
            local t = ns.MailTargets()
            local v = strtrim(box:GetText() or "")
            t[kind] = (v ~= "") and v or nil
        end
        box:HookScript("OnTextChanged", function(_, user) if user ~= false then Save() end end)
        box:HookScript("OnEditFocusLost", Save)
        box.kind = kind
        f.boxes[kind] = box
    end
    local h = 22 + math.ceil(#(ns.MAIL_SWITCHES or {}) / 3) * 46
    local b = ns:CreateButton(f, "Edit my own mail rules", 170, 22, function() OpenRules(2) end)
    b:SetPoint("TOPLEFT", 0, -h - 4)
    f.button = b
    f.Refresh = function()
        local t = ns.MailTargets()
        for kind, box in pairs(f.boxes) do if not box:HasFocus() then box:SetText(t[kind] or "") end end
    end
    f:SetSize(736, h + 30)
    return f, h + 30
end
ns.FeatureExtras = EXTRAS

local function BuildFeatures(page)
    -- One section at a time: the sections are listed down the left, the switches of the chosen one
    -- are on the right in two columns, and a card underneath says what the switch under the mouse
    -- does. Searching lists the matching switches from every section in the same place.
    local boxes = {}
    local TOP = -36
    local RX, COLW, PITCH = 0, 365, 26                        -- (the sections are listed by the window itself, down its left side)
    local CARD_Y, CARD_H = -400, 104

    local search = ns:CreateEditBox(page, 230, 22, "Search switches")
    search:SetPoint("TOPLEFT", 0, 0)
    local found = page:CreateFontString(nil, "OVERLAY")
    ns:Font(found, 11)
    found:SetPoint("LEFT", search, "RIGHT", 10, 0)
    ns:Paint(found, "SetTextColor", "faint")

    -- the sections, in the order of the lists above: { title, keys }
    local sections, labelOf, sectionOf = {}, {}, {}
    for _, group in ipairs(groups) do
        local current
        for _, opt in ipairs(group[2]) do
            local key = opt[1]
            if SECTIONS[key] then current = { title = SECTIONS[key], keys = {} }; sections[#sections + 1] = current end
            if not current then current = { title = group[1], keys = {} }; sections[#sections + 1] = current end
            if not (ns.aurasLocked and LOCKED_HIDE[key]) then
                current.keys[#current.keys + 1] = key
                labelOf[key] = (ns.aurasLocked and LOCKED_LABEL[key]) or opt[2]
                sectionOf[key] = #sections
            end
        end
    end
    page.sectionCount = #sections
    page.sections = sections

    -- the card: what the switch under the mouse does
    local card = CreateFrame("Frame", nil, page, ns.template)
    card:SetSize(736 - RX, CARD_H)
    card:SetBackdrop(ns.BACKDROP)
    ns:Paint(card, "SetBackdropColor", "field", 0.6)
    ns:Paint(card, "SetBackdropBorderColor", "@border", 0.7)
    card.title = card:CreateFontString(nil, "OVERLAY")
    ns:Font(card.title, 13, true)
    card.title:SetPoint("TOPLEFT", 12, -9)
    ns:Paint(card.title, "SetTextColor", "@accent")
    card.desc = card:CreateFontString(nil, "OVERLAY")
    ns:Font(card.desc, 11)
    card.desc:SetPoint("TOPLEFT", 12, -29)
    card.desc:SetWidth(736 - RX - 24)
    card.desc:SetJustifyH("LEFT")
    if card.desc.SetWordWrap then card.desc:SetWordWrap(true) end
    ns:Paint(card.desc, "SetTextColor", "dim")
    card.foot = card:CreateFontString(nil, "OVERLAY")
    ns:Font(card.foot, 10)
    card.foot:SetPoint("BOTTOMLEFT", 12, 7)
    ns:Paint(card.foot, "SetTextColor", "faint")
    local function Describe(key)
        if not key then
            card.title:SetText("")
            card.desc:SetText(ns:Tr("Point at a switch to read what it does."))
            card.foot:SetText("")
            return
        end
        card.title:SetText(ns:Tr(labelOf[key]))
        card.desc:SetText(ns:Tr(DESC[key] or ""))
        local needs = ns.featureNeeds and ns.featureNeeds[key]
        if needs and not ns.db[needs] then
            card.foot:SetText(format(ns:Tr("Needs \"%s\" switched on."), ns:Tr(labelOf[needs] or needs)))
        else
            card.foot:SetText(ns:Tr(INSTANT[key] and "Takes effect at once." or "Takes effect after a /reload."))
        end
        page.described = key
    end
    page.Describe = Describe

    local heading = page:CreateFontString(nil, "OVERLAY")
    ns:Font(heading, 15, true)
    heading:SetPoint("TOPLEFT", RX, TOP)
    ns:Paint(heading, "SetTextColor", "@accent")

    -- the switches: made once, placed whenever a section is chosen
    local Counts
    for _, section in ipairs(sections) do
        local half = math.ceil(#section.keys / 2)
        for n, key in ipairs(section.keys) do
            local label = labelOf[key]
            local cb = ns:CreateCheckbox(page, label, ns.db[key], function(v)
                ns.db[key] = v
                if INSTANT[key] then ns:ApplyInstant() else O.frame.note:Show() end
                Counts()
                if page.Dim then page.Dim() end
            end)
            cb:SetWidth(COLW - 6)
            cb.label:SetWidth(COLW - 6 - 36)                 -- (a name too long for its column is cut short; the card has it in full)
            cb.label:SetJustifyH("LEFT")
            if cb.label.SetWordWrap then cb.label:SetWordWrap(false) end
            cb.row = TOP - 30 - ((n - 1) % half) * PITCH
            cb.key = key
            cb.words = strlower(ns:Tr(label) .. " " .. ns:Tr(DESC[key] or "") .. " " .. key)
            cb:HookScript("OnEnter", function() Describe(key) end)
            cb:Hide()
            boxes[key] = cb
        end
    end

    -- a switch whose parent is off is dimmed (it can still be set, ready for when the parent is on)
    function page.Dim()
        local needs = ns.featureNeeds or {}
        for key, cb in pairs(boxes) do
            local parent = needs[key]
            if cb.SetAlpha then cb:SetAlpha((parent and not ns.db[parent]) and 0.45 or 1) end
        end
    end

    local navBottom = TOP
    local extras = {}
    page.extras = extras
    local function Layout(keys, title, extraName)
        for _, cb in pairs(boxes) do cb:Hide() end
        for _, e in pairs(extras) do e.frame:Hide() end
        local half = math.max(1, math.ceil(#keys / 2))
        for n, key in ipairs(keys) do
            local cb = boxes[key]
            if cb then
                cb:ClearAllPoints()
                cb:SetPoint("TOPLEFT", RX + ((n > half) and (COLW + 6) or 0), TOP - 30 - ((n - 1) % half) * PITCH)
                cb:Show()
            end
        end
        heading:SetText(title)
        if page.Dim then page.Dim() end
        local below = TOP - 30 - half * PITCH - 12
        local build = extraName and EXTRAS[extraName]
        if build then
            local e = extras[extraName]
            if not e then
                local f, h = build(page)
                e = { frame = f, height = h }
                extras[extraName] = e
            end
            e.frame:ClearAllPoints()
            e.frame:SetPoint("TOPLEFT", RX, below + 4)
            if e.frame.Refresh then e.frame.Refresh() end
            e.frame:Show()
            below = below + 4 - e.height - 14
        end
        local cardY = math.min(CARD_Y, below)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", RX, cardY)
        page.shownKeys = keys
        page.contentHeight = math.max(-navBottom, -cardY + CARD_H) + 12
        if page.area then page.area:SetContentHeight(page.contentHeight) end
    end

    -- the sections go in the list down the left of the window (see BuildNav), with how many are on
    local current = 1
    Counts = function() if page.NavCounts then page.NavCounts() end end
    local function Mark(which) if page.NavMark then page.NavMark(which) end end
    local function Select(i)
        if not sections[i] then return end
        current = i
        Mark(i)
        Layout(sections[i].keys, ns:Tr(sections[i].title), sections[i].title)
        page.currentSection = i
    end
    page.Select = Select
    page.navItems = {}
    for i, section in ipairs(sections) do
        page.navItems[i] = { title = section.title, count = function()
            local on = 0
            for _, key in ipairs(section.keys) do if ns.db[key] then on = on + 1 end end
            return on .. "/" .. #section.keys
        end }
    end
    page.NavSelect = function(i) search:SetText(""); Select(i) end

    -- search: the matching switches of every section, listed together
    local function Filter(given)
        local q = (type(given) == "string") and given or search:GetText()
        q = type(q) == "string" and strlower(strtrim(q)) or ""
        if q == "" then
            found:SetText("")
            Select(current)
            return page.sectionCount and #sections[current].keys or 0
        end
        local keys = {}
        for _, section in ipairs(sections) do
            for _, key in ipairs(section.keys) do
                if boxes[key].words:find(q, 1, true) then keys[#keys + 1] = key end
            end
        end
        Mark(0)
        Layout(keys, format(ns:TrN(#keys, "%d match", "%d matches"), #keys))
        found:SetText(#keys == 0 and ("|cffffd100" .. format(ns:Tr("No switch matches \"%s\"."), strtrim(q)) .. "|r") or "")
        return #keys
    end
    search:HookScript("OnTextChanged", Filter)
    page.Filter = function(text) search:SetText(text or ""); return Filter(text or "") end
    -- Bring a switch into view (the search of all options, and the guide, ask for this).
    page.Reveal = function(target)
        local key = type(target) == "table" and rawget(target, "key")
        local at = key and sectionOf[key]
        if not at then
            for i, b in ipairs(page.nav or {}) do if b == target then at = i end end
        end
        if not at then return false end
        search:SetText("")
        Select(at)
        if key then Describe(key) end
        return true
    end

    local function Sync()                                   -- the switches follow the settings (the setup may have changed them)
        for key, cb in pairs(boxes) do cb:SetChecked(ns.db[key]) end
        Counts()
    end
    page.Refresh = Sync
    -- presets: one click sets every switch (click twice, so a slip of the mouse changes nothing)
    local function Apply(preset)
        local changed = ns:ApplyPreset(preset)
        Sync()
        if changed > 0 then O.frame.note:Show() end
        return changed
    end
    page.ApplyPreset = Apply
    local x = 0
    for _, def in ipairs({ { "EVERYTHING", "Everything" }, { "STANDARD", "Standard" }, { "MINIMAL", "Minimal" } }) do
        local btn
        btn = ns:CreateButton(page, def[2], 96, 22, function(self)
            if self.armed then
                self.armed = false
                local n = Apply(def[1])
                self.text:SetText(ns:Tr(def[2]))
                found:SetText(format(ns:TrN(n, "%d switch changed", "%d switches changed"), n))
            else
                self.armed = true
                self.text:SetText("|cffffd100" .. ns:Tr("Click to confirm") .. "|r")
                ns:After(4, function() if btn.armed then btn.armed = false; btn.text:SetText(ns:Tr(def[2])) end end)
            end
        end)
        btn:SetPoint("TOPRIGHT", page, "TOPRIGHT", -x, 0)
        btn:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(ns:Tr(def[2]))
            local text = def[1] == "EVERYTHING" and "Every feature on."
                or def[1] == "MINIMAL" and "Only the core: frames, bars, minimap, quests, bags, chat and windows."
                or "How Fantasy Glass UI comes: everything except the four that flash, pop up or act on their own - notifications, the aggro warning, the AFK screen and level-up screenshots."
            GameTooltip:AddLine(ns:Tr(text), 1, 1, 1, true)
            GameTooltip:AddLine(ns:Tr("Auto quest and the look options are left as they are."), 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
        end)
        btn:HookScript("OnLeave", function() GameTooltip:Hide() end)
        x = x + 102
    end
    local label = page:CreateFontString(nil, "OVERLAY")
    ns:Font(label, 11)
    label:SetPoint("TOPRIGHT", page, "TOPRIGHT", -x - 4, -5)
    label:SetText(ns:Tr("Presets"))
    ns:Paint(label, "SetTextColor", "dim")


    page.boxes = boxes
    Describe(nil)
    Counts()
    Select(1)
    ns.featuresPage = page
end
O.BuildFeatures = BuildFeatures
