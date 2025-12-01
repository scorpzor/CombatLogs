-- CombatLogs.lua - Main addon file
-- Combat Log Manager for WoW 3.3.5

-- Initialize the addon
CombatLogs = {}
CombatLogs.frame = CreateFrame("Frame", "CombatLogsFrame")
CombatLogs.leavingPopupShown = false  -- Track if we've shown the leaving popup

-- Define the combat log start popup
StaticPopupDialogs["COMBATLOGS_STARTED"] = {
    text = "|cff00ff00[Combat Logs]|r\n\nStarting /combatlog Combat Logging.\n\nSee output in your WoW\\Logs folder:\nWoWCombatLog.txt",
    button1 = "OK",
    button2 = "Do Not Log",
    OnAccept = function()
        -- OK button - do nothing, just dismiss
    end,
    OnCancel = function()
        -- Do Not Log button - stop combat logging
        if LoggingCombat() then
            SlashCmdList["COMBATLOG"]("")
            if CombatLogsDB then
                CombatLogsDB.currentZoneLogging = false
            end
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[CombatLogs]|r Logging Stopped")
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Define the leaving zone popup
StaticPopupDialogs["COMBATLOGS_LEAVING_ZONE"] = {
    text = "",  -- Will be set dynamically
    button1 = "Yes, Keep Logging",
    button2 = "No, Stop Logging",
    OnAccept = function()
        -- Keep Logging button - do nothing, just dismiss
        CombatLogs.leavingPopupShown = false
    end,
    OnCancel = function()
        -- Stop Logging button - stop combat logging
        CombatLogs.leavingPopupShown = false
        if LoggingCombat() then
            SlashCmdList["COMBATLOG"]("")
            if CombatLogsDB then
                CombatLogsDB.currentZoneLogging = false
                CombatLogsDB.lastLoggedZone = nil
            end
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[CombatLogs]|r Logging Stopped")
        end
    end,
    OnHide = function()
        -- Do nothing when hidden/dismissed - only stop on explicit button click
        CombatLogs.leavingPopupShown = false
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = false,  -- Don't allow ESC to close (prevents accidental stop)
    preferredIndex = 3,
}

-- Define the changing zone popup (entering new monitored zone while already logging)
StaticPopupDialogs["COMBATLOGS_CHANGING_ZONE"] = {
    text = "",  -- Will be set dynamically
    button1 = "Yes, Keep Logging",
    button2 = "Start New Log",
    button3 = "No, Stop Logging",
    OnAccept = function()
        -- Keep Logging button - just update the zone and dismiss
        CombatLogs.leavingPopupShown = false
        if CombatLogsDB.pendingNewZone then
            CombatLogsDB.lastLoggedZone = CombatLogsDB.pendingNewZone
            CombatLogsDB.pendingNewZone = nil
        end
    end,
    OnCancel = function()
        -- Start New Log button - stop and restart logging
        CombatLogs.leavingPopupShown = false
        if LoggingCombat() then
            SlashCmdList["COMBATLOG"]("")
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[CombatLogs]|r Logging Stopped")
        end
        -- Small delay to ensure stop is processed
        C_Timer.After(0.5, function()
            if CombatLogsDB.pendingNewZone then
                local newZone = CombatLogsDB.pendingNewZone
                CombatLogsDB.pendingNewZone = nil
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[CombatLogs]|r Combat being logged to Logs\\WoWCombatLog.txt for " .. newZone)
                SlashCmdList["COMBATLOG"]("")
                CombatLogsDB.currentZoneLogging = true
                CombatLogsDB.lastLoggedZone = newZone
            end
        end)
    end,
    OnAlt = function()
        -- No, Stop Logging button
        CombatLogs.leavingPopupShown = false
        if LoggingCombat() then
            SlashCmdList["COMBATLOG"]("")
            if CombatLogsDB then
                CombatLogsDB.currentZoneLogging = false
                CombatLogsDB.lastLoggedZone = nil
                CombatLogsDB.pendingNewZone = nil
            end
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[CombatLogs]|r Logging Stopped")
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = false,
    preferredIndex = 3,
}


-- Set up event handler immediately 
CombatLogs.frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "CombatLogs" then
            CombatLogs:Initialize()
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        -- Only check zone on major zone changes (after loading screen)
        if CombatLogs.CheckZone then
            CombatLogs:CheckZone(event)
        end
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "PLAYER_ENTERING_WORLD" then
        -- For other events, just check without popup prompts
        if CombatLogs.CheckZone then
            CombatLogs:CheckZone(event)
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
        ["Ruins of Ahn'Qiraj"] = true,
        ["Temple of Ahn'Qiraj"] = true,
        ["Blackwing Lair"] = true,
        ["Ahn'Qiraj"] = true,
        ["Naxxramas"] = true,
        ["Azuregos (PvE)"] = true,
        ["Master's Gastric Pit"] = true,
        ["The Scarab Wall"] = true,
        ["The Scarab Dais"] = true,
        ["Kazzak (PvE)"] = true,
        ["Lord Kazzak (PvE)"] = true,
        ["Soggoth (PvE)"] = true,
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
function CombatLogs:CheckZone(event)
    -- First, sync our database state with actual combat logging state
    local actuallyLogging = LoggingCombat()
    if CombatLogsDB.currentZoneLogging ~= actuallyLogging then
        CombatLogsDB.currentZoneLogging = actuallyLogging
    end
    
    local zoneName = GetZoneText()
    local instanceName, instanceType = GetInstanceInfo()
    
    -- Use instance name if available, otherwise use zone name
    local currentZone = instanceName ~= "" and instanceName or zoneName
    
    if not CombatLogsDB.zones then
        return
    end
    
    -- Check if current zone is in our monitored zones list (case-insensitive)
    local shouldLog = false
    for zoneName, enabled in pairs(CombatLogsDB.zones) do
        if enabled and zoneName:lower() == currentZone:lower() then
            shouldLog = true
            break
        end
    end
    
    if shouldLog and not CombatLogsDB.currentZoneLogging then
        -- Entering a monitored zone - start logging
        -- Reset the leaving popup flag when entering a monitored zone
        CombatLogs.leavingPopupShown = false
        
        -- Close any existing popups before starting logging
        StaticPopup_Hide("COMBATLOGS_STARTED")
        StaticPopup_Hide("COMBATLOGS_LEAVING_ZONE")
        StaticPopup_Hide("COMBATLOGS_CHANGING_ZONE")
        
        self:StartCombatLog(currentZone)
    elseif shouldLog and CombatLogsDB.currentZoneLogging then
        -- Already logging and entering a monitored zone
        local lastZone = CombatLogsDB.lastLoggedZone or "Unknown Zone"
        
        -- Check if it's a different zone than what we were logging
        if lastZone:lower() ~= currentZone:lower() then
            -- Entering a DIFFERENT monitored zone - show changing zone popup
            CombatLogs.leavingPopupShown = false
            StaticPopup_Hide("COMBATLOGS_LEAVING_ZONE")
            StaticPopup_Hide("COMBATLOGS_STARTED")
            
            -- Store the new zone temporarily
            CombatLogsDB.pendingNewZone = currentZone
            
            -- Show the changing zone popup
            StaticPopupDialogs["COMBATLOGS_CHANGING_ZONE"].text = "|cff00ff00[Combat Logs]|r\n\nYou are now entering a new logging location of\n\"|cff00ffff" .. currentZone .. "|r\"\n\nwhich is different from\n\"|cff00ffff" .. lastZone .. "|r\"\n\nWould you like to keep logging?"
            StaticPopup_Show("COMBATLOGS_CHANGING_ZONE")
        else
            -- Re-entering the same monitored zone - just close leaving popup and confirm
            CombatLogs.leavingPopupShown = false
            StaticPopup_Hide("COMBATLOGS_LEAVING_ZONE")
            CombatLogsDB.lastLoggedZone = currentZone
            self:Print("Still logging for: " .. currentZone)
        end
    elseif not shouldLog and CombatLogsDB.currentZoneLogging and event == "ZONE_CHANGED_NEW_AREA" then
        -- Leaving a monitored zone while logging - only show popup on major zone change
        -- Only show popup if we haven't already shown it
        if not CombatLogs.leavingPopupShown then
            local lastZone = CombatLogsDB.lastLoggedZone or "Unknown Zone"
            if not CombatLogsDB.lastLoggedZone then
                -- Legacy state - save it for future
                CombatLogsDB.lastLoggedZone = lastZone
            end
            
            -- Close the "STARTED" popup if it's still open, accept it by default (keep logging)
            StaticPopup_Hide("COMBATLOGS_STARTED")
            
            -- Mark that we're showing the popup
            CombatLogs.leavingPopupShown = true
            -- Delay showing popup until after zone is fully loaded
            C_Timer.After(1, function()
                -- Double-check we're still logging and still not in a monitored zone
                if CombatLogsDB.currentZoneLogging and LoggingCombat() then
                    -- Update the text and show the popup
                    StaticPopupDialogs["COMBATLOGS_LEAVING_ZONE"].text = "|cff00ff00[Combat Logs]|r\n\n|cffff0000Looks like you are leaving|r\n\"" .. lastZone .. "\"\n\nWould you like to keep logging?"
                    StaticPopup_Show("COMBATLOGS_LEAVING_ZONE")
                else
                    -- Conditions changed, reset the flag
                    CombatLogs.leavingPopupShown = false
                end
            end)
        end
    end
end

-- Start combat logging
function CombatLogs:StartCombatLog(zoneName)
    -- Check if combat logging is already active
    if LoggingCombat() then
        self:Print("Combat logging already active for: " .. zoneName)
        CombatLogsDB.currentZoneLogging = true
        CombatLogsDB.lastLoggedZone = zoneName
        return
    end
    
    -- Start combat logging by executing the /combatlog command
    self:Print("Combat being logged to Logs\\WoWCombatLog.txt for " .. zoneName)
    SlashCmdList["COMBATLOG"]("")
    CombatLogsDB.currentZoneLogging = true
    CombatLogsDB.lastLoggedZone = zoneName
    
    -- Show popup notification
    StaticPopup_Show("COMBATLOGS_STARTED")
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
