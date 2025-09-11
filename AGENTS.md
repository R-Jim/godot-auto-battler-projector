# AGENTS.md - Godot 4 GDScript Auto-Battler Project

## 1. Project Summary

### System Architecture Overview
This project implements a complete auto-battler game system in Godot 4 using GDScript. The architecture consists of three primary interconnected systems:

1. **Battle System**: Core auto-battler mechanics with property projection, skills, and AI
2. **Encounter System**: Wave-based battle orchestration with difficulty scaling
3. **Progression System**: Player and unit advancement with persistent save data

Each system is designed to be modular and testable, with clear interfaces between components.

### Critical Integration Points
- The `EncounterManager` drives battle instances through the `AutoBattler` class
- The `ProgressionManager` (AutoLoad singleton) receives rewards from completed encounters
- The `UnitFactory` creates units using templates from both player progression and encounter data
- All systems share common data structures defined in `data/*.json` files

## 2. Player Progression System

### Core Architecture
The progression system tracks player advancement through a hierarchical data model:

**Component Hierarchy:**
1. `ProgressionManager` (AutoLoad) - Global progression controller
2. `PlayerData` - Player profile with team capacity and unlocks
3. `UnitData` - Individual unit stats, skills, and equipment
4. `SaveManager` - Persistence layer for all progression data

### Implementation Details

**Key Files and Responsibilities:**
- `player_data.gd` - Manages player XP ($level = \lfloor \log_2(XP/100) \rfloor$), team slots, and global unlocks
- `unit_data.gd` - Tracks individual unit progression including:
  - Base stats (hp, attack, defense, speed)
  - Skill unlocks and upgrades
  - Equipment slots (weapon, armor, accessory)
  - Unit-specific XP and level
- `progression_manager.gd` - Central controller that:
  - Distributes encounter rewards
  - Manages unit roster
  - Triggers save/load operations
  - Validates progression state
- `save_manager.gd` - Handles file I/O with versioning and validation
- `player_hud.gd/tscn` - UI components for progression display

### Critical Implementation Notes
- XP distribution uses weighted allocation based on unit participation
- Save files use JSON format with schema validation
- Unit templates in `data/unit_templates.json` define base stats and growth curves
- Equipment modifiers stack additively before multiplicative effects

### Test Coverage
- Run `progression_test_scene.tscn` for interactive testing
- Unit tests in `tests/unit/test_player_progression.gd`

## 3. Encounter System

### System Design
The encounter system manages multi-wave battles with dynamic difficulty adjustment:

**Encounter Flow:**
1. `EncounterManager` loads encounter definition from JSON
2. Creates waves with scaled enemy units via `UnitFactory`
3. Instantiates `AutoBattler` for each wave
4. Processes rewards through `EncounterRewards`
5. Updates progression via `ProgressionManager`

### Component Architecture

**Core Components:**
- `encounter_manager.gd` - Main orchestrator that:
  - Manages encounter state machine (setup → wave → victory/defeat)
  - Handles wave transitions with proper cleanup
  - Applies environmental modifiers
  - Processes completion rewards
- `encounter.gd` - Data model for individual encounters:
  - Wave configurations
  - Difficulty parameters
  - Environmental rules
  - Reward tables
- `wave.gd` - Single wave management:
  - Enemy unit spawning
  - Victory/defeat conditions
  - Wave-specific modifiers
- `unit_factory.gd` - Unit instantiation with:
  - Template-based creation
  - Difficulty scaling application
  - Stat randomization within bounds
- `difficulty_scaler.gd` - Scaling calculations:
  - Linear stat scaling: $stat_{scaled} = stat_{base} \times (1 + 0.1 \times difficulty)$
  - Enemy count adjustment
  - Reward multipliers
- `encounter_rewards.gd` - Reward processing:
  - XP calculation and distribution
  - Gold and item generation
  - Unlock condition checking

### Data Structures
- `data/encounters.json` - Encounter definitions with wave arrays
- `data/unit_templates.json` - Enemy and player unit base configurations

