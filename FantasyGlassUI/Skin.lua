local _, ns = ...

-- The Fantasy Glass UI look. These are the colors before a theme is applied at login (Core.lua's
-- BuildPalette fills them in): glass, fantasy leather and gold, or a celestial night sky.
ns.theme = {
    bg     = { 0.075, 0.060, 0.045, 0.94 },
    border = { 0.42, 0.32, 0.17, 1.00 },      -- bronze
    accent = { 1.00, 0.82, 0.40, 1.00 },      -- gold; replaced by the chosen accent at login
    rim    = { 0.03, 0.025, 0.015, 1.00 },    -- dark line outside every border
    grain  = { 0.62, 0.47, 0.29, 0.13 },      -- tint and strength of the leather grain
    light  = { 1.00, 0.88, 0.62 },            -- color of the soft light along a panel's top
    btn    = { 1.00, 0.88, 0.62 },            -- button lettering
}
ns.FONT = "Fonts\\FRIZQT__.TTF"               -- body text (the game's own face unless "modern font" is on)
ns.TITLEFONT = "Fonts\\MORPHEUS.TTF"          -- headings
ns.FONTFLAGS = ""                             -- soft shadow instead of a hard pixel outline
ns.BAR = ns.FLAT

-- Set a font the Fantasy Glass UI way. title = true uses the heading face.
-- Translations. ns.L["Some text"] gives the translated text, or the English itself when there is no
-- translation. Buttons, checkboxes, sliders and headings look their labels up here automatically, so
-- adding a language is a matter of filling in Locales.lua (see /fgui strings).
-- The translations live in a third folder, FantasyGlassUI_Locales, which the game loads only when it
-- is asked for: the first time a language other than English is needed. English players never load it.
ns.locales = {}
ns.localesAddon = "FantasyGlassUI_Locales"
local ENGLISH = { enUS = true, enGB = true }
-- Load the translations folder if this language needs it and it is not in yet. true when the table is there.
function ns:NeedLocale(code)
    if type(code) ~= "string" or ENGLISH[code] then return false end
    if type(ns.locales[code]) == "table" then return true end
    if ns.localesLoadTried then return false end
    ns.localesLoadTried = true
    local C = C_AddOns
    local load = (type(C) == "table" and C.LoadAddOn) or LoadAddOn
    if type(load) ~= "function" then ns.localesState = "this game client cannot load an add-on on request"; return false end
    local ok, loaded, why = pcall(load, ns.localesAddon)
    if ok and not loaded and why == "DISABLED" then
        local enable = (type(C) == "table" and C.EnableAddOn) or EnableAddOn
        if type(enable) == "function" then pcall(enable, ns.localesAddon); ok, loaded, why = pcall(load, ns.localesAddon) end
    end
    ns.localesState = (ok and loaded) and "loaded" or ("not loaded (" .. tostring(ok and why or loaded) .. ")")
    if not (ok and loaded) then
        ns:PrintRaw("|cffff4444The translations could not be loaded|r (" .. tostring(ok and why or loaded)
            .. "). They are in a third folder, " .. ns.localesAddon .. ", which must sit beside FantasyGlassUI in Interface/AddOns and be enabled. Until then everything shows in English.")
    end
    return type(ns.locales[code]) == "table"
end
ns.seenStrings = {}
ns.L = setmetatable({}, { __index = function(_, key) return key end })
-- The translated text for a count: the first form for exactly one, the second for any other number.
function ns:TrN(n, one, many) return ns:Tr(n == 1 and one or many) end
function ns:Tr(text)
    if type(text) ~= "string" or text == "" then return text end
    ns.seenStrings[text] = true
    return ns.L[text]
end
-- Which language the add-on speaks. By default it follows the game; it can also be set by hand, in
-- the setup or from the Language button at the top of the options. The choice is kept for the whole
-- account, not per profile. Each language is listed under its own name, so it can be found by
-- someone who cannot read the one currently showing.
ns.languages = {
    { "auto", "Same as the game" },
    { "enUS", "English" },
    { "deDE", "Deutsch" },
    { "frFR", "Français" },
    { "esES", "Español" },
    { "itIT", "Italiano" },
    { "ptBR", "Português" },
    { "ruRU", "Русский" },
    { "koKR", "한국어" },
    { "zhCN", "简体中文" },
}
function ns:Language()
    local saved = ns.root and ns.root.language
    for _, def in ipairs(ns.languages) do
        if def[1] == saved then return saved end
    end
    return "auto"
end
function ns:LanguageName(code)
    for _, def in ipairs(ns.languages) do
        if def[1] == code then return (code == "auto") and ns:Tr(def[2]) or def[2] end
    end
    return tostring(code)
end
-- Returns true if the choice changed. Labels are written when each window is built, so a change
-- shows everywhere only after the interface reloads.
function ns:SetLanguage(code)
    if not ns.root then return false end
    local valid = false
    for _, def in ipairs(ns.languages) do if def[1] == code then valid = true end end
    if not valid or code == ns:Language() then return false end
    ns.root.language = (code ~= "auto") and code or nil
    ns:LoadLocale()
    return true
end
-- Only one language is ever in use, but the file holds them all. A little after login the tables for
-- the others are let go, which gives back their memory. If you then pick another language, the
-- change is saved and shows when the interface reloads (which is what the options ask for anyway).
function ns:TrimLocales()
    if ns.keepAllLocales then return 0 end
    local code = ns:Language()
    if code == "auto" then code = GetLocale and GetLocale() or "enUS" end
    local keep, dropped = ns.locales[code], 0
    for key, list in pairs(ns.locales) do
        if list ~= keep then ns.locales[key] = nil; dropped = dropped + 1 end
    end
    ns.localesTrimmed = true
    return dropped
end
function ns:LoadLocale()
    local code = ns:Language()
    if code == "auto" then code = GetLocale and GetLocale() or "enUS" end
    for k in pairs(ns.L) do rawset(ns.L, k, nil) end        -- start again from English
    ns:NeedLocale(code)
    local t = ns.locales[code]
    if type(t) ~= "table" then return code end
    for k, v in pairs(t) do
        if type(k) == "string" and type(v) == "string" and v ~= "" then rawset(ns.L, k, v) end
    end
    ns:TranslateBindings()
    return code
end
-- The names in the game's Key Bindings window, in the chosen language. The English names are noted
-- the first time (one look through the globals), so a change of language starts from them again.
function ns:TranslateBindings()
    if not ns.bindingEnglish then
        ns.bindingEnglish = {}
        for k, v in pairs(_G) do
            if type(k) == "string" and type(v) == "string" and (k:find("^BINDING_NAME_FANTASYGLASSUI_") or k:find("^BINDING_NAME_CLICK FantasyGlassUI")) then
                ns.bindingEnglish[k] = v
            end
        end
    end
    for k, english in pairs(ns.bindingEnglish) do _G[k] = ns.L[english] end
end

local fonts = setmetatable({}, { __mode = "k" })
function ns:Font(fs, size, title)
    if not fs or not fs.SetFont then return end
    local e = fonts[fs]
    if e then e[1], e[2] = size, title else fonts[fs] = { size, title } end
    if rawget(fs, "suiFamily") then return end              -- (a language name drawn with the game's font family)
    fs:SetFont(rawget(fs, "suiFixedFont") or (title and ns.TITLEFONT or ns.FONT), size * (ns.fontScale or 1), ns.FONTFLAGS)
    if fs.SetShadowOffset then
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 0.9)
    end
end

-- A language's own name needs a face that has its letters: the add-on's lettering has none for
-- Korean or Chinese. Those names use the game's own font family, which carries a face for every
-- alphabet (as players' names in chat do), so they read on any client; the file names below are
-- the fallback for a client without font families. Text in the chosen language is handled when
-- the theme is applied; this is for the names in the language lists.
ns.LANGUAGE_FONTS = { koKR = "Fonts\\2002.TTF", zhCN = "Fonts\\ARKai_T.ttf", zhTW = "Fonts\\bLEI00D.ttf" }
-- (defined after ns:Font and its table of fonts, which it uses)
function ns:LanguageFont(fs, code)
    if type(fs) ~= "table" or not fs.SetFont then return end
    local e = fonts[fs]
    if not ns.LANGUAGE_FONTS[code] then
        fs.suiFamily, fs.suiFixedFont = nil, nil
        ns:Font(fs, e and e[1] or 12, e and e[2])
        return
    end
    local family = _G.GameFontHighlight
    if type(family) == "table" and fs.SetFontObject and pcall(fs.SetFontObject, fs, family) then
        fs.suiFamily = true                                  -- (left as the family: setting one file would lose the other alphabets)
        return
    end
    fs.suiFixedFont = ns.LANGUAGE_FONTS[code]
    ns:Font(fs, e and e[1] or 12, e and e[2])
end
-- One error disables the wrapped function (prints once) instead of spamming.
function ns:Safe(label, fn)
    local failed = false
    return function(...)
        if failed then return end
        local ok, err = pcall(fn, ...)
        if not ok then
            failed = true
            if #ns.errors < 60 then ns.errors[#ns.errors + 1] = label .. " (switched off): " .. tostring(err) end
            ns:PrintRaw("|cffff4444" .. label .. " disabled after an error:|r " .. tostring(err))
        end
    end
end

-- Some of the game's frames are "forbidden": an add-on may not call anything on them at all (doing
-- so raises an error), except to ask whether they are forbidden. So anything that walks through
-- frames it did not create - the screen's children, whatever is under the mouse - asks this first.
function ns:Usable(f)
    if type(f) ~= "table" then return false end
    local check = f.IsForbidden
    if check then
        local ok, forbidden = pcall(check, f)
        if not ok or forbidden then return false end
    end
    return true
end

-- Like Safe, but keeps running: reports the first error only.
function ns:Guard(label, fn)
    local told = false
    return function(...)
        local ok, err
        if ns.perfOn then                                    -- /fgui perf is measuring: time this call
            local t0 = debugprofilestop()
            ok, err = pcall(fn, ...)
            ns:PerfAdd(label, debugprofilestop() - t0)
        else
            ok, err = pcall(fn, ...)
        end
        if not ok and not told then
            told = true
            if #ns.errors < 60 then ns.errors[#ns.errors + 1] = label .. ": " .. tostring(err) end
            ns:PrintRaw("|cffff4444" .. label .. ":|r " .. tostring(err))
        end
    end
end

-- Make a Blizzard frame/texture invisible WITHOUT hooking or hiding it.
-- Hooks on the game's own frame methods taint its code (blocked actions in combat),
-- so we only set alpha and quietly re-assert it once a second.
local kept, trees, strict = {}, {}, {}

function ns:Kill(obj, everyFrame)
    if type(obj) ~= "table" or obj.suiKilled or not obj.SetAlpha then return end
    obj.suiKilled = true
    pcall(obj.SetAlpha, obj, 0)
    if obj.EnableMouse and not (obj.IsProtected and obj:IsProtected()) then
        pcall(obj.EnableMouse, obj, false)
    end
    if everyFrame then strict[#strict + 1] = obj else kept[#kept + 1] = obj end
end

-- Kill a whole frame tree and stop anything inside it taking clicks.
function ns:Silence(frame)
    if type(frame) ~= "table" then return end
    ns:Kill(frame)
    for _, f in ipairs(trees) do if f == frame then return end end     -- already being watched
    trees[#trees + 1] = frame
end

function ns:Unkill(obj)
    if type(obj) ~= "table" then return end
    for i = #kept, 1, -1 do if kept[i] == obj then table.remove(kept, i) end end
    for i = #trees, 1, -1 do if trees[i] == obj then table.remove(trees, i) end end
    for i = #strict, 1, -1 do if strict[i] == obj then table.remove(strict, i) end end
    obj.suiKilled = nil
    pcall(obj.SetAlpha, obj, 1)
end

-- what we switched off under each silenced root, so it can be given back
local muted = setmetatable({}, { __mode = "k" })
local hidden = setmetatable({}, { __mode = "k" })

local MuteTree
-- (the children are walked straight off the call's results: this runs every second, so no table is
-- made for them)
local function MuteKids(depth, root, ...)
    for i = 1, select("#", ...) do MuteTree((select(i, ...)), depth, root) end
end
function MuteTree(f, depth, root)
    if depth > 5 or type(f) ~= "table" or not f.GetChildren then return end
    if f.IsForbidden and f:IsForbidden() then return end
    if f.IsProtected and f:IsProtected() then
        -- Invisible secure buttons must not stay clickable. They are only made deaf to the mouse
        -- (out of combat), never hidden: hiding one of the game's buttons runs the game's own code
        -- for it from here, and that leaves the game's bars "touched by an add-on", so that later,
        -- in a fight, the game is refused when it moves or shows them ("Interface action failed").
        if f ~= root and not InCombatLockdown() and f.IsMouseEnabled and f:IsMouseEnabled() then
            f:EnableMouse(false)
            muted[root] = muted[root] or {}
            muted[root][f] = true
        end
    elseif f.IsMouseEnabled and f:IsMouseEnabled() then
        f:EnableMouse(false)
        muted[root] = muted[root] or {}
        muted[root][f] = true
    end
    MuteKids(depth + 1, root, f:GetChildren())
end

-- Undo ns:Silence: visible and clickable again.
function ns:Unsilence(frame)
    if type(frame) ~= "table" then return end
    ns:Unkill(frame)
    if not InCombatLockdown() then
        for f in pairs(muted[frame] or {}) do pcall(f.EnableMouse, f, true) end
        for f in pairs(hidden[frame] or {}) do pcall(f.Show, f) end
    end
    muted[frame], hidden[frame] = nil, nil
end

local function KeepClear(obj)
    if obj:GetAlpha() ~= 0 then obj:SetAlpha(0) end
end
local keeper, kacc = CreateFrame("Frame"), 0
-- (11.14.1) The every-frame list is walked without a protected call per object: one call covers the
-- walk, and if an object fails, the walk goes on after it the same frame.
local function ClearStrict(from)
    for i = from, #strict do
        local o = strict[i]
        if o:GetAlpha() ~= 0 then o:SetAlpha(0) end
    end
end
local function ClearStrictSafe()
    local from = 1
    while from <= #strict do
        local ok = pcall(ClearStrict, from)
        if ok then return end
        -- find the one that failed and step past it
        local bad = from
        for i = from, #strict do
            if not pcall(KeepClear, strict[i]) then bad = i break end
        end
        from = bad + 1
    end
end
keeper:SetScript("OnUpdate", function(_, e)
    if #strict > 0 then ClearStrictSafe() end
    kacc = kacc + e
    if kacc < 1 then return end
    kacc = 0
    for i = 1, #kept do pcall(KeepClear, kept[i]) end
    for _, f in ipairs(trees) do
        if f.IsVisible and f:IsVisible() then pcall(MuteTree, f, 0, f) end      -- hidden frames can't be clicked anyway
    end
end)

-- One shared timer for everything that runs "every so often", instead of a frame per feature.
do
    local jobs = {}
    local driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", function(_, e)
        for i = 1, #jobs do
            local j = jobs[i]
            j.acc = j.acc + e
            if j.acc >= j.every then
                j.acc = 0
                j.fn(j.every)
            end
        end
    end)
    function ns:Every(seconds, label, fn)
        jobs[#jobs + 1] = { every = seconds, acc = 0, fn = ns:Guard(label, fn) }
    end
end

-- Live colors ---------------------------------------------------------------------------------------
-- ns:Paint(obj, "SetVertexColor", "bg", 0.9) sets a themed color AND remembers it, so a theme or
-- accent change can repaint everything on the spot. Roles starting with "@" read the theme table
-- directly ("@accent", "@border", "@bg", "@btn", "@light", "@rim"); the rest are palette roles.
local painted = setmetatable({}, { __mode = "k" })
local DIRECT = { ["@accent"] = "accent", ["@border"] = "border", ["@bg"] = "bg", ["@btn"] = "btn", ["@light"] = "light", ["@rim"] = "rim" }

function ns:Role(role, alpha)
    local key = DIRECT[role]
    if key then
        local c = ns.theme[key]
        if alpha ~= nil then return c[1], c[2], c[3], alpha end
        return c[1], c[2], c[3]
    end
    return ns:T(role, alpha)
end

function ns:Paint(obj, method, role, alpha)
    if type(obj) ~= "table" then return end
    local fn = obj[method]
    if not fn then return end
    local list = painted[obj]
    if not list then list = {}; painted[obj] = list end
    local e = list[method]
    if e then e[1], e[2] = role, alpha else list[method] = { role, alpha } end
    fn(obj, ns:Role(role, alpha))
end

-- Stop re-applying a remembered color (the object is about to take one of its own).
function ns:Unpaint(obj, method)
    local list = type(obj) == "table" and painted[obj]
    if list then list[method] = nil end
end

local themeHooks = {}
function ns:OnTheme(fn) themeHooks[#themeHooks + 1] = fn end

-- Re-apply every remembered color and font, then let modules refresh what they draw themselves.
function ns:Repaint()
    for obj, list in pairs(painted) do
        for method, e in pairs(list) do
            local fn = obj[method]
            if fn then pcall(fn, obj, ns:Role(e[1], e[2])) end
        end
    end
    for fs, e in pairs(fonts) do
        if not rawget(fs, "suiFamily") then pcall(fs.SetFont, fs, rawget(fs, "suiFixedFont") or (e[2] and ns.TITLEFONT or ns.FONT), e[1] * (ns.fontScale or 1), ns.FONTFLAGS) end
        local fit = rawget(fs, "suiFit")
        if fit then pcall(fit) end                               -- (a button's label: fitted again at the new size)
    end
    for _, fn in ipairs(themeHooks) do pcall(fn) end
end

-- Four thin textures forming a rectangle outline; inset < 0 draws outside the frame.
function ns:Outline(frame, inset, r, g, b, a, layer)
    local function line()
        local t = frame:CreateTexture(nil, layer or "BORDER")
        t:SetTexture(ns.FLAT)
        t:SetVertexColor(r, g, b, a or 1)
        t.sui = true
        return t
    end
    local top, bottom, left, right = line(), line(), line(), line()
    top:SetHeight(1);    top:SetPoint("TOPLEFT", inset, -inset);       top:SetPoint("TOPRIGHT", -inset, -inset)
    bottom:SetHeight(1); bottom:SetPoint("BOTTOMLEFT", inset, inset);  bottom:SetPoint("BOTTOMRIGHT", -inset, inset)
    left:SetWidth(1);    left:SetPoint("TOPLEFT", inset, -inset);      left:SetPoint("BOTTOMLEFT", inset, inset)
    right:SetWidth(1);   right:SetPoint("TOPRIGHT", -inset, -inset);   right:SetPoint("BOTTOMRIGHT", -inset, inset)
    local lines = { top, bottom, left, right }
    function lines:SetColor(cr, cg, cb, ca)
        for i = 1, 4 do self[i]:SetVertexColor(cr, cg, cb, ca or 1) end
    end
    return lines
end

-- Panel art painted straight onto a frame's own background layer (fill + rim + the full dressing).
-- Unlike a backdrop child frame this can never end up drawn over the frame's text.
function ns:PaintPanel(frame, alpha, plain)
    if type(frame) ~= "table" or frame.suiPainted or not frame.CreateTexture then return end
    frame.suiPainted = true
    frame.suiNoRound = true              -- a game frame: never swap out its own methods for rounded art
    local th = ns.theme
    -- Some of the game's frames carry a CreateTexture that gives nothing back (seen on one of the
    -- pop-up menu frames). Such a frame can't be painted; it is left as the game draws it. It stays
    -- marked as done above, so it is not tried again every time the menu opens.
    local ok, fill = pcall(frame.CreateTexture, frame, nil, "BACKGROUND", nil, -8)
    if not ok or type(fill) ~= "table" or not fill.SetAllPoints then return nil end
    fill:SetAllPoints()
    fill:SetTexture(ns.FLAT)
    ns:Paint(fill, "SetVertexColor", "window", alpha or 0.97)
    fill.sui = true
    frame.suiFill = fill
    frame.suiRim = ns:Outline(frame, 0, th.border[1], th.border[2], th.border[3], 1, "BACKGROUND")
    ns:Dress(frame, plain)
    return fill
end

-- Celestial (11.11): a four-pointed star, glowing in the accent, centred on `point` of `anchor`.
function ns:Sparkle(host, anchor, point, size, x, y, alpha)
    local t = host:CreateTexture(nil, "OVERLAY")
    t:SetTexture(ns.MEDIA .. "sparkle.tga")
    t:SetSize(size, size)
    t:SetPoint("CENTER", anchor, point, x or 0, y or 0)
    if t.SetBlendMode then t:SetBlendMode("ADD") end
    ns:Paint(t, "SetVertexColor", "@accent", alpha or 1)
    t.sui = true
    return t
end
-- An action button lit from inside, for the Celestial family: a soft glow just inside its edge.
function ns:CelestialButtonEdge(btn)
    if ns.style ~= "CELESTIAL" or type(btn) ~= "table" or not btn.CreateTexture or rawget(btn, "suiStarEdge") then return end
    local t = btn:CreateTexture(nil, "OVERLAY", nil, 6)
    t:SetTexture(ns.MEDIA .. "button_celestial.tga")
    t:SetAllPoints()
    if t.SetBlendMode then t:SetBlendMode("ADD") end
    ns:Paint(t, "SetVertexColor", "@accent", 0.55)
    t.sui = true
    btn.suiStarEdge = t
    return t
end

function ns:Corners(host, anchor, size, offset)
    if ns.style == "GLASS" then return end          -- glass has no ornament
    if ns.style == "CELESTIAL" then return end     -- (Celestial's panels carry their own small star, at the top)
    local a = ns.theme.accent
    size, offset = size or 18, offset or 1
    local coords = {
        TOPLEFT     = { 0, 1, 0, 1,  offset, -offset },
        TOPRIGHT    = { 1, 0, 0, 1, -offset, -offset },
        BOTTOMLEFT  = { 0, 1, 1, 0,  offset,  offset },
        BOTTOMRIGHT = { 1, 0, 1, 0, -offset,  offset },
    }
    local made = {}
    for point, c in pairs(coords) do
        local t = host:CreateTexture(nil, "OVERLAY")
        made[#made + 1] = t
        t:SetTexture(ns.MEDIA .. "corner.tga")
        t:SetTexCoord(c[1], c[2], c[3], c[4])
        t:SetSize(size, size)
        t:SetPoint(point, anchor, point, c[5], c[6])
        ns:Paint(t, "SetVertexColor", "@accent", 1)
        t.sui = true
    end
    return made                                         -- (so a frame can put them away: Starcut)
end

-- A jewelled divider line, tinted with the accent.
function ns:Divider(parent, height)
    local a = ns.theme.accent
    local t = parent:CreateTexture(nil, "ARTWORK")
    if ns.style == "GLASS" then                     -- a line of light that fades out at both ends
        t:SetTexture(ns.MEDIA .. "line.tga")
        t:SetHeight(5)
        ns:Paint(t, "SetVertexColor", "@accent", 1)
    elseif ns.style == "CELESTIAL" then             -- a fine line of light with a star at its middle
        t:SetTexture(ns.MEDIA .. "line.tga")
        t:SetHeight(5)
        if t.SetBlendMode then t:SetBlendMode("ADD") end
        ns:Paint(t, "SetVertexColor", "@accent", 0.85)
        local star = parent:CreateTexture(nil, "OVERLAY")
        star:SetTexture(ns.MEDIA .. "sparkle.tga")
        star:SetSize(22, 22)
        star:SetPoint("CENTER", t, "CENTER", 0, 0)
        if star.SetBlendMode then star:SetBlendMode("ADD") end
        ns:Paint(star, "SetVertexColor", "@accent", 1)
        star.sui = true
        if ns.SkyBreathe then ns.SkyBreathe(star, 0.6, 1, 3.4) end   -- (breathing slowly)
        t.suiStar = star
        hooksecurefunc(t, "Hide", function() star:Hide() end)       -- (the star goes and comes with its line)
        hooksecurefunc(t, "Show", function() star:Show() end)
    else
        t:SetTexture(ns.MEDIA .. "divider.tga")
        t:SetHeight(height or 12)
        ns:Paint(t, "SetVertexColor", "@accent", 0.9)
    end
    return t
end

-- The Fantasy Glass UI panel look: leather grain, warm top light, dark outer rim, inner gold hairline
-- and corner filigree. plain = true leaves the corners off (thin strips and resizing panels).
-- Soft drop shadow around a frame: gradient strips along the edges, a rounded falloff in the corners.
function ns:Shadow(frame, size, strength)
    if not (CreateColor and frame.CreateTexture) then return end
    size, strength = size or 8, strength or 0.4
    local function strip()
        local t = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        t:SetTexture(ns.FLAT)
        t.sui = true
        return t
    end
    local dark, clear = CreateColor(0, 0, 0, strength), CreateColor(0, 0, 0, 0)
    local top, bottom, left, right = strip(), strip(), strip(), strip()
    if not top.SetGradient then return end
    top:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 0);        top:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 0);       top:SetHeight(size)
    bottom:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 0);     bottom:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 0);   bottom:SetHeight(size)
    left:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0);         left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 0);   left:SetWidth(size)
    right:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0);        right:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 0, 0);  right:SetWidth(size)
    top:SetGradient("VERTICAL", dark, clear)
    bottom:SetGradient("VERTICAL", clear, dark)
    left:SetGradient("HORIZONTAL", clear, dark)
    right:SetGradient("HORIZONTAL", dark, clear)
    local corners = {                      -- anchor on the corner texture, anchor on the frame, texcoords
        { "BOTTOMRIGHT", "TOPLEFT",     0, 1, 0, 1 },
        { "BOTTOMLEFT",  "TOPRIGHT",    1, 0, 0, 1 },
        { "TOPRIGHT",    "BOTTOMLEFT",  0, 1, 1, 0 },
        { "TOPLEFT",     "BOTTOMRIGHT", 1, 0, 1, 0 },
    }
    for _, c in ipairs(corners) do
        local t = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        t:SetTexture(ns.MEDIA .. "shadow.tga")
        t:SetTexCoord(c[3], c[4], c[5], c[6])
        t:SetSize(size, size)
        t:SetPoint(c[1], frame, c[2], 0, 0)
        t:SetVertexColor(0, 0, 0, strength)
        t.sui = true
    end
