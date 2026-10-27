local ADDON, A = ...
-- Refuse to load without the shared library. The TOC's `## Dependencies: ForeverCommsVoice`
-- already makes the client decline to load this addon when the library is missing or
-- disabled, so this catches the narrower case the dependency check cannot: the library was
-- loaded but failed partway through, leaving the global unset.
--
-- This is the first statement on purpose. The check used to live in VoiceBridge.lua, the
-- second file in the TOC, which meant this file had already finished: the namespace global
-- was published and the event dispatcher at the bottom was created and registered, so
-- ADDON_LOADED still reached A:Initialize() and the addon half-ran before failing at
-- render time. Erroring here instead leaves _G.ForeverGuildComms unpublished, creates no
-- dispatcher, and lets the Bindings.xml handlers find nil -- the addon goes inert with one
-- clear message. Matches ForeverGroupComms/Core.lua.
if not _G.ForeverCommsVoice then
    error("ForeverGuildComms requires ForeverCommsVoice. Install the Forever Comms " ..
          "bundle, or enable ForeverCommsVoice in the AddOns list.")
end
_G.ForeverGuildComms = A
A.name = ADDON
-- Visible labels in WoW Options > Key Bindings > AddOns.
BINDING_HEADER_FOREVERGUILDCOMMS = "Forever Guild Comms"
BINDING_NAME_FGC_OPEN_ALERTS = "Open guild alerts"
BINDING_NAME_FGC_ASK_HELP = "Ask guild for help"
BINDING_NAME_FGC_RESCAN_PROFESSION = "Rescan open profession"
A.version = "0.7.3-beta"
-- These language preferences are per character; old account-wide settings stay intact.
A.voiceDefaults = {language="en", accent="none", raceFilter=true, accentStrength="subtle"}
A.defaults = {
    enabled = true,
    outgoingMode = "automatic", -- "automatic" or "verify" for roster-triggered messages
    greetLogin = true,
    greetJoin = true,
    congratulateLevel = true,
    randomizeMessages = true, -- rotate curated built-in templates; custom messages are unchanged
    craftingAlerts = true,
    groupAlerts = true,
    tabardInCity = true,
    tabardOnExit = false,
    loginCooldown = 300,
    messageSpacing = 6,
    alertsSound = false,
    reviewAutoShow = true, -- pop the review list when a message is staged

    templates = {
        login = "Welcome back, {name}!",
        join = "Welcome to the guild, {name}!",
        level = "Congratulations on level {level}, {name}!",
        help = "[LFG] {type}: {activity}. I can fill: {myroles}. Looking for: {needed}. Whisper me!",
    },
}
A.classRoles = {
    WARRIOR = {tank=true, damage=true}, PALADIN = {tank=true, healer=true, damage=true},
    DRUID = {tank=true, healer=true, damage=true}, SHAMAN = {healer=true, damage=true},
    PRIEST = {healer=true, damage=true}, ROGUE = {damage=true},
    MAGE = {damage=true}, WARLOCK = {damage=true}, HUNTER = {damage=true},
}
A.roleNames = {tank="Tank", healer="Healer", damage="DPS"}
A.roleOrder = {"tank", "healer", "damage"}
-- The Ask-for-Help activity type, as an index into activityTypes. Declared here rather
-- than captured in BuildRequestUI's closure so A:RequestText can read it before the frame
-- exists, and so a harness can drive the real A:GetActivityType instead of stubbing it.
A.activityTypes = {"Dungeon", "Raid", "Quest"}
A.activityType = 1
-- Both timing options are saved as whole seconds. Clamp values coming from
-- older SavedVariables as well as from the Settings edit boxes.
A.timingLimits = {
    messageSpacing = {min=3, max=120},
    loginCooldown = {min=0, max=3600},
}
function A:NormalizeTiming(key, value, fallback)
    local limits = self.timingLimits[key]
    if not limits then return nil end
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then
        n = fallback == nil and self.defaults[key] or fallback
    end
    return math.max(limits.min, math.min(limits.max, math.floor(n + 0.5)))
