local ADDON, A = ...
-- Refuse to load without the shared library, matching ForeverGuildComms' VoiceBridge.
-- The TOC's `## Dependencies: ForeverCommsVoice` already makes the client decline to load
-- this addon if the library is missing or disabled, so this catches the narrower case the
-- dependency check cannot: the library was loaded but failed partway through, leaving the
-- global unset.
--
-- Degrading instead of failing was the previous behaviour and it was not safe. Every call
-- into the library is guarded, so the addon would have run with English-only wording and
-- no shared queue -- and in that state A:Stage falls back to the local approval list,
-- whose A:Approve re-renders through A:Send rather than replaying the captured text. With
-- randomMessages on, the message sent could then differ from the one the player reviewed.
--
-- This is the first statement on purpose: erroring here means _G.ForeverGroupComms is
-- never published, the event dispatcher at the bottom of this file is never created, and
-- the Bindings.xml handlers find nil. The addon goes inert with one clear message rather
-- than half-running.
if not _G.ForeverCommsVoice then
    error("ForeverGroupComms requires ForeverCommsVoice. Install the Forever Comms " ..
          "bundle, or enable ForeverCommsVoice in the AddOns list.")
end
_G.ForeverGroupComms = A
A.name, A.version = ADDON, "0.7.0-beta"
BINDING_HEADER_FOREVERGROUPCOMMS = "Forever Group Comms"
BINDING_NAME_FGROUP_PANEL = "Open Group Comms"
BINDING_NAME_FGROUP_ROLES = "Review group roles"
BINDING_NAME_FGROUP_QUESTS = "Review group quests"

A.defaults = {
    enabled = true, autoGreeting = false, autoLevel = false,
    privateRoleAlerts = true, privateQuestReminder = true,
    questSync = true, randomMessages = true, useSharedVoice = true,
    maxNotifications = 20,
}
A.db = nil
A.notifications, A.approvals = {}, {}
A.seen, A.lastVariant = {}, {}
A.lastChat = 0
A.roster = {}
A.groupSerial = 0
A.activeGroup = false
A.initialized = false

A.variants = {
    greet = {"Hello everyone!", "Hi all, glad to be here!", "Hey team! Ready for an adventure?", "Greetings, everyone!"},
    welcome = {"Welcome to the group, {name}!", "Glad to have you along, {name}!", "Hey {name}, welcome aboard!"},
    level = {"Grats on {level}, {name}!", "Congrats on level {level}, {name}!", "Nice! Level {level}, {name}!"},
    roles = {"Quick role check: {roles}. Everyone happy with those roles?", "Before we start, can we confirm roles? {roles}", "Role double-check: {roles}. Please flag anything that needs changing."},
    quests = {"Before we get moving, does everyone have the dungeon quests? Please share any we're missing!", "Quest check! Anyone missing quests we can share before we pull?", "Let's compare quests and share what we can before starting."},
    pull = {"Pulling shortly. Everyone set?", "Next pull when everyone's ready.", "Ready for the next pack?"},
    mana = {"Mana break, please. Give our casters a moment.", "Quick mana top-up before the next pull.", "Let's pause for mana."},
    regroup = {"Let's regroup here before moving on.", "Please stack up and regroup.", "Hold up! Let's get everyone together."},
    heal = {"Waiting for the healer before we pull.", "Let's make sure our healer is with us before engaging."},
    cc = {"Please crowd-control the moon-marked target.", "Moon is our CC target. Please leave it alone.", "Keep moon controlled, please."},
    skull = {"Focus skull first, please.", "Skull is priority. Burn it down first.", "All damage on skull!"},
    interrupt = {"Please coordinate interrupts on dangerous casts.", "Watch the casts and rotate interrupts, please."},
    request = {"Could someone share {quest} if it is shareable?", "Does anyone have {quest} to share?", "I'm missing {quest}. Could someone please share it?"},
}
A.labels = {TANK="Tank", HEALER="Healer", DAMAGER="DPS", NONE="Unassigned"}

local function copyDefaults(dest, src)
    for k,v in pairs(src) do if dest[k] == nil then dest[k] = v end end
end
function A:Now() return GetTime and GetTime() or 0 end
function A:Print(s) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff56c8ffGroup Comms|r: " .. tostring(s)) end end
function A:Key(n)
    return type(n) == "string" and n:lower():gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ") or ""
end
function A:Trim(text)
    text = tostring(text or "")
    -- Chat messages are byte capped; preserve UTF-8 boundaries.
    if #text <= 250 then return text end
    local n = 250
    while n > 0 do
        local b = text:byte(n + 1)
        if not b or b < 128 or b >= 192 then break end
        n = n - 1
    end
    return text:sub(1, n)