end

-- Rounded corners. A rounded tile is cut into nine slices by the game so the corners keep their
-- shape at any panel size. Needs a client that can slice textures; otherwise panels stay square.
local function Sliced(tex, file)
    tex:SetTexture(ns.MEDIA .. file)
    tex:SetTextureSliceMargins(8, 8, 8, 8)
    if tex.SetTextureSliceMode and Enum and Enum.UITextureSliceMode then
        tex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    end
    tex.sui = true
end

-- For modules that draw their own rounded pieces (chat bubbles).
function ns:SliceTexture(tex, file) Sliced(tex, file) end

function ns:CanRound()
    return ns.style == "GLASS" and ns.db.rounded and ns.roundOK and true or false
end

-- Swap one of OUR frames' square backdrop for rounded art. From then on its SetBackdropColor and
-- SetBackdropBorderColor paint the rounded pieces, so the rest of the code needs no changes.
function ns:Round(frame)
    if frame.suiRound or not (frame.SetBackdropColor and frame.GetBackdropColor) then return false end
    local r, g, b, a = frame:GetBackdropColor()
    local er, eg, eb, ea = frame:GetBackdropBorderColor()
    local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    fill:SetAllPoints()
    Sliced(fill, "round.tga")
    local edge = frame:CreateTexture(nil, "BORDER")
    edge:SetAllPoints()
    Sliced(edge, "round_edge.tga")
    local setFill, setEdge = frame.SetBackdropColor, frame.SetBackdropBorderColor
    setFill(frame, 0, 0, 0, 0)
    setEdge(frame, 0, 0, 0, 0)
    frame.SetBackdropColor = function(_, cr, cg, cb, ca) fill:SetVertexColor(cr, cg, cb, ca or 1) end
    frame.SetBackdropBorderColor = function(_, cr, cg, cb, ca) edge:SetVertexColor(cr, cg, cb, ca or 1) end
    frame:SetBackdropColor(type(r) == "number" and r or 0, g or 0, b or 0, a or 1)
    frame:SetBackdropBorderColor(type(er) == "number" and er or 0, eg or 0, eb or 0, ea or 1)
    frame.suiRound = true
    return true
end

-- Glass pane dressing: light pooling toward the top, a bright top edge, a dark hairline outside, a soft shadow.
local function DressGlass(frame, plain)
    local lt = ns.theme.light
    local round = not frame.suiNoRound and (frame.suiRound or (ns:CanRound() and ns:Round(frame)))
    local side = round and 6 or 1                       -- keep the light clear of rounded corners
    local sheen = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    sheen:SetPoint("TOPLEFT", side, -1)
    sheen:SetPoint("BOTTOMRIGHT", -side, 1)
    sheen:SetTexture(ns.FLAT)
    sheen.sui = true
    if sheen.SetGradient and CreateColor then
        sheen:SetGradient("VERTICAL", CreateColor(lt[1], lt[2], lt[3], 0), CreateColor(lt[1], lt[2], lt[3], 0.10))
    else
        sheen:SetVertexColor(lt[1], lt[2], lt[3], 0.04)
    end
    local edge = frame:CreateTexture(nil, "BORDER")            -- the pane catching light along its top
    edge:SetHeight(1)
    edge:SetPoint("TOPLEFT", side, -1)
    edge:SetPoint("TOPRIGHT", -side, -1)
    edge:SetTexture(ns.FLAT)
    edge:SetVertexColor(lt[1], lt[2], lt[3], 0.24)
    edge.sui = true
    if not round then ns:Outline(frame, -1, 0, 0, 0, 0.45, "BACKGROUND") end
    ns:Shadow(frame, plain and 5 or 9, plain and 0.28 or 0.40)
end

-- Celestial panel (11.11): a night sky with depth. The sky deepens toward the top, a glow lies along
-- the foot like a horizon, the stars are sparse and uneven (each window sees a different part of the
-- sky), and a faint Milky Way crosses it. One fine line round the edge with a soft glow inside it, a
-- small star at the top, and on large windows one real constellation and an orbit across a corner.
local skyCount = 0
local function SkyLayer(frame, file, sub, size, off, r, g, b, a)
    local t = frame:CreateTexture(nil, "BACKGROUND", nil, sub)
    t:SetPoint("TOPLEFT", 1, -1)
    t:SetPoint("BOTTOMRIGHT", -1, 1)
    if not pcall(t.SetTexture, t, ns.MEDIA .. file, "REPEAT", "REPEAT") then t:SetTexture(ns.MEDIA .. file) end
    if t.SetBlendMode then t:SetBlendMode("ADD") end
    t:SetVertexColor(r, g, b, a)
    t.sui = true
    t.suiTile, t.suiOff = size, off                     -- (the texture at its own size, from its own place in the sky)
    return t
end
local function TileTo(t, w, h)
    local u, v = t.suiOff, t.suiOff * 0.618
    pcall(t.SetTexCoord, t, u, u + w / t.suiTile, v, v + h / t.suiTile)