end
A.eventsSeen = {}
A.lastEventPrune = nil
-- Keep deduplication history for the longest supported cooldown.
-- A shorter retention would re-admit events if a user increases loginCooldown.
A.eventRetentionSeconds = A.timingLimits.loginCooldown.max
A.eventPruneIntervalSeconds = 60
A.alerts = {}
A.onlineCount = 0
A.guildCount = 0
A.lastGuildSend = 0
-- A click is explicit consent, so approvals are not subject to the automatic spacing
-- queue. They do get a small floor, because a rapid run of clicks through a backlog
-- would otherwise post several lines to guild chat in the same instant.
A.approvalFloorSeconds = 2
-- Holds entry RECORDS, not plain strings: {text, kind, guild, time}. The guild stamp is
-- what lets DrainQueue discard a message queued for a guild the player has since left.
A.pendingMessages = {}
A.pendingApprovals = {}

-- Recursive backfill, shared by load-time migration and Settings' Restore Defaults.
-- Exposed on A as A:FillDefaults so Options.lua does not need a second shallow copy.
local function fillDefaults(dest, defaults)
    for key, value in pairs(defaults) do
        if dest[key] == nil then
            if type(value) == "table" then
                dest[key] = {}
                fillDefaults(dest[key], value)
            else
                dest[key] = value
            end
        elseif type(value) == "table" and type(dest[key]) == "table" then
            fillDefaults(dest[key], value)
        end
    end
end

function A:FillDefaults(dest, defaults)
    fillDefaults(dest, defaults or self.defaults)
end
function A:CanFillRole(role)
    -- Which roles this character's class can offer in the help composer. Used both to
    -- seed A.char.myRoles at login and to disable the checkboxes it cannot satisfy.
    return (self.classRoles[self.playerClass] or {})[role] == true
end
function A:Print(s)
    print("|cff6bcbffForeverGuildComms|r: " .. tostring(s))
end
function A:Key(name)
    if type(name) ~= "string" then return "" end
    return name:lower():gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
end
function A:IsSelf(name, guid)
    if guid and self.playerGuid and guid == self.playerGuid then return true end
    if not name then return false end
    local candidate = self:Key(name)
    if candidate == self.playerKey or (self.selfKeys and self.selfKeys[candidate]) then return true end
    -- Normalize only an explicit -Realm suffix, never shorten a character's
    -- first/last name. Two guildmates may share a first name on Forever.
    local withoutRealm = candidate:match("^(.-)%-[^%-]+$")
    if withoutRealm and (withoutRealm == self.playerKey or
        (self.selfKeys and self.selfKeys[withoutRealm])) then return true end
    return false
end
-- Avoid cutting off the continuation bytes of a UTF-8 character when a
-- translated message reaches the game's chat-message byte limit.
function A:ChatLimit(text)
    text = tostring(text or "")
    if #text <= 250 then return text end
    local limit = 250
    while limit > 0 do
        local byte = text:byte(limit + 1)
        if not byte or byte < 128 or byte >= 192 then break end
        limit = limit - 1
    end
    return text:sub(1, limit)
end
function A:Format(template, vars)
    local text = tostring(template or "")
    text = text:gsub("{([%a]+)}", function(key)
        local value = vars and vars[key]
        return value == nil and ("{" .. key .. "}") or tostring(value)
    end)
    return self:ChatLimit(text)
end
-- Existing tests and optional stripped-down installs can still use the
-- default formatter if the new language modules are not present.
function A:CommsText(kind, vars, preview)
    if self.VoiceText then return self:VoiceText(kind, vars, preview) end
    return self:Format(self.db.templates[kind], vars)
end
function A:CanUse()
    return self.db and self.db.enabled and IsInGuild and IsInGuild()
end
function A:Now()
    return GetTime and GetTime() or 0
end
-- Prune transient deduplication keys periodically while new events arrive.
-- All current callers use cooldowns <= loginCooldown.max (3600s). Keeping
-- records for that full window preserves deduplication if settings increase.
function A:PruneEventsSeen(now)
    now = now or self:Now()
    if self.lastEventPrune and now >= self.lastEventPrune
        and now - self.lastEventPrune < self.eventPruneIntervalSeconds then return end
    for key, seenAt in pairs(self.eventsSeen) do
        if type(seenAt) ~= "number" or seenAt > now
            or now - seenAt >= self.eventRetentionSeconds then
            self.eventsSeen[key] = nil
        end
    end
    self.lastEventPrune = now
