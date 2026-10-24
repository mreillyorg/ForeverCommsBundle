-- Run from the addon root: lua5.1 tests/titanmenu.lua
--
-- The Titan/LibDataBroker nested context menu. It is the largest surface in the package
-- that no harness loaded: every toggle writes straight to A.db and every action can post
-- to group chat or change a raid target, so a mislabelled or mis-wired entry is a real
-- hazard. The menu-node mock is the one from ForeverGuildComms/tests/titanmenu.lua,
-- extended with SetEnabled so the leader/grouped gating can be asserted.
local base = (arg and arg[0] and arg[0]:match("^(.*[/\\])tests[/\\]titanmenu%.lua$")) or "./"

local clock = 100
local sent, printed = {}, {}
local world = {grouped = true, raid = false, instance = false, leader = true}
local people = {
    player = {name="Alice Example", level=24, role="HEALER", guid="P1"},
    party1 = {name="Ben Another", level=26, role="TANK", guid="P2"},
}

_G.DEFAULT_CHAT_FRAME = {AddMessage = function(_, s) printed[#printed+1] = s end}
_G.GetTime = function() return clock end
_G.C_Timer = {After = function(_, cb) if cb then cb() end end, NewTicker = function() end}
_G.GetUnitName = function(u) return people[u] and people[u].name end
_G.UnitName = _G.GetUnitName
_G.UnitExists = function(u) return u == "target" or people[u] ~= nil end
_G.UnitGUID = function(u) return people[u] and people[u].guid end
_G.UnitLevel = function(u) return people[u] and people[u].level end
_G.UnitGroupRolesAssigned = function(u) return people[u] and people[u].role end
_G.GetNumSubgroupMembers = function() return 1 end
_G.GetNumGroupMembers = function() return 2 end
_G.LE_PARTY_CATEGORY_INSTANCE = 2
_G.IsInGroup = function(c)
    if c == _G.LE_PARTY_CATEGORY_INSTANCE then return world.instance end
    return world.grouped
end
_G.IsInRaid = function() return world.raid end
_G.UnitIsGroupLeader = function() return world.leader end
_G.UnitIsGroupAssistant = function() return false end
_G.UnitCanAttack = function() return true end
_G.InCombatLockdown = function() return false end
_G.SendChatMessage = function(msg, channel) sent[#sent+1] = {msg=msg, channel=channel} end
_G.SetRaidTarget = function(unit, index) sent[#sent+1] = {mark=index, unit=unit} end
_G.C_PartyInfo = {DoReadyCheck = function() sent[#sent+1] = {ready=true} end}
_G.CreateFrame = function() return {RegisterEvent=function()end, SetScript=function()end} end
_G.SlashCmdList = {}
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end end
_G.UIParent = {GetObjectType = function() return "Frame" end}
local settingsOpens = 0
_G.Settings = {
    RegisterCanvasLayoutCategory = function() return {GetID = function() return 7 end} end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function() settingsOpens = settingsOpens + 1 end,
}

local function menuNode(kind, name, selected, action)
    local node = {kind=kind, name=name, selected=selected, action=action,
                  children={}, enabled=true}
    local function add(k, n, s, a)
        local child = menuNode(k, n, s, a)
        node.children[#node.children+1] = child
        return child
    end
    function node:CreateTitle(n) return add("title", n) end
    function node:CreateDivider() return add("divider", "") end
    function node:CreateButton(n, cb) return add("button", n, nil, cb) end
    function node:CreateCheckbox(n, selectedCb, cb) return add("checkbox", n, selectedCb, cb) end
    function node:CreateRadio(n, selectedCb, cb) return add("radio", n, selectedCb, cb) end
    -- Not in the GuildComms mock: Action() calls this to grey out an unavailable entry,
    -- which is how the leader-only and group-only gating shows up in the menu.
    function node:SetEnabled(value) self.enabled = value and true or false end
    return node
end
local root, lastOwner
_G.MenuUtil = {CreateContextMenu = function(owner, builder)
    lastOwner = owner
    root = menuNode("root", "root")
    builder(owner, root)
end}

-- Core.lua refuses to load without the library, which the TOC guarantees in game. A bare
-- table satisfies that check and exposes no methods, so the menu's "library unavailable"
-- branches still exercise as written. A richer stub is installed later in this file.
_G.ForeverCommsVoice = {}

local A = {}
for _, m in ipairs({"Core.lua", "Roster.lua", "Quests.lua", "TitanMenu.lua"}) do
    assert(loadfile(base .. m))("ForeverGroupComms", A)
end
A.RefreshQuestUI = function() end
A:Initialize()
A.db.randomMessages = false
A.db.useSharedVoice = false
-- UI.lua and Options.lua are intentionally not loaded; this harness is about the menu.
-- Stand in for what they publish: the registered Settings category that A:OpenSettings
-- prefers, and the panel shown when there is none.
A.settingsCategory = {GetID = function() return 7 end}
local panelOpens = 0
A.ShowPanel = function() panelOpens = panelOpens + 1 end
A.ShowQuests = function() panelOpens = panelOpens + 1 end

-- Node lookup helpers. Entries are addressed by their visible label, because that is
-- what the user clicks and what a rename would change.
local function find(node, label)
    for _, child in ipairs(node.children) do
        if child.name == label then return child end
    end
    return nil
end
local function need(node, label)
    local found = find(node, label)
    assert(found, "no menu entry labelled '" .. label .. "'")
    return found
end
local function findPrefix(node, prefix)
    for _, child in ipairs(node.children) do
        if type(child.name) == "string" and child.name:sub(1, #prefix) == prefix then
            return child
        end
    end
    return nil
end
local function titles(node)
    local out = {}
    for _, child in ipairs(node.children) do
        if child.kind == "title" then out[#out+1] = child.name end
    end
    return table.concat(out, " | ")
end

A:OpenTitanMenu(UIParent)
assert(root, "the context menu was built")
assert(lastOwner == UIParent, "the menu is anchored to the owner it was given")

-- Top-level shape.
assert(findPrefix(root, "Forever Group Comms"), "the menu is titled")
need(root, "Enable addon")
need(root, "Greetings & congratulations")
need(root, "Dungeon coordination")
need(root, "Target marking")
need(root, "Quest sharing & checks")
need(root, "Quick actions")
need(root, "Settings...")
need(root, "Voice & queue settings...")
assert(findPrefix(root, "Group status:"), "a status submenu is present")

-- Status submenu reports live state rather than placeholders.
local status = findPrefix(root, "Group status:")
assert(status.name:find("2 players", 1, true), "member count shown, got " .. status.name)
local shown = titles(status)
assert(shown:find("Channel: PARTY", 1, true), "channel shown, got " .. shown)
assert(shown:find("1 tank / 1 healer / 0 DPS / 0 unassigned", 1, true),
    "role counts shown, got " .. shown)
assert(shown:find("Ready check / target marking: Available", 1, true),
    "leader rank reflected, got " .. shown)
assert(shown:find("Quest sync: Enabled", 1, true), "quest sync state shown, got " .. shown)

-- A toggle must read the current value and write the inverse, not a hardcoded true.
local enableToggle = need(root, "Enable addon")
assert(enableToggle.kind == "checkbox", "Enable addon is a checkbox")
assert(enableToggle.selected() == true, "reads the live enabled value")
enableToggle.action()
assert(A.db.enabled == false, "clicking writes the inverse to the db")
assert(enableToggle.selected() == false, "and the read reflects it")
enableToggle.action()
assert(A.db.enabled == true, "clicking again restores it")

local messages = need(root, "Greetings & congratulations")
for _, pair in ipairs({
    {"Automatically greet group members", "autoGreeting"},
    {"Automatically congratulate level-ups", "autoLevel"},
    {"Vary built-in message wording", "randomMessages"},
    {"Use shared languages and accents", "useSharedVoice"},
}) do
    local entry = need(messages, pair[1])
    local key = pair[2]
    local before = A.db[key]
    assert(entry.selected() == (before == true), pair[1] .. " reads its own key")
    entry.action()
    assert(A.db[key] == not before, pair[1] .. " must toggle " .. key)
    entry.action()
    assert(A.db[key] == before, pair[1] .. " must toggle back")
end

-- Turning quest sync ON from the menu schedules a refresh; turning it off does not.
local quests = need(root, "Quest sharing & checks")
local syncToggle = need(quests, "Exchange quest data with addon users")
local scheduled = 0
A.ScheduleQuestSync = function(_, force) scheduled = scheduled + 1; assert(force) end
A.db.questSync = false
syncToggle.action()
assert(A.db.questSync == true, "the toggle enabled sync")
assert(scheduled == 1, "enabling sync requests a refresh, got " .. scheduled)
syncToggle.action()
assert(A.db.questSync == false, "the toggle disabled sync")
assert(scheduled == 1, "disabling sync must not schedule a broadcast")
A.db.questSync = true

-- Gating: target marking needs rank, coordination needs a group. Both are asserted
-- through the menu's own enabled state rather than by calling the actions.
local marks = need(root, "Target marking")
assert(need(marks, "Mark target: skull").enabled, "a leader may mark")
world.leader = false
A:OpenTitanMenu(UIParent)
marks = need(root, "Target marking")
assert(need(marks, "Mark target: skull").enabled == false,
    "a non-leader sees marking greyed out")
assert(need(marks, "Mark target: moon").enabled == false, "both marks are gated")
local status2 = findPrefix(root, "Group status:")
assert(titles(status2):find("Leader or assistant required", 1, true),
    "and the status explains why, got " .. titles(status2))
world.leader = true

-- Ungrouped: the status line changes and every group action is disabled.
world.grouped = false
A.activeGroup = false
A:OpenTitanMenu(UIParent)
local ungrouped = findPrefix(root, "Group status:")
assert(ungrouped.name:find("Not grouped", 1, true), "status says not grouped, got " ..
    ungrouped.name)
assert(titles(ungrouped):find("Not in a party or raid", 1, true), "and explains it")
local coordination = need(root, "Dungeon coordination")
for _, label in ipairs({"Confirm roles", "Start ready check", "Next pull", "Mana break",
                        "Regroup", "Wait for healer", "Coordinate interrupts",
                        "Crowd control moon", "Focus skull"}) do
    assert(need(coordination, label).enabled == false,
        "'" .. label .. "' must be disabled when ungrouped")
end
-- Entries that do not touch group chat stay available.
assert(need(root, "Open Review Panel").enabled, "the review panel is always reachable")
assert(need(root, "Settings...").enabled, "settings are always reachable")
world.grouped = true
A.activeGroup = true

-- The review panel delegates to the shared queue, and says so when it is absent.
A:OpenTitanMenu(UIParent)
local opened = 0
_G.ForeverCommsVoice = {
    ShowQueue = function() opened = opened + 1 end,
    PendingCount = function() return 3 end,
}
need(root, "Open Review Panel").action()
assert(opened == 1, "the review panel opens the shared queue")
A:OpenTitanMenu(UIParent)
assert(titles(findPrefix(root, "Group status:")):find("Pending group reviews: 3", 1, true),
    "the queue count comes from the library")
_G.ForeverCommsVoice = nil
A:OpenTitanMenu(UIParent)
need(root, "Open Review Panel").action()
assert(printed[#printed]:find("unavailable", 1, true),
    "without the library the user is told, got " .. printed[#printed])

-- A menu action that does send must go through the normal chat rails.
A:OpenTitanMenu(UIParent)
clock = 500
local before = #sent
need(need(root, "Greetings & congratulations"), "Send group greeting").action()
assert(#sent == before + 1, "the greeting was sent")
assert(sent[#sent].channel == "PARTY", "through the group channel")
need(need(root, "Greetings & congratulations"), "Send group greeting").action()
assert(#sent == before + 1, "a second click inside the 2-second floor is refused")

-- Without MenuUtil the menu degrades to opening Settings instead of erroring.
local savedMenuUtil = _G.MenuUtil
_G.MenuUtil = nil
local opensBefore = settingsOpens
A:OpenTitanMenu(UIParent)
assert(settingsOpens == opensBefore + 1, "falls back to the Settings panel")
assert(printed[#printed]:find("Nested menus unavailable", 1, true),
    "and explains the fallback, got " .. printed[#printed])
_G.MenuUtil = savedMenuUtil

-- An owner without GetObjectType is replaced by UIParent rather than passed through.
A:OpenTitanMenu({})
assert(lastOwner == UIParent, "a bogus owner falls back to UIParent")
A:OpenTitanMenu(nil)
assert(lastOwner == UIParent, "a nil owner falls back to UIParent")

-- Before Initialize there is no db, and the menu must build nothing rather than error.
-- Restore the library stub first: the "without the library" case above cleared the global,
-- and Core.lua now refuses to load without it.
_G.ForeverCommsVoice = {}
local B = {}
for _, m in ipairs({"Core.lua", "Roster.lua", "TitanMenu.lua"}) do
    assert(loadfile(base .. m))("ForeverGroupComms", B)
end
local bare = menuNode("root", "root")
B:PopulateTitanMenu(bare)
assert(#bare.children == 0, "an uninitialized addon populates an empty menu")

print("PASSED: menu structure, live status/channel/roles/queue counts, every toggle " ..
      "reads and writes its own key, questSync schedules only on enable, marking gated " ..
      "by rank and coordination by grouping, send obeys the chat floor, MenuUtil and " ..
      "owner fallbacks, no db builds nothing")
