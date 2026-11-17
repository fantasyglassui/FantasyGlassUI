local _, ns = ...

local function SkinItem(btn)
    if btn.suiSkinned then return end
    btn.suiSkinned = true
    ns:Kill(btn.NormalTexture or (btn.GetNormalTexture and btn:GetNormalTexture()))
    local icon = btn.icon or btn.Icon or _G[(btn:GetName() or "") .. "IconTexture"]
    if icon and icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    if btn.IconBorder then ns:Kill(btn.IconBorder) end

    local bg = btn:CreateTexture(nil, "BACKGROUND", nil, -8)       -- at the very bottom, so it can never cover the icon
    bg:SetAllPoints()
    bg:SetTexture(ns.FLAT)
    ns:Paint(bg, "SetVertexColor", "bg2", 0.85)
    ns:AddBorder(btn, 0, 0, 0, 1)

    if btn.GetHighlightTexture then ns:ColorTex(btn:GetHighlightTexture(), 1, 1, 1, 0.25) end
    if btn.GetPushedTexture then ns:ColorTex(btn:GetPushedTexture(), 1, 0.85, 0.2, 0.35) end
end

local function ColorItem(btn)
    if not btn.suiBorder then return end
    local bag = btn.GetBagID and btn:GetBagID() or (btn.GetParent and btn:GetParent() and btn:GetParent().GetID and btn:GetParent():GetID())
    local slot = btn:GetID()
    local r, g, b = ns:T("border")
    if bag and slot then
        local _, _, quality = ns:BagItem(bag, slot)
        local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        if c and quality > 1 then r, g, b = c.r, c.g, c.b
        elseif quality == 0 then r, g, b = 0.45, 0.45, 0.45 end
    end
    btn.suiBorder:SetBackdropBorderColor(r, g, b, 1)
end

-- Fallback: restyles Blizzard's own bag frames while our bag window is off.
ns:NewModule("fallbacks", function()
    if ns.db.bagWindow then return end      -- our own bag window replaces Blizzard's
    local frames = { _G.ContainerFrameCombinedBags }
    for i = 1, 13 do frames[#frames + 1] = _G["ContainerFrame" .. i] end

    local function UpdateFrame(frame)
        if not frame or not frame.EnumerateValidItems then return end
        for _, btn in frame:EnumerateValidItems() do
            SkinItem(btn)
            ColorItem(btn)
        end
    end
    for _, f in pairs(frames) do ns:SkinWindow(f) end

    -- Refresh when bag contents change or a bag window opens (polled; no hooks on bag frames)
    local guard = ns:Guard("Bags", UpdateFrame)
    local dirty, wasShown = true, {}
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("BAG_UPDATE_DELAYED")
    ev:SetScript("OnEvent", ns:Guard("Bags events", function() dirty = true end))
    local acc = 0
    ev:SetScript("OnUpdate", function(_, e)
        acc = acc + e
        if acc < 0.2 then return end
        acc = 0
        for _, f in pairs(frames) do
            local shown = f.IsShown and f:IsShown() and true or false
            if shown and (dirty or not wasShown[f]) then guard(f) end
            wasShown[f] = shown
        end
        dirty = false
    end)
end)