end
function A:IsDuplicate(key, cooldown)
    local now = self:Now()
    self:PruneEventsSeen(now)
    local seenAt = self.eventsSeen[key]
    if seenAt and now >= seenAt and now - seenAt < (cooldown or 90) then return true end
    self.eventsSeen[key] = now
    return false
end
function A:SendGuild(message)
    if not self:CanUse() or type(message) ~= "string" or message == "" then return false end
    if not SendChatMessage then return false end
    local ok, err = pcall(SendChatMessage, self:ChatLimit(message), "GUILD")
    if not ok then self:Print("Couldn't send guild message: " .. tostring(err)) end
    return ok
end
-- Roster-triggered guild messages use either timed automatic delivery or a
-- private click-to-send review list. Never approve messages merely by toggling
-- the mode to Automatic: an explicit approval remains explicit.
function A:QueueGuild(message, key, cooldown)
    if not self:CanUse() or type(message) ~= "string" or message == "" then return end
    if self:IsDuplicate(key, cooldown or 90) then return end
    local entry = {
        text = self:ChatLimit(message),
        kind = (type(key) == "string" and key:match("^([^:]+):")) or "message",
        guild = GetGuildInfo and GetGuildInfo("player") or nil,
        time = date and date("%H:%M") or "",
    }
    if self.db.outgoingMode == "verify" then
        self:StageApproval(entry)
    else
        table.insert(self.pendingMessages, entry)
        self:DrainQueue()
    end
end
function A:StageApproval(entry)
    if not entry or not self:CanUse() then return end
    local voice = _G.ForeverCommsVoice
    if voice and voice.Enqueue then
        local guildAtCreation = entry.guild
        local textAtCreation = entry.text
        local id = voice:Enqueue({
            source="guild", kind=entry.kind,
            label=({login="Login greeting",join="New member welcome",level="Level congratulations"})[entry.kind] or "Guild message",
            text=textAtCreation,
            send=function()
                if not self:CanUse() or (GetGuildInfo and GetGuildInfo("player") or nil) ~= guildAtCreation then
                    self:Print("Old guild approval skipped: guild changed or addon disabled.")
                    return false,"stale"
                end
                -- Not stale, just too soon: leave it queued so the click can be repeated.
                if self:ApprovalThrottled() then return false end
                if self:SendGuild(textAtCreation) then
                    self.lastGuildSend=self:Now()
                    return true
                end
                return false
            end,
        })
        if id then return end
    end
    -- Legacy fallback for isolated tests/older installations without Voice.
    if #self.pendingApprovals >= 30 then table.remove(self.pendingApprovals, 1) end
    table.insert(self.pendingApprovals, entry)
    if self.UpdateApprovalsUI then self:UpdateApprovalsUI() end
    if self.UpdateBroker then self:UpdateBroker() end
    -- Opt-out: a busy login can stage several messages at once, and a window that
    -- reopens on each one is intrusive. With the shared queue installed, its own
    -- "auto-open on new messages" setting in /fcv governs instead of this one.
    if self.db.reviewAutoShow ~= false and self.ShowApprovals then self:ShowApprovals() end
end
-- Shared floor for every explicit send-on-click path.
function A:ApprovalThrottled()
    local now = self:Now()
    local since = now - (self.lastGuildSend or 0)
    if self.lastGuildSend > 0 and since < self.approvalFloorSeconds then
        self:Print(("Wait %d second(s) between approved messages.")
            :format(math.max(1, math.ceil(self.approvalFloorSeconds - since))))
        return true
    end
    return false
end
function A:ApprovalCount()
    local voice=_G.ForeverCommsVoice
    if voice and voice.PendingCount then return voice:PendingCount("guild") end
    return #self.pendingApprovals
end
function A:ApproveMessage(index)
    local entry = self.pendingApprovals[index]
    if not entry then return end
    if not self:CanUse() then
        self:Print("Cannot send: you are not in a guild or the addon is disabled.")
        return
    end
    if entry.guild ~= (GetGuildInfo and GetGuildInfo("player") or nil) then
        self:DismissMessage(index)
        self:Print("Message discarded: your guild has changed.")
        return
    end
    if self:ApprovalThrottled() then return end
    -- The Send button is the actual user confirmation. Do not schedule a
    -- delayed automatic send after a click.
    if self:SendGuild(entry.text) then
        self.lastGuildSend = self:Now()
        table.remove(self.pendingApprovals, index)
        if self.UpdateApprovalsUI then self:UpdateApprovalsUI() end
        if self.UpdateBroker then self:UpdateBroker() end
    end
