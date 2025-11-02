-- CombatLogsGUI.lua - GUI interface for Combat Logs Manager

CombatLogs.GUI = {}
local GUI = CombatLogs.GUI

-- Create the main frame
function GUI:CreateMainFrame()
    if self.mainFrame then
        return self.mainFrame
    end
    
    -- Main frame
    local frame = CreateFrame("Frame", "CombatLogsMainFrame", UIParent)
    frame:SetSize(400, 300)
    frame:SetPoint("CENTER")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText("Combat Logs Manager")
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function() frame:Hide() end)
    
    -- Enable checkbox
    local enabledCheckbox = CreateFrame("CheckButton", "CombatLogsEnabledCheckbox", frame, "UICheckButtonTemplate")
    enabledCheckbox:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -50)
    enabledCheckbox:SetSize(24, 24)
    enabledCheckbox.text = enabledCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enabledCheckbox.text:SetPoint("LEFT", enabledCheckbox, "RIGHT", 5, 0)
    enabledCheckbox.text:SetText("Enable Combat Logs Manager")
    enabledCheckbox:SetScript("OnClick", function()
        CombatLogs:ToggleEnabled()
        GUI:UpdateDisplay()
    end)
    
    -- Debug checkbox
    local debugCheckbox = CreateFrame("CheckButton", "CombatLogsDebugCheckbox", frame, "UICheckButtonTemplate")
    debugCheckbox:SetPoint("TOPLEFT", enabledCheckbox, "BOTTOMLEFT", 0, -10)
    debugCheckbox:SetSize(24, 24)
    debugCheckbox.text = debugCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    debugCheckbox.text:SetPoint("LEFT", debugCheckbox, "RIGHT", 5, 0)
    debugCheckbox.text:SetText("Debug Mode")
    debugCheckbox:SetScript("OnClick", function()
        CombatLogs:ToggleDebug()
        GUI:UpdateDisplay()
    end)
    
    -- Current zone display
    local currentZoneLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currentZoneLabel:SetPoint("TOPLEFT", debugCheckbox, "BOTTOMLEFT", 0, -20)
    currentZoneLabel:SetText("Current Zone:")
    
    local currentZoneText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    currentZoneText:SetPoint("LEFT", currentZoneLabel, "RIGHT", 5, 0)
    currentZoneText:SetText("Unknown")
    
    -- Add current zone button
    local addCurrentButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    addCurrentButton:SetSize(120, 22)
    addCurrentButton:SetPoint("LEFT", currentZoneText, "RIGHT", 10, 0)
    addCurrentButton:SetText("Add Current")
    addCurrentButton:SetScript("OnClick", function()
        CombatLogs:AddCurrentZone()
        GUI:UpdateZoneList()
    end)
    
    -- Zone management section
    local zoneLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    zoneLabel:SetPoint("TOPLEFT", currentZoneLabel, "BOTTOMLEFT", 0, -25)
    zoneLabel:SetText("Monitored Zones:")
    
    -- Zone list scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "CombatLogsZoneScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", zoneLabel, "BOTTOMLEFT", 0, -5)
    scrollFrame:SetSize(250, 100)
    
    local zoneListFrame = CreateFrame("Frame", nil, scrollFrame)
    zoneListFrame:SetSize(250, 100)
    scrollFrame:SetScrollChild(zoneListFrame)
    
    -- Add zone input
    local addZoneLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addZoneLabel:SetPoint("TOPLEFT", scrollFrame, "BOTTOMLEFT", 0, -10)
    addZoneLabel:SetText("Add Zone:")
    
    local addZoneEditBox = CreateFrame("EditBox", "CombatLogsAddZoneEditBox", frame, "InputBoxTemplate")
    addZoneEditBox:SetPoint("LEFT", addZoneLabel, "RIGHT", 10, 0)
    addZoneEditBox:SetSize(150, 20)
    addZoneEditBox:SetAutoFocus(false)
    addZoneEditBox:SetScript("OnEnterPressed", function()
        local zoneName = addZoneEditBox:GetText()
        if zoneName and zoneName ~= "" then
            CombatLogs:AddZone(zoneName)
            addZoneEditBox:SetText("")
            GUI:UpdateZoneList()
        end
    end)
    
    local addZoneButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    addZoneButton:SetSize(50, 22)
    addZoneButton:SetPoint("LEFT", addZoneEditBox, "RIGHT", 5, 0)
    addZoneButton:SetText("Add")
    addZoneButton:SetScript("OnClick", function()
        local zoneName = addZoneEditBox:GetText()
        if zoneName and zoneName ~= "" then
            CombatLogs:AddZone(zoneName)
            addZoneEditBox:SetText("")
            GUI:UpdateZoneList()
        end
    end)
    
    -- Store references
    self.mainFrame = frame
    self.enabledCheckbox = enabledCheckbox
    self.debugCheckbox = debugCheckbox
    self.currentZoneText = currentZoneText
    self.zoneListFrame = zoneListFrame
    self.scrollFrame = scrollFrame
    self.addZoneEditBox = addZoneEditBox
    self.zoneButtons = {}
    
    return frame
