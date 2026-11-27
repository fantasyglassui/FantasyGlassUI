local _, ns = ...

------------------------------------------------------------------------------------------
-- 13.5: the check after a game update. At login, when the game's build has changed since this version's first
-- login, every part whose needs (HealthNeeds.lua) have gone is left off (ns.healthOff: the module loop skips it,
-- ns:LoadFolder refuses it), until Fantasy Glass UI is updated. The saved settings are never changed.
--   * Each version takes a baseline at its first login: the build it saw (root.lastBuild) and the names absent
--     then (root.health.base.absent). Many Blizzard frames and templates come only with a load-on-demand add-on,
--     so a name counts as missing only when it was there at the baseline and is gone now.
--   * A new version trusts itself: a new baseline, nothing off, even when the build changed too.
--   * The result is kept (root.health.result) and applied quietly at every later login of the same build and
--     version; the line prints once. In a fight the check waits (the parts start as usual), and what it then
--     finds is off from the next login.
--   * The check is one pass, each name looked up once (ns.HEALTH_BUDGET_MS). /fgui health runs it on demand.
------------------------------------------------------------------------------------------
ns.HEALTH_BUDGET_MS = 4

-- Is this game name there? "t:<name>" a template, "A.B.C" a table's field, else a global. A hidden value is there.
function ns.HealthHas(name)
    if type(name) ~= "string" then return false end
    if name:sub(1, 2) == "t:" then
        local x = _G.C_XMLUtil
        if ns:IsSecret(x) then return true end
        local fn = type(x) == "table" and x.GetTemplateInfo or nil
        if ns:IsSecret(fn) or type(fn) ~= "function" then return true end       -- (it cannot tell: not missing)
        local ok, info = pcall(fn, name:sub(3))
        if not ok then return false end
        return ns:IsSecret(info) or info ~= nil
    end
    if name:find(".", 1, true) then
        local v = _G
        for step in name:gmatch("[^.]+") do
            if ns:IsSecret(v) then return true end
            if type(v) ~= "table" then return false end
            v = v[step]
        end
        return ns:IsSecret(v) or v ~= nil
    end
    local v = _G[name]
    return ns:IsSecret(v) or v ~= nil
end

-- Every needed name that is not there now: { [name] = true }. Each name asked once; a lookup that fails is not an absence.
function ns.HealthScan(has)
    has = has or ns.HealthHas
    local absent = {}
    local names = ns.HEALTH_NAMES or {}
    for i = 1, #names do
        local name = names[i]
        local ok, yes = pcall(has, name)
        if ok and not yes then absent[name] = true end
    end
    return absent
end

local function Label(key)
    local e = ns.HEALTH_NEEDS and ns.HEALTH_NEEDS[key]
    return type(e) == "table" and type(e.label) == "string" and e.label or tostring(key)
end
local function ByLabel(keys)
    table.sort(keys, function(a, b)
        local la, lb = Label(a), Label(b)
        if la ~= lb then return la < lb end
        return a < b
    end)
    return keys
end