end
function A:DismissMessage(index)
    if not self.pendingApprovals[index] then return end
    table.remove(self.pendingApprovals, index)
    if self.UpdateApprovalsUI then self:UpdateApprovalsUI() end
    if self.UpdateBroker then self:UpdateBroker() end
end
function A:ClearApprovals()
    if _G.ForeverCommsVoice and _G.ForeverCommsVoice.SkipAll then
        _G.ForeverCommsVoice:SkipAll("guild")
    end
    wipe(self.pendingApprovals)
    if self.UpdateApprovalsUI then self:UpdateApprovalsUI() end
    if self.UpdateBroker then self:UpdateBroker() end
end
-- Rate-limited automatic queue; re-check the guild and mode before sending.
function A:DrainQueue()
    if self.queueTimer or #self.pendingMessages == 0 then return end
    if not self:CanUse() then wipe(self.pendingMessages); return end
    local gap = math.max(3, tonumber(self.db.messageSpacing) or 6)
    local delay = math.max(0, gap - (self:Now() - self.lastGuildSend))
    self.queueTimer = true
    C_Timer.After(delay, function()
        self.queueTimer = false
        local entry = table.remove(self.pendingMessages, 1)
        if entry and self:CanUse() then
            local sameGuild = entry.guild == (GetGuildInfo and GetGuildInfo("player") or nil)
            if sameGuild then
                if self.db.outgoingMode == "verify" then
                    self:StageApproval(entry)
                elseif self:SendGuild(entry.text) then
                    self.lastGuildSend = self:Now()
                end
            end
        end
        if #self.pendingMessages > 0 then self:DrainQueue() end
    end)
end
function A:RoleText(roles, noneText)
    local labels = {}
    for _, role in ipairs(self.roleOrder) do
        if roles and roles[role] then table.insert(labels, self.roleNames[role]) end
    end
    return #labels > 0 and table.concat(labels, "/") or (noneText or "Any")
end
-- One settings writer shared by Blizzard Settings and the Titan menu.
-- Updating via this method keeps visible controls in sync and ensures timing
-- values always obey the same limits regardless of the UI used to edit them.
function A:RefreshOptions()
    if self.optionsPanel and self.optionsPanel.OnRefresh then
        self.optionsPanel.OnRefresh()
    end
end
function A:SetOption(key, value)
    if not self.db or self.defaults[key] == nil then return false end
    if key == "outgoingMode" then
        if value ~= "automatic" and value ~= "verify" then return false end
    elseif self.timingLimits[key] then
        value = self:NormalizeTiming(key, value, self.db[key])
    elseif type(self.defaults[key]) == "boolean" then
        if type(value) ~= "boolean" then return false end
    else
        -- Templates are edited in Blizzard Settings only, not Titan's menu.
        return false
    end
    local changed = self.db[key] ~= value
    self.db[key] = value
    if changed and key == "outgoingMode" and value == "automatic"
        and self:ApprovalCount() > 0 then
        self:Print("Earlier pending messages still need approval or dismissal. /fgc verify")
    end
    if changed then
        if key == "randomizeMessages" and self.UpdateRequestPreview then self:UpdateRequestPreview() end
        self:RefreshOptions()
        if self.UpdateBroker then self:UpdateBroker() end
    end
    return true
end
function A:VoiceOptionLabel(key, id)
    if key == "language" then return (self.languageByID or {})[id] or tostring(id) end
    if key == "accent" then
        if id == "auto" then return "Auto (character race)" end
        if id == "none" then return "None" end
        return self.accents and self.accents[id] and self.accents[id].label or tostring(id)
    end
    if key == "accentStrength" then
        return ({subtle="Subtle (wording only)", moderate="Moderate (adds a catchphrase)", expressive="Expressive (catchphrase + emphasis)"})[id] or tostring(id)
    end
    return tostring(id)
end
function A:SetVoiceOption(key, value)
    -- ForeverCommsVoice owns validation, mutations, and dependent UI refresh.
    -- Never mutate the shared table directly in the consuming addons.
    local engine = _G.ForeverCommsVoice
    if not engine or not engine.SetOption then return false end
    local success = engine:SetOption(key, value)
    if success and self.UpdateBroker then self:UpdateBroker() end
    return success
