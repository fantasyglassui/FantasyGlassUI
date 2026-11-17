local _, ns = ...

-- Chat look. Everything is painted on the chat frame's own background layer, so it always sits
-- behind the text, and its strength is adjustable (Layout tab: "Chat background").
ns:NewModule("chatSkin", function()
    local th = ns.theme
    local tabParts = { "Left", "Middle", "Right", "SelectedLeft", "SelectedMiddle", "SelectedRight",
                       "HighlightLeft", "HighlightMiddle", "HighlightRight",
                       "ActiveLeft", "ActiveMiddle", "ActiveRight" }
    local editParts = { "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }
    local fills = {}

    local function Hide(tex) if tex and tex.SetAlpha then tex:SetAlpha(0) end end

    local function Strength()
        local v = tonumber(ns.db.chatBg) or 25
        return math.max(0, math.min(100, v)) / 100
    end

    for i = 1, NUM_CHAT_WINDOWS do
        local chat = _G["ChatFrame" .. i]
        if chat then
            -- our own tint, 4px larger than the text area
            local fill = chat:CreateTexture(nil, "BACKGROUND", nil, -8)
            fill:SetPoint("TOPLEFT", -4, 4)
            fill:SetPoint("BOTTOMRIGHT", 4, -4)
            fill:SetTexture(ns.FLAT)
            fill:SetVertexColor(th.bg[1], th.bg[2], th.bg[3], Strength())
            fills[#fills + 1] = fill
            local rim = ns:Outline(chat, -4, th.border[1], th.border[2], th.border[3], 0.55, "BACKGROUND")
            fill.rim = rim

            -- Blizzard paints its own dark sheet behind chat; two sheets on top of each other is what made it too dark
            -- (emptied rather than faded, because the game animates that sheet's opacity whenever you hover chat)
            for _, sheet in ipairs({ _G["ChatFrame" .. i .. "Background"], chat.Background }) do
                if type(sheet) == "table" and sheet.SetTexture then pcall(sheet.SetTexture, sheet, nil) end
            end

            -- lettering with a firmer shadow so it reads over bright scenery too
            if chat.SetShadowOffset then
                chat:SetShadowOffset(1, -1)
                chat:SetShadowColor(0, 0, 0, 1)
            end

            local tab = _G["ChatFrame" .. i .. "Tab"]
            if tab then
                for _, part in ipairs(tabParts) do
                    Hide(tab[part]); Hide(_G["ChatFrame" .. i .. "Tab" .. part])
                end
                local text = tab.Text or _G["ChatFrame" .. i .. "TabText"]
                if text and text.SetFont then ns:Font(text, 12) end
            end

            local eb = _G["ChatFrame" .. i .. "EditBox"]
            if eb then
                for _, part in ipairs(editParts) do
                    Hide(eb[part]); Hide(_G["ChatFrame" .. i .. "EditBox" .. part])
                end
                local ebFill = eb:CreateTexture(nil, "BACKGROUND", nil, -8)
                ebFill:SetPoint("TOPLEFT", 2, -2)
                ebFill:SetPoint("BOTTOMRIGHT", -2, 2)
                ebFill:SetTexture(ns.FLAT)
                ns:Paint(ebFill, "SetVertexColor", "@bg", 0.85)
                eb.suiRim = ns:Outline(eb, 2, th.border[1], th.border[2], th.border[3], 1, "BACKGROUND")
            end
        end
    end

    -- live adjustment from the options slider
    function ns:SetChatBackground(percent)
        ns.db.chatBg = percent
        for _, fill in ipairs(fills) do
            fill:SetVertexColor(th.bg[1], th.bg[2], th.bg[3], Strength())
            fill.rim:SetColor(th.border[1], th.border[2], th.border[3], Strength() > 0 and 0.55 or 0)
        end
    end
    ns:SetChatBackground(ns.db.chatBg or 25)
    ns:OnTheme(function() ns:SetChatBackground(ns.db.chatBg or 25) end)

    -- the edit box rim takes the color of the channel you are typing in
    if ChatEdit_UpdateHeader then
        hooksecurefunc("ChatEdit_UpdateHeader", ns:Safe("Chat edit box", function(eb)
            if not eb.suiRim then return end
            local t = eb:GetAttribute("chatType")
            if t == "CHANNEL" then t = "CHANNEL" .. (eb:GetAttribute("channelTarget") or "") end
            local info = t and ChatTypeInfo[t]
            if info then eb.suiRim:SetColor(info.r, info.g, info.b, 1) end
        end))
    end
end)
