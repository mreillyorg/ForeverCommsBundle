-- Run from the addon root: lua5.1 tests/bytelimit.lua
--
-- The 250-byte chat clamp, in all three places it exists:
--   ForeverCommsVoice  V:Format      (clamps after placeholder substitution)
--   ForeverGuildComms  A:ChatLimit
--   ForeverGroupComms  A:Trim
--
-- WoW caps a chat message in BYTES, not characters, so a translated or accented message
-- can reach the limit mid-character. Cutting there produces a truncated UTF-8 sequence,
-- which the client renders as a replacement glyph or drops. Only the two-byte case was
-- ever tested, and only in one of the three copies.
--
-- Rather than assert hand-computed outputs, this derives the correct cut from the rule
-- the implementations are supposed to follow -- keep the longest prefix of at most 250
-- bytes that does not end inside a character -- and checks all three agree with it.
local base = (arg and arg[0] and arg[0]:match("^(.*[/\\])tests[/\\]bytelimit%.lua$")) or "./"

_G.SlashCmdList, _G.StaticPopupDialogs = {}, {}
_G.CreateFrame = function() return {RegisterEvent=function()end, SetScript=function()end} end
_G.UnitRace = function() return "Human", "Human", 1 end
_G.UnitName = function() return "Hero" end
_G.UnitGUID = function() return "Player-1" end
_G.UnitClass = function() return "Mage", "MAGE" end
_G.IsInGuild = function() return true end
_G.GetGuildInfo = function() return "TestGuild" end
_G.GetTime = function() return 100 end
_G.C_Timer = {After = function() end, NewTicker = function() end}
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end end
_G.DEFAULT_CHAT_FRAME = {AddMessage = function() end}
_G.IsInGroup = function() return false end
_G.IsInRaid = function() return false end
_G.ForeverCommsVoiceCharDB = {}

local V = {}
for _, m in ipairs({"Core.lua", "Languages.lua", "Accents.lua", "RaceProfiles.lua",
                    "MessageVariants.lua", "GroupPhrases.lua"}) do
    assert(loadfile(base .. m))("ForeverCommsVoice", V)
end
_G.ForeverCommsVoice = V
local A = {}
assert(loadfile(base .. "../ForeverGuildComms/Core.lua"))("ForeverGuildComms", A)
local G = {}
assert(loadfile(base .. "../ForeverGroupComms/Core.lua"))("ForeverGroupComms", G)

