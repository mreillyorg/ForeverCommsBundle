local ADDON, V = ...
_G.ForeverCommsVoice = V
V.name, V.version = ADDON, "0.7.1-beta"
V.voiceDefaults = {language="en", accent="none", raceFilter=true, accentStrength="subtle"}
V.defaults = {templates={
    login="Welcome back, {name}!",
    join="Welcome to the guild, {name}!",
    level="Congratulations on level {level}, {name}!",
    help="[LFG] {type}: {activity}. I can fill: {myroles}. Looking for: {needed}. Whisper me!",
}}
V.roleNames = {tank="Tank", healer="Healer", damage="DPS"}
V.roleOrder = {"tank", "healer", "damage"}
V.catalogs = {}
-- Shuffle-bag state for V:Pick: exhaust every wording before reshuffling, while avoiding
-- an immediate repeat across two consecutive bags. Session-local by design, and declared
-- only here — MessageVariants.lua used to re-declare it, which silently replaced this
-- table because both files share one namespace and Core.lua loads first.
V.messageVariantBags = {}
V.initialized = false

function V:Print(message)
    if print then print("|cff55caffForeverCommsVoice|r: " .. tostring(message)) end
end

local function normalize(settings)
    for k, value in pairs(V.voiceDefaults) do
        if settings[k] == nil then settings[k] = value end
    end
    if not (V.languageByID or {})[settings.language] then settings.language = "en" end
    if settings.accentStrength ~= "subtle" and settings.accentStrength ~= "moderate" and settings.accentStrength ~= "expressive" then
        settings.accentStrength = "subtle"
    end
    if type(settings.raceFilter) ~= "boolean" then settings.raceFilter = true end
    if type(settings.accent) ~= "string" then settings.accent = "none" end
    return settings
end
function V:GetSettings()
    if type(_G.ForeverCommsVoiceCharDB) ~= "table" then _G.ForeverCommsVoiceCharDB = {} end
    local db = _G.ForeverCommsVoiceCharDB
    if type(db.voice) ~= "table" then db.voice = {} end
    self.char = {voice=normalize(db.voice)}
    return db.voice
end
function V:MigrateLegacy(legacy)
    local voice = self:GetSettings()
    local db = _G.ForeverCommsVoiceCharDB
    if not db.migratedFromGuild then
        if type(legacy) == "table" then
            for k in pairs(self.voiceDefaults) do
                if legacy[k] ~= nil then voice[k] = legacy[k] end
            end
            db.migratedFromGuild = true
        end
    end
    normalize(voice)
    local valid = false
    for _, entry in ipairs(self:GetAvailableAccents()) do
        if entry.id == voice.accent then valid = true; break end
    end
    if not valid then voice.accent = "auto" end
    return voice
end
function V:ValidateOption(key, value)
    if self.voiceDefaults[key] == nil then return false end
    if key == "language" then return self.languageByID[value] ~= nil end
    if key == "raceFilter" then return type(value) == "boolean" end
    if key == "accentStrength" then return value == "subtle" or value == "moderate" or value == "expressive" end
    if key == "accent" then
        for _, entry in ipairs(self:GetAvailableAccents()) do if entry.id == value then return true end end
    end
    return false
end
-- Bag signatures embed the language and accent, so changing either strands every bag
-- under the old signature: never read again, never freed. Reset on ANY successful option
-- write rather than just those two keys -- raceFilter can reassign the accent below, and
-- accentStrength changes the wording a selection renders into. Enumerating which keys
-- matter is a rule with edge cases; "any successful write" has none. The cost is at most
-- one repeated wording, because a bag is anti-repetition only, never correctness, and a
-- fresh shuffle is what a player expects after changing their voice anyway.
function V:ResetVariantBags()
    -- wipe is a WoW global; the offline harnesses run on plain Lua 5.1 without it.
    if wipe then return wipe(self.messageVariantBags) end
    for signature in pairs(self.messageVariantBags) do
        self.messageVariantBags[signature] = nil
    end
