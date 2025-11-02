-- CombatLogs.lua - Main addon file
-- Combat Log Manager for WoW 3.3.5

-- Initialize the addon
CombatLogs = {}
CombatLogs.frame = CreateFrame("Frame", "CombatLogsFrame")




-- Set up event handler immediately
CombatLogs.frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "CombatLogs" then
            CombatLogs:Initialize()
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "PLAYER_ENTERING_WORLD" then
        if CombatLogs.CheckZone then
            CombatLogs:CheckZone()
        end
    end
end)

-- Register events immediately
CombatLogs.frame:RegisterEvent("ADDON_LOADED")
CombatLogs.frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
CombatLogs.frame:RegisterEvent("ZONE_CHANGED")
CombatLogs.frame:RegisterEvent("ZONE_CHANGED_INDOORS")
CombatLogs.frame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Default settings
local defaults = {
    zones = {
        ["Zul'Gurub"] = true,
        ["Molten Core"] = true,
        ["Blackwing Lair"] = true,
        },
    currentZoneLogging = false,
    debugMode = false
}

-- Database reference
CombatLogsDB = CombatLogsDB or {}

-- Initialize addon
function CombatLogs:Initialize()
    -- Merge saved variables with defaults
    for key, value in pairs(defaults) do
        if CombatLogsDB[key] == nil then
            CombatLogsDB[key] = value
        end
    end
    
    -- Special handling for zones - merge default zones into existing zones table
    if CombatLogsDB.zones then
        for zoneName, enabled in pairs(defaults.zones) do
            if CombatLogsDB.zones[zoneName] == nil then
                CombatLogsDB.zones[zoneName] = enabled
                self:Print("Added default zone: " .. zoneName)
            end
        end
    end
    
    self:Print("Combat Logs Manager loaded. Type /combatlogs for options.")
end

-- Check current zone and manage combat logging
function CombatLogs:CheckZone()
    local zoneName = GetZoneText()
    local instanceName, instanceType = GetInstanceInfo()
    
    -- Use instance name if available, otherwise use zone name
    local currentZone = instanceName ~= "" and instanceName or zoneName
    
    -- Check if current zone is in our monitored zones list (case-insensitive)
    local shouldLog = false
    for zoneName, enabled in pairs(CombatLogsDB.zones) do
        if enabled and zoneName:lower() == currentZone:lower() then
            shouldLog = true
            break
        end
    end
    
    if shouldLog and not CombatLogsDB.currentZoneLogging then
        self:StartCombatLog(currentZone)
    -- Commented out: Don't stop combat logging when leaving monitored zones
    -- This keeps combat logging active even when outside monitored zones
    --elseif not shouldLog and CombatLogsDB.currentZoneLogging then
    --    self:StopCombatLog()
    end
end

-- Start combat logging
function CombatLogs:StartCombatLog(zoneName)
    -- Check if combat logging is already active
    if LoggingCombat() then
        self:Print("Combat logging already active for: " .. zoneName)
        CombatLogsDB.currentZoneLogging = true
        return
    end
    
    -- Start combat logging by executing the /combatlog command
    SlashCmdList["COMBATLOG"]("")
    CombatLogsDB.currentZoneLogging = true
    self:Print("Combat logging started for: " .. zoneName)
end

-- Stop combat logging
function CombatLogs:StopCombatLog()
    -- Check if combat logging is actually active before stopping
    if not LoggingCombat() then
        self:Print("Combat logging was already stopped")
        CombatLogsDB.currentZoneLogging = false
        return
    end
    
    -- Stop combat logging by executing the /combatlog command
    SlashCmdList["COMBATLOG"]("")
    CombatLogsDB.currentZoneLogging = false
    self:Print("Combat logging stopped")
end

-- Add a zone to monitoring list
function CombatLogs:AddZone(zoneName)
    if not zoneName or zoneName == "" then
        self:Print("Please specify a zone name")
        return
    end
    
    -- Ensure zones table exists
    if not CombatLogsDB.zones then
        CombatLogsDB.zones = {}
    end
    
    CombatLogsDB.zones[zoneName] = true
    self:Print("Added zone to combat log monitoring: " .. zoneName)
end

-- Remove a zone from monitoring list
function CombatLogs:RemoveZone(zoneName)
    if not zoneName or zoneName == "" then
        self:Print("Please specify a zone name")
        return
    end
    
    if CombatLogsDB.zones[zoneName] then
        CombatLogsDB.zones[zoneName] = nil
        self:Print("Removed zone from combat log monitoring: " .. zoneName)
    else
        self:Print("Zone not found in monitoring list: " .. zoneName)
    end
