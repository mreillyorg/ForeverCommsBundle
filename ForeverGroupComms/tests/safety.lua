-- Run from the addon root: lua5.1 tests/safety.lua
--
-- The chat-safety model of an addon that writes to party/raid chat, asserted directly.
-- Every rail here exists to stop the worst failure this addon has: posting to the wrong
-- group, or posting several lines at once. tests/smoke.lua proves the happy paths work;
-- this one proves the refusals refuse.
--
-- Rails covered: the 2-second floor in A:SendPrepared, groupSerial rejection of a
-- suggestion staged for a previous group (both the shared-queue closure and the
-- standalone A:Approve fallback), the A:CanManageGroup leader/assistant gate with its
-- feature-detection fallbacks, and A:Notify deduplication plus the backlog cap.
local base = (arg and arg[0] and arg[0]:match("^(.*[/\\])tests[/\\]safety%.lua$")) or "./"

local clock = 100
local sent = {}
local printed = {}
-- Everything the fake client reports is driven from here so each rail can be isolated.
local world = {
    grouped = true, raid = false, instance = false,
    leader = true, assistant = false, combat = false,
    targetExists = true, targetHostile = true,
}
local people = {
    player = {name="Alice Example", level=24, role="HEALER", guid="P1"},
    party1 = {name="Ben Another", level=26, role="TANK", guid="P2"},
}

