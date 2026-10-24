local _, A = ...
local function text(parent, label, x, y, width, height, font)
    local obj = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    obj:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    obj:SetWidth(width)
    if height then obj:SetHeight(height) end
    obj:SetJustifyH("LEFT")
    obj:SetJustifyV("TOP")
    obj:SetText(label)
    return obj
end
local function button(parent, label, x, y, width, height, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetSize(width, height or 26)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end
local function makeFrame(name, title, w, h)
    local f = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(w, h)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    if f.TitleText then f.TitleText:SetText(title) end
    f:Hide()
    return f
end
function A:BuildPanel()
    if self.panel then return end
    local f = makeFrame("ForeverGroupCommsPanel", "Forever Group Comms", 530, 435)
    self.panel = f
    self.groupSummaryLabel = text(f, "Not in a group", 18, -34, 490, 38, "GameFontHighlight")
    text(f, "Quick actions (click to send to your current group)", 18, -86, 490, 22, "GameFontNormal")
    local actions = {
        {"Check roles", "roles"}, {"Ready check", "ready"},
        {"Pull when ready", "pull"}, {"Mana break", "mana"},
        {"Regroup", "regroup"}, {"Wait for healer", "heal"},
        {"Focus skull", "skull"}, {"CC moon", "cc"},
        {"Interrupts", "interrupt"}, {"Quest reminder", "quests"},
        {"Mark skull target", "skullMark"}, {"Mark moon target", "moonMark"},
    }
    for i, action in ipairs(actions) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        button(f, action[1], 18 + 249 * col, -113 - row * 31, 238, 27, function()
            if action[2] == "quests" then A:Send("quests") else A:Quick(action[2]) end
        end)
    end
    self.roleLabel = text(f, "", 18, -318, 490, 56, "GameFontHighlightSmall")
    self.queueSummaryLabel = text(f,"",18,-373,300,25,"GameFontNormalSmall")
    button(f,"Review message queue",317,-370,188,25,function()
        if _G.ForeverCommsVoice then _G.ForeverCommsVoice:ShowQueue(true) end
    end)
    button(f, "Compare quests", 18, -402, 154, 25, function() A:ShowQuests() end)
    button(f, "Settings", 181, -402, 115, 25, function() A:OpenSettings() end)
    button(f, "Recheck roles", 307, -402, 197, 25, function() A:ReviewRoles(false); A:RefreshUI() end)
    f:SetScript("OnShow", function() A:RefreshUI() end)
end
function A:RefreshUI()
    if not self.panel then return end
    local count = 0
    for _ in pairs(self.roster) do count = count + 1 end
    self.groupSummaryLabel:SetText(self.activeGroup and
        (string.format("Group members: %d | %s\nQuest detection works best when everyone has ForeverGroupComms installed.",
            count, self:GroupChannel())) or "Not currently grouped. Quick actions become active inside a party or raid.")
    if self.activeGroup then
        local issues = self:RoleIssues()
        self.roleLabel:SetText("Roles: " .. self:RoleSummary() .. "\n" ..
            (#issues > 0 and ("Double-check: " .. table.concat(issues, "; ")) or "No obvious assignment gaps. Confirm unusual compositions manually."))
    else self.roleLabel:SetText("No group role data available.") end
    local voice=_G.ForeverCommsVoice
    local groupCount=voice and voice.PendingCount and voice:PendingCount("group") or #self.approvals
    self.queueSummaryLabel:SetText("Group messages waiting: " .. groupCount)
    if self.RefreshQuestUI then self:RefreshQuestUI() end
    if self.UpdateBroker then self:UpdateBroker() end
end
function A:ShowPanel()
    self:BuildPanel()
    if self.panel:IsShown() then self.panel:Hide() else self.panel:Show() end
end
function A:BuildQuests()
    if self.questsPanel then return end
    local f = makeFrame("ForeverGroupCommsQuests", "Group Quest Comparison", 735, 510)
    self.questsPanel = f
    self.questPage = 1
    self.questView = "mine"
    button(f, "Switch view", 604, -72, 110, 25, function()
        A.questView = A.questView == "mine" and "others" or "mine"
        A.questPage = 1
        A:RefreshQuestUI()
    end)
    text(f, "Missing = confirmed absent from active quests and completed history. Unknown = no current addon reply.", 18, -35, 686, 36, "GameFontHighlightSmall")
    self.questStats = text(f, "", 18, -76, 690, 25, "GameFontNormal")
    self.questLines = {}
    for i = 1, 9 do
        local y = -105 - (i - 1)*40
        local title = text(f, "", 18, y, 580, 18, "GameFontHighlight")
        local info = text(f, "", 18, y - 18, 600, 20, "GameFontHighlightSmall")
        local share = button(f, "Share", 627, y - 2, 87, 27, function()
            local row = A.questLines[i].data
            if row then
                if A.questView == "others" then A:RequestQuest(row.id) else A:ShareQuest(row.id) end
            end
        end)
        self.questLines[i] = {title=title, info=info, share=share}
    end
    button(f, "< Previous", 18, -473, 110, 25, function() A.questPage = math.max(1, A.questPage - 1); A:RefreshQuestUI() end)
    self.questPager = text(f, "", 149, -477, 250, 24, "GameFontHighlightSmall")
    button(f, "Next >", 386, -473, 110, 25, function() A.questPage = A.questPage + 1; A:RefreshQuestUI() end)
    button(f, "Refresh / sync", 516, -473, 198, 25, function()
        A:ScheduleQuestSync(true)
        A:RefreshQuestUI()
    end)
    f:SetScript("OnShow", function() A:RefreshQuestUI() end)
end
function A:RefreshQuestUI()
    if not self.questsPanel or not self.questsPanel:IsShown() then return end
    local mine = self.questView ~= "others"
    local rows = mine and self:QuestRows() or self:OtherQuestRows()
    local pages = math.max(1, math.ceil(#rows / 9))
    self.questPage = math.min(math.max(self.questPage or 1, 1), pages)
    local known, unknown = 0, 0
    if mine then
        for _, row in ipairs(rows) do known = known + #row.missing; unknown = unknown + #row.unknown end
        self.questStats:SetText(string.format("YOUR QUESTS: %d | missing: %d | unknown: %d", #rows, known, unknown))
    else
        self.questStats:SetText(string.format("THEIR QUESTS YOU LACK: %d (active for other members)", #rows))
    end
    self.questPager:SetText(string.format("Page %d/%d", self.questPage, pages))
    for i, widgets in ipairs(self.questLines) do
        local row = rows[(self.questPage - 1)*9 + i]
        widgets.data = row
        if row then
            widgets.title:SetText(row.title .. "  |cff888888(#" .. row.id .. ")|r")
            if mine then
                local status = row.pushable == false and "Not shareable" or (row.pushable == nil and "Shareability unknown" or "Shareable")
                local details = "Missing " .. #row.missing .. ", has " .. #row.shared .. ", done " .. #row.completed .. ", unknown " .. #row.unknown .. " | " .. status
                if #row.missing > 0 then details = details .. " | missing: " .. table.concat(row.missing, ", ") end
                widgets.info:SetText(A:Trim(details))
                widgets.share:SetText("Share")
                widgets.share:SetEnabled(row.pushable ~= false)
            else
                widgets.info:SetText("Has quest: " .. table.concat(row.holders, ", ") .. " | Ask, don't automatically accept")
                widgets.share:SetText("Ask")
                widgets.share:SetEnabled(true)
            end
            widgets.share:SetShown(true)
        else
            widgets.title:SetText("")
            widgets.info:SetText("")
            widgets.share:SetShown(false)
        end
    end
end
function A:ShowQuests()
    self:BuildQuests()
    if self.questsPanel:IsShown() then self.questsPanel:Hide() else self.questsPanel:Show() end
end