-- Characters written as byte escapes so this file's own encoding cannot affect the test.
local CHARS = {
    {width = 2, bytes = "\195\169",             name = "2-byte U+00E9 e-acute"},
    {width = 3, bytes = "\226\130\172",         name = "3-byte U+20AC euro sign"},
    {width = 3, bytes = "\230\184\172",         name = "3-byte U+6E2C CJK ideograph"},
    {width = 4, bytes = "\240\159\142\137",     name = "4-byte U+1F389 party popper"},
    {width = 4, bytes = "\240\144\128\128",     name = "4-byte U+10000 linear B"},
}
for _, char in ipairs(CHARS) do
    assert(#char.bytes == char.width, char.name .. " fixture has the wrong byte length")
end

-- The three implementations under test, each reduced to string -> string.
local CLAMPS = {
    {name = "ForeverCommsVoice V:Format", fn = function(s) return V:Format(s, nil) end},
    {name = "ForeverGuildComms A:ChatLimit", fn = function(s) return A:ChatLimit(s) end},
    {name = "ForeverGroupComms A:Trim", fn = function(s) return G:Trim(s) end},
}

-- Walk a string and confirm every UTF-8 sequence in it is complete and well formed.
-- This is what the clamp exists to guarantee, so it is checked directly rather than
-- inferred from the output length.
local function utf8Complete(s)
    local i, n = 1, #s
    while i <= n do
        local b = s:byte(i)
        local width
        if b < 0x80 then width = 1
        elseif b >= 0xC2 and b <= 0xDF then width = 2
        elseif b >= 0xE0 and b <= 0xEF then width = 3
        elseif b >= 0xF0 and b <= 0xF4 then width = 4
        else return false, "byte " .. i .. " (" .. b .. ") is not a valid lead byte" end
        if i + width - 1 > n then
            return false, "truncated " .. width .. "-byte sequence at byte " .. i
        end
        for k = 1, width - 1 do
            local cont = s:byte(i + k)
            if cont < 0x80 or cont > 0xBF then
                return false, "byte " .. (i + k) .. " is not a continuation byte"
            end
        end
        i = i + width
    end
    return true
end
assert(utf8Complete("plain ascii"))
assert(utf8Complete("\226\130\172"))
assert(not utf8Complete("\226\130"), "the validator must reject a truncated sequence")
assert(not utf8Complete("\226"), "the validator must reject a lone lead byte")

-- The rule the clamp must implement: the longest prefix of at most 250 bytes whose next
-- byte is not a continuation byte.
local function expectedCut(text)
    if #text <= 250 then return #text end
    local limit = 250
    while limit > 0 do
        local b = text:byte(limit + 1)
        if not b or b < 0x80 or b >= 0xC0 then break end
        limit = limit - 1
    end
    return limit
end

local checks = 0
local function checkAll(text, label)
    local cut = expectedCut(text)
    local want = text:sub(1, cut)
    local ok, why = utf8Complete(want)
    assert(ok, "the expectation itself is malformed for " .. label .. ": " .. tostring(why))
    for _, clamp in ipairs(CLAMPS) do
        local got = clamp.fn(text)
        assert(#got <= 250, string.format(
            "%s returned %d bytes for %s; the chat limit is 250",
            clamp.name, #got, label))
        local valid, reason = utf8Complete(got)
        assert(valid, string.format("%s produced malformed UTF-8 for %s: %s",
            clamp.name, label, tostring(reason)))
        assert(got == want, string.format(
            "%s cut %s at %d bytes, expected %d",
            clamp.name, label, #got, #want))
        checks = checks + 1
    end
end

-- A character straddling the boundary must be dropped whole, at every offset where it
-- can straddle, for every width. This is the case the existing test covered for 2 bytes
-- only; 3- and 4-byte characters back up further and were never exercised.
for _, char in ipairs(CHARS) do
    for leading = 250 - char.width, 251 do
        if leading >= 0 then
            local text = string.rep("a", leading) .. char.bytes .. string.rep("z", 60)
            assert(#text > 250, "fixture must exceed the limit")
            checkAll(text, string.format("%s starting at byte %d", char.name, leading + 1))
        end
    end
end

-- A string made only of multi-byte characters: the cut has to land on a character
-- boundary, which for a 3-byte character means 249 bytes rather than 250.
for _, char in ipairs(CHARS) do
    -- 200 repetitions clears 250 bytes for every width, including the 2-byte case.
    local text = string.rep(char.bytes, 200)
    assert(#text > 250, "fixture must exceed the limit")
    local out = CLAMPS[1].fn(text)
    assert(#out % char.width == 0, string.format(
        "a run of %s must be cut on a character boundary, got %d bytes",
        char.name, #out))
    assert(#out == math.floor(250 / char.width) * char.width, string.format(
        "a run of %s should keep %d bytes, got %d",
        char.name, math.floor(250 / char.width) * char.width, #out))
    checkAll(text, "a solid run of " .. char.name)
end

-- Mixed content, which is what a translated accented message actually looks like.
for _, char in ipairs(CHARS) do
    local unit = "abc" .. char.bytes
    checkAll(string.rep(unit, 90), "repeated ascii + " .. char.name)
    checkAll(string.rep(char.bytes, 40) .. string.rep("a", 200) ..
             string.rep(char.bytes, 40), "multibyte head and tail, " .. char.name)
end

-- Nothing at or under the limit may be touched, including a message ending in a
-- multi-byte character at exactly byte 250.
for _, char in ipairs(CHARS) do
    local exact = string.rep("a", 250 - char.width) .. char.bytes
    assert(#exact == 250, "fixture is exactly at the limit")
    for _, clamp in ipairs(CLAMPS) do
        assert(clamp.fn(exact) == exact, string.format(
            "%s must not alter a message of exactly 250 bytes ending in %s",
            clamp.name, char.name))
        checks = checks + 1
    end
end
for _, clamp in ipairs(CLAMPS) do
    assert(clamp.fn("") == "", clamp.name .. " must pass an empty string through")
    assert(clamp.fn("short") == "short", clamp.name .. " must not alter a short message")
    local justUnder = string.rep("a", 249) .. "\195\169"
    assert(#justUnder == 251)
    assert(#clamp.fn(justUnder) == 249,
        clamp.name .. " must drop a 2-byte character that crosses the limit")
end

-- The clamp applies after placeholder substitution, so a short template with a long
-- substituted value is still clamped and still character-safe.
local long = string.rep("\226\130\172", 120)
local formatted = V:Format("Hi {name}", {name = long})
assert(#formatted <= 250, "V:Format clamps after substitution, got " .. #formatted)
assert(utf8Complete(formatted), "and keeps the substituted value character-safe")
assert(formatted:sub(1, 3) == "Hi ", "the template prefix survives")

print(string.format(
    "PASSED: %d clamp checks across 3 implementations and 5 characters - 2, 3 and " ..
    "4-byte sequences dropped whole at every straddling offset, solid multibyte runs " ..
    "cut on character boundaries, exact-250 messages untouched, substitution clamped",
    checks))