end
local function Gradient(t, top, topA, bottom, bottomA)
    t.suiGradient = true
    if not (t.SetGradient and CreateColor) then t:SetVertexColor(top[1], top[2], top[3], topA * 0.4); return end
    t:SetGradient("VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], bottomA), CreateColor(top[1], top[2], top[3], topA))
end
-- Celestial motion (11.11): stars that twinkle, the horizon, the Milky Way and the constellation
-- breathing slowly, the top star turning, and now and then a shooting star across a large window.
-- All of it is the game's own animation (nothing is redrawn by the add-on each frame), it runs only
-- on windows that are showing, and "Reduce motion" holds it all still.
local skyLoops, skyWindows, skyWatch = {}, setmetatable({}, { __mode = "k" }), false
function ns:SkyLoop(region, kind, time, set, bounce)
    if not (region and region.CreateAnimationGroup) then return nil end
    if rawget(region, "suiGradient") then return nil end         -- (never on a SetGradient fade: it would turn white)
    local g = region:CreateAnimationGroup()
    if g.SetLooping then g:SetLooping(bounce == false and "REPEAT" or "BOUNCE") end
    local a = g:CreateAnimation(kind)
    set(a)
    if a.SetDuration then a:SetDuration(time) end
    if a.SetSmoothing and bounce ~= false then a:SetSmoothing("IN_OUT") end
    skyLoops[#skyLoops + 1] = g
    if ns:Motion() and g.Play then g:Play() end
    if not skyWatch and ns.Every then
        skyWatch = true
        local was = ns:Motion()
        ns:Every(2, "Celestial motion", function()                -- (Reduce motion switched on or off)
            local now = ns:Motion()
            if now == was then return end
            was = now
            for _, loop in ipairs(skyLoops) do
                if now then pcall(loop.Play, loop) else pcall(loop.Stop, loop) end
            end
        end)
    end
    return g
end
local function Breathe(region, low, high, time)
    return ns:SkyLoop(region, "Alpha", time, function(a) a:SetFromAlpha(low); a:SetToAlpha(high) end)
end
ns.SkyBreathe = Breathe
ns.skyLoops = skyLoops
-- Motes of starlight: small stars drifting up through a large window, fading in and out as they go,
-- each on its own path and in its own time.
function ns:SkyMotes(frame, n)
    for i = 1, 6 do
        local m = frame:CreateTexture(nil, "BORDER", nil, 2)
        m:SetTexture(ns.MEDIA .. "sparkle.tga")
        local size = 7 + ((n + i) % 3) * 2
        m:SetSize(size, size)
        if m.SetBlendMode then m:SetBlendMode("ADD") end
        ns:Paint(m, "SetVertexColor", "@accent", 0.9)
        m:SetPoint("BOTTOM", frame, "BOTTOMLEFT", 0, 6)
        m:SetAlpha(0)
        m.sui = true
        m.suiPlace = ((n * 0.37 + i * 0.161) % 1)                     -- (across the window: placed when its width is known)
        local g = m.CreateAnimationGroup and m:CreateAnimationGroup()
        if g then
            if g.SetLooping then g:SetLooping("REPEAT") end
            local time = 6 + ((n + i * 3) % 5)
            local rise = g:CreateAnimation("Translation"); rise:SetOffset((i % 2 == 0) and 14 or -14, 120 + (i % 3) * 30); rise:SetDuration(time)
            local inA = g:CreateAnimation("Alpha"); inA:SetFromAlpha(0); inA:SetToAlpha(1); inA:SetDuration(time * 0.3)
            local outA = g:CreateAnimation("Alpha"); outA:SetFromAlpha(1); outA:SetToAlpha(0); outA:SetDuration(time * 0.5)
            local wait = i * 0.9                                     -- (each mote starts a little after the one before)
            if rise.SetStartDelay then rise:SetStartDelay(wait); inA:SetStartDelay(wait); outA:SetStartDelay(time * 0.5 + wait) end
            skyLoops[#skyLoops + 1] = g
            if ns:Motion() and g.Play then g:Play() end
        end
        local motes = rawget(frame, "suiMotes") or {}
        motes[#motes + 1] = m
        frame.suiMotes = motes
    end
end
function ns.PlaceMotes(frame, w, shown)
    for _, m in ipairs(rawget(frame, "suiMotes") or {}) do
        m:SetShown(shown ~= false)                                   -- (a window too small for them: none)
        m:ClearAllPoints()
        m:SetPoint("BOTTOM", frame, "BOTTOMLEFT", 12 + m.suiPlace * math.max(1, w - 24), 6)
    end
end

-- A shooting star: now and then, across the upper part of one large window that is showing.
local function ShootingStar(frame)
    local s = rawget(frame, "suiShooting")
    if not s then
        s = frame:CreateTexture(nil, "BORDER", nil, 2)
        s:SetTexture(ns.MEDIA .. "shooting.tga")
        s:SetSize(140, 14)
        if s.SetBlendMode then s:SetBlendMode("ADD") end
        local lt = ns.theme.light
        s:SetVertexColor(lt[1] * 0.3 + 0.7, lt[2] * 0.3 + 0.7, lt[3] * 0.3 + 0.7, 1)       -- (nearly white: a streak of real light)
        s:SetAlpha(0)
        if s.SetRotation then pcall(s.SetRotation, s, math.rad(-18)) end    -- (falling a little as it goes)
        s.sui = true
        local g = s.CreateAnimationGroup and s:CreateAnimationGroup()
        if g then
            local fadeIn = g:CreateAnimation("Alpha"); fadeIn:SetFromAlpha(0); fadeIn:SetToAlpha(1); fadeIn:SetDuration(0.15)
            local move = g:CreateAnimation("Translation"); move:SetOffset(150, -48); move:SetDuration(0.9)
            local fadeOut = g:CreateAnimation("Alpha"); fadeOut:SetFromAlpha(1); fadeOut:SetToAlpha(0); fadeOut:SetDuration(0.45)
            if fadeOut.SetStartDelay then fadeOut:SetStartDelay(0.45) end
            s.flight = g
        end
        frame.suiShooting = s
    end
    local okW, w = pcall(frame.GetWidth, frame)
    local okH, h = pcall(frame.GetHeight, frame)
    if not (okW and type(w) == "number") or ns:IsSecret(w) then w = 300 end      -- (size not known: a guess will do)
    if not (okH and type(h) == "number") or ns:IsSecret(h) then h = 200 end
    s:ClearAllPoints()
    s:SetPoint("CENTER", frame, "TOPLEFT", w * (0.15 + math.random() * 0.4), -h * (0.15 + math.random() * 0.25))
    if s.flight then s.flight:Stop(); s.flight:Play() end
    return true
end
ns.ShootingStar = ShootingStar
local nextShot = 0
local function ShootingTick()
    if not ns:Motion() or ns.style ~= "CELESTIAL" then return end
    local now = GetTime()
    if now < nextShot then return end
    nextShot = now + 6 + math.random() * 8                         -- (one every ten seconds or so, somewhere)
    local shown = {}
    for f in pairs(skyWindows) do
        local ok, v = pcall(f.IsVisible, f)
        if ok and v then shown[#shown + 1] = f end
    end
    if #shown > 0 then ns.lastShootingStar = shown[math.random(#shown)]; ShootingStar(ns.lastShootingStar) end
end
ns.ShootingTick = ShootingTick

local function DressCelestial(frame, plain)
    skyCount = skyCount + 1
    local n = skyCount
    local th = ns.theme
    local a, bg, lt = th.accent, th.bg, th.light
    local sky = frame:CreateTexture(nil, "BACKGROUND", nil, 1)          -- deeper toward the top
    sky:SetPoint("TOPLEFT", 1, -1)
    sky:SetPoint("BOTTOMRIGHT", -1, 1)
    sky:SetTexture(ns.FLAT)
    sky.sui = true
    Gradient(sky, { math.min(1, bg[1] * 1.6 + a[1] * 0.05), math.min(1, bg[2] * 1.6 + a[2] * 0.05), math.min(1, bg[3] * 1.6 + a[3] * 0.05 + 0.012) }, 0.9, bg, 0)
    local horizon = frame:CreateTexture(nil, "BACKGROUND", nil, 2)      -- and lit along its foot
    horizon:SetPoint("BOTTOMLEFT", 1, 1)
    horizon:SetPoint("BOTTOMRIGHT", -1, 1)
    horizon:SetHeight(plain and 10 or 60)
    -- (a picture of the fade, tinted: a fade made with SetGradient turns white on some game clients
    -- while an animation plays on it, so nothing that breathes is drawn that way)
    horizon:SetTexture(ns.MEDIA .. "glow_up.tga")
    horizon.sui = true
    ns:Paint(horizon, "SetVertexColor", "@accent", 0.16)
    Breathe(horizon, 0.45, 1, 4 + (n % 3) * 0.5)                    -- the horizon breathing
    local layers = {}
    if not plain then layers[#layers + 1] = SkyLayer(frame, "milkyway.tga", 3, 512, (n * 0.19) % 1, lt[1], lt[2], lt[3], 0.20) end
    layers[#layers + 1] = SkyLayer(frame, "stars.tga", 4, 512, (n * 0.37) % 1, lt[1], lt[2], lt[3], plain and 0.28 or 0.6)
    frame.suiGrain = layers[#layers]
    if layers[2] then Breathe(layers[1], 0.5, 1, 6) end             -- the Milky Way, more slowly
    for k, time in ipairs({ 1.3, 1.9, 2.7 }) do                     -- three layers of bright stars, twinkling out of step
        local tw = SkyLayer(frame, "twinkle.tga", 5, 512, (n * 0.53 + k * 0.29) % 1, lt[1], lt[2], lt[3], plain and 0.35 or 0.8)
        layers[#layers + 1] = tw
        Breathe(tw, 0.05, 1, time + (n % 4) * 0.2)
    end
    for i, alpha in ipairs({ 0.10, 0.06, 0.03 }) do ns:Outline(frame, i, a[1], a[2], a[3], plain and alpha * 0.6 or alpha, "BORDER") end   -- the edge's glow, inward
    ns:Outline(frame, -1, 0, 0, 0.01, 0.8, "BACKGROUND")
    local big = {}
    if not plain then
        local star = frame:CreateTexture(nil, "OVERLAY")                -- a small star at the top centre
        star:SetTexture(ns.MEDIA .. "sparkle.tga")
        star:SetSize(16, 16)
        star:SetPoint("CENTER", frame, "TOP", 0, 0)
        if star.SetBlendMode then star:SetBlendMode("ADD") end
        ns:Paint(star, "SetVertexColor", "@accent", 1)
        star.sui = true
        ns:SkyLoop(star, "Rotation", 10, function(r) r:SetDegrees(-360) end, false)    -- turning
        Breathe(star, 0.5, 1, 1.6)
        local cell = n % 6                                              -- one real constellation, a different one per window
        local c = frame:CreateTexture(nil, "BORDER", nil, 1)
        c:SetTexture(ns.MEDIA .. "constellations.tga")
        c:SetTexCoord((cell % 4) * 0.25, (cell % 4) * 0.25 + 0.25, math.floor(cell / 4) * 0.5, math.floor(cell / 4) * 0.5 + 0.5)
        c:SetPoint("TOPRIGHT", -10, -12)
        local o = frame:CreateTexture(nil, "BORDER", nil, 1)             -- an orbit swept across the bottom-right corner
        o:SetTexture(ns.MEDIA .. "orbit.tga")
        o:SetPoint("BOTTOMRIGHT", -1, 1)
        for _, t in ipairs({ c, o }) do if t.SetBlendMode then t:SetBlendMode("ADD") end; t.sui = true end
        ns:Paint(c, "SetVertexColor", "@accent", 0.55)
        ns:Paint(o, "SetVertexColor", "@accent", 0.45)
        Breathe(c, 0.35, 1, 2.4)                                     -- the constellation's stars glowing and fading
        Breathe(o, 0.4, 1, 3.6)                                      -- and the orbit with them
        ns:SkyMotes(frame, n)                                        -- motes of starlight drifting up
        big.c, big.o = c, o
        skyWindows[frame] = true                                     -- (a window a shooting star can cross)
        if not ns.shootingWatch and ns.Every then ns.shootingWatch = true; ns:Every(1, "Shooting stars", ShootingTick) end
    end
    local function Fit(_, w, h)
        w, h = tonumber(w), tonumber(h)
        if not w or not h or ns:IsSecret(w) or ns:IsSecret(h) or w <= 0 or h <= 0 then return end
        for _, t in ipairs(layers) do TileTo(t, w, h) end
        if big.c then
            local size = math.floor(math.min(110, h * 0.42, w * 0.3))
            big.c:SetSize(math.max(1, size), math.max(1, size)); big.c:SetShown(size >= 48)       -- (too small to read: left out)
            local o = math.floor(math.min(200, w * 0.5, h * 0.7))
            big.o:SetSize(math.max(1, o), math.max(1, o)); big.o:SetShown(size >= 48)
            ns.PlaceMotes(frame, w, size >= 48)
        end
    end
    local okW, w = pcall(frame.GetWidth, frame)
    local okH, h = pcall(frame.GetHeight, frame)
    Fit(nil, okW and w, okH and h)
    if frame.HookScript then pcall(frame.HookScript, frame, "OnSizeChanged", Fit) end
end

function ns:Dress(frame, plain)
    if type(frame) ~= "table" or frame.suiDressed or not frame.CreateTexture then return end
    frame.suiDressed = true
    if ns.After then ns:After(0, function() if ns.StarcutWindow then pcall(ns.StarcutWindow, frame) end end) end   -- (Starcut cuts its corners once it is dressed)
    if not plain and not frame.suiNoRound then pcall(ns.FadeIn, ns, frame) end       -- our windows only, never the game's
    if ns.style == "GLASS" then return DressGlass(frame, plain) end
    if ns.style == "CELESTIAL" then return DressCelestial(frame, plain) end
    local a = ns.theme.accent

    local grain = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    grain:SetPoint("TOPLEFT", 1, -1)
    grain:SetPoint("BOTTOMRIGHT", -1, 1)
    if not pcall(grain.SetTexture, grain, ns.MEDIA .. "panel.tga", "REPEAT", "REPEAT") then
        grain:SetTexture(ns.MEDIA .. "panel.tga")
    end
    if grain.SetHorizTile then grain:SetHorizTile(true); grain:SetVertTile(true) end
    local gt = ns.theme.grain
    grain:SetVertexColor(gt[1], gt[2], gt[3], gt[4] or 0.3)
    frame.suiGrain = grain
    grain.sui = true

    local light = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    light:SetPoint("TOPLEFT", 1, -1)
    light:SetPoint("TOPRIGHT", -1, -1)
    light:SetHeight(36)
    light:SetTexture(ns.FLAT)
    light.sui = true
    if light.SetGradient and CreateColor then
        local lt = ns.theme.light
        light:SetGradient("VERTICAL", CreateColor(lt[1], lt[2], lt[3], 0), CreateColor(lt[1], lt[2], lt[3], 0.10))
    else
        light:SetVertexColor(1, 1, 1, 0.04)
    end

    -- deepen toward the bottom, like dark glass
    local shade = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    shade:SetPoint("TOPLEFT", 1, -1)
    shade:SetPoint("BOTTOMRIGHT", -1, 1)
    shade:SetTexture(ns.FLAT)
    shade.sui = true
    if shade.SetGradient and CreateColor then
        shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.30), CreateColor(0, 0, 0, 0))
    else
        shade:SetVertexColor(0, 0, 0, 0.08)
    end

    local rim = ns.theme.rim
    ns:Outline(frame, -1, rim[1], rim[2], rim[3], 0.95, "BACKGROUND")      -- dark line just outside the rim
    if not plain then frame.suiCorners = ns:Corners(frame, frame, 20, 1) end   -- clean gold brackets in the corners
end

-- Dress the standard controls inside a Blizzard window (buttons, tabs, text boxes, insets), by
-- recognising the pieces each of Blizzard's templates is built from.
local BUTTON_PARTS = { "Left", "Middle", "Right", "Center" }
local TAB_PARTS = { "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive",
                    "LeftHighlight", "MiddleHighlight", "RightHighlight", "LeftDisabled", "MiddleDisabled", "RightDisabled",
                    "SquareBackground", "SquareBackgroundActive", "SquareBackgroundActiveGlow" }
local tabs = setmetatable({}, { __mode = "k" })     -- restyled panel tabs, so the selected one can be marked
local function IsTexture(o)
    return type(o) == "table" and o.GetObjectType and o:GetObjectType() == "Texture"
end
local function PaintControl(f, role, inset)
    if f.suiControl then return end
    f.suiControl = true
    inset = inset or 0
    local th = ns.theme
    local fill = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    fill:SetPoint("TOPLEFT", inset + 1, -inset - 1)
    fill:SetPoint("BOTTOMRIGHT", -inset - 1, inset + 1)
    fill:SetTexture(ns.FLAT)
    fill:SetVertexColor(ns:T(role, 1))
    f.suiFill = fill
    if role == "plate" then
        local lit = f:CreateTexture(nil, "BACKGROUND", nil, -7)
        lit:SetAllPoints(fill)
        lit:SetTexture(ns.FLAT)
        if lit.SetGradient and CreateColor then
            lit:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.35), CreateColor(th.light[1], th.light[2], th.light[3], 0.14))
        else
            lit:SetVertexColor(1, 1, 1, 0.04)
        end
    end
    ns:Outline(f, inset, th.border[1], th.border[2], th.border[3], 1, "BACKGROUND")
end

local function Alpha0(o)
    if type(o) == "table" and o.SetAlpha then pcall(o.SetAlpha, o, 0) end
end

-- Hide every Blizzard texture sitting directly on a frame (ours are tagged and left alone).
function ns:StripArt(frame, layers)
    if type(frame) ~= "table" or not frame.GetRegions then return end
    for _, r in ipairs({ frame:GetRegions() }) do
        if type(r) == "table" and not r.sui and r.GetObjectType and r:GetObjectType() == "Texture" then
            if not layers or layers[r:GetDrawLayer()] then r:SetAlpha(0) end
        end
    end
end

-- Close button: a small plate with an X; turns red under the mouse.
local function SkinClose(btn)
    if btn.suiControl then return end
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
        local t = btn[getter] and btn[getter](btn)
        if t then t:SetAlpha(0) end
    end
    local w = btn.GetWidth and btn:GetWidth() or 32
    local inset = (type(w) == "number" and w >= 28) and 7 or 3
    PaintControl(btn, "plate", inset)
    local x = btn:CreateFontString(nil, "OVERLAY")
    ns:Font(x, 11)
    x:SetPoint("CENTER", 0, 0)
    x:SetText("X")
    ns:Paint(x, "SetTextColor", "@btn")
    local hl = btn.GetHighlightTexture and btn:GetHighlightTexture()
    if hl then
        ns:ColorTex(hl, 0.90, 0.22, 0.18, 0.45)
        hl:ClearAllPoints()
        hl:SetPoint("TOPLEFT", inset + 1, -inset - 1)
        hl:SetPoint("BOTTOMRIGHT", -inset - 1, inset + 1)
    end
end

-- Scroll bar: slim dark trough, accent-colored thumb, arrows tinted to match. Handles both the
-- modern track-and-thumb bars and the older slider bars.
local function TintArrow(b)
    if type(b) ~= "table" then return end
    local c = ns.theme.btn
    local list = { b.Texture, b.Overlay }
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
        if b[getter] then list[#list + 1] = b[getter](b) end
    end
    for _, t in pairs(list) do
        if IsTexture(t) then
            if t.SetDesaturated then pcall(t.SetDesaturated, t, true) end
            t:SetVertexColor(c[1], c[2], c[3])
        end
    end
end

local function SkinScrollBar(sb)
    if sb.suiControl then return end
    sb.suiControl = true
    local a = ns.theme.accent
    if type(sb.Track) == "table" and sb.Track.CreateTexture then              -- modern bar
        for _, k in ipairs({ "Begin", "Middle", "End" }) do Alpha0(sb.Track[k]) end
        Alpha0(sb.Background)
        local trough = sb.Track:CreateTexture(nil, "BACKGROUND")
        trough:SetPoint("TOP", 0, 0)
        trough:SetPoint("BOTTOM", 0, 0)
        trough:SetWidth(4)
        trough:SetTexture(ns.FLAT)
        ns:Paint(trough, "SetVertexColor", "trough", 0.9)
        local thumb = sb.Track.Thumb
        if type(thumb) == "table" and thumb.CreateTexture then
            for _, k in ipairs({ "Begin", "Middle", "End" }) do Alpha0(thumb[k]) end
            local t = thumb:CreateTexture(nil, "ARTWORK")
            t:SetPoint("TOP", 0, -1)
            t:SetPoint("BOTTOM", 0, 1)
            t:SetWidth(6)
            t:SetTexture(ns.FLAT)
            ns:Paint(t, "SetVertexColor", "@accent", 0.85)
        end
        TintArrow(sb.Back); TintArrow(sb.Forward)
    end
    if sb.GetThumbTexture then                                                 -- older slider bar
        local t = sb:GetThumbTexture()
        if t then
            ns:ColorTex(t, a[1], a[2], a[3], 0.85)
            t:SetSize(8, 24)
        end
    end
    for _, k in ipairs({ "trackBG", "Top", "Bottom", "Middle", "ScrollBarTop", "ScrollBarBottom", "ScrollBarMiddle", "ThumbTexture" }) do
        if k ~= "ThumbTexture" and IsTexture(sb[k]) then sb[k]:SetAlpha(0) end
    end
    local name = sb.GetName and sb:GetName()
    if type(name) == "string" then
        for _, suffix in ipairs({ "Top", "Bottom", "Middle", "BG", "Track" }) do
            local t = _G[name .. suffix]
            if IsTexture(t) then t:SetAlpha(0) end
        end
        TintArrow(_G[name .. "ScrollUpButton"]); TintArrow(_G[name .. "ScrollDownButton"])
    end
    TintArrow(sb.ScrollUpButton); TintArrow(sb.ScrollDownButton)
end

-- Rows of scrolling lists are created as you scroll, so the lists are remembered and new rows
-- are dressed a couple of times a second: accent hover, a faint line under each row.
local lists = setmetatable({}, { __mode = "k" })
local function StyleRow(row)
    row.suiRow = true
    local a, th = ns.theme.accent, ns.theme
    local hl = row.GetHighlightTexture and row:GetHighlightTexture()
    if hl then ns:ColorTex(hl, a[1], a[2], a[3], 0.16) end
    if row.CreateTexture then
        local line = row:CreateTexture(nil, "BACKGROUND")
        line:SetHeight(1)
        line:SetPoint("BOTTOMLEFT", 2, 0)
        line:SetPoint("BOTTOMRIGHT", -2, 0)
        line:SetTexture(ns.FLAT)
        ns:Paint(line, "SetVertexColor", "@border", 0.22)
        line.sui = true
    end
    ns:AutoSkin(row, 3)
end
do
    -- A row is styled once and keeps its style when the list reuses it for other lines, so a list
    -- with as many rows as at its last look has nothing new: it is passed over without a walk.
    local rowCounts = setmetatable({}, { __mode = "k" })
    local function StyleList(target)
        if not target:IsVisible() then return end
        local count = target.GetNumChildren and target:GetNumChildren()
        if type(count) == "number" and rowCounts[target] == count then return end
        local n = 0
        for _, row in ipairs({ target:GetChildren() }) do
            if type(row) == "table" and not row.suiRow and not (row.IsForbidden and row:IsForbidden()) then
                StyleRow(row)
                n = n + 1
                if n > 60 then return end                   -- (the rest next time; the count is not noted yet)
            end
        end
        if type(count) == "number" then rowCounts[target] = count end
    end
    ns.StyleList = StyleList
    local f, acc = CreateFrame("Frame"), 0
    f:SetScript("OnUpdate", function(_, e)
        acc = acc + e
        if acc < 0.4 then return end
        acc = 0
        for target in pairs(lists) do pcall(StyleList, target) end
    end)
end

function ns:AutoSkin(root, depth, budget)
    depth, budget = depth or 0, budget or { n = 0 }
    if depth > 5 or type(root) ~= "table" or not root.GetChildren then return end
    for _, child in ipairs({ root:GetChildren() }) do
        budget.n = budget.n + 1
        if budget.n > 600 then return end
        if type(child) == "table" and child.GetObjectType and not (child.IsForbidden and child:IsForbidden()) then
            local kind = child:GetObjectType()
            local name = child.GetName and child:GetName()
            if type(child.ScrollTarget) == "table" then lists[child.ScrollTarget] = true end     -- a scrolling list
            local vertical = kind == "Slider" and not (child.GetOrientation and child:GetOrientation() == "HORIZONTAL")
            if vertical or (type(child.Track) == "table" and (child.Back or child.Forward)) then   -- (option sliders are left alone)
                SkinScrollBar(child)
            elseif (kind == "Button") and (root.CloseButton == child or (type(name) == "string" and name:find("CloseButton$"))) then
                SkinClose(child)
            elseif kind == "Button" or kind == "CheckButton" then
                if IsTexture(child.LeftActive) or IsTexture(child.LeftDisabled) then            -- a panel tab
                    for _, k in ipairs(TAB_PARTS) do if IsTexture(child[k]) then child[k]:SetAlpha(0) end end
                    PaintControl(child, "plate", 3)
                    tabs[child] = true
                elseif IsTexture(child.Left) and IsTexture(child.Right) then                     -- a standard push button
                    for _, k in ipairs(BUTTON_PARTS) do if IsTexture(child[k]) then child[k]:SetAlpha(0) end end
                    PaintControl(child, "plate", 0)
                    local hl = child.GetHighlightTexture and child:GetHighlightTexture()
                    if hl then ns:ColorTex(hl, ns.theme.accent[1], ns.theme.accent[2], ns.theme.accent[3], 0.18) end
                end
            elseif kind == "EditBox" then
                if IsTexture(child.Left) and IsTexture(child.Right) then                          -- a text box
                    for _, k in ipairs(BUTTON_PARTS) do if IsTexture(child[k]) then child[k]:SetAlpha(0) end end
                    PaintControl(child, "field", 0)
                end
            elseif type(child.NineSlice) == "table" and child.NineSlice.SetAlpha then            -- an inset or sub-panel
                child.NineSlice:SetAlpha(0)
                -- Never add a fill of our own here: the frame that carries the border is often an overlay
                -- lying on top of the content (world map, guild roster), and a fill would cover it.
                -- The panel's own background already sits on the right layer, so keep it and recolor it.
                if IsTexture(child.Bg) and not child.Bg.suiTinted then
                    child.Bg.suiTinted = true
                    if child.Bg.SetDesaturated then pcall(child.Bg.SetDesaturated, child.Bg, true) end
                    ns:Paint(child.Bg, "SetVertexColor", "inset", 1)
                end
                if child.CreateTexture and not child.suiInset then                           -- a thin rim only
                    child.suiInset = true
                    local th = ns.theme
                    ns:Outline(child, 0, th.border[1], th.border[2], th.border[3], 0.6, "BACKGROUND")
                end
            end
            ns:AutoSkin(child, depth + 1, budget)
        end
    end
end

function ns:ColorTex(tex, r, g, b, a)
    if not tex then return end
    if tex.SetColorTexture then tex:SetColorTexture(r, g, b, a or 1)
    else tex:SetTexture(ns.FLAT); tex:SetVertexColor(r, g, b, a or 1) end
end

-- Dark filled panel parented to `parent`, drawn behind it by default.
function ns:NewBackdrop(parent, bg, border, levelOffset, pad)
    pad = pad or 0
    local f = CreateFrame("Frame", nil, parent, ns.template)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", -pad, pad)
    f:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", pad, -pad)
    f:SetFrameLevel(math.max(0, parent:GetFrameLevel() + (levelOffset or -1)))
    f:EnableMouse(false)
    f:SetBackdrop(ns.BACKDROP)
    bg, border = bg or ns.theme.bg, border or ns.theme.border
    f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    f:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
    return f
end

-- Rim drawn on top of a button / bar: a colored line with a dark line outside it.
-- Black (the old flat-UI default) means "use the theme's bronze".
function ns:AddBorder(frame, r, g, b, a, offset)
    if frame.suiBorder then return frame.suiBorder end
    offset = offset or 1
    local th = ns.theme
    local themed = (r == nil) or (r == 0 and g == 0 and b == 0)       -- black means "the theme's rim", kept live

    local outer = CreateFrame("Frame", nil, frame, ns.template)
    outer:SetPoint("TOPLEFT", frame, "TOPLEFT", -offset - 1, offset + 1)
    outer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", offset + 1, -offset - 1)
    outer:SetFrameLevel(frame:GetFrameLevel() + 2)
    outer:EnableMouse(false)
    outer:SetBackdrop({ edgeFile = ns.FLAT, edgeSize = 1 })
    ns:Paint(outer, "SetBackdropBorderColor", "@rim", 0.95)

    local f = CreateFrame("Frame", nil, frame, ns.template)
    f:SetPoint("TOPLEFT", frame, "TOPLEFT", -offset, offset)
    f:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", offset, -offset)
    f:SetFrameLevel(frame:GetFrameLevel() + 2)
    f:EnableMouse(false)
    f:SetBackdrop({ edgeFile = ns.FLAT, edgeSize = 1 })
    if themed then ns:Paint(f, "SetBackdropBorderColor", "@border", a or 1) else f:SetBackdropBorderColor(r, g, b, a or 1) end
    f.outer = outer                                          -- (so both lines can be shown and hidden together)
    frame.suiBorder = f
    return f
end

-- Restyle a standard Blizzard window: remove ornate art, add a dark panel.
local KILL = { "NineSlice", "Bg", "TitleBg", "TopTileStreaks", "PortraitContainer" }
local function KillKeys(f, keys)
    for _, k in ipairs(keys) do
        local o = f[k]
        if type(o) == "table" and o.SetAlpha then pcall(o.SetAlpha, o, 0) end
    end
end

function ns:SkinWindow(frame, extraKill)
    if not frame or type(frame) ~= "table" or frame.suiWindow or not frame.GetFrameLevel then return end
    frame.suiWindow = true
    KillKeys(frame, KILL)
    if extraKill then KillKeys(frame, extraKill) end
    if type(frame.Inset) == "table" then KillKeys(frame.Inset, { "NineSlice", "Bg" }) end
    if type(frame.BorderFrame) == "table" then KillKeys(frame.BorderFrame, { "NineSlice", "Bg", "TitleBg" }) end
    pcall(ns.PaintPanel, ns, frame)
    pcall(ns.AutoSkin, ns, frame)
    local title = frame.TitleText or (type(frame.TitleContainer) == "table" and frame.TitleContainer.TitleText)
    if title and title.SetFont then pcall(ns.Font, ns, title, 14, true) end
end

-- Button: a bronze plate with a lit top edge; the rim turns gold under the mouse -----------
-- "template" (optional) adds one of the game's templates to it, for a button that must be a secure one;
-- such a button is given no click handler here, because the template brings its own.
function ns:CreateButton(parent, text, w, h, onClick, template, name)
    local th = ns.theme
    local b = CreateFrame("Button", name, parent, template and (template .. (ns.template and ("," .. ns.template) or "")) or ns.template)
    b:SetSize(w or 100, h or 24)
    b.suiW = w or 100
    b:SetBackdrop(ns.BACKDROP)
    ns:Paint(b, "SetBackdropColor", "plate", (ns.style == "GLASS") and 0.55 or 1)
    ns:Paint(b, "SetBackdropBorderColor", "@border", 1)
    local side = ns:CanRound() and 4 or 1
    b.wash = b:CreateTexture(nil, "ARTWORK")                   -- accent wash shown under the mouse
    b.wash:SetPoint("TOPLEFT", side, -1)
    b.wash:SetPoint("BOTTOMRIGHT", -side, 1)
    b.wash:SetTexture(ns.FLAT)
    ns:Paint(b.wash, "SetVertexColor", "@accent", (ns.style == "GLASS") and 0.26 or 0.10)
    b.wash:Hide()
    if ns:CanRound() then ns:Round(b) end
    local plate = b:CreateTexture(nil, "BORDER")
    plate:SetPoint("TOPLEFT", side, -1)
    plate:SetPoint("BOTTOMRIGHT", -side, 1)
    plate:SetTexture(ns.FLAT)
    if plate.SetGradient and CreateColor then
        local lt = th.light
        if ns.style == "GLASS" then
            plate:SetGradient("VERTICAL", CreateColor(lt[1], lt[2], lt[3], 0), CreateColor(lt[1], lt[2], lt[3], 0.12))
        elseif ns.style == "CELESTIAL" then              -- night: a little starlight pooling at the top
            local a = th.accent
            plate:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.25), CreateColor(a[1], a[2], a[3], 0.12))
        else
            plate:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.35), CreateColor(lt[1], lt[2], lt[3], 0.16))
        end
    else
        plate:SetVertexColor(1, 0.85, 0.55, 0.05)
    end
    b.text = b:CreateFontString(nil, "OVERLAY")
    ns:Font(b.text, 12)
    b.text:SetPoint("CENTER")
    -- A label longer than its button (a long word in another language) is drawn a little smaller,
    -- down to 9 points; one still too long is cut short with "...", and the whole of it is in the
    -- tooltip under the mouse.
    local fitting
    local function Fit()
        local t = b.text
        if fitting or not (t and t.GetStringWidth and t.SetWidth) or rawget(t, "suiFamily") then return end
        fitting = true
        local okW, bw = pcall(b.GetWidth, b)
        local room = ((okW and type(bw) == "number" and bw > 0) and bw or b.suiW or 100) - 8
        if room > 0 then
            pcall(t.SetWidth, t, 0)
            local e = fonts[t]
            local base, face = (e and e[1]) or 12, rawget(t, "suiFixedFont") or ((e and e[2]) and ns.TITLEFONT or ns.FONT)
            local size = base
            local function Wide()
                local ok, sw = pcall(t.GetStringWidth, t)
                return ok and type(sw) == "number" and sw > room
            end
            pcall(t.SetFont, t, face, size * (ns.fontScale or 1), ns.FONTFLAGS)
            while size > 9 and Wide() do
                size = size - 1
                pcall(t.SetFont, t, face, size * (ns.fontScale or 1), ns.FONTFLAGS)
            end
            if Wide() then pcall(t.SetWidth, t, room) end
        end
        fitting = nil
    end
    b.text.suiFit = Fit
    b.text:SetText(ns:Tr(text) or "")
    hooksecurefunc(b.text, "SetText", Fit)
    b:HookScript("OnSizeChanged", Fit)
    Fit()
    ns:Paint(b.text, "SetTextColor", "@btn")
    b:SetScript("OnEnter", function(self)
        ns:Paint(self, "SetBackdropBorderColor", "@accent", 1)
        self.text:SetTextColor(1, 1, 1)
        self.wash:Show()
        local tip = self.suiTip or (type(text) == "string" and ns.BUTTON_TIPS[text])
        local cut = self.text.IsTruncated and ns.Yes(self.text:IsTruncated())
        if tip or cut then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            local own = (cut or (text or "") == "") and (self.text:GetText() or "")      -- (a label set later, or cut short)
            GameTooltip:AddLine(ns:AccentHex() .. (own or ns:Tr(text or "")) .. "|r")
            if tip then GameTooltip:AddLine(type(tip) == "function" and tip() or ns:Tr(tip), 1, 1, 1, true) end
            GameTooltip:Show()
            self.suiTipShown = true
        end
    end)
    b:SetScript("OnLeave", function(self)
        ns:Paint(self, "SetBackdropBorderColor", "@border", 1)
        local c = self.suiTextColor                         -- (a label in a color of its own, such as a class color, keeps it)
        if type(c) == "table" then self.text:SetTextColor(c[1], c[2], c[3]) else ns:Paint(self.text, "SetTextColor", "@btn") end
        self.wash:Hide()
        if self.suiTipShown then self.suiTipShown = nil; GameTooltip:Hide() end
    end)
    if onClick then b:SetScript("OnClick", onClick) end
    b:SetScript("PostClick", function() ns.UISound("IG_MAINMENU_OPTION") end)    -- (the game's own click, whatever OnClick becomes)
    ns:IndexOption(text, b)
    return b
end
-- The tooltip a button shows by its label, unless it was given one of its own (ns:ButtonTip).
ns.BUTTON_TIPS = {
    ["Turn these on"] = "Switch on the features suggested for your class. Some take effect after a reload.",
    ["Preview"] = "Show sample unit, party and raid frames so you can see your changes without a group.",
    ["Move panels"] = "Unlock every panel so you can drag it where you want. Right-click a panel for its size; click again to lock.",
    ["Show sample frames"] = "Show sample unit, party and raid frames so you can see your changes without a group.",
    ["Reset positions"] = "Put every panel back where it came. Asks first.",
    ["Role layout"] = "Place the frames the way that suits your role: tank, healer or damage.",
    ["Use the layout for my role"] = "Place the frames the way that suits your role: tank, healer or damage.",
    ["Share layout"] = "Export your layout as text to share, import someone else's, or keep one layout per talent set.",
    ["Layout gallery"] = "Ready-made layouts to try. Your own is backed up first.",
    ["Info bar pieces"] = "Choose which pieces the info bar shows: gold, durability, bags, time and more.",
    ["Reset window positions"] = "Put the add-on's list windows back in the middle of the screen. Asks first.",
    ["Create copy of current"] = "A new profile that starts as a copy of the one you are using.",
    ["Export current profile"] = "Your current profile as a line of text you can share or keep.",
    ["Preview a shared string"] = "See what a shared profile, layout or theme would change before you take it.",
    ["Send my layout"] = "Send your layout to the player you are targeting or whispering with.",
    ["Send my profile"] = "Send your profile to the player you are targeting or whispering with.",
    ["Send my theme"] = "Send your theme to the player you are targeting or whispering with.",
    ["Run setup again"] = "The first-login setup again: role, theme, layout and language.",
    ["Report a problem"] = "A short report to copy into a bug report: version, client, errors and the switches you changed.",
    ["Reload UI"] = "Reload the interface: needed after a few changes, such as switching theme family.",
    ["Language"] = "Show the add-on in another language. Takes effect after a reload.",
    ["Use my current theme"] = "Take the colors of the theme you are wearing as the start of your own.",
    ["Color wheel..."] = "Pick a color for this class on the game's color wheel.",
    ["Reset this class"] = "This class's color back to how it came.",
    ["Reset all"] = "Every class color back to how it came. Asks first.",
    ["Edit my own bag rules"] = "Your own rules for which bag each item goes to.",
    ["Edit my own mail rules"] = "Your own rules for which items go to which character.",
    ["Fill from my action bars"] = "Put the spells on your action bars into the key list.",
    ["Fill from action bars"] = "Put the spells on your action bars into the key list.",
    ["Apply bindings"] = "Set the keys in this list as your key bindings.",
    ["Apply to the bar"] = "Use these settings on the bar you chose.",
    ["Edit the route"] = "Change the steps of the guide you are following.",
    ["Your guides"] = "The guides you have written or pasted, to follow or edit.",
    ["Write or paste a guide"] = "Write a guide of your own, or paste one someone shared.",
    ["Auras hidden on every frame"] = "The buffs and debuffs you chose never to show on frames and nameplates.",
    ["Try the voice"] = "Hear the voice your spoken alerts will use.",
    ["Back to how it came"] = "This one back to how the add-on came.",
    ["Learn all"] = "Learn every spell this trainer can teach you that you can afford.",
    ["Copy"] = "Copy this chat into a box you can select text from.",
    ["Undo"] = "Undo the last change.",
    ["Options"] = "Open the options.",
    ["Guides"] = "Your guides, to follow or edit.",
    ["Save and follow"] = "Save this guide and start following it.",
    ["Skill-ups"] = "Recipes that still give skill points, best first, with what each needs.",
}
-- A small button as wide as its label needs (at least min): "Copy" in Russian is a long word.
function ns:SizeToLabel(b, min)
    if not (b and b.text and b.text.GetStringWidth) then return b end
    local ok, sw = pcall(b.text.GetStringWidth, b.text)
    if ok and type(sw) == "number" and not ns:IsSecret(sw) then b:SetWidth(math.max(min or 40, math.ceil(sw) + 14)) end
    return b
end
-- A line of help when the mouse is over one of our buttons.
function ns:ButtonTip(b, tip)
    if type(b) == "table" then b.suiTip = tip end
    return b
end

-- Flat checkbox -----------------------------------------------------------------
-- A click handler that asks first: the first click turns the button red ("Click to confirm") for four
-- seconds, a second click in that time does it. For anything that deletes or resets.
function ns:ConfirmClick(fn)
    return function(self, ...)
        if self.suiArmed then
            self.suiArmed = false
            if self.text and self.suiLabel then self.text:SetText(self.suiLabel) end
            return fn(self, ...)
        end
        self.suiArmed = true
        self.suiLabel = self.suiLabel or (self.text and self.text:GetText())
        if self.text then self.text:SetText(ns:SignalHex("bad") .. ns:Tr("Click to confirm") .. "|r") end
        ns:After(4, function()
            if self.suiArmed then
                self.suiArmed = false
                if self.text and self.suiLabel then self.text:SetText(self.suiLabel) end
            end
        end)
    end
end
-- The game's own interface sounds, by name (quietly nothing on a client without them).
function ns.UISound(kit)
    if PlaySound and SOUNDKIT and SOUNDKIT[kit] then pcall(PlaySound, SOUNDKIT[kit]) end
end
function ns:CreateCheckbox(parent, label, checked, onChange)
    local th = ns.theme
    -- A switch: a small track with a knob that sits left (off, gray) or right (on, in the accent
    -- color). Glass themes with rounded corners get a pill and a round knob; the rest are square.
    local c = CreateFrame("Button", nil, parent)
    c:SetSize(260, 22)
    local round = ns:CanRound()
    c.box = CreateFrame("Frame", nil, c, (not round) and ns.template or nil)
    c.box:SetSize(28, 14)
    c.box:SetPoint("LEFT", 0, 0)
    if round then
        c.fill = c.box:CreateTexture(nil, "BACKGROUND")
        c.fill:SetAllPoints()
        c.fill:SetTexture(ns.MEDIA .. "pill.tga")
        c.edge = c.box:CreateTexture(nil, "BORDER")
        c.edge:SetAllPoints()
        c.edge:SetTexture(ns.MEDIA .. "pill_edge.tga")
    else
        c.box:SetBackdrop(ns.BACKDROP)
    end
    c.tick = c.box:CreateTexture(nil, "OVERLAY")              -- the knob
    c.tick:SetSize(10, 10)
    c.tick:SetTexture(round and (ns.MEDIA .. "dot.tga") or ns.FLAT)
    c.label = c:CreateFontString(nil, "OVERLAY")
    ns:Font(c.label, 12)
    c.label:SetPoint("LEFT", c.box, "RIGHT", 8, 0)
    c.label:SetJustifyH("LEFT")
    if c.label.SetWordWrap then c.label:SetWordWrap(false) end
    c.label:SetText(ns:Tr(label))
    -- The label keeps to the switch's own width: one too long in another language is cut short with
    -- "..." (and shown whole under the mouse) instead of running into whatever sits beside it.
    local function FitLabel(_, w)
        w = tonumber(w)
        if w and not ns:IsSecret(w) and w > 60 then c.label:SetWidth(w - 36) end
    end
    c:HookScript("OnSizeChanged", FitLabel)
    if hooksecurefunc then                                   -- (and at once when it is given a width, before it is first drawn)
        hooksecurefunc(c, "SetWidth", function(self, w) FitLabel(self, w) end)
        hooksecurefunc(c, "SetSize", function(self, w) FitLabel(self, w) end)
    end
    FitLabel(c, 260)
    local function Draw(self, hover)
        local on = self.checked
        local rim = (on or hover) and "@accent" or "@border"
        if self.fill then
            ns:Paint(self.fill, "SetVertexColor", on and "@accent" or "field", on and 0.32 or 1)
            ns:Paint(self.edge, "SetVertexColor", rim, 1)
        else
            ns:Paint(self.box, "SetBackdropColor", on and "@accent" or "field", on and 0.32 or 1)
            ns:Paint(self.box, "SetBackdropBorderColor", rim, 1)
        end
        ns:Paint(self.tick, "SetVertexColor", on and "@accent" or "faint", 1)
        ns:Paint(self.label, "SetTextColor", on and "text" or "dim")
        self.tick:ClearAllPoints()
        if on then self.tick:SetPoint("RIGHT", self.box, "RIGHT", -2, 0) else self.tick:SetPoint("LEFT", self.box, "LEFT", 2, 0) end
    end
    function c:SetChecked(v)
        self.checked = v and true or false
        Draw(self, false)
    end
    c:SetChecked(checked)
    c:SetScript("OnClick", function(self)
        self:SetChecked(not self.checked)
        ns.UISound(self.checked and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF")
        if onChange then onChange(self.checked) end
    end)
    c:SetScript("OnEnter", function(self)
        Draw(self, true)
        if self.label.IsTruncated and ns.Yes(self.label:IsTruncated()) then        -- (a tooltip of its own, hooked on later, replaces this)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.label:GetText() or "", 1, 1, 1, 1, true)
            GameTooltip:Show()
            self.suiTipShown = true
        end
    end)
    c:SetScript("OnLeave", function(self)
        Draw(self, false)
        if self.suiTipShown then self.suiTipShown = nil; GameTooltip:Hide() end
    end)
    ns:IndexOption(label, c)
    return c
end

-- Scroll frame with a thin indicator ---------------------------------------------
function ns:CreateScroll(parent, width)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(width or 200, 10)
    sf:SetScrollChild(content)
    sf:EnableMouseWheel(true)

    local thumb = sf:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(ns.FLAT)
    ns:Paint(thumb, "SetVertexColor", "@accent", 0.6)
    thumb:SetWidth(3)

    local function UpdateThumb()
        local viewH, contentH = sf:GetHeight(), content:GetHeight()
        if not viewH or viewH <= 0 or contentH <= viewH then thumb:Hide() return end
        local range = sf:GetVerticalScrollRange() or 0
        local cur = sf:GetVerticalScroll() or 0
        local h = math.max(24, viewH * viewH / contentH)
        local off = (range > 0) and (cur / range) * (viewH - h) or 0
        thumb:SetHeight(h)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 0, -off)
        thumb:Show()
    end
    sf:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.max(0, math.min(range, (self:GetVerticalScroll() or 0) - delta * 42)))
    end)
    sf:SetScript("OnVerticalScroll", UpdateThumb)
    sf:SetScript("OnScrollRangeChanged", UpdateThumb)
    function sf:SetContentHeight(h)
        content:SetHeight(math.max(h, 10))
        UpdateThumb()
    end
    return sf, content
