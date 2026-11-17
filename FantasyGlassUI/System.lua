local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end
local function GetVar(name)
    local Get = (C_CVar and C_CVar.GetCVar) or GetCVar
    if type(Get) ~= "function" then return nil end
    local ok, v = pcall(Get, name)
    return (ok and v ~= nil and not Secret(v)) and tostring(v) or nil
end
local function SetVar(name, value)
    local Set = (C_CVar and C_CVar.SetCVar) or SetCVar
    if type(Set) == "function" then pcall(Set, name, value) end
end

------------------------------------------------------------------------------------------
-- Fonts and bar textures from other add-ons, through LibSharedMedia (if any add-on brought it).
--   /fgui media                  what there is to choose from
--   /fgui font Expressway        use that font          /fgui font off          back to ours
--   /fgui bartexture Minimalist  use that bar texture   /fgui bartexture off
-- Our own bar textures are offered to other add-ons the same way.
------------------------------------------------------------------------------------------
local function Library()
    local stub = _G.LibStub
    if type(stub) ~= "table" and type(stub) ~= "function" then return nil end
    local ok, lib = pcall(stub, "LibSharedMedia-3.0", true)
    return (ok and type(lib) == "table" and type(lib.Fetch) == "function") and lib or nil
end
ns.SharedMedia = Library
-- Called by the look code after it has chosen our own font and bar texture.
function ns:ApplySharedMedia()
    local lib = Library()
    if not lib or not ns.db then return false end
    local used = false
    if type(ns.db.sharedFont) == "string" then
        local ok, path = pcall(lib.Fetch, lib, "font", ns.db.sharedFont, true)
        if ok and type(path) == "string" then ns.FONT, ns.TITLEFONT, ns.FONTFLAGS = path, path, ""; used = true end
    end
    if type(ns.db.sharedBar) == "string" then
        local ok, path = pcall(lib.Fetch, lib, "statusbar", ns.db.sharedBar, true)
        if ok and type(path) == "string" then ns.BAR = path; used = true end
    end
    return used
end
function ns:MediaCommand(kind, text)
    local lib = Library()
    if not lib then ns:Print("No add-on here has brought LibSharedMedia, so there are only our own fonts and textures (Look tab)."); return false end
    local key = (kind == "font") and "sharedFont" or "sharedBar"
    local media = (kind == "font") and "font" or "statusbar"
    text = ns.Trim(text)
    if kind == "list" or text == "" then
        for _, m in ipairs({ "font", "statusbar" }) do
            local ok, names = pcall(lib.List, lib, m)
            ns:PrintRaw("|cff33ccffFantasy Glass UI|r: " .. ns:Tr(m == "font" and "Fonts" or "Bar textures") .. ": " .. ((ok and type(names) == "table") and table.concat(names, ", ") or "-"))
        end
        return true
    end
    if text:lower() == "off" then
        ns.db[key] = nil
        ns:Print("Back to our own. Type /reload to see it everywhere.")
    else
        local found
        local ok, names = pcall(lib.List, lib, media)
        for _, name in ipairs((ok and type(names) == "table") and names or {}) do if tostring(name):lower() == text:lower() then found = name end end
        if not found then ns:Print("Nothing called \"%s\" here. /fgui media lists what there is.", text); return false end
        ns.db[key] = found
        ns:Print("Using \"%s\". Type /reload to see it everywhere.", found)
    end
    if ns.Retheme then pcall(ns.Retheme, ns) end
    return true
end
do
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_LOGIN")
    ev:SetScript("OnEvent", ns:Guard("Shared media", function()
        local lib = Library()
        if not lib or type(lib.Register) ~= "function" or not ns.MEDIA then return end
        pcall(lib.Register, lib, "statusbar", "Fantasy Glass", ns.MEDIA .. "bar_glass.tga")
        pcall(lib.Register, lib, "statusbar", "Fantasy Glass (plain)", ns.MEDIA .. "bar.tga")
    end))
end

