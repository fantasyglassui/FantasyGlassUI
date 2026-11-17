local _, ns = ...

------------------------------------------------------------------------------------------
-- New characters (11.6): the first time a character logs in, it gets its own profile copied from
-- your main's setup (layout, bars, theme, switches) and fitted to it: a role this class can play
-- (your main's if it can, else damage), that role's frame layout if the role changed, and the
-- switches suggested for its class turned on. Your main is the character you choose with
-- /fgui main, or else the one you played last. Switched off (Profiles tab), new characters share
-- the Default profile as before. A first install with no character set up yet still gets the setup.
------------------------------------------------------------------------------------------
ns.CLASS_ROLES = {
    WARRIOR = { TANK = true, DAMAGE = true }, PALADIN = { TANK = true, HEALER = true, DAMAGE = true },
    HUNTER = { DAMAGE = true }, ROGUE = { DAMAGE = true }, PRIEST = { HEALER = true, DAMAGE = true },
    SHAMAN = { HEALER = true, DAMAGE = true }, MAGE = { DAMAGE = true }, WARLOCK = { DAMAGE = true },
    DRUID = { TANK = true, HEALER = true, DAMAGE = true }, DEATHKNIGHT = { TANK = true, DAMAGE = true },
    MONK = { TANK = true, HEALER = true, DAMAGE = true }, DEMONHUNTER = { TANK = true, DAMAGE = true },
    EVOKER = { HEALER = true, DAMAGE = true },
}
-- A few switches that suit each class (the Tools tab's "Suggestions for your class" uses these too).
ns.classSuggestions = {
    WARRIOR = { "executeLine", "swingTimer", "aggroWarn", "cooldownPulse" },
    PALADIN = { "buffMissing", "classBar", "executeLine", "cooldownPulse" },
    HUNTER = { "swingTimer", "focusCastAlert", "classBar", "cooldownPulse" },
    ROGUE = { "imbueReminder", "classBar", "focusCastAlert", "swingTimer" },
    PRIEST = { "buffMissing", "raidFrames", "focusCastAlert", "cooldownPulse" },
    SHAMAN = { "buffMissing", "totems", "imbueReminder", "travelBar" },
    MAGE = { "travelBar", "focusCastAlert", "cooldownPulse", "buffMissing" },
    WARLOCK = { "classBar", "buffMissing", "executeLine", "focusCastAlert" },
    DRUID = { "classBar", "travelBar", "buffMissing", "raidFrames" },
    DEATHKNIGHT = { "classBar", "travelBar", "executeLine", "cooldownPulse" },
    MONK = { "classBar", "travelBar", "focusCastAlert", "cooldownPulse" },
    DEMONHUNTER = { "focusCastAlert", "cooldownPulse", "executeLine", "classBar" },
    EVOKER = { "classBar", "focusCastAlert", "cooldownPulse", "raidFrames" },
}

-- The role a class takes from your main: the same one if it can play it, else damage.
function ns.AltRole(mainRole, class)
    local can = ns.CLASS_ROLES[class]
    if not can then return mainRole or "DAMAGE" end
    if mainRole and can[mainRole] then return mainRole end
    return "DAMAGE"
end

local function Copy(t, seen)
    if type(t) ~= "table" then return t end
    seen = seen or {}
    if seen[t] then return seen[t] end
    local out = {}
    seen[t] = out
    for k, v in pairs(t) do out[Copy(k, seen)] = Copy(v, seen) end
    return out
end

-- Fit a copied profile to another class. Returns what changed: { role, switched = { keys } }.
function ns.FitProfile(db, fromClass, toClass)
    local was = db.role
    db.role = ns.AltRole(was, toClass)
    local changed = { role = db.role, roleChanged = (db.role ~= was), switched = {} }
    if changed.roleChanged and ns.layouts[db.role] then
        db.pos = type(db.pos) == "table" and db.pos or {}
        for key, p in pairs(ns.layouts[db.role]) do db.pos[key] = { p[1], p[1], p[2], p[3] } end
    end
    if fromClass ~= toClass then
        for _, key in ipairs(ns.classSuggestions[toClass] or {}) do
            if db[key] == false then db[key] = true; changed.switched[#changed.switched + 1] = key end
        end
        db.kickOrder = nil                                       -- (your main's group, not this one's)
    end
    return changed
end

-- Whose setup a new character copies: your main, else the character played last. nil when none.
function ns.AltSource(root, me)
    local info = type(root.charInfo) == "table" and root.charInfo or {}
    local function Usable(char)
        if not char or char == me then return false end
        local p = root.chars and root.chars[char]
        return type(p) == "string" and type(root.profiles[p]) == "table" and root.profiles[p].role ~= nil
    end
    if Usable(root.mainChar) then return root.mainChar end
    local best, bestT
    for char, i in pairs(info) do
        if Usable(char) and type(i) == "table" and (not bestT or (tonumber(i.last) or 0) > bestT) then best, bestT = char, tonumber(i.last) or 0 end
    end
    if best then return best end
    for char in pairs(root.chars or {}) do if Usable(char) then return char end end        -- (characters from before 11.6)
    return nil
end

-- Called while the saved settings are read, for a character never seen before. Returns the profile
-- name it now uses, or nil to share the Default profile as before.
function ns:NewCharacterProfile(root, key)
    if root.altCopy == false then return nil end
    local from = ns.AltSource(root, key)
    if not from then return nil end
    local _, class = UnitClass("player")
    local fromProfile = root.chars[from]
    local db = Copy(root.profiles[fromProfile])
    local fromClass = type(root.charInfo) == "table" and type(root.charInfo[from]) == "table" and root.charInfo[from].class or nil
    local changed = ns.FitProfile(db, fromClass, class)
    local name = key
    local n = 2
    while root.profiles[name] do name = key .. " " .. n; n = n + 1 end
    root.profiles[name] = db
    ns.altSetupNote = { from = from, profile = fromProfile, class = class, changed = changed }
    return name
end

-- Every login: what class each character is and when it was last played (for choosing whose
-- setup a new character copies).
function ns:NoteCharacter(root, key)
    root.charInfo = type(root.charInfo) == "table" and root.charInfo or {}
    local _, class = UnitClass("player")
    root.charInfo[key] = { class = class, last = time and time() or 0 }
end

function ns:MainCommand(text)
    local root = ns.root
    if not root then return end
    local arg = ns.Trim(text or ""):lower()
    if arg == "off" or arg == "none" then
        root.mainChar = nil
        ns:Print("No main chosen: new characters copy the character you played last.")
    elseif arg == "share" then
        root.altCopy = false
        ns:Print("New characters share the Default profile. |cffffff00/fgui main copy|r to give them their own again.")
    elseif arg == "copy" then
        root.altCopy = nil
        ns:Print("New characters get their own copy of your main's setup, fitted to their class.")
    else
        root.mainChar = ns:CharKey()
        ns:Print("%s is now your main: new characters copy its setup (|cffffff00/fgui main off|r to undo).", ns:CharKey())
    end
    return root.mainChar
end

do  -- say what was done, once the world is up
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        local note = ns.altSetupNote
        if not note then return end
        ns:After(5, function()
            local roleLabel = ns.roles[note.changed.role] and ns:Tr(ns.roles[note.changed.role].label) or tostring(note.changed.role)
            local className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[note.class]) or tostring(note.class)
            ns:Print("New character: its own setup, copied from %s and fitted to a %s (%s).", (note.from:gsub(" %- .*$", "")), className, roleLabel)
            if #note.changed.switched > 0 then
                local labels, names = {}, {}
                if ns.LoadOptions and ns:LoadOptions() then          -- (the switch names live with the options)
                    for _, group in ipairs(ns.featureGroups or {}) do
                        for _, opt in ipairs(group[2]) do names[opt[1]] = ns:Tr(opt[2]) end
                    end
                end
                for _, key in ipairs(note.changed.switched) do labels[#labels + 1] = names[key] or key end
                ns:Print("Switched on for this class: %s.", table.concat(labels, ", "))
            end
            ns:Print("|cffffff00/fgui setup|r goes through it yourself; the Profiles tab shares another profile instead.")
        end)
    end)
end
