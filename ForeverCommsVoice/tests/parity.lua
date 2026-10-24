-- Run from the addon root: lua5.1 tests/parity.lua
--
-- The bundle keeps three pairs of duplicated message tables, because each consuming
-- addon must still work if the library is absent. All three pairs are load-bearing and
-- drift in any of them is silent, so this harness asserts they are byte-identical.
--
-- The one with teeth is GuildComms' defaults.templates against the library's English
-- guild catalog. V:Render treats options.custom as a USER edit whenever it differs from
-- the English base, and user edits are deliberately never translated. So if GuildComms
-- ships a default that the library's catalog does not recognise, every player who never
-- touched that template looks like they customized it, and translation silently stops
-- for everyone. The behavioural half at the bottom pins that mechanism from both sides.
local base = (arg and arg[0] and arg[0]:match("^(.*[/\\])tests[/\\]parity%.lua$")) or "./"

_G.SlashCmdList, _G.StaticPopupDialogs = {}, {}
_G.CreateFrame = function() return {RegisterEvent=function()end, SetScript=function()end} end
_G.UnitRace = function() return "Human", "Human", 1 end
_G.UnitName = function() return "Hero" end
_G.UnitGUID = function() return "Player-1" end
_G.UnitClass = function() return "Mage", "MAGE" end
_G.IsInGuild = function() return true end
_G.GetGuildInfo = function() return "TestGuild" end
_G.GetTime = function() return 100 end
_G.C_Timer = {After=function() end, NewTicker=function() end}
_G.wipe = function(t) for k in pairs(t) do t[k]=nil end end
_G.DEFAULT_CHAT_FRAME = {AddMessage=function() end}
_G.IsInGroup = function() return false end
_G.IsInRaid = function() return false end

local V = {}
for _, m in ipairs({"Core.lua", "Languages.lua", "Accents.lua", "RaceProfiles.lua",
                    "MessageVariants.lua", "GroupPhrases.lua"}) do
    assert(loadfile(base .. m))("ForeverCommsVoice", V)
end
_G.ForeverCommsVoice = V

local A = {}
assert(loadfile(base .. "../ForeverGuildComms/Core.lua"))("ForeverGuildComms", A)
assert(loadfile(base .. "../ForeverGuildComms/VoiceBridge.lua"))("ForeverGuildComms", A)
local G = {}
assert(loadfile(base .. "../ForeverGroupComms/Core.lua"))("ForeverGroupComms", G)

local function firstOf(value)
    return type(value) == "table" and value[1] or value
end
local function sameKeySet(mine, theirs, label)
    for key in pairs(mine) do
        assert(theirs[key] ~= nil, label .. ": '" .. key .. "' is missing from the library")
    end
    for key in pairs(theirs) do
        assert(mine[key] ~= nil, label .. ": library has an extra kind '" .. key .. "'")
    end
end

-- 1. GuildComms' own defaults against the library's guild defaults.
sameKeySet(A.defaults.templates, V.defaults.templates, "guild defaults")
for kind, text in pairs(A.defaults.templates) do
    assert(text == V.defaults.templates[kind], string.format(
        "guild default '%s' has drifted from V.defaults.templates\n  guild: %s\n  voice: %s",
        kind, tostring(text), tostring(V.defaults.templates[kind])))
end

-- 2. The pair that drives custom-template detection: GuildComms' defaults against the
-- English entry of the registered guild catalog, which is what V:Render compares to.
assert(type(V.localeTemplates) == "table" and type(V.localeTemplates.en) == "table",
    "the guild catalog must expose an English table")
for kind, text in pairs(A.defaults.templates) do
    local englishBase = firstOf(V.localeTemplates.en[kind])
    assert(text == englishBase, string.format(
        "guild default '%s' does not match the English catalog base, so an untouched " ..
        "template would be mistaken for a user edit and never translated\n" ..
        "  guild default: %s\n  catalog base : %s",
        kind, tostring(text), tostring(englishBase)))
end

-- 3. GroupComms' standalone variants against the library's English group catalog.
-- Order matters as well as content: both sides index [1] as the non-random default.
sameKeySet(G.variants, V.groupTemplates.en, "group variants")
for kind, list in pairs(G.variants) do
    local theirs = V.groupTemplates.en[kind]
    assert(#list == #theirs, string.format(
        "group '%s' has %d local variants but %d in the library catalog",
        kind, #list, #theirs))
    for i = 1, #list do
        assert(list[i] == theirs[i], string.format(
            "group '%s' variant %d has drifted\n  group: %s\n  voice: %s",
            kind, i, list[i], theirs[i]))
    end
end

-- 4. The behaviour the parity protects, asserted from both directions. An untouched
-- default must translate; a genuinely edited template must not.
A.db = {enabled=true, templates={}, randomizeMessages=false}
for kind, text in pairs(A.defaults.templates) do A.db.templates[kind] = text end
A.char = {voice=V:GetSettings()}
assert(V:SetOption("language", "es"))

local translated = A:CommsText("login", {name="Rosa"})
assert(translated:find("Rosa", 1, true), "the player name must survive translation")
assert(translated ~= A.defaults.templates.login,
    "an untouched default must be translated, not returned verbatim")
assert(translated:find("Bienvenido", 1, true),
    "an untouched guild default must reach the Spanish catalog, got: " .. translated)

A.db.templates.login = "Totally custom, {name}."
local custom = A:CommsText("login", {name="Rosa"})
assert(custom == "Totally custom, Rosa.",
    "a user-edited template must be used verbatim and never translated, got: " .. custom)

-- Simulate the drift this harness exists to catch: a default that no longer matches the
-- catalog is indistinguishable from a user edit, so translation stops.
A.db.templates.login = A.defaults.templates.login .. " "
local drifted = A:CommsText("login", {name="Rosa"})
assert(not drifted:find("Bienvenido", 1, true),
    "a drifted default must demonstrably lose translation; if this fails the " ..
    "custom-detection mechanism changed and assertion 2 above may no longer matter")

assert(V:SetOption("language", "en"))
print("PASSED: guild defaults match the library and its English catalog, group variants " ..
      "match entry for entry, untouched defaults translate and user edits do not")
