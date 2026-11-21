local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Captions (12.1): a line on screen for things that get your attention with a sound - a ready check,
-- a whisper, a queue that is ready, a group invite, a duel, a boss emote, a raid warning, a roll on
-- loot, the aggro warning and your own alerts - so nothing is missed with the sound off or for
-- anyone who cannot hear it. Each line has a mark for its kind, sits over a dark band, and goes after
-- a few seconds (with Calm mode, after longer; click a line to put it away). Up to four at once,
-- the newest at the foot. Move them in move mode.
--
-- ns:Caption(kind, text) is the one way in: other parts of the add-on call it too.
------------------------------------------------------------------------------------------
ns.CAPTION_KINDS = {
    ready   = { mark = "?",  label = "Ready check" },
    whisper = { mark = "@",  label = "Whisper" },
    queue   = { mark = ">",  label = "Queue" },
    invite  = { mark = "+",  label = "Invite" },
    duel    = { mark = "x",  label = "Duel" },
    boss    = { mark = "!!", label = "Boss" },
    warning = { mark = "!",  label = "Raid warning" },
    loot    = { mark = "$",  label = "Loot" },
    aggro   = { mark = "!!", label = "Aggro" },
    alert   = { mark = "!",  label = "Alert" },
}
local MAX, HOLD, CALM_HOLD, W, H = 4, 6, 14, 460, 26
local frame, rows, queue = nil, {}, {}
local function Build()
    frame = CreateFrame("Frame", "FantasyGlassUICaptions", UIParent)
    frame:SetSize(W, MAX * (H + 4))
    frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 250)
    for i = 1, MAX do
        local r = CreateFrame("Button", nil, frame, ns.template)
        r:SetSize(W, H)
        r:SetBackdrop(ns.BACKDROP)
        r:SetBackdropColor(0, 0, 0, 0.78)                      -- (always dark, whatever the theme: captions must read)
        ns:Paint(r, "SetBackdropBorderColor", "@border", 0.9)
        r.mark = r:CreateFontString(nil, "OVERLAY")
        ns:Font(r.mark, 14, true)
        r.mark:SetPoint("LEFT", 8, 0)
        r.mark:SetWidth(26)
        r.mark:SetJustifyH("CENTER")
        ns:Paint(r.mark, "SetTextColor", "@accent")
        r.text = r:CreateFontString(nil, "OVERLAY")
        ns:Font(r.text, 14)
        r.text:SetPoint("LEFT", 38, 0)
        r.text:SetPoint("RIGHT", -10, 0)
        r.text:SetJustifyH("LEFT")
        if r.text.SetWordWrap then r.text:SetWordWrap(false) end
        r.text:SetTextColor(1, 1, 1)
        r:SetScript("OnClick", function(self) self.until_ = 0 end)
        r:Hide()
        rows[i] = r
    end
    local entry = ns:RegisterMovable(frame, "captions", "Captions")
    if type(entry) == "table" then entry.offPage = true end
