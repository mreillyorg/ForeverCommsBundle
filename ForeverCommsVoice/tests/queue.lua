-- Run from the addon root: lua5.1 tests/queue.lua
-- Resolves its own package from arg[0] and the sibling consumers relative to it, matching
-- every other harness in the suite. tools/run_tests.py runs each one with its package
-- folder as the working directory.
local base = (arg and arg[0] and arg[0]:match("^(.*[/\\])tests[/\\]queue%.lua$")) or "./"
local root = base
local siblings = base .. "../"
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
_G.CreateFrame=function()
  local obj={RegisterEvent=function()end}
  function obj:SetScript() end
  return obj
end
-- Expiry runs from a C_Timer ticker, not an OnUpdate handler. Capture the callback so
-- the test can fire it deliberately instead of waiting half a second.
local watchers={}
_G.C_Timer={
  NewTicker=function(_,callback) watchers[#watchers+1]=callback; return {Cancel=function()end} end,
  After=function(_,callback) callback() end,
}
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
assert(loadfile(siblings..'ForeverGuildComms/Core.lua'))('ForeverGuildComms',g)
g.db={enabled=true,outgoingMode="verify",messageSpacing=6}
g.UpdateBroker=function()end
local p={}
assert(loadfile(siblings..'ForeverGroupComms/Core.lua'))('ForeverGroupComms',p)
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
-- Hidden-window expiration must run from the independent ticker.
assert(#watchers==1,"expiry must be driven by exactly one C_Timer ticker")
t=t+60
for _,fn in ipairs(watchers)do fn()end
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
-- Backlog cap on the SHARED queue. With the library installed this is the live ceiling
-- for both addons, so it matters more than the 30-entry standalone list GuildComms uses
-- as a fallback (asserted in ForeverGuildComms/tests/verify.lua). The queue holds 100
-- and drops the oldest, so a flood cannot grow it without bound or push out the newest.
v:SkipAll()
assert(v:PendingCount()==0,"precondition: an empty queue")
assert(v:SetQueueOption("autoSkipSeconds",0),"no expiry while filling the queue")
local ids={}
for i=1,100 do
  ids[i]=v:Enqueue({source="guild",text="Flood "..i,send=function()return true end})
  assert(ids[i],"entry "..i.." was accepted")
end
assert(v:PendingCount()==100,"100 entries fit, got "..v:PendingCount())
assert(v:PendingList()[1].text=="Flood 1","oldest first")
assert(v:PendingList()[100].text=="Flood 100","newest last")
local overflow=v:Enqueue({source="guild",text="Flood 101",send=function()return true end})
assert(overflow,"the overflowing entry is still accepted")
assert(v:PendingCount()==100,"the queue stays capped at 100, got "..v:PendingCount())
assert(v:PendingList()[1].text=="Flood 2","the oldest entry was dropped")
assert(v:PendingList()[100].text=="Flood 101","the newest entry was kept")
assert(not v:FindQueueItem(ids[1]),"the dropped id is no longer findable")
-- A dropped entry must never fire its callback; dropping is not sending.
local fired=false
v:SkipAll()
for i=1,101 do
  v:Enqueue({source="group",text="Drop "..i,
    send=function() fired=true; return true end})
end
assert(v:PendingCount()==100 and not fired,
  "overflowing the queue discards silently and never invokes a send callback")
v:SkipAll()
assert(v:SetQueueOption("autoSkipSeconds",20))
print("PASSED: shared guild/group queue, click approval, FIFO, source counts, hidden " ..
      "expiry, per-record TTL, stale identity, selective clear, no auto-send, " ..
      "100-entry cap dropping the oldest without firing it")
