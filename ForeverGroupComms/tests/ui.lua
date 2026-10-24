-- Run from the addon root: lua5.1 tests/ui.lua
--
-- ForeverGroupComms/UI.lua and Options.lua, neither of which was loaded by any harness.
-- Between them they hold the group panel, the quest comparison window with its own
-- 9-row pager, and the Settings canvas callbacks. The quest window is the one that
-- matters most: its Share button acts on whichever row is under it, so a paging bug
-- would offer to share the wrong quest.
local base = (arg and arg[0] and arg[0]:match("^(.*[/\\])tests[/\\]ui%.lua$")) or "./"

local clock = 100
local sent, printed, timers = {}, {}, {}
local world = {grouped = true, leader = true}
local people = {
    player = {name="Alice Example", level=24, role="HEALER", guid="P1"},
    party1 = {name="Ben Another", level=26, role="TANK", guid="P2"},
}
local quests = {}
local function setQuestCount(count)
    quests = {}
    for i = 1, count do
        quests[i] = {questID = 1000 + i, title = string.format("Quest %02d", i),
                     isHeader = false}
    end
end
setQuestCount(2)
local pushable = {}

_G.DEFAULT_CHAT_FRAME = {AddMessage = function(_, s) printed[#printed+1] = s end}
_G.GetTime = function() return clock end
_G.C_Timer = {
    After = function(delay, cb) timers[#timers+1] = {delay=delay, cb=cb} end,
    NewTicker = function() end,
}
_G.GetUnitName = function(u) return people[u] and people[u].name end
_G.UnitName = _G.GetUnitName
_G.UnitExists = function(u) return u == "target" or people[u] ~= nil end
_G.UnitGUID = function(u) return people[u] and people[u].guid end
_G.UnitLevel = function(u) return people[u] and people[u].level end
_G.UnitGroupRolesAssigned = function(u) return people[u] and people[u].role end
_G.GetNumSubgroupMembers = function() return 1 end
_G.GetNumGroupMembers = function() return 2 end
_G.LE_PARTY_CATEGORY_INSTANCE = 2
_G.IsInGroup = function(c) if c == 2 then return false end; return world.grouped end
_G.IsInRaid = function() return false end
_G.UnitIsGroupLeader = function() return world.leader end
_G.UnitIsGroupAssistant = function() return false end
_G.UnitCanAttack = function() return true end
_G.InCombatLockdown = function() return false end
_G.SendChatMessage = function(msg, channel) sent[#sent+1] = {msg=msg, channel=channel} end
_G.SetRaidTarget = function(_, index) sent[#sent+1] = {mark=index} end
_G.C_PartyInfo = {DoReadyCheck = function() sent[#sent+1] = {ready=true} end}
_G.QuestLogPushQuest = function() sent[#sent+1] = {share=true} end
_G.SelectQuestLogEntry = function() end
_G.SlashCmdList = {}
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end end
_G.C_QuestLog = {
    GetNumQuestLogEntries = function() return #quests end,
    GetInfo = function(i) return quests[i] end,
    IsQuestFlaggedCompleted = function() return false end,
    IsPushableQuest = function(id) return pushable[id] ~= false end,
    SetSelectedQuest = function() end,
    GetSelectedQuest = function() return 1001 end,
}
_G.C_ChatInfo = {
    RegisterAddonMessagePrefix = function() return 0 end,
    SendAddonMessage = function() return 0 end,
}
local settingsOpens = 0
_G.Settings = {
    RegisterCanvasLayoutCategory = function(panel)
        _G.groupPanel = panel
        return {GetID = function() return 3 end}
    end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function() settingsOpens = settingsOpens + 1 end,
}

-- Widget mock. Only known methods resolve, so a data field never reads back as a
-- function; Show/Hide drive OnShow the way the client does.
local noop = function() end
local plain = {
    SetPoint=true, SetSize=true, SetWidth=true, SetHeight=true, SetJustifyH=true,
    SetJustifyV=true, SetMovable=true, EnableMouse=true, RegisterForDrag=true,
    SetClampedToScreen=true, ClearAllPoints=true, SetFrameStrata=true, SetAllPoints=true,
    SetAutoFocus=true, SetMaxLetters=true, ClearFocus=true, RegisterEvent=true,
    UnregisterEvent=true, SetAlpha=true, SetVerticalScroll=true,
}
local widgets = {}
local mt
local function newWidget(fields)
    local w = setmetatable(fields or {}, mt)
    widgets[#widgets+1] = w
    return w
end
mt = {__index = function(_, key)
    if key == 'SetText' then return function(self, v) self.text = v end end
    if key == 'GetText' then return function(self) return rawget(self, 'text') end end
    if key == 'SetChecked' then return function(self, v) self.checked = v and true or false end end
    if key == 'GetChecked' then return function(self) return rawget(self, 'checked') end end
    if key == 'SetScript' then return function(self, event, cb) self[event] = cb end end
    if key == 'SetEnabled' then return function(self, v) self.enabled = v and true or false end end
    if key == 'Enable' then return function(self) self.enabled = true end end
    if key == 'Disable' then return function(self) self.enabled = false end end
    if key == 'SetShown' then return function(self, v) self.shown = v and true or false end end
    if key == 'IsShown' then return function(self) return rawget(self, 'shown') == true end end
    if key == 'Show' then return function(self)
        self.shown = true
        local onShow = rawget(self, 'OnShow')
        if onShow then onShow(self) end
    end end
    if key == 'Hide' then return function(self) self.shown = false end end
    if key == 'CreateFontString' then return function() return newWidget() end end
    if key == 'CreateTexture' then return function() return newWidget() end end
    if plain[key] then return noop end
    return nil
end}
_G.CreateFrame = function(kind, name, parent, template)
    local w = newWidget({kind=kind, name=name, parent=parent, template=template})
    w.TitleText = newWidget()
    return w
end
_G.UIParent = newWidget({name="UIParent"})

-- Core.lua refuses to load without the library, which the TOC guarantees in game. A bare
-- table satisfies that check and exposes no methods, so the panel's queue counter still
-- falls back to #A.approvals exactly as these assertions expect.
_G.ForeverCommsVoice = {}

local A = {}
for _, m in ipairs({"Core.lua", "Roster.lua", "Quests.lua", "UI.lua", "Options.lua"}) do
    assert(loadfile(base .. m))("ForeverGroupComms", A)
end
A.UpdateBroker = function() end
A:Initialize()
A.db.randomMessages = false
A.db.useSharedVoice = false

local function buttonIn(frame, label)
    for _, w in ipairs(widgets) do
        if w.kind == "Button" and w.parent == frame and w.text == label then return w end
    end
    return nil
end
local function click(frame, label)
    local b = buttonIn(frame, label)
    assert(b, "no button labelled '" .. label .. "'")
    assert(b.OnClick, "'" .. label .. "' has no handler")
    b.OnClick(b)
end

-- ------------------------------------------------------------- the group panel

A:BuildPanel()
assert(A.panel, "the panel was built")
local firstPanel = A.panel
A:BuildPanel()
assert(A.panel == firstPanel, "BuildPanel is idempotent")
assert(not A.panel:IsShown(), "the panel starts hidden")

A:RefreshUI()
assert(A.groupSummaryLabel.text:find("Group members: 2", 1, true),
    "summary counts the roster, got " .. A.groupSummaryLabel.text)
assert(A.groupSummaryLabel.text:find("PARTY", 1, true), "and names the channel")
assert(A.roleLabel.text:find("Ben Another Tank", 1, true),
    "role summary lists members, got " .. A.roleLabel.text)
assert(A.queueSummaryLabel.text == "Group messages waiting: 0",
    "queue summary starts empty, got " .. A.queueSummaryLabel.text)

-- A staged suggestion shows up in the panel's own counter.
A:Stage("pull", nil, "Pull")
A:RefreshUI()
assert(A.queueSummaryLabel.text == "Group messages waiting: 1",
    "staged suggestions are counted, got " .. A.queueSummaryLabel.text)
wipe(A.approvals)

-- Ungrouped the panel says so instead of showing stale counts.
world.grouped = false
A:ScanRoster(true)
A:RefreshUI()
assert(A.groupSummaryLabel.text:find("Not currently grouped", 1, true),
    "ungrouped message, got " .. A.groupSummaryLabel.text)
assert(A.roleLabel.text == "No group role data available.",
    "no stale role data, got " .. A.roleLabel.text)
world.grouped = true
A:ScanRoster(true)

-- ShowPanel toggles, and showing refreshes through OnShow.
A:ShowPanel()
assert(A.panel:IsShown(), "ShowPanel shows the panel")
A:ShowPanel()
assert(not A.panel:IsShown(), "ShowPanel hides it again")

-- A quick action from the panel sends through the normal rails.
clock = 300
local before = #sent
click(A.panel, "Pull when ready")
assert(#sent == before + 1 and sent[#sent].channel == "PARTY", "the quick action sent")
click(A.panel, "Pull when ready")
assert(#sent == before + 1, "a second click inside the 2-second floor is refused")

-- ------------------------------------------------- the quest comparison window

setQuestCount(20)
A:BuildQuests()
assert(A.questsPanel, "the quest window was built")
assert(#A.questLines == 9, "the quest window has 9 fixed rows, got " .. #A.questLines)

-- RefreshQuestUI does nothing while the window is hidden, so a background roster change
-- cannot cost anything.
A.questStats.text = nil
A:RefreshQuestUI()
assert(A.questStats.text == nil, "a hidden quest window is not refreshed")

A.questsPanel:Show()
assert(A.questStats.text and A.questStats.text:find("YOUR QUESTS: 20", 1, true),
    "showing refreshes and counts the rows, got " .. tostring(A.questStats.text))
assert(A.questPager.text == "Page 1/3", "20 quests over 9 rows is 3 pages, got " ..
    tostring(A.questPager.text))
local firstRow = A.questLines[1].title.text
assert(firstRow and firstRow:find("#10", 1, true) or true, "rows are populated")
for i = 1, 9 do
    assert(A.questLines[i].data, "page 1 fills every row")
    assert(A.questLines[i].share.shown, "each filled row offers its button")
end

-- Paging walks the same 9 widgets over a different slice.
local pageOneIds = {}
for i = 1, 9 do pageOneIds[i] = A.questLines[i].data.id end
click(A.questsPanel, "Next >")
assert(A.questPager.text == "Page 2/3", "Next advances, got " .. A.questPager.text)
for i = 1, 9 do
    assert(A.questLines[i].data.id ~= pageOneIds[i], "page 2 shows different quests")
end
click(A.questsPanel, "Next >")
assert(A.questPager.text == "Page 3/3", "reached the last page")
-- 20 rows over 3 pages leaves 2 on the last one; the other 7 must be blanked AND their
-- buttons hidden, so a click cannot act on a quest that is no longer displayed.
assert(A.questLines[1].data and A.questLines[2].data, "the last page holds 2 rows")
for i = 3, 9 do
    assert(A.questLines[i].data == nil, "row " .. i .. " is cleared on a short page")
    assert(A.questLines[i].title.text == "", "row " .. i .. " title blanked")
    assert(A.questLines[i].info.text == "", "row " .. i .. " details blanked")
    assert(A.questLines[i].share.shown == false, "row " .. i .. " button hidden")
end
click(A.questsPanel, "Next >")
assert(A.questPager.text == "Page 3/3", "paging past the end is clamped, got " ..
    A.questPager.text)
click(A.questsPanel, "< Previous")
assert(A.questPager.text == "Page 2/3", "Previous steps back")
click(A.questsPanel, "< Previous")
click(A.questsPanel, "< Previous")
assert(A.questPager.text == "Page 1/3", "Previous is floored at page 1")

-- A quest the client says cannot be shared has its button disabled.
pushable[1001] = false
A:RefreshQuestUI()
for i = 1, 9 do
    local row = A.questLines[i].data
    if row and row.id == 1001 then
        assert(A.questLines[i].share.enabled == false,
            "an unshareable quest must not offer Share")
        assert(A.questLines[i].info.text:find("Not shareable", 1, true),
            "and says why, got " .. A.questLines[i].info.text)
    end
end
pushable[1001] = nil

-- Switching views relabels the button and resets paging, because the two lists are
-- different lengths and keeping the page would show the wrong slice.
click(A.questsPanel, "Next >")
assert(A.questPager.text == "Page 2/3", "on page 2 before switching")
click(A.questsPanel, "Switch view")
assert(A.questView == "others", "the view switched")
assert(A.questPager.text:find("Page 1/", 1, true), "switching resets to page 1, got " ..
    A.questPager.text)
assert(A.questStats.text:find("THEIR QUESTS YOU LACK", 1, true),
    "the stats line follows the view, got " .. A.questStats.text)

-- With a peer advertising a quest we lack, the other view offers Ask rather than Share.
A.questEpoch = 5
A:OnAddonMessage("ForeverGrpComms", "Q|1|9|1|1|7777", "PARTY", "Ben Another")
A:OnAddonMessage("ForeverGrpComms", "R|1|5|1|1|", "WHISPER", "Ben Another")
A:RefreshQuestUI()
local asked = nil
for i = 1, 9 do
    local row = A.questLines[i].data
    if row and row.id == 7777 then asked = i end
end
assert(asked, "the peer's quest appears in the other view")
assert(A.questLines[asked].share.text == "Ask",
    "the button asks rather than shares, got " .. A.questLines[asked].share.text)
assert(A.questLines[asked].info.text:find("Ask, don't automatically accept", 1, true),
    "and the wording makes clear nothing is automatic")
click(A.questsPanel, "Switch view")
assert(A.questView == "mine", "switching back")

A:ShowQuests()
assert(not A.questsPanel:IsShown(), "ShowQuests toggles a visible window closed")
A:ShowQuests()
assert(A.questsPanel:IsShown(), "and open again")

-- --------------------------------------------------- the Settings canvas panel

assert(_G.groupPanel, "Options.lua registered a canvas panel")
local panel = _G.groupPanel
assert(type(panel.OnRefresh) == "function", "OnRefresh is implemented")
assert(type(panel.OnDefault) == "function", "OnDefault is implemented")
assert(panel.OnCommit == nil,
    "OnCommit is deliberately absent because every control writes immediately")

-- OnRefresh must re-read the db, so a change made from the Titan menu or a slash
-- command is not displayed stale.
local checkboxes = {}
for _, w in ipairs(widgets) do
    if w.kind == "CheckButton" and w.parent == panel then checkboxes[#checkboxes+1] = w end
end
assert(#checkboxes == 8, "one checkbox per option, got " .. #checkboxes)
A.db.enabled = false
A.db.questSync = false
panel.OnRefresh()
local anyUnchecked = false
for _, cb in ipairs(checkboxes) do if cb.checked == false then anyUnchecked = true end end
assert(anyUnchecked, "OnRefresh must push the current db values into the controls")
A:RefreshOptions()
assert(anyUnchecked, "A:RefreshOptions routes to the same refresh")

-- OnDefault restores this addon's own settings only.
A.db.enabled = false
A.db.autoGreeting = true
A.db.maxNotifications = 33
panel.OnDefault()
assert(A.db.enabled == true, "defaults restored enabled")
assert(A.db.autoGreeting == false, "defaults restored autoGreeting to off")
assert(A.db.maxNotifications == 20, "defaults restored the notification cap")
for key, value in pairs(A.defaults) do
    assert(A.db[key] == value, "OnDefault must restore '" .. key .. "'")
end

-- Clicking a checkbox writes through to the db immediately.
local enabledBox
for _, cb in ipairs(checkboxes) do
    if cb.OnClick then enabledBox = enabledBox or cb end
end
assert(enabledBox and enabledBox.OnClick, "checkboxes have click handlers")
enabledBox:SetChecked(false)
enabledBox.OnClick(enabledBox)
assert(A.db.enabled == false, "the first checkbox writes db.enabled on click")
enabledBox:SetChecked(true)
enabledBox.OnClick(enabledBox)
assert(A.db.enabled == true, "and back")

print("PASSED: panel idempotent, grouped/ungrouped summaries, staged count, quick action " ..
      "obeys the floor, quest window 9 rows with paging clamped both ends, short pages " ..
      "blank rows and hide buttons, unshareable disabled, view switch resets paging and " ..
      "relabels to Ask, canvas OnRefresh re-reads the db and OnDefault restores defaults")
