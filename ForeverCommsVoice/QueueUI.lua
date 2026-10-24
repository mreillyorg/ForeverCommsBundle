local _, V = ...
local ROW_HEIGHT = 62
local function txt(parent, value, x, y, width, font)
    local f=parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    f:SetWidth(width); f:SetJustifyH("LEFT"); f:SetJustifyV("TOP")
    f:SetText(value or "")
    return f
end
local function button(parent, text, x, y, width, callback)
    local b=CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetSize(width, 23); b:SetText(text); b:SetScript("OnClick", callback)
    return b
end
function V:BuildQueueUI()
    if self.queueFrame or not CreateFrame then return end
    local q = self:GetQueueSettings()
    -- Small independent overlay, not a Blizzard UIPanel-managed window.
    local f = CreateFrame("Frame", "ForeverCommsVoiceQueueFrame", UIParent)
    f:SetSize(675, 85 + q.visibleRows * ROW_HEIGHT)
    f:SetPoint("CENTER", UIParent, "CENTER", q.x, q.y)
    f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if self.GetCenter and UIParent and UIParent.GetCenter then
            local x,y=self:GetCenter(); local cx,cy=UIParent:GetCenter()
            if x and cx then
                local settings=V:GetQueueSettings()
                settings.x,settings.y=x-cx,y-cy
            end
        end
    end)
    f:SetFrameStrata("DIALOG")
    local background=f:CreateTexture(nil,"BACKGROUND")
    background:SetAllPoints(f)
    background:SetColorTexture(0.035,0.045,0.07,0.92)
    local header=f:CreateTexture(nil,"BORDER")
    header:SetPoint("TOPLEFT", f,"TOPLEFT",0,0)
    header:SetPoint("TOPRIGHT",f,"TOPRIGHT",0,0)
    header:SetHeight(30)
    header:SetColorTexture(0.12,0.16,0.23,0.98)
    self.queueFrame = f
    self.queueHeading=txt(f,"Comms queue  |  Tick to send · Skip to discard",12,-9,545,"GameFontNormal")
    local close=button(f,"X",636,-3,29,function() f:Hide() end)
    self.queueClose=close
    self.queueCount=txt(f,"",12,-35,400,"GameFontNormalSmall")
    self.queueScroll=CreateFrame("ScrollFrame","ForeverCommsVoiceQueueScroll",f,"UIPanelScrollFrameTemplate")
    self.queueScroll:SetPoint("TOPLEFT",f,"TOPLEFT",10,-49)
    self.queueScroll:SetSize(642,q.visibleRows*ROW_HEIGHT)
    self.queueChild=CreateFrame("Frame",nil,self.queueScroll)
    self.queueChild:SetSize(630,1)
    self.queueScroll:SetScrollChild(self.queueChild)
    self.queueRows={}
    self.queueScroll:EnableMouseWheel(true)
    self.queueScroll:SetScript("OnMouseWheel",function(self, delta)
        self:SetVerticalScroll(math.max(0, self:GetVerticalScroll() - delta * ROW_HEIGHT))
    end)
    self.queueSkipAll=button(f,"Skip all",423,-(56+q.visibleRows*ROW_HEIGHT),100,function() V:SkipAll() end)
    self.queueSettings=button(f,"Settings",533,-(56+q.visibleRows*ROW_HEIGHT),92,function() V:OpenOptions() end)
    f:Hide()
    self:RefreshQueueUI()
    -- The independent watcher is started by Enqueue even if auto-open is off.
    self:EnsureQueueTicker()
end
function V:RefreshQueueCountdowns()
    for _,r in ipairs(self.queueRows or {}) do
        if r.id then
            local _,item=self:FindQueueItem(r.id)
            if item and item.expiresAt then
                r.timer:SetText(math.max(0,math.ceil(item.expiresAt - (GetTime and GetTime() or 0))) .. "s")
            elseif item then r.timer:SetText("No limit") end
        end
    end