end
function V:SetOption(key, value)
    local voice = self:GetSettings()
    if not self:ValidateOption(key, value) then return false end
    voice[key] = value
    if key == "language" or key == "raceFilter" then
        local valid = false
        for _, entry in ipairs(self:GetAvailableAccents()) do if entry.id == voice.accent then valid = true end end
        if not valid then voice.accent = "auto" end
    end
    self:ResetVariantBags()
    if self.RefreshOptions then self:RefreshOptions() end
    if _G.ForeverGuildComms and _G.ForeverGuildComms.RefreshOptions then
        _G.ForeverGuildComms:RefreshOptions()
        if _G.ForeverGuildComms.UpdateRequestPreview then _G.ForeverGuildComms:UpdateRequestPreview() end
    end
    return true
end
function V:RegisterCatalog(scope, catalog)
    if type(scope) ~= "string" or type(catalog) ~= "table" then return false end
    self.catalogs[scope] = catalog
    return true
end
function V:Format(template, vars)
    local result = tostring(template or ""):gsub("{([%a]+)}", function(key)
        local value = vars and vars[key]
        return value == nil and ("{" .. key .. "}") or tostring(value)
    end)
    -- Preserve UTF-8 while respecting the WoW chat byte cap.
    if #result <= 250 then return result end
    local last = 250
    while last > 0 do
        local b = result:byte(last + 1)
        if not b or b < 128 or b >= 192 then break end
        last = last - 1
    end
    return result:sub(1, last)
