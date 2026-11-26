local _, ns = ...

------------------------------------------------------------------------------------------
-- 11.7: backups of your settings, a history of what you changed, profiles made from a role
-- template, and what each feature costs to load.
------------------------------------------------------------------------------------------
local function Copy(v) return ns.DeepCopy and ns.DeepCopy(v) or v end

------------------------------------------------------------------------------------------
-- Backups: your settings (every profile, which character uses which, your main, your mail rules)
-- are copied before each update of the add-on and once a day, at the first login of the day.
-- /fgui backup lists them; /fgui backup restore update|daily puts one back and reloads. A restore
-- first keeps what you have now as "before restore", so a restore can itself be undone.
------------------------------------------------------------------------------------------
ns.BACKUP_KINDS = { "update", "daily", "restore", "reset" }
ns.BACKUP_LABELS = { update = "Before the last update", daily = "Start of the last day you played", restore = "Before the last restore",
    reset = "Before the last reset" }
local function Snapshot(root, label)
    return { when = time and time() or 0, version = ns.version, label = label,
             profiles = Copy(root.profiles), chars = Copy(root.chars), mainChar = root.mainChar,
             mailRules = Copy(root.mailRules), mailTo = Copy(root.mailTo), altCopy = root.altCopy }
end
-- Called while the saved settings are read, once a session. Returns which backups were taken.
function ns:TakeBackups(root, today)
    if ns.backupsTaken then return {} end
    ns.backupsTaken = true
    root.backups = type(root.backups) == "table" and root.backups or {}
    local b, took = root.backups, {}
    local seen = root.seenVersion
    if type(seen) == "string" and seen ~= ns.version and type(root.profiles) == "table" then
        b.update = Snapshot(root, seen)                              -- (as it was under the version before)
        took[#took + 1] = "update"
    end
    today = today or (ns.Today and ns.Today()) or 0
    if b.dailyDay ~= today and type(root.profiles) == "table" then
        b.daily = Snapshot(root, nil)
        b.dailyDay = today
        took[#took + 1] = "daily"
    end
    return took
end
function ns:RestoreBackup(kind)
    local root = ns.root
    local b = type(root) == "table" and type(root.backups) == "table" and root.backups[kind]
    if type(b) ~= "table" or type(b.profiles) ~= "table" then return false, "There is no backup of that kind yet." end
    if InCombatLockdown() then return false, "Not during a fight." end
    root.backups.restore = Snapshot(root, nil)
    root.profiles = Copy(b.profiles)
    root.chars = Copy(b.chars) or root.chars
    root.mainChar = b.mainChar
    root.mailRules, root.mailTo = Copy(b.mailRules), Copy(b.mailTo)
    root.altCopy = b.altCopy
    if type(root.profiles.Default) ~= "table" then root.profiles.Default = {} end
    return true, "Settings put back. The interface reloads now."
end
-- /fgui reset: this profile back to how it came. Typed twice within ten seconds, so it is never an
-- accident, and a backup of everything is kept first ("/fgui backup restore reset" undoes it).
local resetAsked = 0
function ns:ResetProfileCommand(now)
    now = now or GetTime()
    local root = ns.root
    if type(root) ~= "table" or type(root.profiles) ~= "table" then return false end
    if InCombatLockdown() then ns:Print("Not during a fight."); return false end
    if now - resetAsked > 10 then
        resetAsked = now
        ns:Print("This puts every setting of the profile \"%s\" back to how it came, and reloads. Type |cffffff00/fgui reset|r again within ten seconds to do it.", tostring(ns.profile))
        return false
    end
    resetAsked = 0
    root.backups = type(root.backups) == "table" and root.backups or {}
    root.backups.reset = Snapshot(root, nil)
    root.profiles[ns.profile] = {}        -- this profile back to defaults; other profiles untouched
    ns:Print("Reset. If you change your mind: |cffffff00/fgui backup restore reset|r.")
    ReloadUI()
    return true
end

function ns.BackupLines(backups, now)
    local out = {}
    for _, kind in ipairs(ns.BACKUP_KINDS) do
        local b = type(backups) == "table" and backups[kind]
        if type(b) == "table" then
            local n = 0
            for _ in pairs(b.profiles or {}) do n = n + 1 end
            local when = ns.Ago((now or 0) - (b.when or 0))
            out[#out + 1] = { kind = kind, label = ns.BACKUP_LABELS[kind], when = when, profiles = n, version = b.label or b.version }
        end
    end
    return out
end
function ns:BackupCommand(text)
    local what = ns.Trim(text or ""):lower()
    local kind = what:match("^restore%s+(%a+)$")
    if kind then
        local ok, msg = ns:RestoreBackup(kind)
        ns:Print(msg)
        if ok then ReloadUI() end
        return ok
    end
    local lines = {}
    for _, l in ipairs(ns.BackupLines(ns.root.backups, time and time() or 0)) do
        lines[#lines + 1] = {
            left = ns:Tr(l.label) .. (l.version and ("  |cff9aa4b4" .. ns:Tr("version") .. " " .. tostring(l.version) .. "|r") or ""),
            right = "|cff9aa4b4" .. l.when .. ", " .. format(ns:Tr("%d profiles"), l.profiles) .. "|r",
            click = function()
                ns:Print("To put these settings back (the interface reloads), type: |cffffff00/fgui backup restore %s|r", l.kind)
            end,
            tip = { ns:Tr(l.label), format(ns:Tr("To put these settings back, type /fgui backup restore %s. What you have now is kept as \"Before the last restore\"."), l.kind) },
        }
    end
    if #lines == 0 then lines[1] = { left = ns:Tr("No backups yet: one is made at your first login each day and before each update.") } end
    ns:ShowList("Backups", "Backups of your settings", lines, "Made by themselves: before each update, once a day, and before a reset.", 460, math.min(300, 80 + #lines * 18))
    return #lines
end

------------------------------------------------------------------------------------------
-- What you changed: a short history for each profile ("Raid frame width 80 to 96, yesterday"),
-- worked out by comparing the settings with how they were last time, when the options window
-- closes, when you stop moving panels, and when you log out. Click a change to undo it.
------------------------------------------------------------------------------------------
local IGNORE = { layouts = true, layoutCtx = true, design = true, setupDone = true, tourDone = true }
local KEEP_CHANGES = 60
local function Repr(v)
    local t = type(v)
    if t == "table" then
        local keys, out = {}, {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do
            local x = v[k]
            out[#out + 1] = tostring(k) .. "=" .. ((type(x) == "table") and "{...}" or tostring(x))
        end
        return "{" .. table.concat(out, ",") .. "}"
    end
    return tostring(v)
end
-- The settings as a flat list: "key" or "key.sub" -> { repr, value }.
function ns.FlattenSettings(db)
    local out = {}
    for k, v in pairs(db or {}) do
        if type(k) == "string" and not IGNORE[k] and k:sub(1, 3) ~= "sui" then
            if type(v) == "table" then
                for k2, v2 in pairs(v) do
                    if type(k2) == "string" or type(k2) == "number" then out[k .. "." .. tostring(k2)] = { Repr(v2), Copy(v2) } end
                end
            elseif type(v) ~= "function" then
                out[k] = { Repr(v), v }
            end
        end
    end
    return out
end
-- What differs: { { path, old, new, oldValue } }, sorted by path.
function ns.SettingsDiff(before, after)
    local out = {}
    for path, a in pairs(after) do
        local b = before[path]
        if not b or b[1] ~= a[1] then out[#out + 1] = { path = path, old = b and b[1] or "(not set)", new = a[1], oldValue = b and b[2], wasSet = b ~= nil } end
    end
    for path, b in pairs(before) do
        if not after[path] then out[#out + 1] = { path = path, old = b[1], new = "(not set)", oldValue = b[2], wasSet = true } end
    end
    table.sort(out, function(x, y) return x.path < y.path end)
    return out
end
local function HistoryStore()
    local root = ns.root
    root.history = type(root.history) == "table" and root.history or {}
    root.history[ns.profile] = type(root.history[ns.profile]) == "table" and root.history[ns.profile] or { changes = {} }
    return root.history[ns.profile]
end
local lastFlat
-- Compare with last time and note what changed. Returns how many changes were noted.
function ns:NoteSettingChanges()
    if not (ns.db and ns.root) then return 0 end
    local now = ns.FlattenSettings(ns.db)
    local h = HistoryStore()
    local before = lastFlat or h.snapshot
    lastFlat = now
    h.snapshot = now
    if not before then return 0 end
    local diff = ns.SettingsDiff(before, now)
    if #diff > 25 then                                       -- (a preset, a gallery layout or an import: one line for it all)
        diff = { { path = format(ns:Tr("%d settings at once"), #diff), old = "", new = "", bulk = true } }
    end
    local t = time and time() or 0
    for _, d in ipairs(diff) do
        d.t = t
        table.insert(h.changes, 1, d)
    end
    while #h.changes > KEEP_CHANGES do table.remove(h.changes) end
    return #diff
end
function ns:UndoSettingChange(i)
    local h = HistoryStore()
    local d = h.changes[i]
    if type(d) ~= "table" or d.bulk then return false end
    local key, sub = d.path:match("^([^.]+)%.(.+)$")
    key = key or d.path
    local value = d.wasSet and Copy(d.oldValue) or nil
    if sub then
        if type(ns.db[key]) ~= "table" then ns.db[key] = {} end
        local k = tonumber(sub) or sub
        if ns.db[key][k] == nil and ns.db[key][sub] ~= nil then k = sub end
        ns.db[key][k] = value
    else
        ns.db[key] = value
        if value == nil and ns.defaults[key] ~= nil then ns.db[key] = Copy(ns.defaults[key]) end
    end
    table.remove(h.changes, i)
    lastFlat = ns.FlattenSettings(ns.db)
    h.snapshot = lastFlat
    return true
end
-- How a change reads in the list: the setting's name as the options show it (a switch's label, or the
-- name of a look or layout setting), then which panel it belongs to; on and off in words.
local SETTING_NAMES = { theme = "Theme", accent = "Accent color", fontStyle = "Lettering", fontScale = "Text size",
    uiScale = "Interface size", role = "Role", rounded = "Rounded corners", windowAlpha = "Window opacity",
    chatBg = "Chat background", barFade = "Fade when not in use", mailRules = "Mail rules", pos = "Panel positions",
    windowPos = "Window positions", panelShow = "When panels show", bars = "Bar settings", infobarParts = "Info bar",
    clickCast = "Click-casting" }
local function SettingName(path)
    local key, sub = path:match("^([^.]+)%.(.+)$")
    key = key or path
    local name = SETTING_NAMES[key] and ns:Tr(SETTING_NAMES[key])
    if not name then
        for _, group in ipairs(ns.featureGroups or {}) do
            for _, opt in ipairs(group[2]) do if opt[1] == key then name = ns:Tr(opt[2]) end end
        end
    end
    if not name then return path end
    if sub then
        local movable = ns.FindMovable and ns:FindMovable(sub)
        sub = (type(movable) == "table" and movable.label) and ns:Tr(movable.label) or sub
        return name .. ": " .. sub
    end
    return name
end
local function SettingValue(v)
    if v == "true" then return ns:Tr("on") elseif v == "false" then return ns:Tr("off")
    elseif v == "(not set)" then return ns:Tr("(not set)") end
    return v
end
ns.SettingName, ns.SettingValue = SettingName, SettingValue
function ns:ShowSettingHistory()
    if ns.LoadOptions then pcall(ns.LoadOptions, ns) end          -- (the switches' names live with the options)
    ns:NoteSettingChanges()
    local h = HistoryStore()
    local lines = {}
    local now = time and time() or 0
    for i, d in ipairs(h.changes) do
        local when = ns.Ago(now - (d.t or now))
        local old, new = SettingValue(tostring(d.old)), SettingValue(tostring(d.new))
        if #old > 24 then old = old:sub(1, 22) .. "..." end
        if #new > 24 then new = new:sub(1, 22) .. "..." end
        local name = d.bulk and d.path or SettingName(d.path)
        lines[#lines + 1] = {
            left = name .. (d.bulk and "" or ("  |cff9aa4b4" .. old .. " > |r" .. new)),
            right = "|cff9aa4b4" .. when .. "|r",
            click = (not d.bulk) and function()
                if ns:UndoSettingChange(i) then ns:Print("Undone: %s. Some changes show after a /reload.", name); ns:ShowSettingHistory() end
            end or nil,
            tip = { name, (not d.bulk) and ns:Tr("Click to put it back as it was.") or nil },
        }
    end
    if #lines == 0 then lines[1] = { left = ns:Tr("No changes noted yet for this profile.") } end
    ns:ShowList("SettingHistory", format(ns:Tr("Changes to the profile %s"), ns.profile), lines, "Newest first. Click one to undo it.", 520, 380)
    return #lines
end
do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Safety events", function(self, event)
        if event == "PLAYER_ENTERING_WORLD" then self:UnregisterEvent("PLAYER_ENTERING_WORLD") end
        pcall(ns.NoteSettingChanges, ns)
    end))
end

------------------------------------------------------------------------------------------
-- Profiles from a role template: a ready-made Tank, Healer or Damage setup, your current look
-- kept, the frames placed by the gallery's layout for that role, and the switches that suit it.
------------------------------------------------------------------------------------------
ns.ROLE_TEMPLATES = {
    TANK   = { label = "Tank",   gallery = "tank",    on = { "aggroWarn", "roleHUD", "kickRotation", "groupCDs", "nameplates" } },
    HEALER = { label = "Healer", gallery = "healer",  on = { "raidFrames", "buffCoverage", "groupCDs", "ufParty", "roleHUD" } },
    DAMAGE = { label = "Damage", gallery = "classic", on = { "executeLine", "cooldownPulse", "kickRotation", "focusCastAlert", "roleHUD" } },
}
local LOOK = { "theme", "accent", "fontStyle", "fontScale", "rounded", "barTexture", "windowAlpha", "chatBg" }
function ns.TemplateProfile(role, current)
    local t = ns.ROLE_TEMPLATES[role]
    if not t then return nil end
    local db = {}
    for k, v in pairs(ns.defaults) do
        if not (ns.GuideGatedHidden and ns.GuideGatedHidden(k)) then db[k] = Copy(v) end   -- (locked: no guide settings; they read their defaults)
    end
    for _, k in ipairs(LOOK) do if current and current[k] ~= nil then db[k] = Copy(current[k]) end end
    db.role = role
    db.design = 4
    db.pos = {}
    for _, g in ipairs(ns.GALLERY or {}) do
        if g.key == t.gallery then
            for k, p in pairs(g.pos) do db.pos[k] = { p[1], p[1], p[2], p[3] } end
            for k, v in pairs(g.db or {}) do db[k] = v end
        end
    end
    for _, k in ipairs(t.on) do if ns.defaults[k] ~= nil then db[k] = true end end
    db.setupDone = true
    return db
end
function ns:NewTemplateProfile(role)
    local t = ns.ROLE_TEMPLATES[role]
    if not t then return false, "No such template." end
    local base = ns:Tr(t.label) .. " " .. ns:Tr("template")
    local name, n = base, 2
    while ns.root.profiles[name] do name = base .. " " .. n; n = n + 1 end
    ns.root.profiles[name] = ns.TemplateProfile(role, ns.db)
    return true, format(ns:Tr("Profile '%s' made. Click Use to switch to it."), name), name
end

------------------------------------------------------------------------------------------
-- What each feature costs: the time it took to start at login and the memory it took then (an
-- estimate: memory is shared, and the game tidies it up at its own times). In the self-check and
-- /fgui perf load.
------------------------------------------------------------------------------------------
ns.moduleCost = ns.moduleCost or {}
function ns.CostRows(costs)
    local out = {}
    for key, c in pairs(costs or {}) do out[#out + 1] = { key = key, ms = c.ms or 0, kb = c.kb or 0 } end
    table.sort(out, function(a, b) if a.ms ~= b.ms then return a.ms > b.ms end return a.key < b.key end)
    return out
end
function ns:ShowLoadCost()
    local rows = ns.CostRows(ns.moduleCost)
    ns:LoadOptions()
    local names = {}
    for _, group in ipairs(ns.featureGroups or {}) do for _, opt in ipairs(group[2]) do names[opt[1]] = ns:Tr(opt[2]) end end
    local totalMs, totalKb = 0, 0
    for _, r in ipairs(rows) do totalMs, totalKb = totalMs + r.ms, totalKb + math.max(0, r.kb) end
    local lines = { { left = ns:AccentHex() .. ns:Tr("Every feature") .. "|r", right = format("%.0f ms  %.0f KB", totalMs, totalKb) } }
    for i, r in ipairs(rows) do
        if i > 40 then break end
        lines[#lines + 1] = { left = names[r.key] or r.key, right = format("%.1f ms  |cff9aa4b4%.0f KB|r", r.ms, math.max(0, r.kb)),
            bar = totalMs > 0 and r.ms / totalMs or 0, click = ns.ShowSwitch and function() ns:ShowSwitch(r.key) end or nil }
    end
    ns:ShowList("LoadCost", "What each feature costs at login", lines,
        "Time to start, and memory taken then (an estimate). Click one to go to its switch.", 460, 380)
    return #rows
end
