class_name BattleUnit
extends Node2D

const StatProjector = preload("res://src/skills/stat_projector.gd")

signal unit_died
signal stat_changed(stat_name: String, new_value: float)
signal status_applied(status: StatusEffect)
signal status_removed(status: StatusEffect)

@export var unit_name: String = "Unit"
@export var team: int = 1

var stats: Dictionary = {
    "health": 100.0,
    "max_health": 100.0,
    "attack": 10.0,
    "defense": 5.0,
    "speed": 5.0,
    "initiative": 0.0,
    "attacks_taken": 0,
    "damage_taken": 0.0
}

var stat_projectors: Dictionary = {}
var skills: Array[BattleSkill] = []
var status_effects: Array[StatusEffect] = []
var equipment: Dictionary = {}
var locked_resources: Dictionary = {}  # Track reserved resources for pending skill casts

func _init() -> void:
    # Initialize stat projectors in _init so they're available before _ready
    for stat_name in stats.keys():
        stat_projectors[stat_name] = StatProjector.new()

func _ready() -> void:
    # Initialize any missing stat projectors (for dynamically added stats like mana)
    for stat_name in stats.keys():
        _ensure_stat_projector(stat_name)
    
    # Connect signals after node is in tree
    for stat_name in stats.keys():
        stat_projectors[stat_name].connect("stat_calculation_changed", _on_stat_calculation_changed.bind(stat_name))
    
    recalculate_stats()

func _on_stat_calculation_changed(payload: Dictionary, stat_name: String) -> void:
    stat_changed.emit(stat_name, get_projected_stat(stat_name))

func get_projected_stat(stat_name) -> float:
    var key_name: String = String(stat_name)
    if not _ensure_stat_projector(key_name):
        push_error("Unknown stat: " + stat_name)
        return 0.0
    var raw_value = stats.get(key_name, stats.get(StringName(key_name), 0.0))
    return stat_projectors[key_name].calculate_stat(raw_value)

func capture_battle_state() -> Dictionary:
    var base_stats: Dictionary = {}
    var projected_stats: Dictionary = {}
    var modifier_state: Dictionary = {}

    for stat_key in stats.keys():
        var stat_name: String = String(stat_key)
        base_stats[stat_name] = stats[stat_key]
        projected_stats[stat_name] = get_projected_stat(stat_name)
        modifier_state[stat_name] = _serialize_stat_modifiers(stat_name)

    var equipment_slots: Array = equipment.keys()
    var locked_copy: Dictionary = locked_resources.duplicate(true)

    return {
        "unit_id": name,
        "unit_name": unit_name,
        "team": team,
        "base_stats": base_stats,
        "projected_stats": projected_stats,
        "modifiers": modifier_state,
        "status_effects": get_status_list(),
        "equipment": equipment_slots,
        "locked_resources": locked_copy
    }

func _serialize_stat_modifiers(stat_name: String) -> Array[Dictionary]:
    var key_name: String = String(stat_name)
    if not _ensure_stat_projector(key_name):
        return []

    var serialized: Array[Dictionary] = []
    for mod in stat_projectors[key_name].list_modifiers():
        if not mod is StatProjector.StatModifier:
            continue

        serialized.append({
            "id": mod.id,
            "op": _modifier_op_to_string(mod.op),
            "value": mod.value,
            "priority": mod.priority,
            "applies_to": mod.applies_to.duplicate(true),
            "expires_at_unix": mod.expires_at_unix
        })

    return serialized

func _modifier_op_to_string(op: int) -> String:
    match op:
        StatProjector.ModifierOp.ADD:
            return "ADD"
        StatProjector.ModifierOp.MUL:
            return "MUL"
        StatProjector.ModifierOp.SET:
            return "SET"
        _:
            return "UNKNOWN"

func _ensure_stat_projector(stat_name) -> StatProjector:
    var key_name: String = String(stat_name)
    if stat_projectors.has(key_name):
        return stat_projectors[key_name]

    var key_name_sn = StringName(key_name)

    if not stats.has(key_name) and not stats.has(key_name_sn):
        return null

    var projector: StatProjector = StatProjector.new()
    stat_projectors[key_name] = projector
    if is_inside_tree():
        projector.connect("stat_calculation_changed", _on_stat_calculation_changed.bind(key_name))
    return projector

