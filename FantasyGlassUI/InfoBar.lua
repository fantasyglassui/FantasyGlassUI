local _, ns = ...

ns:NewModule("infobar", function()
    local th = ns.theme
    local bar = CreateFrame("Frame", "FantasyGlassUIInfoBar", UIParent)
    bar:SetSize(520, 22)
    bar:SetPoint("TOP", UIParent, "TOP", 0, -2)
    bar:SetFrameStrata("BACKGROUND")
    bar:EnableMouse(true)

    -- the panel art lives on its own layer so its strength can go all the way to nothing
    local art = CreateFrame("Frame", nil, bar, ns.template)
    art:SetAllPoints()
    art:SetBackdrop(ns.BACKDROP)
    ns:Paint(art, "SetBackdropColor", "bg", 0.85)
    ns:Paint(art, "SetBackdropBorderColor", "@border", 1)
    ns:Dress(art, true)

    local layer = CreateFrame("Frame", nil, bar)
    layer:SetAllPoints()
    layer:SetFrameLevel(art:GetFrameLevel() + 3)
    local text = ns:NewText(layer, 12, "CENTER")
    text:SetPoint("CENTER")

    function ns:SetInfoBarBackground(percent)
        local v = math.max(0, math.min(100, tonumber(percent) or 0))
        ns.db.infobarBg = v
        art:SetAlpha(v / 100)
        if v == 0 then art:Hide() else art:Show() end
    end
    ns:SetInfoBarBackground(ns.db.infobarBg)

    local function ColorFor(value, good, warn, invert)
        local bad = invert and (value <= warn) or (not invert and value >= warn)
        local ok  = invert and (value >= good) or (not invert and value <= good)
        if ok then return ns:SignalHex("good") elseif bad then return ns:SignalHex("bad") end
        return ns:SignalHex("warn")
    end

    local loginMoney = GetMoney()

    local function FreeBagSlots()
        local free, total = 0, 0
        local C = C_Container
        if not (C and C.GetContainerNumFreeSlots and C.GetContainerNumSlots) then return nil end
        for bag = 0, 4 do
            local ok, f = pcall(C.GetContainerNumFreeSlots, bag)
            local ok2, t = pcall(C.GetContainerNumSlots, bag)
            if ok and type(f) == "number" then free = free + f end
            if ok2 and type(t) == "number" then total = total + t end
        end
        return free, total
    end
    local function FriendsOnline()
        local n = 0
        if C_FriendList and C_FriendList.GetNumOnlineFriends then
            local ok, v = pcall(C_FriendList.GetNumOnlineFriends)
            if ok and type(v) == "number" then n = n + v end
        end
        if BNGetNumFriends then
            local ok, _, online = pcall(BNGetNumFriends)
            if ok and type(online) == "number" then n = n + online end
        end
        return n
    end
    local function GuildOnline()
        if not (IsInGuild and IsInGuild() and GetNumGuildMembers) then return nil end
        local ok, _, online = pcall(GetNumGuildMembers)
        return (ok and type(online) == "number") and online or 0
    end

    -- The pieces of the bar, in the order they appear. Each can be switched off ("Info bar pieces"
    -- on the Layout tab, or right-click the bar). The four marked `extra` also need the Features
    -- switch "Info bar: bags, friends, guild".
    ns.infobarPieces = {
        { "role",       "Role" },
        { "fps",        "Frame rate" },
        { "ms",         "Latency" },
        { "durability", "Durability" },
        { "gold",       "Gold" },
        { "bags",       "Free bag slots", true },
        { "friends",    "Friends online", true },
        { "guild",      "Guild online", true },
        { "mail",       "Mail", true },
        { "speed",      "Movement speed" },
        { "hearth",     "Hearthstone cooldown" },
        { "currency",   "Currency" },
        { "reset",      "Daily reset" },
        { "volume",     "Volume" },
        { "clock",      "Clock" },
    }
    -- A piece is on unless switched off - except these, which are off unless switched on.
    local DEFAULT_OFF = { speed = true, hearth = true, currency = true, reset = true, volume = true }
    ns.infobarDefaultOff = DEFAULT_OFF
    for _, piece in ipairs(ns.apiInfoPieces or {}) do      -- pieces other add-ons added before the bar was made (API.lua)
        ns.infobarPieces[#ns.infobarPieces + 1] = { piece.key, piece.label }
        if piece.defaultOff then DEFAULT_OFF[piece.key] = true end
    end
    local function On(piece)
        local chosen = ns.db.infobarParts
        local v = type(chosen) == "table" and chosen[piece]
        if v == false then return false end
        if v == true then return true end
        return not DEFAULT_OFF[piece]
    end
    -- How fast you are moving, as a percentage of an ordinary run (100% on foot, more mounted). Standing
    -- still it shows what you would do if you set off.
    function ns.SpeedPercent()
        if type(GetUnitSpeed) ~= "function" then return nil end
        local ok, now, run = pcall(GetUnitSpeed, "player")
        if not ok or ns:IsSecret(now) or ns:IsSecret(run) or type(now) ~= "number" then return nil end
        local speed = (now > 0) and now or (type(run) == "number" and run or 0)
        return math.floor(speed / 7 * 100 + 0.5)
    end
    ns.InfoBarPieceOn = On
    local parts = {}                                        -- (one list, reused each second)
    local MORE = { "hearth", "currency", "reset", "volume" }
    local function Compose()
        for i = #parts, 1, -1 do parts[i] = nil end
        local role = ns.roles[ns.db.role]
        if On("role") and role then parts[#parts + 1] = ns:RoleHex(ns.db.role) .. "[" .. role.label .. "]|r" end
        if On("fps") then
            local fps = floor(GetFramerate())
            parts[#parts + 1] = format("%s%d|r fps", ColorFor(fps, 60, 30, true), fps)
        end
        if On("ms") then
            local ms = select(4, GetNetStats()) or select(3, GetNetStats()) or 0
            parts[#parts + 1] = format("%s%d|r ms", ColorFor(ms, 80, 200), ms)
        end
        if On("durability") then
            local dur = floor(ns:LowestDurability())
            parts[#parts + 1] = format("%s%d%%|r durability", ColorFor(dur, 60, 25, true), dur)
        end
        if On("gold") then parts[#parts + 1] = ns:Coins(GetMoney()) end
        if ns.db.infobarExtras then
            local free = On("bags") and FreeBagSlots()
            if free then parts[#parts + 1] = format("%s%d|r %s", ColorFor(free, 8, 3, true), free, ns:Tr("free")) end
            if On("friends") then parts[#parts + 1] = format("|cffffffff%d|r %s", FriendsOnline(), ns:Tr("friends")) end
            local guild = On("guild") and GuildOnline()
            if guild then parts[#parts + 1] = format("|cffffffff%d|r %s", guild, ns:Tr("guild")) end
            if On("mail") and HasNewMail and HasNewMail() then parts[#parts + 1] = "|cffffd100" .. ns:Tr("mail") .. "|r" end
        end
        if On("speed") then
            local pct = ns.SpeedPercent()
            if pct then parts[#parts + 1] = format("|cffffffff%d%%|r %s", pct, ns:Tr("speed")) end
        end
        for _, extra in ipairs(MORE) do
            if On(extra) and ns.InfoPiece then
                local ok, piece = pcall(ns.InfoPiece, extra)
                if ok and piece then parts[#parts + 1] = piece end
            end
        end
        for _, piece in ipairs(ns.apiInfoPieces or {}) do      -- pieces other add-ons added (API.lua)
            if On(piece.key) then
                local ok, txt = pcall(piece.text)
                if ok and type(txt) == "string" and txt ~= "" then parts[#parts + 1] = txt end
            end
        end
        if On("clock") then parts[#parts + 1] = "|cffffffff" .. ns:ClockText() .. "|r" end
        return table.concat(parts, "   "), #parts
    end
    ns.InfoBarCompose = Compose
    local function Update()
        local line, count = Compose()
        text:SetText(line)
        local w = text.GetStringWidth and text:GetStringWidth()
        if type(w) == "number" and w > 0 and not InCombatLockdown() then
            bar:SetWidth(math.max(count >= 5 and 520 or 140, w + 36))        -- (a short bar may be narrow)
        end
    end
    function ns:RefreshInfoBar() pcall(Update) end

    -- Switch one piece on or off. A piece that is on by default is stored only when switched off, and
    -- one that is off by default only when switched on, so new defaults reach everyone else.
    function ns.InfoBarSetPiece(key, on)
        if type(ns.db.infobarParts) ~= "table" then ns.db.infobarParts = {} end
        local parts = ns.db.infobarParts
        if DEFAULT_OFF[key] then
            if on then parts[key] = true else parts[key] = nil end
        else
            if on then parts[key] = nil else parts[key] = false end
        end
        return On(key)
    end
    -- choosing the pieces: a small list of switches, in two columns
    local pieces
    function ns:ToggleInfoBarPieces(anchor)
        if pieces and pieces:IsShown() then pieces:Hide(); return end
        if not pieces then
            pieces = CreateFrame("Frame", "FantasyGlassUIInfoBarPieces", UIParent, ns.template)
            pieces:SetSize(372, 40 + math.ceil(#ns.infobarPieces / 2) * 24 + 34)
            pieces:SetFrameStrata("FULLSCREEN_DIALOG")
            pieces:SetToplevel(true)
            pieces:SetBackdrop(ns.BACKDROP)
            ns:Paint(pieces, "SetBackdropColor", "@bg", 1)
            ns:Paint(pieces, "SetBackdropBorderColor", "@accent", 1)
            pieces:EnableMouse(true)
            local title = ns:NewText(pieces, 13, "LEFT", true)
            title:SetPoint("TOPLEFT", 12, -10)
            title:SetText(ns:Tr("Info bar pieces"))
            ns:Paint(title, "SetTextColor", "@accent")
            local close = ns:CreateButton(pieces, "X", 20, 20, function() pieces:Hide() end)
            close:SetPoint("TOPRIGHT", -6, -6)
            pieces.boxes = {}
            ns.infoBarPiecesFrame = pieces
            for n, def in ipairs(ns.infobarPieces) do
                local key = def[1]
                local cb = ns:CreateCheckbox(pieces, def[2], On(key), function(v)
                    ns.InfoBarSetPiece(key, v)
                    ns:RefreshInfoBar()
                end)
                local half = math.ceil(#ns.infobarPieces / 2)
                cb:SetWidth(170)
                cb:SetPoint("TOPLEFT", 12 + ((n > half) and 178 or 0), -34 - ((n - 1) % half) * 24)
                pieces.boxes[key] = cb
            end
            local note = ns:NewText(pieces, 10, "LEFT")
            note:SetPoint("BOTTOMLEFT", 12, 10)
            note:SetWidth(348)
            note:SetWordWrap(true)
            note:SetText(ns:Tr("Bags, friends, guild and mail also need their switch on the Features tab."))
            ns:Paint(note, "SetTextColor", "faint")
            tinsert(UISpecialFrames, "FantasyGlassUIInfoBarPieces")
        end
        for key, cb in pairs(pieces.boxes) do if cb.SetChecked then cb:SetChecked(On(key)) end end
        pieces:ClearAllPoints()
        if type(anchor) == "table" and anchor.GetObjectType then pieces:SetPoint("TOP", anchor, "BOTTOM", 0, -6) else pieces:SetPoint("CENTER") end
        pieces:Show()
    end

    local elapsed = 0
    bar:SetScript("OnUpdate", ns:Guard("Info bar", function(_, e)
        elapsed = elapsed + e
        if elapsed >= 1 then elapsed = 0; Update() end
    end))

    -- One tooltip with the details behind the numbers.
    local function Tooltip(self)
        local a = th.accent
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Fantasy Glass UI")

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(ns:Tr("Gold"), a[1], a[2], a[3])
        local chars = type(ns.root) == "table" and type(ns.root.inventory) == "table" and ns.root.inventory.chars
        local me, total, rows = ns:CharKey(), 0, {}
        if type(chars) == "table" then
            for key, c in pairs(chars) do
                if type(c) == "table" and type(c.money) == "number" then
                    local money = (key == me) and GetMoney() or c.money
                    rows[#rows + 1] = { key = key, money = money, class = c.class }
                    total = total + money
                end
            end
        end
        if #rows == 0 then rows[1] = { key = me, money = GetMoney() }; total = GetMoney() end
        table.sort(rows, function(x, y) return x.money > y.money end)
        for i, r in ipairs(rows) do
            if i > 12 then break end
            local cr, cg, cb = ns:ClassRGB(r.class)
            GameTooltip:AddDoubleLine((r.key:gsub(" %- .*$", "")), ns:Coins(r.money), cr or 1, cg or 1, cb or 1, 1, 1, 1)
        end
        if #rows > 1 then GameTooltip:AddDoubleLine(ns:Tr("All characters"), ns:Coins(total), 1, 0.82, 0, 1, 1, 1) end
        local change = GetMoney() - loginMoney
        if change ~= 0 then
            GameTooltip:AddDoubleLine(ns:Tr("This session"), (change > 0 and "+" or "-") .. ns:Coins(math.abs(change)), 1, 1, 1,
                change > 0 and 0.3 or 1, change > 0 and 1 or 0.35, 0.35)
        end

        local free, slots = FreeBagSlots()
        if free then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine(ns:Tr("Bag space"), format("%d / %d", free, slots), a[1], a[2], a[3], 1, 1, 1)
        end

        if C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex then
            local shown = 0
            local okN, n = pcall(C_FriendList.GetNumFriends)
            for i = 1, (okN and type(n) == "number") and n or 0 do
                local ok, f = pcall(C_FriendList.GetFriendInfoByIndex, i)
                if ok and type(f) == "table" and f.connected and type(f.name) == "string" then
                    if shown == 0 then GameTooltip:AddLine(" "); GameTooltip:AddLine(ns:Tr("Friends online"), a[1], a[2], a[3]) end
                    shown = shown + 1
                    if shown <= 12 then
                        GameTooltip:AddDoubleLine(f.name, format("%s  %s", tostring(f.level or ""), tostring(f.area or "")), 1, 1, 1, 0.7, 0.7, 0.7)
                    end
                end
            end
        end

        if IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo then
            if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end      -- ask for a fresh list
            local okN, n = pcall(GetNumGuildMembers)
            local shown = 0
            for i = 1, (okN and type(n) == "number") and math.min(n, 500) or 0 do
                local ok, name, _, _, level, _, zone, _, _, online, _, class = pcall(GetGuildRosterInfo, i)
                if ok and online and type(name) == "string" then
                    if shown == 0 then GameTooltip:AddLine(" "); GameTooltip:AddLine(ns:Tr("Guild online"), a[1], a[2], a[3]) end
                    shown = shown + 1
                    if shown <= 15 then
                        local cr, cg, cb = ns:ClassRGB(class)
                        GameTooltip:AddDoubleLine((name:gsub("%-.*$", "")), format("%s  %s", tostring(level or ""), tostring(zone or "")), cr or 1, cg or 1, cb or 1, 0.7, 0.7, 0.7)
                    end
                end
            end
            if shown > 15 then GameTooltip:AddLine(format(ns:Tr("... and %d more"), shown - 15), 0.7, 0.7, 0.7) end
        end

        if HasNewMail and HasNewMail() then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(ns:Tr("You have unread mail."), 1, 0.82, 0)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(ns:Tr("Click to open options"), 0.7, 0.7, 0.7)
        GameTooltip:AddLine(ns:Tr("Right-click to choose the pieces"), 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end
    bar:SetScript("OnEnter", ns:Guard("Info bar tooltip", Tooltip))
    bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- one handler for both buttons (a second one set later would replace the first, not join it)
    local function Clicked(self, button)
        if button == "RightButton" then ns:ToggleInfoBarPieces(self) else ns:ToggleConfig() end
    end
    ns.InfoBarClicked = Clicked
    bar:SetScript("OnMouseUp", Clicked)

    Update()
    ns:RegisterMovable(bar, "infobar", "Info Bar")
end)

-- Other add-ons' data on the info bar. Many add-ons publish a line of text (gold, memory, a
-- profession timer ...) through a small shared library called LibDataBroker. If one of your add-ons
-- brought that library, the lines it publishes are shown in a strip under the info bar: click and
-- hover do whatever that add-on set up. Nothing is shown if no add-on uses it.
ns:NewModule("infobarPlugins", function()
    local ldb
    pcall(function()
        local stub = _G.LibStub
        if stub then ldb = stub("LibDataBroker-1.1", true) end
    end)
    if type(ldb) ~= "table" or not ldb.DataObjectIterator then
        ns.brokerState = "none of your add-ons publishes info-bar data"
        return
    end
    local MAX, H = 8, 20

    local strip = CreateFrame("Frame", "FantasyGlassUIBrokers", UIParent)
    strip:SetSize(200, H)
    local home = _G.FantasyGlassUIInfoBar
    if type(home) == "table" then strip:SetPoint("TOP", home, "BOTTOM", 0, -2) else strip:SetPoint("TOP", UIParent, "TOP", 0, -26) end
    strip:SetFrameStrata("BACKGROUND")

    local buttons = {}
    local function Button(i)
        if buttons[i] then return buttons[i] end
        local b = CreateFrame("Button", nil, strip)
        b:SetHeight(H)
        b:RegisterForClicks("AnyUp")
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(14, 14)
        b.icon:SetPoint("LEFT", 0, 0)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.label = ns:NewText(b, 11, "LEFT")
        b.label:SetPoint("LEFT", 18, 0)
        b:SetScript("OnClick", function(self, button)
            local obj = self.obj
            if obj and type(obj.OnClick) == "function" then pcall(obj.OnClick, self, button) end
        end)
        b:SetScript("OnEnter", function(self)
            local obj = self.obj
            if not obj then return end
            if type(obj.OnTooltipShow) == "function" then
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                if pcall(obj.OnTooltipShow, GameTooltip) then GameTooltip:Show() else GameTooltip:Hide() end
            elseif type(obj.OnEnter) == "function" then
                pcall(obj.OnEnter, self)
            end
        end)
        b:SetScript("OnLeave", function(self)
            local obj = self.obj
            if obj and type(obj.OnLeave) == "function" then pcall(obj.OnLeave, self) end
            GameTooltip:Hide()
        end)
        buttons[i] = b
        return b
    end

    local function Refresh()
        local names, objects = {}, {}
        for name, obj in ldb:DataObjectIterator() do
            if type(name) == "string" and type(obj) == "table" and obj.type == "data source" then
                names[#names + 1] = name
                objects[name] = obj
            end
        end
        table.sort(names)                                    -- a steady order from one login to the next
        local x, n = 0, 0
        for _, name in ipairs(names) do
            if n >= MAX then break end
            local obj = objects[name]
            local text = obj.text
            if type(text) == "string" or type(text) == "number" then
                text = tostring(text)
                if type(obj.label) == "string" and obj.label ~= "" and text ~= "" then text = obj.label .. ": " .. text end
                if text ~= "" then
                    n = n + 1
                    local b = Button(n)
                    b.obj = obj
                    b.label:SetText(text)
                    local hasIcon = obj.icon ~= nil
                    if hasIcon then b.icon:SetTexture(obj.icon); b.icon:Show() else b.icon:Hide() end
                    b.label:ClearAllPoints()
                    b.label:SetPoint("LEFT", hasIcon and 18 or 0, 0)
                    local w = b.label.GetStringWidth and b.label:GetStringWidth()
                    w = (type(w) == "number" and w or 60) + (hasIcon and 18 or 0)
                    b:SetWidth(w)
                    b:ClearAllPoints()
                    b:SetPoint("LEFT", strip, "LEFT", x, 0)
                    b:Show()
                    x = x + w + 16
                end
            end
        end
        for i = n + 1, #buttons do buttons[i]:Hide() end
        if n > 0 and not InCombatLockdown() then strip:SetWidth(math.max(40, x - 16)) end
        if n > 0 then strip:Show() else strip:Hide() end
        ns.brokerState = n > 0 and (n .. " shown") or "the library is here, but nothing is published yet"
    end
    ns:Every(1, "Info bar plugins", Refresh)
    Refresh()
    ns:RegisterMovable(strip, "brokers", "Add-on Data")
end)
