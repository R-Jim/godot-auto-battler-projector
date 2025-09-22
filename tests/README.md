# Test Suite

This directory contains unit and integration tests for the Auto Battler project using the GUT (Godot Unit Test) framework.

## Running Tests

### From Godot Editor
1. Open the project in Godot 4.x
2. Enable the GUT plugin if not already enabled (Project > Project Settings > Plugins)
3. Open `scenes/tests/run_all_tests.tscn` in the editor
4. Press F6 to run the test scene

### From Command Line
```bash
# Run all tests
./run_tests.sh

# Or manually with Godot
godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

# Run specific test file
godot --headless -s res://addons/gut/gut_cmdln.gd -gtest=test_property_projector.gd -gexit
```

## Test Structure

- `unit/` - Unit tests for individual classes
  - `test_property_projector.gd` - Tests for PropertyProjector system
  - `test_battle_unit.gd` - Tests for BattleUnit functionality
  - `test_equipment.gd` - Tests for Equipment system
  - `test_status_effect.gd` - Tests for StatusEffect
  - `test_battle_skill.gd` - Tests for BattleSkill
  - `test_battle_rule_processor.gd` - Tests for rule processing
  - `test_tag_builder.gd` - Tests for tag building system

- `integration/` - Integration tests
  - `test_battle_integration.gd` - End-to-end battle system tests

## Writing Tests

All test files must:
1. Extend `GutTest` class
2. Use `test_` prefix for test methods
3. Use `before_each()` for setup
4. Use `after_each()` for cleanup

Example:
```gdscript
extends GutTest

var my_object

func before_each():
    my_object = MyClass.new()

func after_each():
    my_object.queue_free()

func test_example():
    assert_eq(my_object.value, 0)
```

## Common Assertions

- `assert_eq(got, expected)` - Assert equality
- `assert_ne(got, not_expected)` - Assert not equal
- `assert_true(condition)` - Assert true
- `assert_false(condition)` - Assert false
- `assert_null(value)` - Assert null
- `assert_not_null(value)` - Assert not null
- `assert_gt/gte/lt/lte(a, b)` - Comparison assertions
- `assert_signal_emitted(obj, signal_name)` - Assert signal was emitted
- `assert_signal_emitted_with_parameters(obj, signal_name, params)` - Assert signal with specific parameters

## Notes

- The GUT framework is installed in `/addons/gut/`
- Configuration is in `.gutconfig.json`
- Tests requiring scene tree nodes should properly add/remove them
- Use `watch_signals()` to track signal emissions
- Use `gut.p()` for debug output during tests