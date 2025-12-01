# CombatLogs Manager

A World of Warcraft 3.3.5 addon that automatically manages combat logging based on instance zones.

## Features

- **Automatic Combat Logging** - Starts combat logging when entering specified zones/instances (/combatlog)
- **Zone-Based Monitoring** - Configure which zones should trigger combat logging
- **Smart Zone Transitions** - Intelligent popup system when changing between zones
- **Multi-Zone Support** - Handles transitions between different monitored zones seamlessly
- **Persistent Settings** - All settings saved to WTF folder between sessions
- **CLI Commands** - Complete slash command system for in-game management
- **Case-Insensitive Matching** - Zone names work regardless of capitalization
- **Always Active** - No need to manually enable, works automatically

## Installation

1. Extract the `CombatLogs` folder to your `Interface\AddOns\` directory
2. Rename the folder to `CombatLogs`
3. Restart WoW or type `/reload`
4. The addon will load automatically with default zones pre-configured

## Default Monitored Zones

The addon comes pre-configured to monitor these zones:

- Zul'Gurub
- Molten Core
- Ruins of Ahn'Qiraj
- Temple of Ahn'Qiraj
- Blackwing Lair
- Ahn'Qiraj
- Naxxramas
- Azuregos (PvE)
- Master's Gastric Pit
- The Scarab Wall
- The Scarab Dais
- Kazzak (PvE)
- Lord Kazzak (PvE)
- Soggoth (PvE)

## Commands

### Basic Commands

- `/combatlogs` or `/cl` - Show help
- `/cl add [zone]` - Add zone to monitoring (current zone if no name given)
- `/cl remove [zone]` - Remove zone from monitoring
- `/cl list` - List all monitored zones
- `/cl current` - Show current zone name

### Utility Commands

- `/cl status` - Show addon status
- `/cl debug` - Toggle debug mode
- `/cl test` - Manually test zone detection
- `/cl gui` - Open settings GUI

## Usage Examples

```
/cl add Icecrown Citadel    # Add ICC to monitoring
/cl add                     # Add your current zone
/cl remove Icrecrown Citadel              # Remove a zone
/cl list                   # See all monitored zones
```

## How It Works

1. **Zone Monitoring** - The addon listens for zone change events
2. **Auto-Activation** - When you enter a monitored zone, it automatically runs `/combatlog`
3. **Continuous Logging** - Combat logging stays active even when leaving monitored zones
4. **Settings Storage** - All configurations saved to `WTF\Account\[Account]\SavedVariables\CombatLogs.lua`

## Smart Popup System

The addon features an intelligent popup system that handles different zone transition scenarios:

### Entering a Monitored Zone (First Time)
- Shows a **green "Starting Combat Logs"** popup
- **Options:**
  - `OK` - Continue logging
  - `Do Not Log` - Stop logging immediately

### Leaving a Monitored Zone
- Shows a **red "Looks like you are leaving"** popup asking if you want to keep logging
- **Options:**
  - `Yes, Keep Logging` - Continue logging in the new area
  - `No, Stop Logging` - Stop combat logging

### Changing Between Monitored Zones
- When you leave one monitored zone and enter another (e.g., Molten Core → Blackwing Lair)
- Shows which zone you're leaving and which you're entering
- **Options:**
  - `Yes, Keep Logging` - Continue the same log file seamlessly
  - `Start New Log` - Stop current log and start fresh for the new zone
  - `No, Stop Logging` - Stop logging entirely

### Auto-Dismiss Behavior
- Popups automatically close when you change zones to prevent multiple overlapping dialogs
- Smart detection prevents duplicate popups from appearing

## GUI Interface

Access the GUI with `/cl gui` for:

- Enable/disable toggle controls
- Current zone display with quick-add button
- Scrollable list of monitored zones
- Add/remove zones with buttons
- Debug mode toggle

## Technical Details

### Zone Detection

- Uses `GetInstanceInfo()` for instance names
- Falls back to `GetZoneText()` for regular zones
- Case-insensitive matching for user convenience

### Combat Logging

- Executes actual `/combatlog` slash command
- Checks current logging status before starting
- Shows standard WoW combat logging messages

### Event System

- Listens for `ZONE_CHANGED_NEW_AREA`, `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`, `PLAYER_ENTERING_WORLD`
- Automatic zone checking on any zone transition

## Settings File Location

Settings are automatically saved to:

```
WTF\Account\[YourAccountName]\SavedVariables\CombatLogs.lua
```

## Troubleshooting

### Combat logging not starting?

1. Check if the zone is monitored: `/cl list`
2. Test zone detection: `/cl test`
3. Add current zone: `/cl add`

### Zone names not matching?

- Use `/cl current` to see exact zone name
- Zone matching is case-insensitive
- Instance names may include "(Normal)" or "(Heroic)"

### GUI not opening?

- Make sure both CombatLogs.lua and CombatLogsGUI.lua are loaded
- Try `/reload` to refresh the addon

## Compatibility

- **WoW Version**: 3.3.5 (Wrath of the Lich King)
- **Server**: Tested on Ascension WoW
- **Combat Logging**: Uses standard WoW combat logging system

## Notes

- Combat logs in WoW 3.3.5 are buffered and written to file in chunks
- Log data appears in `Logs\WoWCombatLog.txt` after buffer flushes
- The addon correctly starts/stops logging; file writing is handled by WoW client

## Support

For issues or feature requests, check your addon configuration and ensure all files are properly installed in the AddOns directory.