### Environmental Modifiers
Encounters can apply battle-wide effects:
- Stat modifiers (e.g., +20% speed to all units)
- Damage type resistances/vulnerabilities
- Special victory conditions

### Test Scenarios
- `encounter_test.tscn` - Standalone encounter testing
- `progression_test_scene.tscn` - Full integration testing

## 4. Build and Test Infrastructure

### Build Commands
```bash
# Run all tests (headless)
./run_tests.sh
# Alternative: godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

# Run specific test file
godot --headless -s res://addons/gut/gut_cmdln.gd -gtest=test_property_projector.gd -gexit

# Run tests with pattern matching
godot --headless -s res://addons/gut/gut_cmdln.gd -gtest=test_*skill*.gd -gexit

# Run tests in editor (visual)
# Open run_all_tests.tscn and press F6

# Lint/Format
# Use Godot editor's built-in script analyzer (Project → Tools → Script Editor → Script → Tool → Format)

# Run project
# Open in Godot 4.x editor and press F5
```

### Testing Framework Configuration
**GUT (Godot Unit Test) v9.3.0 Setup:**
1. Tests must extend `GutTest` from `res://addons/gut/test.gd`
2. Test directory structure:
   - `tests/unit/` - Isolated unit tests
   - `tests/integration/` - System integration tests
3. GUT plugin must be enabled in Project Settings → Plugins

**Test File Requirements:**
```gdscript
extends GutTest

func before_each():
    # Setup code here
    pass

func test_example():
    # Test implementation
    assert_eq(actual, expected, "Description of assertion")
```

### Critical Test Files
- `test_property_projector.gd` - Core stat calculation tests
- `test_battle_unit.gd` - Unit behavior and state management
- `test_skill_cast.gd` - Skill execution and targeting
- `test_encounter_system.gd` - Wave and reward processing
- `test_player_progression.gd` - XP and unlock systems

## 5. Code Style and Conventions

### GDScript Structure Requirements

**File Organization (strict order):**
```gdscript
class_name MyClass
extends BaseClass

# Signals
signal state_changed(old_state: int, new_state: int)

# Enums
enum State { IDLE, ACTIVE, COMPLETE }

# Constants
const MAX_RETRIES: int = 3

# Exported variables
@export var public_property: float = 1.0

# Private variables
var _internal_state: State = State.IDLE

# Lifecycle methods
func _init() -> void:
    pass

func _ready() -> void:
    pass

# Public methods
func do_action(param: String) -> bool:
    return true

# Private methods  
func _validate_state() -> void:
    pass
```

### Naming Conventions (Mandatory)
| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `PropertyProjector`, `BattleUnit` |
| Files | snake_case.gd | `property_projector.gd`, `battle_unit.gd` |
| Functions | snake_case | `calculate_damage()`, `add_modifier()` |
| Variables | snake_case | `base_damage`, `unit_count` |
| Private members | _snake_case | `_internal_state`, `_cached_value` |
| Signals | snake_case verb | `value_changed`, `battle_started` |
| Constants | UPPER_SNAKE_CASE | `MAX_HEALTH`, `DEFAULT_SPEED` |
| Enums | PascalCase | `enum DamageType { PHYSICAL, MAGICAL }` |

### Type Safety Requirements
**All functions and variables MUST have type annotations:**
```gdscript
# Required format
var health: int = 100
var damage_multiplier: float = 1.5
var unit_list: Array[BattleUnit] = []
var config: Dictionary = {}

func calculate_damage(base: float, multiplier: float) -> int:
    return int(base * multiplier)

# Signal parameters must be typed
signal damage_dealt(attacker: BattleUnit, target: BattleUnit, amount: int)
```

### Error Handling Patterns

**Critical Principle: Fail Fast with Clear Errors**