func take_damage(amount: float) -> void:
    var actual_damage = amount
    var defense = get_projected_stat("defense")
    actual_damage = max(1.0, actual_damage - defense)
    
    var current_health: float = stats.get("health", 0.0)
    current_health -= actual_damage
    stats["health"] = current_health

    var attacks_taken: int = stats.get("attacks_taken", 0)
    attacks_taken += 1
    stats["attacks_taken"] = attacks_taken

    var damage_taken: float = stats.get("damage_taken", 0.0)
    damage_taken += actual_damage
    stats["damage_taken"] = damage_taken
    
    if current_health <= 0:
        stats["health"] = 0.0
        unit_died.emit()
    
    stat_changed.emit("health", stats.get("health", 0.0))
    stat_changed.emit("attacks_taken", stats.get("attacks_taken", 0))
    stat_changed.emit("damage_taken", stats.get("damage_taken", 0.0))

func heal(amount: float) -> void:
    var max_health = get_projected_stat("max_health")
    var new_health = min(stats.get("health", 0.0) + amount, max_health)
    stats["health"] = new_health
    stat_changed.emit("health", new_health)

func add_status_effect(status: StatusEffect) -> void:
    if status_effects.has(status):
        return
    
    status_effects.append(status)
    status.apply_to(self)
    status_applied.emit(status)

func remove_status_effect(status: StatusEffect) -> void:
    if not status_effects.has(status):
        return
    
    status_effects.erase(status)
    status.remove_from(self)
    status_removed.emit(status)

func get_status_list() -> Array[String]:
    var result: Array[String] = []
    for status in status_effects:
        result.append(status.id)
    return result

func clear_status_effects() -> void:
    for status in status_effects.duplicate():
        remove_status_effect(status)
    status_effects.clear()

func add_skill(skill: BattleSkill) -> void:
    if not skills.has(skill):
        skills.append(skill)

func equip_item(slot: String, item: Equipment) -> void:
    if equipment.has(slot):
        var old_item = equipment[slot]
        old_item.unequip_from(self)
    
    equipment[slot] = item
    item.equip_to(self)

func unequip_item(slot: String) -> void:
    if equipment.has(slot):
        var item = equipment[slot]
        item.unequip_from(self)
        equipment.erase(slot)

func recalculate_stats() -> void:
    for stat_name in stats.keys():
        var projected = get_projected_stat(stat_name)
        stat_changed.emit(stat_name, projected)

func get_health_percentage() -> float:
    var max_health = get_projected_stat("max_health")
    if max_health <= 0:
        return 0.0
    return stats.health / max_health

func has_status(status_name: String) -> bool:
    for status in status_effects:
        if status.id == status_name:
            return true
    return false

func has_tag(tag: String) -> bool:
    # Check unit metadata for tags
    if has_meta("tags"):
        var unit_tags = get_meta("tags")
        if unit_tags is Array and unit_tags.has(tag):
            return true
    return false

func is_alive() -> bool:
    return stats.health > 0

func reset_initiative() -> void:
    stats.initiative = 0.0

func roll_initiative() -> float:
    var speed = get_projected_stat("speed")
    stats.initiative = speed + randf_range(0, 2)
    return stats.initiative

func lock_resource(resource_type: String, amount: float) -> void:
    if not locked_resources.has(resource_type):
        locked_resources[resource_type] = 0.0
    locked_resources[resource_type] += amount

func unlock_resource(resource_type: String, amount: float) -> void:
    if not locked_resources.has(resource_type):
        return
    locked_resources[resource_type] = max(0.0, locked_resources[resource_type] - amount)
    if locked_resources[resource_type] <= 0:
        locked_resources.erase(resource_type)

func get_locked_resource(resource_type: String) -> float:
    return locked_resources.get(resource_type, 0.0)

func get_available_resource(resource_type: String) -> float:
    var total = stats.get(resource_type, 0.0)
    var locked = get_locked_resource(resource_type)
    return total - locked

func clear_locked_resources() -> void:
    locked_resources.clear()

func get_turn_order() -> int:
    return floori(stats.initiative)
