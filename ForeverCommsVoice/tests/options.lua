-- Run from the addon root: lua5.1 tests/options.lua
--
-- ForeverCommsVoice/Options.lua, which no harness loaded. It owns the only UI for the
-- shared per-character profile both consumer addons read, so a control that writes the
-- wrong key changes how GuildComms AND GroupComms speak.
--
-- It also carries the regression test for a real defect: the ADDON_LOADED handler used
-- to compare the event's addon name against a bare `ADDON`, which is nil in any file
-- following the `local _, V = ...` module pattern. The comparison never matched, so the
-- panel was never registered and Forever Comms Voice had no Settings entry until the
-- player typed /fcv. The fix compares V.name; the last block here pins it.
local base = (arg and arg[0] and arg[0]:match("^(.*[/\\])tests[/\\]options%.lua$")) or "./"

local clock = 100
_G.SlashCmdList = {}
_G.GetTime = function() return clock end
_G.C_Timer = {
    After = function() end,
    NewTicker = function() return {Cancel = function() end} end,
}
_G.UnitRace = function() return "Human", "Human", 1 end
_G.UnitName = function() return "Hero" end
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end end
_G.ForeverCommsVoiceCharDB = {}

local noop = function() end
local plain = {
    SetPoint=true, SetSize=true, SetWidth=true, SetHeight=true, SetJustifyH=true,
    SetJustifyV=true, ClearAllPoints=true, SetAutoFocus=true, SetMaxLetters=true,
    ClearFocus=true, RegisterEvent=true, UnregisterEvent=true, Show=true, Hide=true,
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
    if key == 'CreateFontString' then return function() return newWidget() end end
    if key == 'CreateTexture' then return function() return newWidget() end end
    if plain[key] then return noop end
    return nil
end}
_G.CreateFrame = function(kind, name, parent, template)
    return newWidget({kind=kind, name=name, parent=parent, template=template})