end
function V:Pick(scope, kind, language, accent, base, additional, randomized)
    if not randomized then return base end
    local choices = {base}
    for _, candidate in ipairs(additional or {}) do
        if type(candidate) == "string" and candidate ~= "" and candidate ~= base then
            local duplicate = false
            for _, existing in ipairs(choices) do if existing == candidate then duplicate = true end end
            if not duplicate then choices[#choices+1] = candidate end
        end
    end
    if #choices == 1 then return base end
    local signature = table.concat({scope,kind,language,accent and accent.id or "none"}, ":")
    local bag = self.messageVariantBags[signature]
    if not bag or bag.count ~= #choices or bag.position > #bag.order then
        local order = {}
        for i=1,#choices do order[i]=i end
        -- Do NOT add math.randomseed here. It does not exist in the WoW environment,
        -- so the call would error at load; the client seeds the generator at startup.
        -- The offline harnesses DO run unseeded on a real Lua 5.1, which makes this
        -- shuffle repeat identically across runs. That is deliberate and useful: it is
        -- what lets tests/integration.lua assert shuffle behaviour at all. Seeing the
        -- repetition in a test run is not a bug to fix. It was filed as one once: see
        -- item 25 in SUGGESTED-CHANGES.md (decided SKIP) and the Avoid entry in
        -- .kiro/steering/lua-style.md.
        for i=#order,2,-1 do local j=math.random(i); order[i],order[j]=order[j],order[i] end
        if bag and bag.last and order[1]==bag.last then order[1],order[2]=order[2],order[1] end
        bag = {order=order, position=1, count=#choices, last=bag and bag.last}
        self.messageVariantBags[signature] = bag
    end
    local index = bag.order[bag.position]
    bag.last, bag.position = index, bag.position+1
    return choices[index]
end
-- The two scopes resolve wording differently, so each has its own resolver and V:Render
-- is a dispatcher. Returns the candidate list plus that scope's variant bank.

-- Guild: an accent replaces the sentence outright, and its extra wordings live in a
-- separate bank rather than in the localized list.
local function guildCandidates(self, kind, catalog, lang, english, accent)
    local localized = ((catalog[lang] or {})[kind]) or english
    localized = type(localized)=="table" and localized or {localized}
    local alternates
    if accent then
        alternates = (self.accentVariants[accent.id] or {})[kind]
        local accented = (accent.text or {})[kind]
        if accented then localized = {accented} end
    end
    return localized, alternates
end

-- Group: an accent's curated wordings ARE the candidate list, so variation happens
-- within the list instead of against a separate bank.
local function groupCandidates(self, kind, catalog, lang, english, accent)
    local localized = ((catalog[lang] or {})[kind]) or english
    localized = type(localized)=="table" and localized or {localized}
    local alternates
    if accent then
        alternates = ((self.groupAccentVariants or {})[accent.id] or {})[kind]
        if alternates and #alternates > 0 then localized = alternates end
    end
    return localized, alternates
end

local RESOLVERS = {guild = guildCandidates, group = groupCandidates}

local function pickTemplate(self, scope, kind, lang, accent, template, localized, alternates)
    if scope == "guild" then
        -- Without an accent the neutral locale bank supplies the alternatives.
        local bank = accent and alternates or ((self.localeVariants or {})[lang] or {})[kind]
        if bank then return self:Pick(scope,kind,lang,accent,template,bank,true) end
    end
    local rest = {}
    for i=2,#localized do rest[#rest+1]=localized[i] end
    return self:Pick(scope,kind,lang,accent,template,rest,true)
end

-- Gates BOTH halves of applyFlair: the catchphrase prefix and the Expressive
-- punctuation change. Anything this returns false for is rendered neutrally, whatever
-- the strength setting says.
--
-- Guild messages take the catchphrase everywhere except [LFG], which stays scannable.
-- Group messages take it only on the social kinds, never on a combat directive: a
-- dungeon instruction has to stay plain to be followed under pressure.
--
-- The group entry is deliberate, not an oversight. Expressive therefore rewrites the
-- final mark of group greet/welcome/level too, which is documented in the accent
-- strength section of ForeverCommsVoice/README.md and pinned by tests/expressive.lua.
local function flairApplies(scope, kind)
    if scope == "guild" then return kind ~= "help" end
    if scope == "group" then
        return kind == "greet" or kind == "welcome" or kind == "level"
    end
    return false
end

local function applyFlair(template, accent, voice, curatedGroupAccent)
    if not (accent and accent.flair) then return template end
    -- Only moderate/expressive add a prefix. Subtle is the phrasebook alone.
    if voice.accentStrength ~= "moderate" and voice.accentStrength ~= "expressive" then
        return template
    end
    -- Avoid repeating a racial catchphrase already present in a curated party
    -- template (e.g. two consecutive "By the forge!" prefixes).
    if not curatedGroupAccent and template:sub(1,#accent.flair) ~= accent.flair then
        template = accent.flair .. template
    end
    if voice.accentStrength == "expressive" then
        -- Match legacy GuildComms: amplify terminal !, convert terminal .
        -- BEFORE placeholder substitution so player/quest names are unchanged.
        -- Runs even for a curated group wording that skipped the prefix above, so
        -- "May the stars guide our group." becomes "...group!" with no catchphrase.
        if template:sub(-1) == "!" then
            template = template .. "!"
        elseif template:sub(-1) == "." then
            template = template:sub(1, -2) .. "!"
        end
    end
    return template
end

function V:Render(scope, kind, vars, options)
    options = options or {}
    local voice = self:GetSettings()
    local catalog = self.catalogs[scope]
    if not catalog then return self:Format(options.fallback or "", vars) end
    local english = (catalog.en or {})[kind]
    local base = type(english)=="table" and english[1] or english
    if not base then return self:Format(options.fallback or "", vars) end
    -- User-authored guild templates always win, untransformed.
    if options.custom ~= nil and options.custom ~= base then
        return self:Format(options.custom, vars)
    end
    local lang = voice.language or "en"
    local accent = self:ResolveAccent()
    local resolve = RESOLVERS[scope]
    if not resolve then return self:Format(options.fallback or base, vars) end
    local localized, alternates = resolve(self, kind, catalog, lang, english, accent)
    local template = localized[1] or base
    if not options.preview and options.random ~= false then
        template = pickTemplate(self, scope, kind, lang, accent, template, localized, alternates)
    end
    if flairApplies(scope, kind) then
        local curated = scope == "group" and alternates and #alternates > 0
        template = applyFlair(template, accent, voice, curated)
    end
    return self:Format(template, vars)
end
