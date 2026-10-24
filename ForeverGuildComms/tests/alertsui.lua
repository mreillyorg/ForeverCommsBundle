-- Run from the addon root: lua5.1 tests/alertsui.lua
--
-- The alerts window is part of the authorization path for public messages: its Review
-- button is how the player reaches the staged-message queue, and a row that shows a
-- stale sender would point the Whisper button at the wrong person. Until now no harness
-- loaded UI.lua at all, so none of the paging arithmetic was exercised.
--
-- The window has exactly 7 fixed rows and pages by index arithmetic; there is no row
-- pool and no scrolling. Every assertion below reads the mock's recorded Show/Hide and
-- SetText, so it checks what the player would actually see.
local base = (arg and arg[0] and arg[0]:match("^(.*[/\\])tests[/\\]alertsui%.lua$")) or "./"

local clock = 1000
_G.print = print
_G.StaticPopupDialogs, _G.SlashCmdList = {}, {}
_G.UnitName = function() return "Hero" end
_G.GetUnitName = function() return "Hero" end
_G.UnitGUID = function() return "Player-123" end
_G.UnitClass = function() return "Mage", "MAGE" end
_G.GetTime = function() clock = clock + 1; return clock end
_G.IsInGuild = function() return true end
_G.GetGuildInfo = function() return "TestGuild" end
_G.C_Timer = {
    After = function() end,
    -- Queue.lua keeps the handle and cancels it when the queue drains.
    NewTicker = function() return {Cancel = function() end} end,
}
_G.SendChatMessage = function() end
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end end
_G.ERR_GUILD_JOIN_S = "%s has joined the guild."
_G.date = function() return "12:00" end
_G.UIParent = {}
_G.ForeverGuildCommsDB, _G.ForeverGuildCommsCharDB = {}, {}
local whispered = {}
_G.ChatFrame_OpenChat = function(text) whispered[#whispered+1] = text end

-- Widget mock: the metatable pattern from tests/settings.lua, plus Show/Hide recorders
-- so row visibility can be asserted.
local widgets = {}
local noop = function() end
-- Deliberately NOT a catch-all __index. A metatable that returns a no-op function for
-- every unknown key also answers data reads: row.sender would come back as a function
-- instead of nil, and the "hidden rows forget their whisper target" assertions below
-- would pass against a broken addon. So only known method names resolve, and anything
-- else reads as a plain field. A method this list is missing fails loudly by name.
local plainMethods = {
    SetSize=true, SetPoint=true, SetWidth=true, SetHeight=true, SetMovable=true,
    EnableMouse=true, RegisterForDrag=true, SetFrameStrata=true, SetJustifyH=true,
    SetJustifyV=true, ClearAllPoints=true, SetAllPoints=true, SetAutoFocus=true,
    SetMaxLetters=true, ClearFocus=true, SetNumeric=true, SetVerticalScroll=true,
    Enable=true, SetAlpha=true, SetShown=true,
    -- Core.lua's event dispatcher is created through the same CreateFrame.
    RegisterEvent=true, UnregisterEvent=true, RegisterUnitEvent=true,
    RegisterForClicks=true, SetClampedToScreen=true, SetResizable=true,
}
local mt
local function newWidget(fields)
    local w = setmetatable(fields or {}, mt)
    widgets[#widgets+1] = w
    return w
end
mt = {__index = function(_, key)
    if key == 'SetText' then return function(self, text) self.text = text end end
    if key == 'GetText' then return function(self) return rawget(self, 'text') end end
    if key == 'SetChecked' then return function(self, v) self.checked = v end end
    if key == 'GetChecked' then return function(self) return rawget(self, 'checked') end end
    if key == 'SetScript' then return function(self, event, cb) self[event] = cb end end
    if key == 'Show' then return function(self) self.shown = true end end
    if key == 'Hide' then return function(self) self.shown = false end end
    if key == 'Disable' then return function(self) self.disabled = true end end
    if key == 'HasFocus' then return function() return false end end
    if key == 'CreateFontString' then return function() return newWidget() end end
    if key == 'CreateTexture' then return function() return newWidget() end end
    if plainMethods[key] then return noop end
    return nil
end}
_G.CreateFrame = function(kind, name, parent, template)
    local w = newWidget({kind=kind, name=name, parent=parent, template=template})
    -- A real BasicFrameTemplateWithInset exposes TitleText as a FontString, and UI.lua
    -- indexes it, so it has to be a widget rather than a bare field.
    w.TitleText = newWidget()
    return w
end

-- Core.lua refuses to load without the library, which the TOC guarantees in game. A bare
-- table satisfies that load-time guard; the real library replaces it a few lines below.
_G.ForeverCommsVoice = {}
local A = {}
assert(loadfile(base .. "Core.lua"))("ForeverGuildComms", A)
local V = {}
local voicePath = (os.getenv and os.getenv("FOREVER_VOICE_PATH")) or (base .. "../ForeverCommsVoice/")
-- Queue.lua is included because the Review shortcut counts the shared queue. QueueUI.lua
-- is left out on purpose: Queue.lua guards its ShowQueue call, so the count is asserted
-- without dragging in the overlay's widgets.
for _, mod in ipairs({"Core.lua", "Languages.lua", "Accents.lua", "RaceProfiles.lua",
                      "MessageVariants.lua", "GroupPhrases.lua", "Queue.lua"}) do
    assert(loadfile(voicePath .. mod))("ForeverCommsVoice", V)
end
_G.ForeverCommsVoice = V
assert(loadfile(base .. "VoiceBridge.lua"))("ForeverGuildComms", A)
assert(loadfile(base .. "Alerts.lua"))("ForeverGuildComms", A)
assert(loadfile(base .. "UI.lua"))("ForeverGuildComms", A)

A:Initialize()
-- Silence the addon's chat output; AddAlert prints every alert and this harness seeds
-- dozens, which would bury the suite's own output.
A.Print = function() end
-- Broker.lua is not loaded here, and UI.lua's Clear handler calls A:UpdateBroker()
-- without the existence guard the rest of the bundle uses. Harmless in game because
-- Broker.lua is always in the TOC, but it has to be stubbed to drive Clear offline.
A.UpdateBroker = function() end

assert(A.alertRows, "BuildUI must have created the alert rows")
assert(#A.alertRows == 7, "the window is built with exactly 7 rows, got " .. #A.alertRows)
assert(A.alertPage == 1, "paging starts on page 1")

local function button(label)
    for _, w in ipairs(widgets) do
        if w.kind == "Button" and w.text == label then return w end
    end
    error("no button labelled '" .. label .. "'")
end
local function click(label)
    local b = button(label)
    assert(b.OnClick, "button '" .. label .. "' has no OnClick handler")
    b.OnClick(b)
end
local function visibleRows()
    local shown = {}
    for _, row in ipairs(A.alertRows) do
        if row.shown then shown[#shown+1] = row end
    end
    return shown
end
-- Alerts are newest-first, so seeding N of them puts "alert N" on top.
local function seed(count)
    wipe(A.alerts)
    wipe(A.eventsSeen)
    for i = 1, count do
        A:AddAlert("Group request", "Sender" .. i, "alert " .. i)
    end
    A.alertPage = 1
    A:UpdateAlertsUI()
end

-- An empty list still reports one page and hides every row.
seed(0)
assert(#visibleRows() == 0, "no rows are shown when there are no alerts")
assert(A.alertPageText.text == "Page 1 of 1", "empty list reads as one page, got " ..
    tostring(A.alertPageText.text))
for _, row in ipairs(A.alertRows) do
    assert(row.sender == nil, "a hidden row must not retain a whisper target")
end

-- A partial page shows only as many rows as there are alerts.
seed(3)
assert(#visibleRows() == 3, "3 alerts fill 3 rows, got " .. #visibleRows())
assert(A.alertPageText.text == "Page 1 of 1", "3 alerts is still one page")
assert(A.alertRows[1].message.text == "alert 3", "newest alert is on top, got " ..
    tostring(A.alertRows[1].message.text))
assert(A.alertRows[1].sender == "Sender3", "row carries its own sender")
assert(A.alertRows[4].sender == nil, "unused rows are cleared and hidden")

-- Exactly one full page must not report a second, empty page.
seed(7)
assert(#visibleRows() == 7, "7 alerts fill the page")
assert(A.alertPageText.text == "Page 1 of 1", "exactly 7 alerts is one page, got " ..
    tostring(A.alertPageText.text))

-- One more alert opens a second page holding the single oldest entry.
seed(8)
assert(A.alertPageText.text == "Page 1 of 2", "8 alerts spans two pages")
assert(A.alertRows[1].message.text == "alert 8", "page 1 starts at the newest")
click("Next >")
assert(A.alertPage == 2, "Next advances the page")
assert(#visibleRows() == 1, "page 2 holds the one remaining alert, got " .. #visibleRows())
assert(A.alertRows[1].message.text == "alert 1", "page 2 shows the oldest alert, got " ..
    tostring(A.alertRows[1].message.text))
assert(A.alertPageText.text == "Page 2 of 2", "page indicator follows")
-- Rows 2-7 were populated on page 1 and are now empty. They must have given up their
-- whisper targets, not merely been hidden: the Whisper button reads row.sender when it
-- is clicked, so a retained value would open a chat to whoever was last displayed there.
for i = 2, 7 do
    assert(A.alertRows[i].shown == false, "row " .. i .. " is hidden on a short page")
    assert(A.alertRows[i].sender == nil,
        "row " .. i .. " must forget its whisper target when hidden, still has " ..
        tostring(A.alertRows[i].sender))
end

-- Next past the end is clamped back by UpdateAlertsUI rather than showing a blank page.
click("Next >")
assert(A.alertPage == 2, "paging past the last page is clamped, got " .. A.alertPage)
assert(#visibleRows() == 1, "the clamped page still renders its row")

-- Prev is floored at page 1 and cannot reach 0.
click("< Prev")
assert(A.alertPage == 1, "Prev returns to page 1")
click("< Prev")
assert(A.alertPage == 1, "Prev is floored at page 1, got " .. A.alertPage)

-- Landing on a page that later disappears must not leave the user stranded.
seed(15)
assert(A.alertPageText.text == "Page 1 of 3", "15 alerts spans three pages")
click("Next >"); click("Next >")
assert(A.alertPage == 3, "reached the last page")
wipe(A.alerts)
A:UpdateAlertsUI()
assert(A.alertPage == 1, "emptying the list must pull the view back to page 1, got " ..
    A.alertPage)
assert(#visibleRows() == 0, "and show no rows")

-- The 30-entry cap means paging can never exceed 5 pages.
seed(40)
assert(#A.alerts == 30, "the alert list is capped at 30, got " .. #A.alerts)
assert(A.alertPageText.text == "Page 1 of 5", "30 alerts is five pages, got " ..
    tostring(A.alertPageText.text))
assert(A.alertRows[1].message.text == "alert 40", "the newest alert survives the cap")

-- Long alert text is truncated for display, and the underlying entry is left intact.
wipe(A.alerts); wipe(A.eventsSeen)
local long = string.rep("x", 120)
A:AddAlert("Craft: Thing", "Sender", long)
A.alertPage = 1
A:UpdateAlertsUI()
local shown = A.alertRows[1].message.text
assert(#shown == 78, "an over-long line is clipped to 78 characters, got " .. #shown)
assert(shown:sub(-3) == "...", "clipped text is marked with an ellipsis")
assert(A.alerts[1].text == long, "the stored alert keeps its full text")

-- The Whisper button targets the row's own sender and only opens the edit box.
seed(2)
A.alertRows[1].whisper.OnClick(A.alertRows[1].whisper)
assert(#whispered == 1 and whispered[1] == "/w Sender2 ",
    "whisper opens the chat box for that row's sender, got " .. tostring(whispered[1]))

-- Clear wipes the list, resets paging and does not send anything.
click("Clear")
assert(#A.alerts == 0, "Clear empties the alert list")
assert(A.alertPage == 1, "Clear resets paging")
assert(#visibleRows() == 0, "Clear hides every row")

-- The Review shortcut reflects the pending count from the shared queue.
A:UpdateApprovalsUI()
assert(A.reviewShortcut.text == "Review (0)", "empty queue shows zero, got " ..
    tostring(A.reviewShortcut.text))
assert(V:Enqueue({source="guild", kind="login", text="Welcome back, Alice!",
    send=function() return true end}), "staged a guild message in the shared queue")
A:UpdateAlertsUI()
assert(A.reviewShortcut.text == "Review (1)",
    "the shortcut counts the shared queue, got " .. tostring(A.reviewShortcut.text))
V:SkipAll("guild")

print("PASSED: 7 fixed rows, empty/partial/exact/overflow pages, Next clamped and Prev " ..
      "floored, page pulled back when the list empties, 30-cap bounds paging at 5, " ..
      "line clipped for display only, whisper targets its own row, Review counts the queue")