_G.DEFAULT_CHAT_FRAME = {AddMessage = function(_, s) printed[#printed+1] = s end}
_G.GetTime = function() return clock end
_G.C_Timer = {After = function(_, cb) if cb then cb() end end, NewTicker = function() end}
_G.GetUnitName = function(u) return people[u] and people[u].name end
_G.UnitName = _G.GetUnitName
_G.UnitExists = function(u)
    if u == "target" then return world.targetExists end
    return people[u] ~= nil
end
_G.UnitGUID = function(u) return people[u] and people[u].guid end
_G.UnitLevel = function(u) return people[u] and people[u].level end
_G.UnitGroupRolesAssigned = function(u) return people[u] and people[u].role end
_G.GetNumSubgroupMembers = function() return 1 end
_G.GetNumGroupMembers = function() return 2 end
_G.LE_PARTY_CATEGORY_INSTANCE = 2
_G.IsInGroup = function(category)
    if category == _G.LE_PARTY_CATEGORY_INSTANCE then return world.instance end
    return world.grouped
end
_G.IsInRaid = function() return world.raid end
_G.UnitIsGroupLeader = function() return world.leader end
_G.UnitIsGroupAssistant = function() return world.assistant end
_G.UnitCanAttack = function() return world.targetHostile end
_G.InCombatLockdown = function() return world.combat end
_G.SendChatMessage = function(msg, channel) sent[#sent+1] = {msg=msg, channel=channel} end
_G.SetRaidTarget = function(unit, index) sent[#sent+1] = {mark=index, unit=unit} end
_G.C_PartyInfo = {DoReadyCheck = function() sent[#sent+1] = {ready=true} end}
_G.CreateFrame = function() return {RegisterEvent=function()end, SetScript=function()end} end
_G.SlashCmdList = {}
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end end

local A = {}
for _, m in ipairs({"Core.lua", "Roster.lua"}) do
    assert(loadfile(base .. m))("ForeverGroupComms", A)
end
A:Initialize()
-- Deterministic wording keeps the assertions about *whether* a message went out, not
-- which variant it was.
A.db.randomMessages = false
A.db.useSharedVoice = false

local function lastPrint() return printed[#printed] or "" end
local function countSends() return #sent end

-- -------------------------------------------------------- the 2-second floor

assert(A.lastChat == 0, "nothing has been sent during initialization")
assert(A:Send("pull"), "the first message of a session is not throttled")
assert(#sent == 1 and sent[1].channel == "PARTY", "sent to party chat, got " ..
    tostring(sent[1] and sent[1].channel))
assert(A.lastChat == 100, "a successful send records the clock")

clock = 101
assert(not A:Send("mana"), "a second message one second later must be refused")
assert(#sent == 1, "the refused message must not reach chat")
assert(lastPrint():find("two seconds", 1, true), "the user is told why, got " .. lastPrint())
assert(A.lastChat == 100, "a refused attempt must not slide the window forward")

clock = 101.9
assert(not A:Send("mana"), "still refused just under the floor")
clock = 102
assert(A:Send("mana"), "allowed at exactly two seconds")
assert(#sent == 2, "the message went out")
assert(A.lastChat == 102, "the window moved to the successful send")

-- The channel follows the group type, so a raid message never goes to PARTY.
clock = 110
world.raid = true
assert(A:Send("pull"), "raid send")
assert(sent[#sent].channel == "RAID", "raid uses RAID, got " .. sent[#sent].channel)
clock = 120
world.instance = true
assert(A:Send("pull"), "instance send")
assert(sent[#sent].channel == "INSTANCE_CHAT", "instance group uses INSTANCE_CHAT, got " ..
    sent[#sent].channel)
world.raid, world.instance = false, false

-- CanChat refuses when disabled or ungrouped, regardless of the clock.
clock = 200
A.db.enabled = false
assert(not A:Send("pull"), "a disabled addon sends nothing")
A.db.enabled = true
world.grouped = false
A.activeGroup = false
assert(not A:Send("pull"), "no group means no send")
world.grouped = true
A.activeGroup = true
assert(countSends() == 4, "neither refusal reached chat")

-- -------------------------------------------- groupSerial: no cross-group sends

-- Fallback path, used when the shared library is absent: A:Stage records the serial and
-- A:Approve drops the entry if the group has changed since.
wipe(A.approvals)
clock = 300
A:Stage("greet", nil, "Welcome the new party")
assert(#A.approvals == 1, "the suggestion was staged")
assert(A.approvals[1].serial == A.groupSerial, "the staged entry carries the serial")
local staleSerial = A.groupSerial
A.groupSerial = A.groupSerial + 1
local before = countSends()
A:Approve(1)
assert(#A.approvals == 0, "a stale suggestion is discarded, not sent")
assert(countSends() == before, "nothing reached chat from the previous group")
assert(lastPrint():find("previous group", 1, true), "the user is told, got " .. lastPrint())
A.groupSerial = staleSerial

-- A fresh suggestion does send, and survives a refusal so the click is not lost.
wipe(A.approvals)
clock = 400
A:Stage("pull", nil, "Pull")
A:Approve(1)
assert(#A.approvals == 0 and countSends() == before + 1, "a current suggestion is sent")
wipe(A.approvals)
A:Stage("mana", nil, "Mana")
A:Approve(1)
assert(#A.approvals == 1, "a throttled click keeps the suggestion clickable")
assert(countSends() == before + 1, "and sends nothing")

-- Shared-queue path: A:Stage captures the rendered text AND the serial in a closure, so
-- approving after a roster change returns the "stale" marker the queue uses to drop it.
local captured
_G.ForeverCommsVoice = {
    Enqueue = function(_, item) captured = item; return 1 end,
    SkipAll = function() end,
    PendingCount = function() return 0 end,
}
wipe(A.approvals)
clock = 500
A:Stage("greet", nil, "Welcome the new party")
assert(captured and type(captured.send) == "function", "the queue received a send closure")
assert(#A.approvals == 0, "the fallback list is not used when the queue accepts")
local queuedText = captured.text
A.groupSerial = A.groupSerial + 1
before = countSends()
local ok, reason = captured.send()
assert(ok == false and reason == "stale",
    "the closure must report staleness so the queue drops it, got " ..
    tostring(ok) .. "/" .. tostring(reason))
assert(countSends() == before, "a stale approval sends nothing")

-- The same closure on an unchanged roster sends exactly the text the player was shown.
A.groupSerial = A.groupSerial - 1
clock = 600
assert(captured.send() == true, "an unchanged roster sends")
assert(sent[#sent].msg == queuedText,
    "the queue must send the previewed wording verbatim, not a re-rolled variant")
_G.ForeverCommsVoice = nil

-- A roster identity change bumps the serial and clears staged suggestions outright.
wipe(A.approvals)
clock = 700
A:Stage("pull", nil, "Pull")
assert(#A.approvals == 1, "staged before the change")
local serialBefore = A.groupSerial
people.party2 = {name="Cora Person", level=25, role="DAMAGER", guid="P3"}
_G.GetNumSubgroupMembers = function() return 2 end
A:ScanRoster(true)
assert(A.groupSerial == serialBefore + 1, "a new member bumps the serial")
assert(#A.approvals == 0, "and wipes suggestions staged for the old roster")

-- ------------------------------------------- the leader / assistant gate

world.leader = true
assert(A:CanManageGroup(), "the leader may manage")
world.leader = false
assert(not A:CanManageGroup(), "a plain member may not")
world.assistant = true
assert(not A:CanManageGroup(), "assistant status outside a raid does not grant rank")
world.raid = true
assert(A:CanManageGroup(), "a raid assistant may manage")
world.raid, world.assistant = false, false

-- Ungrouped is checked before rank, so a former leader cannot act after leaving.
world.leader = true
A.activeGroup = false
assert(not A:CanManageGroup(), "leaving the group revokes management")
A.activeGroup = true

-- A missing client API must deny, never permit.
local savedLeader, savedAssistant = _G.UnitIsGroupLeader, _G.UnitIsGroupAssistant
_G.UnitIsGroupLeader, _G.UnitIsGroupAssistant = nil, nil
assert(not A:CanManageGroup(), "absent rank APIs must fail closed")
_G.UnitIsGroupLeader, _G.UnitIsGroupAssistant = savedLeader, savedAssistant

-- Both gated actions refuse for a non-leader and act for a leader.
world.leader = false
before = countSends()
A:ReadyCheck()
assert(countSends() == before, "a non-leader cannot start a ready check")
assert(lastPrint():find("leader", 1, true), "told why, got " .. lastPrint())
A:MarkTarget(8)
assert(countSends() == before, "a non-leader cannot mark targets")
world.leader = true
A:ReadyCheck()
assert(sent[#sent].ready, "the leader starts a ready check")
A:MarkTarget(8)
assert(sent[#sent].mark == 8, "the leader marks the target")

-- Marking still refuses on a missing or friendly target, and in combat.
before = countSends()
world.targetExists = false
A:MarkTarget(8)
assert(countSends() == before, "no target means no mark")
world.targetExists = true
world.targetHostile = false
A:MarkTarget(8)
assert(countSends() == before, "a friendly target is not marked")
world.targetHostile = true
world.combat = true
A:MarkTarget(8)
assert(countSends() == before, "marking is refused in combat")
A:ReadyCheck()
assert(countSends() == before, "ready checks are refused in combat")
world.combat = false

-- ------------------------------------------------- Notify dedup and cap

A.notifications = {}
wipe(A.seen)
clock = 1000
A:Notify("Roles need confirmation", "roles:1")
assert(#A.notifications == 1, "first notification stored")
A:Notify("Roles need confirmation", "roles:1")
assert(#A.notifications == 1, "a repeat inside the window is suppressed")
clock = 1089
A:Notify("Roles need confirmation", "roles:1")
assert(#A.notifications == 1, "still suppressed one second before the window closes")
clock = 1090
A:Notify("Roles need confirmation", "roles:1")
assert(#A.notifications == 2, "allowed once the 90-second window has passed")

-- A different key is a different notification.
A:Notify("Quest reminder", "questgroup:1")
assert(#A.notifications == 3, "a distinct key is not deduplicated")

-- No key means no dedup at all, which is what staged-suggestion notices rely on.
A:Notify("Suggested: Pull")
A:Notify("Suggested: Pull")
assert(#A.notifications == 5, "keyless notifications are never suppressed")

-- The backlog is capped and drops the oldest, keeping the newest at index 1.
A.notifications = {}
A.db.maxNotifications = 5
for i = 1, 9 do A:Notify("notice " .. i) end
assert(#A.notifications == 5, "the backlog is capped, got " .. #A.notifications)
assert(A.notifications[1] == "notice 9", "newest first, got " .. A.notifications[1])
assert(A.notifications[5] == "notice 5", "oldest dropped, got " .. A.notifications[5])

-- A disabled addon records nothing at all.
A.db.enabled = false
A:Notify("while disabled")
assert(#A.notifications == 5, "a disabled addon stores no notifications")
A.db.enabled = true

print("PASSED: 2s floor holds and refusals do not slide it, channel follows group type, " ..
      "stale serial blocked on both the queue closure and the fallback, queue sends the " ..
      "previewed text verbatim, rank gate fails closed, Notify dedup window and cap")