end
function A:VoiceChoices(key)
    if key == "language" then return self.languages or {{id="en", label="English"}} end
    if key == "accent" then return self:GetAvailableAccents() end
    if key == "accentStrength" then
        return {{id="subtle", label="Subtle (wording only)"}, {id="moderate", label="Moderate (adds a catchphrase)"},
            {id="expressive", label="Expressive (catchphrase + emphasis)"}}
    end
    return {}
end
-- Single entry point for TitanPanel, keybindings and any future shortcuts.
-- None of these actions sends guild chat; help only opens the composer.
function A:RunQuickAction(action)
    if not self.initialized then return end
    if action == "alerts" then
        self:ShowAlerts()
    elseif action == "help" then
        self:ShowRequest()
    elseif action == "rescan" then
        if self.ScanRecipes and self:ScanRecipes() then
            self:Print("Open profession rescanned. /fgc recipes shows your cached recipes.")
        else
            self:Print("Open a profession window first, then rescan its learned recipes.")
        end
    end
end

function A:OpenSettings(section)
    if self.settingsCategory and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(self.settingsCategory:GetID())
        -- Settings panels are displayed asynchronously; defer scrolling until
        -- the scroll child is available. Only an explicit menu shortcut uses it.
        if (section == "messages" or section == "languages") and self.optionsScroll then
            local scroll = self.optionsScroll
            local target = section == "languages" and self.languagesScrollY or self.messagesScrollY
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    if scroll.SetVerticalScroll then scroll:SetVerticalScroll(target) end
                end)
            end
        end
    else
        self:Print("Settings page is not available yet. Try /reload.")
    end
end
function A:Initialize()
    if self.initialized then return end
    self.initialized = true
    ForeverGuildCommsDB = type(ForeverGuildCommsDB) == "table" and ForeverGuildCommsDB or {}
    ForeverGuildCommsCharDB = type(ForeverGuildCommsCharDB) == "table" and ForeverGuildCommsCharDB or {}
    fillDefaults(ForeverGuildCommsDB, self.defaults)
    if ForeverGuildCommsDB.outgoingMode ~= "verify" then
        ForeverGuildCommsDB.outgoingMode = "automatic"
    end
    -- Older saved profiles may have accidentally retained blank edit fields.
    -- Populate those with the built-in defaults; preserve nonempty edits.
    for key, defaultMessage in pairs(self.defaults.templates) do
        if type(ForeverGuildCommsDB.templates[key]) ~= "string"
           or ForeverGuildCommsDB.templates[key]:match("^%s*$") then
            ForeverGuildCommsDB.templates[key] = defaultMessage
        end
    end
    -- Migrate old profiles (including edited SavedVariables) to safe values.
    for key in pairs(self.timingLimits) do
        ForeverGuildCommsDB[key] = self:NormalizeTiming(key, ForeverGuildCommsDB[key])
    end
    self.db = ForeverGuildCommsDB
    self.char = ForeverGuildCommsCharDB
    -- Adopt the old per-character voice preferences once, then use the shared
    -- SavedVariables table. Existing custom guild message templates are untouched.
    local voiceEngine = _G.ForeverCommsVoice
    if voiceEngine and voiceEngine.MigrateLegacy then
        self.char.voice = voiceEngine:MigrateLegacy(self.char.voice)
    else
        self.char.voice = type(self.char.voice) == "table" and self.char.voice or {}
    end
    fillDefaults(self.char.voice, self.voiceDefaults)
    if not self.languageByID or not self.languageByID[self.char.voice.language] then self.char.voice.language = "en" end
    if self.char.voice.accentStrength ~= "subtle" and self.char.voice.accentStrength ~= "moderate" and self.char.voice.accentStrength ~= "expressive" then
        self.char.voice.accentStrength = "subtle"
    end
    if type(self.char.voice.raceFilter) ~= "boolean" then self.char.voice.raceFilter = true end
    if self.GetAvailableAccents then
        local valid = false
        for _, entry in ipairs(self:GetAvailableAccents()) do
            if entry.id == self.char.voice.accent then valid = true; break end
        end
        if not valid then self.char.voice.accent = "auto" end
    end
    self.char.recipes = self.char.recipes or {}
    self.char.myRoles = self.char.myRoles or {}
    self.char.needRoles = self.char.needRoles or {}
    self.playerGuid = UnitGUID("player")
    self.playerName = UnitName("player") or ""
    self.playerKey = self:Key(self.playerName)
    self.selfKeys = {[self.playerKey]=true}
    if GetUnitName then
        local full = GetUnitName("player", true)
        if full and full ~= "" then self.selfKeys[self:Key(full)] = true end
    end
    if UnitFullName then
        local full = UnitFullName("player")
        if full and full ~= "" then self.selfKeys[self:Key(full)] = true end
    end
    local _, playerClass = UnitClass("player")
    self.playerClass = playerClass or ""
    for _, role in ipairs(self.roleOrder) do
        if self.char.myRoles[role] == nil then
            self.char.myRoles[role] = self:CanFillRole(role)
        end
    end
    if self.BuildOptions then self:BuildOptions() end
    if self.BuildUI then self:BuildUI() end
    if self.SetupRoster then self:SetupRoster() end
    -- Prune stale event keys even during quiet guild sessions. The lightweight
    -- activity-triggered sweep in IsDuplicate handles busy sessions promptly.
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(300, function() self:PruneEventsSeen() end)
    end
    if self.CheckTabard then C_Timer.After(3, function() self:CheckTabard(true) end) end
    if self.TryBroker then self:TryBroker() end
    self:Print("Loaded. /fgc for alerts, /fgc verify to review messages, /fgc options for settings.")
