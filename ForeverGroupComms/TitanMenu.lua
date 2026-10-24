local _, A = ...
-- LibDataBroker/Titan right-click context menus. Uses Blizzard MenuUtil when available.
local function Toggle(parent, key, label)
    parent:CreateCheckbox(label,
        function() return A.db and A.db[key] == true end,
        function()
            A.db[key] = not A.db[key]
            if key == "questSync" and A.db[key] and A.ScheduleQuestSync then A:ScheduleQuestSync(true) end
            if A.RefreshUI then A:RefreshUI() end
            if A.UpdateBroker then A:UpdateBroker() end
        end)
end
local function Action(parent, label, fn, enabled)
    local entry = parent:CreateButton(label, fn)
    if enabled == false and entry.SetEnabled then entry:SetEnabled(false) end
    return entry
end
function A:ReviewPanel()
    local voice = _G.ForeverCommsVoice
    if voice and voice.ShowQueue then voice:ShowQueue(true)
    else self:Print("ForeverCommsVoice review panel is unavailable.") end
end
function A:StatusSnapshot()
    local count = 0
    for _ in pairs(self.roster or {}) do count = count + 1 end
    local roles = self.RoleCounts and self:RoleCounts() or {}
    local voice = _G.ForeverCommsVoice
    local queued = 0
    if voice and voice.PendingCount then
        local ok, result = pcall(voice.PendingCount, voice, "group")
        if ok and type(result) == "number" then queued = result end
    end
    if queued == 0 then queued = #(self.approvals or {}) end
    return {count=count, roles=roles, queued=queued, grouped=self.activeGroup == true,
        channel=self.GroupChannel and self:GroupChannel() or nil,
        leader=self.CanManageGroup and self:CanManageGroup() or false}
end
function A:PopulateTitanMenu(root)
    if not self.db then return end
    local status = self:StatusSnapshot()
    root:CreateTitle("Forever Group Comms " .. (self.version or ""))
    Toggle(root, "enabled", "Enable addon")
    root:CreateDivider()

    local state = root:CreateButton("Group status: " .. (status.grouped and (status.count .. " players") or "Not grouped"))
    state:CreateTitle(status.grouped and ("Channel: " .. (status.channel or "Unknown")) or "Not in a party or raid")
    state:CreateTitle(string.format("Roles: %d tank / %d healer / %d DPS / %d unassigned",
        status.roles.TANK or 0, status.roles.HEALER or 0,
        status.roles.DAMAGER or 0, status.roles.NONE or 0))
    state:CreateTitle("Ready check / target marking: " .. (status.leader and "Available" or "Leader or assistant required"))
    state:CreateTitle("Pending group reviews: " .. status.queued)
    state:CreateTitle("Quest sync: " .. (self.db.questSync and "Enabled" or "Disabled"))
    Action(state, "Review roles", function() A:ReviewRoles(false) end, status.grouped)
    Action(state, "Compare quests", function() A:ShowQuests() end, status.grouped)
    Action(state, "Open Review Panel", function() A:ReviewPanel() end)

    local messages = root:CreateButton("Greetings & congratulations")
    Toggle(messages, "autoGreeting", "Automatically greet group members")
    Toggle(messages, "autoLevel", "Automatically congratulate level-ups")
    Toggle(messages, "randomMessages", "Vary built-in message wording")
    Toggle(messages, "useSharedVoice", "Use shared languages and accents")
    messages:CreateDivider()
    Action(messages, "Send group greeting", function() A:Quick("greet") end, status.grouped)
    Action(messages, "Quest sharing reminder", function() A:Quick("quests") end, status.grouped)

    local coordination = root:CreateButton("Dungeon coordination")
    for _, item in ipairs({
        {"Confirm roles", "roles"}, {"Start ready check", "ready"},
        {"Next pull", "pull"}, {"Mana break", "mana"},
        {"Regroup", "regroup"}, {"Wait for healer", "heal"},
        {"Coordinate interrupts", "interrupt"}, {"Crowd control moon", "cc"},
        {"Focus skull", "skull"},
    }) do
        local kind = item[2]
        Action(coordination, item[1], function() A:Quick(kind) end, status.grouped)
    end
    local marks = root:CreateButton("Target marking")
    Action(marks, "Mark target: skull", function() A:Quick("skullMark") end, status.leader)
    Action(marks, "Mark target: moon", function() A:Quick("moonMark") end, status.leader)

    local quests = root:CreateButton("Quest sharing & checks")
    Toggle(quests, "questSync", "Exchange quest data with addon users")
    Toggle(quests, "privateQuestReminder", "Private quest reminders")
    Toggle(quests, "privateRoleAlerts", "Private role alerts")
    quests:CreateDivider()
    Action(quests, "Compare quest logs", function() A:ShowQuests() end, status.grouped)
    Action(quests, "Request quest refresh", function()
        if A.ScheduleQuestSync then A:ScheduleQuestSync(true) end
    end, status.grouped)
    Action(quests, "Send quest sharing reminder", function() A:Quick("quests") end, status.grouped)

    local quick = root:CreateButton("Quick actions")
    Action(quick, "Open Review Panel", function() A:ReviewPanel() end)
    Action(quick, "Open group panel", function() A:ShowPanel() end)
    Action(quick, "Review roles", function() A:ReviewRoles(false) end, status.grouped)
    Action(quick, "Compare quests", function() A:ShowQuests() end, status.grouped)
    root:CreateDivider()
    Action(root, "Open Review Panel", function() A:ReviewPanel() end)
    Action(root, "Open group panel", function() A:ShowPanel() end)
    Action(root, "Settings...", function() A:OpenSettings() end)
    Action(root, "Voice & queue settings...", function()
        local voice = _G.ForeverCommsVoice
        if voice and voice.OpenOptions then voice:OpenOptions() end
    end)
end
function A:OpenTitanMenu(owner)
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        self:Print("Nested menus unavailable in this client; opening Settings instead.")
        self:OpenSettings()
        return
    end
    if not owner or not owner.GetObjectType then owner = UIParent end
    MenuUtil.CreateContextMenu(owner, function(_, root) A:PopulateTitanMenu(root) end)
end
