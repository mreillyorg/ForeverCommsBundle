local _, A = ...
function A:TryBroker()
    if self.broker then return end
    local lib = LibStub and LibStub("LibDataBroker-1.1", true)
    if not lib then return end
    self.broker = lib:NewDataObject("ForeverGroupComms", {
        type="data source", label="Group Comms", text="Group Comms", icon="Interface\\AddOns\\ForeverGroupComms\\Media\\Icon",
        OnClick=function(_, button)
            if button == "RightButton" then A:OpenSettings()
            elseif IsShiftKeyDown and IsShiftKeyDown() then A:ShowQuests()
            else A:ShowPanel() end
        end,
        OnTooltipShow=function(t)
            t:AddLine("Forever Group Comms")
            t:AddLine("Click: quick group actions")
            t:AddLine("Shift-click: quest comparison")
            t:AddLine("Right-click: settings")
        end,
    })
    self:UpdateBroker()
end
function A:UpdateBroker()
    if not self.broker then return end
    local count=0
    for _ in pairs(self.roster) do count = count+1 end
    self.broker.text = self.activeGroup and ("Group " .. count .. " | Review " .. #self.approvals) or "Group Comms"
end
