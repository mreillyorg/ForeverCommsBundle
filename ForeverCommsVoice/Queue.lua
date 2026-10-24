-- Shared click-to-send review queue for both consumer addons.
--
-- The queue CONTENTS are never persisted: each item holds a send callback supplied by
-- another addon plus a session-specific guild or group identity, and neither may survive
-- a login or reload. The queue SETTINGS are persisted, per character, under
-- ForeverCommsVoiceCharDB.queue -- see V:GetQueueSettings.
local _, V = ...
V.reviewQueue = {}
V.reviewNextID = 0
V.queueDefaults = {visibleRows=2, autoSkipSeconds=20, sourceDisplay="text", showOnNew=true, x=0, y=0}
local function now()
    return GetTime and GetTime() or 0
end
local function integer(value, lo, hi, fallback)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return fallback end
    return math.max(lo, math.min(hi, math.floor(value + 0.5)))
end
function V:GetQueueSettings()
    self:GetSettings()
    local db = _G.ForeverCommsVoiceCharDB
    if type(db.queue) ~= "table" then db.queue = {} end
    local q = db.queue
    q.visibleRows = integer(q.visibleRows, 1, 10, self.queueDefaults.visibleRows)
    q.autoSkipSeconds = integer(q.autoSkipSeconds, 0, 3600, self.queueDefaults.autoSkipSeconds)
    if q.sourceDisplay ~= "icon" then q.sourceDisplay = "text" end
    if type(q.showOnNew) ~= "boolean" then q.showOnNew = true end
    for _, axis in ipairs({"x", "y"}) do
        if type(q[axis]) ~= "number" or q[axis] ~= q[axis] or math.abs(q[axis]) > 10000 then q[axis] = 0 end
    end
    return q
end
function V:SetQueueOption(key, value)
    local q = self:GetQueueSettings()
    if key == "visibleRows" then value = integer(value, 1, 10, q[key])
    elseif key == "autoSkipSeconds" then value = integer(value, 0, 3600, q[key])
    elseif key == "sourceDisplay" then if value ~= "text" and value ~= "icon" then return false end
    elseif key == "showOnNew" then if type(value) ~= "boolean" then return false end
    else return false end
    q[key] = value
    if self.RefreshQueueUI then self:RefreshQueueUI() end
    if self.RefreshOptions then self:RefreshOptions() end
    return true
end
function V:PendingCount(source)
    local count = 0
    for _, item in ipairs(self.reviewQueue) do
        if source == nil or item.source == source then count = count + 1 end
    end
    return count
end
function V:PendingList(source)
    local list = {}
    for _, item in ipairs(self.reviewQueue) do
        if source == nil or item.source == source then list[#list+1] = item end
    end
    return list
end
function V:FindQueueItem(id)
    for i, item in ipairs(self.reviewQueue) do if item.id == id then return i, item end end
end
function V:QueueChanged()
    if self.RefreshQueueUI then self:RefreshQueueUI() end
    local guild = _G.ForeverGuildComms
    if guild and guild.UpdateApprovalsUI then guild:UpdateApprovalsUI() end
    if guild and guild.UpdateBroker then guild:UpdateBroker() end
    local group = _G.ForeverGroupComms
    if group and group.RefreshUI then group:RefreshUI() end
end
-- Expiry must run even while the window is hidden, so it needs its own clock rather
-- than a UI refresh. A 0.5s ticker is accurate enough for a countdown display and
-- avoids an OnUpdate handler, which the project's Lua style rules exclude for periodic
-- work in favour of C_Timer.
function V:EnsureQueueTicker()
    if self.queueWatcher then return end
    if not (C_Timer and C_Timer.NewTicker) then return end
    self.queueWatcher = C_Timer.NewTicker(0.5, function()
        if #V.reviewQueue == 0 then return end
        local changed = V:Expire()
        if not changed and V.queueFrame and V.queueFrame.IsShown and V.queueFrame:IsShown()
            and V.RefreshQueueCountdowns then V:RefreshQueueCountdowns() end
    end)
end
function V:Enqueue(data)
    if type(data) ~= "table" or (data.source ~= "guild" and data.source ~= "group")
        or type(data.text) ~= "string" or data.text == "" or type(data.send) ~= "function" then return nil end
    self:Expire()
    local q = self:GetQueueSettings()
    local ttl = data.timeout == nil and q.autoSkipSeconds or integer(data.timeout, 0, 3600, q.autoSkipSeconds)
    self.reviewNextID = self.reviewNextID + 1
    local item = {id=self.reviewNextID, source=data.source, kind=data.kind or "message",
        label=data.label or data.kind or "Message", text=data.text,
        send=data.send, created=now(), timeout=ttl,
        expiresAt=ttl > 0 and now() + ttl or nil}
    if #self.reviewQueue >= 100 then table.remove(self.reviewQueue, 1) end
    self.reviewQueue[#self.reviewQueue+1] = item
    self:EnsureQueueTicker()
    self:QueueChanged()
    if q.showOnNew and self.ShowQueue then self:ShowQueue(true) end
    return item.id
end
function V:Skip(id)
    local index = self:FindQueueItem(id)
    if not index then return false end
    table.remove(self.reviewQueue, index)
    self:QueueChanged()
    return true
end
function V:SkipAll(source)
    local changed = false
    for i=#self.reviewQueue,1,-1 do
        if source == nil or self.reviewQueue[i].source == source then
            table.remove(self.reviewQueue,i); changed=true
        end
    end
    if changed then self:QueueChanged() end
    return changed
end
function V:Approve(id)
    local index, item = self:FindQueueItem(id)
    if not item then return false end
    -- Expired messages can never be resurrected by an overlapping user click.
    if item.expiresAt and now() >= item.expiresAt then self:Skip(id); return false end
    local success, result, reason = pcall(item.send, item)
    if not success then
        if self.Print then self:Print("Could not approve message: " .. tostring(result)) end
        return false
    end
    if result == true then
        self:Skip(id)
        return true
    end
    if reason == "stale" then self:Skip(id) end
    return false
end
function V:Expire(timestamp)
    timestamp = timestamp or now()
    local removed = false
    for i=#self.reviewQueue,1,-1 do
        local item=self.reviewQueue[i]
        if item.expiresAt and timestamp >= item.expiresAt then
            table.remove(self.reviewQueue,i); removed=true
        end
    end
    if removed then self:QueueChanged() end
    return removed
end

