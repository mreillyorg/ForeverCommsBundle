-- Run from the addon root: lua5.1 tests/roster.lua
--
-- Two things that have carried untested since 0.1.0:
--
-- 1. A:IsSelf realm handling. Getting this wrong in either direction is bad: too loose
--    and the addon congratulates the player on their own level-up (a headline non-goal);
--    too strict and it greets itself. The rule is that only an explicit "-Realm" suffix
--    may be stripped, never a prefix, because two guildmates can share a first name.
-- 2. The suspicious-roster-read guard. The client briefly reports a partial guild roster
--    after a zone change, and acting on that would greet everyone at once as they
--    "come online". Discarding a read is always preferred over a burst of chat.
--
-- This is the first harness in the package to mock GetNumGuildMembers/GetGuildRosterInfo,
-- so it drives the real A:ReadRoster rather than hand-feeding A:AcceptRoster the way
-- tests/smoke.lua does.
local base = (arg and arg[0] and arg[0]:match("^(.*[/\\])tests[/\\]roster%.lua$")) or "./"

local clock = 1000
local scheduled = {}
local guild = "TestGuild"
-- The roster the fake client will report. Index order is irrelevant to ReadRoster,
-- which keys by normalized name.
local members = {}

_G.print = print
_G.StaticPopupDialogs, _G.SlashCmdList = {}, {}
_G.UnitName = function() return "Hero" end
_G.GetUnitName = function(unit, withRealm)
    if unit == "player" and withRealm then return "Hero-Ravenholdt" end
    return "Hero"
end
_G.UnitFullName = function() return "Hero" end
_G.UnitGUID = function() return "Player-123" end
_G.UnitClass = function() return "Mage", "MAGE" end
_G.GetTime = function() return clock end
_G.IsInGuild = function() return guild ~= nil end
_G.GetGuildInfo = function() return guild end
_G.GetNumGuildMembers = function() return #members end
_G.GetGuildRosterInfo = function(i)
    local m = members[i]
    if not m then return nil end
    -- ReadRoster reads positions 1, 4, 9 and 17 out of Blizzard's 17-value tuple.
    return m.name, nil, nil, m.level, nil, nil, nil, nil, m.online,
           nil, nil, nil, nil, nil, nil, nil, m.guid
