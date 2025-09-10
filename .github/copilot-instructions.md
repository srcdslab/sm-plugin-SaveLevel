# SaveLevel Plugin - Copilot Coding Agent Instructions

## Repository Overview

This repository contains **SaveLevel**, a SourcePawn plugin for SourceMod that saves and restores player progression/levels on zombie escape maps when players disconnect and reconnect. The plugin tracks entity properties and outputs to maintain game state continuity across player sessions.

**Key Functionality:**
- Automatically saves player level/progress when they disconnect
- Restores saved progress when players reconnect
- Supports complex level matching based on entity properties, outputs, and mathematical calculations
- Map-specific configuration system for different zombie escape maps

## Technical Environment

- **Language**: SourcePawn
- **Platform**: SourceMod 1.11.0+ (configured in sourceknight.yaml)
- **Build System**: SourceKnight (modern SourceMod build tool)
- **Compiler**: SourcePawn compiler (spcomp) via SourceKnight
- **CI/CD**: GitHub Actions workflow (`.github/workflows/ci.yml`)

## Dependencies

**Required Extensions/Plugins:**
- SourceMod 1.11.0+ (base framework)
- MultiColors (colored chat messages)
- OutputInfo (entity output manipulation)
- UtilsHelper (utility functions)

**Include Files Used:**
- `sourcemod.inc` - Core SourceMod API
- `sdktools.inc` - SDK Tools for entity manipulation
- `outputinfo.inc` - Custom extension for output handling
- `multicolors.inc` - Chat color formatting
- `utilshelper.inc` - Utility functions

## Project Structure

```
addons/sourcemod/
├── scripting/
│   └── SaveLevel.sp              # Main plugin source (567 lines)
├── configs/savelevel/            # Map-specific configuration files
│   ├── ze_FFVII_Mako_Reactor_*.cfg
│   ├── ze_harry_potter_*.cfg
│   └── [other map configs]
└── plugins/                      # Compiled plugins (generated)
    └── SaveLevel.smx

.github/
├── workflows/ci.yml              # Build and release automation
└── dependabot.yml               # Dependency management

sourceknight.yaml                 # Build configuration
```

## Code Architecture

### Core Components

1. **Global Variables:**
   - `g_PlayerLevels` (StringMap) - Stores player SteamID → level data mapping
   - `g_Config` (KeyValues) - Current map configuration
   - `g_PropAltNames` (KeyValues) - Property name aliases

2. **Key Functions:**
   - `OnPluginStart()` - Initialize plugin, register commands
   - `OnPluginEnd()` - Cleanup memory (proper delete usage)
   - `OnClientPostAdminCheck()` - Restore player levels on connect
   - `OnClientDisconnect()` - Save player levels on disconnect
   - `RestoreLevel()` - Apply saved level to player
   - `GetLevel()` - Determine current player level
   - `LoadMapConfig()` - Load map-specific configuration

3. **Level Matching System:**
   - **Props matching**: Entity property values (`m_iName`, etc.)
   - **Outputs matching**: Entity output configurations
   - **Math matching**: Mathematical calculations on output parameters
   - **Complex logic**: MinMatches, MaxMatches, ExactMatches criteria

## Configuration System

### Map Configuration Files
- Located in `addons/sourcemod/configs/savelevel/`
- Format: KeyValues (`.cfg` files)
- Naming: `mapname.cfg` (e.g., `ze_FFVII_Mako_Reactor_v1_4_1.cfg`)

### Configuration Structure
```
"levels"
{
    "0"
    {
        "name"      "Level 0"
        "restore"   // Actions to restore this level
        "match"     // Criteria to identify this level
    }
    "1"
    {
        "name"      "Level 1" 
        "match"
        {
            "props"    // Entity property matching
            "outputs"  // Entity output matching  
            "math"     // Mathematical calculations
        }
        "restore"
        {
            "AddOutput"     // Add entity outputs
            "DeleteOutput"  // Remove entity outputs
            "m_iName"       // Set entity properties
        }
    }
}
```

## Build & Development Process

### Building the Plugin

**Using SourceKnight (Recommended):**
```bash
# Install SourceKnight if not already installed
npm install -g sourceknight

# Build the plugin
sourceknight build
```

**Output:** Compiled plugin will be in `addons/sourcemod/plugins/SaveLevel.smx`

### CI/CD Pipeline
- **Trigger**: Push, PR, or manual workflow dispatch
- **Build**: Automated via GitHub Actions using SourceKnight
- **Package**: Creates distributable tar.gz with plugin + configs
- **Release**: Auto-releases on tags and main/master branch pushes

