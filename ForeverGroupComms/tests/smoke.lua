-- Runs under texlua (or stock Lua); basic isolated WoW API simulation.
local root = arg[1] or '.'
local now, timers = 100, {}
local traffic = {}
local quests = {
    {questID=101,title='Dungeon Starter',isHeader=false},
    {questID=202,title='Collect Shells',isHeader=false},
}
local completed = {[303]=true}
local people = {
    player={name='Alice Example',level=24,role='HEALER',guid='P1'},
    party1={name='Ben Another',level=26,role='TANK',guid='P2'},
    party2={name='Cora Person',level=25,role='DAMAGER',guid='P3'},
}
DEFAULT_CHAT_FRAME={AddMessage=function(_,s) end}
C_Timer={After=function(wait,cb) timers[#timers+1]={delay=wait,cb=cb} end}
GetTime=function() return now end
GetUnitName=function(u) return people[u] and people[u].name end
UnitName=GetUnitName
UnitExists=function(u) return u == "target" or people[u]~=nil end
UnitGUID=function(u) return people[u] and people[u].guid end
UnitLevel=function(u) return people[u] and people[u].level end
UnitGroupRolesAssigned=function(u) return people[u] and people[u].role end
IsInGroup=function() return true end
IsInRaid=function() return false end
GetNumSubgroupMembers=function() return 2 end
UnitIsGroupLeader=function() return true end
UnitCanAttack=function() return true end
InCombatLockdown=function() return false end
SendChatMessage=function(msg,channel) traffic[#traffic+1]={kind='chat', msg=msg, channel=channel} end
SetRaidTarget=function(unit,index) traffic[#traffic+1]={kind='mark',unit=unit,index=index} end
QuestLogPushQuest=function() traffic[#traffic+1]={kind='questshare'} end
C_PartyInfo={DoReadyCheck=function() traffic[#traffic+1]={kind='ready'} end}
C_QuestLog={
 GetNumQuestLogEntries=function() return #quests end,
 GetInfo=function(i) return quests[i] end,
 IsQuestFlaggedCompleted=function(id) return completed[id] == true end,
 IsPushableQuest=function(id) return true end,
 SetSelectedQuest=function(id) end,
 GetSelectedQuest=function() return 101 end,
}
C_ChatInfo={
 RegisterAddonMessagePrefix=function() return 0 end,
 SendAddonMessage=function(prefix,message,channel,to)
   traffic[#traffic+1]={kind='addon',prefix=prefix,msg=message,channel=channel,target=to}
   return 0
 end,
}
CreateFrame=function()
    return {RegisterEvent=function() end,SetScript=function() end}
end
SlashCmdList={}
wipe=function(t) for k in pairs(t) do t[k]=nil end end
local A={}
local function module(path)
    local f,err=loadfile(root..'/'..path)
    assert(f,err)
    f('ForeverGroupComms',A)
end
module('Core.lua'); module('Roster.lua'); module('Quests.lua')
A.BuildOptions=function() end
A.TryBroker=function() end
A.RefreshQuestUI=function() end
A:Initialize()
assert(A.activeGroup)
assert(A:RoleSummary():find('Ben Another Tank',1,true))
assert(#A:RoleIssues() == 0)
A:ReadyCheck()
assert(traffic[#traffic].kind=='ready')
A:MarkTarget(8)
assert(traffic[#traffic].kind=='mark' and traffic[#traffic].index==8)
assert(A:Send('roles',{roles=A:RoleSummary()}))
local originalLevels=#A.approvals
people.party1.level=27
A:ScanRoster(false)
assert(#A.approvals==originalLevels+1,'expected private level congratulation')
-- Emit a local active quest snapshot. Do not require recipients to have addon.
A:BroadcastQuests()
while #timers>0 do
  local timer=table.remove(timers,1); now=now+timer.delay; timer.cb()
end
local qCount=0
for _,m in ipairs(traffic) do if m.kind=='addon' and m.msg:match('^Q|') then qCount=qCount+1 end end
assert(qCount>0,'expected addon Q snapshot')
-- Simulated party member advertises having 101, and confirms they have not completed 202.
A:OnAddonMessage('ForeverGrpComms','Q|1|12|1|1|101','PARTY','Ben Another')
A:OnAddonMessage('ForeverGrpComms','R|1|'..A.questEpoch..'|1|1|','WHISPER','Ben Another')
local rows=A:QuestRows()
local byid={}; for _,r in ipairs(rows) do byid[r.id]=r end
assert(#byid[101].shared==1, 'expected peer active quest')
assert(#byid[202].missing==1, 'expected peer confirmed missing quest')
assert(#byid[101].unknown==1, 'expected unknown nonaddon party member')
A:ShareQuest(202)
assert(traffic[#traffic].kind=='questshare')
-- Verify stale completion epoch never produces an unwarranted missing claim.
A.questEpoch=A.questEpoch+1
rows=A:QuestRows(); byid={};for _,r in ipairs(rows)do byid[r.id]=r end
assert(#byid[202].missing==0 and #byid[202].unknown==2)
-- Peer has quest 404 we lack; suppress already-completed quest 303.
A:OnAddonMessage('ForeverGrpComms','Q|1|13|1|1|101,303,404','PARTY','Ben Another')
local others=A:OtherQuestRows()
assert(#others==1 and others[1].id==404, 'expected reverse quest comparison, not completed quests')
A:RequestQuest(404)
assert(traffic[#traffic].kind=='chat' and traffic[#traffic].msg:find('404',1,true))
print('Smoke tests passed: roster, roles, level suggestions, quick actions, Q/R sync, share and staleness')