end

SLASH_FOREVERGUILDCOMMS1 = "/fgc"
SLASH_FOREVERGUILDCOMMS2 = "/guildcomms"
SlashCmdList.FOREVERGUILDCOMMS = function(input)
    input = (input or ""):lower():match("^%s*(.-)%s*$")
    if not A.initialized then A:Print("Not initialized yet."); return end
    if input == "options" or input == "settings" then A:OpenSettings()
    elseif input == "request" or input == "help" then A:ShowRequest()
    elseif input == "alerts" then A:ShowAlerts()
    elseif input == "verify" or input == "review" then A:ShowApprovals()
    elseif input == "recipes" then
        local count = 0
        for _, recipes in pairs(A.char.recipes) do for _ in pairs(recipes) do count = count + 1 end end
        A:Print(count .. " learned recipe names cached. Open each profession to refresh the cache.")
    elseif input == "clearrecipes" then
        wipe(A.char.recipes)
        A:Print("Recipe cache cleared. Open your professions again to repopulate it.")
    elseif input == "status" then
        A:Print("Guild members: " .. A.guildCount .. ", online: " .. A.onlineCount .. ", private alerts: " .. #A.alerts .. ", pending review: " .. A:ApprovalCount() .. ", mode: " .. A.db.outgoingMode)
    else A:ShowAlerts() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_GUILD_UPDATE")
events:RegisterEvent("CHAT_MSG_GUILD")
events:RegisterEvent("CHAT_MSG_SYSTEM")
events:RegisterEvent("UI_INFO_MESSAGE")
events:RegisterEvent("GUILD_ROSTER_UPDATE")
events:RegisterEvent("TRADE_SKILL_SHOW")
events:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
events:RegisterEvent("NEW_RECIPE_LEARNED")
events:RegisterEvent("ZONE_CHANGED")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("ZONE_CHANGED_INDOORS")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then A:Initialize(); return end
    if event == "ADDON_LOADED" then
        if A.initialized and A.TryBroker then A:TryBroker() end
        return
    end
    if not A.initialized then return end
    if event == "CHAT_MSG_GUILD" then
        if A.OnGuildChat then A:OnGuildChat(...) end
    elseif event == "CHAT_MSG_SYSTEM" then
        if A.OnSystemGuildJoin then A:OnSystemGuildJoin(...) end
    elseif event == "UI_INFO_MESSAGE" then
        if A.OnSystemGuildJoin then A:OnSystemGuildJoin(select(2, ...)) end
    elseif event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
        if A.OnRosterEvent then A:OnRosterEvent(event) end
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" or event == "NEW_RECIPE_LEARNED" then
        if A.ScheduleRecipeScan then A:ScheduleRecipeScan() end
    elseif A.ScheduleTabardCheck and (event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED_INDOORS" or event == "PLAYER_ENTERING_WORLD") then
        A:ScheduleTabardCheck()
    end
end)
