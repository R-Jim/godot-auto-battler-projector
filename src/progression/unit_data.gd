class_name UnitData
extends Resource

signal level_up(new_level: int)
signal experience_gained(amount: int)

@export var unit_id: String = ""
@export var custom_name: String = ""
@export var template_id: String = ""
@export var unit_level: int = 1
@export var current_experience: int = 0
@export var equipped_items: Dictionary = {
	"weapon": "",
	"armor": "",
	"accessory": ""
}
@export var skill_points: int = 0
@export var unlocked_skills: Array[String] = []
@export var skill_levels: Dictionary = {}
@export var total_battles: int = 0
@export var total_kills: int = 0

const MAX_UNIT_LEVEL = 10
const EXPERIENCE_PER_LEVEL = [
	0,     # Level 1
	100,   # Level 2
	250,   # Level 3
	450,   # Level 4
	700,   # Level 5
	1000,  # Level 6
	1400,  # Level 7
	1900,  # Level 8
	2500,  # Level 9
	3200   # Level 10
]

func _init(_unit_id: String = "", _template_id: String = "") -> void:
	unit_id = _unit_id
	template_id = _template_id

func get_display_name() -> String:
	if custom_name != "":
		return custom_name
	return unit_id

func get_experience_for_next_level() -> int:
	if unit_level >= MAX_UNIT_LEVEL:
		return 0
	return EXPERIENCE_PER_LEVEL[unit_level]

func get_total_experience_for_level(level: int) -> int:
	if level <= 1:
		return 0
	if level > MAX_UNIT_LEVEL:
		level = MAX_UNIT_LEVEL
	
	var total = 0
	for i in range(1, level):
		total += EXPERIENCE_PER_LEVEL[i]
	return total

func add_experience(amount: int) -> void:
	if unit_level >= MAX_UNIT_LEVEL:
		return
	
	current_experience += amount
	experience_gained.emit(amount)
	
	while unit_level < MAX_UNIT_LEVEL and current_experience >= get_experience_for_next_level():
		_level_up()

func _level_up() -> void:
	if unit_level >= MAX_UNIT_LEVEL:
		return
	
	current_experience -= get_experience_for_next_level()
	unit_level += 1
	skill_points += 1
	
	level_up.emit(unit_level)

func equip_item(slot: String, item_id: String) -> void:
	if equipped_items.has(slot):
		equipped_items[slot] = item_id

func unequip_item(slot: String) -> void:
	if equipped_items.has(slot):
		equipped_items[slot] = ""

func get_equipped_item(slot: String) -> String:
	return equipped_items.get(slot, "")

func unlock_skill(skill_id: String) -> void:
	if skill_id not in unlocked_skills:
		unlocked_skills.append(skill_id)
		skill_levels[skill_id] = 1

func upgrade_skill(skill_id: String) -> bool:
	if skill_id in unlocked_skills and skill_points > 0:
		var current_level = skill_levels.get(skill_id, 1)
		if current_level < 5:
			skill_levels[skill_id] = current_level + 1
			skill_points -= 1
			return true
	return false

func get_skill_level(skill_id: String) -> int:
	return skill_levels.get(skill_id, 0)

func get_stat_multiplier() -> float:
	return 1.0 + (unit_level - 1) * 0.1

func record_battle() -> void:
	total_battles += 1

func record_kill() -> void:
	total_kills += 1

func to_dict() -> Dictionary:
	return {
		"unit_id": unit_id,
		"custom_name": custom_name,
		"template_id": template_id,
		"unit_level": unit_level,
		"current_experience": current_experience,
		"equipped_items": equipped_items,
		"skill_points": skill_points,
		"unlocked_skills": unlocked_skills,
		"skill_levels": skill_levels,
		"total_battles": total_battles,
		"total_kills": total_kills
	}

static func from_dict(data: Dictionary) -> UnitData:
	var unit_data = UnitData.new()
	
	unit_data.unit_id = data.get("unit_id", "")
	unit_data.custom_name = data.get("custom_name", "")
	unit_data.template_id = data.get("template_id", "")
	unit_data.unit_level = data.get("unit_level", 1)
	unit_data.current_experience = data.get("current_experience", 0)
	unit_data.equipped_items = data.get("equipped_items", unit_data.equipped_items)
	unit_data.skill_points = data.get("skill_points", 0)
	
	var skills = data.get("unlocked_skills", [])
	unit_data.unlocked_skills.clear()
	for skill in skills:
		unit_data.unlocked_skills.append(skill)
	
	unit_data.skill_levels = data.get("skill_levels", {})
	unit_data.total_battles = data.get("total_battles", 0)
	unit_data.total_kills = data.get("total_kills", 0)
	
	return unit_data