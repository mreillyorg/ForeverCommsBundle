local _, A = ...

local function Label(parent, text, x, y, width, size)
    local label = parent:CreateFontString(nil, "OVERLAY", size or "GameFontNormal")
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(width or 400)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end
local function Button(parent, text, x, y, width, callback)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, 23)
    btn:SetPoint("TOPLEFT", x, y)
    btn:SetText(text)
    btn:SetScript("OnClick", callback)
    return btn
end
local function Check(parent, title, x, y, checked, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetChecked(checked)
    Label(parent, title, x+27, y-4, 95, "GameFontHighlightSmall")
    cb:SetScript("OnClick", function(self) onClick(self:GetChecked()) end)
    return cb
end
function A:BuildUI()
    local alerts = CreateFrame("Frame", "FGCAlertsFrame", UIParent, "BasicFrameTemplateWithInset")
    alerts:SetSize(570, 440)
    alerts:SetPoint("CENTER")
    alerts:SetMovable(true)
    alerts:EnableMouse(true)
    alerts:RegisterForDrag("LeftButton")
    alerts:SetScript("OnDragStart", alerts.StartMoving)
    alerts:SetScript("OnDragStop", alerts.StopMovingOrSizing)
    alerts:SetFrameStrata("DIALOG")
    if alerts.TitleText then alerts.TitleText:SetText("Forever Guild Comms") end
    Label(alerts, "Recent guild requests (alerts stay private)", 17, -42, 480)
    local rows = {}
    for i = 1, 7 do
        local row = CreateFrame("Frame", nil, alerts)
        row:SetSize(532, 43)
        row:SetPoint("TOPLEFT", 18, -71-(i-1)*43)
        row.title = Label(row, "", 0, 0, 400, "GameFontNormalSmall")
        row.message = Label(row, "", 0, -16, 432, "GameFontHighlightSmall")
        row.whisper = Button(row, "Whisper", 441, -4, 80, function()
            if row.sender then ChatFrame_OpenChat("/w " .. row.sender .. " ") end
        end)
        rows[i] = row
    end
    self.alertFrame = alerts
    self.alertRows = rows
    self.alertPage = 1
    self.alertPageText = Label(alerts, "", 412, -45, 130, "GameFontHighlightSmall")
    Button(alerts, "< Prev", 18, -380, 80, function()
        A.alertPage = math.max(1, A.alertPage-1)
        A:UpdateAlertsUI()
    end)
    Button(alerts, "Next >", 455, -380, 80, function()
        A.alertPage = A.alertPage + 1
        A:UpdateAlertsUI()
    end)
    Button(alerts, "Clear", 388, -380, 59, function()
        wipe(A.alerts)
        A.alertPage = 1
        A:UpdateAlertsUI()
        A:UpdateBroker()
    end)
    Button(alerts, "Ask for Help", 249, -380, 130, function()
        alerts:Hide()
        A:ShowRequest()
    end)
    self.reviewShortcut = Button(alerts, "Review (0)", 110, -380, 130, function()
        A:ShowApprovals()
    end)
    alerts:Hide()
    self:BuildApprovalsUI()
    self:BuildRequestUI()
    self:UpdateAlertsUI()
end
function A:UpdateAlertsUI()
    if self.reviewShortcut then
        self.reviewShortcut:SetText("Review (" .. self:ApprovalCount() .. ")")
    end
    if not self.alertRows then return end
    local pages = math.max(1, math.ceil(#self.alerts / 7))
    self.alertPage = math.min(self.alertPage, pages)
    self.alertPageText:SetText("Page " .. self.alertPage .. " of " .. pages)
    for i, row in ipairs(self.alertRows) do
        local entry = self.alerts[(self.alertPage-1)*7+i]
        if entry then
            row:Show()
            row.sender = entry.sender
            row.title:SetText((entry.time or "") .. "  " .. entry.kind .. " | " .. entry.sender)
            local line = entry.text or ""
            row.message:SetText(#line > 78 and line:sub(1, 75) .. "..." or line)
        else
            row.sender = nil
            row:Hide()
        end
    end
end
function A:ShowAlerts()
    if self.alertFrame then self:UpdateAlertsUI(); self.alertFrame:Show() end
end
-- Shared review queue owned by ForeverCommsVoice; no duplicate Guild window.
function A:BuildApprovalsUI() end
function A:UpdateApprovalsUI()
    if self.reviewShortcut then self.reviewShortcut:SetText("Review (" .. self:ApprovalCount() .. ")") end
end
function A:ShowApprovals()
    local voice = _G.ForeverCommsVoice
    if voice and voice.ShowQueue then voice:ShowQueue(true)
    else self:Print("ForeverCommsVoice review queue is unavailable.") end
end
function A:BuildRequestUI()
    local f = CreateFrame("Frame", "FGCRequestFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(518, 390)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    if f.TitleText then f.TitleText:SetText("Ask Guild for Help") end
    Label(f, "Activity (dungeon, raid, or quest name):", 22, -44, 400)
    local activity = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    activity:SetPoint("TOPLEFT", 28, -71)
    activity:SetSize(440, 25)
    activity:SetAutoFocus(false)
    activity:SetMaxLetters(100)
    activity:SetScript("OnEscapePressed", activity.ClearFocus)
    activity:SetScript("OnEnterPressed", activity.ClearFocus)
    self.activityEdit = activity
    Label(f, "Activity type:", 22, -117, 150)
    local types = {"Dungeon", "Raid", "Quest"}
    local currentType = 1
    local typeBtn = Button(f, types[currentType] .. "  >", 178, -111, 147, function(btn)
        currentType = currentType % #types + 1
        btn:SetText(types[currentType] .. "  >")
        A:UpdateRequestPreview()
    end)
    self.GetActivityType = function() return types[currentType] end
    self.roleChecks = {}
    Label(f, "My roles (available for your class):", 22, -164, 410)
    for i, role in ipairs(self.roleOrder) do
        local can = (self.classRoles[self.playerClass] or {})[role]
        local checkbox = Check(f, self.roleNames[role], 23+(i-1)*155, -185,
            self.char.myRoles[role], function(checked)
                A.char.myRoles[role] = checked
                A:UpdateRequestPreview()
            end)
        if not can then checkbox:Disable() end
        self.roleChecks[role] = checkbox
    end
    self.needChecks = {}
    Label(f, "Roles you want to recruit (none = any):", 22, -229, 410)
    for i, role in ipairs(self.roleOrder) do
        self.needChecks[role] = Check(f, self.roleNames[role], 23+(i-1)*155, -251,
            self.char.needRoles[role], function(checked)
                A.char.needRoles[role] = checked
                A:UpdateRequestPreview()
            end)
    end
    Label(f, "Guild message preview:", 22, -290, 440)
    local preview = Label(f, "", 22, -310, 472, "GameFontHighlightSmall")
    preview:SetHeight(44)
    preview:SetJustifyV("TOP")
    self.requestPreview = preview
    Button(f, "Send to Guild", 289, -355, 135, function()
        A:SendHelpRequest()
    end)
    Button(f, "Cancel", 75, -355, 110, function() f:Hide() end)
    activity:SetScript("OnTextChanged", function() A:UpdateRequestPreview() end)
    self.requestFrame = f
    f:Hide()
    self:UpdateRequestPreview()
end
function A:RequestText()
    local activity = (self.activityEdit:GetText() or ""):match("^%s*(.-)%s*$")
    if activity == "" then activity = "[activity]" end
    local custom = self.db.templates.help ~= self.defaults.templates.help
    local vars = {
        activity = activity,
        type = custom and self.GetActivityType() or self:LocalizeActivityType(self.GetActivityType()),
        myroles = custom and self:RoleText(self.char.myRoles, "Flexible") or self:LocalizeRoleText(self.char.myRoles, "flexible"),
        needed = custom and self:RoleText(self.char.needRoles, "Any role") or self:LocalizeRoleText(self.char.needRoles, "any"),
        name = self.playerName,
    }
    local voice = self.char.voice or {}
    local fingerprint = table.concat({
        tostring(self.db.templates.help), tostring(self.db.randomizeMessages),
        tostring(voice.language), tostring(voice.accent),
        tostring(voice.raceFilter), tostring(voice.accentStrength),
        tostring(vars.activity), tostring(vars.type), tostring(vars.myroles),
        tostring(vars.needed), tostring(vars.name),
    }, "\031")
    -- The Send button must send exactly the wording shown in the preview.
    -- Redraws/reopened Settings should never silently change a pending draft.
    if not self.requestDraft or self.requestDraft.fingerprint ~= fingerprint then
        self.requestDraft = {fingerprint=fingerprint, text=self:CommsText("help", vars)}
    end
    return self.requestDraft.text
end
function A:UpdateRequestPreview()
    if self.requestPreview and self.db then self.requestPreview:SetText(self:RequestText()) end
end
function A:ShowRequest()
    if not self.requestFrame then return end
    self.requestDraft = nil -- new opening, fresh format choice
    self:UpdateRequestPreview()
    self.requestFrame:Show()
end
function A:SendHelpRequest()
    if not self:CanUse() then self:Print("You must be in a guild to send a request."); return end
    local activity = (self.activityEdit:GetText() or ""):match("^%s*(.-)%s*$")
    if activity == "" then self:Print("Enter an activity before sending."); return end
    if self.lastManualRequest and self:Now() - self.lastManualRequest < 20 then
        self:Print("Wait 20 seconds between guild requests.")
        return
    end
    if self:SendGuild(self:RequestText()) then
        self.lastManualRequest = self:Now()
        self.requestDraft = nil
        self.requestFrame:Hide()
    end
end