end

-- Update the display with current settings
function GUI:UpdateDisplay()
    if not self.mainFrame then
        return
    end
    
    self.enabledCheckbox:SetChecked(CombatLogsDB.enabled)
    self.debugCheckbox:SetChecked(CombatLogsDB.debugMode)
    
    -- Update current zone
    local zoneName = GetZoneText()
    local instanceName, instanceType = GetInstanceInfo()
    local currentZone = instanceName ~= "" and instanceName or zoneName
    self.currentZoneText:SetText(currentZone)
    
    self:UpdateZoneList()
end

-- Update the zone list
function GUI:UpdateZoneList()
    if not self.zoneListFrame then
        return
    end
    
    -- Clear existing buttons
    for _, button in pairs(self.zoneButtons) do
        button:Hide()
        button:SetParent(nil)
    end
    self.zoneButtons = {}
    
    -- Create new buttons for each zone
    local yOffset = 0
    for zoneName, _ in pairs(CombatLogsDB.zones) do
        local zoneFrame = CreateFrame("Frame", nil, self.zoneListFrame)
        zoneFrame:SetSize(240, 20)
        zoneFrame:SetPoint("TOPLEFT", self.zoneListFrame, "TOPLEFT", 0, yOffset)
        
        local zoneText = zoneFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        zoneText:SetPoint("LEFT", zoneFrame, "LEFT", 5, 0)
        zoneText:SetText(zoneName)
        zoneText:SetJustifyH("LEFT")
        zoneText:SetSize(180, 20)
        
        local removeButton = CreateFrame("Button", nil, zoneFrame, "UIPanelButtonTemplate")
        removeButton:SetSize(50, 18)
        removeButton:SetPoint("RIGHT", zoneFrame, "RIGHT", -5, 0)
        removeButton:SetText("Remove")
        removeButton:SetScript("OnClick", function()
            CombatLogs:RemoveZone(zoneName)
            GUI:UpdateZoneList()
        end)
        
        table.insert(self.zoneButtons, zoneFrame)
        yOffset = yOffset - 25
    end
    
    -- Update scroll frame content height
    local contentHeight = math.max(100, math.abs(yOffset))
    self.zoneListFrame:SetHeight(contentHeight)
end

-- Toggle the GUI visibility
function GUI:Toggle()
    if not self.mainFrame then
        self:CreateMainFrame()
    end
    
    if self.mainFrame:IsShown() then
        self.mainFrame:Hide()
    else
        self:UpdateDisplay()
        self.mainFrame:Show()
    end
end

-- Show the GUI
function GUI:Show()
    if not self.mainFrame then
        self:CreateMainFrame()
    end
    
    self:UpdateDisplay()
    self.mainFrame:Show()
end

-- Hide the GUI
function GUI:Hide()
    if self.mainFrame then
        self.mainFrame:Hide()
    end
end

-- Initialize GUI when addon loads
local function OnAddonLoaded()
    -- GUI is ready to be created when needed
end

-- Hook into the main addon's event system
if CombatLogs and CombatLogs.frame then
    local originalOnEvent = CombatLogs.OnEvent
    CombatLogs.OnEvent = function(self, event, ...)
        originalOnEvent(self, event, ...)
        if event == "ADDON_LOADED" then
            local addonName = ...
            if addonName == "CombatLogs" then
                OnAddonLoaded()
            end
        end
    end
end