-- What a scan means against a baseline: { off = { key, ... } (by label), missing = { [key] = { name, ... } },
-- core = { name, ... } }. A name is missing when it is absent now and was not absent in the baseline.
function ns.HealthJudge(absent, base)
    absent = type(absent) == "table" and absent or {}
    local before = type(base) == "table" and type(base.absent) == "table" and base.absent or {}
    local names = ns.HEALTH_NAMES or {}
    local result = { off = {}, missing = {}, core = {} }
    for key, e in pairs(ns.HEALTH_NEEDS or {}) do
        local gone = {}
        for _, i in ipairs(e) do
            local name = names[i]
            if name and absent[name] and not before[name] then gone[#gone + 1] = name end
        end
        if #gone > 0 then
            table.sort(gone)
            if key == "core" then
                result.core = gone
            else
                result.missing[key] = gone
                result.off[#result.off + 1] = key
            end
        end
    end
    ByLabel(result.off)
    return result
end

-- The game's build, as a string; nil when it cannot be read.
local function Build()
    local ok, _, build = pcall(GetBuildInfo)
    if not ok or ns:IsSecret(build) then return nil end
    if type(build) == "number" then return tostring(build) end
    if type(build) == "string" and build ~= "" then return build end
    return nil
end
local function Now()
    local ok, t = pcall(time)
    return (ok and not ns:IsSecret(t) and type(t) == "number") and t or 0
end
local function Labels(keys)
    local out = {}
    for _, key in ipairs(keys) do out[#out + 1] = ns:Tr(Label(key)) end
    return table.concat(out, ", ")
end

local function Check(deferred)
    local build = Build()
    local root = ns.root
    if not build or type(root) ~= "table" then return end
    local health = type(root.health) == "table" and root.health or {}
    local result = health.result
    local kept = type(result) == "table" and result.build == build and result.version == ns.version
    if not deferred and ns.Yes(InCombatLockdown()) and ns.AfterFight then
        -- (waits only when there is something to do once the fight ends: a baseline to take, or a game update to check)
        local base = health.base
        local fresh = type(base) == "table" and base.version == ns.version and root.lastBuild == build
        if kept or fresh then return end
        if ns:AfterFight("Health check", function() Check(true) end, true) then return end
    end
    root.health = health
    if kept then
        if not deferred then
            for _, key in ipairs(result.off or {}) do ns.healthOff[key] = true end
        end
        return
    end
    local base = health.base
    if type(base) ~= "table" or base.version ~= ns.version then                   -- (a first login, or an update)
        health.base = { version = ns.version, absent = ns.HealthScan() }
        health.result = nil
        root.lastBuild = build
        return
    end
    if root.lastBuild == build then return end
    local r = ns.HealthJudge(ns.HealthScan(), base)                                 -- (a game update)
    result = { build = build, version = ns.version, when = Now(), off = r.off, missing = r.missing, core = r.core }
    health.result = result
    if #r.off > 0 then
        if deferred then
            result.later = true
            ns:Print("After the game's update, these parts may not work. They are off from your next login until Fantasy Glass UI is updated: %s.", Labels(r.off))
        else
            for _, key in ipairs(r.off) do ns.healthOff[key] = true end
            ns:Print("After the game's update, these parts are off until Fantasy Glass UI is updated: %s.", Labels(r.off))
        end
        result.told = true
    elseif #r.core > 0 then
        ns:Print("After the game's update, some of what Fantasy Glass UI uses is missing: /fgui health lists it.")
        result.told = true
    end
end
function ns:HealthLogin() Check(false) end

-- /fgui health: the check now, against this version's baseline. The number of lines shown.
function ns:HealthCommand(text)
    if ns:AfterFight("Health check", function() ns:HealthCommand(text) end) then return 0 end
    local root = type(ns.root) == "table" and ns.root or nil
    local health = root and type(root.health) == "table" and root.health or nil
    local r = ns.HealthJudge(ns.HealthScan(), health and health.base or { absent = {} })
    if root then
        root.health = health or {}
        root.health.last = { when = Now(), build = Build(), version = ns.version, off = r.off, missing = r.missing, core = r.core }
    end
    local lines = {}
    local offNow = {}
    for key, on in pairs(ns.healthOff) do if on then offNow[#offNow + 1] = key end end
    for _, key in ipairs(ByLabel(offNow)) do
        lines[#lines + 1] = { left = format(ns:Tr("%s: off this session"), ns:Tr(Label(key))), tone = "dim" }
    end
    for _, key in ipairs(r.off) do
        lines[#lines + 1] = { left = ns:Tr(Label(key)), right = table.concat(r.missing[key], ", ") }
    end
    if #r.core > 0 then
        lines[#lines + 1] = { left = ns:Tr(Label("core")), right = table.concat(r.core, ", ") }
    end
    if #lines == 0 then lines[1] = { left = ns:Tr("Everything this version uses is in the game.") } end
    ns:ShowList("Health", "Health check", lines, "What this version needs from the game, and what the last check after a game update turned off.")
    return #lines
end

-- Report a problem: what the last check after a game update found (kept in English, for the maintainer).
ns.AddReportSection("health", function()
    local lines = { "AFTER THE LAST GAME UPDATE" }
    local health = type(ns.root) == "table" and type(ns.root.health) == "table" and ns.root.health or {}
    local r = health.result
    if type(r) ~= "table" then
        lines[2] = "  no game update since this version was installed"
        return lines
    end
    lines[#lines + 1] = "  build " .. tostring(r.build) .. ", version " .. tostring(r.version) .. ", checked against " .. tostring(ns.HEALTH_BUILD)
    local off = {}
    for _, key in ipairs(r.off or {}) do off[#off + 1] = Label(key) end
    if #off > 0 then lines[#lines + 1] = "  off: " .. table.concat(off, ", ") end
    for _, key in ipairs(r.off or {}) do
        local names = type(r.missing) == "table" and r.missing[key]
        if type(names) == "table" then lines[#lines + 1] = "  missing in " .. Label(key) .. ": " .. table.concat(names, ", ") end
    end
    if type(r.core) == "table" and #r.core > 0 then lines[#lines + 1] = "  core missing: " .. table.concat(r.core, ", ") end
    return lines
end)