end
_G.C_Timer = {
    After = function(delay, callback) scheduled[#scheduled+1] = {delay=delay, cb=callback} end,
    NewTicker = function() end,
}
_G.SendChatMessage = function() end
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end end
_G.CreateFrame = function() return {RegisterEvent=function()end, SetScript=function()end} end
_G.ERR_GUILD_JOIN_S = "%s has joined the guild."
_G.date = function() return "12:00" end
_G.ForeverGuildCommsDB, _G.ForeverGuildCommsCharDB = {}, {}

local A = {}
assert(loadfile(base .. "Core.lua"))("ForeverGuildComms", A)
local V = {}
local voicePath = (os.getenv and os.getenv("FOREVER_VOICE_PATH")) or (base .. "../ForeverCommsVoice/")
for _, mod in ipairs({"Core.lua", "Languages.lua", "Accents.lua", "RaceProfiles.lua",
                      "MessageVariants.lua", "GroupPhrases.lua"}) do
    assert(loadfile(voicePath .. mod))("ForeverCommsVoice", V)
end
_G.ForeverCommsVoice = V
assert(loadfile(base .. "VoiceBridge.lua"))("ForeverGuildComms", A)
assert(loadfile(base .. "Roster.lua"))("ForeverGuildComms", A)

local function runScheduled()
    -- Run whatever is pending, allowing callbacks to schedule more.
    local guard = 0
    while #scheduled > 0 do
        guard = guard + 1
        assert(guard < 50, "scheduled callbacks are not settling")
        local timer = table.remove(scheduled, 1)
        timer.cb()
    end
end

A:Initialize()
local queued = {}
A.QueueGuild = function(_, message, key, cooldown)
    queued[#queued+1] = {message=message, key=key, cooldown=cooldown}
end

-- ---------------------------------------------------------------- A:IsSelf

-- Initialize must have built selfKeys from all three player-name APIs.
assert(A.playerGuid == "Player-123", "player GUID captured")
assert(A.playerKey == "hero", "player key normalized")
assert(A.selfKeys["hero"], "bare name in selfKeys")
assert(A.selfKeys["hero-ravenholdt"], "realm-qualified name in selfKeys")

local isSelf = {
    -- The GUID is authoritative and is checked before the name.
    {true,  "Someoneelse", "Player-123", "GUID match outranks a mismatched name"},
    {true,  nil,           "Player-123", "GUID match with no name at all"},
    {true,  "Hero",        "Other-9",    "name match still works when the GUID differs"},
    -- Name normalization: case, leading/trailing space, collapsed whitespace.
    {true,  "Hero",        nil, "exact name"},
    {true,  "hero",        nil, "lowercased"},
    {true,  "  HERO  ",    nil, "trimmed and lowercased"},
    -- Realm handling.
    {true,  "Hero-Ravenholdt",   nil, "own realm-qualified name, direct selfKeys hit"},
    {true,  "Hero-Someotherrealm", nil, "realm suffix stripped back to the player key"},
    -- The reason prefixes are never stripped: shared first names on Forever.
    {false, "Herolin",  nil, "a longer name that merely starts with the player's"},
    {false, "Heroic",   nil, "another prefix collision"},
    {false, "Her",      nil, "a shorter name that is a prefix of the player's"},
    {false, "Hero Smith", nil, "a two-word name is not shortened at the space"},
    {false, "Alice",    nil, "an unrelated guildmate"},
    {false, "Alice-Ravenholdt", nil, "an unrelated guildmate on the player's realm"},
    {false, "Hero-",    nil, "a trailing hyphen is not a realm suffix"},
    {false, nil,        nil, "no name and no GUID"},
    {false, nil,        "Other-9", "no name with a foreign GUID"},
}
for _, case in ipairs(isSelf) do
    local want, name, guid, label = case[1], case[2], case[3], case[4]
    local got = A:IsSelf(name, guid) and true or false
    assert(got == want, string.format("IsSelf(%s, %s) should be %s -- %s",
        tostring(name), tostring(guid), tostring(want), label))
end

-- A GUID comparison is exact; a differently-cased GUID is a different player.
assert(not A:IsSelf("Alice", "player-123"), "GUID comparison must be case sensitive")

-- ------------------------------------------------- suspicious roster reads

-- Build a guild of 20 so the 70% rule is in play (it only applies above 10 members).
local function setMembers(count, onlineCount)
    members = {}
    -- count == 0 must really produce an empty roster, otherwise the zero-member rule is
    -- never reached and the 70% rule silently stands in for it.
    for i = 1, count do
        if i == 1 then
            members[1] = {name="Hero", level=20, online=true, guid="Player-123"}
        else
            members[i] = {name="Member" .. i, level=20,
                          online=i <= (onlineCount or count), guid="Other-" .. i}
        end
    end
end

setMembers(20, 20)
A.rosterGuild = nil
A.rosterReady = false
A:OnRosterEvent("PLAYER_GUILD_UPDATE")
runScheduled()
assert(A.rosterReady, "the deferred baseline capture must have run")
assert(A.guildCount == 20, "baseline recorded the full count, got " .. tostring(A.guildCount))
assert(#queued == 0, "the baseline read must never send anything")

local function expectDiscarded(count, label)
    local keptRoster, keptCount, keptOnline = A.roster, A.guildCount, A.onlineCount
    local before = #queued
    setMembers(count, count)
    A:OnRosterEvent("GUILD_ROSTER_UPDATE")
    assert(A.roster == keptRoster, label .. ": roster table must be left untouched")
    assert(A.guildCount == keptCount, label .. ": guildCount must be left untouched")
    assert(A.onlineCount == keptOnline, label .. ": onlineCount must be left untouched")
    assert(A.rosterReady, label .. ": rosterReady must stay true")
    assert(#queued == before, label .. ": a discarded read must queue no messages")
end
local function expectAccepted(count, label)
    setMembers(count, count)
    A:OnRosterEvent("GUILD_ROSTER_UPDATE")
    assert(A.guildCount == count, label .. ": expected the read to be accepted")
end

-- Zero members is always rejected, whatever the known count. This is the only rule a
-- guild of 10 or fewer gets, so it is asserted again further down against a small guild.
expectDiscarded(0, "an empty roster read")
-- Known 20, so the floor is 14. Strictly below is rejected, exactly 70% is accepted.
expectDiscarded(1, "a near-empty read")
expectDiscarded(13, "a read at 65% of the known count")
expectAccepted(14, "a read at exactly 70% of the known count")

-- The rule compounds: the known count is now 14, so the floor has moved to 9.8 and a
-- read of 8 is still a collapse. This is deliberate - a guild shrinking for real takes
-- several accepted reads to walk the floor down, and each discarded read costs nothing
-- but a 60-second wait for the next poll.
expectDiscarded(8, "a read below the floor recomputed from the new known count")
expectAccepted(10, "a read at 71% of 14 is accepted and lowers the known count to 10")

-- At or below 10 members only the zero rule applies, because a real three-member guild
-- losing one member is a 33% drop that must not be mistaken for a partial read.
assert(A.guildCount == 10, "precondition: the threshold test needs a known count of 10")
expectDiscarded(0, "an empty read on a small guild")
expectAccepted(3, "a small guild may shrink sharply without being second-guessed")

-- A guild change must reset state and re-enter the baseline path, so the 70% rule
-- cannot compare counts across two different guilds.
A.pendingMessages[#A.pendingMessages+1] = {text="queued for the old guild", guild="TestGuild"}
guild = "DifferentGuild"
setMembers(30, 30)
A:OnRosterEvent("PLAYER_GUILD_UPDATE")
assert(#A.pendingMessages == 0, "queued messages must not leak into a new guild")
assert(not A.rosterReady, "a guild change must clear rosterReady")
assert(A.guildCount == 0, "a guild change must clear the known count")
local before = #queued
runScheduled()
assert(A.guildCount == 30, "the new guild gets a fresh baseline")
assert(#queued == before, "the new guild's baseline must send nothing")

-- Leaving the guild entirely is handled without error and sends nothing.
guild = nil
A:OnRosterEvent("PLAYER_GUILD_UPDATE")
assert(not A.rosterReady, "leaving the guild clears rosterReady")
assert(#queued == before, "leaving the guild sends nothing")

print("PASSED: IsSelf GUID/name/realm matrix including prefix collisions, baseline " ..
      "sends nothing, empty and collapsed reads discarded without touching state, " ..
      "small guilds exempt from the 70% rule, guild change resets and re-baselines")
