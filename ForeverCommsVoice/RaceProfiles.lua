local _, A = ...

-- UnitRace returns a locale-independent second value. The custom client may
-- add races without publishing their IDs; unknown races fall back gracefully.
A.raceAccents = {
    Human={"british", "american", "australian", "scottish", "irish", "canadian", "newzealand", "southafrican"},
    Dwarf={"dwarf", "wildhammer", "darkiron"},
    Gnome={"gnome"}, NightElf={"nightelf"},
    Orc={"orc"}, Troll={"troll"}, Tauren={"tauren"}, Scourge={"forsaken"},
    Undead={"forsaken"}, Goblin={"goblin"}, BloodElf={"bloodelf"}, Draenei={"draenei"},
    Skyborne={"skyborne"},
}
function A:GetPlayerRace()
    local localName, token = nil, nil
    if UnitRace then localName, token = UnitRace("player") end
    local probe = tostring(token or localName or "")
    if probe:lower():find("skyborne", 1, true) then return "Skyborne" end
    return token or localName or "Unknown"
end
function A:GetAvailableAccents()
    local selected = self.char and self.char.voice or self.voiceDefaults
    local language = selected.language or "en"
    local allowed = nil
    if selected.raceFilter then
        allowed = {}
        for _, key in ipairs(self.raceAccents[self:GetPlayerRace()] or {}) do allowed[key] = true end
        if self:GetPlayerRace() == "Human" then
            -- Regional human styles are available in their own languages.
            for _, key in ipairs({"mexican", "cuban", "spanish", "quebec", "bavarian", "brazilian", "portuguese", "southernitalian"}) do
                allowed[key] = true
            end
        end
    end
    local options = {{id="auto", label="Auto (character race)"}, {id="none", label="None"}}
    for _, key in ipairs(self.accentOrder or {}) do
        local accent = self.accents[key]
        if accent and accent.language == language and (not allowed or allowed[key]) then
            options[#options+1] = {id=key, label=accent.label}
        end
    end
    return options
end
function A:ResolveAccent()
    local voice = self.char and self.char.voice or self.voiceDefaults
    local chosen = voice.accent
    if chosen == "none" then return nil end
    local options = self:GetAvailableAccents()
    local valid = {}
    for _, entry in ipairs(options) do valid[entry.id] = true end
    if chosen == "auto" then
        for _, preferred in ipairs(self.raceAccents[self:GetPlayerRace()] or {}) do
            if valid[preferred] then return self.accents[preferred] end
        end
        return nil
    end
    if valid[chosen] then return self.accents[chosen] end
    return nil
end
-- A:VoiceText used to live here. It was the pre-extraction ForeverGuildComms method,
-- moved wholesale into the library, where it was unreachable: it reads self.db, which
-- the library never assigns. V:Render replaced it. Removed once V:Render had regained
-- the Expressive terminal-period conversion this method uniquely still contained --
-- see ForeverCommsVoice/tests/integration.lua, which now guards that behaviour.
function A:LocalizeRoleText(roles, fallback)
    local voice = self.char and self.char.voice or self.voiceDefaults
    local names = (self.localeRoleNames and self.localeRoleNames[voice.language]) or self.roleNames
    local output = {}
    for _, role in ipairs(self.roleOrder) do
        if roles and roles[role] then output[#output+1] = names[role] or self.roleNames[role] end
    end
    return #output > 0 and table.concat(output, "/") or (names[fallback] or fallback)
end
function A:LocalizeActivityType(kind)
    local voice = self.char and self.char.voice or self.voiceDefaults
    return ((self.localeActivityTypes or {})[voice.language] or {})[kind] or kind
end
