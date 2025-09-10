class_name PlayerData
extends Resource

signal level_up(new_level: int)
signal experience_gained(amount: int)
signal gold_changed(new_amount: int)
signal unit_unlocked(unit_id: String)
signal encounter_completed(encounter_id: String)

@export var player_level: int = 1
@export var current_experience: int = 0
@export var gold: int = 0
@export var team_size_limit: int = 3
@export var unlocked_units: Array[String] = []
@export var completed_encounters: Array[String] = []
@export var unlocked_encounters: Array[String] = ["tutorial_battle"]
@export var unit_roster: Array[UnitData] = []
@export var inventory: Dictionary = {}
@export var achievements: Dictionary = {}
@export var statistics: Dictionary = {
	"battles_won": 0,
	"battles_lost": 0,
	"total_damage_dealt": 0,
	"total_damage_taken": 0,
	"units_lost": 0
}

const MAX_TEAM_SIZE = 6
const BASE_TEAM_SIZE = 3
const TEAM_SIZE_UNLOCK_LEVELS = [1, 10, 20, 30, 40, 50]

func _init() -> void:
	if unlocked_units.is_empty():
		unlocked_units = ["player_warrior", "player_archer", "player_healer"]

func get_experience_for_next_level() -> int:
	return player_level * player_level * 100

func get_total_experience_for_level(level: int) -> int:
	var total = 0
	for i in range(1, level):
		total += i * i * 100
	return total

func add_experience(amount: int) -> void:
	current_experience += amount
	experience_gained.emit(amount)
	
	while current_experience >= get_experience_for_next_level():
		_level_up()

func _level_up() -> void:
	current_experience -= get_experience_for_next_level()
	player_level += 1
	
	update_team_size_limit()
	
	level_up.emit(player_level)

func update_team_size_limit() -> void:
	var new_limit = BASE_TEAM_SIZE
	for i in range(TEAM_SIZE_UNLOCK_LEVELS.size()):
		if player_level >= TEAM_SIZE_UNLOCK_LEVELS[i]:
			new_limit = BASE_TEAM_SIZE + i
	
	team_size_limit = min(new_limit, MAX_TEAM_SIZE)

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
		return true
	return false

func unlock_unit(unit_id: String) -> void:
	if unit_id not in unlocked_units:
		unlocked_units.append(unit_id)
		unit_unlocked.emit(unit_id)

func complete_encounter(encounter_id: String) -> void:
	if encounter_id not in completed_encounters:
		completed_encounters.append(encounter_id)
		encounter_completed.emit(encounter_id)

func unlock_encounter(encounter_id: String) -> void:
	if encounter_id not in unlocked_encounters:
		unlocked_encounters.append(encounter_id)

func is_encounter_unlocked(encounter_id: String) -> bool:
	return encounter_id in unlocked_encounters

func can_play_encounter(encounter: Encounter) -> bool:
	if not is_encounter_unlocked(encounter.encounter_id):
		return false
	
	var requirements = encounter.unlock_requirements
	if requirements.is_empty():
		return true
	
	if requirements.has("completed_encounters"):
		for req_encounter in requirements.completed_encounters:
			if req_encounter not in completed_encounters:
				return false
	
	if requirements.has("player_level"):
		if player_level < requirements.player_level:
			return false
	
	return true

func get_unit_data(unit_id: String) -> UnitData:
	for unit_data in unit_roster:
		if unit_data.unit_id == unit_id:
			return unit_data
	return null

func add_unit_to_roster(unit_data: UnitData) -> void:
	if get_unit_data(unit_data.unit_id) == null:
		unit_roster.append(unit_data)

func update_statistics(stat: String, value: int) -> void:
	if statistics.has(stat):
		statistics[stat] += value

func add_item(item_id: String, quantity: int = 1) -> void:
	if inventory.has(item_id):
		inventory[item_id] += quantity
	else:
		inventory[item_id] = quantity

func use_item(item_id: String, quantity: int = 1) -> bool:
	if inventory.has(item_id) and inventory[item_id] >= quantity:
		inventory[item_id] -= quantity
		if inventory[item_id] <= 0:
			inventory.erase(item_id)
		return true
	return false

func update_achievement_progress(achievement_id: String, progress: int) -> void:
	if achievements.has(achievement_id):
		achievements[achievement_id] += progress
	else:
		achievements[achievement_id] = progress

func to_save_dict() -> Dictionary:
	var roster_data = []
	for unit_data in unit_roster:
		roster_data.append(unit_data.to_dict())
	
	return {
		"player_level": player_level,
		"current_experience": current_experience,
		"gold": gold,
		"team_size_limit": team_size_limit,
		"unlocked_units": unlocked_units,
		"completed_encounters": completed_encounters,
		"unlocked_encounters": unlocked_encounters,
		"unit_roster": roster_data,
		"inventory": inventory,
		"achievements": achievements,
		"statistics": statistics
	}

static func from_save_dict(data: Dictionary) -> PlayerData:
	var player_data = PlayerData.new()
	
	player_data.player_level = data.get("player_level", 1)
	player_data.current_experience = data.get("current_experience", 0)
	player_data.gold = data.get("gold", 0)
	player_data.team_size_limit = data.get("team_size_limit", 3)
	
	var unlocked = data.get("unlocked_units", [])
	player_data.unlocked_units.clear()
	for unit_id in unlocked:
		player_data.unlocked_units.append(unit_id)
	
	var completed = data.get("completed_encounters", [])
	player_data.completed_encounters.clear()
	for encounter_id in completed:
		player_data.completed_encounters.append(encounter_id)
	
	var available = data.get("unlocked_encounters", ["tutorial_battle"])
	player_data.unlocked_encounters.clear()
	for encounter_id in available:
		player_data.unlocked_encounters.append(encounter_id)
	
	var roster = data.get("unit_roster", [])
	player_data.unit_roster.clear()
	for unit_dict in roster:
		player_data.unit_roster.append(UnitData.from_dict(unit_dict))
	
	player_data.inventory = data.get("inventory", {})
	player_data.achievements = data.get("achievements", {})
	player_data.statistics = data.get("statistics", player_data.statistics)
	
	return player_data