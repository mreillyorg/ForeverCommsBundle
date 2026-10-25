local _, A = ...
local function partyUnits()
    local result = {"player"}
    if IsInRaid and IsInRaid() then
        for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do result[#result+1] = "raid" .. i end
    else
        for i = 1, (GetNumSubgroupMembers and GetNumSubgroupMembers() or 0) do result[#result+1] = "party" .. i end
    end
    return result
end
function A:ScanRoster(silent)
    local selfName = (GetUnitName and GetUnitName("player", true)) or (UnitName and UnitName("player"))
    if selfName and selfName ~= "" then self.playerKey = self:Key(selfName) end
    local grouped = IsInGroup and IsInGroup() or false
    local previous = self.roster or {}
    local wasGrouped = self.activeGroup
    local current = {}
    if grouped then
        for _, token in ipairs(partyUnits()) do
            if UnitExists and UnitExists(token) then
                local name = (GetUnitName and GetUnitName(token, true)) or UnitName(token)
                local key = self:Key(name)
                if key ~= "" and not current[key] then
                    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(token) or "NONE"
                    if not self.labels[role] then role = "NONE" end
                    current[key] = {name=name, key=key, guid=UnitGUID(token), token=token,
                        role=role, level=UnitLevel(token)}
                end
            end
        end
    end
    local identitiesChanged = grouped ~= wasGrouped
    if not identitiesChanged then
        for key in pairs(previous) do if not current[key] then identitiesChanged = true; break end end
        if not identitiesChanged then
            for key in pairs(current) do if not previous[key] then identitiesChanged = true; break end end
        end
    end
    if identitiesChanged then
        self.groupSerial = self.groupSerial + 1
        -- Preserve clicks only when the exact roster is stable; no old group sends.
        wipe(self.approvals)
        if _G.ForeverCommsVoice and _G.ForeverCommsVoice.SkipAll then
            _G.ForeverCommsVoice:SkipAll("group")
        end
        if self.ClearQuestPeers then self:ClearQuestPeers() end
    end
    self.activeGroup, self.roster = grouped, current
    if grouped and not silent and self.db and self.db.enabled then
        if not wasGrouped then
            if not self:IsDuplicate("join:" .. self.groupSerial, 30) then
                if self.db.autoGreeting then self:Send("greet")
                else self:Stage("greet", nil, "Welcome the new party") end
            end
        else
            for key, member in pairs(current) do
                if not previous[key] and key ~= self.playerKey then
                    local id = "welcome:" .. key .. ":" .. self.groupSerial
                    if not self:IsDuplicate(id, 30) then
                        if self.db.autoGreeting then self:Send("welcome", {name=member.name})
                        else self:Stage("welcome", {name=member.name}, "Welcome " .. member.name) end
                    end
                end
            end
        end
        for key, member in pairs(current) do
            local old = previous[key]
            if old and old.guid == member.guid and type(member.level) == "number" and member.level > 0
                and type(old.level) == "number" and old.level > 0 and member.level > old.level then
                local id = "level:" .. key .. ":" .. member.level
                if not self:IsDuplicate(id, 180) then
                    if self.db.autoLevel then self:Send("level", {name=member.name, level=member.level})
                    else self:Stage("level", {name=member.name, level=member.level}, member.name .. " reached level " .. member.level) end
                end
            end
        end
    end
    if grouped and identitiesChanged and self.db and self.db.enabled then
        if self.db.privateRoleAlerts then self:ReviewRoles(true) end
        if self.db.privateQuestReminder then
            self:Notify("Before your first pull, compare quests and share any missing ones.", "questgroup:" .. self.groupSerial)
        end
        if self.ScheduleQuestSync then self:ScheduleQuestSync(true) end
    end
    if self.RefreshUI then self:RefreshUI() end
    if self.UpdateBroker then self:UpdateBroker() end
end
function A:RoleCounts()
    local counts = {TANK=0, HEALER=0, DAMAGER=0, NONE=0}
    for _, member in pairs(self.roster) do counts[member.role] = (counts[member.role] or 0) + 1 end
    return counts
end
function A:RoleSummary()
    local members = {}
    for _, m in pairs(self.roster) do members[#members+1] = m end
    table.sort(members, function(a,b)
        local r = {TANK=1, HEALER=2, DAMAGER=3, NONE=4}
        if r[a.role] ~= r[b.role] then return r[a.role] < r[b.role] end
        return a.name < b.name
    end)
    local names = {}
    for _,m in ipairs(members) do
        names[#names+1] = m.name .. " " .. (self.labels[m.role] or "Unassigned")
    end
    local out = table.concat(names, "; ")
    -- For large raids keep the shorter counts instead of truncating individual names.
    if #out > 160 then
        local c = self:RoleCounts()
        out = string.format("%d tank(s), %d healer(s), %d DPS, %d unassigned", c.TANK, c.HEALER, c.DAMAGER, c.NONE)
    end
    return out
end
function A:RoleIssues()
    local issues = {}
    if not self.activeGroup then return issues end
    local counts = self:RoleCounts()
    if counts.NONE > 0 then issues[#issues+1] = counts.NONE .. " unassigned role(s)" end
    if not (IsInRaid and IsInRaid()) then
        if counts.TANK ~= 1 then issues[#issues+1] = "expected one tank, found " .. counts.TANK end
        if counts.HEALER ~= 1 then issues[#issues+1] = "expected one healer, found " .. counts.HEALER end
    end
    return issues
end
function A:ReviewRoles(quiet)
    if not self.activeGroup then if not quiet then self:Print("Not in a group.") end; return end
    local issues = self:RoleIssues()
    if #issues > 0 then
        self:Notify("Roles need confirmation: " .. table.concat(issues, "; "), "roles:" .. self.groupSerial)
    elseif not quiet then
        self:Print("Roles look assigned. Confirm with the group anyway if the party is unconventional.")
    end
end

-- Ready-check status is private; never automatically announces results to chat.
-- A lack of READY_CHECK_CONFIRM is not proof the member clicked "Not ready".
function A:OnReadyCheckEvent(event, ...)
    if not self.activeGroup then return end
    if event == "READY_CHECK" then
        self.readyCheck = {serial=self.groupSerial, results={}, started=self:Now()}
    elseif event == "READY_CHECK_CONFIRM" then
        local unit, isReady = ...
        local name = UnitExists and UnitExists(unit) and
            ((GetUnitName and GetUnitName(unit, true)) or UnitName(unit))
        local key = self:Key(name)
        if key ~= "" and self.readyCheck and self.readyCheck.serial == self.groupSerial then
            self.readyCheck.results[key] = isReady == true and "ready" or "not ready"
        end
    elseif event == "READY_CHECK_FINISHED" then
        local check = self.readyCheck
        self.readyCheck = nil
        if not check or check.serial ~= self.groupSerial then return end
        local counts = {ready=0, unready=0, unknown=0}
        for key in pairs(self.roster) do
            local status = check.results[key]
            if status == "ready" then counts.ready = counts.ready+1
            elseif status == "not ready" then counts.unready = counts.unready+1
            else counts.unknown = counts.unknown+1 end
        end
        self:Notify(string.format("Ready check responses: %d ready, %d not ready, %d unconfirmed (may include members without an event).",
            counts.ready, counts.unready, counts.unknown), "ready:" .. tostring(check.started))
    end
end
