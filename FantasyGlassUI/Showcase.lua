local _, ns = ...

------------------------------------------------------------------------------------------
-- Screenshot mode (11.13): /fgui showcase (or /fgui screenshot). Every frame comes up with sample data
-- worth a picture - a boss as your target with a breath on its way, a party of four classes at
-- different health, a focus and a pet with names of their own, the raid frames, the cast bar - and
-- everything that would spoil the picture goes: the options window, the movers, the tooltip, and
-- the busier samples (notifications, warnings, loot rolls). A short note says how to end it and fades
-- before you take the shot. Nothing is said in chat.
--
-- The same command ends it, and so does a fight. It is the preview (/fgui test) underneath: frames
-- show you until they are given their sample, and everything is put back when it ends.
------------------------------------------------------------------------------------------
local DRAGON = "Interface\\Icons\\INV_Misc_Head_Dragon_Black"

-- A spell's name and picture in the game's own language, or the English given.
local function Spell(id, fallback, icon)
    local name, tex
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, id)
        if ok and type(info) == "table" then name, tex = info.name, info.iconID end
    elseif GetSpellInfo then
        local ok, n, _, t = pcall(GetSpellInfo, id)
        if ok then name, tex = n, t end
    end
    if type(name) ~= "string" or ns:IsSecret(name) or name == "" then name = fallback end
    return name, tex or icon
end

-- What each frame shows, by its unit. A frame not listed keeps showing you; `hide` puts it away.
function ns.ShowcaseSamples()
    local breath, breathIcon = Spell(18435, "Flame Breath", "Interface\\Icons\\Spell_Fire_Fire")
    local fireball, fireIcon = Spell(133, "Fireball", "Interface\\Icons\\Spell_Fire_FlameBolt")
    local boss = { 1, 0.3, 0.25 }
    local red = { 0.78, 0.19, 0.16 }
    local rage, mana = { 0.78, 0.25, 0.25 }, { 0.25, 0.5, 1 }
    return {
        target = { name = "Onyxia", level = "??", levelColor = boss, color = red, hp = 72, pp = 92, icon = DRAGON,
                   cast = { name = breath, icon = breathIcon, done = 42 } },
        focus = { name = "Onyxian Warder", level = "62", levelColor = boss, color = red, hp = 45, pp = 30, icon = DRAGON,
                  cast = { name = fireball, icon = fireIcon, done = 70 } },
        focustarget = { name = "Brannoc", class = "WARRIOR", hp = 58 },
        pet = { name = "Ironfang", color = { 0.25, 0.75, 0.35 }, hp = 100, pp = 80, powerColor = { 1, 0.82, 0.25 }, icon = "Interface\\Icons\\Ability_Hunter_Pet_Wolf" },
        party1 = { name = "Kaelith", class = "PRIEST", hp = 94, pp = 71, powerColor = mana },
        party2 = { name = "Brannoc", class = "WARRIOR", hp = 58, pp = 40, powerColor = rage },
        party3 = { name = "Sylvae", class = "MAGE", hp = 100, pp = 88, powerColor = mana },
        party4 = { name = "Tormund", class = "PALADIN", hp = 23, pp = 35, powerColor = mana },
        boss1 = { name = "Onyxia", level = "??", levelColor = boss, color = red, hp = 72, pp = 92, icon = DRAGON },
        boss2 = { name = "Onyxian Whelp", level = "57", levelColor = boss, color = red, hp = 40, icon = DRAGON },
        boss3 = { name = "Onyxian Whelp", level = "57", levelColor = boss, color = red, hp = 65, icon = DRAGON },
        boss4 = { hide = true }, boss5 = { hide = true },
        arena1 = { hide = true }, arena2 = { hide = true }, arena3 = { hide = true }, arena4 = { hide = true }, arena5 = { hide = true },
    }
end

local note
local function Note(text)
    if not note then
        note = CreateFrame("Frame", nil, UIParent)
        note:SetFrameStrata("TOOLTIP")
        note:SetSize(600, 40)
        note:SetPoint("TOP", UIParent, "TOP", 0, -120)
        note.text = ns:NewText(note, 15, "CENTER", true)
        note.text:SetAllPoints()
        ns:Paint(note.text, "SetTextColor", "@accent")
    end
    note.text:SetText(ns:Tr(text))
    note:SetAlpha(1)
    note:Show()
    local started = GetTime()
    note:SetScript("OnUpdate", function(self)
        local t = GetTime() - started
        if t > 4 then self:SetAlpha(math.max(0, 1 - (t - 4)))  end
        if t > 5 then self:Hide(); self:SetScript("OnUpdate", nil) end
    end)
end

local function Frames()
    local list = {}
    for _, f in ipairs(ns.unitFrameList or {}) do if f.realUnit then list[#list + 1] = f end end
    return list
end

local function Clear()
    for _, f in ipairs(Frames()) do
        if f.showcase == true or (f.cast and f.cast.showcase == true) then
            ns.UnitFrameSample(f, nil)
            if ns.UnitFrameUpdate then pcall(ns.UnitFrameUpdate, f) end
        end
    end
end

function ns:ToggleShowcase(force)
    local want = force
    if want == nil then want = not ns.showcasing end
    if want == (ns.showcasing or false) then return end
    if want and InCombatLockdown() then ns:Print("Screenshot mode can't start in a fight.") return end
    if want then
        ns.showcasing = true
        if ns.configFrame and ns.configFrame:IsShown() then ns.configFrame:Hide() end
        if ns.moving and ns.ToggleMove then pcall(ns.ToggleMove, ns) end
        if GameTooltip then GameTooltip:Hide() end
        if ns.previewing then ns:TogglePreview(true) end          -- (start it afresh, in screenshot mode)
        ns:TogglePreview(nil, "showcase", true)
        local samples = ns.ShowcaseSamples()
        for _, f in ipairs(Frames()) do
            local d = samples[f.realUnit]
            if d and d.hide then
                f:Hide()
            elseif d then
                pcall(ns.UnitFrameSample, f, d)
            end
        end
        Note("Screenshot mode: take your picture. /fgui showcase again ends it.")
    else
        ns.showcasing = nil
        Clear()
        if ns.previewing then ns:TogglePreview(true) end
        if ns.RefreshUnitFrames and not InCombatLockdown() then ns:RefreshUnitFrames() end
        Note("Screenshot mode ended.")
    end
end

-- a fight ends it, before the game locks the frames
do
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:SetScript("OnEvent", ns:Guard("Screenshot mode", function()
        if not ns.showcasing then return end
        ns.showcasing = nil
        Clear()
        if ns.previewing then ns:TogglePreview(true) end
    end))
end
