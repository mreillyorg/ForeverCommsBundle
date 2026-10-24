local _, A = ...
function A:TryBroker()
    if self.broker then return end
    local lib = LibStub and LibStub("LibDataBroker-1.1", true)
    if not lib then return end
    self.broker = lib:NewDataObject("ForeverGroupComms", {
        type="data source", label="Group Comms", text="Group Comms", icon="Interface\\AddOns\\ForeverGroupComms\\Media\\Icon",
        OnClick=function(frame, button)
            if button == "RightButton" then A:OpenTitanMenu(frame)
            elseif IsShiftKeyDown and IsShiftKeyDown() then A:ShowQuests()
            else A:ShowPanel() end
        end,
        OnTooltipShow=function(tooltip)
            -- Match ForeverGuildComms' Titan tooltip visual hierarchy.
            local snapshot = A:StatusSnapshot()
            local roles = snapshot.roles or {}
            tooltip:AddLine("Forever Group Comms")
            tooltip:AddLine("Group: " .. (snapshot.grouped and (snapshot.count .. " members") or "Not grouped"), 1, 1, 1)
            tooltip:AddLine(string.format("Roles: %d tank / %d healer / %d DPS / %d unassigned",
                roles.TANK or 0, roles.HEALER or 0, roles.DAMAGER or 0, roles.NONE or 0), 1, 1, 1)
            tooltip:AddLine("Quest sync: " .. (A.db and A.db.questSync and "Enabled" or "Disabled"), 1, 1, 1)
            tooltip:AddLine("Messages awaiting approval: " .. (snapshot.queued or 0), 1, 0.8, 0.4)
            tooltip:AddLine("Left-click: quick group actions", 0.7, 0.8, 1)
            tooltip:AddLine("Shift + left-click: quest comparison", 0.7, 0.8, 1)
            tooltip:AddLine("Right-click: nested options + quick actions", 0.7, 0.8, 1)
        end,
    })
    self:UpdateBroker()
end
function A:UpdateBroker()
    if not self.broker then return end
    local count=0
    for _ in pairs(self.roster) do count = count+1 end
    local status = self:StatusSnapshot()
    self.broker.text = self.activeGroup and ("Group " .. count .. " | Review " .. status.queued) or "Group Comms"
end