end
local function Layout()
    local shown = {}
    for _, r in ipairs(rows) do if r:IsShown() then shown[#shown + 1] = r end end
    table.sort(shown, function(a, b) return (a.at or 0) < (b.at or 0) end)
    for i, r in ipairs(shown) do                              -- oldest on top, newest at the foot
        r:ClearAllPoints()
        r:SetPoint("BOTTOM", frame, "BOTTOM", 0, (#shown - i) * (H + 4))
    end
end
local function Place(item)
    local free
    for _, r in ipairs(rows) do if not r:IsShown() then free = r; break end end
    if not free then                                          -- (full: the oldest makes room)
        local oldest
        for _, r in ipairs(rows) do if not oldest or (r.at or 0) < (oldest.at or 0) then oldest = r end end
        free = oldest
    end
    local k = ns.CAPTION_KINDS[item.kind] or ns.CAPTION_KINDS.alert
    free.mark:SetText(k.mark)
    free.text:SetText(item.text)
    free.at = GetTime()
    free.until_ = free.at + ((ns.db and ns.db.calmMode) and CALM_HOLD or HOLD)
    free:SetAlpha(1)
    free:Show()
    Layout()
end
-- Show a caption. kind: one of ns.CAPTION_KINDS; text: what happened, in a few words.
function ns:Caption(kind, text)
    if not (ns.db and ns.db.captions) then return false end
    if type(text) ~= "string" or text == "" or Secret(text) then return false end
    if not frame then Build() end
    ns.captionLast, ns.captionCount = text, (ns.captionCount or 0) + 1
    -- Calm mode: one at a time; the next waits until it is put away or its time is up
    if ns.db.calmMode then
        for _, r in ipairs(rows) do
            if r:IsShown() then
                queue[#queue + 1] = { kind = kind, text = text }
                if #queue > 8 then table.remove(queue, 1) end
                return true
            end
        end
    end
    Place({ kind = kind, text = text })
    return true
end
function ns.CaptionRows() return rows end

ns:NewModule("captions", function()
    if not frame then Build() end
    ns:Every(0.1, "Captions", function()
        local now, any = GetTime(), false
        for _, r in ipairs(rows) do
            if r:IsShown() then
                local left = (r.until_ or 0) - now
                if left <= 0 then r:Hide()
                else
                    any = true
                    if left < 0.6 and ns:Motion() then r:SetAlpha(left / 0.6) end
                end
            end
        end
        if not any and #queue > 0 then Place(table.remove(queue, 1)); any = true end
        if any then Layout() end
    end)

    local function Name(who)
        if type(who) ~= "string" or Secret(who) then return "?" end
        return (who:gsub("%-.*$", ""))
    end
    local function Plain(text)                                 -- (boss emotes carry colors, icons and a %s for the name)
        if type(text) ~= "string" or Secret(text) then return nil end
        text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|H.-|h(.-)|h", "%1")
        return text
    end
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "READY_CHECK", "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER", "PARTY_INVITE_REQUEST", "DUEL_REQUESTED",
                         "LFG_PROPOSAL_SHOW", "UPDATE_BATTLEFIELD_STATUS", "RAID_BOSS_EMOTE", "RAID_BOSS_WHISPER",
                         "CHAT_MSG_RAID_WARNING", "START_LOOT_ROLL", "RESURRECT_REQUEST", "CONFIRM_SUMMON" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    local bgWas = {}
    ev:SetScript("OnEvent", ns:Guard("Captions", function(_, event, a1, a2)
        if event == "READY_CHECK" then
            ns:Caption("ready", format(ns:Tr("Ready check from %s"), Name(a1)))
        elseif event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" then
            local msg = Plain(a1)
            ns:Caption("whisper", format(ns:Tr("Whisper from %s"), Name(a2)) .. (msg and (": " .. msg) or ""))
        elseif event == "PARTY_INVITE_REQUEST" then
            ns:Caption("invite", format(ns:Tr("Group invite from %s"), Name(a1)))
        elseif event == "DUEL_REQUESTED" then
            ns:Caption("duel", format(ns:Tr("Duel request from %s"), Name(a1)))
        elseif event == "LFG_PROPOSAL_SHOW" then
            ns:Caption("queue", ns:Tr("Your group is ready: accept to join"))
        elseif event == "UPDATE_BATTLEFIELD_STATUS" then
            local i = tonumber(a1)
            local get = GetBattlefieldStatus
            if i and get then
                local ok, status, name = pcall(get, i)
                if ok and status == "confirm" and bgWas[i] ~= "confirm" then
                    ns:Caption("queue", format(ns:Tr("%s is ready: enter now"), (type(name) == "string" and not Secret(name)) and name or ns:Tr("Battleground")))
                end
                if ok then bgWas[i] = status end
            end
        elseif event == "RAID_BOSS_EMOTE" or event == "RAID_BOSS_WHISPER" then
            local text = Plain(a1)
            if text then
                local who = Name(a2)
                ns:Caption("boss", (text:find("%s", 1, true) and text:gsub("%%s", who)) or text)
            end
        elseif event == "CHAT_MSG_RAID_WARNING" then
            local text = Plain(a1)
            if text then ns:Caption("warning", format(ns:Tr("Raid warning: %s"), text)) end
        elseif event == "START_LOOT_ROLL" then
            ns:Caption("loot", ns:Tr("Roll on loot"))
        elseif event == "RESURRECT_REQUEST" then
            ns:Caption("invite", format(ns:Tr("%s offers to resurrect you"), Name(a1)))
        elseif event == "CONFIRM_SUMMON" then
            ns:Caption("invite", ns:Tr("You are being summoned"))
        end
    end))
end)