end
function V:RefreshQueueUI()
    local f=self.queueFrame
    if not f then return end
    local opts=self:GetQueueSettings()
    local rows=self.reviewQueue
    f:SetHeight(85+opts.visibleRows*ROW_HEIGHT)
    if self.queueSkipAll then self.queueSkipAll:ClearAllPoints(); self.queueSkipAll:SetPoint("TOPLEFT",f,"TOPLEFT",423,-(56+opts.visibleRows*ROW_HEIGHT)) end
    if self.queueSettings then self.queueSettings:ClearAllPoints(); self.queueSettings:SetPoint("TOPLEFT",f,"TOPLEFT",533,-(56+opts.visibleRows*ROW_HEIGHT)) end
    self.queueScroll:SetHeight(opts.visibleRows*ROW_HEIGHT)
    self.queueChild:SetHeight(math.max(1,#rows*ROW_HEIGHT))
    self.queueCount:SetText(string.format("Waiting: %d  (Guild %d, Group %d)",#rows,self:PendingCount("guild"),self:PendingCount("group")))
    for i,item in ipairs(rows) do
        local r=self.queueRows[i]
        if not r then
            r=CreateFrame("Frame",nil,self.queueChild)
            r:SetSize(625,ROW_HEIGHT-3)
            r.source=txt(r,"",4,-7,77,"GameFontNormalSmall")
            r.icon=r:CreateTexture(nil,"ARTWORK")
            r.icon:SetSize(31,31);r.icon:SetPoint("TOPLEFT",r,"TOPLEFT",16,-12)
            r.label=txt(r,"",83,-5,385,"GameFontNormalSmall")
            r.message=txt(r,"",83,-21,387,"GameFontHighlightSmall")
            r.message:SetHeight(38)
            r.timer=txt(r,"",473,-9,57,"GameFontHighlightSmall")
            r.check=CreateFrame("CheckButton",nil,r,"UICheckButtonTemplate")
            r.check:SetSize(27,27);r.check:SetPoint("TOPLEFT",r,"TOPLEFT",529,-13)
            r.check:SetScript("OnClick",function(self)
                local id=r.id
                self:SetChecked(false)
                if id then V:Approve(id) end
            end)
            r.approveLabel=txt(r,"Send",529,-40,37,"GameFontHighlightSmall")
            r.skip=button(r,"Skip",561,-15,55,function() if r.id then V:Skip(r.id) end end)
            self.queueRows[i]=r
        end
        r:ClearAllPoints();r:SetPoint("TOPLEFT",self.queueChild,"TOPLEFT",0,-(i-1)*ROW_HEIGHT)
        r.id=item.id
        r.label:SetText(item.label or item.kind)
        r.message:SetText(item.text)
        r.source:SetText(opts.sourceDisplay=="text" and (item.source=="guild" and "Guild" or "Group") or "")
        if opts.sourceDisplay=="icon" then
            r.icon:SetTexture(item.source=="guild" and "Interface\\AddOns\\ForeverGuildComms\\Media\\Icon" or "Interface\\AddOns\\ForeverGroupComms\\Media\\Icon")
            r.icon:Show()
        else r.icon:Hide() end
        r.check:SetChecked(false);r:Show()
    end
    for i=#rows+1,#self.queueRows do self.queueRows[i].id=nil; self.queueRows[i]:Hide() end
    self:RefreshQueueCountdowns()
    if self.queueScroll.UpdateScrollChildRect then self.queueScroll:UpdateScrollChildRect() end
    local maxOffset=math.max(0,(#rows-opts.visibleRows)*ROW_HEIGHT)
    if self.queueScroll:GetVerticalScroll()>maxOffset then self.queueScroll:SetVerticalScroll(maxOffset) end
end
function V:ShowQueue(onlyShow)
    self:BuildQueueUI()
    if not self.queueFrame then return end
    if onlyShow then self.queueFrame:Show()
    elseif self.queueFrame:IsShown() then self.queueFrame:Hide()
    else self.queueFrame:Show() end
    self:RefreshQueueUI()
end
