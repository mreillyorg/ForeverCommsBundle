-- Run from the suite root: texlua ForeverCommsVoice/tests/queue.lua
local root="ForeverCommsVoice/"
local t=100
local sent={}
_G.GetTime=function()return t end
_G.GetGuildInfo=function()return _G.currentGuild end
_G.IsInGuild=function() return _G.currentGuild ~= nil end
_G.currentGuild="Test Guild"
_G.IsInGroup=function()return true end
_G.IsInRaid=function()return false end
_G.SendChatMessage=function(msg,channel) sent[#sent+1]={text=msg,channel=channel} end
_G.wipe=function(tbl)for k in pairs(tbl)do tbl[k]=nil end end
_G.SlashCmdList={}
local watchers={}
_G.CreateFrame=function()
  local obj={RegisterEvent=function()end}
  function obj:SetScript(kind,fn)if kind=="OnUpdate" then watchers[#watchers+1]=fn end end
  return obj
end
_G.UnitRace=function()return "Human","Human",1 end
local v={}
for _,m in ipairs({"Core.lua","Languages.lua","Accents.lua","RaceProfiles.lua","MessageVariants.lua","GroupPhrases.lua","Queue.lua"})do
  assert(loadfile(root..m))("ForeverCommsVoice",v)
end
_G.ForeverCommsVoice=v
-- Test inactive UI behaviour: options prohibit automatic approval.
assert(v:SetQueueOption("showOnNew",false))
assert(v:SetQueueOption("visibleRows",4))
assert(v:SetQueueOption("sourceDisplay","icon"))
assert(v:SetQueueOption("autoSkipSeconds",60))
assert(v:GetQueueSettings().visibleRows==4 and v:GetQueueSettings().sourceDisplay=="icon")
assert(v:SetQueueOption("visibleRows",100) and v:GetQueueSettings().visibleRows==10)
assert(not v:SetQueueOption("sourceDisplay","not-a-mode"))
local g={}
assert(loadfile('ForeverGuildComms/Core.lua'))('ForeverGuildComms',g)
g.db={enabled=true,outgoingMode="verify",messageSpacing=6}
g.UpdateBroker=function()end
local p={}
assert(loadfile('ForeverGroupComms/Core.lua'))('ForeverGroupComms',p)
p.db={enabled=true,useSharedVoice=true,randomMessages=false,maxNotifications=20}
p.activeGroup=true;p.groupSerial=1
p.RefreshUI=function()end
assert(g:CanUse())
g:QueueGuild("Welcome Alice","login:alice",300)
p:Stage("pull",nil,"Pull soon")
assert(v:PendingCount()==2 and v:PendingCount("guild")==1 and v:PendingCount("group")==1)
assert(#sent==0,"staged text must not auto-send")
assert(v:PendingList()[1].source=="guild" and v:PendingList()[2].source=="group")
local guildItem=v:PendingList("guild")[1]
local groupItem=v:PendingList("group")[1]
assert(v:Approve(guildItem.id))
assert(#sent==1 and sent[1].channel=="GUILD")
assert(v:PendingCount()==1 and v:PendingList()[1].id==groupItem.id,"next queued item should move up")
assert(v:Approve(groupItem.id))
assert(#sent==2 and sent[2].channel=="PARTY" and v:PendingCount()==0)
-- Timeout is per comm record. An override expires earlier than the default.
local a=v:Enqueue({source="guild",kind="short",text="Short",timeout=5,send=function() error("Expired sent") end})
local b=v:Enqueue({source="group",kind="long",text="Long",send=function()return true end})
t=t+6
assert(v:Expire(t))
assert(not v:FindQueueItem(a) and v:FindQueueItem(b))
assert(#sent==2,"auto skip posted a chat message")
-- Hidden-window expiration must run from the independent watchdog.
t=t+60
for _,fn in ipairs(watchers)do fn(nil,0.6)end
assert(v:PendingCount()==0,"hidden queue did not expire")
-- Disabled auto-skip, successful skip, and safe no-op for duplicate click.
assert(v:SetQueueOption("autoSkipSeconds",0))
local c=v:Enqueue({source="guild",text="Never expires",send=function()return true end})
t=t+50000
assert(not v:Expire(t) and v:PendingCount()==1)
assert(v:Skip(c) and not v:Skip(c) and #sent==2)
-- Shared queue honors stale group identity and rejects old guilds.
p.groupSerial=3
p:Stage("greet",nil,"Welcome")
local oldId=v:PendingList("group")[1].id
p.groupSerial=4
assert(not v:Approve(oldId) and v:PendingCount("group")==0)
g:QueueGuild("Guild goodbye","join:test",3)
_G.currentGuild="Different guild"
assert(not v:Approve(v:PendingList("guild")[1].id))
assert(v:PendingCount()==0)
-- Clear only one source and preserve the other addon.
v:Enqueue({source="guild",text="Guild only",send=function()return true end})
v:Enqueue({source="group",text="Group only",send=function()return true end})
g:ClearApprovals()
assert(v:PendingCount("guild")==0 and v:PendingCount("group")==1)
assert(#sent==2)
print("PASSED: shared guild/group queue, click approval, FIFO, source counts, hidden expiry, per-record TTL, stale identity, selective clear, no auto-send")
