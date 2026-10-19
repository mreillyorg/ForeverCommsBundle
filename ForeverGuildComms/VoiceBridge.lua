local _, A = ...
-- Thin compatibility bridge: the shared addon is the sole owner of voice data,
-- accent catalogues, language mappings and rotation state.
local V = _G.ForeverCommsVoice
if not V then error("ForeverGuildComms requires ForeverCommsVoice") end
A.voiceDefaults = V.voiceDefaults
A.languages, A.languageByID = V.languages, V.languageByID
A.localeTemplates, A.localeRoleNames, A.localeActivityTypes = V.localeTemplates, V.localeRoleNames, V.localeActivityTypes
A.accents, A.accentOrder, A.raceAccents = V.accents, V.accentOrder, V.raceAccents
A.localeVariants, A.accentVariants = V.localeVariants, V.accentVariants
A.messageVariantBags = V.messageVariantBags
function A:GetPlayerRace() return V:GetPlayerRace() end
function A:GetAvailableAccents() return V:GetAvailableAccents() end
function A:ResolveAccent() return V:ResolveAccent() end
function A:VoiceText(kind,vars,preview)
    return V:Render("guild",kind,vars,{
        custom=self.db and self.db.templates and self.db.templates[kind],
        random=self.db and self.db.randomizeMessages == true,
        preview=preview,
    })
end
function A:LocalizeRoleText(roles,fallback) return V:LocalizeRoleText(roles,fallback) end
function A:LocalizeActivityType(kind) return V:LocalizeActivityType(kind) end
function A:ChooseMessageTemplate(kind,language,accent,base)
    return V:ChooseMessageTemplate(kind,language,accent,base)
end
