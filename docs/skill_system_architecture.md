# Skill System Architecture

This document captures the data-driven approach used by the auto-battler's skill and status effect pipeline. It consolidates the rationale that previously lived in an earlier `src/skills/skill.gd` design note into a maintainable reference for designers and engineers.

## Goals

- Centralize conditional combat logic in JSON so that designers can iterate without touching GDScript.
- Keep skills declarative: they expose base properties and delegate contextual adjustments elsewhere.
- Reuse the `StatProjector` modifier pipeline for every calculation to ensure consistent stacking, priority ordering, and caching.

## Core Components

- **StatProjector** (`src/skills/stat_projector.gd`): The mathematical engine. It accepts a base value and applies ordered `StatModifier` instances to produce results.
- **BattleRuleProcessor** (`src/battle/battle_rule_processor.gd`): Reads `data/battle_rules.json`, evaluates rule conditions against runtime context, and creates the `StatModifier` objects that feed the projector.
- **Skills & Status Effects**: Lightweight scripts that gather context, request modifiers from the processor, and pipe them into temporary or persistent projectors. They no longer embed bespoke `if` statements for special cases.

## Rule Authoring Workflow

1. Designers add or update entries in `data/battle_rules.json` (validate against `data/battle_rules.schema.json`).
2. Each rule defines:
   - `conditions`: Logical tests against context (caster, target, skill metadata, encounter state, etc.).
   - `modifiers`: Serialized `StatProjector.StatModifier` definitions (`id`, `op`, `value`, optional `priority`, `applies_to`, `duration`/`expires_at`).
3. When a skill or status effect executes, it builds a context dictionary and calls `BattleRuleProcessor.get_modifiers_for_context(context)`.
4. Returned modifiers are added to the relevant projector(s); the final value is retrieved via `calculate_stat()`.

Because rules are data-driven, introducing a new interaction such as “bloodied characters deal more fire damage to frozen enemies” only requires updating the JSON—no GDScript changes.

## Execution Flow Example

```gdscript
var calculation_projector := caster.damage_projector.clone()

var context := {
    "caster_health_percentage": caster.get_health_percentage(),
    "target_status": target.get_status(),
    "skill_damage_type": damage_type
}

for mod in rule_processor.get_modifiers_for_context(context):
    calculation_projector.add_modifier(mod)

for defense_mod in target.defense_projector.list_modifiers():
    calculation_projector.add_modifier(defense_mod)

var final_damage := calculation_projector.calculate_stat(base_damage)
target.take_damage(final_damage)
```

The skill script does not need to know **why** the final value changed; that logic is encapsulated in the rule set and carried through the shared modifier pipeline.

## Design Guidelines

- **Fail fast**: Enforce schema validation before shipping new rule data to avoid runtime surprises.
- **Keep modifiers atomic**: Each rule should describe a single conceptual adjustment. Compose effects by emitting multiple modifiers rather than overloading IDs.
- **Leverage priorities**: `StatProjector` sorts by priority (desc) then insertion order. Assign priorities deliberately when mixing additive and multiplicative effects.
- **Reuse context keys**: Align `conditions.property` values with keys provided by callers (skills, statuses, encounters) to keep the rule set predictable.

## Migration Notes

- The prose that previously lived in `src/skills/skill.gd` has been moved here; the stub script has been removed in favor of this canonical reference.
- Update documentation here whenever the skill pipeline gains new concepts (e.g., additional context keys, new modifier operations).
