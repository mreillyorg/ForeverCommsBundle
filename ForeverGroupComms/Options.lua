local _, A = ...
local options = {
    {"enabled", "Enable Forever Group Comms", "Turn off message sending and private notifications."},
    {"autoGreeting", "Automatically greet new groups and members", "Off by default. Otherwise each greeting is shown for click-to-send review."},
    {"autoLevel", "Automatically congratulate level-ups", "Off by default. Only group members whose level changes while grouped are eligible."},
    {"useSharedVoice", "Use ForeverCommsVoice for group messages", "Uses the shared character language and accent. Disable for original English messages."},
    {"randomMessages", "Rotate built-in messages", "Avoid repeating the same wording twice in a row."},
    {"privateRoleAlerts", "Private role double-check alerts", "Spot missing or duplicate tank/healer assignments. Never changes anyone's role."},
    {"privateQuestReminder", "Private quest-sharing reminder", "On group roster changes, suggest checking dungeon quests without spamming group chat."},
    {"questSync", "Share active quest IDs with other Group Comms users", "Enables opt-in addon data exchange. Other users must also have this enabled for full detection."},
}
local controls = {}
function A:BuildOptions()
    if self.settingsCategory then return end
    wipe(controls)
    local f = CreateFrame("Frame")
    f.name = "Forever Group Comms"
    f:SetSize(550, 675)
    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -18)
    title:SetText("Forever Group Comms")
    local note = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 20, -49)
    note:SetWidth(480)
    note:SetJustifyH("LEFT")
    note:SetText("Group greetings, coordination and quest comparison. Manual quick actions send only after a click.")
    local y = -81
    for _,opt in ipairs(options) do
        local key = opt[1]
        local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 16, y)
        cb:SetSize(24,24)
        cb:SetChecked(self.db[key])
        cb:SetScript("OnClick", function(self)
            local old = A.db[key]
            A.db[key] = self:GetChecked() == true
            if key == "questSync" and not old and A.db[key] then A:ScheduleQuestSync(true) end
            if A.RefreshUI then A:RefreshUI() end
        end)
        controls[#controls+1] = function() cb:SetChecked(A.db[key] == true) end
        local label = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("TOPLEFT", 48, y - 4)
        label:SetWidth(458)
        label:SetJustifyH("LEFT")
        label:SetText(opt[2])
        local hint = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 48, y - 25)
        hint:SetWidth(455)
        hint:SetJustifyH("LEFT")
        hint:SetText(opt[3])
        y = y - 54
    end
    local openVoice = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    openVoice:SetSize(290,25)
    openVoice:SetPoint("TOPLEFT",18,y-3)
    openVoice:SetText("Configure shared language and accent")
    openVoice:SetScript("OnClick", function()
        if _G.ForeverCommsVoice then _G.ForeverCommsVoice:OpenOptions() end
    end)
    -- Canvas callbacks. Without OnRefresh the checkboxes keep whatever value they had
    -- when the panel was built, so a setting changed from the Titan menu or a slash
    -- command would display stale here.
    function f.OnRefresh()
        for _, refresh in ipairs(controls) do refresh() end
    end
    -- OnCommit is intentionally absent: every control writes to A.db on click, so there
    -- is no deferred edit to flush. Add one if an edit box is ever introduced.
    function f.OnDefault()
        -- Scoped to this addon's own account settings. The shared language and accent
        -- live in ForeverCommsVoiceCharDB and belong to /fcv, not here.
        for key, value in pairs(A.defaults) do A.db[key] = value end
        f.OnRefresh()
        if A.RefreshUI then A:RefreshUI() end
        if A.UpdateBroker then A:UpdateBroker() end
    end
    self.optionsPanel = f
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(f, f.name)
        Settings.RegisterAddOnCategory(category)
        self.settingsCategory = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(f)
    end
end
function A:RefreshOptions()
    if self.optionsPanel and self.optionsPanel.OnRefresh then self.optionsPanel.OnRefresh() end
end
