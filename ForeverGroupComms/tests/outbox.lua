-- Run from the addon root: lua5.1 tests/outbox.lua
--
-- The addon-message outbox and the questSync opt-out. These are the bounds that keep
-- quest syncing from becoming a traffic source: one packet per 1.15 seconds, at most 60
-- queued, at most 12 chunks per broadcast, and a token that cancels everything pending
-- when the group changes. An opt-out that is never asserted can silently stop working,
-- and a pacing bug would be invisible offline until someone was disconnected in game.
--
-- The timer mock here is a queue rather than an immediate call, so the pacing can
-- actually be observed: tests/smoke.lua drains timers in a loop and cannot see it.
local base = (arg and arg[0] and arg[0]:match("^(.*[/\\])tests[/\\]outbox%.lua$")) or "./"

local PREFIX = "ForeverGrpComms"
local clock = 100
local timers, traffic, printed = {}, {}, {}
local quests = {
    {questID=101, title="Dungeon Starter", isHeader=false},
    {questID=202, title="Collect Shells", isHeader=false},
}
local people = {
    player = {name="Alice Example", level=24, role="HEALER", guid="P1"},
    party1 = {name="Ben Another", level=26, role="TANK", guid="P2"},
}
local registerResult = 0

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
_G.IsInGroup = function() return true end
_G.IsInRaid = function() return false end
_G.InCombatLockdown = function() return false end
_G.SendChatMessage = function() end
_G.CreateFrame = function() return {RegisterEvent=function()end, SetScript=function()end} end
_G.SlashCmdList = {}
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end end
_G.C_QuestLog = {
    GetNumQuestLogEntries = function() return #quests end,
    GetInfo = function(i) return quests[i] end,
    IsQuestFlaggedCompleted = function() return false end,
    IsPushableQuest = function() return true end,
}
_G.C_ChatInfo = {
    RegisterAddonMessagePrefix = function() return registerResult end,
    SendAddonMessage = function(prefix, message, channel, to)
        traffic[#traffic+1] = {prefix=prefix, msg=message, channel=channel, target=to}
        return 0
    end,
}

local A = {}
for _, m in ipairs({"Core.lua", "Roster.lua", "Quests.lua"}) do
    assert(loadfile(base .. m))("ForeverGroupComms", A)
end
A.RefreshQuestUI = function() end
A:Initialize()
A.db.randomMessages = false
assert(A.questCommsReady, "precondition: prefix registration reported success")

local function runNext()
    assert(#timers > 0, "expected a scheduled callback")
    local timer = table.remove(timers, 1)
    clock = clock + timer.delay
    timer.cb()
    return timer.delay
end
local function drain(limit)
    local ran = 0
    while #timers > 0 do
        ran = ran + 1
        assert(ran <= (limit or 200), "timers are not settling")
        runNext()
    end
    return ran
end
local function reset()
    wipe(A.addonOutbox)
    wipe(A.questPeers)
    wipe(A.questParts)
    timers, traffic, printed = {}, {}, {}
    A.outboxBusy = false
    A.lastQuestSignature, A.lastQuestAnnounce = nil, nil
end
local function setQuestCount(count, firstID)
    quests = {}
    for i = 1, count do
        quests[i] = {questID = (firstID or 10000000) + i, title = "Q" .. i, isHeader = false}
    end
end

-- ------------------------------------------------------------ 1.15s pacing

reset()
A:QueuePacket("Q|1|1|1|1|101")
A:QueuePacket("Q|1|1|1|1|202")
A:QueuePacket("Q|1|1|1|1|303")
assert(#A.addonOutbox == 3, "all three packets are queued, got " .. #A.addonOutbox)
assert(#timers == 1, "only one timer is armed at a time, got " .. #timers)
assert(#traffic == 0, "nothing is sent synchronously, not even the first packet")

assert(runNext() == 1.15, "the pacing delay is 1.15 seconds")
assert(#traffic == 1, "exactly one packet per tick, got " .. #traffic)
assert(#A.addonOutbox == 2, "the sent packet left the queue")
assert(#timers == 1, "the next tick is armed because work remains")
assert(runNext() == 1.15, "the second gap is also 1.15 seconds")
assert(#traffic == 2, "one more packet")
runNext()
assert(#traffic == 3, "the last packet went out")
assert(#timers == 0, "an empty queue arms no further timer")
assert(traffic[1].prefix == PREFIX, "sent under the addon's own prefix")
assert(traffic[1].channel == "PARTY", "defaulted to the group channel")

-- ---------------------------------------------------------- the 60-entry cap

reset()
for i = 1, 65 do A:QueuePacket("Q|1|1|1|1|" .. i) end
assert(#A.addonOutbox == 60, "the outbox refuses past 60 entries, got " .. #A.addonOutbox)
-- Refusing rather than truncating means the OLDEST 60 are kept, not the newest.
assert(A.addonOutbox[1].message:find("|1$"), "the first queued packet is still first")
assert(A.addonOutbox[60].message:find("|60$"),
    "entry 60 is the last accepted; 61-65 were dropped, got " ..
    tostring(A.addonOutbox[60].message))

-- -------------------------------------------------------- outboxToken cancel

reset()
for i = 1, 5 do A:QueuePacket("Q|1|1|1|1|" .. i) end
assert(#timers == 1, "a tick is pending")
local tokenBefore = A.outboxToken or 0
A:ClearQuestPeers()
assert((A.outboxToken or 0) == tokenBefore + 1, "ClearQuestPeers bumps the token")
assert(#A.addonOutbox == 0, "and empties the outbox")
runNext()
assert(#traffic == 0, "the already-armed callback must send nothing after a cancel")
assert(#timers == 0, "and must not re-arm the pacing loop")
-- Queueing again after a cancellation works normally.
A:QueuePacket("Q|1|1|1|1|999")
runNext()
assert(#traffic == 1, "the outbox recovers after a cancellation")

-- Isolate the token itself. ClearQuestPeers both empties the outbox AND bumps the
-- token, so the previous case would also pass if the token were ignored entirely: the
-- callback would simply find nothing to send. Bump the token on its own, leaving the
-- queue full, so only the token comparison can prevent the send.
reset()
for i = 1, 3 do A:QueuePacket("Q|1|1|1|1|" .. i) end
assert(#A.addonOutbox == 3 and #timers == 1, "three queued, one tick armed")
A.outboxToken = (A.outboxToken or 0) + 1
runNext()
assert(#traffic == 0, "a superseded callback must not send even with a full outbox")
assert(#A.addonOutbox == 3,
    "and must return before consuming an entry, still " .. #A.addonOutbox)
assert(#timers == 0, "and must not re-arm the loop")

-- A roster identity change is the real trigger for that cancellation.
reset()
for i = 1, 4 do A:QueuePacket("Q|1|1|1|1|" .. i) end
people.party2 = {name="Cora Person", level=25, role="DAMAGER", guid="P3"}
_G.GetNumSubgroupMembers = function() return 2 end
A:ScanRoster(true)
assert(#A.addonOutbox == 0, "a new group member cancels queued packets")
_G.GetNumSubgroupMembers = function() return 1 end
people.party2 = nil
A:ScanRoster(true)

-- A packet that somehow outlives the cancellation is still refused at send time by its
-- recorded serial, which is the belt to the token's braces.
reset()
A:QueuePacket("Q|1|1|1|1|101")
A.groupSerial = A.groupSerial + 1
runNext()
assert(#traffic == 0, "a packet stamped with a previous group serial is not sent")
A.groupSerial = A.groupSerial - 1

-- ------------------------------------------------------- the 12-chunk ceiling

-- Comfortably inside the ceiling: a large but sendable log.
reset()
setQuestCount(200)
A:BroadcastQuests(true)
local chunks = #A.addonOutbox
assert(chunks > 1 and chunks <= 12,
    "200 quests should need several chunks but stay within the ceiling, got " .. chunks)
for _, entry in ipairs(A.addonOutbox) do
    local _, _, total = entry.message:match("^Q|1|(%d+)|(%d+)|(%d+)|")
    assert(tonumber(total) == chunks, "every chunk advertises the same total")
end
assert(#printed == 0, "a sendable log produces no complaint")

-- Past the ceiling: refuse the whole broadcast rather than send a partial log.
reset()
setQuestCount(400)
local epochBefore = A.questEpoch
A:BroadcastQuests(true)
assert(#A.addonOutbox == 0, "an oversized log queues nothing, got " .. #A.addonOutbox)
assert(#timers == 0, "and arms no pacing timer")
assert(printed[#printed] and printed[#printed]:find("too large", 1, true),
    "the user is told the log is too large, got " .. tostring(printed[#printed]))
-- Documented quirk: the epoch is consumed before chunking is attempted, so a refused
-- broadcast still burns one. Harmless, because peers only compare epochs for ordering.
assert(A.questEpoch == epochBefore + 1,
    "a refused broadcast still advances the epoch; if this changes, update the note")
setQuestCount(2)

-- --------------------------------------------- the unchanged-log rebroadcast skip

reset()
A:BroadcastQuests(true)
assert(#A.addonOutbox > 0, "the first broadcast is queued")
drain()
local afterFirst = #traffic
A:BroadcastQuests(false)
assert(#A.addonOutbox == 0,
    "an unchanged log must not be rebroadcast on every QUEST_LOG_UPDATE")
-- Anchor to the recorded announce time: draining the pacing timers already moved the
-- clock, so relative offsets from "now" would overshoot the window.
local announcedAt = A.lastQuestAnnounce
assert(announcedAt, "the broadcast recorded its timestamp")
clock = announcedAt + 239
A:BroadcastQuests(false)
assert(#A.addonOutbox == 0, "still skipped just inside the 240-second window")
clock = announcedAt + 240
A:BroadcastQuests(false)
assert(#A.addonOutbox > 0, "a periodic rebroadcast is allowed once the window passes")
drain()
assert(#traffic > afterFirst, "the rebroadcast went out")
-- A changed log always broadcasts, window or not.
reset()
A:BroadcastQuests(true)
drain()
local before = #traffic
setQuestCount(3)
A:BroadcastQuests(false)
assert(#A.addonOutbox > 0, "a changed quest log broadcasts immediately")
drain()
assert(#traffic > before, "the changed log went out")
setQuestCount(2)

-- ------------------------------------------------------- the questSync opt-out

reset()
A.db.questSync = false
A:QueuePacket("Q|1|1|1|1|101")
assert(#A.addonOutbox == 0, "with sync off nothing may enter the outbox")
A:BroadcastQuests(true)
assert(#A.addonOutbox == 0, "with sync off no broadcast is built")
A:ScheduleQuestSync(true)
assert(#timers == 0, "with sync off no broadcast is even scheduled")

-- Toggling off while a packet is already in flight must suppress it at send time.
A.db.questSync = true
A:QueuePacket("Q|1|1|1|1|101")
assert(#timers == 1, "a tick is pending")
A.db.questSync = false
runNext()
assert(#traffic == 0, "a queued packet is re-checked at send time and suppressed")
A.db.questSync = true

-- The opt-out is send-side only: inbound traffic from a group member is still read, so
-- turning sync off stops disclosure without blinding the user to what peers volunteer.
reset()
A.db.questSync = false
A:OnAddonMessage(PREFIX, "Q|1|50|1|1|101", "PARTY", "Ben Another")
assert(A.questPeers["ben another"], "inbound packets are still processed with sync off")
assert(#A.addonOutbox == 0, "but no completion reply is queued back")
A.db.questSync = true

-- --------------------------------------------- prefix registration failure

-- If the client refuses the prefix, sending is disabled but receiving still works.
reset()
A.questCommsReady = false
A:QueuePacket("Q|1|1|1|1|101")
assert(#A.addonOutbox == 0, "without a registered prefix nothing is queued")
A:BroadcastQuests(true)
assert(#A.addonOutbox == 0, "and nothing is broadcast")
A:OnAddonMessage(PREFIX, "Q|1|60|1|1|101", "PARTY", "Ben Another")
assert(A.questPeers["ben another"], "inbound processing does not depend on registration")
A.questCommsReady = true

-- A client whose RegisterAddonMessagePrefix reports failure leaves comms off entirely.
registerResult = "nope"
local B = {}
for _, m in ipairs({"Core.lua", "Roster.lua", "Quests.lua"}) do
    assert(loadfile(base .. m))("ForeverGroupComms", B)
end
B.RefreshQuestUI = function() end
B:InitializeQuestSync()
assert(B.questCommsReady == false,
    "an unrecognised registration result must disable sending, got " ..
    tostring(B.questCommsReady))
registerResult = 0

print("PASSED: one packet per 1.15s with a single armed timer, 60-entry refusal keeps " ..
      "the oldest, token cancellation on roster change plus serial re-check, 12-chunk " ..
      "refusal with no partial send, 240s unchanged-log skip, questSync opt-out blocks " ..
      "send and queue and schedule but still receives, registration failure fails closed")