end
local registered, categoryOpens = {}, 0
_G.Settings = {
    RegisterCanvasLayoutCategory = function(panel, title)
        registered[#registered+1] = {panel=panel, title=title}
        return {GetID = function() return 11 end}
    end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function() categoryOpens = categoryOpens + 1 end,
}

local V = {}
for _, m in ipairs({"Core.lua", "Languages.lua", "Accents.lua", "RaceProfiles.lua",
                    "MessageVariants.lua", "GroupPhrases.lua", "Queue.lua",
                    "Options.lua"}) do
    assert(loadfile(base .. m))("ForeverCommsVoice", V)
end
_G.ForeverCommsVoice = V
-- QueueUI.lua is not loaded; the panel's queue button only needs to reach ShowQueue.
local queueOpens = 0
V.ShowQueue = function() queueOpens = queueOpens + 1 end

local function buttonWithText(text)
    for _, w in ipairs(widgets) do
        if w.kind == "Button" and w.text == text then return w end
    end
    return nil
end
local function buttonsOfKind(kind)
    local out = {}
    for _, w in ipairs(widgets) do if w.kind == kind then out[#out+1] = w end end
    return out
end

V:BuildOptions()
assert(#registered == 1, "the panel registered exactly one canvas category, got " ..
    #registered)
assert(registered[1].title == "Forever Comms Voice", "registered under its own name, got " ..
    tostring(registered[1].title))
assert(registered[1].panel, "a panel frame was handed to Settings")
assert(V.settingsCategory, "the category handle is kept for OpenOptions")
V:BuildOptions()
assert(#registered == 1, "BuildOptions is idempotent")

-- ------------------------------------------------------------ cycle controls

-- Each cycle button shows the CURRENT value, not the first choice in its list.
local function cycleShowing(text) return buttonWithText(text) end
assert(V:SetOption("language", "en"))
V:RefreshOptions()
local languageButton = cycleShowing("English")
assert(languageButton, "the language button shows the active language")

-- Clicking advances to a different language and writes it to the shared profile.
languageButton.OnClick(languageButton)
local afterOne = V:GetSettings().language
assert(afterOne ~= "en", "clicking changed the language, still " .. afterOne)
V:RefreshOptions()
assert(languageButton.text ~= "English", "the label followed the change, got " ..
    tostring(languageButton.text))

-- Cycling all the way round returns to the start, which proves the index arithmetic
-- wraps rather than running off the end of the list.
assert(V:SetOption("language", "en"))
V:RefreshOptions()
for _ = 1, #V.languages do languageButton.OnClick(languageButton) end
assert(V:GetSettings().language == "en",
    "a full cycle returns to the starting language, got " .. V:GetSettings().language)

-- The race filter checkbox reads and writes the live value.
local checkboxes = buttonsOfKind("CheckButton")
assert(#checkboxes == 2, "race filter and queue auto-open, got " .. #checkboxes)
local raceBox = checkboxes[1]
assert(V:SetOption("raceFilter", true))
V:RefreshOptions()
assert(raceBox.checked == true, "the box reflects raceFilter on")
raceBox:SetChecked(false)
raceBox.OnClick(raceBox)
assert(V:GetSettings().raceFilter == false, "unchecking writes raceFilter off")
raceBox:SetChecked(true)
raceBox.OnClick(raceBox)
assert(V:GetSettings().raceFilter == true, "checking writes it back on")

-- Accent strength offers exactly the three documented labels, in order. These strings
-- are user-facing and are duplicated in GuildComms' Settings and Titan menu.
assert(V:SetOption("accentStrength", "subtle"))
V:RefreshOptions()
local strengthButton = cycleShowing("Subtle (wording only)")
assert(strengthButton, "subtle label present")
strengthButton.OnClick(strengthButton)
assert(V:GetSettings().accentStrength == "moderate", "cycles subtle to moderate, got " ..
    V:GetSettings().accentStrength)
V:RefreshOptions()
assert(strengthButton.text == "Moderate (adds a catchphrase)",
    "moderate label, got " .. tostring(strengthButton.text))
strengthButton.OnClick(strengthButton)
V:RefreshOptions()
assert(V:GetSettings().accentStrength == "expressive", "cycles to expressive")
assert(strengthButton.text == "Expressive (catchphrase + emphasis)",
    "expressive label, got " .. tostring(strengthButton.text))
strengthButton.OnClick(strengthButton)
assert(V:GetSettings().accentStrength == "subtle", "wraps back to subtle, got " ..
    V:GetSettings().accentStrength)

-- The accent cycle only ever lands on an accent SetOption accepts, so a race-filtered
-- list cannot leave the profile holding an unavailable accent.
assert(V:SetOption("raceFilter", true))
assert(V:SetOption("accent", "none"))
V:RefreshOptions()
local accentButton = cycleShowing("None (neutral)") or cycleShowing("None")
if accentButton then
    for _ = 1, 12 do
        accentButton.OnClick(accentButton)
        local current = V:GetSettings().accent
        local allowed = false
        for _, item in ipairs(V:GetAvailableAccents()) do
            if item.id == current then allowed = true end
        end
        assert(allowed, "the accent cycle must stay inside the available list, got " ..
            tostring(current))
    end
end

-- ------------------------------------------------------- queue settings controls

-- Row count cycles 1..10 and wraps.
assert(V:SetQueueOption("visibleRows", 2))
V:RefreshOptions()
local rowsButton = cycleShowing("2 rows")
assert(rowsButton, "the row-count button shows the current value")
rowsButton.OnClick(rowsButton)
assert(V:GetQueueSettings().visibleRows == 3, "cycles to 3, got " ..
    V:GetQueueSettings().visibleRows)
assert(V:SetQueueOption("visibleRows", 10))
V:RefreshOptions()
rowsButton.OnClick(rowsButton)
assert(V:GetQueueSettings().visibleRows == 1, "wraps from 10 back to 1, got " ..
    V:GetQueueSettings().visibleRows)

-- Source display toggles between the two presentations.
assert(V:SetQueueOption("sourceDisplay", "text"))
V:RefreshOptions()
local sourceButton = cycleShowing("Guild / Group text")
assert(sourceButton, "the source button shows the text option")
sourceButton.OnClick(sourceButton)
assert(V:GetQueueSettings().sourceDisplay == "icon", "cycles to icon, got " ..
    V:GetQueueSettings().sourceDisplay)
sourceButton.OnClick(sourceButton)
assert(V:GetQueueSettings().sourceDisplay == "text", "and back to text")

-- The auto-skip edit box sanitizes input and shows what was actually stored, so the
-- field can never display a value the queue is not using.
local edits = buttonsOfKind("EditBox")
assert(#edits == 1, "one numeric field, got " .. #edits)
local timeout = edits[1]
assert(V:SetQueueOption("autoSkipSeconds", 20))
V:RefreshOptions()
assert(timeout.text == "20", "the field shows the stored value, got " ..
    tostring(timeout.text))
timeout:SetText("45")
timeout.OnEnterPressed(timeout)
assert(V:GetQueueSettings().autoSkipSeconds == 45, "a valid entry is stored, got " ..
    V:GetQueueSettings().autoSkipSeconds)
assert(timeout.text == "45", "and echoed back")
timeout:SetText("not a number")
timeout.OnEnterPressed(timeout)
assert(V:GetQueueSettings().autoSkipSeconds == 45,
    "garbage input must not change the setting, got " ..
    V:GetQueueSettings().autoSkipSeconds)
assert(timeout.text == "45", "and the field snaps back to the stored value, got " ..
    tostring(timeout.text))
timeout:SetText("99999")
timeout.OnEnterPressed(timeout)
local clamped = V:GetQueueSettings().autoSkipSeconds
assert(clamped >= 0 and clamped <= 3600, "an out-of-range entry is clamped, got " .. clamped)
assert(timeout.text == tostring(clamped), "the field shows the clamped value")
timeout:SetText("0")
timeout.OnEnterPressed(timeout)
assert(V:GetQueueSettings().autoSkipSeconds == 0, "zero means never expire and is valid")
-- Escape abandons an edit rather than committing it.
timeout:SetText("123")
timeout.OnEscapePressed(timeout)
assert(V:GetQueueSettings().autoSkipSeconds == 0, "escape must not commit, got " ..
    V:GetQueueSettings().autoSkipSeconds)
assert(timeout.text == "0", "escape restores the displayed value, got " ..
    tostring(timeout.text))
assert(V:SetQueueOption("autoSkipSeconds", 20))

-- Auto-open checkbox and the queue shortcut.
local showBox = checkboxes[2]
assert(V:SetQueueOption("showOnNew", true))
V:RefreshOptions()
assert(showBox.checked == true, "auto-open reflects the setting")
showBox:SetChecked(false)
showBox.OnClick(showBox)
assert(V:GetQueueSettings().showOnNew == false, "unchecking disables auto-open")
local openButton = buttonWithText("Open message review queue")
assert(openButton, "the queue shortcut exists")
openButton.OnClick(openButton)
assert(queueOpens == 1, "the shortcut opens the review queue, got " .. queueOpens)

-- OpenOptions reaches the registered category rather than rebuilding the panel.
V:OpenOptions()
assert(categoryOpens == 1, "OpenOptions opens the Settings category, got " .. categoryOpens)
assert(#registered == 1, "and does not register a second panel")

-- ------------------------------- regression: the ADDON_LOADED registration gate

-- Options.lua creates its own frame and registers ADDON_LOADED at file scope. Load the
-- module fresh and fire the event the way the client would: the panel must register for
-- the addon's own name and ignore every other addon's load.
local W = {}
local fresh = {}
local savedCreateFrame = _G.CreateFrame
_G.CreateFrame = function(kind, name, parent, template)
    local w = setmetatable({kind=kind, name=name, parent=parent, template=template}, mt)
    fresh[#fresh+1] = w
    widgets[#widgets+1] = w
    return w
end
registered = {}
for _, m in ipairs({"Core.lua", "Languages.lua", "Accents.lua", "RaceProfiles.lua",
                    "MessageVariants.lua", "GroupPhrases.lua", "Queue.lua",
                    "Options.lua"}) do
    assert(loadfile(base .. m))("ForeverCommsVoice", W)
end
_G.CreateFrame = savedCreateFrame
assert(W.name == "ForeverCommsVoice", "Core.lua publishes the addon name, got " ..
    tostring(W.name))
assert(W.initialized == false, "a freshly loaded library is not initialized")

local handler
for _, w in ipairs(fresh) do
    if rawget(w, "OnEvent") then handler = w end
end
assert(handler, "Options.lua registered an OnEvent handler")

handler.OnEvent(handler, "ADDON_LOADED", "SomeOtherAddon")
assert(W.initialized == false, "another addon loading must not initialize us")
assert(#registered == 0, "and must not register our panel")

handler.OnEvent(handler, "ADDON_LOADED", "ForeverCommsVoice")
assert(W.initialized == true,
    "our own ADDON_LOADED must initialize the library; a nil comparison here was the " ..
    "bug that left Forever Comms Voice absent from the Settings list until /fcv")
assert(#registered == 1, "and must register the Settings panel, got " .. #registered)
assert(W.settingsCategory, "the category handle is stored")

print("PASSED: canvas registered once, cycles show live values and wrap, accent cycle " ..
      "stays inside the available list, strength labels exact, queue row/source cycles, " ..
      "auto-skip sanitizes and clamps and escape abandons, ADDON_LOADED registers for " ..
      "our own addon only")
