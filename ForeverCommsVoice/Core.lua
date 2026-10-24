local ADDON, V = ...
_G.ForeverCommsVoice = V
V.name, V.version = ADDON, "0.2.0-beta"
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
V.messageVariantBags = {}
V.initialized = false

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
function V:SetOption(key, value)
    local voice = self:GetSettings()
    if not self:ValidateOption(key, value) then return false end
    voice[key] = value
    if key == "language" or key == "raceFilter" then
        local valid = false
        for _, entry in ipairs(self:GetAvailableAccents()) do if entry.id == voice.accent then valid = true end end
        if not valid then voice.accent = "auto" end
    end
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
        for i=#order,2,-1 do local j=math.random(i); order[i],order[j]=order[j],order[i] end
        if bag and bag.last and order[1]==bag.last then order[1],order[2]=order[2],order[1] end
        bag = {order=order, position=1, count=#choices, last=bag and bag.last}
        self.messageVariantBags[signature] = bag
    end
    local index = bag.order[bag.position]
    bag.last, bag.position = index, bag.position+1
    return choices[index]
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
    local localized = ((catalog[lang] or {})[kind]) or english
    localized = type(localized)=="table" and localized or {localized}
    local accent = self:ResolveAccent()
    local accentAlternates
    if scope == "guild" and accent then
        accentAlternates = (self.accentVariants[accent.id] or {})[kind]
        local accentTemplate = (accent.text or {})[kind]
        if accentTemplate then localized = {accentTemplate} end
    elseif scope == "group" and accent then
        accentAlternates = ((self.groupAccentVariants or {})[accent.id] or {})[kind]
        if accentAlternates and #accentAlternates > 0 then localized = accentAlternates end
    end
    local template = localized[1] or base
    if not options.preview and options.random ~= false then
        if scope == "guild" and not accent then
            accentAlternates = ((self.localeVariants or {})[lang] or {})[kind]
        end
        if scope == "guild" and accentAlternates then
            template = self:Pick(scope,kind,lang,accent,template,accentAlternates,true)
        else
            local rest = {}
            for i=2,#localized do rest[#rest+1]=localized[i] end
            template = self:Pick(scope,kind,lang,accent,template,rest, true)
        end
    end
    if accent and accent.flair and (scope == "guild" and kind ~= "help" or scope == "group" and (kind == "greet" or kind == "welcome" or kind == "level")) then
        -- For guild messages, match original behaviour: only moderate/expressive
        -- get prefix flavour. For group fallback greetings, subtle can still use
        -- the accent-specific template when supplied.
        if voice.accentStrength == "moderate" or voice.accentStrength == "expressive" then
            -- Avoid repeating a racial catchphrase already present in a curated
            -- party template (e.g. two consecutive "By the forge!" prefixes).
            local hasCuratedGroupAccent = scope == "group" and accentAlternates and #accentAlternates > 0
            if not hasCuratedGroupAccent and template:sub(1,#accent.flair) ~= accent.flair then
                template = accent.flair .. template
            end
            if voice.accentStrength == "expressive" then
                -- Match legacy GuildComms: amplify terminal !, convert terminal .
                -- BEFORE placeholder substitution so player/quest names are unchanged.
                if template:sub(-1) == "!" then
                    template = template .. "!"
                elseif template:sub(-1) == "." then
                    template = template:sub(1, -2) .. "!"
                end
            end
        end
    end
    return self:Format(template, vars)
end