end
function A:Render(kind, vars)
    if self.db and self.db.useSharedVoice and _G.ForeverCommsVoice then
        return _G.ForeverCommsVoice:Render("group", kind, vars, {
            random=self.db.randomMessages,
            fallback=(self.variants[kind] or {})[1],
        })
    end
    local list = self.variants[kind]
    if not list then return "" end
    local index = 1
    if self.db and self.db.randomMessages and #list > 1 then
        -- Unseeded on purpose: math.randomseed is absent in the WoW client, which seeds
        -- the RNG at startup. Full reasoning is in ForeverCommsVoice Core.lua, V:Pick.
        index = math.random(#list)
        if self.lastVariant[kind] == index then index = (index % #list) + 1 end
    end
    self.lastVariant[kind] = index
    return self:Trim(list[index]:gsub("{([%a]+)}", function(k)
        return tostring(vars and vars[k] or "{" .. k .. "}")
    end))
end
function A:GroupChannel()
    if not self.activeGroup then return nil end
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid and IsInRaid() then return "RAID" end
    return "PARTY"
end
function A:SameGroup(name)
    if not self.activeGroup or not name then return false end
    return self.roster[self:Key(name)] ~= nil
end
function A:IsSelf(name)
    return self:Key(name) == self.playerKey
end
function A:IsDuplicate(key, seconds)
    local now = self:Now()
    if self.lastPrune == nil or now < self.lastPrune or now - self.lastPrune > 60 then
        for k, time in pairs(self.seen) do
            if type(time) ~= "number" or time > now or now - time > 1200 then self.seen[k] = nil end
        end
        self.lastPrune = now
    end
    local prev = self.seen[key]
    if prev and prev <= now and now - prev < (seconds or 90) then return true end
    self.seen[key] = now
    return false
end
function A:Notify(message, key)
    if not self.db or not self.db.enabled then return end
    if key and self:IsDuplicate("notify:" .. key, 90) then return end
    table.insert(self.notifications, 1, self:Trim(message))
    while #self.notifications > self.db.maxNotifications do table.remove(self.notifications) end
    self:Print(message)
    if self.RefreshUI then self:RefreshUI() end
end
function A:CanChat()
    return self.db and self.db.enabled and self.activeGroup and SendChatMessage ~= nil
end
function A:SendPrepared(message, serial)
    if not self:CanChat() then self:Print("Join a group first, or enable the addon."); return false end
    if serial ~= nil and serial ~= self.groupSerial then
        self:Print("Skipping suggestion from a previous group.")
        return false,"stale"
    end
    if type(message)~="string" or message=="" then return false end
    local now=self:Now()
    if self.lastChat > 0 and now-self.lastChat < 2 then
        self:Print("Please allow two seconds between group messages.")
        return false
    end
    local ok,err=pcall(SendChatMessage,message,self:GroupChannel())
    if not ok then self:Print("Chat error: " .. tostring(err));return false end
    self.lastChat=now
    return true
end
function A:Send(kind, vars)
    return self:SendPrepared(self:Render(kind, vars))
end
function A:Stage(kind, vars, desc)
    if not self.activeGroup or not self.db.enabled then return end
    local voice=_G.ForeverCommsVoice
    if voice and voice.Enqueue then
        -- Capture exactly the message the player sees. No re-rolling variants
        -- and never post it to a different party after a roster transition.
        local serial=self.groupSerial
        local message=self:Render(kind, vars)
        local id=voice:Enqueue({source="group",kind=kind,label=desc or kind,text=message,
            send=function() return self:SendPrepared(message,serial) end})
        if id then
            self:Notify("Suggested: " .. (desc or kind) .. " (/fcv queue)")
            return
        end
    end
    -- Compatibility for standalone smoke tests without shared Voice.
    if #self.approvals >= 12 then table.remove(self.approvals, 1) end
    table.insert(self.approvals,{kind=kind,vars=vars,text=desc or kind,serial=self.groupSerial})
    self:Notify("Suggested: " .. (desc or kind) .. " (open /fgp to send)")
    if self.RefreshUI then self:RefreshUI() end
end
function A:Approve(index)
    local entry=self.approvals[index]
    if not entry then return end
    if entry.serial ~= self.groupSerial then
        table.remove(self.approvals,index)
        self:Print("That suggestion belongs to a previous group.")
        return
    end
    if self:Send(entry.kind,entry.vars) then table.remove(self.approvals,index) end
    if self.RefreshUI then self:RefreshUI() end
end
function A:Quick(kind)
    if kind == "roles" then return self:Send("roles", {roles=self:RoleSummary()}) end
    if kind == "ready" then return self:ReadyCheck() end
    if kind == "quest" then return self:ShowQuests() end
    if kind == "panel" then return self:ShowPanel() end
    if kind == "skullMark" then return self:MarkTarget(8) end
    if kind == "moonMark" then return self:MarkTarget(5) end
    if self.variants[kind] then return self:Send(kind) end
end
function A:CanManageGroup()
    if not self.activeGroup then return false end
    if UnitIsGroupLeader and UnitIsGroupLeader("player") then return true end
    if IsInRaid and IsInRaid() and UnitIsGroupAssistant and UnitIsGroupAssistant("player") then return true end
    return false
end
function A:ReadyCheck()
    if not self:CanManageGroup() then self:Print("Only the group leader/raid assistant can initiate a ready check."); return end
    if InCombatLockdown and InCombatLockdown() then self:Print("Try the ready check after combat."); return end
    local fn = (C_PartyInfo and C_PartyInfo.DoReadyCheck) or DoReadyCheck
    if not fn then self:Print("This client does not expose ready-check initiation."); return end
    local ok, err = pcall(fn)
    if not ok then self:Print("Ready check unavailable: " .. tostring(err)) end
end
function A:MarkTarget(index)
    if not self.activeGroup then self:Print("Join a group first."); return end
    if not self:CanManageGroup() then self:Print("Only the leader/raid assistant can mark targets."); return end
    if not (UnitExists and UnitExists("target")) then self:Print("Select a mob first."); return end
    if UnitCanAttack and not UnitCanAttack("player", "target") then self:Print("Select a hostile target."); return end
    if InCombatLockdown and InCombatLockdown() then self:Print("Marking may be restricted during combat."); return end
    local fn = SetRaidTarget or SetRaidTargetIcon
    if not fn then self:Print("Target-marker API unavailable."); return end
    local ok, err = pcall(fn, "target", index)
    if not ok then self:Print("Could not mark target: " .. tostring(err)) end
end
function A:OpenSettings()
    if self.settingsCategory and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(self.settingsCategory:GetID())
    else self:ShowPanel() end
end
function A:Initialize()
    if self.initialized then return end
    self.initialized = true
    ForeverGroupCommsDB = type(ForeverGroupCommsDB) == "table" and ForeverGroupCommsDB or {}
    copyDefaults(ForeverGroupCommsDB, self.defaults)
    for key,default in pairs(self.defaults) do
        if type(ForeverGroupCommsDB[key]) ~= type(default) then ForeverGroupCommsDB[key] = default end
    end
    ForeverGroupCommsDB.maxNotifications = math.max(5, math.min(40, math.floor(ForeverGroupCommsDB.maxNotifications)))
    self.db = ForeverGroupCommsDB
    self.playerKey = self:Key(GetUnitName and GetUnitName("player", true) or UnitName("player"))
    if self.playerKey == "" then self.playerKey = self:Key(UnitName("player")) end
    if self.InitializeQuestSync then self:InitializeQuestSync() end
    if self.BuildOptions then self:BuildOptions() end
    self:ScanRoster(true)
    if self.TryBroker then self:TryBroker() end
    self:Print("Ready. /fgp for quick actions; /fgp quests to compare quest logs.")
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("UNIT_LEVEL")
f:RegisterEvent("PLAYER_ROLES_ASSIGNED")
f:RegisterEvent("QUEST_LOG_UPDATE")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("READY_CHECK")
f:RegisterEvent("READY_CHECK_CONFIRM")
f:RegisterEvent("READY_CHECK_FINISHED")
f:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if (...) == ADDON then A:Initialize() end
        return
    end
    if not A.initialized then return end
    if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
        -- Cancel stale delayed work by a sequence stamp; group identity is rechecked.
        A.rosterRequest = (A.rosterRequest or 0) + 1
        local req = A.rosterRequest
        C_Timer.After(1.2, function()
            if A.rosterRequest == req then A:ScanRoster(event == "PLAYER_ENTERING_WORLD") end
        end)
    elseif event == "UNIT_LEVEL" or event == "PLAYER_ROLES_ASSIGNED" then
        A:ScanRoster(false)
    elseif event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" or event == "READY_CHECK_FINISHED" then
        if A.OnReadyCheckEvent then A:OnReadyCheckEvent(event, ...) end
    elseif event == "QUEST_LOG_UPDATE" then
        if A.ScheduleQuestSync then A:ScheduleQuestSync() end
    elseif event == "CHAT_MSG_ADDON" then
        if A.OnAddonMessage then A:OnAddonMessage(...) end
    end
end)

SLASH_FOREVERGROUPCOMMS1 = "/fgp"
SLASH_FOREVERGROUPCOMMS2 = "/forevergroup"
SlashCmdList.FOREVERGROUPCOMMS = function(input)
    if not A.initialized then return end
    local cmd = A:Key(input):match("^(%S+)") or ""
    if cmd == "" or cmd == "open" then A:ShowPanel()
    elseif cmd == "quests" or cmd == "quest" then A:ShowQuests()
    elseif cmd == "roles" then A:Quick("roles")
    elseif cmd == "ready" then A:Quick("ready")
    elseif cmd == "skull" then A:Quick("skullMark")
    elseif cmd == "moon" then A:Quick("moonMark")
    elseif cmd == "pull" or cmd == "mana" or cmd == "regroup" or cmd == "heal" or cmd == "cc" or cmd == "interrupt" then A:Quick(cmd)
    elseif cmd == "queue" or cmd == "review" then if _G.ForeverCommsVoice then _G.ForeverCommsVoice:ShowQueue(true) end
    elseif cmd == "settings" then A:OpenSettings()
    elseif cmd == "sync" then if A.ScheduleQuestSync then A:ScheduleQuestSync(true) end
    else A:Print("Commands: /fgp, quests, roles, ready, skull, moon, pull, mana, regroup, heal, cc, interrupt, sync, queue, settings") end
end