end

-- Movable, scalable panels (/fgui move) ----------------------------------------------
ns.movables = {}
ns.moving = false

local function ValidPos(pos)
    return type(pos) == "table" and type(pos[1]) == "string" and type(pos[2]) == "string"
       and type(pos[3]) == "number" and type(pos[4]) == "number"
end

local function ClampScale(v)
    v = tonumber(v)
    if not v then return nil end
    return math.max(0.5, math.min(2, v))
end

-- Undo ---------------------------------------------------------------------------------------------------------
-- Every change to where a panel sits or how big it is (a drag, a nudge, Center, Reset, a scale
-- slider, a role layout) first notes how things were. Undo puts the most recent change back. The
-- notes are kept for the session, thirty deep.
--   * a run of nudges on one panel, or one drag of a scale slider, counts as a single step
--   * a step may cover several panels at once (a role layout moves many)
ns.undoStack = {}
local function CopyPos(pos) return ValidPos(pos) and { pos[1], pos[2], pos[3], pos[4] } or false end
function ns:PushUndo(keys, what, label)
    if type(keys) ~= "table" then keys = { keys } end
    local top, now = ns.undoStack[#ns.undoStack], GetTime()
    if what and top and top.what == what and top.first == keys[1] and now - top.at < 2 then
        top.at = now                                         -- still the same nudge-nudge-nudge, or the same slider drag
        return top
    end
    local step = { what = what, label = label, at = now, first = keys[1], panels = {} }
    for _, key in ipairs(keys) do
        step.panels[#step.panels + 1] = {
            key = key, pos = CopyPos(ns.db.pos[key]), scale = ns.db.scale[key] or false,
            show = (type(ns.db.panelShow) == "table" and ns.db.panelShow[key]) or false,
        }
    end
    ns.undoStack[#ns.undoStack + 1] = step
    while #ns.undoStack > 30 do table.remove(ns.undoStack, 1) end
    if ns.RefreshMoveBar then ns:RefreshMoveBar() end
    return step
end
local FindMovable                                            -- (defined further down)
function ns:Undo()
    local step = ns.undoStack[#ns.undoStack]
    if not step then ns:Print("Nothing to undo."); return false end
    if InCombatLockdown() then ns:Print("Panels can't be moved in combat."); return false end
    ns.undoStack[#ns.undoStack] = nil
    for _, was in ipairs(step.panels) do
        ns.db.pos[was.key] = was.pos or nil
        ns.db.scale[was.key] = was.scale or nil
        if type(ns.db.panelShow) ~= "table" then ns.db.panelShow = {} end
        ns.db.panelShow[was.key] = was.show or nil
        local m = FindMovable(was.key)
        if m then
            m.frame:SetScale(ClampScale(was.scale) or 1)
            if was.pos then
                m.frame:ClearAllPoints()
                m.frame:SetPoint(was.pos[1], UIParent, was.pos[2], was.pos[3], was.pos[4])
                if m.onMoved then pcall(m.onMoved) end
            elseif m.onReset then
                pcall(m.onReset)                             -- it had never been moved: back to the game's own place
            elseif m.home then
                m.frame:ClearAllPoints()
                m.frame:SetPoint(m.home[1], UIParent, m.home[2], m.home[3], m.home[4])
            end
        end
    end
    ns:PanelShowTick()
    if ns.RefreshMoveBar then ns:RefreshMoveBar() end
    if ns.RefreshPanelMenu then ns:RefreshPanelMenu() end
    ns:Print("Undone: %s.", ns:Tr(tostring(step.label or "the last change")))
    return true
end

-- Snapping to other panels ---------------------------------------------------------------------------------
-- rect and each of others: { left, right, top, bottom } in screen units. Returns how far to shift
-- rect, across and up, so that one of its edges meets an edge of another panel: its left against
-- their left or right, its top against their top or bottom, and so on. Only the nearest edge on
-- each axis counts, and only within `reach`; a panel has to overlap or nearly overlap the other on
-- the opposite axis, so that things on far sides of the screen do not pull on each other.
function ns.SnapToPanels(rect, others, reach)
    reach = reach or 10
    local bestX, bestY
    local function near(a1, a2, b1, b2) return a1 <= b2 + 40 and b1 <= a2 + 40 end
    for _, o in ipairs(others) do
        if near(rect[4], rect[3], o[4], o[3]) then           -- level with it: line up left and right edges
            for _, mine in ipairs({ rect[1], rect[2] }) do
                for _, theirs in ipairs({ o[1], o[2] }) do
                    local d = theirs - mine
                    if math.abs(d) <= reach and (not bestX or math.abs(d) < math.abs(bestX)) then bestX = d end
                end
            end
        end
        if near(rect[1], rect[2], o[1], o[2]) then           -- above or below it: line up top and bottom edges
            for _, mine in ipairs({ rect[3], rect[4] }) do
                for _, theirs in ipairs({ o[3], o[4] }) do
                    local d = theirs - mine
                    if math.abs(d) <= reach and (not bestY or math.abs(d) < math.abs(bestY)) then bestY = d end
                end
            end
        end
    end
    return bestX or 0, bestY or 0
end
-- A frame's edges in screen units, or nil if it has no place yet.
local function ScreenRect(frame)
    local l, b, w, h = frame:GetLeft(), frame:GetBottom(), frame:GetWidth(), frame:GetHeight()
    local fs, us = frame:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if type(l) ~= "number" or type(b) ~= "number" or type(w) ~= "number" or type(h) ~= "number" or type(fs) ~= "number" or type(us) ~= "number" or us <= 0 then return nil end
    local k = fs / us
    return { l * k, (l + w) * k, (b + h) * k, b * k }
end

function ns:RegisterMovable(frame, key, label)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    local home                                           -- where the panel sits when it has never been moved
    do
        local ok, point, _, relPoint, x, y = pcall(frame.GetPoint, frame, 1)
        if ok and type(point) == "string" and type(x) == "number" then home = { point, relPoint or point, x, y } end
    end
    local pos = ns.db.pos[key]
    if ValidPos(pos) then
        frame:ClearAllPoints()
        frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    end
    local scale = ClampScale(ns.db.scale[key])
    if scale then frame:SetScale(scale) end

    local entry = { frame = frame, key = key, label = label or key, home = home, feature = ns.startingModule }
    local ov = CreateFrame("Frame", nil, UIParent, ns.template)
    ov:SetAllPoints(frame)
    ov:SetFrameStrata("DIALOG")
    ov:SetBackdrop(ns.BACKDROP)
    ov:SetBackdropColor(0.75, 0.55, 0.15, 0.45)
    ov:SetBackdropBorderColor(1, 0.82, 0.4, 1)
    ov:EnableMouse(true)
    ov:RegisterForDrag("LeftButton")
    local t = ov:CreateFontString(nil, "OVERLAY")
    ns:Font(t, 12)
    t:SetPoint("CENTER")
    t:SetText(ns:Tr(label or key))                            -- (the panel's name in your language)
    ov:SetScript("OnDragStart", function()
        ns:PushUndo(key, nil, format(ns:Tr("moved %s"), ns:Tr(tostring(label or key))))
        frame:StartMoving()
    end)
    ov:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        -- snap to an 8-unit grid, and to the screen's centre lines when close (hold Shift to place freely)
        local cx, cy = frame:GetCenter()
        local ux, uy = UIParent:GetCenter()
        if not IsShiftKeyDown() and type(cx) == "number" and type(ux) == "number" then
            local fs, us = frame:GetEffectiveScale(), UIParent:GetEffectiveScale()
            local dx, dy = (cx * fs - ux * us) / us, (cy * fs - uy * us) / us       -- offset from centre, in screen units
            local function snap(v)
                if math.abs(v) < 12 then return 0 end
                return math.floor(v / 8 + 0.5) * 8
            end
            local scale = frame:GetScale()
            if type(scale) ~= "number" or scale <= 0 then scale = 1 end
            local sx, sy = snap(dx), snap(dy)
            -- then to the edges of other panels, when one is close (this wins over the grid)
            if ns.db.snapPanels ~= false then
                local w, h = frame:GetWidth(), frame:GetHeight()
                if type(w) == "number" and type(h) == "number" then
                    local hw, hh = w * fs / us / 2, h * fs / us / 2
                    local mine = { ux + sx - hw, ux + sx + hw, uy + sy + hh, uy + sy - hh }
                    local others = {}
                    for _, other in ipairs(ns.movables) do
                        if other.frame ~= frame and not other.ruleHidden then
                            local okS, shown = pcall(other.frame.IsShown, other.frame)
                            local r = okS and shown and ScreenRect(other.frame)
                            if r then others[#others + 1] = r end
                        end
                    end
                    local ax, ay = ns.SnapToPanels(mine, others, 10)
                    sx, sy = sx + ax, sy + ay
                end
            end
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", sx / scale, sy / scale)
        end
        local point, _, relPoint, x, y = frame:GetPoint()
        ns.db.pos[key] = { point, relPoint, x, y }
        if entry.onMoved then pcall(entry.onMoved) end      -- (action bars follow their handle)
    end)
    ov:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then ns:OpenPanelMenu(key) end      -- this panel's own settings
    end)
    ov:Hide()
    entry.overlay = ov
    table.insert(ns.movables, entry)
    return entry
end

-- "BoE" for an item in a bag that binds when equipped and is not bound yet (so it can still be sold
-- or traded). info is what the game says about that bag slot. Anything unknown or hidden: no tag.
function ns:BindTag(info)
    if not ns.db.bagBoE or type(info) ~= "table" then return "" end
    local link, bound = info.hyperlink, info.isBound
    if type(link) ~= "string" or ns:IsSecret(link) or ns:IsSecret(bound) or bound then return "" end
    local ok, bindType = pcall(function() return (select(14, ns:GetItemInfo(link))) end)
    if ok and not ns:IsSecret(bindType) and bindType == 2 then return "BoE" end
    return ""
end

-- Finding a setting --------------------------------------------------------------------------------------------
-- While the options window is being built, every labelled control notes itself here with the tab it
-- is on. ns:SearchOptions then finds settings on any tab by a word from their label (or, for the
-- switches on the Features tab, from their description).
ns.optionIndex = {}
function ns:IndexOption(label, frame, words)
    if not ns.indexingTab or type(label) ~= "string" or #label < 3 then return end
    ns.optionIndex[#ns.optionIndex + 1] = { tab = ns.indexingTab, label = label, frame = frame, words = words }
end
function ns:SearchOptions(query, limit)
    local out = {}
    if type(query) ~= "string" then return out end
    query = strlower((query:gsub("^%s+", ""):gsub("%s+$", "")))
    if #query < 2 then return out end
    local first, rest, seen = {}, {}, {}
    for _, entry in ipairs(ns.optionIndex) do
        local shown = ns:Tr(entry.label)
        local text = strlower(shown)
        local id = entry.tab .. "|" .. text
        if not seen[id] then
            local at = text:find(query, 1, true)
            if at then
                seen[id] = true
                local hit = { tab = entry.tab, label = shown, frame = entry.frame }
                if at == 1 then first[#first + 1] = hit else rest[#rest + 1] = hit end       -- labels that start with it come first
            elseif type(entry.frame) == "table" and type(entry.frame.words) == "string" and entry.frame.words:find(query, 1, true) then
                seen[id] = true
                rest[#rest + 1] = { tab = entry.tab, label = shown, frame = entry.frame }
            end
        end
    end
    for _, list in ipairs({ first, rest }) do
        for _, hit in ipairs(list) do
            if #out >= (limit or 10) then return out end
            out[#out + 1] = hit
        end
    end
    return out
end

-- The clock -------------------------------------------------------------------------------------------------
-- One function for every clock the add-on shows (info bar, minimap): 24-hour or 12-hour, and your
-- computer's time or the game server's.
function ns.FormatClock(hour, minute, twelve)
    hour, minute = math.floor(tonumber(hour) or 0) % 24, math.floor(tonumber(minute) or 0) % 60
    if not twelve then return format("%02d:%02d", hour, minute) end
    local h = hour % 12
    return format("%d:%02d%s", h == 0 and 12 or h, minute, hour >= 12 and "pm" or "am")
end
function ns:ClockText()
    local hour, minute
    if ns.db.clockServer and type(GetGameTime) == "function" then
        local ok, h, m = pcall(GetGameTime)
        if ok and type(h) == "number" and type(m) == "number" then hour, minute = h, m end
    end
    if not hour then
        local now = date("*t")
        hour, minute = now.hour, now.min
    end
    return ns.FormatClock(hour, minute, ns.db.clock12)
end

-- Safe mode ---------------------------------------------------------------------------------------------------
-- A way back for someone whose screen has gone wrong: the interface reloads with every feature left
-- unstarted. The choice is kept until it is undone, so it survives further reloads and relogging.
function ns:SetSafeMode(on)
    if not ns.root then return false end
    on = on and true or false
    if (ns.root.safeMode and true or false) == on then return false end
    ns.root.safeMode = on or nil
    return true
end
function ns:ShowSafeBanner()
    if ns.safeBanner then ns.safeBanner:Show(); return ns.safeBanner end
    local f = CreateFrame("Frame", "FantasyGlassUISafeMode", UIParent, ns.template)
    f:SetSize(560, 74)
    f:SetPoint("TOP", UIParent, "TOP", 0, -90)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop(ns.BACKDROP)
    ns:Paint(f, "SetBackdropColor", "@bg", 1)
    ns:Paint(f, "SetBackdropBorderColor", "@accent", 1)
    local title = ns:NewText(f, 14, "LEFT", true)
    title:SetPoint("TOPLEFT", 14, -10)
    title:SetText("Fantasy Glass UI: " .. ns:Tr("safe mode"))
    ns:Paint(title, "SetTextColor", "@accent")
    local body = f:CreateFontString(nil, "OVERLAY")
    ns:Font(body, 11)
    body:SetPoint("TOPLEFT", 14, -32)
    body:SetWidth(330)
    body:SetJustifyH("LEFT")
    body:SetWordWrap(true)
    body:SetText(ns:Tr("Every feature is off. Switch off whatever was causing trouble in the options, then leave safe mode."))
    ns:Paint(body, "SetTextColor", "text")
    local leave = ns:CreateButton(f, "Leave safe mode", 130, 24, function()
        if ns:SetSafeMode(false) then ReloadUI() end
    end)
    leave:SetPoint("BOTTOMRIGHT", -12, 12)
    ns:ButtonTip(leave, "Turn your features back on and reload.")
    local options = ns:CreateButton(f, "Options", 70, 24, function() ns:ToggleConfig() end)
    options:SetPoint("RIGHT", leave, "LEFT", -6, 0)
    ns.safeBanner = f
    return f
end

-- A scrolling area ------------------------------------------------------------------------------------------
-- For a page or a picker that holds more than fits. Returns the area (place it like any frame) and
-- the sheet inside it (build on it exactly as on a page). Roll the mouse wheel to scroll; a thin
-- bar at the right shows where you are, and is there only when there is something to scroll to.
--   area:SetContentHeight(h)   how tall the sheet's contents are
--   area:ScrollTo(y)           put that distance from the top of the sheet at the top of the area
--   area:ScrollToShow(top, h)  scroll just far enough that a piece at `top`, `h` tall, is in view
function ns:ScrollArea(parent, width, height)
    local area = CreateFrame("ScrollFrame", nil, parent)
    if width and height then area:SetSize(width, height) end
    local sheet = CreateFrame("Frame", nil, area)
    sheet:SetSize(width or 100, height or 100)
    area:SetScrollChild(sheet)

    local track = parent:CreateTexture(nil, "ARTWORK")
    track:SetTexture(ns.FLAT)
    track:SetWidth(3)
    track:SetPoint("TOPLEFT", area, "TOPRIGHT", 5, 0)
    track:SetPoint("BOTTOMLEFT", area, "BOTTOMRIGHT", 5, 0)
    ns:Paint(track, "SetVertexColor", "trough", 0.9)
    local thumb = parent:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(ns.FLAT)
    thumb:SetWidth(3)
    ns:Paint(thumb, "SetVertexColor", "@accent", 0.9)

    local offset, content = 0, 0
    local band                                                -- { top, height }: only this slice of the sheet is reachable
    local function View()
        local h = area:GetHeight()
        return (type(h) == "number" and h > 0) and h or (height or 100)
    end
    local function Apply()
        local view = View()
        local least = band and band.top or 0
        local total = band and (band.top + band.height) or content
        local most = math.max(least, total - view)
        offset = math.max(least, math.min(most, offset))
        area:SetVerticalScroll(offset)
        if most <= least then
            track:Hide(); thumb:Hide()
        else
            local size = math.max(16, view * view / math.max(1, total - least))
            thumb:SetHeight(size)
            thumb:ClearAllPoints()
            thumb:SetPoint("TOPLEFT", area, "TOPRIGHT", 5, -((offset - least) / (most - least)) * (view - size))
            track:Show(); thumb:Show()
        end
        area.offset, area.most, area.least = offset, most, least
    end
    area:EnableMouseWheel(true)
    area:SetScript("OnMouseWheel", function(_, delta) offset = offset - (tonumber(delta) or 0) * 42; Apply() end)
    area:HookScript("OnShow", Apply)
    area:HookScript("OnSizeChanged", function(_, w)
        if type(w) == "number" and w > 0 then sheet:SetWidth(w) end
        Apply()
    end)
    function area:SetContentHeight(h)
        content = tonumber(h) or 0
        sheet:SetHeight(math.max(1, content))
        Apply()
    end
    function area:ScrollTo(y) offset = tonumber(y) or 0; Apply() end
    function area:ScrollToShow(top, h)
        local view = View()
        top, h = tonumber(top) or 0, tonumber(h) or 0
        if top < offset then offset = top elseif top + h > offset + view then offset = top + h - view end
        Apply()
    end
    function area:Scroll(delta) offset = offset + (tonumber(delta) or 0); Apply() end
    -- Show one slice of the sheet and nothing else: from `top` down, `height` tall (nil, nil: all of it).
    -- Make the area itself no taller than the slice, or what follows the slice shows under it.
    function area:SetBand(top, h)
        if top == nil then band = nil else band = { top = math.max(0, tonumber(top) or 0), height = math.max(1, tonumber(h) or 1) } end
        offset = band and band.top or 0
        area.band = band
        Apply()
    end
    sheet.area = area
    Apply()
    return area, sheet
end

-- Moving one of the game's own frames ---------------------------------------------------------------------
-- Action bars, the buff frame and the like belong to the game, and the game places them. Such a frame
-- is "adopted": it gets a handle of ours that simply sits on top of it. Nothing changes until the
-- handle is dragged in move mode. From then on the frame is pinned to its handle, and put back there
-- whenever the game places it again. "Reset" in the handle's right-click menu hands it back to the
-- game. These frames often can't be re-placed during combat, so a change the game makes mid-fight
-- is corrected as the fight ends.
--   note    shown in the handle's menu in place of a scale slider (these are sized elsewhere)
--   corner  true: pin the frame by the corner the game anchors it with, so a frame that grows and
--           shrinks (buffs coming and going) keeps that corner still. Otherwise it is pinned by its centre.
ns.adopted = {}
-- Holding a protected frame where you put it, through a fight.
--
-- The game re-lays its action bars whenever one of them changes: a stance or aura bar appearing, a pet
-- bar, a vehicle. Out of combat the add-on simply puts an adopted bar back. In combat it cannot: an
-- add-on may not move an action bar during a fight, so the bar sat in the game's default place until
-- the fight ended.
--
-- What can be done is to set, beforehand, the frame's "keep on screen" rule. Every frame has one, with
-- a margin on each side. With the margins chosen so that the kept-on-screen box is exactly the size
-- of the screen when the frame is in its assigned spot, that spot is the only place the game's own
-- layout engine will let the frame be - whoever tries to move it, and whenever.
function ns.PinInsets(left, right, top, bottom, screenW, screenH)
    return -left, screenW - right, screenH - top, -bottom
end
local function AdoptUnpin(info)
    if not info.pinned or InCombatLockdown() then return false end
    local frame, was = info.bar, info.clampWas or { clamped = false, 0, 0, 0, 0 }
    pcall(frame.SetClampRectInsets, frame, was[1] or 0, was[2] or 0, was[3] or 0, was[4] or 0)
    pcall(frame.SetClampedToScreen, frame, was.clamped and true or false)
    info.pinned, info.pinRect = nil, nil
    return true
end
local function AdoptPin(info)
    local frame = info.bar
    if InCombatLockdown() or ns.moving or not info.attached then return false end
    if not (frame.SetClampedToScreen and frame.SetClampRectInsets and frame.IsProtected and frame.GetLeft) then return false end
    local okP, protected = pcall(frame.IsProtected, frame)
    if not (okP and protected) then return false end          -- (anything else is put back the moment the game moves it)
    local function num(fn, obj)
        local ok, v = pcall(fn, obj)
        if ok and type(v) == "number" and not ns:IsSecret(v) then return v end
    end
    local left, right, top, bottom = num(frame.GetLeft, frame), num(frame.GetRight, frame), num(frame.GetTop, frame), num(frame.GetBottom, frame)
    local scale, ui = num(frame.GetEffectiveScale, frame), num(UIParent.GetEffectiveScale, UIParent)
    local w, h = num(UIParent.GetWidth, UIParent), num(UIParent.GetHeight, UIParent)
    if not (left and right and top and bottom and scale and ui and w and h) or scale <= 0 then return false end
    if not info.clampWas then                                -- how the game had it, for "Reset"
        local was = { clamped = false, 0, 0, 0, 0 }
        local okC, clamped = pcall(frame.IsClampedToScreen, frame)
        was.clamped = okC and clamped == true
        if frame.GetClampRectInsets then
            local ok, a, b, c, d = pcall(frame.GetClampRectInsets, frame)
            if ok and type(a) == "number" and type(b) == "number" and type(c) == "number" and type(d) == "number" then was[1], was[2], was[3], was[4] = a, b, c, d end
        end
        info.clampWas = was
    end
    local l, r, t, b = ns.PinInsets(left, right, top, bottom, w * ui / scale, h * ui / scale)
    if not (pcall(frame.SetClampRectInsets, frame, l, r, t, b) and pcall(frame.SetClampedToScreen, frame, true)) then return false end
    info.pinned = true
    info.pinRect = { left, bottom }
    return true
end
-- Did a pinned frame stay put? (Looked at a moment after the game has tried to move it in a fight.)
local function AdoptCheckPin(info)
    if not info.pinned or not info.pinRect then return end
    local frame = info.bar
    local okL, left = pcall(frame.GetLeft, frame)
    local okB, bottom = pcall(frame.GetBottom, frame)
    if not (okL and okB and type(left) == "number" and type(bottom) == "number") or ns:IsSecret(left) or ns:IsSecret(bottom) then return end
    if math.abs(left - info.pinRect[1]) > 2 or math.abs(bottom - info.pinRect[2]) > 2 then
        info.pinSlipped = (info.pinSlipped or 0) + 1
    else
        info.pinHeld = (info.pinHeld or 0) + 1
    end
end
-- For the self-check: each frame moved off its default place, and how it fared in fights.
function ns:AdoptedReport()
    local out = {}
    for _, info in ipairs(ns.adopted) do
        if info.attached then
            local line = info.key .. ": " .. (info.pinned and "held in place through fights" or "put back after a fight (not a frame the game locks, or it could not be measured)")
            if info.movedInCombat then
                line = line .. format("; the game moved it %d times during fights", info.movedInCombat)
                if info.pinned or info.pinHeld or info.pinSlipped then
                    line = line .. format(" - it stayed put %d times, slipped %d times", info.pinHeld or 0, info.pinSlipped or 0)
                end
            end
            out[#out + 1] = line
        end
    end
    return out
end
-- The game's Edit Mode frames (its bars, buff rows and others) have their own SetPoint and
-- ClearAllPoints, written in Lua, that note things about the frame as they move it. Called from an
-- add-on, those notes are left "touched by an add-on", and in a fight the game's own layout, reading
-- them, is refused when it moves or shows those frames ("Interface action failed"). Such frames also
-- keep the plain versions as SetPointBase and ClearAllPointsBase: the add-on moves them with those.
local function Raw(frame, name)
    local f = frame[name .. "Base"]
    if type(f) == "function" then return f end
    return frame[name]
end
ns.RawFrameCall = Raw
local function AdoptAttach(info)
    if not ns.db.pos[info.key] then return end
    if InCombatLockdown() then info.pending = true; return end
    info.pending = nil
    AdoptUnpin(info)                                         -- (measured and pinned afresh below)
    local frame, holder = info.bar, info.holder
    if not info.original then                                -- remember where the game had it, for "Reset"
        info.original = {}
        local count = frame.GetNumPoints and frame:GetNumPoints() or 0
        for i = 1, (type(count) == "number" and count or 0) do info.original[i] = { frame:GetPoint(i) } end
    end
    if not info.attached then                                -- first time: the handle stops following the frame
        local pos = ns.db.pos[info.key]
        holder:ClearAllPoints()
        holder:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    end
    local w, h, scale = frame:GetWidth(), frame:GetHeight(), frame:GetScale()
    if type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then
        if type(scale) ~= "number" or scale <= 0 then scale = 1 end
        holder:SetSize(w * scale, h * scale)
    end
    local pin = "CENTER"
    if info.corner and info.original[1] and type(info.original[1][1]) == "string" then pin = info.original[1][1] end
    info.busy = true
    Raw(frame, "ClearAllPoints")(frame)
    Raw(frame, "SetPoint")(frame, pin, holder, pin, 0, 0)
    info.busy = nil
    info.attached = true
    AdoptPin(info)
end
local function AdoptRelease(info)
    if not info.attached then return end
    if InCombatLockdown() then info.releasePending = true; return end
    AdoptUnpin(info)
    info.attached, info.releasePending = nil, nil
    local frame, holder = info.bar, info.holder
    info.busy = true
    Raw(frame, "ClearAllPoints")(frame)
    for _, p in ipairs(info.original or {}) do pcall(Raw(frame, "SetPoint"), frame, p[1], p[2], p[3], p[4], p[5]) end
    info.busy = nil
    holder:ClearAllPoints()
    holder:SetAllPoints(frame)                               -- the handle follows the frame again
end
local adoptWatcher
function ns:AdoptGameFrame(frame, key, label, note, corner)
    if type(frame) ~= "table" or not frame.SetPoint or not frame.GetCenter or not ns:Usable(frame) then return nil end
    for _, known in ipairs(ns.adopted) do if known.key == key then return known, known.entry end end
    local holder = CreateFrame("Frame", "FantasyGlassUIHandle_" .. key, UIParent)
    holder:SetSize(200, 40)
    holder:SetAllPoints(frame)
    local saved = ns.db.pos[key]
    local entry = ns:RegisterMovable(holder, key, label)
    if not saved then                                        -- registering must not pull the handle off an unmoved frame
        holder:ClearAllPoints()
        holder:SetAllPoints(frame)
    end
    local info = { key = key, bar = frame, holder = holder, entry = entry, corner = corner and true or false }
    entry.adopted = true                                     -- (its handle is ours, the frame is the game's)
    entry.noScale = note or "This belongs to the game, which sets its size."
    entry.onMoved = function() AdoptAttach(info) end
    entry.onReset = function() AdoptRelease(info) end
    if hooksecurefunc then
        pcall(hooksecurefunc, frame, "SetPoint", function()
            if not info.attached or info.busy then return end
            if InCombatLockdown() then
                info.pending = true
                info.movedInCombat = (info.movedInCombat or 0) + 1
                ns:After(0.3, function() pcall(AdoptCheckPin, info) end)
            else
                ns:After(0.05, function() AdoptAttach(info) end)
            end
        end)
    end
    ns.adopted[#ns.adopted + 1] = info
    info.Pin, info.Unpin = function() return AdoptPin(info) end, function() return AdoptUnpin(info) end
    if not adoptWatcher then
        adoptWatcher = CreateFrame("Frame")
        for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
            pcall(adoptWatcher.RegisterEvent, adoptWatcher, e)
        end
        adoptWatcher:SetScript("OnEvent", ns:Guard("Skin events", function(_, event)
            ns:After(event == "PLAYER_REGEN_ENABLED" and 0.1 or 1, function()
                for _, known in ipairs(ns.adopted) do
                    if known.releasePending then pcall(AdoptRelease, known)
                    elseif ns.db.pos[known.key] and (event ~= "PLAYER_REGEN_ENABLED" or known.pending) then pcall(AdoptAttach, known) end
                end
            end)
        end))
    end
    if saved then ns:After(1, function() pcall(AdoptAttach, info) end) end      -- a place saved earlier: take it up
    return info, entry
end

-- Panel settings (right-click a panel in move mode) ---------------------------------------------------
-- Scale, fine nudging, centring, back to where it started, and switching its feature off: the things
-- you want while arranging, without going back to the options window.
local PANEL_FEATURE = {                                  -- which feature switch a panel belongs to
    minimap = "minimap", infobar = "infobar", tracker = "questTracker", roleHUD = "roleHUD", raid = "raidFrames",
    playerCast = "playerCast", swing = "swingTimer", cooldowns = "cooldowns", alerts = "buffAlerts", totems = "totems",
    imbue = "imbueReminder", aggro = "aggroWarn", Buffs = "auraBars", Debuffs = "auraBars", xpBar = "xpBar",
    raidTools = "raidTools", lootRoll = "lootRoll", bags = "bagWindow", bank = "bankWindow", menu = "actionBars",
    meter = "damageMeter", combatAlert = "combatAlert", consumables = "consumeBar", cooldownPulse = "cooldownPulse", missingBuffs = "buffMissing", questGuide = "questGuide", lossOfControl = "locAlert", bossTimer = "bossTimer",
    openAll = "openAll", travel = "travelBar", flight = "flightTimer", talkingHead = "talkingHeadMove", buttonBag = "buttonBag", toasts = "toasts", brokers = "infobarPlugins", mirror = "mirrorBars",
    gameBuffs = "auraBars", gameDebuffs = "auraBars", combatTimer = "combatTimer",
}
local function PanelGroup(key)                           -- the four party frames are sized and switched as one
    if key:find("^ufParty") then return { "ufParty1", "ufParty2", "ufParty3", "ufParty4" }, "ufParty" end
    if key:find("^ufBoss") then return { "ufBoss1", "ufBoss2", "ufBoss3", "ufBoss4", "ufBoss5" }, "ufBoss" end
    if key:find("^ufArena") then return { "ufArena1", "ufArena2", "ufArena3", "ufArena4", "ufArena5" }, "ufArena" end
    return { key }, PANEL_FEATURE[key] or (key:find("^uf") and "unitFrames") or (key:find("^bar_") and "actionBars") or nil
end
FindMovable = function(key)
    for _, m in ipairs(ns.movables) do if m.key == key then return m end end
end
function ns:FindMovable(key) return FindMovable(key) end

-- The actions, usable without the menu (and by tests).
function ns:NudgePanel(key, dx, dy)
    local m = FindMovable(key)
    if not m or InCombatLockdown() then return false end
    local point, _, relPoint, x, y = m.frame:GetPoint(1)
    if type(point) ~= "string" or type(x) ~= "number" then return false end
    ns:PushUndo(key, "nudge", format(ns:Tr("nudged %s"), ns:Tr(tostring(m.label))))
    m.frame:ClearAllPoints()
    m.frame:SetPoint(point, UIParent, relPoint or point, x + dx, y + dy)
    ns.db.pos[key] = { point, relPoint or point, x + dx, y + dy }
    if m.onMoved then pcall(m.onMoved) end
    return true
end
function ns:CenterPanel(key)                             -- centered left to right, keeping its height on screen
    local m = FindMovable(key)
    if not m or InCombatLockdown() then return false end
    local _, cy = m.frame:GetCenter()
    local _, uy = UIParent:GetCenter()
    if type(cy) ~= "number" or type(uy) ~= "number" then return false end
    local fs, us = m.frame:GetEffectiveScale(), UIParent:GetEffectiveScale()
    local scale = m.frame:GetScale()
    if type(scale) ~= "number" or scale <= 0 then scale = 1 end
    local y = ((cy * fs - uy * us) / us) / scale
    ns:PushUndo(key, nil, format(ns:Tr("centered %s"), ns:Tr(tostring(m.label))))
    m.frame:ClearAllPoints()
    m.frame:SetPoint("CENTER", UIParent, "CENTER", 0, y)
    ns.db.pos[key] = { "CENTER", "CENTER", 0, y }
    if m.onMoved then pcall(m.onMoved) end
    return true
end
function ns:ResetPanel(key)                              -- back to where it sits by default, at normal size
    local m = FindMovable(key)
    if not m or InCombatLockdown() then return false end
    ns:PushUndo(key, nil, format(ns:Tr("reset %s"), ns:Tr(tostring(m.label))))
    ns.db.pos[key], ns.db.scale[key] = nil, nil
    if type(ns.db.panelShow) == "table" then ns.db.panelShow[key] = nil end      -- and back to showing always
    m.frame:SetScale(1)
    if m.onReset then
        pcall(m.onReset)                                     -- it knows how to go home itself
    elseif m.home then
        m.frame:ClearAllPoints()
        m.frame:SetPoint(m.home[1], UIParent, m.home[2], m.home[3], m.home[4])
    end
    return true
end

-- When a panel shows ---------------------------------------------------------------------------------------
-- Each panel can be set to show always (as it comes), only in combat, only out of combat, or only
-- while you have a target. The choice is in the panel's right-click menu in move mode.
--   * Where the game allows it the panel is really hidden, so it takes no clicks.
--   * A panel the game protects (the unit frames) cannot be hidden by an add-on during combat, so it
--     is made see-through instead. It is still there: clicking where it was still works.
--   * While you are moving panels, or previewing, everything shows.
-- A panel whose own feature has nothing to display stays as empty as it was; this only ever takes
-- away, never forces something onto the screen.
ns.showRules = { "ALWAYS", "COMBAT", "NOCOMBAT", "TARGET" }
ns.showRuleNames = { ALWAYS = "Show: always", COMBAT = "Show: only in combat", NOCOMBAT = "Show: only out of combat", TARGET = "Show: only with a target" }
function ns:PanelShowRule(key)
    local rule = type(ns.db.panelShow) == "table" and ns.db.panelShow[key]
    return ns.showRuleNames[rule] and rule or "ALWAYS"
end
function ns:SetPanelShow(keys, rule)
    if type(ns.db.panelShow) ~= "table" then ns.db.panelShow = {} end
    if not ns.showRuleNames[rule] then rule = "ALWAYS" end
    for _, key in ipairs(type(keys) == "table" and keys or { keys }) do
        ns.db.panelShow[key] = (rule ~= "ALWAYS") and rule or nil
    end
    ns:PanelShowTick()
end
local function RuleWants(rule, combat, target)
    if rule == "COMBAT" then return combat end
    if rule == "NOCOMBAT" then return not combat end
    if rule == "TARGET" then return target end
    return true
end
ns.RuleWants = RuleWants
function ns:PanelShowTick()
    local rules = ns.db and ns.db.panelShow
    if type(rules) ~= "table" then return end
    local arranging = ns.moving or ns.previewing
    local combat, target = false, false
    if not arranging and next(rules) then
        combat = InCombatLockdown() and true or false
        if not combat and UnitAffectingCombat then
            local ok, v = pcall(UnitAffectingCombat, "player")
            combat = ok and ns.Is(v, true)
        end
        local ok, v = pcall(UnitExists, "target")
        target = ok and (v == true or ns:IsSecret(v))        -- (if the game will not say, assume there is one)
    end
    for _, m in ipairs(ns.movables) do
        if not m.adopted then
            local rule = rules[m.key]
            local want = arranging or not rule or RuleWants(rule, combat, target)
            local f = m.frame
            if want then
                if m.ruleHidden == "hide" then
                    if not ns:Locked(f) then f:Show(); m.ruleHidden = nil end      -- (locked for this fight: as soon as it ends)
                elseif m.ruleHidden == "alpha" then
                    f:SetAlpha(1)
                    m.ruleHidden = nil
                end
            elseif not m.ruleHidden then
                local ok, protected = pcall(f.IsProtected, f)
                if ok and protected then
                    f:SetAlpha(0); m.ruleHidden = "alpha"
                else
                    f:Hide(); m.ruleHidden = "hide"
                end
            elseif m.ruleHidden == "alpha" then
                f:SetAlpha(0)                                -- (its own feature may have raised it again)
            else
                local ok, shown = pcall(f.IsShown, f)
                if ok and shown and not ns:Locked(f) then f:Hide() end      -- (likewise)
            end
        end
    end
end
ns:Every(0.2, "When panels show", function() ns:PanelShowTick() end)

local panelMenu
function ns:OpenPanelMenu(key)
    local m = FindMovable(key)
    if not m then return end
    local keys, feature = PanelGroup(key)
    if not panelMenu then
        local f = CreateFrame("Frame", "FantasyGlassUIPanelMenu", UIParent, ns.template)
        f:SetSize(236, 234)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetBackdrop(ns.BACKDROP)
        ns:Paint(f, "SetBackdropColor", "window", 0.98)
        ns:Paint(f, "SetBackdropBorderColor", "@accent", 1)
        ns:Dress(f, true)
        f:EnableMouse(true)
        f:SetClampedToScreen(true)
        tinsert(UISpecialFrames, "FantasyGlassUIPanelMenu")
        f.title = ns:NewText(f, 13, "LEFT", true)
        f.title:SetPoint("TOPLEFT", 12, -10)
        local close = ns:CreateButton(f, "X", 20, 20, function() f:Hide() end)
        close:SetPoint("TOPRIGHT", -6, -6)
        f.scale = ns:CreateSlider(f, "Scale", 0.6, 1.6, 0.05, 1, "%.2f", function(v)
            if f.keys then ns:SetPanelScale(f.keys, v) end
        end, 210)
        f.scale:SetPoint("TOPLEFT", 12, -36)
        local hint = ns:NewText(f, 10, "LEFT")
        hint:SetPoint("TOPLEFT", 12, -80)
        hint:SetText(ns:Tr("Nudge"))
        ns:Paint(hint, "SetTextColor", "faint")
        local prevArrow
        for _, d in ipairs({ { "<", -1, 0 }, { "^", 0, 1 }, { "v", 0, -1 }, { ">", 1, 0 } }) do
            local b = ns:CreateButton(f, d[1], 30, 22, function()
                local step = IsShiftKeyDown() and 10 or 1
                for _, k in ipairs(f.keys or {}) do ns:NudgePanel(k, d[2] * step, d[3] * step) end
            end)
            if prevArrow then b:SetPoint("LEFT", prevArrow, "RIGHT", 4, 0)
            else b:SetPoint("LEFT", hint, "RIGHT", 10, 0) end   -- (after the word, however long it is in your language)
            prevArrow = b
        end
        local center = ns:CreateButton(f, "Center", 102, 22, function()
            for _, k in ipairs(f.keys or {}) do ns:CenterPanel(k) end
        end)
        center:SetPoint("TOPLEFT", 12, -108)
        local reset = ns:CreateButton(f, "Reset", 102, 22, function()
            for _, k in ipairs(f.keys or {}) do ns:ResetPanel(k) end
            f.scale:SetValue(1)
        end)
        reset:SetPoint("LEFT", center, "RIGHT", 6, 0)
        ns:ButtonTip(center, "Center this panel left to right, keeping its height.")
        ns:ButtonTip(reset, "Put this panel back where it started, at its first size. /fgui undo puts it back again.")
        f.show = ns:CreateButton(f, "", 210, 22, function()  -- each click moves on to the next choice
            if not f.keys then return end
            local now, nextRule = ns:PanelShowRule(f.keys[1]), ns.showRules[1]
            for i, rule in ipairs(ns.showRules) do if rule == now then nextRule = ns.showRules[i % #ns.showRules + 1] end end
            ns:SetPanelShow(f.keys, nextRule)
            f.Refresh()
        end)
        f.show:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(ns:Tr("When this panel shows"))
            GameTooltip:AddLine(ns:Tr("Click to change: always, only in combat, only out of combat, or only while you have a target. While you are moving panels everything shows, so the change is seen once you leave move mode."), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        f.show:HookScript("OnLeave", function() GameTooltip:Hide() end)
        f.off = ns:CreateButton(f, "", 210, 22, function(self)
            if not f.feature then return end
            ns.db[f.feature] = not ns.db[f.feature]
            f.Refresh()
            f.note:SetText(ns:Tr("Takes effect after a /reload."))
        end)
        f.note = ns:NewText(f, 10, "LEFT")
        f.note:SetWidth(212)
        f.note:SetWordWrap(true)                             -- a sentence, not a label: it may take two lines
        if f.note.SetJustifyV then f.note:SetJustifyV("TOP") end
        ns:Paint(f.note, "SetTextColor", "faint")
        f.fade = ns:CreateCheckbox(f, "Fade when not in use", false, function(v)
            if f.fadeKey and ns.SetBarFade then ns:SetBarFade(f.fadeKey, v) end
        end)
        f.fade:SetWidth(212)
        f.fade:SetPoint("TOPLEFT", 12, -40)
        f.fade:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(ns:Tr("Fade when not in use"))
            GameTooltip:AddLine(ns:Tr("Out of combat this bar is invisible until you point at it. It returns in combat, and while you drag a spell or item."), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        f.fade:HookScript("OnLeave", function() GameTooltip:Hide() end)
        function f.Refresh()
            -- the lower rows close up when one of them is not offered for this panel
            local y = -138
            if f.canShowRule then
                f.show.text:SetText(ns:Tr(ns.showRuleNames[ns:PanelShowRule(f.keys[1])]))
                f.show:ClearAllPoints(); f.show:SetPoint("TOPLEFT", 12, y); f.show:Show()
                y = y - 28
            else
                f.show:Hide()
            end
            f.off:ClearAllPoints(); f.off:SetPoint("TOPLEFT", 12, y)
            if f.feature then y = y - 28 end
            f.note:ClearAllPoints(); f.note:SetPoint("TOPLEFT", 12, y - 2)
            f:SetHeight(-y + 40)
            if f.fadeKey then
                f.fade:SetChecked(ns.db.barFade and ns.db.barFade[f.fadeKey] and true or false)
                f.fade:Show()
            else
                f.fade:Hide()
            end
            if f.feature then
                f.off.text:SetText(ns:Tr(ns.db[f.feature] and "Turn this feature off" or "Turn this feature back on"))
                f.off:Show()
            else
                f.off:Hide()
            end
        end
        panelMenu = f
    end
    local f = panelMenu
    f.keys, f.feature, f.fadeKey = keys, feature, m.fadeKey
    function ns:RefreshPanelMenu() if f:IsShown() and f.Refresh then pcall(f.Refresh) end end
    f.canShowRule = not m.adopted                            -- (the game's own frames come and go by the game's rules)
    f.title:SetText(ns:Tr(m.label))
    if m.noScale then                                        -- sized elsewhere (action bars: the Layout tab)
        f.scale:Hide()
        f.note:SetText(ns:Tr(m.noScale))
    else
        f.scale:Show()
        f.scale:SetValue(ClampScale(ns.db.scale[key]) or 1)
        f.note:SetText(ns:Tr("Shift-click a nudge arrow to move ten at a time."))
    end
    f.Refresh()
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", m.overlay, "TOPRIGHT", 8, 0)
    f:Show()
end

function ns:ToggleMove()
    if not ns.moving and InCombatLockdown() then
        ns:Print("Panels can't be moved in combat.")
        return
    end
    ns.moving = not ns.moving
    if not ns.moving and ns.NoteSettingChanges then ns:After(0.5, function() pcall(ns.NoteSettingChanges, ns) end) end     -- (Safety.lua)
    -- frames held in place for fights are let go while you arrange things, and held again afterwards
    for _, info in ipairs(ns.adopted) do
        if ns.moving then pcall(info.Unpin)
        elseif info.attached then
            if InCombatLockdown() then info.pending = true else pcall(info.Pin) end
        end
    end
    for _, m in ipairs(ns.movables) do
        if ns.moving then m.overlay:Show() else m.overlay:Hide() end
    end
    -- alignment grid with the two centre lines picked out
    if ns.moving and not ns.grid then
        local g = CreateFrame("Frame", nil, UIParent)
        g:SetAllPoints(UIParent)
        g:SetFrameStrata("BACKGROUND")
        local a = ns.theme.accent
        local w, h = UIParent:GetWidth(), UIParent:GetHeight()
        w, h = type(w) == "number" and w or 1920, type(h) == "number" and h or 1080
        local function line(vertical, offset, centre)
            local t = g:CreateTexture(nil, "BACKGROUND")
            t:SetTexture(ns.FLAT)
            if centre then ns:Paint(t, "SetVertexColor", "@accent", 0.75) else t:SetVertexColor(1, 1, 1, 0.10) end
            if vertical then
                t:SetWidth(centre and 2 or 1)
                t:SetPoint("TOP", g, "TOP", offset, 0)
                t:SetPoint("BOTTOM", g, "BOTTOM", offset, 0)
            else
                t:SetHeight(centre and 2 or 1)
                t:SetPoint("LEFT", g, "LEFT", 0, offset)
                t:SetPoint("RIGHT", g, "RIGHT", 0, offset)
            end
        end
        for x = 64, w / 2, 64 do line(true, x); line(true, -x) end
        for y = 64, h / 2, 64 do line(false, y); line(false, -y) end
        line(true, 0, true); line(false, 0, true)
        ns.grid = g
    end
    if ns.grid then
        if ns.moving then ns.grid:Show() else ns.grid:Hide() end
    end
    if not ns.moving and panelMenu then panelMenu:Hide() end
    -- a small bar at the top while panels are being moved: Undo, and a way out
    if ns.moving and not ns.moveBar then
        local bar = CreateFrame("Frame", "FantasyGlassUIMoveBar", UIParent, ns.template)
        bar:SetSize(430, 40)
        bar:SetPoint("TOP", UIParent, "TOP", 0, -40)
        bar:SetFrameStrata("FULLSCREEN_DIALOG")
        bar:SetBackdrop(ns.BACKDROP)
        ns:Paint(bar, "SetBackdropColor", "@bg", 0.95)
        ns:Paint(bar, "SetBackdropBorderColor", "@accent", 1)
        local label = ns:NewText(bar, 12, "LEFT")
        label:SetPoint("LEFT", 12, 0)
        label:SetText(ns:Tr("Moving panels"))
        ns:Paint(label, "SetTextColor", "@accent")
        bar.done = ns:CreateButton(bar, "Done", 70, 24, function() if ns.moving then ns:ToggleMove() end end)
        bar.done:SetPoint("RIGHT", -8, 0)
        bar.undo = ns:CreateButton(bar, "Undo", 150, 24, function() ns:Undo() end)
        bar.undo:SetPoint("RIGHT", bar.done, "LEFT", -6, 0)
        bar.undo:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(ns:Tr("Undo the last change"))
            GameTooltip:AddLine(ns:Tr("Puts back the last move, nudge, resize or reset. Ctrl+Z does the same while you are moving panels."), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        bar.undo:HookScript("OnLeave", function() GameTooltip:Hide() end)
        -- Ctrl+Z
        if bar.EnableKeyboard and bar.SetPropagateKeyboardInput then
            bar:EnableKeyboard(true)
            pcall(bar.SetPropagateKeyboardInput, bar, true)       -- every other key goes on to the game as usual
            bar:SetScript("OnKeyDown", function(_, key)
                if key == "Z" and IsControlKeyDown and IsControlKeyDown() then ns:Undo() end
            end)
        end
        ns.moveBar = bar
    end
    function ns:RefreshMoveBar()
        local bar = ns.moveBar
        if not bar then return end
        local n = #ns.undoStack
        bar.undo.text:SetText(n > 0 and (ns:Tr("Undo") .. "  (" .. n .. ")") or ns:Tr("Undo"))
        bar.undo:SetAlpha(n > 0 and 1 or 0.45)
    end
    if ns.moveBar then
        if ns.moving then ns.moveBar:Show(); ns:RefreshMoveBar() else ns.moveBar:Hide() end
    end
    if ns.moving then
        ns:Print("Move mode ON - drag the panels (they snap to the grid; hold Shift to place freely), right-click one for its own settings, then |cffffff00/fgui move|r again to lock.")
    else
        ns:Print("Move mode OFF - positions saved.")
    end
end

-- Scale one or several panels (keys is a list). Returns false when it has to wait for combat to end.
function ns:SetPanelScale(keys, value)
    if InCombatLockdown() then
        ns:Print("Sizes can't be changed in combat.")
        return false
    end
    value = ClampScale(value) or 1
    local first = FindMovable(keys[1])
    ns:PushUndo(keys, "scale", format(ns:Tr("resized %s"), ns:Tr(tostring(first and first.label or keys[1]))))
    for _, m in ipairs(ns.movables) do
        for _, key in ipairs(keys) do
            if m.key == key then
                ns.db.scale[key] = value
                m.frame:SetScale(value)
            end
        end
    end
    return true
end

function ns:ResetPositions()
    ns.db.pos, ns.db.scale = {}, {}
    ReloadUI()
end

-- Preview mode (/fgui test): modules register a function(on) that shows sample content -----
ns.previews = {}
ns.previewing = false

-- Class emblems ---------------------------------------------------------------------------------------
-- Fantasy Glass UI's own medallion for each class (Media/emblem): a glass disc, the class's animated
-- sigil in the class color (a loop of sixteen frames drawn for each class: swords meeting, a bow
-- drawn and loosed, a lightning bolt crackling, the warlock's flame) over a glow that breathes, a
-- ring in the accent color that turns slowly (clean in the Glass themes, runes in the Fantasy ones)
-- and motes of light circling it.
-- The medallion's movement is done by the game's own animation system; a check once a second
-- restarts any loop the game has stopped (a frame that was hidden and shown again, a loading
-- screen). The sigil's frames follow the clock (see EmblemStep), so they can never fall behind.
-- "Reduce motion" or the animation switch off: the medallion holds still.
local emblemWidgets = {}                                     -- every medallion made (portraits last the whole session)
local EMBLEM_COLS, EMBLEM_FRAMES, EMBLEM_CELL, EMBLEM_SHEET = 4, 16, 64, 256
local EMBLEM_FPS = { MONK = 8, PRIEST = 10, PALADIN = 9, EVOKER = 9, DRUID = 10, DEATHKNIGHT = 10, HUNTER = 11, WARLOCK = 11 }   -- the rest: 12
function ns:EmblemCoords(frame)                              -- half a texel in from each edge, so neighbours never bleed in
    local col, row = frame % EMBLEM_COLS, math.floor(frame / EMBLEM_COLS)
    return (col * EMBLEM_CELL + 0.5) / EMBLEM_SHEET, ((col + 1) * EMBLEM_CELL - 0.5) / EMBLEM_SHEET,
           (row * EMBLEM_CELL + 0.5) / EMBLEM_SHEET, ((row + 1) * EMBLEM_CELL - 0.5) / EMBLEM_SHEET
end
local E = function(name) return ns.MEDIA .. "emblem\\" .. name .. ".tga" end
local function EmblemMoves() return ns:Motion() and not (ns.db and ns.db.emblemAnim == false) end
ns.EmblemMoves = EmblemMoves

local function Loop(region, build)
    if not (region and region.CreateAnimationGroup) then return nil end
    local g = region:CreateAnimationGroup()
    if g.SetLooping then g:SetLooping(build.bounce and "BOUNCE" or "REPEAT") end
    local a = g:CreateAnimation(build.kind)
    build.set(a)
    if a.SetDuration then a:SetDuration(build.time) end
    if build.delay and a.SetStartDelay then a:SetStartDelay(build.delay) end
    if build.smooth and a.SetSmoothing then a:SetSmoothing(build.smooth) end
    return g
end

function ns:CreateEmblem(parent, inset)
    local m = CreateFrame("Frame", nil, parent)
    inset = inset or 0
    m:SetPoint("TOPLEFT", inset, -inset)
    m:SetPoint("BOTTOMRIGHT", -inset, inset)
    local function Layer(layer, sub, file, pad)
        local t = m:CreateTexture(nil, layer, nil, sub)
        t:SetTexture(E(file))
        t:SetPoint("TOPLEFT", pad or 0, -(pad or 0))
        t:SetPoint("BOTTOMRIGHT", -(pad or 0), pad or 0)
        return t
    end
    m.disc = Layer("BACKGROUND", 1, "disc")
    ns:Paint(m.disc, "SetVertexColor", "@bg", 1)
    m.glow = Layer("BORDER", 0, "glow")
    if m.glow.SetBlendMode then m.glow:SetBlendMode("ADD") end
    m.sigil = m:CreateTexture(nil, "ARTWORK", nil, 1)
    m.sigil:SetPoint("CENTER")
    m.ring = Layer("OVERLAY", 1, "ring_glass")
    m.sparks = Layer("OVERLAY", 2, "sparks")
    if m.sparks.SetBlendMode then m.sparks:SetBlendMode("ADD") end
    -- the loops
    m.loops = {}
    local function Add(g) if g then m.loops[#m.loops + 1] = g end; return g end
    m.ringSpin = Add(Loop(m.ring, { kind = "Rotation", time = 24, set = function(a) a:SetDegrees(-360) end }))
    m.sparkSpin = Add(Loop(m.sparks, { kind = "Rotation", time = 7, set = function(a) a:SetDegrees(360) end }))
    m.breath = Add(Loop(m.glow, { kind = "Alpha", time = 1.6, bounce = true, smooth = "IN_OUT",
        set = function(a) a:SetFromAlpha(0.35); a:SetToAlpha(0.95) end }))
    m.pulse = Add(Loop(m.sigil, { kind = "Scale", time = 2.4, bounce = true, smooth = "IN_OUT",
        set = function(a)
            if a.SetScaleFrom then a:SetScaleFrom(1, 1); a:SetScaleTo(1.07, 1.07) else a:SetScale(1.07, 1.07) end
            if a.SetOrigin then a:SetOrigin("CENTER", 0, 0) end
        end }))

    function m:Fit()                                         -- sizes that follow the medallion's own size
        local w = self:GetWidth()
        if type(w) ~= "number" or ns:IsSecret(w) or w <= 0 then w = 40 end
        self.sigil:SetSize(w * 0.74, w * 0.74)
        self.size = w
    end
    function m:Restyle()                                     -- the ring of this theme's family
        local rune = (ns.style ~= "GLASS")
        local sky = (ns.style == "CELESTIAL")                -- an orbit ring with star points round a night disc
        self.ring:SetTexture(E(sky and "ring_celestial" or rune and "ring_rune" or "ring_glass"))
        self.disc:SetTexture(E(sky and "disc_celestial" or "disc"))
        if self.ring.SetBlendMode then self.ring:SetBlendMode(sky and "ADD" or "BLEND") end
        ns:Paint(self.ring, "SetVertexColor", "@accent", rune and 0.95 or 0.85)
        ns:Paint(self.sparks, "SetVertexColor", "@accent", 0.9)
        self.style = ns.style
    end
    function m:SetClass(class, r, g, b)
        r, g, b = r or 1, g or 1, b or 1
        self.class = class
        self.sigil:SetTexture(E(class))                      -- (a sheet of sixteen frames; EmblemStep shows one at a time)
        self.fps = EMBLEM_FPS[class] or 12
        self.frame = nil
        ns.EmblemStep(self)
        -- a touch lighter than the class color, so a dark one (Shaman, Death Knight) still reads on the glass
        self.sigil:SetVertexColor(r * 0.75 + 0.25, g * 0.75 + 0.25, b * 0.75 + 0.25)
        self.glow:SetVertexColor(r, g, b)
        if self.style ~= ns.style then self:Restyle() end
        self:Fit()
        self:Animate()
    end
    function m:Animate()
        local move = EmblemMoves()
        for _, g in ipairs(self.loops) do
            if move then
                if not (g.IsPlaying and g:IsPlaying()) then pcall(g.Play, g) end
            else
                pcall(g.Stop, g)
            end
        end
        if not move then self.glow:SetAlpha(0.7) end
    end
    m:SetScript("OnShow", function(self) self:Fit(); self:Animate() end)
    m:SetScript("OnSizeChanged", function(self) self:Fit() end)
    m:Restyle()
    emblemWidgets[#emblemWidgets + 1] = m
    return m
end

-- Once a second: any medallion on screen whose loops the game has stopped is started again.
-- Returns how many are on screen and how many of those are moving, for /fgui check.
function ns:EmblemTick()
    local shown, moving = 0, 0
    for _, m in ipairs(emblemWidgets) do
        local okV, vis = pcall(m.IsVisible, m)
        if m.class and okV and ns.Yes(vis) then
            shown = shown + 1
            if m.style ~= ns.style then m:Restyle() end
            local ok, err = pcall(m.Animate, m)
            if not ok then ns.emblemError = tostring(err) end
            local playing = true
            for _, g in ipairs(m.loops) do if g.IsPlaying and g:IsPlaying() == false then playing = false end end
            if playing and EmblemMoves() and #m.loops > 0 then moving = moving + 1 end
        end
    end
    ns.emblemCount, ns.emblemMoving = shown, moving
    return shown, moving
end
ns:Every(1, "Class emblems", function() ns:EmblemTick() end)

-- The sigil's frame for this moment: every medallion of a class shows the same frame, worked out from
-- the clock, so a loop never stalls or drifts. Held on the first frame when it should hold still.
function ns.EmblemFrameAt(t, fps, moving)
    if not moving then return 0 end
    return math.floor((tonumber(t) or 0) * (fps or 12)) % EMBLEM_FRAMES
end
function ns.EmblemStep(m)
    local frame = ns.EmblemFrameAt(GetTime(), m.fps, EmblemMoves())
    if frame ~= m.frame then
        m.sigil:SetTexCoord(ns:EmblemCoords(frame))
        m.frame = frame
    end
    return frame
end
ns:Every(0.04, "Class emblem frames", function()
    local moves = EmblemMoves()
    for _, m in ipairs(emblemWidgets) do
        -- (only the ones on screen: the rest catch up as they show; still ones already on their
        -- first frame need nothing, so a still emblem costs nothing at all)
        if m.class and (moves or m.frame ~= 0) and m:IsVisible() then
            local ok, err = pcall(ns.EmblemStep, m)
            if not ok then ns.emblemError = tostring(err) end
        end
    end
end)

-- Demo: the preview (sample frames, bars, raid, loot roll ...) plus a run of sample notifications
-- and a banner, so the whole interface can be seen at a glance - for a first look, or screenshots.
-- It ends when asked, or by itself when a fight starts.
local demoBanner
local DEMO_TOASTS = {
    { nil, "Level 11", "You gained a level.", "11" },
    { nil, "|cff0070dd[Stormforged Blade]|r", "You received", "+" },
    { nil, "New mail", "There is mail waiting for you.", "@" },
    { nil, "Whisper from Thrall", "Lok'tar! Are you coming to the raid tonight?", "T" },
    { nil, "|cffa335ee[Mantle of the Tempest]|r", "You received", "+" },
}
local demoStep = 0
function ns:ToggleDemo(forceOff)
    local want = not ns.demo
    if forceOff then want = false end
    if want == (ns.demo and true or false) then return end
    if want and InCombatLockdown() then
        ns:Print("The demo can't start in combat.")
        return
    end
    ns.demo = want or nil
    if want then
        if not ns.previewing then ns:TogglePreview() end
        if not demoBanner then
            demoBanner = CreateFrame("Frame", "FantasyGlassUIDemoBanner", UIParent, ns.template)
            demoBanner:SetSize(420, 30)
            demoBanner:SetPoint("TOP", UIParent, "TOP", 0, -60)
            demoBanner:SetFrameStrata("DIALOG")
            demoBanner:SetBackdrop(ns.BACKDROP)
            ns:Paint(demoBanner, "SetBackdropColor", "window", 0.92)
            ns:Paint(demoBanner, "SetBackdropBorderColor", "@accent", 1)
            demoBanner.text = ns:NewText(demoBanner, 12, "CENTER", true)
            demoBanner.text:SetPoint("CENTER")
        end
        demoBanner.text:SetText(ns:Tr("Fantasy Glass UI demo: these are samples. /fgui demo to end."))
        local w = demoBanner.text.GetStringWidth and demoBanner.text:GetStringWidth()       -- (as wide as its text needs)
        if type(w) == "number" and not ns:IsSecret(w) then demoBanner:SetWidth(math.max(420, w + 32)) end
        demoBanner:Show()
        demoStep = 0
        ns:Print("Demo ON - sample frames and notifications are showing. |cffffff00/fgui demo|r again to end.")
    else
        if ns.previewing then ns:TogglePreview(true) end
        if demoBanner then demoBanner:Hide() end
        if not forceOff then ns:Print("Demo OFF.") end
    end
end
function ns:DemoTick()                                      -- one sample notification at a time, round and round
    if not ns.demo then return false end
    if InCombatLockdown() then ns:ToggleDemo(true) return false end
    demoStep = demoStep % #DEMO_TOASTS + 1
    local t = DEMO_TOASTS[demoStep]
    if ns.Toast then ns:Toast(t[1], ns:Tr(t[2]), ns:Tr(t[3]), t[4]) end
    return true
end

function ns:RegisterPreview(fn)
    table.insert(ns.previews, fn)
end

-- mode "showcase": screenshot mode, where the busier samples (notifications, warnings, loot rolls)
-- stay away; quiet: nothing said in chat
function ns:TogglePreview(forceOff, mode, quiet)
    local want = not ns.previewing
    if forceOff then want = false end
    if want == ns.previewing then return end
    if want and InCombatLockdown() then
        ns:Print("Preview can't start in combat.")
        return
    end
    ns.previewing = want
    for _, fn in ipairs(ns.previews) do pcall(fn, want, want and mode or nil) end
    if not forceOff and not quiet then
        ns:Print(want and "Preview ON - sample frames are showing. |cffffff00/fgui test|r again to end."
                      or "Preview OFF.")
    end
end

do  -- a fight ends the preview (this event fires just before the game locks secure frames)
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:SetScript("OnEvent", ns:Guard("Skin events", function()
        if ns.previewing then
            ns:TogglePreview(true)
            ns:Print("Preview ended: you entered combat.")
        end
    end))
end

-- Slider ----------------------------------------------------------------------------------
function ns:CreateSlider(parent, label, minV, maxV, step, value, fmt, onChange, width)
    local th = ns.theme
    width = width or 200
    local c = CreateFrame("Frame", nil, parent)
    c:SetSize(width, 34)
    c.label = c:CreateFontString(nil, "OVERLAY")
    ns:Font(c.label, 11)
    c.label:SetPoint("TOPLEFT", 0, 0)
    c.label:SetText(ns:Tr(label))
    ns:Paint(c.label, "SetTextColor", "text")
    c.value = c:CreateFontString(nil, "OVERLAY")
    ns:Font(c.value, 11)
    c.value:SetPoint("TOPRIGHT", 0, 0)
    c.label:SetWidth(math.max(40, width - 44))               -- (a long name in another language stops short of the value)
    c.label:SetJustifyH("LEFT")
    if c.label.SetWordWrap then c.label:SetWordWrap(false) end

    local s = CreateFrame("Slider", nil, c, ns.template)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(width, 10)
    s:SetPoint("BOTTOMLEFT", 0, 4)
    s:SetBackdrop(ns.BACKDROP)
    ns:Paint(s, "SetBackdropColor", "field", 1)
    ns:Paint(s, "SetBackdropBorderColor", "@border", 1)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(ns.FLAT)
    ns:Paint(thumb, "SetVertexColor", "@accent", 1)
    thumb:SetSize(10, 16)
    s:SetThumbTexture(thumb)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end

    local function Snap(v)
        v = tonumber(v) or minV
        return math.max(minV, math.min(maxV, math.floor(v / step + 0.5) * step))
    end
    local last = Snap(value)
    s:SetValue(last)
    c.value:SetText(format(fmt or "%d", last))
    s:SetScript("OnValueChanged", function(_, v)
        v = Snap(v)
        c.value:SetText(format(fmt or "%d", v))
        if v ~= last then
            last = v
            if onChange then onChange(v) end
        end
    end)
    c.slider = s
    function c:SetValue(v) s:SetValue(Snap(v)) end       -- (the container is a plain frame; the slider is inside it)
    ns:IndexOption(label, c)
    return c
end

-- Text box --------------------------------------------------------------------------------
function ns:CreateEditBox(parent, w, h, hintText)
    local th = ns.theme
    local eb = CreateFrame("EditBox", nil, parent, ns.template)
    eb:SetSize(w, h or 22)
    eb:SetAutoFocus(false)
    ns:Font(eb, 12)
    eb:SetTextInsets(6, 6, 0, 0)
    eb:SetBackdrop(ns.BACKDROP)
    ns:Paint(eb, "SetBackdropColor", "field", 1)
    ns:Paint(eb, "SetBackdropBorderColor", "@border", 1)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    if hintText then
        local hint = eb:CreateFontString(nil, "OVERLAY")
        ns:Font(hint, 11)
        hint:SetPoint("LEFT", 7, 0)
        hint:SetText(ns:Tr(hintText))
        hint:SetJustifyH("LEFT")
        if hint.SetWordWrap then hint:SetWordWrap(false) end
        local function FitHint(_, bw)                         -- (the hint stays inside the box, whatever its width)
            bw = tonumber(bw)
            if bw and not ns:IsSecret(bw) and bw > 20 then hint:SetWidth(bw - 14) end
        end
        FitHint(eb, w)
        eb:HookScript("OnSizeChanged", FitHint)
        if hooksecurefunc then
            hooksecurefunc(eb, "SetWidth", function(self, bw) FitHint(self, bw) end)
            hooksecurefunc(eb, "SetSize", function(self, bw) FitHint(self, bw) end)
        end
        ns:Paint(hint, "SetTextColor", "faint")
        eb.hint = hint
        eb:SetScript("OnTextChanged", function(self)
            local t = self:GetText()
            if type(t) == "string" and t ~= "" then hint:Hide() else hint:Show() end
        end)
    end
    return eb
end

-- A box holding text ready for Ctrl+C --------------------------------------------------------
local copyBox
function ns:ShowCopyBox(text, caption)
    local th = ns.theme
    if not copyBox then
        copyBox = CreateFrame("Frame", "FantasyGlassUICopyBox", UIParent, ns.template)
        copyBox:SetSize(460, 74)
        copyBox:SetPoint("CENTER", 0, 140)
        copyBox:SetFrameStrata("TOOLTIP")
        copyBox:SetBackdrop(ns.BACKDROP)
        ns:Paint(copyBox, "SetBackdropColor", "window", 0.97)
        ns:Paint(copyBox, "SetBackdropBorderColor", "@border", 1)
        ns:Dress(copyBox)
        copyBox.label = copyBox:CreateFontString(nil, "OVERLAY")
        ns:Font(copyBox.label, 11)
        copyBox.label:SetPoint("TOPLEFT", 12, -10)
        copyBox.label:SetWidth(436)                              -- (a long caption takes two lines, never runs out of the box)
        copyBox.label:SetWordWrap(true)
        if copyBox.label.SetMaxLines then copyBox.label:SetMaxLines(2) end
        copyBox.label:SetJustifyH("LEFT")
        ns:Paint(copyBox.label, "SetTextColor", "dim")
        local eb = ns:CreateEditBox(copyBox, 436, 24)
        eb:SetPoint("BOTTOM", 0, 12)
        ns:Paint(eb, "SetBackdropBorderColor", "@accent", 1)
        eb:SetScript("OnEscapePressed", function() copyBox:Hide() end)
        eb:SetScript("OnEnterPressed", function() copyBox:Hide() end)
        copyBox.eb = eb
        tinsert(UISpecialFrames, "FantasyGlassUICopyBox")
    end
    copyBox.label:SetText(caption or "Press Ctrl+C to copy, Esc to close")
    copyBox.eb:SetText(text or "")
    copyBox:Show()
    copyBox.eb:SetFocus()
    copyBox.eb:HighlightText()
end

-- A status bar in the Fantasy Glass UI look: dark trough, flat fill, glassy sheen.
function ns:NewStatusBar(parent, border)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(ns.BAR or ns.FLAT)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetTexture(ns.FLAT)
    ns:Paint(bar.bg, "SetVertexColor", "trough", 0.95)
    local sheen = bar:CreateTexture(nil, "ARTWORK", nil, 2)
    sheen:SetAllPoints()
    sheen:SetTexture(ns.FLAT)
    if sheen.SetGradient and CreateColor then
        sheen:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.28), CreateColor(1, 1, 1, 0.14))
    else
        sheen:SetVertexColor(1, 1, 1, 0.05)
    end
    bar.sheen = sheen                                   -- (Starcut cuts it to the bar's shape too)
    if border then ns:AddBorder(bar, 0, 0, 0, 1) end
    return bar
end

-- A one-line label. (It does not wrap: text longer than its width is cut short with "...". For a
-- sentence or anything with several lines, switch wrapping on, or make one of these per line.)
function ns:NewText(parent, size, justify, title)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    ns:Font(fs, size, title)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end


-- A window of selectable text (Ctrl+A, Ctrl+C). Used for the self-check report and for copying chat.
local textWin
-- What someone has to do to get a report to the address, as a list of steps in order.
function ns:ReportSteps(link)
    if type(link) ~= "string" or link == "" then return {} end
    if link:find("@", 1, true) and not link:find("://", 1, true) then            -- an email address
        return { "Click the address above and press Ctrl+C to copy it. Start a new email to that address.",
                 "Click in the report below, then press Ctrl+A and Ctrl+C to copy all of it.",
                 "Paste it into the email (Ctrl+V) and send it." }
    end
    if ns.reportAsFile then                                                       -- a form with a file upload
        return { "Click in the report below, then press Ctrl+A and Ctrl+C to copy all of it.",
                 "Open Notepad (or any text editor) and press Ctrl+V to paste it.",
                 "Save it as a file, somewhere you can find it again.",
                 "Click the address above, press Ctrl+C, and paste it into your web browser.",
                 "On the page that opens, upload the file you saved." }
    end
    return { "Click the address above, press Ctrl+C, and paste it into your web browser.",
             "Click in the report below, then press Ctrl+A and Ctrl+C to copy all of it.",
             "Paste it (Ctrl+V) into the page that opened." }
end

-- link (optional): an address to send the text to. It gets a row of its own under the title: the
-- address in a box that selects itself when clicked, and a numbered list of what to do with it.
function ns:ShowTextWindow(title, text, toBottom, link)
    if not textWin then
        textWin = CreateFrame("Frame", "FantasyGlassUIText", UIParent, ns.template)
        textWin:SetSize(640, 440)
        textWin:SetPoint("CENTER")
        -- This window is for reading and copying, and it is usually opened from another of our windows
        -- (the options, for a report). So it sits on a layer above them, and it is solid: the window
        -- opacity setting is not applied to it, because text over text can't be read.
        textWin:SetFrameStrata("FULLSCREEN_DIALOG")
        if textWin.SetToplevel then textWin:SetToplevel(true) end
        textWin:SetBackdrop(ns.BACKDROP)
        ns:Paint(textWin, "SetBackdropColor", "@bg", 1)
        ns:Paint(textWin, "SetBackdropBorderColor", "@border", 1)
        ns:Dress(textWin)
        textWin:EnableMouse(true)
        textWin:SetMovable(true)
        textWin:SetClampedToScreen(true)
        textWin:RegisterForDrag("LeftButton")
        textWin:SetScript("OnDragStart", textWin.StartMoving)
        ns:KeepPlace(textWin, "TextWindow")
        tinsert(UISpecialFrames, "FantasyGlassUIText")
        textWin.title = ns:NewText(textWin, 15, "LEFT", true)
        textWin.title:SetPoint("TOPLEFT", 16, -12)
        local hint = ns:NewText(textWin, 11, "LEFT")
        hint:SetPoint("LEFT", textWin.title, "RIGHT", 12, 0)
        hint:SetText(ns:Tr("click in the text, Ctrl+A then Ctrl+C to copy"))
        ns:Paint(hint, "SetTextColor", "faint")
        textWin.hint = hint
        local close = ns:CreateButton(textWin, "X", 22, 22, function() textWin:Hide() end)
        close:SetPoint("TOPRIGHT", -8, -8)
        hint:SetPoint("RIGHT", close, "LEFT", -8, 0)            -- (cut short before the X when the title is long)
        local sf = CreateFrame("ScrollFrame", nil, textWin)
        sf:SetPoint("TOPLEFT", 16, -40)
        sf:SetPoint("BOTTOMRIGHT", -16, 14)
        sf:EnableMouseWheel(true)
        sf:SetScript("OnMouseWheel", function(self, delta)
            local range = self:GetVerticalScrollRange() or 0
            self:SetVerticalScroll(math.max(0, math.min(range, (self:GetVerticalScroll() or 0) - delta * 60)))
        end)
        local box = CreateFrame("EditBox", nil, sf)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        ns:Font(box, 12)
        box:SetWidth(600)
        box:SetScript("OnEscapePressed", function() textWin:Hide() end)
        sf:SetScrollChild(box)
        textWin.sf, textWin.box = sf, box
    end
    if link and not textWin.linkBox then
        local label = ns:NewText(textWin, 12, "LEFT", true)
        label:SetPoint("TOPLEFT", 16, -44)
        ns:Paint(label, "SetTextColor", "@accent")
        local lb = ns:CreateEditBox(textWin, 400, 22)
        lb:SetPoint("LEFT", label, "RIGHT", 10, 0)
        lb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        lb:SetScript("OnMouseUp", function(self) self:SetFocus(); self:HighlightText() end)
        lb:SetScript("OnTextChanged", function(self, byUser)           -- it is for copying from, not for typing in
            if byUser then self:SetText(self.link or ""); self:HighlightText() end
        end)
        local how = ns:NewText(textWin, 12, "LEFT", true)
        how:SetPoint("TOPLEFT", 16, -76)
        how:SetText(ns:Tr("How to send it"))
        ns:Paint(how, "SetTextColor", "@accent")
        -- The steps: a list, one line of text each, each free to wrap onto a second line. Every step
        -- hangs from the one above it, so a step that wraps pushes the rest down instead of being cut.
        local steps = {}
        for i = 1, 5 do
            local fs = textWin:CreateFontString(nil, "OVERLAY")
            ns:Font(fs, 12)
            fs:SetJustifyH("LEFT")
            if fs.SetJustifyV then fs:SetJustifyV("TOP") end
            fs:SetWidth(604)
            fs:SetWordWrap(true)
            if i == 1 then fs:SetPoint("TOPLEFT", how, "BOTTOMLEFT", 4, -6) else fs:SetPoint("TOPLEFT", steps[i - 1], "BOTTOMLEFT", 0, -5) end
            ns:Paint(fs, "SetTextColor", "text")
            steps[i] = fs
        end
        local rule = textWin:CreateTexture(nil, "ARTWORK")             -- a line between the instructions and the report
        rule:SetTexture(ns.FLAT)
        rule:SetHeight(1)
        ns:Paint(rule, "SetVertexColor", "@border", 0.8)
        textWin.linkLabel, textWin.linkBox, textWin.linkHow, textWin.linkSteps, textWin.linkRule = label, lb, how, steps, rule
    end
    local lastStep
    if textWin.linkBox then
        local list = link and ns:ReportSteps(link) or {}
        if link then
            local email = link:find("@", 1, true) and not link:find("://", 1, true)
            textWin.linkLabel:SetText(ns:Tr(email and "Email this report to" or "Send this report to"))
            textWin.linkBox.link = link
            textWin.linkBox:SetText(link)
            if textWin.linkBox.SetCursorPosition then textWin.linkBox:SetCursorPosition(0) end
        end
        for i, fs in ipairs(textWin.linkSteps) do
            if list[i] then
                fs:SetText(ns:AccentHex() .. i .. ".|r  " .. ns:Tr(list[i]))
                fs:Show()
                lastStep = fs
            else
                fs:SetText("")                               -- (an empty line takes no room, so later ones close up)
                fs:Hide()
            end
        end
        for _, piece in ipairs({ textWin.linkLabel, textWin.linkBox, textWin.linkHow, textWin.linkRule }) do
            if link then piece:Show() else piece:Hide() end
        end
        if lastStep then
            textWin.linkRule:ClearAllPoints()
            textWin.linkRule:SetPoint("TOPLEFT", lastStep, "BOTTOMLEFT", -4, -9)
            textWin.linkRule:SetWidth(608)
        end
    end
    textWin:SetHeight(lastStep and 540 or 440)               -- taller with instructions, so the report keeps its room
    if textWin.hint then                                     -- the one-line hint would only repeat the first step
        if lastStep then textWin.hint:Hide() else textWin.hint:Show() end
    end
    textWin.sf:ClearAllPoints()                              -- the report starts under whatever is above it
    if lastStep then
        textWin.sf:SetPoint("TOPLEFT", lastStep, "BOTTOMLEFT", -4, -18)
        textWin.sf:SetPoint("BOTTOMRIGHT", textWin, "BOTTOMRIGHT", -16, 14)
    else
        textWin.sf:SetPoint("TOPLEFT", 16, -40)
        textWin.sf:SetPoint("BOTTOMRIGHT", -16, 14)
    end
    textWin.link = link
    textWin.title:SetText(ns:Tr(title or ""))
    textWin.box:SetText(text or "")
    textWin:Show()
    if textWin.Raise then textWin:Raise() end                -- in front of anything else on its layer
    textWin.sf:SetVerticalScroll(0)
    if toBottom then
        ns:After(0.05, function()
            if textWin.sf.GetVerticalScrollRange then textWin.sf:SetVerticalScroll(textWin.sf:GetVerticalScrollRange() or 0) end
        end)
    end
end


-- Smooth bars ---------------------------------------------------------------------------------------
-- ns:SetBar(bar, value) glides to the new value. Newer clients can do that themselves (and can do it
-- with hidden combat values); otherwise we glide readable numbers ourselves and set hidden ones at once.
local EASE = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
local gliding = {}
function ns:SetBar(bar, value)
    if not ns.db.smoothBars or not ns:Motion() then gliding[bar] = nil; bar:SetValue(value) return end
    if EASE ~= nil then bar:SetValue(value, EASE) return end
    if ns:IsSecret(value) or type(value) ~= "number" then gliding[bar] = nil; bar:SetValue(value) return end
    gliding[bar] = value
end
do
    local f = CreateFrame("Frame")
    local function Glide(bar, target, e)
        local cur = bar:GetValue()
        if ns:IsSecret(cur) or type(cur) ~= "number" then error("unreadable") end
        local lo, hi = bar:GetMinMaxValues()
        local span = (type(lo) == "number" and type(hi) == "number" and not ns:IsSecret(hi)) and math.abs(hi - lo) or 1
        local step = cur + (target - cur) * math.min(1, e * 12)
        if math.abs(target - step) <= span * 0.004 then
            bar:SetValue(target)
            gliding[bar] = nil
        else
            bar:SetValue(step)
        end
    end
    f:SetScript("OnUpdate", function(_, e)
        for bar, target in pairs(gliding) do
            if not pcall(Glide, bar, target, e) then gliding[bar] = nil; pcall(bar.SetValue, bar, target) end
        end
    end)
end

-- Windows fade in when they open (our own frames only).
function ns:FadeIn(frame)
    if frame.suiFade or not (frame.CreateAnimationGroup and frame.HookScript) then return end
    local group = frame:CreateAnimationGroup()
    local a = group:CreateAnimation("Alpha")
    a:SetFromAlpha(0)
    a:SetToAlpha(1)
    a:SetDuration(0.14)
    if a.SetSmoothing then a:SetSmoothing("OUT") end
    if group.SetToFinalAlpha then group:SetToFinalAlpha(true) end
    frame.suiFade = group
    frame:HookScript("OnShow", function()
        if ns.db.fades and ns:Motion() and not InCombatLockdown() then group:Stop(); group:Play() end
    end)
end

-- A short colored flash over a bar (critical hits, critical heals).
function ns:Flasher(bar)
    local t = bar:CreateTexture(nil, "OVERLAY")
    t:SetAllPoints()
    t:SetTexture(ns.FLAT)
    t:SetAlpha(0)
    local group = t:CreateAnimationGroup()
    local a = group:CreateAnimation("Alpha")
    a:SetFromAlpha(0.55)
    a:SetToAlpha(0)
    a:SetDuration(0.45)
    return function(r, g, b)
        t:SetVertexColor(r, g, b)
        group:Stop()
        group:Play()
    end
end


-- Panel tabs: the game still shows and hides its (now invisible) "active" art when you switch tabs,
-- so reading that tells us which tab is selected. The selected one gets an accent tint.
ns:Every(0.15, "Tabs", function()
    for tab in pairs(tabs) do
        if tab.IsVisible and tab:IsVisible() and tab.suiFill then
            local mark = (IsTexture(tab.LeftActive) and tab.LeftActive) or (IsTexture(tab.SquareBackgroundActive) and tab.SquareBackgroundActive)
            local selected = mark and mark.IsShown and mark:IsShown() and true or false
            if selected ~= tab.suiSelected then
                tab.suiSelected = selected
                if selected then ns:Paint(tab.suiFill, "SetVertexColor", "@accent", 0.45)
                else ns:Paint(tab.suiFill, "SetVertexColor", "plate", 1) end
            end
        end
    end
end)

-- Helpers for window-specific passes (Character.lua, Polish.lua) -----------------------------------
ns.kit = {}
local kit = ns.kit
kit.IsTexture = IsTexture
function kit.Hide(o) if type(o) == "table" and o.SetAlpha then pcall(o.SetAlpha, o, 0) end end

-- Keep a piece's shape but drain its gold and tint it with a theme color.
function kit.Tint(tex, role, alpha)
    if not IsTexture(tex) or tex.sui or tex.suiTinted then return end
    tex.suiTinted = true
    if tex.SetDesaturated then pcall(tex.SetDesaturated, tex, true) end
    ns:Paint(tex, "SetVertexColor", role or "@btn", alpha)
end

-- A flat plate drawn on the frame itself (its own icon stays on top), with our rim set in by `inset`.
function kit.Plate(frame, inset, role, alpha)
    local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    fill:SetPoint("TOPLEFT", inset, -inset)
    fill:SetPoint("BOTTOMRIGHT", -inset, inset)
    fill:SetTexture(ns.FLAT)
    ns:Paint(fill, "SetVertexColor", role or "bg3", alpha or 0.9)
    fill.sui = true
    ns:AddBorder(frame, 0, 0, 0, 1, -inset)
    return fill
end

-- A section heading: plate with an accent underline.
function kit.Heading(frame, fontString, size)
    if frame.suiHeading then return end
    frame.suiHeading = true
    local fill = frame:CreateTexture(nil, "BACKGROUND")
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", -2, 2)
    fill:SetTexture(ns.FLAT)
    ns:Paint(fill, "SetVertexColor", "plate", 0.6)
    fill.sui = true
    local line = frame:CreateTexture(nil, "BORDER")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
    line:SetTexture(ns.FLAT)
    ns:Paint(line, "SetVertexColor", "@accent", 0.9)
    line.sui = true
    if type(fontString) == "table" and fontString.SetFont then ns:Font(fontString, size or 13, true) end
end

-- Hide every named piece whose key matches a pattern ("^InsetBorder", "Filigree").
function kit.HideKeys(frame, pattern)
    if type(frame) ~= "table" then return end
    for k, v in pairs(frame) do
        if type(k) == "string" and k:find(pattern) and IsTexture(v) then v:SetAlpha(0) end
    end
end

-- Buttons that are wrapped in ornate nine-slice child frames (equipment slots, spell buttons).
function kit.HideNineSliceChildren(frame)
    if type(frame) ~= "table" or not frame.GetChildren then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if type(child) == "table" and IsTexture(child.TopLeftCorner) and IsTexture(child.BottomRightCorner) then child:SetAlpha(0) end
    end
end

-- A flat field or plate on a control (the same paint our own edit boxes and buttons get).
function kit.Control(frame, role, inset) PaintControl(frame, role or "field", inset or 0) end

-- An item button (vendor goods, mail attachments): its slot art goes, the icon is squared off and
-- cropped, and it gets our rim. kit.ItemQuality then keeps the rim in the item's quality color by
-- reading the game's own (now invisible) quality border, which the game still shows, hides and colors.
function kit.ItemButton(btn, icon)
    if type(btn) ~= "table" or btn.suiItem or not btn.CreateTexture then return end
    btn.suiItem = true
    icon = icon or btn.icon or btn.Icon
    kit.Hide(btn.NormalTexture or (btn.GetNormalTexture and btn:GetNormalTexture()))
    if IsTexture(icon) then
        for _, key in ipairs({ "Mask", "CircleMask", "IconMask" }) do              -- round or shaped icons become square
            if type(btn[key]) == "table" and icon.RemoveMaskTexture then pcall(icon.RemoveMaskTexture, icon, btn[key]) end
        end
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    ns:AddBorder(btn, 0, 0, 0, 1, 0)
end
function kit.ItemQuality(btn)
    local rim, mark = btn.suiBorder, btn.IconBorder
    if not rim or not IsTexture(mark) then return end
    if mark:IsShown() then
        local r, g, b = mark:GetVertexColor()
        if type(r) == "number" and not ns:IsSecret(r) then
            mark:SetAlpha(0)
            rim:SetBackdropBorderColor(r, g, b, 1)
            return
        end
    end
    ns:Paint(rim, "SetBackdropBorderColor", "@border", 1)
end

-- Bars built from a Fill texture cut to shape by a Mask, inside an ornate Border on a Background
-- (profession ranks, and the reputation and skill bars of the character window). The ornate frame
-- and backdrop go; the fill and its mask stay exactly as the game drives them, on a flat trough with
-- our rim. The trough is fitted to FillArea when the bar has one, otherwise to the bar's own frame.
-- (Never to the mask: a mask is only as wide as the bar but can be many times taller, and a trough
-- sized to it covers half the window.)
function kit.FlatBar(bar)
    if type(bar) ~= "table" or bar.suiBar or not IsTexture(bar.Fill) or not bar.CreateTexture then return end
    bar.suiBar = true
    kit.Hide(bar.Background); kit.Hide(bar.Border)
    local area = (type(bar.FillArea) == "table" and bar.FillArea.GetObjectType) and bar.FillArea or bar
    local trough = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    trough:SetAllPoints(area)
    trough:SetTexture(ns.FLAT)
    ns:Paint(trough, "SetVertexColor", "trough", 0.9)
    trough.sui = true
    local th = ns.theme
    ns:Outline(area, -1, th.border[1], th.border[2], th.border[3], 1, "OVERLAY")
    local rank = type(bar.Rank) == "table" and bar.Rank.Text or bar.Text
    if type(rank) == "table" and rank.SetFont then ns:Font(rank, 11) end
end

-- Art that is named after its frame instead of attached to it: MerchantMoneyBg + "Left" / "Middle" / "Right".
function kit.HideNamed(name, suffixes)
    for _, suffix in ipairs(suffixes or { "Left", "Middle", "Right" }) do kit.Hide(_G[name .. suffix]) end
end

-- Big icon tabs built as Background / SelectedTexture / Icon / Mask (character window, quest panel).
local iconTabs = setmetatable({}, { __mode = "k" })
function kit.IconTab(tab)
    if type(tab) ~= "table" or tab.suiTab or not IsTexture(tab.SelectedTexture) then return end
    tab.suiTab, tab.suiChar = true, true
    kit.Hide(tab.Background)
    kit.Hide(tab.SelectedTexture)                      -- still shown/hidden by the game: we read that
    tab.suiFill = kit.Plate(tab, 5, "plate", 0.75)
    if IsTexture(tab.Icon) then
        if type(tab.Mask) == "table" and tab.Icon.RemoveMaskTexture then pcall(tab.Icon.RemoveMaskTexture, tab.Icon, tab.Mask) end
        tab.Icon:ClearAllPoints()
        tab.Icon:SetPoint("TOPLEFT", tab, "TOPLEFT", 7, -7)
        tab.Icon:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -7, 7)
    end
    if IsTexture(tab.HighlightTexture) then
        ns:ColorTex(tab.HighlightTexture, 1, 1, 1, 0.14)
        tab.HighlightTexture:ClearAllPoints()
        tab.HighlightTexture:SetPoint("TOPLEFT", tab, "TOPLEFT", 6, -6)
        tab.HighlightTexture:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -6, 6)
    end
    iconTabs[tab] = true
end
ns:Every(0.1, "Icon tabs", function()
    for tab in pairs(iconTabs) do
        if tab.IsVisible and tab:IsVisible() then
            local sel = tab.SelectedTexture
            local selected = sel.IsShown and sel:IsShown() and true or false
            if selected ~= tab.suiSelected then
                tab.suiSelected = selected
                if selected then
                    ns:Paint(tab.suiBorder, "SetBackdropBorderColor", "@accent", 1)
                    ns:Paint(tab.suiFill, "SetVertexColor", "@accent", 0.28)
                else
                    ns:Paint(tab.suiBorder, "SetBackdropBorderColor", "@border", 1)
                    ns:Paint(tab.suiFill, "SetVertexColor", "plate", 0.75)
                end
            end
        end
    end
end)

------------------------------------------------------------------------------------------
-- Starcut (11.12): bars cut to points at both ends, with a fine edge, a dark line under it so it
-- holds on bright ground, and a glow in the bar's own color. Used by the unit frames (the "Starcut"
-- frame style) and by every other bar of the add-on, so they all change together. Only the look
-- changes: each shape is a mask on the game's own textures.
------------------------------------------------------------------------------------------
local SC = ns.MEDIA .. "starcut\\"
function ns.StarcutOn() return (ns.db and ns.db.ufStyle or "STARCUT") ~= "CLASSIC" end

-- A mask the size of `region` plus `out` pixels all round.
local function ScMask(host, file, region, out)
    local ok, m = pcall(host.CreateMaskTexture, host)
    if not ok or not m then return nil end
    m:SetTexture(SC .. file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetPoint("TOPLEFT", region, "TOPLEFT", -out, out)
    m:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", out, -out)
    return m
end
local function ScMasked(tex, mask, on)
    if not (tex and mask and tex.AddMaskTexture) then return end
    if on and not tex.scMasked then pcall(tex.AddMaskTexture, tex, mask); tex.scMasked = true
    elseif not on and tex.scMasked then pcall(tex.RemoveMaskTexture, tex, mask); tex.scMasked = nil end
end

-- One bar cut to points: its fill, trough and sheen share one mask; under them a line in the rim's
-- color one pixel larger, a dark line one pixel larger again (so the edge holds on bright ground), and a
-- glow in the bar's own color around it all.
local ScGlowFit
local function ScBar(bar, on, glow)
    if not bar or not bar.CreateTexture then return end
    if on and not bar.sc then
        local sc = {}
        local file = bar.scMaskFile or "bar_mask"             -- (a bar may take another shape: the resource's dots are diamonds)
        sc.mask = ScMask(bar, file, bar, 0)
        sc.dark = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
        sc.dark:SetTexture(ns.FLAT)
        sc.dark:SetPoint("TOPLEFT", -2, 2); sc.dark:SetPoint("BOTTOMRIGHT", 2, -2)
        sc.dark:SetVertexColor(0, 0, 0, 0.9)
        sc.darkMask = ScMask(bar, file, bar, 2)
        sc.edge = bar:CreateTexture(nil, "BACKGROUND", nil, -6)
        sc.edge:SetTexture(ns.FLAT)
        sc.edge:SetPoint("TOPLEFT", -1, 1); sc.edge:SetPoint("BOTTOMRIGHT", 1, -1)
        ns:Paint(sc.edge, "SetVertexColor", "@rim", 0.55)
        sc.edgeMask = ScMask(bar, file, bar, 1)
        ScMasked(sc.dark, sc.darkMask, true)
        ScMasked(sc.edge, sc.edgeMask, true)
        sc.glow = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
        sc.glow:SetTexture(SC .. "bar_glow")
        if sc.glow.SetBlendMode then sc.glow:SetBlendMode("ADD") end
        bar.sc = sc
        -- the glow follows the bar's size, however it is set
        if bar.HookScript then
            bar:HookScript("OnSizeChanged", function(self, w, h) if self.sc and self.sc.glow:IsShown() then ScGlowFit(self, w, h) end end)
        end
    end
    local sc = bar.sc
    if not sc then return end
    ScMasked(bar:GetStatusBarTexture(), sc.mask, on)
    ScMasked(bar.bg, sc.mask, on)
    ScMasked(bar.sheen, sc.mask, on)
    for _, t in ipairs(bar.scAlso or {}) do ScMasked(t, sc.mask, on) end   -- (a bar's own extra textures)
    sc.dark:SetShown(on); sc.edge:SetShown(on)
    sc.glow:SetShown(on and glow ~= false)
    if on and glow ~= false then
        local w, h = bar:GetWidth(), bar:GetHeight()
        if type(w) == "number" and type(h) == "number" then ScGlowFit(bar, w, h) end
    end
end
-- The glow's picture holds the bar shape in its middle 208 x 32 of 256 x 64: stretch it to fit.
function ScGlowFit(bar, w, h)
    local g = bar and bar.sc and bar.sc.glow
    if not g or not w or not h or w <= 0 or h <= 0 then return end
    local x, y = w * 24 / 208, h * 16 / 32
    g:ClearAllPoints()
    g:SetPoint("TOPLEFT", bar, "TOPLEFT", -x, y)
    g:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", x, -y)
end
-- the glow takes the bar's color (called whenever that color is set)
local function ScTint(bar, alpha)
    local g = bar and bar.sc and bar.sc.glow
    if not g or not g:IsShown() then return end
    local ok, r, gg, b = pcall(bar.GetStatusBarColor, bar)
    if ok and type(r) == "number" then g:SetVertexColor(r, gg, b, alpha or 0.5) end
end
ns.StarcutTint = ScTint
ns.StarcutMask, ns.StarcutMasked, ns.StarcutBar, ns.StarcutGlowFit = ScMask, ScMasked, ScBar, ScGlowFit

-- Other bars follow the frame style too: each registers what to do when it changes.
local styleHooks = {}
function ns:OnFrameStyle(fn) styleHooks[#styleHooks + 1] = fn end
function ns:ApplyFrameStyle()
    if InCombatLockdown() then ns.designPending = true; ns.styleHooksPending = true; return end
    if ns.RefreshUnitFrames then ns:RefreshUnitFrames() end
    if ns.ApplyAuraDesign then ns:ApplyAuraDesign() end
    for _, fn in ipairs(styleHooks) do pcall(fn, ns.StarcutOn()) end
    ns.styleHooksPending = nil
end
function ns:RunFrameStyleHooks()                 -- (after a fight, when the change was asked for during it)
    if not ns.styleHooksPending then return end
    ns.styleHooksPending = nil
    for _, fn in ipairs(styleHooks) do pcall(fn, ns.StarcutOn()) end
end

-- A bar made with ns:NewStatusBar that should follow the frame style from now on: cut to points (and
-- its box border put away) under Starcut, back in its box under Classic. Its glow takes its color
-- whenever the color is set. `glow` false: no glow (bars that come by the dozen, like nameplates).
-- bar.scAlso: more of its own textures to cut to the shape; bar.scOnStyle(bar, on): the rest of what
-- that bar changes (its icon, where its text sits).
local scBars = setmetatable({}, { __mode = "k" })
local function ScApplyOne(bar, glow)
    local on = ns.StarcutOn()
    ScBar(bar, on, glow)
    local b = bar.suiBorder
    if b then b:SetShown(not on); if b.outer then b.outer:SetShown(not on) end end
    if bar.scOnStyle then pcall(bar.scOnStyle, bar, on) end
    if on then ScTint(bar, 0.5) end
end
function ns:StarcutStyleBar(bar, glow)
    if not bar then return end
    scBars[bar] = glow ~= false
    if glow ~= false and not bar.scTintHooked and hooksecurefunc then      -- (only a glowing bar needs its color followed)
        bar.scTintHooked = true
        hooksecurefunc(bar, "SetStatusBarColor", function(self) if self.sc then ScTint(self, 0.5) end end)
    end
    ScApplyOne(bar, scBars[bar])
end
ns:OnFrameStyle(function() for bar, glow in pairs(scBars) do ScApplyOne(bar, glow) end end)
-- (the text inside a bar steps in from the points: `on` and the usual inset)
function ns.StarcutInset(on, inset) return on and math.max(inset or 6, 14) or (inset or 6) end

-- (11.14) A square button cut like a gem: its corners cut away, a fine rim in the theme's rim color,
-- and its cooldown sweep cut to the same shape. Action buttons and bag slots. Under Classic it is the
-- square in its box again. `parts`: { icon = texture, also = { more textures }, cooldown = frame,
-- ownRim = true when the button colors the rim itself }.
local scButtons = setmetatable({}, { __mode = "k" })
local function FacetApply(btn, on)
    local p = scButtons[btn]
    if not p then return end
    if on and not btn.scFacet then
        btn.scFacet = ScMask(btn, "facet", btn, 0)
        local rim = btn:CreateTexture(nil, "OVERLAY", nil, 5)
        rim:SetTexture(SC .. "facet_ring")
        rim:SetPoint("TOPLEFT", -1, 1); rim:SetPoint("BOTTOMRIGHT", 1, -1)
        if not p.ownRim then ns:Paint(rim, "SetVertexColor", "@rim", 1) end   -- (bag slots color it by the item's quality)
        btn.scFacetRim = rim
    end
    local mask = btn.scFacet
    if not mask then return end
    ScMasked(p.icon, mask, on)
    for _, t in ipairs(p.also or {}) do ScMasked(t, mask, on) end
    for _, k in ipairs({ "GetHighlightTexture", "GetPushedTexture", "GetCheckedTexture" }) do
        local ok, t = pcall(function() return btn[k] and btn[k](btn) end)
        if ok and type(t) == "table" then ScMasked(t, mask, on) end
    end
    btn.scFacetRim:SetShown(on)
    local b = btn.suiBorder
    if b then b:SetShown(not on); if b.outer then b.outer:SetShown(not on) end end
    if rawget(btn, "suiStarEdge") then btn.suiStarEdge:SetShown(not on) end
    local cd = p.cooldown
    if cd and cd.SetSwipeTexture then pcall(cd.SetSwipeTexture, cd, on and (SC .. "facet") or ns.FLAT) end
    btn.scFacetOn = on or nil
end
function ns:StarcutFacet(btn, parts)
    if type(btn) ~= "table" or not btn.CreateTexture then return end
    scButtons[btn] = parts or {}
    FacetApply(btn, ns.StarcutOn())
end
ns:OnFrameStyle(function(on) for btn in pairs(scButtons) do FacetApply(btn, on) end end)

-- (11.15) Windows and tooltips cut like the rest: a small corner cut away at each corner, a fine rim
-- along the cut, and on big windows (not Glass, which wears no ornament) a star on the two top cuts.
-- The cut is a mask drawn in nine slices, so it keeps its size on any window; on a game client whose
-- masks cannot be sliced, windows keep their square corners and get only the stars.
local scWindows = setmetatable({}, { __mode = "k" })
local CUT = { window = { mask = "window_cut", line = "cut_line", size = 12 }, tip = { mask = "tip_cut", line = "cut_line_tip", size = 6 } }
local CUT_CORNERS = {                                 -- point, line tex coords, offset out of the frame
    { "TOPLEFT", 0, 1, 0, 1, -2, 2 }, { "TOPRIGHT", 1, 0, 0, 1, 2, 2 },
    { "BOTTOMLEFT", 0, 1, 1, 0, -2, -2 }, { "BOTTOMRIGHT", 1, 0, 1, 0, 2, -2 },
}
local sliceOK
local function CanSlice(frame)
    if sliceOK ~= nil then return sliceOK end
    local ok, m = pcall(frame.CreateMaskTexture, frame)
    sliceOK = ok and type(m) == "table" and type(m.SetTextureSliceMargins) == "function" or false
    if ok and type(m) == "table" and m.Hide then m:Hide() end
    return sliceOK
end
ns.StarcutCanSlice = function(reset) if reset then sliceOK = nil end return sliceOK end
local function CutRegions(frame, mask, on, w)
    w.masked = w.masked or {}
    if on then
        for _, r in ipairs({ frame:GetRegions() }) do
            if not w.masked[r] and r.GetObjectType and r:GetObjectType() == "Texture" and r.scCutLine ~= true then
                local layer = r.GetDrawLayer and r:GetDrawLayer()
                if layer == "BACKGROUND" or layer == "BORDER" then
                    if pcall(r.AddMaskTexture, r, mask) then w.masked[r] = true end
                end
            end
        end
        w.regions = frame.GetNumRegions and frame:GetNumRegions() or 0
    else
        for r in pairs(w.masked) do pcall(r.RemoveMaskTexture, r, mask) end
        w.masked = {}
        w.regions = nil
    end
end
local function WindowApply(frame, on)
    local w = scWindows[frame]
    if not w then return end
    local spec = CUT[w.kind] or CUT.window
    local cut = on and CanSlice(frame)
    if cut and not w.mask then
        w.mask = frame:CreateMaskTexture()
        w.mask:SetPoint("TOPLEFT", -2, 2); w.mask:SetPoint("BOTTOMRIGHT", 2, -2)
    end
    if w.mask and w.maskKind ~= w.kind then
        w.mask:SetTexture(SC .. spec.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        pcall(w.mask.SetTextureSliceMargins, w.mask, spec.size, spec.size, spec.size, spec.size)
        if w.mask.SetTextureSliceMode then pcall(w.mask.SetTextureSliceMode, w.mask, 0) end
        w.maskKind = w.kind
        if w.lines then for _, l in ipairs(w.lines) do l:SetTexture(SC .. spec.line); l:SetSize(spec.size, spec.size) end end
    end
    if w.mask then CutRegions(frame, w.mask, cut, w) end
    -- the rim along each cut
    if cut and not w.lines then
        w.lines = {}
        for i, c in ipairs(CUT_CORNERS) do
            local l = frame:CreateTexture(nil, "BORDER", nil, 7)
            l.scCutLine = true
            l:SetTexture(SC .. spec.line)
            l:SetTexCoord(c[2], c[3], c[4], c[5])
            l:SetSize(spec.size, spec.size)
            l:SetPoint(c[1], frame, c[1], c[6], c[7])
            ns:Paint(l, "SetVertexColor", "@border", 1)
            w.lines[i] = l
        end
    end
    if w.lines then for _, l in ipairs(w.lines) do l:SetShown(cut and true or false) end end
    -- the corner brackets would hang in the air over a cut corner
    for _, t in ipairs(type(frame.suiCorners) == "table" and frame.suiCorners or {}) do
        if t.SetShown then t:SetShown(not cut) end
    end
    -- stars on the two top cuts of a big window
    local big = w.kind == "window" and ns.style ~= "GLASS" and (frame:GetWidth() or 0) >= 300 and (frame:GetHeight() or 0) >= 200
    if on and big and not w.stars then
        w.stars = {}
        for i, pt in ipairs({ "TOPLEFT", "TOPRIGHT" }) do
            local s = frame:CreateTexture(nil, "OVERLAY", nil, 6)
            s:SetTexture(SC .. "star")
            s:SetSize(14, 14)
            local x = (i == 1) and (spec.size / 2 - 2) or -(spec.size / 2 - 2)
            s:SetPoint("CENTER", frame, pt, x, -(spec.size / 2 - 2))
            if s.SetBlendMode then s:SetBlendMode("ADD") end
            ns:Paint(s, "SetVertexColor", "@accent", 0.9)
            w.stars[i] = s
        end
    end
    if w.stars then for _, s in ipairs(w.stars) do s:SetShown(on and big and true or false) end end
    frame.scCut = cut or nil
end
function ns.StarcutWindow(frame, kind)
    if type(frame) ~= "table" or not frame.CreateTexture or not frame.GetRegions then return end
    local w = scWindows[frame]
    if not w then
        w = {}
        scWindows[frame] = w
        if frame.HookScript then                         -- (new pieces, a new size: looked at as it shows)
            pcall(frame.HookScript, frame, "OnShow", function(self)
                local ww = scWindows[self]
                local n = self.GetNumRegions and self:GetNumRegions() or 0
                if ww and ns.StarcutOn() and (ww.regions ~= n or not ww.sized) then ww.sized = true; WindowApply(self, true) end
            end)
            pcall(frame.HookScript, frame, "OnSizeChanged", function(self) local ww = scWindows[self]; if ww then ww.sized = nil end end)
        end
    end
    if w.kind ~= "tip" then w.kind = kind or w.kind or "window" end   -- (a tooltip stays a tooltip)
    WindowApply(frame, ns.StarcutOn())
end
ns:OnFrameStyle(function(on) for frame in pairs(scWindows) do pcall(WindowApply, frame, on) end end)
