-- Run from the addon root: lua5.1 tests/protocol.lua
--
-- Negative tests for the quest-sync wire protocol. A:OnAddonMessage is the only code in
-- the bundle that reads data another player sent, so every rejection branch matters:
-- anything that gets past it ends up in A.questPeers and is shown to the user as fact.
--
-- tests/smoke.lua covers the happy Q/R round trip. This harness only feeds malformed,
-- hostile and out-of-order input, and asserts that nothing is recorded. The parser
-- itself (parseIDs) is file-local by design, so it is driven through the real handler
-- rather than reached into.
local base = (arg and arg[0] and arg[0]:match("^(.*[/\\])tests[/\\]protocol%.lua$")) or "./"

local PREFIX = "ForeverGrpComms"
local clock = 100
local timers, traffic = {}, {}
local quests = {
    {questID=101, title="Dungeon Starter", isHeader=false},
    {questID=202, title="Collect Shells", isHeader=false},
}
local completed = {[303]=true}
local people = {
    player = {name="Alice Example", level=24, role="HEALER", guid="P1"},
    party1 = {name="Ben Another", level=26, role="TANK", guid="P2"},
}

_G.DEFAULT_CHAT_FRAME = {AddMessage = function() end}
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
    IsQuestFlaggedCompleted = function(id) return completed[id] == true end,
    IsPushableQuest = function() return true end,
}
_G.C_ChatInfo = {
    RegisterAddonMessagePrefix = function() return 0 end,
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

local SENDER = "Ben Another"
local SENDER_KEY = "ben another"
assert(A.roster[SENDER_KEY], "precondition: the sender must be in the roster")
assert(A.playerKey == "alice example", "precondition: player key, got " .. A.playerKey)

local function reset()
    wipe(A.questPeers)
    wipe(A.questParts)
    wipe(A.addonOutbox)
    A.lastPartPrune = nil
end
-- A packet is "accepted" only if it left peer state behind.
local function feed(message, channel, sender)
    A:OnAddonMessage(PREFIX, message, channel or "PARTY", sender or SENDER)
end
local function accepted()
    local peer = A.questPeers[SENDER_KEY]
    return peer ~= nil and (peer.active ~= nil or peer.completed ~= nil)
end
local function rejects(message, label, channel, sender)
    reset()
    feed(message, channel, sender)
    -- Check the WHOLE peer table, not just this sender's slot. A packet from an
    -- unexpected sender would land under its own key, so asserting against one key
    -- would let a dropped sender check pass unnoticed.
    assert(next(A.questPeers) == nil, "should have been rejected: " .. label ..
        "\n  payload: " .. tostring(message) ..
        "\n  but peer state was recorded")
    assert(next(A.questParts) == nil,
        "a rejected packet must not leave reassembly state: " .. label)
end
local function acceptsQ(message, label)
    reset()
    feed(message)
    assert(accepted(), "should have been accepted: " .. label ..
        "\n  payload: " .. tostring(message))
end

-- Sanity: the shape every negative case below is a mutation of.
acceptsQ("Q|1|12|1|1|101", "a well-formed single-chunk Q packet")
assert(A.questPeers[SENDER_KEY].active[101], "the advertised quest was recorded")
-- An empty CSV is legal and means "I have no active quests".
acceptsQ("Q|1|12|1|1|", "an empty quest list is a valid statement, not a malformed one")
assert(next(A.questPeers[SENDER_KEY].active) == nil, "an empty list records no quests")

-- Envelope: prefix, type, group membership, sender identity, channel.
reset()
A:OnAddonMessage("SomeOtherAddon", "Q|1|12|1|1|101", "PARTY", SENDER)
assert(not accepted(), "another addon's prefix must be ignored")
reset()
A:OnAddonMessage(PREFIX, nil, "PARTY", SENDER)
assert(not accepted(), "a non-string body must be ignored")
reset()
A:OnAddonMessage(PREFIX, {}, "PARTY", SENDER)
assert(not accepted(), "a table body must be ignored")
rejects("Q|1|12|1|1|101", "a sender who is not in the group roster", "PARTY", "Stranger")
rejects("Q|1|12|1|1|101", "a packet apparently from the player themself", "PARTY",
    "Alice Example")
rejects("Q|1|12|1|1|101", "an unresolvable empty sender", "PARTY", "")
rejects("Q|1|12|1|1|101", "guild chat is not a quest-sync channel", "GUILD")
rejects("Q|1|12|1|1|101", "a custom chat channel", "CHANNEL")
rejects("Q|1|12|1|1|101", "a yell", "YELL")
reset()
A:OnAddonMessage(PREFIX, "Q|1|12|1|1|101", nil, SENDER)
assert(not accepted(), "a message with no channel at all must be ignored")
for _, channel in ipairs({"PARTY", "RAID", "INSTANCE_CHAT", "WHISPER"}) do
    reset()
    feed("Q|1|12|1|1|101", channel)
    assert(accepted(), channel .. " must be an accepted channel")
end

-- Header: kind, protocol, field count, emptiness.
rejects("X|1|12|1|1|101", "an unknown packet kind")
rejects("q|1|12|1|1|101", "a lowercase kind")
rejects("Q|2|12|1|1|101", "a future protocol version")
rejects("Q||12|1|1|101", "an empty protocol field")
rejects("Q|1|12|1|1", "too few fields")
rejects("Q|1||1|1|101", "an empty epoch field")
rejects("Q|1|12||1|101", "an empty part field")
rejects("Q|1|12|1||101", "an empty total field")
rejects("", "an empty message")
rejects("Q", "a truncated message")
rejects("not a packet at all", "unstructured text")

-- Numeric ranges and integrality.
rejects("Q|1|0|1|1|101", "epoch below the minimum")
rejects("Q|1|100000001|1|1|101", "epoch above the maximum")
rejects("Q|1|1.5|1|1|101", "a fractional epoch")
rejects("Q|1|abc|1|1|101", "a non-numeric epoch")
-- Exponent notation is accepted, because tonumber("1e2") is the integer 100 and 100 is
-- a legal epoch. Harmless, and pinned here so the integrality check is not mistaken for
-- a syntactic one: it rejects non-integers, not unusual spellings of integers.
acceptsQ("Q|1|1e2|1|1|101", "an exponent-notation epoch that resolves to an integer")
assert(A.questPeers[SENDER_KEY].epoch == 100, "1e2 is read as epoch 100, got " ..
    tostring(A.questPeers[SENDER_KEY].epoch))
rejects("Q|1|12|0|1|101", "part below 1")
rejects("Q|1|12|2|1|101", "part greater than total")
rejects("Q|1|12|1|0|101", "total below 1")
rejects("Q|1|12|1|13|101", "total above the 12-chunk ceiling")
rejects("Q|1|12|1.5|2|101", "a fractional part")
rejects("Q|1|12|1|2.5|101", "a fractional total")

-- Payload: the character-class gate, comma placement, id range, length.
rejects("Q|1|12|1|1|101,abc", "a non-numeric id")
rejects("Q|1|12|1|1|101;202", "a semicolon separator")
rejects("Q|1|12|1|1|101 202", "a space separator")
rejects("Q|1|12|1|1|-101", "a negative id")
rejects("Q|1|12|1|1|10.1", "a decimal id")
rejects("Q|1|12|1|1|0x65", "a hex id")
rejects("Q|1|12|1|1|,101", "a leading comma")
rejects("Q|1|12|1|1|101,", "a trailing comma")
rejects("Q|1|12|1|1|101,,202", "a doubled comma")
rejects("Q|1|12|1|1|0", "quest id zero")
rejects("Q|1|12|1|1|100000000", "a quest id above the maximum")
rejects("Q|1|12|1|1|101|202", "a pipe smuggled into the payload")
-- Isolate the length rule: these two payloads are character-for-character valid and
-- every id is in range, so only the 230-byte cap can separate them. A single long run
-- of digits would be rejected by the id ceiling instead and prove nothing about length.
local atCap = string.rep("11,", 76) .. "11"        -- 230 bytes
local overCap = string.rep("11,", 76) .. "111"     -- 231 bytes
assert(#atCap == 230 and #overCap == 231, "payload fixtures must straddle the cap")
rejects("Q|1|12|1|1|" .. overCap, "a payload one byte past the 230-byte cap")
-- A pattern metacharacter must be refused as data, never compiled.
rejects("Q|1|12|1|1|10%d", "a Lua pattern metacharacter in the payload")
rejects("Q|1|12|1|1|.*", "a wildcard payload")
-- The boundaries themselves are legal.
acceptsQ("Q|1|12|1|1|1", "the lowest valid quest id")
acceptsQ("Q|1|12|1|1|99999999", "the highest valid quest id")
acceptsQ("Q|1|1|1|1|101", "the lowest valid epoch")
acceptsQ("Q|1|100000000|1|1|101", "the highest valid epoch")
acceptsQ("Q|1|12|1|1|" .. atCap, "a payload at exactly the 230-byte cap")

-- Reassembly: nothing is acted on until every chunk arrives.
reset()
feed("Q|1|20|1|2|101")
assert(not accepted(), "a partial set must not be acted on")
assert(A.questParts[SENDER_KEY .. ":Q:20"], "the first chunk is held pending")
feed("Q|1|20|2|2|202")
assert(accepted(), "the set completes once the last chunk arrives")
local active = A.questPeers[SENDER_KEY].active
assert(active[101] and active[202], "both chunks merged")
assert(next(A.questParts) == nil, "completed reassembly releases its slot")

-- A chunk claiming a different total than the set in progress is refused.
reset()
feed("Q|1|21|1|3|101")
feed("Q|1|21|2|2|202")
assert(not accepted(), "a total that disagrees mid-reassembly is refused")

-- A re-sent chunk overwrites rather than duplicating, and stale parts expire.
reset()
feed("Q|1|22|1|2|101")
clock = clock + 61
feed("Q|1|22|2|2|202")
assert(not accepted(), "a chunk arriving after the 60-second part window starts over")
clock = 100

-- Epoch ordering: an older advertisement must never overwrite a newer one.
reset()
feed("Q|1|30|1|1|101")
assert(A.questPeers[SENDER_KEY].epoch == 30, "newer epoch recorded")
feed("Q|1|29|1|1|202")
assert(A.questPeers[SENDER_KEY].epoch == 30, "an older epoch is ignored")
assert(A.questPeers[SENDER_KEY].active[101] and not A.questPeers[SENDER_KEY].active[202],
    "the older advertisement's payload must not be applied")
feed("Q|1|31|1|1|202")
assert(A.questPeers[SENDER_KEY].epoch == 31, "a newer epoch replaces the advertisement")

-- Completion replies are only trusted for the log we most recently advertised, so a
-- stale reply cannot make a peer look like they are missing a quest.
reset()
A.questEpoch = 7
feed("R|1|7|1|1|303", "WHISPER")
assert(A.questPeers[SENDER_KEY].completed[303], "a reply matching our epoch is accepted")
assert(A.questPeers[SENDER_KEY].completionEpoch == 7, "the reply epoch is recorded")
reset()
feed("R|1|6|1|1|303", "WHISPER")
assert(not accepted(), "a reply to a previous advertisement is discarded")
reset()
feed("R|1|8|1|1|303", "WHISPER")
assert(not accepted(), "a reply quoting an epoch we never sent is discarded")

-- Nothing from the wire is ever used as a name: peer names come from the roster.
-- A peer only counts as known once BOTH its advertisement and a completion reply for
-- our current epoch have arrived, so feed the pair before reading the rows.
reset()
A.questEpoch = 7
feed("Q|1|40|1|1|101")
feed("R|1|7|1|1|", "WHISPER")
local rows = A:QuestRows()
local byId = {}
for _, row in ipairs(rows) do byId[row.id] = row end
assert(#byId[101].shared == 1 and byId[101].shared[1] == "Ben Another",
    "the displayed name comes from the roster, not the packet")

-- An ungrouped client ignores traffic entirely.
reset()
A.activeGroup = false
feed("Q|1|50|1|1|101")
assert(not accepted(), "an ungrouped client records nothing")
A.activeGroup = true

print("PASSED: envelope, sender, channel, header, numeric range, integrality, payload " ..
      "character class, comma placement, id bounds, length cap, pattern metacharacters, " ..
      "reassembly totals and expiry, epoch ordering, reply-epoch matching")
