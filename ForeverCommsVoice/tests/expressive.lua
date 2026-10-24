-- Run from the addon root: lua5.1 tests/expressive.lua
--
-- Pins the full scope matrix for accent strength, which is the question item 24 asked:
-- the Expressive terminal-punctuation rule is NOT guild-only. It also reaches group
-- greet/welcome/level, and that is deliberate. The decision was to keep the group
-- behaviour and document it, so this harness is the executable half of that decision.
--
-- The rule lives in applyFlair() in Core.lua and is gated by flairApplies(scope, kind):
--   guild  -> every kind except `help`, which stays scannable for [LFG]
--   group  -> only greet, welcome and level; never a combat or coordination directive
-- Strength layers on top: subtle changes nothing, moderate adds the catchphrase prefix,
-- expressive adds the prefix AND amplifies the final mark (`.` -> `!`, `!` -> `!!`).
local base = (arg and arg[0] and arg[0]:match("^(.*[/\\])tests[/\\]expressive%.lua$")) or "./"

_G.SlashCmdList = {}
_G.CreateFrame = function() return {RegisterEvent=function()end, SetScript=function()end} end
_G.UnitRace = function() return "Human", "Human", 1 end

local V = {}
for _, m in ipairs({"Core.lua", "Languages.lua", "Accents.lua", "RaceProfiles.lua",
                    "MessageVariants.lua", "GroupPhrases.lua"}) do
    assert(loadfile(base .. m))("ForeverCommsVoice", V)
end
_G.ForeverCommsVoice = V

-- raceFilter off so a Human test character may wear the Kaldorei/Tauren/Dwarf voices.
assert(V:SetOption("language", "en"))
assert(V:SetOption("raceFilter", false))

local vars = {name="Keeper", level=31, roles="Alice: Tank", quest="[Q]"}
local function render(scope, kind, accent, strength)
    assert(V:SetOption("accent", accent), "accent " .. accent .. " unavailable")
    assert(V:SetOption("accentStrength", strength))
    -- random=false keeps the first template, so every expectation below is exact.
    return V:Render(scope, kind, vars, {random=false})
end
local function eq(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s\n  expected: %s\n  actual:   %s", label, expected, actual), 2)
    end
end
local function occurrences(haystack, needle)
    local count, at = 0, 1
    while true do
        local s, e = haystack:find(needle, at, true)
        if not s then return count end
        count, at = count + 1, e + 1
    end
end

-- 1. Group social kind WITH a curated accent wording (groupAccentVariants.nightelf.greet).
-- The curated sentence replaces the candidate list, so the catchphrase prefix is
-- suppressed to avoid stacking two invocations. Expressive still rewrites the final mark.
eq(render("group", "greet", "nightelf", "subtle"),
   "May the stars guide our group.", "group greet, curated, subtle")
eq(render("group", "greet", "nightelf", "moderate"),
   "May the stars guide our group.", "group greet, curated, moderate adds no prefix")
eq(render("group", "greet", "nightelf", "expressive"),
   "May the stars guide our group!", "group greet, curated, expressive converts the period")
for _, strength in ipairs({"subtle", "moderate", "expressive"}) do
    local out = render("group", "greet", "nightelf", strength)
    assert(not out:find("By the stars", 1, true),
        "a curated group wording must not also take the catchphrase prefix (" .. strength .. ")")
end

-- 2. Group social kind WITHOUT a curated accent wording. The neutral template is used,
-- so the prefix DOES apply, and expressive doubles the existing exclamation.
eq(render("group", "level", "nightelf", "subtle"),
   "Grats on 31, Keeper!", "group level, uncurated, subtle")
eq(render("group", "level", "nightelf", "moderate"),
   "By the stars, Grats on 31, Keeper!", "group level, uncurated, moderate")
eq(render("group", "level", "nightelf", "expressive"),
   "By the stars, Grats on 31, Keeper!!", "group level, uncurated, expressive doubles the !")
eq(render("group", "welcome", "nightelf", "expressive"),
   "By the stars, Welcome to the group, Keeper!!", "group welcome is a social kind too")

-- Expressive differs from moderate by punctuation alone, never by wording.
local moderate = render("group", "level", "nightelf", "moderate")
eq(render("group", "level", "nightelf", "expressive"), moderate .. "!",
   "expressive is moderate plus one mark when the template already ends in !")

-- 3. Every other group kind is untouched at expressive: no prefix, no punctuation change.
-- This is the half of the contract that keeps a dungeon instruction readable.
for _, kind in ipairs({"skull", "cc", "pull", "mana", "regroup", "heal", "interrupt",
                       "roles", "quests", "request"}) do
    local neutral = V:Format(V.groupTemplates.en[kind][1], vars)
    eq(render("group", kind, "nightelf", "expressive"), neutral,
       "group " .. kind .. " must be byte-identical to the neutral template at expressive")
end

-- The headline contrast: at the same setting, a social line loses its full stop and a
-- combat directive keeps it.
eq(render("group", "skull", "nightelf", "expressive"):sub(-1), ".",
   "a combat directive keeps its terminal period at expressive")
eq(render("group", "greet", "nightelf", "expressive"):sub(-1), "!",
   "a social greeting loses its terminal period at expressive")

-- 4. A curated wording that already opens with its own catchphrase is not given a second.
local dwarf = render("group", "greet", "dwarf", "expressive")
eq(dwarf, "By the forge! Good tae see ye all!!", "dwarf curated group greet")
eq(occurrences(dwarf, "By the forge!"), 1, "the catchphrase must not be duplicated")

-- 5. A second curated wording ending in a period, to show case 1 is not accent-specific.
eq(render("group", "greet", "tauren", "moderate"),
   "Walk in peace, companions.", "tauren curated greet, moderate")
eq(render("group", "greet", "tauren", "expressive"),
   "Walk in peace, companions!", "tauren curated greet, expressive")

-- 6. The guild side, kept here so both halves of flairApplies are pinned in one file.
eq(render("guild", "login", "nightelf", "moderate"),
   "By the stars, The stars welcome your return, Keeper.", "guild login, moderate")
eq(render("guild", "login", "nightelf", "expressive"),
   "By the stars, The stars welcome your return, Keeper!", "guild login, expressive")
local help = render("guild", "help", "nightelf", "expressive")
assert(help:sub(1, 5) == "[LFG]", "help must keep [LFG] at the front in every mode")
eq(help:sub(-1), ".", "help is exempt from the expressive punctuation change")
assert(not help:find("By the stars", 1, true), "help takes no catchphrase prefix")

print("PASSED: expressive scope matrix - group greet/welcome/level amplified, " ..
      "combat and coordination directives untouched, curated wordings keep one " ..
      "catchphrase, guild help exempt")
