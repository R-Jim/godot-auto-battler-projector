# AGENTS.md - Godot 4 GDScript Project

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