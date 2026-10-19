local _, A = ...
-- Only disclose active quest IDs. The completion reply answers IDs the party
-- already disclosed. No quest titles, objective progress or history are broadcast.
local PREFIX = "ForeverGrpComms" -- 15 bytes; WoW prefix limit is 16.
local PROTOCOL = "1"
local TTL = 300
A.questPeers = {}
A.questParts = {}
A.questEpoch = 0
A.questLocal = {}
A.questAwaiting = {}
A.addonOutbox = {}

local function currentQuests()
    local quests = {}
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        local count = C_QuestLog.GetNumQuestLogEntries() or 0
        for i=1,count do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and tonumber(info.questID) and info.questID > 0 then
                quests[info.questID] = {id=info.questID, title=info.title or ("Quest " .. info.questID)}
            end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        local count = GetNumQuestLogEntries()
        for i=1,count do
            local title, _, _, isHeader, _, _, _, id = GetQuestLogTitle(i)
            if not isHeader and id and id > 0 then quests[id] = {id=id, title=title or ("Quest " .. id)} end
        end
    end
    return quests
end
local function sortedIDs(quests)
    local ids = {}
    for id in pairs(quests) do ids[#ids+1] = tonumber(id) end
    table.sort(ids)
    return ids
end
local function parseIDs(csv)
    if type(csv) ~= "string" or #csv > 230 then return nil end
    local ids = {}
    if csv == "" then return ids end
    if csv:find("[^%d,]") or csv:find("^,") or csv:find(",$") or csv:find(",,") then return nil end
    for part in csv:gmatch("[^,]+") do
        local id = tonumber(part)
        if not id or id < 1 or id > 99999999 then return nil end
        ids[id] = true
    end
    return ids
end
local function packetize(head, ids)
    local chunks, buffer = {}, ""
    for _, id in ipairs(ids) do
        local s = tostring(id)
        if #buffer + #s + 1 > 205 then
            chunks[#chunks+1] = buffer
            buffer = ""
        end
        buffer = buffer == "" and s or (buffer .. "," .. s)
    end
    chunks[#chunks+1] = buffer
    if #chunks > 12 then return nil end
    return chunks
end
function A:InitializeQuestSync()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        local ok, result = pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
        self.questCommsReady = ok and (result == 0 or result == 1 or result == true)
    else self.questCommsReady = false end
    self.questLocal = currentQuests()
end
function A:ClearQuestPeers()
    wipe(self.questPeers)
    wipe(self.questParts)
    wipe(self.questAwaiting)
    wipe(self.addonOutbox)
    self.lastQuestSignature = nil
    self.lastQuestAnnounce = nil
    self.outboxToken = (self.outboxToken or 0) + 1
    if self.RefreshQuestUI then self:RefreshQuestUI() end
end
function A:QueuePacket(message, channel, target)
    if not self.questCommsReady or not self.activeGroup or not self.db.questSync then return end
    if #self.addonOutbox >= 60 then return end
    self.addonOutbox[#self.addonOutbox+1] = {message=message, channel=channel or self:GroupChannel(), target=target, serial=self.groupSerial}
    self:FlushPackets()
end
function A:FlushPackets()
    if self.outboxBusy or #self.addonOutbox == 0 then return end
    self.outboxBusy = true
    local token = self.outboxToken or 0
    C_Timer.After(1.15, function()
        self.outboxBusy = false
        if token ~= (self.outboxToken or 0) then return end
        local entry = table.remove(self.addonOutbox, 1)
        if entry and entry.serial == self.groupSerial and self.activeGroup and self.db and self.db.questSync then
            local fn = C_ChatInfo and C_ChatInfo.SendAddonMessage
            if fn then
                local ok = pcall(fn, PREFIX, entry.message, entry.channel, entry.target)
                if not ok then self:Print("Quest syncing encountered an API error.") end
            end
        end
        if #self.addonOutbox > 0 then self:FlushPackets() end
    end)
end
function A:ScheduleQuestSync(force)
    if not self.initialized or not self.activeGroup or not self.db or not self.db.questSync then return end
    self.syncSeq = (self.syncSeq or 0) + 1
    local stamp = self.syncSeq
    C_Timer.After(force and 2.5 or 4, function()
        if self.syncSeq == stamp and self.activeGroup then self:BroadcastQuests(force) end
    end)
end
function A:BroadcastQuests(force)
    if not self.questCommsReady or not self.activeGroup or not self.db.questSync then return end
    self.questLocal = currentQuests()
    local ids = sortedIDs(self.questLocal)
    -- QUEST_LOG_UPDATE also fires for kill counts: never resend unchanged logs
    -- on every objective tick. Still permit periodic rebroadcasts and new groups.
    local signature = table.concat(ids, ",")
    local now = self:Now()
    if not force and self.lastQuestSignature == signature and self.lastQuestAnnounce
        and now >= self.lastQuestAnnounce and now - self.lastQuestAnnounce < 240 then
        return
    end
    self.lastQuestSignature, self.lastQuestAnnounce = signature, now
    self.questEpoch = self.questEpoch + 1
    for _, peer in pairs(self.questPeers) do peer.completionEpoch = nil; peer.completed = nil end
    local chunks = packetize("Q", ids)
    if not chunks then self:Print("Quest log too large for group sync."); return end
    for part,csv in ipairs(chunks) do
        self:QueuePacket(string.format("Q|%s|%d|%d|%d|%s", PROTOCOL, self.questEpoch, part, #chunks, csv))
    end
    if self.RefreshQuestUI then self:RefreshQuestUI() end
end
function A:ReplyCompletions(sender, epoch, ids)
    local completed = {}
    if not (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) then return end
    for id in pairs(ids) do
        local ok, result = pcall(C_QuestLog.IsQuestFlaggedCompleted, id)
        if ok and result == true then completed[#completed+1] = id end
    end
    table.sort(completed)
    local chunks = packetize("R", completed)
    if not chunks then return end
    for part,csv in ipairs(chunks) do
        self:QueuePacket(string.format("R|%s|%d|%d|%d|%s", PROTOCOL, epoch, part, #chunks, csv), "WHISPER", sender)
    end
end
function A:OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= PREFIX or type(message) ~= "string" or not self.activeGroup then return end
    local key = self:Key(sender)
    if key == "" or key == self.playerKey or not self.roster[key] then return end
    -- Explicit group membership check prevents unrelated whispers injecting rows.
    if channel ~= "PARTY" and channel ~= "RAID" and channel ~= "INSTANCE_CHAT" and channel ~= "WHISPER" then return end
    local kind, proto, epochStr, partStr, totalStr, csv = message:match("^([QR])|([^|]+)|([^|]+)|([^|]+)|([^|]+)|(.*)$")
    if not kind or proto ~= PROTOCOL then return end
    local epoch, part, total = tonumber(epochStr), tonumber(partStr), tonumber(totalStr)
    if not epoch or epoch < 1 or epoch > 100000000 or not part or not total or total < 1 or total > 12 or part < 1 or part > total then return end
    if math.floor(epoch) ~= epoch or math.floor(part) ~= part or math.floor(total) ~= total then return end
    local ids = parseIDs(csv)
    if not ids then return end
    local token = key .. ":" .. kind .. ":" .. epoch
    local now = self:Now()
    if not self.lastPartPrune or now < self.lastPartPrune or now - self.lastPartPrune > 60 then
        for id, old in pairs(self.questParts) do
            if not old.when or old.when > now or now - old.when > 60 then self.questParts[id] = nil end
        end
        self.lastPartPrune = now
    end
    local state = self.questParts[token]
    if not state or now < state.when or now - state.when > 60 then
        state = {total=total, pieces={}, when=now}; self.questParts[token] = state
    end
    if state.total ~= total then return end
    state.pieces[part] = ids
    for i=1,total do if not state.pieces[i] then return end end
    self.questParts[token] = nil
    local merged = {}
    for i=1,total do for id in pairs(state.pieces[i]) do merged[id] = true end end
    local peer = self.questPeers[key] or {}
    self.questPeers[key] = peer
    if kind == "Q" then
        if peer.epoch and epoch < peer.epoch then return end
        peer.epoch, peer.active, peer.when = epoch, merged, now
        self:ReplyCompletions(sender, epoch, merged)
    else
        -- Only accept a completion reply to our most recently advertised log.
        if epoch ~= self.questEpoch then return end
        peer.completed, peer.completionEpoch, peer.when = merged, epoch, now
    end
    if self.RefreshQuestUI then self:RefreshQuestUI() end
end
function A:QuestRows()
    local rows = {}
    local now = self:Now()
    self.questLocal = currentQuests()
    for id, quest in pairs(self.questLocal) do
        local row = {id=id, title=quest.title, missing={}, unknown={}, shared={}, completed={}, pushable=nil}
        if C_QuestLog and C_QuestLog.IsPushableQuest then
            local ok, result = pcall(C_QuestLog.IsPushableQuest, id)
            if ok then row.pushable = result == true end
        end
        for key, member in pairs(self.roster) do
            if key ~= self.playerKey then
                local peer = self.questPeers[key]
                local fresh = peer and peer.when and now >= peer.when and now - peer.when < TTL
                if not fresh or not peer.active or peer.completionEpoch ~= self.questEpoch then
                    row.unknown[#row.unknown+1] = member.name
                elseif peer.active[id] then
                    row.shared[#row.shared+1] = member.name
                elseif peer.completed and peer.completed[id] then
                    row.completed[#row.completed+1] = member.name
                else
                    row.missing[#row.missing+1] = member.name
                end
            end
        end
        rows[#rows+1] = row
    end
    table.sort(rows, function(a,b)
        if #a.missing ~= #b.missing then return #a.missing > #b.missing end
        if #a.unknown ~= #b.unknown then return #a.unknown > #b.unknown end
        return a.title < b.title
    end)
    return rows
end
function A:ShareQuest(id)
    if not self.activeGroup then self:Print("Join a group first."); return end
    if InCombatLockdown and InCombatLockdown() then self:Print("Share quests after combat."); return end
    local quest = currentQuests()[tonumber(id)]
    if not quest then self:Print("That quest isn't in your log anymore."); return end
    if C_QuestLog and C_QuestLog.IsPushableQuest then
        local ok, pushable = pcall(C_QuestLog.IsPushableQuest, id)
        if ok and pushable == false then
            self:Print("The game says this quest cannot be shared."); return
        end
    end
    local selectQuest = C_QuestLog and C_QuestLog.SetSelectedQuest
    local selected = C_QuestLog and C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()
    if not selectQuest and SelectQuestLogEntry then
        local logIndex = C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id)
        if logIndex and logIndex > 0 then pcall(SelectQuestLogEntry, logIndex) end
    elseif selectQuest then
        local ok, err = pcall(selectQuest, id)
        if not ok then self:Print("Cannot select quest for sharing: " .. tostring(err)); return end
    end
    if not QuestLogPushQuest then self:Print("Quest sharing API isn't available in this build."); return end
    local ok, err = pcall(QuestLogPushQuest)
    if selectQuest and selected and selected > 0 then pcall(selectQuest, selected) end
    if ok then self:Print("Asked the game to share: " .. quest.title .. ". Eligibility is checked by WoW.")
    else self:Print("Quest share failed: " .. tostring(err)) end
end

-- The other direction: detect quests known to peers but absent from our log.
-- Suppress quests we already turned in; eligibility is still unknown.
function A:OtherQuestRows()
    local rows, localQuests = {}, currentQuests()
    local now = self:Now()
    for key, member in pairs(self.roster) do
        local peer = self.questPeers[key]
        if key ~= self.playerKey and peer and peer.active and peer.when
            and now >= peer.when and now - peer.when < TTL then
            for id in pairs(peer.active) do
                if not localQuests[id] then
                    local done = false
                    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
                        local ok,value = pcall(C_QuestLog.IsQuestFlaggedCompleted, id)
                        done = ok and value == true
                    end
                    if not done then
                        local row = rows[id]
                        if not row then
                            local title = C_QuestLog and C_QuestLog.GetTitleForQuestID
                                and C_QuestLog.GetTitleForQuestID(id)
                            row = {id=id, title=(title and title ~= "" and title) or ("Quest #" .. id), holders={}}
                            rows[id] = row
                        end
                        row.holders[#row.holders+1] = member.name
                    end
                end
            end
        end
    end
    local sorted={}
    for _,row in pairs(rows) do sorted[#sorted+1]=row end
    table.sort(sorted,function(a,b)
        if #a.holders ~= #b.holders then return #a.holders > #b.holders end
        return a.title < b.title
    end)
    return sorted
end
function A:RequestQuest(id)
    if not self.activeGroup then return end
    local rows = self:OtherQuestRows()
    for _,quest in ipairs(rows) do
        if quest.id == id then
            self:Send("request", {quest=quest.title})
            return
        end
    end
    self:Print("No current party data for that quest. Refresh the comparison.")
end
