-- Part of Fantasy Glass UI's options folder (see Config.lua): the Tools tab and the guide.
local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end
local Trim = function(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

------------------------------------------------------------------------------------------
-- The guide: a question in plain words is matched against what the add-on knows about itself -
-- every feature switch with its description, every /fgui command, and a few written answers to
-- the things people ask most. It is a search, not a conversation: nothing leaves the game.
------------------------------------------------------------------------------------------
local STOP = {}
for word in ([[a an the and or of to in on at by for from with without is are was be been do does did how what where when why which who can could
    should would will i me my mine you your it its this that these those there here get got make made have has had want need see show find
    put set use using change if so not no yes up out off into over under while as than then just only also some any all every each one two
    wie kann ich der die das ein eine mein meine und zu für mit ist
    como puedo el la los las mi un una y para con es de
    comment puis je le les mon ma est et pour avec du des]]):gmatch("%S+") do STOP[word] = true end

-- Words that mean something the add-on calls by another name.
local ALSO = {
    font = "lettering", fonts = "lettering", typeface = "lettering",
    color = "theme accent", colour = "theme accent", colors = "theme accent", skin = "theme", appearance = "theme look",
    drag = "move", position = "move", place = "move", arrange = "move", unlock = "move",
    bigger = "scale size", smaller = "scale size", larger = "scale size", resize = "scale size", big = "scale size", small = "scale size",
    dps = "damage meter", hps = "healing meter", recount = "damage meter", details = "damage meter", threat = "aggro meter",
    hotkey = "keybind key", shortcut = "keybind key", bind = "keybind", binding = "keybind",
    money = "gold", coins = "gold", rich = "gold", junk = "sell gray", trash = "sell gray", vendor = "vendors sell",
    plates = "nameplates", nameplate = "nameplates", castbar = "cast bar", cd = "cooldown", cds = "cooldown", cooldowns = "cooldown",
    bag = "bags", inventory = "bags", backpack = "bags", pm = "whisper", tell = "whisper", dm = "whisper",
    hearth = "hearthstone travel", teleport = "travel", portal = "travel", flying = "flight", taxi = "flight",
    spec = "talent", specs = "talent", respec = "talent", gear = "gear set", outfit = "gear set", alt = "characters", alts = "characters",
    mute = "sound mute", loud = "sound volume", quiet = "sound volume", noise = "sound",
    stun = "loss control", stunned = "loss control", silenced = "loss control", feared = "loss control",
    fish = "fishing", pole = "fishing", marker = "markers raid", lockout = "lockouts", saved = "lockouts",
    drops = "missing", gone = "missing", fell = "missing", forgot = "missing reminder", remind = "reminder",
    broken = "error problem", bug = "error problem", crash = "error problem", wrong = "error problem",
    disable = "switch off", enable = "switch on", fight = "combat", fighting = "combat", battle = "combat",
    ping = "minimap", pinged = "minimap ping", sort = "raidsort order", sorted = "raidsort order", ordered = "raidsort", waypoint = "way", minutes = "timer countdown", minute = "timer countdown", seconds = "timer countdown", alarm = "timer countdown",
    timer = "countdown", countdown = "timer",
    health = "health frames", mana = "resource frames", portrait = "portraits", arrow = "waypoint", coords = "coordinates",
    note = "notes", notes = "notes notepad", todo = "to-do", calculate = "calculator", maths = "calculator", math = "calculator",
}

local function Stem(word)
    if #word > 5 and word:sub(-3) == "ing" then return word:sub(1, -4) end
    if #word > 4 and word:sub(-2) == "ed" then return word:sub(1, -3) end
    if #word > 3 and word:sub(-1) == "s" and word:sub(-2) ~= "ss" then return word:sub(1, -2) end
    return word
end
-- The words of a text that carry meaning, each once: { "move", "action", "bar" }.
function ns.GuideWords(text, expand)
    local out, seen = {}, {}
    local function add(word)
        word = Stem(word)
        if #word >= 2 and not STOP[word] and not seen[word] then seen[word] = true; out[#out + 1] = word end
    end
    for word in tostring(text or ""):lower():gmatch("[%w\128-\255][%w\128-\255%-']*") do
        if not STOP[word] then
            add(word)
            if word:find("-", 1, true) then for part in word:gmatch("[^%-]+") do if not STOP[part] then add(part) end end end      -- "auto-sell": also "auto", "sell"
            if expand and ALSO[word] then for more in ALSO[word]:gmatch("%S+") do add(more) end end
        end
    end
    return out, seen
end
local function Matches(word, set)
    if set[word] then return true end
    if #word < 5 then return false end                     -- (a short word must be the same word: "time" is not "timer")
    for other in pairs(set) do
        if #other >= 5 and (other:sub(1, #word) == word or word:sub(1, #other) == other) then return true end
    end
    return false
end

-- Written answers to the things people ask most. tab = where "Show me" goes; find = the label it rings.
ns.guideTopics = {
    { title = "Moving things", tab = "layout", find = "Move panels", keys = "move panel frame bar window where layout lock verschieben bewegen mover déplacer deplacer",
      text = "Type /fgui move, drag anything to where you want it, and type /fgui move again to lock. While moving, right-click a panel for its own scale, nudge, centre and reset." },
    { title = "Size of panels", tab = "layout", find = "Panel scale", keys = "scale size width height panel frame slider größe groesse tamaño taille",
      text = "Layout and profiles › Moving and scale has a scale slider for every panel. Unit frames, raid frames and action bars are sized with each of them, in Frames and bars. In move mode, right-click a panel for its own scale." },
    { title = "Themes", tab = "look", find = "Glass", keys = "theme glass fantasy look dark style thema design farbe tema thème",
      text = "Look and themes › Themes lists every theme under Glass, Fantasy and Celestial; click one to see it at once. Your own theme, beside it, makes one from three colors." },
    { title = "Lettering", tab = "look", find = "Lettering", keys = "lettering letters text face schrift schriftart fuente police",
      text = "Lettering is chosen in Look and themes › Accent and lettering, separately from the theme. Fonts from other add-ons can be picked there too." },
    { title = "Text size", tab = "look", find = "Contrast and text size", keys = "text size letters read small large scale",
      text = "Accessibility › Seeing has three text sizes; /fgui textsize 130 sets any size from 70 to 150." },
    { title = "Accent color", tab = "look", find = "Accent", keys = "accent highlight theme",
      text = "The swatches in Look and themes › Accent and lettering change the accent color." },
    { title = "Key bindings", command = "/fgui bind", keys = "keybind key press button action taste tastenbelegung tecla touche raccourci",
      text = "Type /fgui bind, point at an action button and press the key. The game's own Key Bindings menu has an AddOns section for this add-on's keys (potion, food, mount and the rest)." },
    { title = "Profiles", tab = "profiles", keys = "profile character copy share export import settings profil perfil",
      text = "Layout and profiles › Profiles keeps separate sets of settings, copies one to another, and exports them as text to share." },
    { title = "Language", command = "/fgui language", keys = "language german deutsch french français spanish español english italian italiano portuguese português russian русский язык korean 한국어 언어 chinese 中文 语言 translate sprache idioma langue lingua língua",
      text = "The Language button at the top right of this window, or /fgui language deutsch (english, français, español, auto)." },
    { title = "When something goes wrong", command = "/fgui report", keys = "error problem report help fix fail fehler hilfe ayuda erreur problema problème aide",
      text = "/fgui check lists what this game client supports and any errors. /fgui report gathers everything for a problem report. /fgui safe reloads with every feature off, to see whether the add-on is the cause." },
    { title = "Undo", command = "/fgui undo", keys = "undo mistake back revert accident rückgängig deshacer annuler",
      text = "/fgui undo (or Ctrl+Z while moving panels) puts back the last move, resize or reset, thirty steps deep." },
    { title = "Starting again", command = "/fgui reset", keys = "reset default defaults start again fresh zurücksetzen restablecer réinitialiser",
      text = "/fgui reset puts the current profile back to how the add-on comes. /fgui windows reset only puts the game's windows back where they open." },
    { title = "Click casting", tab = "combat", find = "Click casting", keys = "click cast mouse heal mouseover unit frame spell",
      text = "In Frames and bars › Raid frames, bind a mouse button (with or without a modifier) to a spell. Clicking any unit frame then casts it on that player." },
    { title = "Choosing cooldowns and buff alerts", tab = "combat", keys = "cooldown tracker choose add ability spell buff alert list",
      text = "Combat › Cooldowns holds the abilities for the cooldown tracker, and Combat › Alerts and warnings the buffs for buff alerts." },
    { title = "Showing a panel only at certain times", tab = "layout", find = "Move panels", keys = "hide show only combat visible fade target panel",
      text = "In move mode, right-click a panel and click its \"Show:\" button to step through always, only in combat, only out of combat and only with a target." },
    { title = "Switching a feature on or off", tab = "features", low = true, keys = "switch feature turn schalter interruptor",
      text = "Every feature has a switch in its section of the settings. Point at one to read what it does; most need a /reload." },
    { title = "The setup", command = "/fgui setup", keys = "setup wizard first role tank healer begin",
      text = "/fgui setup (or Run setup again below) opens the guided setup: role, look, lettering, layout." },
    { title = "Other add-ons", command = "/fgui conflicts off", keys = "conflict other addon add-on bar bag nameplate compatible together",
      text = "When another add-on does the same job (bars, bags, nameplates, unit frames, chat), this one leaves that job to it and says so. /fgui conflicts off runs everything regardless." },
    { title = "What is new", command = "/fgui new", keys = "new change changelog update version latest",
      text = "/fgui new shows the note for the last few versions. /fgui help lists every command." },
    { title = "Portraits", tab = "look", find = "Frame style", keys = "portraits 3d 2d face model emblem picture",
      text = "Frames and bars › Your frames has four choices for portraits: 3D model, 2D picture, class emblem, or none." },
    { title = "Class colors", tab = "look", find = "Class colors", keys = "class colour color custom paint frame red green blue wheel",
      text = "In Look and themes › Class colors, pick a class and set its color with the sliders or the color wheel. /fgui colors opens it." },
}

-- Everything the guide can answer with: { title, text, tab, find, command, key, label = {words}, keys = {words}, desc = {words} }.
local entries
local function Set(text) local _, set = ns.GuideWords(text); return set end
function ns:GuideEntries()
    if entries then return entries end
    entries = {}
    local topics = {}
    for _, t in ipairs(ns.guideTopics) do topics[#topics + 1] = t end
    for _, t in ipairs(ns.apiGuideTopics or {}) do topics[#topics + 1] = t end      -- (topics other add-ons added: API.lua)
    for _, topic in ipairs(topics) do
        -- (a topic's first two key words are what it is about: they count for more)
        local first, n = {}, 0
        for word in topic.keys:gmatch("%S+") do n = n + 1; if n <= 2 and not topic.low then first[#first + 1] = word end end
        entries[#entries + 1] = { title = topic.title, text = topic.text, tab = topic.tab, find = topic.find, command = topic.command,
            -- (the words of the player's own language count too: a question asked in German finds the German answer)
            label = Set(topic.title .. " " .. ns:Tr(topic.title)), main = Set(table.concat(first, " ")), keys = Set(topic.keys),
            desc = Set(topic.text .. " " .. ns:Tr(topic.text)), written = true, low = topic.low }
    end
    for _, group in ipairs(ns.featureGroups or {}) do
        for _, opt in ipairs(group[2]) do
            local key, label = opt[1], opt[2]
            local desc = (ns.featureDesc and ns.featureDesc[key]) or ""
            local shown = ns:Tr(label)
            entries[#entries + 1] = { key = key, title = shown, text = desc, tab = "sections", find = label,
                label = Set(label .. " " .. shown), keys = {}, desc = Set(desc .. " " .. ns:Tr(desc)) }
        end
    end
    for _, line in ipairs(ns.helpLines or {}) do
        if type(line) == "table" and line[2] and type(line[1]) == "string" and line[1]:sub(1, 1) == "/" then
            local word = line[1]:match("^/%a+%s+(%a+)") or ""
            -- (a command's description is short and all of it matters: its words count as key words)
            entries[#entries + 1] = { title = line[1], text = ns:Tr(line[2]), command = line[1],
                label = Set(word), keys = Set(line[2] .. " " .. ns:Tr(line[2])), desc = {} }
        end
    end
    return entries
end
-- The best answer and up to two that are close. Nil when nothing fits.
function ns:GuideAnswer(question)
    local words = ns.GuideWords(question, true)
    if #words == 0 then return nil end
    local scored = {}
    for i, e in ipairs(ns:GuideEntries()) do
        local score = 0
        for _, word in ipairs(words) do
            if e.main and Matches(word, e.main) then score = score + 8
            elseif Matches(word, e.label) then score = score + 4
            elseif Matches(word, e.keys) then score = score + 3
            elseif Matches(word, e.desc) then score = score + 1 end
        end
        if score >= 3 and not e.written then                 -- every word of its name was asked for: that is the one meant
            local all, any, count = true, false, 0
            for _ in pairs(e.label) do count = count + 1 end
            if count < 2 then all = false end
            local asked = {}
            for _, word in ipairs(words) do asked[word] = true end
            for word in pairs(e.label) do any = true; if not Matches(word, asked) then all = false end end
            if any and all then score = score + 3 end
        end
        if score >= 3 then scored[#scored + 1] = { entry = e, score = score + ((e.written and not e.low) and 0.5 or 0), at = i } end
    end
    table.sort(scored, function(a, b) if a.score ~= b.score then return a.score > b.score end return a.at < b.at end)
    if not scored[1] then return nil end
    local others = {}
    for i = 2, math.min(3, #scored) do others[#others + 1] = scored[i].entry end
    return scored[1].entry, others, scored[1].score
end
-- What the answer says, as lines: the answer, its state, what else is close.
function ns:GuideLines(question)
    local best, others = ns:GuideAnswer(question)
    if not best then
        return { ns:Tr("Nothing here matches that. Try one or two words, such as bags or move.") }, nil
    end
    local text = ns:Tr(best.text)
    if best.key then
        local on = ns.db and ns.db[best.key]
        local sec = ns.SectionOfRow and ns:SectionOfRow(best.key)
        text = text .. "  " .. (on and ns:Tr("It is switched on.") or format(ns:Tr("It is switched off. Its switch is in %s."),
            sec and (ns:Tr(sec.category.title) .. " › " .. ns:Tr(sec.title)) or ns:Tr("the settings")))
    end
    local lines = { ns:AccentHex() .. ns:Tr(best.title) .. "|r", text }
    if #others > 0 then
        local names = {}
        for _, e in ipairs(others) do names[#names + 1] = ns:Tr(e.title) end
        lines[#lines + 1] = "|cff8f96a3" .. ns:Tr("Also close") .. ": " .. table.concat(names, ";  ") .. "|r"
    end
    return lines, best
end
-- /fgui ask how do I move the bars
function ns:GuidePrint(question)
    if Trim(question) == "" then ns:Print("Ask in a few words: /fgui ask how do I move the bars"); return end
    for _, line in ipairs((ns:GuideLines(question))) do ns:PrintRaw(line) end
end
-- Take the reader to the answer: the switch or section on its tab, or the command ready to send.
function ns:GuideShow(entry)
    if type(entry) ~= "table" then return false end
    if entry.tab then
        local hit
        if entry.find then
            for _, e in ipairs(ns.optionIndex or {}) do
                if e.tab == entry.tab and e.label == entry.find then hit = { tab = e.tab, label = e.label, frame = e.frame } break end
            end
        end
        if hit and ns.GoToOption then ns.GoToOption(hit) else ns:ToggleConfig(entry.tab) end
        return "tab"
    elseif entry.command then
        pcall(ChatFrameUtil.OpenChat, (entry.command:gsub("%s*[<%[].*$", "")))
        return "command"
    end
    return false
end

------------------------------------------------------------------------------------------
-- Suggestions by class: a few switches that suit it. One button turns on those that are off.
------------------------------------------------------------------------------------------
-- (ns.classSuggestions, the switches that suit each class, is in the main add-on: AltSetup.lua)
local function LabelOf(key)
    for _, group in ipairs(ns.featureGroups or {}) do
        for _, opt in ipairs(group[2]) do if opt[1] == key then return opt[2] end end
    end
    return key
end
-- The suggestions for a class: { { key, label, on } ... }.
function ns:ClassSuggestions(class)
    local out = {}
    for _, key in ipairs(ns.classSuggestions[class] or { "cooldownPulse", "focusCastAlert", "buffMissing" }) do
        out[#out + 1] = { key = key, label = LabelOf(key), on = ns.db[key] and true or false }
    end
    return out
end
-- Switch on those that are off. Returns how many changed.
function ns:ApplySuggestions(class)
    local changed = 0
    for _, s in ipairs(ns:ClassSuggestions(class)) do
        if not s.on then ns.db[s.key] = true; changed = changed + 1 end
    end
    return changed
end

------------------------------------------------------------------------------------------
-- The Tools tab.
------------------------------------------------------------------------------------------
ns.toolWindows = {
    { "Gold history", "gold" }, { "Loot log", "loot" }, { "Rolls", "rolls" }, { "Notes on players", "note", "list" },
    { "Recent group mates", "recent" }, { "Lockouts", "lockouts" }, { "Your characters", "alts" }, { "Trades", "trades" },
    { "To do", "todo" }, { "Notepad", "notepad" }, { "Add-on memory", "addons" }, { "Whisper window", "whispers" },
    { "Shopping list", "shop" }, { "Who is missing", "missing" },
    { "Session", "session" }, { "Rares you have seen", "rares" }, { "Crafting queue", "queue", "list" }, { "Goals", "goal" },
    { "Ready check", "ready" }, { "Where to level", "level" }, { "Profession cooldowns", "profcd" },
    { "Performance", "perf" }, { "Tour", "tour" }, { "What's this?", "whatsthis" },
    { "Layout gallery", "gallery" }, { "Self-test", "selftest" }, { "Checklist", "checklist" },
    { "Talent builds", "talents" }, { "Events and holidays", "events" }, { "Raid composition", "comp" }, { "Battleground score", "bgscore" },
    { "Bag rules", "bagrules" }, { "Mail rules", "mailrules" }, { "Preview a shared string", "sharepreview" },
    { "Reputations and currencies", "reps" }, { "Professions", "crafts" }, { "Key bindings", "keys" },
    { "Login briefing", "briefing" }, { "Weekly recap", "recap" }, { "Skill-ups", "skillups" },
}
for _, w in ipairs(ns.apiToolWindows or {}) do ns.toolWindows[#ns.toolWindows + 1] = w end      -- (other add-ons' windows: API.lua)
ns.toolActions = {
    { "Make chat tabs", function() ns:SetupChatTabs() end, "A Loot tab and a Whispers tab." },
    { "Reset instances", function() ns:ResetInstancesNow() end, "Resets your instances and tells the group." },
    { "Deposit materials", function() ns:DepositMaterials() end, "With the bank open: every crafting material goes in." },
    { "Sort bags", function() ns:SortBags() end, "Your bags in the order of your bag sections. Click again to stop." },
    { "Quiet mode", function() ns:ToggleQuiet() end, "No chat, names over heads or info bar, for screenshots and streaming. Again to bring them back." },
    { "Check new features", function() ns:CheckNew() end, "Tries each feature added since 11.6 and reports what works, to copy and send." },
    { "Am I ready?", function() ns:ReadyMe() end, "Food, flask, weapon oil, repairs, reagents, bag space, talents and gear, before a raid." },
    { "Boss notes", function() ns:BossNoteCommand("list") end, "Your notes for each boss; with a boss targeted, /fgui bossnote writes one." },
    { "Death recap", function() ns:ShowDeathRecap() end, "What hit you before you last died." },
    { "Worth selling", function() ns:ShowWorthSelling() end, "What in your bags sells for more at the auction house than at a vendor." },
    { "Measure a fight", function() ns:PerfFight() end, "Measures the add-on through your next fight, then gives a report to send." },
    { "Group practice", function() ns:ToggleTestGroup() end, "Made-up group mates for five minutes, to see group cooldowns, the interrupt rotation and buff coverage on your own." },
    { "Put on upgrades", function() ns:EquipBest() end, "Every piece in your bags with a higher item level than what you wear, already bound to you, goes on." },
    { "Pull timer", function() ns:CountdownCommand("pull", "10") end, "A 10 second pull countdown for the group (/fgui pull 15 for another length)." },
    { "Break timer", function() ns:CountdownCommand("break", "5") end, "A 5 minute break for the group (/fgui break 10 for another length)." },
    { "Waypoint...", function() pcall(ChatFrameUtil.OpenChat, "/fgui way ") end, "Puts /fgui way in the typing bar: add two numbers, such as 45 62." },
}
ns.toolLists = {
    { key = "remindBuffs", title = "Buff reminders", hint = "a buff's name", need = "buffMissing", note = "An icon with a ! shows while one of these is missing." },
    { key = "auraHide", title = "Hidden buffs", hint = "a buff's name", need = "auraFilter", note = "These are left out of your own buff row." },
    { key = "keywords", title = "Keywords", hint = "a word", need = "chatKeywords", note = "Picked out in chat, with a sound." },
    { key = "restock", title = "Restock", hint = "shift-click an item, then a number", need = "restockOn", map = true, note = "Bought at any vendor who sells it, up to that many." },
    { key = "auraBlock", title = "Hidden on frames", hint = "a buff or debuff's name", note = "Never shown on the unit frames, raid frames or nameplates." },
}
-- Your rules (11.2.2): the same editor, for bag rules, mail rules, checklist jobs and talent builds.
-- Each kind gives its rows ({ text, remove, act, actLabel }) and takes what is typed (with the
-- choice made on the chooser above the box, where it has one).
local MAIL_WHAT = { "cloth", "leather", "ore", "herbs", "cooking", "elemental", "enchanting", "gems", "potions", "name" }
local MAIL_LABEL = { cloth = "Cloth", leather = "Leather", ore = "Ore and stone", herbs = "Herbs", cooking = "Cooking ingredients",
    elemental = "Elemental", enchanting = "Enchanting materials", gems = "Gems", potions = "Potions and food", name = "Name contains" }
local function BagKindLabel(kind)
    for _, k in ipairs(ns.BAG_RULE_KINDS or {}) do if k[1] == kind then return k[2] end end
    return kind
end
ns.toolRules = {
    { key = "bagRules", title = "Bag rules", need = "bagWindow", chooseLabel = "Rule",
      note = "Sections of your own in the one-window bags. The first rule an item meets decides its section; ^ moves a rule up.",
      choices = function() local out = {}; for _, k in ipairs(ns.BAG_RULE_KINDS or {}) do out[#out + 1] = k[2] end; return out end,
      hint = function(choice)
          local kind = ns.BAG_RULE_KINDS and ns.BAG_RULE_KINDS[choice] and ns.BAG_RULE_KINDS[choice][1]
          if kind == "ilvl" then return "50 = Upgrades" elseif kind == "quality" then return "4 = Epics"
          elseif kind == "type" then return "consumable = Food" elseif kind == "name" then return "potion = Potions" end
          return "a name for the section"
      end,
      rows = function()
          local out = {}
          local rules = ns.BagRules and ns.BagRules() or {}
          for i, rule in ipairs(rules) do
              out[#out + 1] = { text = ns:Tr(BagKindLabel(rule.kind)) .. (rule.value and (" " .. rule.value) or "") .. "  |cff9aa4b4>|r  " .. ns:AccentHex() .. rule.section .. "|r",
                  remove = function() table.remove(rules, i); if ns.RefreshBagWindow then pcall(ns.RefreshBagWindow, ns) end end,
                  act = (i > 1) and function() rules[i], rules[i - 1] = rules[i - 1], rules[i]; if ns.RefreshBagWindow then pcall(ns.RefreshBagWindow, ns) end end or nil,
                  actLabel = "^" }
          end
          return out
      end,
      add = function(text, choice)
          local kind = ns.BAG_RULE_KINDS and ns.BAG_RULE_KINDS[choice] and ns.BAG_RULE_KINDS[choice][1]
          if not kind or text == "" then return false end
          local value, section = text:match("^(.-)%s*=%s*(.+)$")
          if not section then value, section = nil, text end
          if (kind == "ilvl" or kind == "quality") and not tonumber(value) then return false end
          if (kind == "type" or kind == "name") and (not value or value == "") then return false end
          local rules = ns.BagRules()
          rules[#rules + 1] = { kind = kind, value = (value and value ~= "") and value or nil, section = Trim(section):sub(1, 24) }
          if ns.RefreshBagWindow then pcall(ns.RefreshBagWindow, ns) end
          return true
      end },
    { key = "mailRules", title = "Mail rules", chooseLabel = "Send",
      note = "At a mailbox, \"Send by my rules\" above the mail window sends each rule's items to its character.",
      choices = function() local out = {}; for _, w in ipairs(MAIL_WHAT) do out[#out + 1] = MAIL_LABEL[w] end; return out end,
      hint = function(choice) return MAIL_WHAT[choice] == "name" and "character, then part of a name" or "to which character" end,
      rows = function()
          local out = {}
          local rules = ns.MailRules and ns.MailRules() or {}
          for i, r in ipairs(rules) do
              local what = r.what:match("^name:(.+)$")
              local label = what and (ns:Tr("Name contains") .. " " .. what) or ns:Tr(MAIL_LABEL[r.what] or r.what)
              out[#out + 1] = { text = label .. "  |cff9aa4b4>|r  " .. ns:AccentHex() .. r.to .. "|r", remove = function() table.remove(rules, i) end }
          end
          return out
      end,
      add = function(text, choice)
          local what = MAIL_WHAT[choice]
          if not what or text == "" then return false end
          local to, part = text:match("^(%S+)%s*(.*)$")
          if what == "name" then
              if not part or part == "" then return false end
              what = "name:" .. part:lower()
          end
          local rules = ns.MailRules()
          rules[#rules + 1] = { to = to, what = what }
          return true
      end },
    { key = "checklist", title = "Checklist jobs", chooseLabel = "Every",
      note = "Your daily and weekly jobs. Tick them in the checklist window (/fgui checklist); the ticks clear at the resets.",
      choices = function() return { "Daily", "Weekly" } end,
      hint = "a job, such as Cooking quest",
      rows = function()
          local out = {}
          local store = ns.ChecklistStore and ns.ChecklistStore() or { items = {} }
          for i, item in ipairs(store.items) do
              out[#out + 1] = { text = "|cff9aa4b4" .. ns:Tr(item.period == "weekly" and "Weekly" or "Daily") .. "|r  " .. item.text
                  .. (item.holiday and ("  |cff9aa4b4(" .. ns:Tr("holiday") .. ")|r") or ""), remove = function() table.remove(store.items, i) end }
          end
          return out
      end,
      add = function(text, choice)
          if not ns.ChecklistAdd or text == "" then return false end
          return ns.ChecklistAdd(ns.ChecklistStore(), choice == 2 and "weekly" or "daily", text) ~= nil
      end },
    { key = "talents", title = "Talent builds",
      note = "Type a name to keep the talents you have now. Use puts a build in the game's Import box: press Import there and it joins your loadouts. /fgui talents send <player> <build> sends one.",
      hint = "a name for your talents now",
      state = function() if ns.TalentAPI and not ns.TalentAPI() then return "This game client does not let add-ons read talents." end end,
      rows = function()
          local out, names = {}, {}
          local builds = ns.TalentBuilds and ns.TalentBuilds() or {}
          for name in pairs(builds) do names[#names + 1] = name end
          table.sort(names)
          for _, name in ipairs(names) do
              local b = builds[name]
              out[#out + 1] = { text = name .. (b.spec and ("  |cff9aa4b4" .. b.spec .. "|r") or ""),
                  remove = function() builds[name] = nil end,
                  act = function() ns:ApplyTalentBuild(name) end, actLabel = "Use" }
          end
          return out
      end,
      add = function(text) return ns.SaveTalentBuild and ns:SaveTalentBuild(text) ~= nil end },
}
-- What a list holds, as rows to show: { text, remove = fn }.
function ns:ToolListRows(def)
    local list = ns:SavedList(def.key)
    local rows = {}
    if def.map then
        local ids = {}
        for id in pairs(list) do ids[#ids + 1] = id end
        table.sort(ids)
        for _, id in ipairs(ids) do
            local ok, name = pcall(function() return (ns:GetItemInfo(id)) end)
            rows[#rows + 1] = { text = ((ok and type(name) == "string") and name or (ns:Tr("Item") .. " " .. id)) .. "  |cff9aa4b4x" .. tostring(list[id]) .. "|r",
                remove = function() list[id] = nil end }
        end
    else
        for i, name in ipairs(list) do
            rows[#rows + 1] = { text = tostring(name), remove = function()
                for n = #list, 1, -1 do if list[n] == name then table.remove(list, n) end end
                ns.listChanged = (ns.listChanged or 0) + 1
            end }
        end
    end
    return rows
end
function ns:ToolListAdd(def, text)
    text = Trim(text)
    if text == "" then return false end
    if def.map then
        local before = 0
        for _ in pairs(ns:SavedList(def.key)) do before = before + 1 end
        ns:RestockCommand(text)
        local after = 0
        for _ in pairs(ns:SavedList(def.key)) do after = after + 1 end
        return after ~= before or ns:ItemIDOf(text) ~= nil
    end
    local did = ns.ListEdit(ns:SavedList(def.key), "add " .. text)
    ns.listChanged = (ns.listChanged or 0) + 1
    return did == "added"
end

-- Every heading on a tab is noted with where it is: the tabs list their sections down the left, and
-- show the chosen one (see BuildNav in Config.lua).
function ns.NoteSection(parent, text, x, y, fs)
    if type(parent) ~= "table" then return end
    local list = rawget(parent, "suiHeads")
    if not list then list = {}; rawset(parent, "suiHeads", list) end
    list[#list + 1] = { text = text, x = x or 0, y = y or 0, fs = fs }
end
local function Heading(parent, text, x, y, width)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    ns:Font(fs, 14, true)
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(ns:Tr(text))
    ns:Paint(fs, "SetTextColor", "@accent")
    ns:IndexOption(text, fs)
    ns.NoteSection(parent, text, x, y, fs)
    if ns.optUI and ns.optUI.Mark then ns.optUI.Mark(parent, text, y, fs, x) end
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture(ns.FLAT)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", x, y - 20)
    line:SetWidth(width or 226)
    ns:Paint(line, "SetVertexColor", "@border", 0.8)
    return fs
end
local function Small(parent, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    ns:Font(fs, size or 11)
    fs:SetJustifyH(justify or "LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(true) end
    return fs
end
local function Tip(button, text)
    button:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(ns:Tr(text), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- The Tools page: windows to open and things to do once. Its other pieces are built here too and
-- shown where they belong (12.0): each of your lists and rules beside the switches it goes with, the
-- guide's question box and the suggestions for your class on Home.
--
-- One list or one kind of rule: its entries in a scroll area with an x on each (and a second button
-- where an entry has one: move up, use), a chooser where the kind needs one, a box and Add, and what
-- it is for beside it.
local function Editor(host, def, RowsOf, AddTo)
    local E = { current = def, choice = 1 }
    local rows = {}
    local well = CreateFrame("Frame", nil, host, ns.template)  -- (a field behind the entries)
    well:SetPoint("TOPLEFT", 0, 0)
    well:SetSize(356, 144)
    well:SetBackdrop(ns.BACKDROP)
    ns:Paint(well, "SetBackdropColor", "field", 0.5)
    ns:Paint(well, "SetBackdropBorderColor", "@border", 0.7)
    local area, sheet = ns:ScrollArea(host, 340, 136)
    area:SetPoint("TOPLEFT", 6, -4)
    local y = -152
    local chooser
    if def.choices then
        chooser = ns:CreateButton(host, "", 356, 22, function(_, button)
            local list = E.current.choices and E.current.choices() or nil
            if not list then return end
            E.choice = (E.choice - 1 + (button == "RightButton" and -1 or 1)) % #list + 1
            E.Draw()
        end)
        chooser:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        chooser:SetPoint("TOPLEFT", 0, y)
        ns:Font(chooser.text, 11)
        Tip(chooser, "Click for the next choice; right-click to step back.")
        y = y - 28
    end
    local add = ns:CreateEditBox(host, 290, 22, " ")
    add:SetPoint("TOPLEFT", 0, y)
    local title = host:CreateFontString(nil, "OVERLAY")
    ns:Font(title, 12, true)
    title:SetPoint("TOPLEFT", 376, 0)
    ns:Paint(title, "SetTextColor", "text")
    title:SetText(ns:Tr(def.title))
    local note = Small(host, 11)
    note:SetPoint("TOPLEFT", 376, -20)
    note:SetWidth(350)
    ns:Paint(note, "SetTextColor", "dim")
    function E.Draw()
        local list = RowsOf(E.current, E.choice)
        for i, item in ipairs(list) do
            local row = rows[i]
            if not row then
                row = CreateFrame("Frame", nil, sheet)
                row:SetSize(334, 22)
                row:SetPoint("TOPLEFT", 0, -(i - 1) * 24)
                row.text = Small(row, 12)
                row.text:SetPoint("LEFT", 4, 0)
                if row.text.SetWordWrap then row.text:SetWordWrap(false) end
                row.x = ns:CreateButton(row, "x", 20, 18, function(self)
                    if self.item then self.item.remove(); E.Draw() end
                end)
                row.x:SetPoint("RIGHT", -2, 0)
                row.act = ns:CreateButton(row, "", 34, 18, function(self)
                    if self.item and self.item.act then self.item.act(); E.Draw() end
                end)
                row.act:SetPoint("RIGHT", row.x, "LEFT", -3, 0)
                ns:Font(row.act.text, 10)
                rows[i] = row
            end
            row.text:SetText(item.text)
            row.x.item, row.act.item = item, item
            if item.act then
                row.act.text:SetText(ns:Tr(item.actLabel or "Use"))
                row.act:Show()
                row.text:SetWidth(264)
            else
                row.act:Hide()
                row.text:SetWidth(302)
            end
            row:Show()
        end
        for i = #list + 1, #rows do rows[i].x.item = nil; rows[i].act.item = nil; rows[i]:Hide() end
        if area.SetContentHeight then area:SetContentHeight(math.max(1, #list) * 24) end
        local choices = def.choices and def.choices() or nil
        if chooser and choices then
            if E.choice > #choices then E.choice = 1 end
            chooser.text:SetText(ns:Tr(def.chooseLabel or "Kind") .. ":  " .. ns:Tr(choices[E.choice]))
        end
        if add.hint then
            local hint = def.hint
            if type(hint) == "function" then hint = hint(E.choice) end
            add.hint:SetText(ns:Tr(hint or ""))
        end
        local off = def.need and not ns.db[def.need]
        local extra = def.state and def.state() or nil
        note:SetText(ns:Tr(def.note) .. (off and ("\n\n|cffffd100" .. format(ns:Tr("Needs \"%s\" switched on."), ns:Tr(ns:FeatureLabel(def.need, ns.featureLabels and ns.featureLabels[def.need] or def.need))) .. "|r") or "")
            .. (extra and ("\n\n|cffffd100" .. ns:Tr(extra) .. "|r") or "")
            .. ((#list == 0 and not extra) and ("\n\n" .. ns:Tr("Nothing on this list yet.")) or ""))
        E.count = #list
        return #list
    end
    function E.Add()
        local ok = AddTo(E.current, add:GetText(), E.choice)
        if ok then add:SetText("") end
        add:ClearFocus()
        E.Draw()
        return ok
    end
    add:SetScript("OnEnterPressed", function() E.Add() end)
    local addBtn = ns:CreateButton(host, "Add", 60, 22, function() E.Add() end)
    addBtn:SetPoint("LEFT", add, "RIGHT", 6, 0)
    E.addBox, E.addButton, E.chooser = add, addBtn, chooser
    E.height = -y + 28
    E.Set = function(choice) E.choice = choice or 1; return E.Draw() end
    host:SetSize(736, E.height)
    return E
end

function ns.BuildToolsPage(page)
    local T = {}
    ns.toolsPage = T
    T.sheet = page

    -- Open a window, Do something once: four to a row ---------------------------------------
    local COLS, W = 4, 178
    Heading(page, "Open a window", 0, 0, 736)
    T.windowButtons = {}
    for i, def in ipairs(ns.toolWindows) do
        local b = ns:CreateButton(page, def[1], W - 6, 22, function()
            local fn = ns.toolCommands and ns.toolCommands[def[2]]
            if def[2] == "alts" then fn = function() ns:ShowCharacters() end end
            if ns.HideConfig then ns.HideConfig() end
            if fn then fn(def[3] or "") end
        end)
        b:SetPoint("TOPLEFT", ((i - 1) % COLS) * W, -28 - math.floor((i - 1) / COLS) * 26)
        ns:Font(b.text, 11)
        T.windowButtons[i] = b
    end
    local y = -28 - math.ceil(#ns.toolWindows / COLS) * 26 - 16
    Heading(page, "Do something once", 0, y, 736)
    for i, def in ipairs(ns.toolActions) do
        local b = ns:CreateButton(page, def[1], W - 6, 22, ns:Guard("Tools", def[2]))
        b:SetPoint("TOPLEFT", ((i - 1) % COLS) * W, y - 28 - math.floor((i - 1) / COLS) * 26)
        ns:Font(b.text, 11)
        Tip(b, def[3])
    end
    local bottom = y - 28 - math.ceil(#ns.toolActions / COLS) * 26

    -- Ask the guide (shown on Home) -----------------------------------------------------------
    local askFrame = CreateFrame("Frame", nil, page)
    askFrame:SetSize(736, 120)
    askFrame:Hide()
    T.askFrame = askFrame
    local ask = ns:CreateEditBox(askFrame, 620, 24, "For example: how do I move the action bars")
    ask:SetPoint("TOPLEFT", 0, 0)
    local answerTitle = Small(askFrame, 13)
    answerTitle:SetPoint("TOPLEFT", 2, -32)
    local answer = Small(askFrame, 11)
    answer:SetPoint("TOPLEFT", 2, -50)
    answer:SetWidth(620)
    ns:Paint(answer, "SetTextColor", "dim")
    local also = Small(askFrame, 11)
    also:SetPoint("TOPLEFT", answer, "BOTTOMLEFT", 0, -4)       -- (under the answer, however many lines that takes)
    also:SetWidth(620)
    answer:SetText(ns:Tr("Type a question and press Enter. The guide looks through every feature and command of this add-on; it knows nothing else."))
    local show
    local function Ask(text)
        local lines, best = ns:GuideLines(text or ask:GetText())
        T.best = best
        answerTitle:SetText(best and lines[1] or "")
        answer:SetText(best and lines[2] or lines[1])
        also:SetText(best and lines[3] or "")
        if best and (best.tab or best.command) then
            show.text:SetText(ns:Tr(best.tab and "Show me" or "Type it for me"))
            show:Show()
        else
            show:Hide()
        end
        if T.OnAnswer then pcall(T.OnAnswer) end             -- (Home sizes its card to the answer)
        return best
    end
    T.Ask = Ask
    local go = ns:CreateButton(askFrame, "Ask", 100, 24, function() ask:ClearFocus(); Ask() end)
    go:SetPoint("LEFT", ask, "RIGHT", 8, 0)
    ask:SetScript("OnEnterPressed", function(self) self:ClearFocus(); Ask() end)
    show = ns:CreateButton(askFrame, "Show me", 100, 24, function() ns:GuideShow(T.best) end)
    show:SetPoint("TOPLEFT", 628, -32)
    show:Hide()
    T.askBox, T.showButton = ask, show
    T.answerTitle, T.answer, T.also = answerTitle, answer, also
    -- (12.3) the box and its answer at a width: the answer stops short of "Show me" at its right, and
    -- the frame is as tall as the answer turns out to be
    local SHOW_W, SHOW_GAP = 100, 12
    local function Height(fs, size, width)
        local h = fs.GetStringHeight and fs:GetStringHeight()
        if type(h) == "number" and h > 0 then return h end
        local text = fs.GetText and fs:GetText()
        if type(text) ~= "string" or text == "" then return 0 end
        local scale = ns.fontScale or 1
        return math.max(1, math.ceil(#text * 0.5 * size * scale / math.max(80, width))) * size * scale * 1.25
    end
    function T.LayoutAsk(w)
        w = math.max(300, tonumber(w) or 736)
        askFrame:SetWidth(w)
        ask:SetWidth(w - 108)
        show:ClearAllPoints()
        show:SetPoint("TOPRIGHT", askFrame, "TOPRIGHT", 0, -32)
        local textW = w - 2 - SHOW_W - SHOW_GAP
        answerTitle:SetWidth(textW); answer:SetWidth(textW); also:SetWidth(textW)
        T.answerWidth = textW
        local alsoH = Height(also, 11, textW)
        local h = 50 + Height(answer, 11, textW) + ((alsoH > 0) and (4 + alsoH) or 0)
        h = math.max(56, math.ceil(h))
        askFrame:SetHeight(h)
        T.askHeight = h
        return h
    end

    -- Suggested for your class (shown on Home) -------------------------------------------------
    local suggestFrame = CreateFrame("Frame", nil, page)
    suggestFrame:SetSize(736, 96)
    suggestFrame:Hide()
    T.suggestFrame = suggestFrame
    local class = select(2, UnitClass("player"))
    if type(class) ~= "string" or ns:IsSecret(class) then class = nil end
    local suggest = Small(suggestFrame, 11)
    suggest:SetPoint("TOPLEFT", 0, 0)
    suggest:SetWidth(460)
    local turnOn
    local function DrawSuggest()
        local lines, off = {}, 0
        for _, s in ipairs(ns:ClassSuggestions(class)) do
            lines[#lines + 1] = (s.on and (ns:SignalHex("good") .. "+|r ") or "|cff8f96a3-|r ") .. ns:Tr(s.label)
            if not s.on then off = off + 1 end
        end
        suggest:SetText(table.concat(lines, "\n"))
        if off > 0 then turnOn:Show() else turnOn:Hide() end
        return off
    end
    turnOn = ns:CreateButton(suggestFrame, "Turn these on", 200, 24, function()
        if ns:ApplySuggestions(class) > 0 and ns.ShowReloadNote then ns.ShowReloadNote() end
        DrawSuggest()
    end)
    turnOn:SetPoint("TOPLEFT", 480, 0)
    T.DrawSuggest, T.class = DrawSuggest, class
    T.suggestText, T.turnOn = suggest, turnOn
    -- (12.3) the suggestions at a width: the list, and "Turn these on" at its right; as tall as the list
    function T.LayoutSuggest(w)
        w = math.max(300, tonumber(w) or 736)
        suggestFrame:SetWidth(w)
        local textW = math.min(460, w - 200 - 20)
        suggest:SetWidth(textW)
        turnOn:ClearAllPoints()
        turnOn:SetPoint("TOPRIGHT", suggestFrame, "TOPRIGHT", 0, 0)
        local h = suggest.GetStringHeight and suggest:GetStringHeight()
        if type(h) ~= "number" or h <= 0 then
            local text = suggest.GetText and suggest:GetText()
            local n = 1
            if type(text) == "string" then for _ in text:gmatch("\n") do n = n + 1 end end
            h = n * 11 * (ns.fontScale or 1) * 1.25
        end
        h = math.max(24, math.ceil(h))
        suggestFrame:SetHeight(h)
        T.suggestHeight = h
        return h
    end

    -- Your lists and your rules, one block each (shown in their sections) -----------------------
    T.listBlocks, T.ruleBlocks = {}, {}
    local function Block(def, RowsOf, AddTo)
        local f = CreateFrame("Frame", nil, page)
        f:Hide()
        local E = Editor(f, def, RowsOf, AddTo)
        f.editor = E
        f.Refresh = E.Draw
        return f
    end
    for i, def in ipairs(ns.toolLists) do
        T.listBlocks[def.key] = Block(def, function(d) return ns:ToolListRows(d) end, function(d, text) return ns:ToolListAdd(d, text) end)
        T.listBlocks[i] = T.listBlocks[def.key]
    end
    for i, def in ipairs(ns.toolRules) do
        T.ruleBlocks[def.key] = Block(def, function(d) return d.rows() end, function(d, text, choice) return d.add(Trim(text), choice) end)
        T.ruleBlocks[i] = T.ruleBlocks[def.key]
    end
    -- an item shift-clicked while the restock box is being typed in goes into it
    local stock = T.listBlocks.restock and T.listBlocks.restock.editor.addBox
    if stock and type(hooksecurefunc) == "function" then
        pcall(hooksecurefunc, ChatFrameUtil, "InsertLink", function(link)
            if type(link) == "string" and stock.HasFocus and stock:HasFocus() == true and stock.Insert then stock:Insert(link .. " ") end
        end)
    end
    -- (one list at a time, by its place in ns.toolLists: for the guide and the tests)
    local at = 1
    local function DrawList() local n = T.listBlocks[at].editor.Draw(); T.listCount = n; return n end
    T.DrawList = DrawList
    T.SetList = function(i) if T.listBlocks[i] then at = i end; return DrawList() end
    T.AddNow = function() local ok = T.listBlocks[at].editor.Add(); T.listCount = T.listBlocks[at].editor.count; return ok end
    local R = { at = 1 }
    function R.Set(i, choice)
        if T.ruleBlocks[i] then R.at = i end
        local E = T.ruleBlocks[R.at].editor
        R.addBox, R.chooser = E.addBox, E.chooser
        return E.Set(choice)
    end
    function R.Add() return T.ruleBlocks[R.at].editor.Add() end
    function R.Draw() local n = 0; for _, def in ipairs(ns.toolRules) do n = T.ruleBlocks[def.key].editor.Draw() end; return n end
    R.addBox = T.ruleBlocks[1].editor.addBox
    T.rules = R

    -- stepping through other add-ons' fonts and textures: the next choice after `now` in `names`
    -- ("ours" - nil - comes after the last and before the first)
    function ns.NextChoice(names, now, back)
        local found = 0
        for i, name in ipairs(names) do if name == now then found = i end end
        local n = #names + 1
        local to = (found + (back and -1 or 1)) % n
        return names[to]
    end

    page.Refresh = function()
        for _, def in ipairs(ns.toolLists) do T.listBlocks[def.key].editor.Draw() end
        R.Draw(); DrawSuggest()
    end
    page.Refresh()
    page.contentHeight = -bottom + 16
    if page.area then page.area:SetContentHeight(page.contentHeight) end
    return T
end
