local _, ns = ...

-- Profiles: create, switch, delete, export to a text string, import from one.
-- The export format is our own and is PARSED, never executed, so a pasted string can't run code.

local function DeepCopy(v, depth)
    depth = depth or 0
    if type(v) ~= "table" or depth > 20 then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = DeepCopy(x, depth + 1) end
    return t
end

-- Encoding: T / F booleans, N<number>; numbers, S<length>:<text> strings, { key value ... } tables
local function Encode(v, out, depth)
    local tv = type(v)
    if tv == "boolean" then
        out[#out + 1] = v and "T" or "F"
    elseif tv == "number" then
        out[#out + 1] = "N" .. format("%.10g", v) .. ";"
    elseif tv == "string" then
        out[#out + 1] = "S" .. #v .. ":" .. v
    elseif tv == "table" and depth < 20 then
        out[#out + 1] = "{"
        local keys = {}
        for k in pairs(v) do
            if type(k) == "string" or type(k) == "number" then keys[#keys + 1] = k end
        end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do
            local x = v[k]
            local tx = type(x)
            if tx == "boolean" or tx == "number" or tx == "string" or tx == "table" then
                Encode(k, out, depth + 1)
                Encode(x, out, depth + 1)
            end
        end
        out[#out + 1] = "}"
    end
end

local function Decode(s, i, depth)
    if depth > 20 then error("too deep") end
    local c = s:sub(i, i)
    if c == "T" then return true, i + 1 end
    if c == "F" then return false, i + 1 end
    if c == "N" then
        local j = s:find(";", i, true)
        local n = j and tonumber(s:sub(i + 1, j - 1))
        if not n then error("bad number") end
        return n, j + 1
    end
    if c == "S" then
        local j = s:find(":", i, true)
        local len = j and tonumber(s:sub(i + 1, j - 1))
        if not len or len < 0 or len > 4096 then error("bad text") end
        local str = s:sub(j + 1, j + len)
        if #str ~= len then error("text cut short") end
        return str, j + len + 1
    end
    if c == "{" then
        local t = {}
        i = i + 1
        while s:sub(i, i) ~= "}" do
            if i > #s then error("unfinished") end
            local k, v
            k, i = Decode(s, i, depth + 1)
            v, i = Decode(s, i, depth + 1)
            if type(k) ~= "string" and type(k) ~= "number" then error("bad key") end
            t[k] = v
        end
        return t, i + 1
    end
    error("unexpected character")
end

-- Exported for the plan code (PlannerCode.lua): the same encoding, a string in and out.
function ns.ShareEncode(value)
    local out = {}
    Encode(value, out, 0)
    return table.concat(out)
end
-- value, the index after it; nil when the text is not a well-formed value (never raises).
function ns.ShareDecode(text, start)
    if type(text) ~= "string" then return nil end
    local ok, value, stop = pcall(Decode, text, start or 1, 0)
    if ok then return value, stop end
    return nil
end

local HEADER = "SUI1!"
ns.DeepCopy = function(v) return DeepCopy(v) end
ns.PACK_HEADER = "FGP1!"

function ns:ProfileList()
    local names = {}
    for name in pairs(ns.root.profiles) do names[#names + 1] = name end
    table.sort(names)
    return names
end

local function CleanName(name)
    if type(name) ~= "string" then return nil end
    name = strtrim(name)
    if name == "" or #name > 32 then return nil end
    return name
end

-- Create a profile as a copy of the current one (or of `source`). Returns ok, message.
function ns:NewProfile(name, source)
    name = CleanName(name)
    if not name then return false, "Give the profile a name (up to 32 characters)." end
    if ns.root.profiles[name] then return false, format(ns:Tr("A profile called \"%s\" already exists."), name) end
    ns.root.profiles[name] = DeepCopy(source or ns.db)
    return true, format(ns:Tr("Profile \"%s\" created."), name)
end

-- Switch this character to another profile. It takes over at the reload, which the Use button does
-- itself (ns:ReloadButton: the game refuses a reload called from add-on code).
function ns:UseProfile(name)
    if type(ns.root.profiles[name]) ~= "table" then return false, "No such profile." end
    ns.root.chars[ns:CharKey()] = name
    return true
end

function ns:DeleteProfile(name)
    if name == ns.profile then return false, "You can't delete the profile you are using." end
    if name == "Default" then return false, "The Default profile can't be deleted." end
    if not ns.root.profiles[name] then return false, "No such profile." end
    ns.root.profiles[name] = nil
    for char, used in pairs(ns.root.chars) do
        if used == name then ns.root.chars[char] = "Default" end
    end
    return true, format(ns:Tr("Profile \"%s\" deleted."), name)
end

-- (13.5) Settings that are only ever the player's own choice: a profile, pack or line from someone else never
-- carries them, and what is taken in keeps the receiving player's own values (both are opt-in switches).
ns.NOT_SHARED = { crashReports = true, plannerLearnTimes = true }
local function NotShared(k) return type(ns.NOT_SHARED) == "table" and ns.NOT_SHARED[k] == true end
ns.NotShared = NotShared
-- A profile as it is shared: the same table less the keys that are never shared (a shallow copy only when needed).
local function Shareable(db)
    if type(db) ~= "table" then return db end
    local any
    for k in pairs(ns.NOT_SHARED or {}) do if db[k] ~= nil then any = true end end
    if not any then return db end
    local out = {}
    for k, v in pairs(db) do if not NotShared(k) then out[k] = v end end
    return out
end
-- Into a profile made from someone else's: the receiving player's own values of the keys never shared.
local function KeepOwn(clean)
    for k in pairs(ns.NOT_SHARED or {}) do
        clean[k] = nil
        local mine
        if type(ns.db) == "table" then mine = ns.db[k] end
        if ns.defaults[k] ~= nil and type(mine) == type(ns.defaults[k]) then clean[k] = mine end
    end
    return clean
end

function ns:ExportProfile()
    local out = {}
    Encode(Shareable(ns.db), out, 0)
    return HEADER .. table.concat(out)
end

function ns:ImportProfile(name, text)
    name = CleanName(name)
    if not name then return false, "Give the imported profile a name." end
    if ns.root.profiles[name] then return false, format(ns:Tr("A profile called \"%s\" already exists."), name) end
    if type(text) ~= "string" then return false, "Nothing to import." end
    text = strtrim(text)
    if text:sub(1, #HEADER) ~= HEADER then return false, "That isn't a Fantasy Glass UI profile string." end
    local ok, data, stop = pcall(Decode, text, #HEADER + 1, 0)
    if not ok or type(data) ~= "table" or stop ~= #text + 1 then
        return false, "The profile string is damaged or incomplete."
    end
    -- keep only settings this version knows, with the type it expects
    local clean = {}
    for k, default in pairs(ns.defaults) do
        if type(data[k]) == type(default) and not NotShared(k) then clean[k] = data[k] end
    end
    KeepOwn(clean)
    if type(data.role) == "string" then clean.role = data.role end
    clean.pos, clean.scale = {}, {}
    if type(data.pos) == "table" then
        for k, p in pairs(data.pos) do
            if type(k) == "string" and type(p) == "table" and type(p[1]) == "string" and type(p[2]) == "string"
               and type(p[3]) == "number" and type(p[4]) == "number" then
                clean.pos[k] = { p[1], p[2], p[3], p[4] }
            end
        end
    end
    if type(data.scale) == "table" then
        for k, v in pairs(data.scale) do
            if type(k) == "string" and type(v) == "number" then clean.scale[k] = math.max(0.5, math.min(2, v)) end
        end
    end
    clean.classColors = {}
    if type(data.classColors) == "table" then
        for class, c in pairs(data.classColors) do
            if type(class) == "string" and type(c) == "table" and type(c[1]) == "number" and type(c[2]) == "number" and type(c[3]) == "number" then
                clean.classColors[class] = { math.max(0, math.min(1, c[1])), math.max(0, math.min(1, c[2])), math.max(0, math.min(1, c[3])) }
            end
        end
    end
    ns.root.profiles[name] = clean
    return true, format(ns:Tr("Profile \"%s\" imported. Click Use to switch to it."), name)
end

------------------------------------------------------------------------------------------
-- Layouts: where panels sit, how big they are, and the frame sizes - nothing else.
-- A layout can be shared as a text string (parsed, never executed, like profiles), and each
-- talent set can keep its own layout that is swapped in automatically.
------------------------------------------------------------------------------------------
local LAYOUT_HEADER = "SUIL1!"
local SIZE_KEYS = { "ufW", "ufH", "partyW", "partyH", "raidW", "raidH" }

function ns:LayoutSnapshot()
    local sizes = {}
    for _, k in ipairs(SIZE_KEYS) do sizes[k] = ns.db[k] end
    return { pos = DeepCopy(ns.db.pos), scale = DeepCopy(ns.db.scale), size = sizes }
end

-- Keep only what a layout may contain, with the types and ranges we expect.
local function CleanLayout(data)
    if type(data) ~= "table" then return nil end
    local clean = { pos = {}, scale = {}, size = {} }
    if type(data.pos) == "table" then
        for k, p in pairs(data.pos) do
            if type(k) == "string" and #k < 40 and type(p) == "table" and type(p[1]) == "string" and type(p[2]) == "string"
               and type(p[3]) == "number" and type(p[4]) == "number" then
                clean.pos[k] = { p[1], p[2], p[3], p[4] }
            end
        end
    end
    if type(data.scale) == "table" then
        for k, v in pairs(data.scale) do
            if type(k) == "string" and #k < 40 and type(v) == "number" then clean.scale[k] = math.max(0.5, math.min(2, v)) end
        end
    end
    if type(data.size) == "table" then
        for _, k in ipairs(SIZE_KEYS) do
            if type(data.size[k]) == "number" then clean.size[k] = math.max(20, math.min(400, data.size[k])) end
        end
    end
    return clean
end

local pendingLayout
-- Put a layout in place. In combat it is saved and applied when the fight ends.
function ns:ApplyLayout(layout)
    layout = CleanLayout(layout)
    if not layout then return false end
    ns.db.pos, ns.db.scale = layout.pos, layout.scale
    for k, v in pairs(layout.size) do ns.db[k] = v end
    if InCombatLockdown() then
        pendingLayout = true
        return true, true
    end
    pendingLayout = nil
    for _, m in ipairs(ns.movables or {}) do
        local p = layout.pos[m.key]
        if p then
            pcall(function()
                m.frame:ClearAllPoints()
                m.frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
            end)
        end
        pcall(m.frame.SetScale, m.frame, layout.scale[m.key] or 1)
    end
    if ns.ResizeUnitFrames then pcall(ns.ResizeUnitFrames, ns) end
    if ns.ResizeRaid then pcall(ns.ResizeRaid, ns) end
    return true, false
end

function ns:ExportLayout()
    local out = {}
    Encode(ns:LayoutSnapshot(), out, 0)
    return LAYOUT_HEADER .. table.concat(out)
end

function ns:ImportLayout(text)
    if type(text) ~= "string" then return false, "Nothing to import." end
    text = strtrim(text)
    if text:sub(1, #HEADER) == HEADER then return false, "That is a whole profile, not a layout. Import it in Layout and profiles › Profiles." end
    if text:sub(1, #LAYOUT_HEADER) ~= LAYOUT_HEADER then return false, "That isn't a Fantasy Glass UI layout string." end
    local ok, data, stop = pcall(Decode, text, #LAYOUT_HEADER + 1, 0)
    if not ok or type(data) ~= "table" or stop ~= #text + 1 then return false, "The layout string is damaged or incomplete." end
    local _, later = ns:ApplyLayout(data)
    return true, later and "Layout saved. It moves into place when you leave combat." or "Layout applied."
end

-- Layouts that switch by themselves ---------------------------------------------------------------
-- Two independent options: a layout per talent set, and a layout per group size (alone, in a party,
-- in a raid). Whatever is switched on makes up the "context"; each context remembers its own layout,
-- and when the context changes the old layout is saved and the new one put in place.
function ns:TalentSet()
    for _, probe in ipairs({ { "C_SpecializationInfo.GetActiveSpecGroup", C_SpecializationInfo.GetActiveSpecGroup } }) do
        if type(probe[2]) == "function" then
            local ok, n = pcall(probe[2])
            if ok and type(n) == "number" and n >= 1 and n < 20 then return n, probe[1] end
        end
    end
    return 1, "none"
end

function ns:GroupKind()
    if IsInRaid and IsInRaid() then return "raid" end
    if IsInGroup and IsInGroup() then return "party" end
    return "solo"
end

-- nil when neither option is on. (A talent-set-only context is just the set's number, as before.)
function ns:LayoutContext()
    if not ns.db then return nil end
    local parts = {}
    if ns.db.specLayouts then parts[#parts + 1] = tostring((ns:TalentSet())) end
    if ns.db.groupLayouts then parts[#parts + 1] = ns:GroupKind() end
    if ns.db.screenLayouts then parts[#parts + 1] = ns.ScreenKey() end
    if #parts == 0 then return nil end
    return table.concat(parts, "/")
end

-- (11.5) the screen's size, as part of a layout's context: "2560x1440"
function ns.ScreenKey(w, h)
    if not w and type(GetPhysicalScreenSize) == "function" then
        local ok, pw, ph = pcall(GetPhysicalScreenSize)
        if ok then w, h = pw, ph end
    end
    w, h = tonumber(w), tonumber(h)
    if not w or not h or w <= 0 then return "screen" end
    return format("%dx%d", w, h)
end
local function Describe(ctx)
    local words = {}
    for part in tostring(ctx):gmatch("[^/]+") do
        if part:match("^%d+$") then words[#words + 1] = format(ns:Tr("talent set %s"), part)
        elseif part:match("^%d+x%d+$") then words[#words + 1] = format(ns:Tr("a %s screen"), part)
        elseif part == "screen" then words[#words + 1] = ns:Tr("this screen")          -- (the game would not say its size)
        elseif part == "raid" or part == "party" or part == "solo" then
            words[#words + 1] = ns:Tr(part == "raid" and "in a raid" or part == "party" and "in a party" or "on your own")
        end
    end
    return table.concat(words, ", ")
end
ns.DescribeLayoutContext = Describe

local function CheckLayoutContext()
    if not ns.db then return end
    local now = ns:LayoutContext()
    local before = ns.db.layoutCtx
    ns.db.layoutCtx = now
    ns.db.layoutSet = ns:TalentSet()
    if now == nil or before == nil or before == now then return end
    ns.db.layouts[before] = ns:LayoutSnapshot()                    -- remember the one we are leaving
    local saved = ns.db.layouts[now]
    if saved then
        local _, later = ns:ApplyLayout(saved)
        ns:Print(later and "Layout for %s moves into place when you leave combat." or "Layout for %s loaded.", Describe(now))
    else
        ns:Print("No layout saved yet for %s. Arrange your panels and it will be remembered.", Describe(now))
    end
end
ns.CheckLayoutContext = CheckLayoutContext

-- Share one of your own themes as text (parsed, never executed, like profiles and layouts).
local THEME_HEADER = "SUIT1!"
function ns:ExportTheme()
    local t = ns.themes[ns.db.theme]
    local def
    if t and t.custom then
        def = ns.db.customThemes[t.customName]
    else                                                          -- a built-in theme: share what is on screen
        local ar, ag, ab = ns:AccentColor(ns.db.accent or "AZURE")
        local th = ns.theme
        def = { panel = { th.bg[1], th.bg[2], th.bg[3] }, rim = { th.border[1], th.border[2], th.border[3] }, accent = { ar, ag, ab }, style = ns.style }
    end
    local name = (t and t.custom and t.customName ~= "*") and t.customName or (t and t.name:gsub("^%a+: ", ""):gsub(" %(.-%)$", "")) or "Theme"
    local out = {}
    Encode({ name = name, panel = def.panel, rim = def.rim, accent = def.accent, style = def.style }, out, 0)
    return THEME_HEADER .. table.concat(out)
end
function ns:ImportTheme(text)
    if type(text) ~= "string" then return false, "Nothing to import." end
    text = strtrim(text)
    if text:sub(1, #THEME_HEADER) ~= THEME_HEADER then return false, "That isn't a Fantasy Glass UI theme string." end
    local ok, data, stop = pcall(Decode, text, #THEME_HEADER + 1, 0)
    if not ok or type(data) ~= "table" or stop ~= #text + 1 then return false, "The theme string is damaged or incomplete." end
    local name = type(data.name) == "string" and strtrim(data.name):gsub("[|:%c]", ""):sub(1, 24) or ""
    if name == "" or name == "*" then name = "Imported" end
    local base, n = name, 1
    while ns.db.customThemes[name] do n = n + 1; name = (base:sub(1, 21) .. " " .. n) end      -- never overwrite one of yours
    ns.db.theme = ns:SaveCustomTheme(name, data)                  -- (colors and style are cleaned as they are saved)
    ns.db.accent = "CUSTOM"
    return true, name
end

-- What a shared string holds, read but not taken (for the preview): kind, data  or  nil, why.
function ns:DecodeShared(text)
    if type(text) ~= "string" then return nil, "Nothing to import." end
    text = strtrim(text)
    for _, h in ipairs({ { HEADER, "profile" }, { LAYOUT_HEADER, "layout" }, { THEME_HEADER, "theme" }, { ns.PACK_HEADER, "pack" } }) do
        if text:sub(1, #h[1]) == h[1] then
            local ok, data, stop = pcall(Decode, text, #h[1] + 1, 0)
            if not ok or type(data) ~= "table" or stop ~= #text + 1 then return nil, "The string is damaged or incomplete." end
            return h[2], data
        end
    end
    return nil, "That isn't a Fantasy Glass UI string."
end

do
    local f = CreateFrame("Frame")
    for _, e in ipairs({ "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_LOGOUT", "DISPLAY_SIZE_CHANGED" }) do
        pcall(f.RegisterEvent, f, e)
    end
    f:SetScript("OnEvent", ns:Guard("Profiles events", function(_, event)
        if not ns.db then return end
        if event == "PLAYER_REGEN_ENABLED" then
            if pendingLayout then pcall(ns.ApplyLayout, ns, ns:LayoutSnapshot()) end
        elseif event == "PLAYER_LOGOUT" then
            if ns.db.layoutCtx then ns.db.layouts[ns.db.layoutCtx] = ns:LayoutSnapshot() end
        else
            pcall(CheckLayoutContext)
        end
    end))
end

------------------------------------------------------------------------------------------
-- Whole-UI packs (11.7): one string with everything a setup is: the profile (look, switches,
-- panels, bars, frame designs, bag rules, your own themes), your mail rules and who gets what, and
-- the game's own Edit Mode layout for its bars, where this client can write one out. A guild or a
-- streamer can share "the UI" in one paste. Parsed, never run, like the other strings.
------------------------------------------------------------------------------------------
local function EditModeString()
    local E = C_EditMode
    if not (type(E) == "table" and E.GetLayouts and E.ConvertLayoutInfoToString) then return nil end
    local ok, info = pcall(E.GetLayouts)
    if not ok or type(info) ~= "table" or type(info.layouts) ~= "table" then return nil end
    local idx = tonumber(info.activeLayout)
    for _, i in ipairs({ idx and (idx - 2), idx }) do
        local layout = i and info.layouts[i]
        if type(layout) == "table" then
            local okS, s = pcall(E.ConvertLayoutInfoToString, layout)
            if okS and type(s) == "string" and #s > 0 and #s <= 4000 then return s end
        end
    end
    return nil
end
function ns:ExportPack()
    local data = { v = 1, profile = Shareable(ns.db), from = UnitName("player") }
    if type(ns.root.mailRules) == "table" then data.mailRules = ns.root.mailRules end
    if type(ns.root.mailTo) == "table" then data.mailTo = ns.root.mailTo end
    data.editMode = EditModeString()
    local out = {}
    Encode(data, out, 0)
    return ns.PACK_HEADER .. table.concat(out)
end
-- A pack's profile, kept to what this version knows: every setting with the type it expects, and
-- the add-on's own tables (positions, sizes, designs, rules) as plain tables.
function ns.CleanPackProfile(p)
    local clean = {}
    if type(p) ~= "table" then return clean end
    for k, default in pairs(ns.defaults) do
        if type(p[k]) == type(default) and not NotShared(k) then clean[k] = DeepCopy(p[k]) end
    end
    KeepOwn(clean)
    for k, v in pairs(p) do
        if type(k) == "string" and clean[k] == nil and ns.defaults[k] == nil and not NotShared(k) and (type(v) == "table" or type(v) == "string" or type(v) == "number" or type(v) == "boolean") then
            clean[k] = DeepCopy(v)
        end
    end
    if type(clean.pos) == "table" then
        for k, at in pairs(clean.pos) do
            if not (type(k) == "string" and type(at) == "table" and type(at[1]) == "string" and type(at[2]) == "string" and type(at[3]) == "number" and type(at[4]) == "number") then
                clean.pos[k] = nil
            end
        end
    else clean.pos = {} end
    if type(clean.scale) == "table" then
        for k, v in pairs(clean.scale) do
            if type(v) ~= "number" then clean.scale[k] = nil else clean.scale[k] = math.max(0.5, math.min(2, v)) end
        end
    else clean.scale = {} end
    return clean
end
function ns:ImportPack(name, text, withMail)
    name = CleanName(name)
    if not name then return false, "Give the pack's profile a name." end
    if ns.root.profiles[name] then return false, format(ns:Tr("A profile called \"%s\" already exists."), name) end
    local kind, data = ns:DecodeShared(text)
    if kind ~= "pack" then return false, "That isn't a Fantasy Glass UI pack." end
    ns.root.profiles[name] = ns.CleanPackProfile(data.profile)
    if withMail ~= false and type(data.mailRules) == "table" then ns.root.mailRules = DeepCopy(data.mailRules) end
    if withMail ~= false and type(data.mailTo) == "table" then ns.root.mailTo = DeepCopy(data.mailTo) end
    ns.packEditMode = type(data.editMode) == "string" and data.editMode or nil
    return true, format(ns:Tr("Pack saved as the profile \"%s\". Click Use to switch to it."), name), ns.packEditMode
end