### Testing
- Deploy to development SourceMod server
- Test with map configurations in `configs/savelevel/`
- Verify level saving/restoration across player disconnects
- Check for memory leaks using SourceMod's profiler

## Code Style & Best Practices

### SourcePawn Standards (Applied in this codebase)
- ✅ `#pragma semicolon 1` and `#pragma newdecls required`
- ✅ Tab indentation (4 spaces)
- ✅ camelCase for local variables (`sSteamID`, `sTargets`)
- ✅ PascalCase for functions (`RestoreLevel`, `GetLevel`)
- ✅ Global variable prefix `g_` (`g_PlayerLevels`, `g_Config`)
- ✅ Proper memory management with `delete` keyword
- ✅ No null checks before `delete` (not needed in SourcePawn)

### Memory Management Patterns
```sourcepawn
// ✅ Correct cleanup pattern (used in this plugin)
public void OnPluginEnd()
{
    if(g_Config)
        delete g_Config;
    if(g_PlayerLevels)
        delete g_PlayerLevels;
    delete g_PropAltNames;  // No null check needed
}

// ✅ Proper StringMap recreation (avoid .Clear())
delete g_PlayerLevels;
g_PlayerLevels = new StringMap();
```

### Entity Interaction Patterns
```sourcepawn
// Property access
GetEntPropString(client, Prop_Data, sKey, sOutput, sizeof(sOutput));

// Output manipulation 
SetVariantString(sValue);
AcceptEntityInput(client, sKey, client, client);

// Output deletion
while((Index = FindOutput(client, sValue, 0)) != -1)
    DeleteOutput(client, sValue, Index);
```

## Common Development Tasks

### Adding New Map Support
1. Create new config file: `addons/sourcemod/configs/savelevel/mapname.cfg`
2. Define level structure with match criteria and restore actions
3. Test level detection and restoration in-game
4. Validate configuration syntax

### Modifying Level Logic
1. Focus on `GetLevel()` function for detection logic
2. Modify `RestoreLevel()` for restoration behavior
3. Update configuration parsing if needed
4. Test with existing map configurations

### Adding New Matching Criteria
1. Extend the match system in `GetLevel()` function
2. Add new section handling (currently: props, outputs, math)
3. Update configuration documentation
4. Ensure backward compatibility

### Debugging Common Issues
- **Level not saving**: Check `OnClientDisconnect()` and `GetLevel()` logic
- **Level not restoring**: Verify `OnClientPostAdminCheck()` and `RestoreLevel()`
- **Config not loading**: Check `LoadMapConfig()` and file paths
- **Memory leaks**: Review `delete` usage and KeyValues handling

## Plugin Commands

### Admin Commands
- `sm_level <player> <level>` - Manually set player level (ADMFLAG_GENERIC)
- `sm_savelevel_reload` - Reload map configuration (ADMFLAG_CONFIG)

### Server Commands  
- `sm_clearlevelcache` - Clear all cached player levels

## Performance Considerations

### Current Optimizations
- StringMap for O(1) player data lookup
- KeyValues caching for configuration
- Efficient entity property access
- Minimal timer usage

### Areas to Monitor
- Level detection complexity (called frequently)
- Configuration parsing overhead
- Memory usage with large player counts
- Entity output manipulation performance

## Security & Validation

### Input Validation
- SteamID validation before storage/retrieval
- Entity validity checks before manipulation
- Configuration value bounds checking

### SQL Considerations
- **Note**: This plugin doesn't use SQL currently
- If adding database features: Use async queries, escape strings, prevent injection

## Troubleshooting Guide

### Common Error Patterns
1. **Plugin fails to load**: Check dependency inclusion and SourceMod version
2. **Levels not detected**: Verify map configuration exists and is valid
3. **Memory errors**: Review delete usage and KeyValues cleanup
4. **Entity manipulation fails**: Check entity validity and property names

### Debugging Tools
- SourceMod error logs
- Plugin profiler for performance analysis
- Entity debugging commands for property inspection
- KeyValues dump for configuration validation

## Files You Should NOT Modify
- `.github/workflows/ci.yml` (unless changing build process)
- `sourceknight.yaml` dependencies (unless upgrading versions)
- Existing map configuration files (unless fixing bugs)

## Getting Started Checklist

When working on this repository:

1. **Setup**: Ensure SourceKnight is available for building
2. **Build**: Test compilation with `sourceknight build`
3. **Test Environment**: Set up development SourceMod server
4. **Map Configs**: Review existing configurations to understand patterns
5. **Code Review**: Focus on memory management and entity manipulation
6. **Testing**: Verify level saving/restoration with real gameplay scenarios

This plugin is production-ready and actively used, so maintain high code quality and thorough testing for any changes.