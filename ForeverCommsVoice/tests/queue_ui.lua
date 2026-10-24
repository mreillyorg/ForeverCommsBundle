-- Lightweight WoW frame mock for the shared message list (does not replace in-game tests).
local all={}
local function frame()
 local f={shown=true,scripts={},offset=0}
 f.TitleText={SetText=function()end}
 function f:CreateFontString()return frame()end
 function f:CreateTexture()return frame()end
 function f:SetScript(kind,cb) self.scripts[kind]=cb end
 function f:SetVerticalScroll(v)self.offset=v end
 function f:GetVerticalScroll()return self.offset end
 function f:Show()self.shown=true end
 function f:Hide()self.shown=false end
 function f:IsShown()return self.shown end
 function f:SetText(t)self.text=t end
 function f:GetText()return self.text end
 function f:SetTexture(path)self.texture=path end
 function f:SetChecked(t)self.checked=t end
 function f:GetCenter()return 500,400 end
 setmetatable(f,{__index=function(_,k)return function()end end})
 all[#all+1]=f
 return f
end
_G.UIParent=frame()
_G.UIParent.GetCenter=function()return 500,400 end
_G.CreateFrame=function()return frame()end
_G.GetTime=function()return 100 end
_G.ForeverCommsVoiceCharDB={}
local v={}
function v:GetSettings()
 self.voiceDefaults={}
 if not _G.ForeverCommsVoiceCharDB.voice then _G.ForeverCommsVoiceCharDB.voice={} end
 return _G.ForeverCommsVoiceCharDB.voice
end
for _,file in ipairs({'Queue.lua','QueueUI.lua'}) do
 assert(loadfile('ForeverCommsVoice/'..file))('ForeverCommsVoice',v)
end
assert(v:GetQueueSettings().visibleRows==2 and v:GetQueueSettings().autoSkipSeconds==20, 'fresh queue defaults must be two rows and twenty seconds')
v:ShowQueue(true)
assert(v.queueFrame and v.queueFrame:IsShown())
assert(v.queueScroll and v.queueRows and #v.queueRows==0)
local sent={}
for i=1,8 do
 local n=i
 v:Enqueue({source=i%2==0 and 'group' or 'guild',kind='greet',text='Message '..i,
   label='Greeting '..i,send=function()sent[#sent+1]=n;return true end})
end
assert(#v.queueRows==8 and v:PendingCount()==8)
assert(v.queueChild.height or v.queueChild) -- scrollable list has a scroll child
local first=v.queueRows[1]
assert(first.id and first.check.scripts.OnClick)
first.check.scripts.OnClick(first.check)
assert(v:PendingCount()==7 and #sent==1 and sent[1]==1)
assert(v.queueRows[1].label.text=='Greeting 2','next item should appear after approval')
v.queueRows[1].skip.scripts.OnClick()
assert(v:PendingCount()==6 and #sent==1)
assert(v:SetQueueOption('sourceDisplay','icon'))
assert(v.queueRows[1].icon.texture:find('ForeverGuildComms',1,true))
assert(v:SetQueueOption('visibleRows',2) and v.queueScroll and v.queueFrame)
assert(v.queueScroll.scripts.OnMouseWheel)
v.queueScroll.scripts.OnMouseWheel(v.queueScroll,-1)
assert(v.queueScroll.offset>0,'mouse wheel should scroll queue')
assert(v.queueFrame.scripts.OnDragStop)
v.queueFrame.scripts.OnDragStop(v.queueFrame)
assert(v:GetQueueSettings().x==0 and v:GetQueueSettings().y==0)
print('PASSED: floating panel, two-row and twenty-second defaults, scroll control, checkbox send, skip, queue advancement, source icon, row size')
