# AGENTS.md - Godot 4 GDScript Project

## Encounter System Overview
The game now includes a comprehensive encounter system that manages battles across multiple waves. Key features:
- **Wave-based battles**: Each encounter consists of multiple waves of enemies
- **Dynamic difficulty**: Adjustable difficulty modes with adaptive scaling
- **JSON configuration**: All encounters and enemy templates defined in data files
- **Rewards system**: Experience, gold, items, and unlockables
- **Environment modifiers**: Encounter-specific battle rules

### Key Files:
- `encounter_manager.gd` - Main encounter orchestrator
- `encounter.gd` - Individual encounter configuration
- `wave.gd` - Wave management within encounters
- `unit_factory.gd` - Enemy generation from templates
- `difficulty_scaler.gd` - Difficulty scaling system
- `encounter_rewards.gd` - Rewards and progression system
- `data/encounters.json` - Encounter definitions
- `data/unit_templates.json` - Enemy unit templates

### Test Scene:
- Run `encounter_test.tscn` to test the encounter system

## Build/Test Commands
- **Run tests**: `./run_tests.sh` or `godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
- **Run specific test**: `godot --headless -s res://addons/gut/gut_cmdln.gd -gtest=test_property_projector.gd -gexit`
- **Run tests in editor**: Open `run_all_tests.tscn` and press F6
- **Lint/Format**: Use Godot editor's built-in script analyzer
- **Run project**: Open in Godot 4.x editor and press F5

## Testing Notes
- Tests use the GUT (Godot Unit Test) framework v9.3.0
- Test files must extend `GutTest` class from `res://addons/gut/test.gd`
- Tests are located in `tests/unit/` and `tests/integration/`
- Enable the GUT plugin in Project Settings > Plugins if not already enabled

## Code Style Guidelines

### GDScript Conventions
- Use `class_name` at top of scripts for custom classes
- Prefer `extends RefCounted` for data objects, `extends Node` for scene objects
- Order: class_name, extends, signals, enums, exports, vars, _init, _ready, public methods, private methods
- Use type hints: `var value: float`, `func method(param: String) -> int`
- Prefix private members with underscore: `var _internal_state`

### Naming & Structure
- Classes: PascalCase (PropertyProjector, Modifier)
- Functions/variables: snake_case (add_modifier, base_damage)
- Signals: snake_case verb phrases (projection_changed)
- Constants/enums: UPPER_SNAKE_CASE or PascalCase for enum values
- File names: snake_case.gd matching class_name when possible

### Error Handling
- Use `push_error()` for runtime errors
- Use `assert()` for programmer errors/preconditions
- Return null or empty values on failure, document in comments
- Validate inputs early, especially Dictionary keys and types
- **Dictionary Access**: Always check if key exists with `has()` before accessing:
  ```gdscript
  # Bad - causes "Invalid access to property or key" error
  var value = dict["key"]
  
  # Good - safe access
  if dict.has("key"):
      var value = dict["key"]
  # Or use get() with default
  var value = dict.get("key", default_value)
  ```

## MCP Integration

This project includes MCP (Model Context Protocol) server integration for AI-assisted development:

### Setup MCP Server
1. Run `./setup_mcp.sh` to install dependencies
2. Configure Claude Desktop (see MCP_SETUP.md)
3. Server provides tools for testing, data management, and scene control

### Available MCP Tools
- `run_tests` - Run GUT unit tests
- `check_script_errors` - Validate GDScript syntax
- `get_encounter_data` - View encounter configurations
- `add_unit_template` - Add new unit templates
- `create_encounter` - Create new encounters
- `run_scene` - Run specific Godot scenes

See `MCP_SETUP.md` for complete documentation.