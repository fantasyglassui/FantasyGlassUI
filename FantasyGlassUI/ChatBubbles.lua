local _, ns = ...

-- Chat bubbles in the theme's own style, built from the same parts as the add-on's panels.
--
--   Glass themes     a see-through pane (rounded where the client allows) with a soft shadow, a
--                    bright top edge, a thin rim and a bar of the accent color down its left side.
--   Fantasy themes   a solid panel with grain, a dark outer line, a rim in the theme's metal and
--                    small corner brackets in the accent color.
--   Celestial themes a small piece of night sky with a few stars, one fine line with a soft glow
--                    inside it, and a small star at the top.
--
-- Both have a tail that is part of the outline, and the speaker's name on a small tab above, in
-- their class color. The words keep the game's own color, because it says what kind of speech it
-- is (say, yell, party).
--
-- The game creates and recycles the bubble frames itself. We look them up a few times a second and
-- dress each one once; nothing is hooked. Inside dungeons and raids the game locks bubbles away from
-- add-ons, so there they keep Blizzard's look.
ns:NewModule("chatBubbles", function()
    local CB = C_ChatBubbles
    if not (type(CB) == "table" and CB.GetAllChatBubbles) then return end

    -- who said what, so a bubble can be given its speaker's name
    local recent = {}
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
                         "CHAT_MSG_RAID_LEADER", "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_PARTY" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", ns:Guard("Chat bubbles", function(_, _, text, sender, _, _, _, _, _, _, _, _, _, guid)
        if type(text) ~= "string" or ns:IsSecret(text) or type(sender) ~= "string" or ns:IsSecret(sender) then return end
        local class
        if type(guid) == "string" and GetPlayerInfoByGUID then
            local ok, _, token = pcall(GetPlayerInfoByGUID, guid)
            if ok and type(token) == "string" then class = token end
        end
        recent[text] = { name = (sender:gsub("%-.*$", "")), class = class, at = GetTime() }
    end))
    -- Bubbles only appear when someone speaks, so the look below runs for a while after a line is
    -- heard and sleeps the rest of the time. (Any chat line wakes it, even one the add-on can't read.)
    local awakeUntil = 0
    local wake = CreateFrame("Frame")
    for _, e in ipairs({ "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
                         "CHAT_MSG_RAID_LEADER", "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_PARTY" }) do
        pcall(wake.RegisterEvent, wake, e)
    end
    wake:SetScript("OnEvent", function(_, event)
        if type(event) == "string" and event:find("^CHAT_MSG_") then awakeUntil = GetTime() + 12 end
    end)

    local function FindString(frame)
        if type(frame.String) == "table" and frame.String.SetFont then return frame.String end
        for _, r in ipairs({ frame:GetRegions() }) do
            if type(r) == "table" and r.GetObjectType and r:GetObjectType() == "FontString" then return r end
        end
    end

    local grains = setmetatable({}, { __mode = "k" })      -- fantasy grain takes the theme's tint
    ns:OnTheme(function()
        local g = ns.theme.grain
        for tex in pairs(grains) do pcall(tex.SetVertexColor, tex, g[1], g[2], g[3], g[4] or 0.13) end
    end)

    -- Everything is drawn as textures on the bubble's own frame, in its background layer, so the
    -- game's text always stays on top. Each piece is tagged (.sui) so it survives the strip of
    -- Blizzard's art, and named (.part) so it can be told apart.
    local function Dress(holder, str)
        holder.suiBubble = true
        local glass = (ns.style == "GLASS")
        local round = ns:CanRound()
        local alpha = glass and 0.92 or 0.97
        local function tex(part, sub, layer)
            local t = holder:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
            t.sui, t.part = true, part
            return t
        end
        local function flat(part, sub, layer)
            local t = tex(part, sub, layer)
            t:SetTexture(ns.FLAT)
            return t
        end
        -- four one-pixel lines round a region; inset below zero puts them outside it
        local function Lines(part, anchor, inset, sub, role, a, keep)
            for _, def in ipairs({ { "TOPLEFT", "TOPRIGHT", false }, { "BOTTOMLEFT", "BOTTOMRIGHT", false },
                                   { "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true } }) do
                local t = flat(part, sub)
                local function at(point)
                    local dx = point:find("LEFT") and inset or -inset
                    local dy = point:find("TOP") and -inset or inset
                    t:SetPoint(point, anchor, point, dx, dy)
                end
                at(def[1]); at(def[2])
                if def[3] then t:SetWidth(1) else t:SetHeight(1) end
                ns:Paint(t, "SetVertexColor", role, a)
                if keep then keep[#keep + 1] = t end
            end
        end
        local function Gradient(t, r, g, b, bottomAlpha, topAlpha, fallback)
            if t.SetGradient and CreateColor then
                t:SetGradient("VERTICAL", CreateColor(r, g, b, bottomAlpha), CreateColor(r, g, b, topAlpha))
            else
                t:SetVertexColor(r, g, b, fallback)
            end
        end

        -- the pane hugs the words, whatever size the game made the bubble
        local fill = tex("fill", -6)
        fill:SetPoint("TOPLEFT", str, "TOPLEFT", glass and -15 or -13, 9)
        fill:SetPoint("BOTTOMRIGHT", str, "BOTTOMRIGHT", glass and 12 or 13, -9)
        if round then ns:SliceTexture(fill, "round.tga") else fill:SetTexture(ns.FLAT) end
        ns:Paint(fill, "SetVertexColor", "window", alpha)
        local lt = ns.theme.light

        if glass then
            local shadow = tex("shadow", -8)                 -- the same shape in shadow, a little lower and wider
            shadow:SetPoint("TOPLEFT", fill, "TOPLEFT", -2, 0)
            shadow:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 2, -4)
            if round then ns:SliceTexture(shadow, "round.tga") else shadow:SetTexture(ns.FLAT) end
            shadow:SetVertexColor(0, 0, 0, 0.34)
            local side = round and 6 or 1                    -- keep the light clear of rounded corners
            local sheen = flat("sheen", -5)
            sheen:SetPoint("TOPLEFT", fill, "TOPLEFT", side, -1)
            sheen:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", -side, 1)
            Gradient(sheen, lt[1], lt[2], lt[3], 0, 0.12, 0.05)
            if round then
                local rim = tex("rim", -4)
                rim:SetAllPoints(fill)
                ns:SliceTexture(rim, "round_edge.tga")
                ns:Paint(rim, "SetVertexColor", "@border", 1)
            else
                Lines("rim", fill, 0, -4, "@border", 1)
            end
            local edge = flat("edge", -3)                    -- the pane catching light along its top
            edge:SetHeight(1)
            edge:SetPoint("TOPLEFT", fill, "TOPLEFT", side, -1)
            edge:SetPoint("TOPRIGHT", fill, "TOPRIGHT", -side, -1)
            ns:Paint(edge, "SetVertexColor", "@light", 0.26)
            local bar = flat("accent", -3)                   -- a bar of the accent color, like a quoted line
            bar:SetWidth(2)
            bar:SetPoint("TOPLEFT", fill, "TOPLEFT", 6, -7)
            bar:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT", 6, 7)
            ns:Paint(bar, "SetVertexColor", "@accent", 0.95)
        elseif ns.style == "CELESTIAL" then
            -- a small piece of night sky: deeper toward the top, lit along its foot, a scatter of stars,
            -- one fine line with a soft glow inside it, and the small star at the top every Celestial window has
            local a, bg = ns.theme.accent, ns.theme.bg
            local sky = flat("sky", -5)
            sky:SetPoint("TOPLEFT", fill, "TOPLEFT", 1, -1)
            sky:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", -1, 1)
            Gradient(sky, math.min(1, bg[1] * 1.6 + a[1] * 0.05), math.min(1, bg[2] * 1.6 + a[2] * 0.05), math.min(1, bg[3] * 1.6 + a[3] * 0.05 + 0.012), 0, 0.9, 0.3)
            local horizon = tex("horizon", -4)
            horizon:SetTexture(ns.MEDIA .. "glow_up.tga")
            horizon:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT", 1, 1)
            horizon:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", -1, 1)
            horizon:SetHeight(10)
            ns:Paint(horizon, "SetVertexColor", "@accent", 0.16)
            local stars = tex("stars", -4)
            stars:SetTexture(ns.MEDIA .. "stars.tga")
            stars:SetPoint("TOPLEFT", fill, "TOPLEFT", 1, -1)
            stars:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", -1, 1)
            stars:SetTexCoord(0.1, 0.45, 0.2, 0.32)           -- (a strip of the sky: the stars keep their size)
            ns:Paint(stars, "SetVertexColor", "@light", 0.35)
            Lines("outline", fill, -1, -7, "bg", 0.8)
            Lines("rim", fill, 0, -3, "@border", 1)
            Lines("glow", fill, 1, -3, "@accent", 0.10)
            local star = tex("star", 4, "BORDER")
            star:SetTexture(ns.MEDIA .. "sparkle.tga")
            star:SetSize(12, 12)
            star:SetPoint("CENTER", fill, "TOP", 0, 0)
            if star.SetBlendMode then star:SetBlendMode("ADD") end
            ns:Paint(star, "SetVertexColor", "@accent", 1)
        else
            Lines("outline", fill, -1, -7, "@rim", 0.95)     -- the dark line just outside the rim
            local grain = tex("grain", -5)
            grain:SetPoint("TOPLEFT", fill, "TOPLEFT", 1, -1)
            grain:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", -1, 1)
            if not pcall(grain.SetTexture, grain, ns.MEDIA .. "panel.tga", "REPEAT", "REPEAT") then
                grain:SetTexture(ns.MEDIA .. "panel.tga")
            end
            if grain.SetHorizTile then grain:SetHorizTile(true); grain:SetVertTile(true) end
            local g = ns.theme.grain
            grain:SetVertexColor(g[1], g[2], g[3], g[4] or 0.13)
            grains[grain] = true
            local light = flat("light", -4)                  -- lit from above
            light:SetPoint("TOPLEFT", fill, "TOPLEFT", 1, -1)
            light:SetPoint("TOPRIGHT", fill, "TOPRIGHT", -1, -1)
            light:SetHeight(12)
            Gradient(light, lt[1], lt[2], lt[3], 0, 0.14, 0.05)
            local shade = flat("shade", -4)                  -- and deeper toward the bottom
            shade:SetPoint("TOPLEFT", fill, "TOPLEFT", 1, -1)
            shade:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", -1, 1)
            Gradient(shade, 0, 0, 0, 0.30, 0, 0.08)
            Lines("rim", fill, 0, -3, "@border", 1)
            for point, c in pairs({ TOPLEFT = { 0, 1, 0, 1, 1, -1 }, TOPRIGHT = { 1, 0, 0, 1, -1, -1 },
                                    BOTTOMLEFT = { 0, 1, 1, 0, 1, 1 }, BOTTOMRIGHT = { 1, 0, 1, 0, -1, 1 } }) do
                local t = tex("corner", 1, "BORDER")         -- the small brackets our fantasy panels wear
                t:SetTexture(ns.MEDIA .. "corner.tga")
                t:SetTexCoord(c[1], c[2], c[3], c[4])
                t:SetSize(9, 9)
                t:SetPoint(point, fill, point, c[5], c[6])
                ns:Paint(t, "SetVertexColor", "@accent", 1)
            end
        end

        -- The tail. A short strip in the pane's color hides the rim where the tail joins, so the
        -- outline runs round the pane and the tail as one shape.
        local drop = glass and 0 or -1
        local joint = flat("joint", -2)
        joint:SetSize(12, glass and 2 or 3)
        joint:SetPoint("BOTTOM", fill, "BOTTOM", 0, drop)
        ns:Paint(joint, "SetVertexColor", "window", 1)
        local tail = tex("tail", -2)
        tail:SetTexture(ns.MEDIA .. "tail.tga")
        tail:SetSize(14, 8)
        tail:SetPoint("TOP", fill, "BOTTOM", 0, drop)
        ns:Paint(tail, "SetVertexColor", "window", alpha)
        local tailEdge = tex("tailEdge", -1)
        tailEdge:SetTexture(ns.MEDIA .. "tail_edge.tga")
        tailEdge:SetAllPoints(tail)
        ns:Paint(tailEdge, "SetVertexColor", "@border", 1)

        -- The speaker's name, on a tab of its own: a floating chip on glass, attached on fantasy.
        local name = holder:CreateFontString(nil, "OVERLAY")
        ns:Font(name, 11, true)
        name:SetPoint("BOTTOMLEFT", fill, "TOPLEFT", glass and 13 or 11, glass and 7 or 4)
        local tabParts = {}
        local tab = tex("tab", 2)
        tab:SetPoint("TOPLEFT", name, "TOPLEFT", -7, 3)
        tab:SetPoint("BOTTOMRIGHT", name, "BOTTOMRIGHT", 7, -3)
        if round then ns:SliceTexture(tab, "round.tga") else tab:SetTexture(ns.FLAT) end
        ns:Paint(tab, "SetVertexColor", "window", alpha)
        tabParts[1] = tab
        if round then
            local tabRim = tex("tabRim", 3)
            tabRim:SetAllPoints(tab)
            ns:SliceTexture(tabRim, "round_edge.tga")
            ns:Paint(tabRim, "SetVertexColor", "@border", 1)
            tabParts[#tabParts + 1] = tabRim
        else
            if not glass then Lines("tabOutline", tab, -1, 1, "@rim", 0.95, tabParts) end
            Lines("tabRim", tab, 0, 3, "@border", 1, tabParts)
        end
        holder.suiName, holder.suiTab, holder.suiString = name, tabParts, str
    end

    local function Style(bubble)
        if type(bubble) ~= "table" or (bubble.IsForbidden and bubble:IsForbidden()) then return end
        local holder = bubble.GetChildren and bubble:GetChildren()        -- newer clients keep the art on a child frame
        if type(holder) ~= "table" or not holder.GetRegions then holder = bubble end
        if holder.IsForbidden and holder:IsForbidden() then return end
        local str = holder.suiString or FindString(holder)
        if not str then return end

        if not holder.suiBubble then Dress(holder, str) end
        ns:StripArt(holder)                                 -- Blizzard's bubble and tail (ours are tagged and kept)
        local size = tonumber(ns.db.bubbleFont) or 13
        if holder.suiFontSize ~= size or holder.suiFontScale ~= ns.fontScale then    -- (only when it changed: this runs ten times a second)
            holder.suiFontSize, holder.suiFontScale = size, ns.fontScale
            ns:Font(str, size)
        end

        -- speaker's name, when we saw the line that this bubble is showing
        local label = holder.suiName
        local shown = false
        if ns.db.bubbleNames then
            local ok, text = pcall(str.GetText, str)
            if ok and type(text) == "string" and not ns:IsSecret(text) then
                local who = recent[text]
                if who and GetTime() - who.at < 20 then
                    label:SetText(who.name)
                    local r, g, b = ns:ClassRGB(who.class)
                    if r then label:SetTextColor(r, g, b) else ns:Paint(label, "SetTextColor", "dim") end
                    shown = true
                end
            end
        end
        if holder.suiTabShown ~= shown then                 -- the tab comes and goes with the name
            holder.suiTabShown = shown
            if shown then label:Show() else label:Hide() end
            for _, part in ipairs(holder.suiTab or {}) do
                if shown then part:Show() else part:Hide() end
            end
        end
    end
    ns.StyleBubble = Style
    -- (for tests) note a line as heard from someone; with no name, forget it
    function ns:BubbleHeard(text, name, class)
        recent[text] = name and { name = name, class = class, at = GetTime() } or nil
    end

    local function Poll()
        if GetTime() > awakeUntil then return end
        local ok, list = pcall(CB.GetAllChatBubbles, false)          -- false: skip the ones the game has locked
        if not ok or type(list) ~= "table" then return end
        for _, bubble in pairs(list) do pcall(Style, bubble) end
    end
    ns.BubblePoll = Poll
    ns:Every(0.1, "Chat bubbles", Poll)

    -- forget old lines so the table never grows
    ns:Every(30, "Chat bubbles", function()
        local now = GetTime()
        for text, who in pairs(recent) do
            if now - who.at > 30 then recent[text] = nil end
        end
    end)
end)