------------------------------------------------------------------------------------------
-- Mute sounds: sounds you never want to hear again, by the game's number for the sound file
-- (the number is on the sound's page on Wowhead).   /fgui mute 567458     /fgui mute list
------------------------------------------------------------------------------------------
function ns:MuteCommand(text)
    if type(MuteSoundFile) ~= "function" then ns:Print("This game client does not let add-ons mute a sound."); return false end
    local list = ns:SavedList("mutedSounds", true)   -- luacheck: ignore
    text = ns.Trim(text)
    local id = text:match("(%d+)%s*$")
    if text ~= "" and text:lower() ~= "list" and not id then ns:Print("Give the sound file's number: /fgui mute 567458."); return false end
    local words = id and text:gsub("%d+%s*$", id) or text
    local did, name = ns:ListCommand("mutedSounds", words, "Muted sounds", true)
    if did == "added" then pcall(MuteSoundFile, tonumber(name))
    elseif did == "removed" and UnmuteSoundFile then pcall(UnmuteSoundFile, tonumber(name)) end
    return did
end
do
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_LOGIN")
    ev:SetScript("OnEvent", ns:Guard("Muted sounds", function()
        if type(MuteSoundFile) ~= "function" or type(ns.root) ~= "table" then return end
        for _, id in ipairs(type(ns.root.mutedSounds) == "table" and ns.root.mutedSounds or {}) do
            if tonumber(id) then pcall(MuteSoundFile, tonumber(id)) end
        end
    end))
end

------------------------------------------------------------------------------------------
-- Raid graphics: the costly settings are turned down while you are inside a raid and put back
-- when you leave.
------------------------------------------------------------------------------------------
ns.RAID_GRAPHICS = { graphicsShadowQuality = "0", graphicsLiquidDetail = "0", graphicsSSAO = "0", graphicsDepthEffects = "0",
                     graphicsParticleDensity = "1", graphicsSpellDensity = "1", graphicsProjectedTextures = "0" }
-- What to change: every setting whose value is above the raid value. Returns { cvar = raidValue }.
function ns.RaidGraphicsPlan(now, wanted)
    local plan = {}
    for cvar, value in pairs(wanted) do
        local have = tonumber(now[cvar])
        if have and have > tonumber(value) then plan[cvar] = value end
    end
    return plan
end
ns:NewModule("raidGraphics", function()
    if type(ns.root) ~= "table" then return end
    local function Check()
        if InCombatLockdown() then return nil end
        local inside, kind = false, nil
        if IsInInstance then local ok, a, b = pcall(IsInInstance); if ok then inside, kind = ns.Is(a, true), b end end
        local raid = inside and kind == "raid"
        local before = ns.root.raidGraphicsBefore
        if raid and not before then
            local now = {}
            for cvar in pairs(ns.RAID_GRAPHICS) do now[cvar] = GetVar(cvar) end
            local plan = ns.RaidGraphicsPlan(now, ns.RAID_GRAPHICS)
            before = {}
            for cvar, value in pairs(plan) do before[cvar] = now[cvar]; SetVar(cvar, value) end
            ns.root.raidGraphicsBefore = before
            if next(before) then ns:Print("Raid graphics: some settings are turned down until you leave.") end
        elseif not raid and before then
            for cvar, value in pairs(before) do SetVar(cvar, value) end
            ns.root.raidGraphicsBefore = nil
            if next(before) then ns:Print("Raid graphics: your settings are back.") end
        end
        ns.raidGraphicsState = raid and "on, turned down now" or "on"
        return raid
    end
    ns.raidGraphicsTest = { Check = Check }
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("System events", function() ns:After(2, function() pcall(Check) end) end))
end)

------------------------------------------------------------------------------------------
-- Add-on memory: /fgui addons lists every running add-on by the memory it uses.
------------------------------------------------------------------------------------------
-- addons: { { name, kb } ... } -> sorted, with the total.
function ns.AddonLines(addons)
    local total = 0
    table.sort(addons, function(a, b) if a.kb ~= b.kb then return a.kb > b.kb end return a.name < b.name end)
    for _, a in ipairs(addons) do total = total + a.kb end
    return addons, total
end
function ns.Memory(kb)
    if kb >= 1024 then return format("%.1f MB", kb / 1024) end
    return format("%.0f KB", kb)
end
function ns:ShowAddons()
    if type(UpdateAddOnMemoryUsage) ~= "function" or type(GetAddOnMemoryUsage) ~= "function" then ns:Print("This game client does not report add-on memory."); return end
    pcall(UpdateAddOnMemoryUsage)
    local A = C_AddOns or {}
    local Num, Info, Loaded = A.GetNumAddOns or GetNumAddOns, A.GetAddOnInfo or GetAddOnInfo, A.IsAddOnLoaded or IsAddOnLoaded
    local list = {}
    for i = 1, (type(Num) == "function" and tonumber(Num())) or 0 do
        local name, title = Info(i)
        if type(name) == "string" and ns.Yes(Loaded(i)) then
            local ok, kb = pcall(GetAddOnMemoryUsage, i)
            list[#list + 1] = { name = (type(title) == "string" and title ~= "") and title or name, kb = (ok and tonumber(kb)) or 0 }
        end
    end
    local sorted, total = ns.AddonLines(list)
    local most = (sorted[1] and sorted[1].kb > 0) and sorted[1].kb or 1
    local lines = { { left = ns:Tr("Total"), right = ns.Memory(total), color = { 1, 0.82, 0.3 } } }
    for _, a in ipairs(sorted) do lines[#lines + 1] = { left = a.name, right = ns.Memory(a.kb), bar = a.kb / most } end
    return ns:ShowList("Addons", "Add-on memory", lines, "The add-ons running now, by the memory each uses.", 420, 380)
end

------------------------------------------------------------------------------------------
-- The talking head (the box with a face that speaks during quests): hide it, or move it.
------------------------------------------------------------------------------------------
ns:NewModule("talkingHeadHide", function()
    local function Hook()
        local head = _G.TalkingHeadFrame
        if type(head) ~= "table" or head.suiHidden or not head.HookScript then return false end
        head.suiHidden = true
        pcall(head.HookScript, head, "OnShow", function(self) if not ns:Locked(self) then pcall(self.Hide, self) end end)
        ns.talkingHeadState = "hidden when it appears"
        return true
    end
    ns.talkingHeadState = "waiting for the game to load it"
    if not Hook() then
        local ev = CreateFrame("Frame")
        ev:RegisterEvent("ADDON_LOADED")
        ev:SetScript("OnEvent", ns:Guard("System events", function() Hook() end))
    end
end)
ns:NewModule("talkingHeadMove", function()
    local function Adopt()
        local head = _G.TalkingHeadFrame
        if type(head) ~= "table" or not ns.AdoptGameFrame then return false end
        return ns:AdoptGameFrame(head, "talkingHead", "Talking Head") and true or false
    end
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_LOGIN", "ADDON_LOADED" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Talking head", function() if not InCombatLockdown() then Adopt() end end))
end)
