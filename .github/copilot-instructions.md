# Copilot Instructions for Shop_Nades Plugin

## Repository Overview
This repository contains a **SourceMod plugin** for Source engine games that provides grenade model customization through a shop system. The plugin allows players to purchase and equip different visual models for their grenades, integrating with the broader Shop-Core plugin ecosystem.

**Plugin Purpose**: Extends game functionality by replacing default grenade models with custom ones (watermelon, banana, axe, beer bottle, etc.) that players can purchase using in-game currency.

## Technical Environment

### Core Technologies
- **Language**: SourcePawn (.sp files)
- **Platform**: SourceMod 1.11.0+ (Source engine games like CS:GO, CS:S, TF2)
- **Build System**: SourceKnight (sourceknight.yaml configuration)
- **Compiler**: SourcePawn compiler (spcomp) via SourceKnight

### Dependencies
- **SourceMod**: Version 1.11.0-git6934 or newer
- **MultiColors**: For colored chat messages ([sm-plugin-MultiColors](https://github.com/srcdslab/sm-plugin-MultiColors))
- **Shop-Core**: Main shop system ([sm-plugin-Shop-Core](https://github.com/srcdslab/sm-plugin-Shop-Core))

### Key Files Structure
```
addons/sourcemod/
├── scripting/
│   └── Shop_Nades.sp          # Main plugin source (399 lines)
└── configs/shop/
    ├── nades.txt              # Item definitions and prices
    └── nades_downloads.txt    # Download requirements (currently empty)
sourceknight.yaml              # Build configuration and dependencies
.github/workflows/ci.yml       # Automated CI/CD pipeline
```

## Code Style & Standards

### SourcePawn-Specific Guidelines
- Use `#pragma semicolon 1` and `#pragma newdecls required` (migrate legacy code)
- **Indentation**: Tabs (4 spaces equivalent)
- **Variables**: camelCase for locals, PascalCase for functions, prefix globals with "g_"
- **Memory Management**: Use `delete` instead of `CloseHandle()` (legacy code needs updating)
- **Arrays**: Prefer `StringMap`/`ArrayList` over static arrays when appropriate

### Current Code Issues to Address
The existing code uses **legacy SourcePawn syntax** and should be modernized:
```sourcepawn
// Current (legacy):
new Handle:kv;
new String:sNadeMdl[MAXPLAYERS+1][PLATFORM_MAX_PATH];

// Should be (modern):
KeyValues kv;
char sNadeMdl[MAXPLAYERS+1][PLATFORM_MAX_PATH];
```

### Memory Management
- Use `delete` directly without null checks: `delete kv;`
- **Never** use `.Clear()` on StringMap/ArrayList (causes memory leaks)
- Use `delete` and recreate instead: `delete myMap; myMap = new StringMap();`

## Plugin Architecture

### Core Components
1. **Item Registration**: Reads `nades.txt` configuration and registers shop items
2. **Model Handling**: Precaches and applies custom grenade models
3. **Shop Integration**: Communicates with Shop-Core for purchases/equipping
4. **Event Handling**: Manages player connect/disconnect and grenade events

### Key Functions
- `Shop_Started()`: Registers items with shop system
- `OnMapStart()`: Loads configuration and precaches models
- `OnEquipItem()`: Handles item equipping/unequipping
- `OnEntityCreated()`: Applies custom models to grenades

### Configuration System
- **nades.txt**: KeyValues format defining available items with prices, models, and attributes
- **Model Validation**: Only `.mdl` files are accepted and automatically precached
- **Pricing**: Each item has both purchase and sell prices

## Build & Development Process

### Building the Plugin
```bash
# Using SourceKnight (recommended)
sourceknight build

# Manual compilation (if needed)
spcomp -i addons/sourcemod/scripting/include addons/sourcemod/scripting/Shop_Nades.sp
```

### Testing Requirements
- Test on a development server with Shop-Core installed
- Verify model precaching doesn't cause performance issues
- Ensure grenade model changes apply correctly to all grenade types
- Test item purchasing, equipping, and selling functionality

### CI/CD Pipeline
- **Automated Building**: GitHub Actions compiles plugin on push/PR
- **Artifact Creation**: Packages plugin with configurations
- **Release Management**: Automatic releases on tags and main branch updates

## Development Best Practices

### Performance Considerations
- **Model Precaching**: All models are precached on map start to prevent in-game lag
- **Event Optimization**: Minimize operations in frequently called functions like `OnEntityCreated`
- **Memory Efficiency**: Use appropriate data structures (StringMap for lookups, ArrayList for lists)

### Error Handling
- Validate configuration file parsing with `FileToKeyValues`
- Check model file extensions before precaching
- Handle missing or invalid shop items gracefully
- Provide clear error messages for administrators

### Shop Integration
- Use `Shop_RegisterCategory()` to create item categories
- Implement proper item callbacks for equip/unequip events
- Support item attributes and custom properties
- Follow Shop-Core API patterns for consistency

### Security & Validation
- Validate all file paths and model references
- Escape any user input if SQL operations are added
- Check item permissions and requirements before allowing equips

## Common Development Tasks

### Adding New Grenade Models
1. Add model entry to `addons/sourcemod/configs/shop/nades.txt`
2. Ensure model files are available and properly named
3. Set appropriate pricing and attributes
4. Test model precaching and application

### Updating Legacy Code
Priority areas for modernization:
- Replace `Handle` with proper types (`KeyValues`, `StringMap`, etc.)
- Update variable declarations to new syntax
- Replace `CloseHandle()` with `delete`
- Add `#pragma newdecls required`

### Debugging Issues
- Check SourceMod error logs for compilation or runtime errors
- Verify Shop-Core is loaded and functioning
- Ensure model files exist and are accessible
- Test configuration file syntax and formatting

## Integration Points

### Shop-Core Dependency
- Registers as shop category "nades"
- Uses shop callbacks for item management
- Supports shop permissions and economy system
- Follows shop item lifecycle (purchase → equip → sell)

### Game Engine Integration
- Hooks entity creation for grenade model replacement
- Uses SourceMod's model precaching system
- Integrates with Source engine's entity system
- Supports multiple Source engine games

## Maintenance Notes
- Monitor for SourceMod API changes that might affect compatibility
- Update dependencies when new stable versions are released
- Review configuration files for balance and new content
- Maintain backwards compatibility when possible

---

**When working with this repository**: Focus on maintaining compatibility with the Shop-Core ecosystem, ensure proper memory management, and follow SourcePawn best practices. The plugin is stable but would benefit from syntax modernization and improved error handling.