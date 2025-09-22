class_name StatusEffect
extends RefCounted

const BattleRuleProcessorScript = preload("res://src/battle/battle_rule_processor.gd")

@export var id: String = ""
@export var effect_name: String = "Status Effect"
@export var description: String = ""
@export var duration: float = 0.0
@export var is_debuff: bool = false
@export var stack_type: String = "replace"
@export var max_stacks: int = 1

var expires_at: float = 0.0
var stacks: int = 1
var applied_modifiers: Array[Dictionary] = []

func _init(_id: String = "", _name: String = "", _desc: String = "", _duration: float = 0.0) -> void:
    id = _id
    effect_name = _name
    description = _desc
    duration = _duration
    
    if duration > 0:
        expires_at = Time.get_unix_time_from_system() + duration

func apply_to(unit: BattleUnit) -> void:
    var rule_processor = BattleRuleProcessorScript.test_instance

    if not rule_processor and unit.is_inside_tree():
        rule_processor = unit.get_node_or_null("/root/RuleProcessor")
        if not rule_processor and unit.get_tree():
            for child in unit.get_tree().root.get_children():
                if child.name == "RuleProcessor":
                    rule_processor = child
                    break

    if not rule_processor:
        # Apply minimal bookkeeping so unit still tracks the status
        unit.recalculate_stats()
        push_warning("RuleProcessor not found for status effect application; skipping stat modifiers")
        return
    
    var context = {
        "status_id": id,
        "status_applied": true,
        "target_health_percentage": unit.get_health_percentage(),
        "target_team": unit.team,
        "target_status": unit.get_status_list()
    }
    
    var modifiers = rule_processor.get_modifiers_for_context(context)
    
    for mod in modifiers:
        if not mod is StatProjector.StatModifier:
            push_error("Invalid modifier type from rule processor: " + str(typeof(mod)))
            continue
            
        if mod.expires_at_unix < 0 and duration > 0:
            mod.expires_at_unix = expires_at
        
        var applies_to = mod.applies_to
        if applies_to.is_empty():
            applies_to = ["attack"]
        
        for stat_name in applies_to:
            if unit.stat_projectors.has(stat_name):
                unit.stat_projectors[stat_name].add_modifier(mod)
                if not mod is StatProjector.StatModifier:
                    push_error("Trying to store non-Modifier in applied_modifiers: " + str(typeof(mod)))
                applied_modifiers.append({"modifier": mod, "stat": stat_name})
    
    unit.recalculate_stats()

func remove_from(unit: BattleUnit) -> void:
    for mod_data in applied_modifiers:
        if not mod_data.has("stat") or not mod_data.has("modifier"):
            push_error("Invalid mod_data structure: " + str(mod_data))
            continue
            
        var stat_name = mod_data["stat"]
        var modifier = mod_data["modifier"]
        
        # Skip if modifier was serialized as a dictionary or is otherwise invalid
        if not modifier is StatProjector.StatModifier:
            push_warning("Skipping non-Modifier object in applied_modifiers: " + str(typeof(modifier)))
            continue
            
        if unit.stat_projectors.has(stat_name):
            unit.stat_projectors[stat_name].remove_modifier(modifier)
    
    applied_modifiers.clear()
    unit.recalculate_stats()

func is_expired(now: float) -> bool:
    return expires_at > 0 and now >= expires_at

func on_turn_start(unit: BattleUnit) -> void:
    var rule_processor = BattleRuleProcessorScript.test_instance
    if not rule_processor and unit.is_inside_tree():
        rule_processor = unit.get_node_or_null("/root/RuleProcessor")
    if not rule_processor:
        return
    
    var context = {
        "status_id": id,
        "status_turn_trigger": true,
        "target_health_percentage": unit.get_health_percentage(),
        "target_team": unit.team
    }
    
    var turn_effects = rule_processor.get_modifiers_for_context(context)
    
    for mod in turn_effects:
        if mod.id.ends_with("_damage"):
            unit.take_damage(mod.value)
        elif mod.id.ends_with("_heal"):
            unit.heal(mod.value)

func refresh(new_duration: float = 0.0) -> void:
    if new_duration > 0:
        duration = new_duration
    
    if duration > 0:
        expires_at = Time.get_unix_time_from_system() + duration

func add_stack() -> void:
    if stacks < max_stacks:
        stacks += 1

func can_stack_with(other: StatusEffect) -> bool:
    return id == other.id and stacks < max_stacks

func clone() -> StatusEffect:
    var new_effect = StatusEffect.new(id, effect_name, description, duration)
    new_effect.is_debuff = is_debuff
    new_effect.stack_type = stack_type
    new_effect.max_stacks = max_stacks
    return new_effect
