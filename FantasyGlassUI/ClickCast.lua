local _, ns = ...

-- Click-casting: bind a mouse button (with or without a modifier) to a spell, and clicking a unit
-- frame casts it on that player. Bindings are plain secure attributes, so they work in combat;
-- changing them has to wait until you are out of combat.
--   ns.db.clickCast = { { mod = "shift", button = 1, spell = "Renew" }, ... }

local targets = {}            -- every secure unit frame of ours

function ns:RegisterClickCast(frame)
    targets[#targets + 1] = frame
end

local function Keys(binding)
    local prefix = (binding.mod and binding.mod ~= "") and (binding.mod .. "-") or ""
    return prefix .. "type" .. binding.button, prefix .. "spell" .. binding.button
end

local function Valid(b)
    return type(b) == "table" and type(b.spell) == "string" and b.spell ~= "" and type(b.button) == "number"
       and b.button >= 1 and b.button <= 5 and (b.mod == nil or b.mod == "" or b.mod == "shift" or b.mod == "ctrl" or b.mod == "alt")
end

-- Returns true when applied, false when it has to wait for combat to end.
function ns:ApplyClickCast()
    if InCombatLockdown() then
        ns:Print("Click-cast changes apply when you leave combat.")
        ns.clickCastPending = true
        return false
    end
    ns.clickCastPending = nil
    local list = {}
    for _, b in ipairs(type(ns.db.clickCast) == "table" and ns.db.clickCast or {}) do
        if Valid(b) then list[#list + 1] = b end
    end
    for _, frame in ipairs(targets) do
        if frame.SetAttribute and not frame.suiSample then
            for _, key in ipairs(frame.suiClickKeys or {}) do frame:SetAttribute(key, nil) end     -- remove the old set
            frame.suiClickKeys = {}
            for _, b in ipairs(list) do
                local typeKey, spellKey = Keys(b)
                frame:SetAttribute(typeKey, "spell")
                frame:SetAttribute(spellKey, b.spell)
                frame.suiClickKeys[#frame.suiClickKeys + 1] = typeKey
                frame.suiClickKeys[#frame.suiClickKeys + 1] = spellKey
            end
        end
    end
    -- raid cells that don't exist yet pick the bindings up from the header when they are created
    local header = ns.raidHeader
    if header and header.SetAttribute then
        header:SetAttribute("ccCount", #list)
        for i, b in ipairs(list) do
            local typeKey, spellKey = Keys(b)
            header:SetAttribute("ccTypeKey" .. i, typeKey)
            header:SetAttribute("ccSpellKey" .. i, spellKey)
            header:SetAttribute("ccSpell" .. i, b.spell)
        end
    end
    return true
end

do  -- finish a change that was asked for mid-fight
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", ns:Guard("ClickCast events", function()
        if ns.clickCastPending and ns.db then
            local ok, applied = pcall(ns.ApplyClickCast, ns)
            if ok and applied then ns:Print("Click-cast changes are in place now.") end       -- (said they would wait: now say they are done)
        end
    end))
end
