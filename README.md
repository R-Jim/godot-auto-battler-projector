# Auto Battler - Property Projection System

A sophisticated auto battler implementation for Godot 4 that uses a data-driven property projection system and rule-based mechanics. This system separates game logic from code, allowing designers to modify game behavior through JSON configuration without touching the codebase.

## Table of Contents

1. [Overview](#overview)
2. [Core Systems](#core-systems)
3. [Property Projection System](#property-projection-system)
4. [Battle Rule Processing](#battle-rule-processing)
5. [Combat Flow](#combat-flow)
6. [Unit System](#unit-system)
7. [Skills & Abilities](#skills--abilities)
8. [Status Effects](#status-effects)
9. [Equipment System](#equipment-system)
10. [AI System](#ai-system)
11. [Encounter System](#encounter-system)
12. [Player Progression System](#player-progression-system)
13. [Configuration Guide](#configuration-guide)
14. [Examples](#examples)

## Overview

This auto battler uses a unique architecture that combines:
- **Property Projectors**: Mathematical engine for stat calculations with modifiers
- **Rule-Based Logic**: All game mechanics defined in JSON, evaluated at runtime
- **Data-Driven Design**: Skills, items, and effects defined as data, not code

### Key Benefits

- **Designer-Friendly**: Modify game balance without programming
- **Highly Extensible**: Add new mechanics by editing JSON rules
- **Clean Separation**: Game logic isolated from implementation
- **Predictable**: Deterministic modifier application with clear priority

## Core Systems

### 1. Property Projection System (`property_projectors_v9.gd`)

The heart of the stat calculation system. Every stat (health, attack, defense, etc.) has its own PropertyProjector that manages modifiers.

```gdscript
# Example: Unit with base attack of 10
var attack_projector = PropertyProjector.new()

# Add a sword (+5 attack)
attack_projector.add_additive("sword", 5.0, priority=10)

# Add a strength buff (+20%)
attack_projector.add_multiplier("strength_buff", 1.2, priority=20)

# Final attack = (10 + 5) * 1.2 = 18
var final_attack = attack_projector.get_projected_value(10.0)
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

### 2. Battle Rule Processing (`battle_rule_processor.gd`)

Evaluates conditions and generates modifiers based on the current game context. All combat mechanics are defined in `battle_rules.json`.

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

## Combat Flow

### Turn Order System

1. **Round Start**
   - All alive units roll initiative: `speed + random(0-2)`
   - Units sorted by initiative (highest first)

2. **Turn Processing**
   - Process status effects
   - AI chooses action
   - Execute skill/attack
   - Apply damage/effects

3. **Battle End**
   - When one team has no alive units
   - Or maximum rounds reached

### Damage Calculation Pipeline

1. **Context Building**
   ```gdscript
   context = {
     "skill_name": "Fireball",
     "skill_damage_type": "fire",
     "caster_health_percentage": 0.8,
     "target_status": ["frozen"],
     "caster_team": 1,
     "target_team": 2
   }
   ```

2. **Rule Evaluation**
   - BattleRuleProcessor checks all rules
   - Matching rules generate modifiers

3. **Modifier Application**
   - Create temporary PropertyProjector
   - Add caster's permanent modifiers
   - Add contextual modifiers from rules
   - Calculate final damage

4. **Defense Application**
   - Target's defense reduces damage
   - Minimum 1 damage always dealt

## Unit System

### BattleUnit Structure

```gdscript
var stats = {
    "health": 100.0,
    "max_health": 100.0,
    "attack": 10.0,
    "defense": 5.0,
    "speed": 5.0,
    "initiative": 0.0,
    "mana": 50.0,      # Optional resource
    "max_mana": 50.0
}
```

Each stat has its own PropertyProjector for independent modifier tracking.

### Unit Lifecycle

1. **Creation**: Initialize base stats and projectors
2. **Equipment**: Apply equipment modifiers
3. **Battle Start**: Reset initiative, apply pre-battle effects
4. **During Battle**: Apply/remove temporary modifiers
5. **Death**: Emit signals, remove from turn queue

## Skills & Abilities

### Skill Properties

```gdscript
class_name BattleSkill

@export var skill_name: String = "Skill"
@export var base_damage: float = 10.0
@export var damage_type: String = "physical"
@export var target_type: String = "single_enemy"
@export var cooldown: float = 0.0
@export var resource_cost: float = 0.0
@export var resource_type: String = "mana"
```

### Target Types
- **single_enemy**: One enemy unit
- **all_enemies**: All enemy units
- **single_ally**: One allied unit
- **all_allies**: All allied units
- **self**: Caster only
- **random_enemy**: Random enemy
- **lowest_health_enemy**: Enemy with lowest HP
- **lowest_health_ally**: Ally with lowest HP %

### Skill Execution Flow

1. Check cooldown and resource availability
2. Build context with caster/target info
3. Get modifiers from BattleRuleProcessor
4. Create damage projector with all modifiers
5. Calculate final damage
6. Apply to target(s)
7. Deduct resources and set cooldown

## Status Effects

### Status Effect Properties

```gdscript
@export var id: String = "poison"
@export var effect_name: String = "Poison"
@export var duration: float = 5.0
@export var is_debuff: bool = true
@export var stack_type: String = "replace"
@export var max_stacks: int = 1
```

### Status Effect Types (Configured in Rules)

1. **Stat Modifiers** (Applied on gain)
   ```json
   {
     "id": "frozen_status_effect",
     "conditions": {
       "and": [
         { "property": "status_id", "op": "eq", "value": "frozen" },
         { "property": "status_applied", "op": "eq", "value": true }
       ]
     },
     "modifiers": [
       { "id": "frozen_speed", "op": "MUL", "value": 0.5, "applies_to": ["speed"] }
     ]
   }
   ```

2. **Turn Effects** (Triggered each turn)
   ```json
   {
     "id": "poison_status_effect",
     "conditions": {
       "and": [
         { "property": "status_id", "op": "eq", "value": "poison" },
         { "property": "status_turn_trigger", "op": "eq", "value": true }
       ]
     },
     "modifiers": [
       { "id": "poison_damage", "op": "ADD", "value": 5.0 }
     ]
   }
   ```

## Equipment System

### Equipment Structure

```gdscript
var sword = Equipment.create_weapon("Iron Sword", attack_bonus=5.0)
var armor = Equipment.create_armor("Iron Armor", defense_bonus=3.0)
var ring = Equipment.create_accessory("Speed Ring", {"speed": 2.0})
```

### Equipment Slots
- **weapon**: Primary weapon
- **armor**: Body armor
- **accessory**: Rings, amulets, etc.

Equipment modifiers are permanent while equipped and stack with all other modifiers.

## AI System

### AI Types

1. **AGGRESSIVE**
   - High skill usage (80%)
   - Targets lowest health (80%)
   - Low heal threshold (30%)

2. **DEFENSIVE**
   - Moderate skill usage (60%)
   - Targets highest threat
   - High heal threshold (70%)

3. **BALANCED**
   - Standard parameters
   - Mixed targeting

4. **SUPPORT**
   - Prioritizes healing/buffs
   - Targets allies in need

5. **RANDOM**
   - Unpredictable behavior

### AI Decision Flow

1. Filter available targets
2. Get usable skills (not on cooldown)
3. Score each skill/target combination
4. Execute highest scoring action

### Scoring Factors
- Base damage
- Target count (AoE bonus)
- Heal priority (based on ally health)
- Synergies (e.g., fire vs frozen)

## Encounter System

### Overview

The encounter system provides wave-based combat scenarios with progression, rewards, and dynamic difficulty scaling.

### Key Components

1. **EncounterManager** (`encounter_manager.gd`)
   - Orchestrates encounter flow
   - Manages wave transitions
   - Tracks player progress and statistics
   - Distributes rewards

2. **Encounter** (`encounter.gd`)
   - Individual encounter configuration
   - Contains multiple waves of enemies
   - Defines victory/defeat conditions
   - Specifies rewards and unlockables

3. **Wave** (`wave.gd`)
   - Single combat wave within an encounter
   - Enemy composition and formations
   - Wave-specific modifiers and objectives
   - Victory conditions (eliminate all, survive time, etc.)

4. **UnitFactory** (`unit_factory.gd`)
   - Generates enemies from JSON templates
   - Applies level scaling and difficulty modifiers
   - Manages formations and positioning

5. **DifficultyScaler** (`difficulty_scaler.gd`)
   - Five difficulty modes: Easy, Normal, Hard, Nightmare, Adaptive
   - Dynamic scaling based on player performance
   - Progressive difficulty increase through encounters

### Wave Types
- **Standard**: Defeat all enemies
- **Boss**: Defeat boss unit(s)
- **Survival**: Survive for specified duration
- **Timed**: Complete within time limit
- **Endless**: Survive as long as possible
- **Objective**: Complete specific goals

### Rewards System
- **Immediate**: Gold, XP after each wave
- **Completion**: Major rewards for finishing encounter
- **Performance**: Bonuses for no deaths, speed completion
- **Unlockables**: New encounters, units, skills

### Data Configuration

Encounters are defined in `data/encounters.json`:
```json
{
  "encounter_id": "forest_ambush",
  "encounter_name": "Forest Ambush",
  "waves": [
    {
      "wave_type": "standard",
      "enemy_units": [
        {
          "template_id": "bandit_archer",
          "count": 2,
          "level": 1
        }
      ],
      "formation": "triangle"
    }
  ],
  "rewards": {
    "experience": 500,
    "gold": 200,
    "items": ["health_potion"]
  }
}
```

Enemy templates in `data/unit_templates.json`:
```json
{
  "id": "bandit_archer",
  "name": "Archer",
  "base_stats": {
    "health": 80,
    "attack": 15,
    "defense": 5,
    "speed": 7
  },
  "skills": ["arrow_shot"],
  "ai_type": "AGGRESSIVE"
}
```

### Usage Example
```gdscript
# Initialize encounter manager
var encounter_manager = EncounterManager.new()
encounter_manager.difficulty_mode = DifficultyScaler.DifficultyMode.NORMAL

# Start an encounter
var player_team = [warrior, mage, healer, archer]
encounter_manager.start_encounter("forest_ambush", player_team)

# Connect signals
encounter_manager.wave_started.connect(_on_wave_started)
encounter_manager.encounter_completed.connect(_on_encounter_completed)
```

### Testing
- Run `encounter_test.tscn` for basic encounter system testing
- Run `encounter_test_scene.tscn` for a full-featured encounter test interface with:
  - Encounter selection screen with details
  - Live battle visualization
  - Team status tracking
  - Battle log
  - Results screen with rewards
  - Session statistics

## Configuration Guide

### Adding a New Skill

1. Create the skill in code:
   ```gdscript
   var lightning = BattleSkill.new()
   lightning.skill_name = "Lightning Bolt"
   lightning.base_damage = 35.0
   lightning.damage_type = "lightning"
   lightning.target_type = "single_enemy"
   ```

2. Add rules for skill interactions:
   ```json
   {
     "id": "wet_lightning_bonus",
     "conditions": {
       "and": [
         { "property": "target_status", "op": "contains", "value": "wet" },
         { "property": "skill_damage_type", "op": "eq", "value": "lightning" }
       ]
     },
     "modifiers": [
       { "id": "wet_lightning", "op": "MUL", "value": 1.75, "priority": 60 }
     ]
   }
   ```

### Adding a New Status Effect

1. Define the status effect:
   ```gdscript
   var wet = StatusEffect.new("wet", "Wet", "Vulnerable to lightning", 3.0)
   ```

2. Add rules for the effect:
   ```json
   {
     "id": "wet_status_effect",
     "conditions": {
       "and": [
         { "property": "status_id", "op": "eq", "value": "wet" },
         { "property": "status_applied", "op": "eq", "value": true }
       ]
     },
     "modifiers": [
       { "id": "wet_fire_resist", "op": "MUL", "value": 0.5, "applies_to": ["fire_resistance"] }
     ]
   }
   ```

### Creating Synergies

Example: Combo system where certain skills gain bonuses
```json
{
  "id": "fire_into_oil",
  "conditions": {
    "and": [
      { "property": "target_status", "op": "contains", "value": "oiled" },
      { "property": "skill_damage_type", "op": "eq", "value": "fire" }
    ]
  },
  "modifiers": [
    { "id": "oil_explosion", "op": "MUL", "value": 2.5, "priority": 100 }
  ]
}
```

## Examples

### Example 1: Critical Strike System

```json
{
  "id": "critical_strike_chance",
  "conditions": {
    "property": "random_roll",
    "op": "lt",
    "value": "$caster_crit_chance"
  },
  "modifiers": [
    { "id": "critical_damage", "op": "MUL", "value": 2.0, "priority": 90 }
  ]
}
```

### Example 2: Execution Mechanic

```json
{
  "id": "execute_low_health",
  "conditions": {
    "and": [
      { "property": "skill_name", "op": "eq", "value": "execute" },
      { "property": "target_health_percentage", "op": "lt", "value": 0.2 }
    ]
  },
  "modifiers": [
    { "id": "execute_damage", "op": "MUL", "value": 999.0, "priority": 200 }
  ]
}
```

### Example 3: Damage Reduction

```json
{
  "id": "armor_damage_reduction",
  "conditions": {
    "property": "damage_type",
    "op": "eq",
    "value": "physical"
  },
  "modifiers": [
    {
      "id": "armor_reduction",
      "op": "MUL", 
      "value": "$target_armor_multiplier",
      "priority": 30
    }
  ]
}
```

## Best Practices

1. **Priority Guidelines**
   - 0-20: Base modifiers (equipment, permanent buffs)
   - 30-50: Conditional modifiers (status effects)
   - 60-80: Synergies and combos
   - 90-100: Critical effects
   - 150+: Override effects (immunity, special cases)

2. **Rule Organization**
   - Group related rules together
   - Use clear, descriptive IDs
   - Comment complex conditions
   - Test interactions thoroughly

3. **Performance Tips**
   - Limit active modifiers per unit
   - Use expiration times
   - Batch rule evaluations
   - Cache unchanged projections

## Extending the System

### Adding New Mechanics

1. **Define the context properties** in skill/effect execution
2. **Create rules** in battle_rules.json
3. **Apply modifiers** through the rule system
4. **Test interactions** with existing rules

### Custom Modifier Types

Extend the PropertyProjector to add new operations:
```gdscript
enum Op { ADD, MUL, SET, MAX, MIN }  # Add MAX/MIN

# In projection calculation:
match mod.op:
    Modifier.Op.MAX: value = max(value, mod.value)
    Modifier.Op.MIN: value = min(value, mod.value)
```

This system provides unlimited flexibility while maintaining clean, understandable code. Designers can create complex interactions without programming knowledge, and developers can extend the system without breaking existing content.

## Player Progression System

The game features a comprehensive progression system that tracks player advancement through encounters:

### Key Features
- **Player Leveling**: Experience-based progression with team size unlocks
- **Unit Progression**: Individual unit leveling, skills, and equipment  
- **Save/Load System**: Persistent progression across sessions
- **Reward Integration**: Automatic reward application from encounters
- **Visual Battle System**: Animated 2D battles with unit sprites, health bars, and effects

### Progression Components
- `player_data.gd` - Player profile, unlocks, and roster management
- `unit_data.gd` - Individual unit progression tracking
- `progression_manager.gd` - Central progression controller (AutoLoad singleton)
- `save_manager.gd` - Save/load functionality with JSON serialization
- `player_hud.gd/tscn` - UI for displaying player stats and progression

### Visual Battle System
Units are displayed as colored sprites with:
- Team-based coloring (Team 1: Cyan, Team 2: Orange)
- Health bars and status effect indicators
- Attack and skill animations
- Damage number popups
- Formation-based positioning

## Getting Started

### Requirements
- Godot Engine 4.4.1 or higher
- GUT (Godot Unit Test) framework v9.3.0 (included in addons/)

### Quick Start
1. Clone the repository
2. Open the project in Godot 4
3. Run `progression_test_scene.tscn` for full progression and visual battle system
4. Run `visual_battle_test.tscn` for visual battle testing
5. Run `sample_battle.tscn` for basic combat demo
6. Run `encounter_test.tscn` for encounter system demo
7. Run tests with `./run_tests.sh` or open `run_all_tests.tscn` in editor

### Test Scenes
- **progression_test_scene.tscn** - Full game loop with progression, encounters, and visual battles
- **visual_battle_test.tscn** - Dedicated visual battle testing with Camera2D setup
- **encounter_test_scene.tscn** - Encounter system testing with detailed UI
- **sample_battle.tscn** - Basic battle mechanics demonstration

### Project Structure
```
├── core/                     # Core battle system
│   ├── auto_battler.gd      # Main battle orchestrator (Node2D with visuals)
│   ├── battle_unit.gd       # Unit class with visual components
│   ├── battle_skill.gd      # Skill system
│   ├── battle_ai.gd         # AI decision making
│   └── unit_visual.gd       # Visual representation of units
├── progression/              # Player progression
│   ├── player_data.gd       # Player stats and unlocks
│   ├── unit_data.gd         # Unit progression
│   ├── progression_manager.gd # Progression controller
│   └── save_manager.gd      # Save/load system
├── encounters/               # Encounter system
│   ├── encounter_manager.gd # Encounter orchestrator
│   ├── encounter.gd         # Individual encounters
│   ├── wave.gd             # Wave management
│   └── unit_factory.gd      # Enemy generation
├── data/                     # JSON configuration files
│   ├── encounters.json      # Encounter definitions
│   ├── unit_templates.json  # Enemy and player unit templates
│   └── battle_rules.json    # Combat rules and modifiers
├── tests/                    # Unit and integration tests
├── addons/gut/              # Testing framework
└── scenes/                   # Demo and test scenes
```

## MCP (Model Context Protocol) Integration

This project includes MCP server integration, allowing AI assistants like Claude to interact with the Godot project through standardized tools. The MCP server provides tools for:

- Running tests and checking script errors
- Managing game data (encounters, unit templates)
- Running scenes and validating configurations
- Exploring project structure

See [MCP_SETUP.md](MCP_SETUP.md) for detailed setup instructions and available tools.
