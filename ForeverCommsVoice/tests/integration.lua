-- Run from ForeverCommsVoice folder: texlua tests/integration.lua
local base=(arg and arg[0] and arg[0]:match("^(.*[/\\])tests[/\\]integration%.lua$")) or "./"
_G.SlashCmdList={}
_G.CreateFrame=function()return {RegisterEvent=function()end,SetScript=function()end}end
local race="Human"
_G.UnitRace=function()return race,race,1 end
local V={}
for _,m in ipairs({"Core.lua","Languages.lua","Accents.lua","RaceProfiles.lua","MessageVariants.lua","GroupPhrases.lua"}) do
  assert(loadfile(base .. m))("ForeverCommsVoice",V)
end
_G.ForeverCommsVoice=V
local legacy={language="es",accent="mexican",raceFilter=true,accentStrength="moderate"}
local voice=V:MigrateLegacy(legacy)
assert(voice.language=="es" and voice.accent=="mexican")
assert(_G.ForeverCommsVoiceCharDB.migratedFromGuild==true)
local g=V:Render("guild","level",{name="Rosa",level=31},{custom=V.defaults.templates.level,random=false})
assert(g:find("Rosa",1,true) and g:find("31",1,true),"guild translation interpolation")
local p=V:Render("group","level",{name="Rosa",level=31},{random=false})
assert(p:find("Rosa",1,true) and p:find("31",1,true),"group translation interpolation")
local special="|cff00ff00|Hitem:123|h[Axe]|h|r"
assert(V:Render("guild","join",{name="Bob"},{custom="Look "..special.." {name}", random=true})=="Look "..special.." Bob","custom templates/links intact")
assert(V:Render("group","request",{quest="|Hquest:18|h[The Frozen Path]|h"},{random=false}):find("|Hquest:18|h[The Frozen Path]|h",1,true),"quest links intact")
-- Regression: legacy Expressive accent converts terminal . -> !, not just ! -> !!.
-- This behaviour was lost once when V:Render reimplemented it instead of moving it.
assert(V:SetOption("language","en"))
assert(V:SetOption("raceFilter", false))
assert(V:SetOption("accent","nightelf"))
assert(V:SetOption("accentStrength","expressive"))
local expressive=V:Render("guild","login",{name="Keeper"},{random=false})
assert(expressive:find("Keeper!",1,true), "Expressive must turn terminal period into exclamation")
assert(not expressive:find("Keeper.",1,true), "terminal period should be replaced")
local custom=V:Render("guild","login",{name="Keeper"},{random=false,custom="Custom greeting, {name}."})
assert(custom=="Custom greeting, Keeper.", "custom guild templates must not be transformed")
assert(V:SetOption("accent","australian"))
assert(V:Render("guild","login",{name="Friend"},{random=false}):sub(-2)=="!!", "Expressive doubles terminal exclamations")
assert(V:SetOption("accentStrength","subtle"))
assert(V:SetOption("raceFilter", true))
assert(V:SetOption("accent","none"))
assert(V:SetOption("language","en") and V:SetOption("accent","none"))
local roles=V:Render("group","roles",{roles="Alice: Tank, Bob: Healer"},{random=false})
assert(roles:find("Tank, Bob: Healer",1,true),"roles not transformed")
assert(V:SetOption("accent","scottish"))
assert(V:Render("group","greet",nil,{random=false}):find("Guid tae",1,true),"accented group greeting")
local skull=V:Render("group","skull",nil,{random=false})
assert(skull==V.groupTemplates.en.skull[1],"combat instructions are unaccented")
assert(V:SetOption("language","es"))
local same=V:GetSettings()
assert(same.language=="es" and same.accent=="auto", "language change filters incompatible accents")
local reloaded=V:MigrateLegacy(legacy)
assert(reloaded.language=="es" and reloaded.accent=="auto", "old guild setting must not overwrite shared preference")
assert(V:SetOption("language","en") and V:SetOption("accent","none"))
for _, scope in ipairs({"guild","group"}) do
  local seen={}
  for _=1,3 do
    local result=V:Render(scope,"level",{name="Alice",level=50},{random=true})
    assert(not seen[result],"non-repeating " .. scope .. " shuffle bag")
    seen[result]=true
  end
end
-- Exercise both actual addon adapters against the same voice settings.
local G={}
assert(loadfile(base .. "../ForeverGroupComms/Core.lua"))("ForeverGroupComms",G)
G.db={enabled=true,useSharedVoice=true,randomMessages=false}
local B={}
assert(loadfile(base .. "../ForeverGuildComms/Core.lua"))("ForeverGuildComms",B)
assert(loadfile(base .. "../ForeverGuildComms/VoiceBridge.lua"))("ForeverGuildComms",B)
B.db={templates={}}
for kind,text in pairs(B.defaults.templates) do B.db.templates[kind]=text end
B.db.randomizeMessages=false
B.char={voice=V:GetSettings()}
assert(V:SetOption("language","es"))
assert(G:Render("greet"):find("Hola",1,true),"group uses current shared language")
assert(B:CommsText("login",{name="Rosa"}):find("Bienvenido",1,true),"guild uses current shared language")
G.db.useSharedVoice=false
assert(G:Render("greet")=="Hello everyone!","group opt-out restores original English wording")
assert(V:SetOption("language","en"))
assert(#V:GetAvailableAccents()>2,"human accent choices")
race="UnlistedRace"
assert(#V:GetAvailableAccents()==2,"race-filtered unknown race is safe")
print("PASSED: guild migration, shared per-character voice, both rendering paths, accented greeting, combat clarity, variables, fallback, shuffle")
