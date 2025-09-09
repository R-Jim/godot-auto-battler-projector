class_name BattleUnit
extends Node2D

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
	"initiative": 0.0
}

var projectors: Dictionary = {}
var skills: Array[BattleSkill] = []
var status_effects: Array[StatusEffect] = []
var equipment: Dictionary = {}

func _ready() -> void:
	for stat_name in stats.keys():
		projectors[stat_name] = PropertyProjector.new()
		projectors[stat_name].connect("projection_changed", _on_projection_changed.bind(stat_name))
	
	recalculate_stats()

func _on_projection_changed(payload: Dictionary, stat_name: String) -> void:
	stat_changed.emit(stat_name, get_projected_stat(stat_name))

func get_projected_stat(stat_name: String) -> float:
	if not projectors.has(stat_name):
		push_error("Unknown stat: " + stat_name)
		return 0.0
	return projectors[stat_name].get_projected_value(stats.get(stat_name, 0.0))

func take_damage(amount: float) -> void:
	var actual_damage = amount
	var defense = get_projected_stat("defense")
	actual_damage = max(1.0, actual_damage - defense)
	
	stats.health -= actual_damage
	if stats.health <= 0:
		stats.health = 0
		unit_died.emit()
	
	stat_changed.emit("health", stats.health)

func heal(amount: float) -> void:
	var max_health = get_projected_stat("max_health")
	stats.health = min(stats.health + amount, max_health)
	stat_changed.emit("health", stats.health)

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

func is_alive() -> bool:
	return stats.health > 0

func reset_initiative() -> void:
	stats.initiative = 0.0

func roll_initiative() -> float:
	var speed = get_projected_stat("speed")
	stats.initiative = speed + randf_range(0, 2)
	return stats.initiative