end

-- List all monitored zones
function CombatLogs:ListZones()
    local count = 0
    self:Print("Monitored zones:")
    
    -- Ensure zones table exists
    if not CombatLogsDB.zones then
        CombatLogsDB.zones = {}
    end
    
    for zoneName, _ in pairs(CombatLogsDB.zones) do
        self:Print("  - " .. zoneName)
        count = count + 1
    end
    
    if count == 0 then
        self:Print("  No zones are currently being monitored")
    end
end

-- Toggle debug mode
function CombatLogs:ToggleDebug()
    CombatLogsDB.debugMode = not CombatLogsDB.debugMode
    self:Print("Debug mode: " .. (CombatLogsDB.debugMode and "enabled" or "disabled"))
end

-- Get current zone name
function CombatLogs:GetCurrentZone()
    local zoneName = GetZoneText()
    local instanceName, instanceType = GetInstanceInfo()
    local currentZone = instanceName ~= "" and instanceName or zoneName
    
    self:Print("Current zone: " .. currentZone)
    if instanceType and instanceType ~= "" then
        self:Print("Instance type: " .. instanceType)
    end
    
    return currentZone
end

-- Add current zone to monitoring
function CombatLogs:AddCurrentZone()
    local currentZone = self:GetCurrentZone()
    self:AddZone(currentZone)
end

-- Print function
function CombatLogs:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[CombatLogs]|r " .. msg)
    
    -- Close chat input box for WoW 3.3.5
    if ChatFrame1EditBox and ChatFrame1EditBox:IsVisible() then
        ChatFrame1EditBox:Hide()
    end
    if DEFAULT_CHAT_FRAME.editBox and DEFAULT_CHAT_FRAME.editBox:IsVisible() then
        DEFAULT_CHAT_FRAME.editBox:Hide()
    end
end

-- Slash command handler
SLASH_COMBATLOGS1 = "/combatlogs"
SLASH_COMBATLOGS2 = "/cl"
SlashCmdList["COMBATLOGS"] = function(msg)
    -- Split the message into command and arguments
    local args = {}
    for word in string.gmatch(msg, "%S+") do
        table.insert(args, word)
    end
    
    local command = args[1] and args[1]:lower() or ""
    local rest = ""
    
    -- Rebuild the rest of the arguments
    if #args > 1 then
        local restArgs = {}
        for i = 2, #args do
            table.insert(restArgs, args[i])
        end
        rest = table.concat(restArgs, " ")
    end
    
    if command == "" or command == "help" then
        CombatLogs:Print("Available commands:")
        CombatLogs:Print("/combatlogs add [zone] - Add zone to monitoring (or current zone if no name given)")
        CombatLogs:Print("/combatlogs remove [zone] - Remove zone from monitoring")
        CombatLogs:Print("/combatlogs list - List all monitored zones")
        CombatLogs:Print("/combatlogs current - Show current zone")
        CombatLogs:Print("/combatlogs status - Show addon status")
        CombatLogs:Print("/combatlogs debug - Toggle debug mode")
        CombatLogs:Print("/combatlogs test - Test zone detection manually")
        CombatLogs:Print("/combatlogs gui - Open settings GUI")
    elseif command == "test" then
        CombatLogs:Print("Manual zone test:")
        CombatLogs:CheckZone()
    elseif command == "add" then
        if rest == "" then
            CombatLogs:AddCurrentZone()
        else
            CombatLogs:AddZone(rest)
        end
    elseif command == "remove" then
        CombatLogs:RemoveZone(rest)
    elseif command == "list" then
        CombatLogs:ListZones()
    elseif command == "current" then
        CombatLogs:GetCurrentZone()
    elseif command == "status" then
        CombatLogs:Print("Combat Logs Manager is always active")
        CombatLogs:Print("Currently logging: " .. (CombatLogsDB.currentZoneLogging and "yes" or "no"))
        CombatLogs:Print("Debug mode: " .. (CombatLogsDB.debugMode and "enabled" or "disabled"))
    elseif command == "debug" then
        CombatLogs:ToggleDebug()
    elseif command == "gui" then
        if CombatLogs.GUI and CombatLogs.GUI.Toggle then
            CombatLogs.GUI:Toggle()
        else
            CombatLogs:Print("GUI not available")
        end
    else
        CombatLogs:Print("Unknown command: '" .. command .. "'. Type /combatlogs help for available commands.")
    end
end