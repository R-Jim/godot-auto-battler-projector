# Auto Battler - Godot 4 Implementation

A sophisticated auto battler implementation for Godot 4 featuring a data-driven stat projection system, rule-based mechanics, and comprehensive progression. This project demonstrates clean architecture principles with complete separation of game logic from implementation, allowing designers to modify game behavior through JSON configuration.

## Table of Contents

1. [Overview](#overview)
2. [Project Status](#project-status)
3. [Getting Started](#getting-started)
4. [Core Systems](#core-systems)
5. [Stat Projection System](#stat-projection-system)
6. [Battle System](#battle-system)
7. [Encounter System](#encounter-system)
8. [Player Progression System](#player-progression-system)
9. [Skills & Abilities](#skills--abilities)
10. [Configuration Guide](#configuration-guide)
11. [Testing](#testing)
12. [MCP Integration](#mcp-integration)
13. [Architecture](#architecture)

## Overview

This auto battler demonstrates professional game development practices in Godot 4:

### Core Features
- **Stat Projection System**: Mathematical engine for dynamic stat calculations with layered modifiers
- **Rule-Based Combat**: JSON-driven mechanics allowing runtime behavior modification
- **Full Progression System**: Player and unit advancement with persistent saves
- **Visual Battle System**: Animated 2D combat with formations and effects
- **AI-Driven Combat**: Multiple AI personalities for varied gameplay
- **Encounter Management**: Wave-based battles with difficulty scaling

### Architecture Highlights
- **Data-Driven Design**: Game balance lives in JSON, not code
- **Clean Separation**: Business logic isolated from presentation
- **Test Coverage**: Comprehensive unit and integration tests
- **MCP Integration**: AI-assisted development support

## Project Status

✅ **Production Ready Systems:**
- Core battle mechanics and stat calculations
- Turn-based auto-battler combat
- Player progression with save/load
- Encounter system with 10+ configured battles
- Visual battle system with animations
- Equipment and skill systems
- Status effects and combat modifiers

⚠️ **Known Issues:**
- Visual component initialization in test environment
- Some observer pattern memory management warnings

## Getting Started

### Requirements
- Godot Engine 4.4.1 or higher
- GUT (Godot Unit Test) framework v9.3.0 (included)
- Python 3.8+ (for MCP integration, optional)

### Quick Start
1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd godot-auto-battler-projector
   ```

2. Open in Godot 4 and run one of these scenes:
   - `scenes/tests/progression_test_scene.tscn` - Full game experience with progression
   - `scenes/tests/visual_battle_test.tscn` - Visual battle system testing
   - `scenes/tests/encounter_test_scene.tscn` - Encounter selection and management
   - `scenes/samples/sample_battle.tscn` - Basic combat demonstration

3. Run tests:
   ```bash
   ./run_tests.sh  # Headless testing
   # or open scenes/tests/run_all_tests.tscn in editor
   ```

## Core Systems

### 1. Stat Projection System (`src/skills/stat_projector.gd`)

The mathematical engine powering all stat calculations. Each stat uses a StatProjector to manage and apply modifiers in a predictable order.

```gdscript
# Example: Unit with base attack of 10
var attack_projector = StatProjector.new()

# Add a sword (+5 attack)
attack_projector.add_modifier(Modifier.create_add("sword", 5.0, priority=10))

# Add a strength buff (+20%)
attack_projector.add_modifier(Modifier.create_mul("strength_buff", 1.2, priority=20))

# Final attack = (10 + 5) * 1.2 = 18
var final_attack = attack_projector.project(10.0)
```

#### Modifier Types
- **ADD**: Adds a flat value
- **MUL**: Multiplies by a factor
- **SET**: Overrides to a specific value

#### Modifier Properties
- **Priority**: Higher priority modifiers apply first
- **Expires At**: Unix timestamp when modifier auto-removes
- **Applies To**: Which properties this modifier affects
- **Insertion Order**: Tie-breaker for same priority

### 2. Battle System (`src/battle/auto_battler.gd`)

Complete auto-battler implementation with visual components:
- Turn-based combat with initiative system
- Skill execution with cooldowns and resources
- Status effect management
- AI-driven decision making
- Visual feedback with animations and effects

### 3. Battle Rule Processing (`src/battle/battle_rule_processor.gd`)

Evaluates conditions and generates modifiers based on game context. All combat mechanics are defined in the JSON file referenced by the project setting `[game] battle_rules_path` (defaults to `res://data/battle_rules.json`).

```json
{
  "id": "frozen_fire_vulnerability",
  "name": "Frozen targets take extra fire damage",
  "conditions": {
    "and": [
      { "property": "target_status", "op": "contains", "value": "frozen" },
      { "property": "skill_damage_type", "op": "eq", "value": "fire" }
    ]
  },
  "modifiers": [
    {
      "id": "frozen_fire_vuln",
      "op": "MUL",
      "value": 1.5,
      "priority": 50
    }
  ]
}
```

#### Condition Operators
- **eq/neq**: Equals/not equals
- **gt/gte/lt/lte**: Greater/less than (or equal)
- **contains**: Array/string contains value
- **in**: Value is in array
- **regex**: String matches pattern
- **$property**: Reference another context property

#### Logical Operators
- **and**: All conditions must be true
- **or**: Any condition must be true
- **not**: Inverts the condition

## Battle System

### Combat Flow

1. **Initialization**
   - Teams positioned in formations
   - Unit visuals created (sprites, health bars)
   - Battle rules loaded from JSON

2. **Turn Order**
   - Initiative: `speed + random(0-2)`
   - Units act in descending initiative order
   - Status effects processed before actions

3. **Action Resolution**
   - AI evaluates targets and skills
   - Skill execution with visual feedback
   - Damage calculation through stat projectors
   - Status effect application

4. **Victory Conditions**
   - Team elimination
   - Objective completion
   - Turn limit reached

### Damage Calculation Pipeline

```gdscript
# 1. Build context with all relevant battle information
var context = {
    "skill_name": "Fireball",
    "skill_damage_type": "fire",
    "caster_health_percentage": 0.8,
    "target_status": ["frozen"],
    "environmental_effects": ["rain"]
}

# 2. Rule processor evaluates conditions and generates modifiers
var modifiers = rule_processor.get_modifiers(context)

# 3. Apply modifiers through stat projector
var damage_projector = StatProjector.new()
for mod in modifiers:
    damage_projector.add_modifier(mod)

# 4. Calculate final damage
var final_damage = damage_projector.project(base_damage)
```

### Unit System

BattleUnit extends Node2D and includes:
- Base stats with individual StatProjectors
- Visual representation through UnitVisual
- Equipment slots (weapon, armor, accessory)
- Skill management with cooldowns
- Status effect tracking
- AI behavior configuration

```gdscript
# Unit initialization example
var unit = BattleUnit.new()
unit.init_from_template({
    "name": "Knight",
    "stats": {
        "health": 150,
        "attack": 20,
        "defense": 15,
        "speed": 5
    },
    "skills": ["sword_strike", "shield_bash"],
    "ai_type": "DEFENSIVE"
})
```

## Skills & Abilities

### Skill System Architecture

The skill system uses a cast-based approach with proper separation of concerns (see `docs/skill_system_architecture.md` for the full design rationale):

```gdscript
# Skill definition
var fireball = BattleSkill.new()
fireball.configure({
    "name": "Fireball",
    "base_damage": 35.0,
    "damage_type": "fire",
    "target_type": "single_enemy",
    "cooldown": 3.0,
    "mana_cost": 20.0
})

# Skill execution through SkillCast
var cast = SkillCast.new()
cast.execute(caster, skill, [target])
```

### Advanced Features
- **Skill Evaluation**: AI scoring system for optimal skill selection
- **Skill Queueing**: Action queue management for concurrent casts
- **Visual Effects**: Integrated animation system
- **Combo System**: Chain skills through rule conditions



## Encounter System

The encounter system provides structured wave-based combat progression:

### Architecture
- **EncounterManager**: Orchestrates multi-wave battles with proper cleanup
- **Wave Management**: Sequential combat waves with different objectives
- **Difficulty Scaling**: Dynamic adjustment based on player performance
- **Reward Distribution**: XP, gold, and item rewards with unlock progression
- **Formation System**: Strategic unit positioning for both teams

### Encounter Types
```json
{
  "encounter_id": "dragon_lair",
  "waves": [
    {
      "wave_type": "STANDARD",
      "enemy_units": [
        {"template_id": "dragon_whelp", "count": 3}
      ]
    },
    {
      "wave_type": "BOSS",
      "enemy_units": [
        {"template_id": "elder_dragon", "count": 1}
      ],
      "environmental_modifiers": ["fire_ground"]
    }
  ]
}
```

### Available Encounters
- Tutorial Battle - Training grounds introduction
- Forest Ambush - Early game combat
- Bandit Camp - Multi-wave assault
- Dragon's Lair - Boss encounter with environmental hazards
- Arena Championship - Tournament-style battles
- 10+ additional encounters with unique mechanics

## Configuration Guide

### JSON-Driven Game Design

All game mechanics can be modified through JSON files without touching code:

#### Battle Rules (`data/battle_rules.json`)
Define combat interactions, synergies, and conditional modifiers (stored as an array of rule dictionaries). Validate new entries against `data/battle_rules.schema.json` to ensure they map cleanly onto `StatProjector` modifiers:
```json
[
  {
    "id": "elemental_synergy",
    "name": "Fire melts ice for bonus damage",
    "conditions": {
      "and": [
        { "property": "target_status", "op": "contains", "value": "frozen" },
        { "property": "skill_damage_type", "op": "eq", "value": "fire" }
      ]
    },
    "modifiers": [
      { "id": "melt_bonus", "op": "MUL", "value": 1.5, "priority": 50 }
    ]
  }
]
```

#### Unit Templates (`data/unit_templates.json`)
Configure enemies and allies with stats, skills, and AI:
```json
{
  "id": "fire_mage",
  "name": "Pyromancer",
  "base_stats": {
    "health": 100,
    "attack": 30,
    "defense": 10,
    "speed": 6
  },
  "skills": ["fireball", "flame_wall", "ignite"],
  "ai_type": "AGGRESSIVE",
  "elemental_affinity": "fire"
}
```

#### Encounters (`data/encounters.json`)
Design multi-wave battles with rewards and progression:
```json
{
  "encounter_id": "volcano_ascent",
  "waves": [
    {
      "enemy_units": [
        {"template_id": "fire_elemental", "count": 2},
        {"template_id": "lava_golem", "count": 1}
      ],
      "environmental_effects": ["extreme_heat"]
    }
  ],
  "rewards": {
    "experience": 1000,
    "items": ["fire_resistance_ring"],
    "unlock_encounters": ["dragon_peak"]
  }
}
```

## Testing

### Test Infrastructure
The project includes comprehensive test coverage using GUT (Godot Unit Test) framework:

```bash
# Run all tests headless
./run_tests.sh

# Run specific test category
godot --headless -s res://addons/gut/gut_cmdln.gd -gtest=test_*unit*.gd

# Run tests in editor with GUI
# Open scenes/tests/run_all_tests.tscn
```

### Test Categories
- **Unit Tests** (`tests/unit/`): Core system functionality
  - Stat projectors and modifiers
  - Battle mechanics and skills
  - Progression and saves
  - AI decision making

- **Integration Tests** (`tests/integration/`): System interactions
  - Full battle scenarios
  - Encounter flow
  - Visual component integration
  - Observer patterns

### Writing Tests
```gdscript
extends GutTest

func test_damage_calculation():
    var projector = StatProjector.new()
    projector.add_modifier(Modifier.create_add("weapon", 10))
    projector.add_modifier(Modifier.create_mul("buff", 1.5))
    
    assert_eq(projector.project(100), 165.0)  # (100 + 10) * 1.5
```

## Player Progression System

Comprehensive progression tracking with persistent saves:

### Features
- **Player Profile**: Level-based progression with team capacity unlocks
- **Unit Development**: Individual XP, skill unlocks, and equipment
- **Roster Management**: Recruit and manage multiple units
- **Save System**: JSON-based persistence with versioning
- **Reward Integration**: Automatic processing from encounters

### Progression Flow
```gdscript
# Player levels up and unlocks new team slot
func _on_player_level_up(new_level: int):
    if new_level == 5:
        player_data.unlock_team_slot()
    if new_level % 10 == 0:
        player_data.unlock_new_unit_template()

# Unit gains experience and learns skills
func _on_unit_level_up(unit: UnitData, new_level: int):
    var new_skills = skill_unlock_table.get(new_level, [])
    for skill in new_skills:
        unit.learn_skill(skill)
```

### Visual Battle System
The game features a polished 2D visual presentation:
- Sprite-based unit rendering with team colors
- Health bars and status effect indicators
- Smooth attack and skill animations
- Floating damage numbers
- Formation-based positioning
- Camera controls for battle viewing



## MCP Integration

The project includes Model Context Protocol support for AI-assisted development:

### Features
- Direct project interaction through Claude Desktop
- Automated testing and validation
- Game data management (JSON editing)
- Scene execution and debugging
- Code analysis and refactoring support

### Setup
```bash
# Install MCP dependencies
./setup_mcp.sh

# Configure Claude Desktop (see MCP_SETUP.md)
```

### Available Tools
- `run_tests` - Execute test suites
- `check_script_errors` - Validate GDScript syntax
- `get_encounter_data` - Query game content
- `create_encounter` - Design new battles
- `run_scene` - Execute Godot scenes

## Architecture

### Design Principles
1. **Separation of Concerns**: Logic, data, and presentation are clearly separated
2. **Data-Driven Design**: Game behavior defined in JSON, not code
3. **Composition over Inheritance**: Systems built from reusable components
4. **Test-First Development**: Comprehensive test coverage for reliability

### Project Structure
```
├── src/
│   ├── battle/              # Auto-battler combat systems
│   ├── encounter/           # Wave orchestration and scaling
│   ├── progression/         # Player data, units, and saves
│   ├── skills/              # Skills, evaluators, and modifiers
│   ├── shared/              # Shared gameplay helpers (e.g., visuals)
│   └── ui/                  # HUD and other UI scripts
├── scenes/
│   ├── samples/             # Demo scenes for quick previews
│   └── tests/               # Instrumented test harness scenes
├── tools/
│   ├── diagnostics/         # Runtime verification utilities
│   └── testing/             # Automated test runners
├── tests/                   # GUT unit and integration suites
├── data/                    # JSON configuration for units/encounters
├── addons/                  # Third-party plugins (e.g., GUT)
└── run_tests.sh             # Convenience script for headless tests
```


### Extension Points
- Add new stat types in StatProjector
- Create custom AI behaviors
- Design new skill types and effects
- Implement additional victory conditions
- Add new visual effects and animations

## Contributing

When contributing to this project:
1. Follow the established code style (see AGENTS.md)
2. Add tests for new functionality
3. Update documentation as needed
4. Ensure all tests pass before submitting

## License

[Add your license information here]