```gdscript
# Dictionary access pattern (REQUIRED)
func get_unit_stat(stats: Dictionary, stat_name: String) -> float:
    if not stats.has(stat_name):
        push_error("Stat '%s' not found in stats dictionary" % stat_name)
        return 0.0
    
    var value = stats[stat_name]
    if not value is float and not value is int:
        push_error("Stat '%s' has invalid type: %s" % [stat_name, type_string(typeof(value))])
        return 0.0
    
    return float(value)

# Precondition validation
func apply_damage(amount: int) -> void:
    assert(amount >= 0, "Damage amount must be non-negative")
    assert(is_inside_tree(), "Unit must be in scene tree")
    
    # Implementation
    _current_health = max(0, _current_health - amount)

# Null safety pattern
func get_target_unit() -> BattleUnit:
    var target = _find_best_target()
    if not target:
        push_warning("No valid target found")
        return null
    return target
```

### Documentation Requirements
```gdscript
## Brief class description.
## Detailed explanation if needed.
class_name ExampleClass

## Calculates the final damage after applying all modifiers.
## Returns the damage amount, minimum 0.
## @param base_damage: Raw damage before modifiers
## @param armor: Target's armor value
## @return: Final damage to apply
func calculate_final_damage(base_damage: float, armor: float) -> int:
    # Implementation
    pass
```

## 6. MCP Integration

### Overview
The project includes MCP (Model Context Protocol) server integration for AI-assisted development. This enables Claude Desktop to directly interact with the Godot project for testing, data management, and scene control.

### Setup Process
1. **Install Dependencies:**
   ```bash
   ./setup_mcp.sh
   ```
   This installs Python dependencies and configures the virtual environment.

2. **Configure Claude Desktop:**
   Update Claude Desktop settings as documented in `MCP_SETUP.md`

3. **Verify Connection:**
   The MCP server provides bidirectional communication with the Godot project.

### Available MCP Tools

| Tool | Purpose | Parameters |
|------|---------|------------|
| `run_tests` | Execute GUT unit tests | `pattern` (optional): Test file pattern |
| `check_script_errors` | Validate GDScript syntax | `script_path`: Path to script file |
| `get_encounter_data` | Retrieve encounter configurations | `encounter_id` (optional): Specific encounter |
| `add_unit_template` | Create new unit templates | `template_data`: Unit configuration JSON |
| `create_encounter` | Define new encounters | `encounter_data`: Encounter definition JSON |
| `run_scene` | Execute Godot scenes | `scene_path`: Path to .tscn file |

### Implementation Details
- Server: `mcp_godot_server.py`
- Configuration: `opencode_mcp_config.json`
- Full documentation: `MCP_SETUP.md`

## 7. Architecture Principles

### Design Patterns
1. **Property Projection**: Stats are calculated through a modifier pipeline, not stored directly
2. **Component Composition**: Units gain abilities through skill and equipment components
3. **Event-Driven Updates**: State changes propagate through signals, not polling
4. **Data-Driven Configuration**: Game balance lives in JSON, not code

### Performance Considerations
- Property projections are cached and invalidated on modifier changes
- Battle simulations run at fixed timestep (10 updates/second)
- Visual updates are decoupled from simulation logic
- Large battles (>20 units) may require optimization

### Extension Points
- New skill types: Extend `Skill` class and implement `execute()`
- Custom AI behaviors: Override `_select_target()` in `BattleAI`
- Additional stat types: Add to `PropertyProjector` pipeline
- New progression mechanics: Extend `ProgressionManager`

## 8. Known Limitations and Future Work

### Current Limitations
1. No multiplayer support - single player only
2. Limited to 2D sprite-based visuals
3. Maximum 32 units per battle (performance constraint)
4. Save files not encrypted (JSON plaintext)

### Planned Enhancements
1. Skill combo system for chained abilities
2. Tournament mode with bracket progression
3. Unit fusion/evolution mechanics
4. Steam Workshop integration for custom content

### Technical Debt
- `BattleUnit` class needs refactoring (>500 lines)
- Test coverage at 75%, target 90%
- Performance profiling needed for large battles
- Save file migration system required