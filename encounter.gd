class_name Encounter
extends Resource

@export var encounter_id: String = ""
@export var encounter_name: String = ""
@export var description: String = ""
@export var difficulty_level: int = 1
@export var waves: Array[Wave] = []
@export var victory_conditions: Dictionary = {}
@export var defeat_conditions: Dictionary = {}
@export var rewards: EncounterRewards
@export var unlock_requirements: Dictionary = {}
@export var environment_modifiers: Array[Dictionary] = []
@export var background_scene: String = ""
@export var music_track: String = ""
@export var is_boss_encounter: bool = false
@export var is_optional: bool = false
@export var next_encounters: Array[String] = []
@export var tags: Array[String] = []

func _init(
	_id: String = "",
	_name: String = "",
	_description: String = "",
	_difficulty: int = 1
) -> void:
	encounter_id = _id
	encounter_name = _name
	description = _description
	difficulty_level = _difficulty
	rewards = EncounterRewards.new()

func add_wave(wave: Wave) -> void:
	waves.append(wave)

func get_wave(index: int) -> Wave:
	if index >= 0 and index < waves.size():
		return waves[index]
	return null

func get_wave_count() -> int:
	return waves.size()

func add_environment_modifier(modifier: Dictionary) -> void:
	environment_modifiers.append(modifier)

func is_unlocked(player_data: Dictionary) -> bool:
	if unlock_requirements.is_empty():
		return true
	
	for requirement_type in unlock_requirements:
		var requirement_value = unlock_requirements[requirement_type]
		
		match requirement_type:
			"completed_encounters":
				for encounter_id in requirement_value:
					if encounter_id not in player_data.get("completed_encounters", []):
						return false
			
			"player_level":
				if player_data.get("level", 0) < requirement_value:
					return false
			
			"items_owned":
				var inventory = player_data.get("inventory", [])
				for item in requirement_value:
					if item not in inventory:
						return false
			
			"achievement":
				var achievements = player_data.get("achievements", [])
				if requirement_value not in achievements:
					return false
			
			"custom":
				return false
	
	return true

func get_total_enemies() -> int:
	var total = 0
	for wave in waves:
		total += wave.get_total_enemy_count()
	return total

func calculate_estimated_duration() -> float:
	var duration = 0.0
	for wave in waves:
		duration += wave.spawn_delay
		duration += 60.0
		duration += 5.0
	return duration

func get_difficulty_stars() -> int:
	return clamp(difficulty_level, 1, 5)

func to_dict() -> Dictionary:
	var waves_data = []
	for wave in waves:
		waves_data.append(wave.to_dict())
	
	return {
		"encounter_id": encounter_id,
		"encounter_name": encounter_name,
		"description": description,
		"difficulty_level": difficulty_level,
		"waves": waves_data,
		"victory_conditions": victory_conditions,
		"defeat_conditions": defeat_conditions,
		"rewards": rewards.to_dict() if rewards else {},
		"unlock_requirements": unlock_requirements,
		"environment_modifiers": environment_modifiers,
		"background_scene": background_scene,
		"music_track": music_track,
		"is_boss_encounter": is_boss_encounter,
		"is_optional": is_optional,
		"next_encounters": next_encounters,
		"tags": tags
	}

static func from_dict(data: Dictionary) -> Encounter:
	var encounter = Encounter.new()
	
	if "encounter_id" in data:
		encounter.encounter_id = data.encounter_id
	if "encounter_name" in data:
		encounter.encounter_name = data.encounter_name
	if "description" in data:
		encounter.description = data.description
	if "difficulty_level" in data:
		encounter.difficulty_level = data.difficulty_level
	
	if "waves" in data:
		encounter.waves.clear()
		for wave_data in data.waves:
			encounter.waves.append(Wave.from_dict(wave_data))
	
	if "victory_conditions" in data:
		encounter.victory_conditions = data.victory_conditions
	if "defeat_conditions" in data:
		encounter.defeat_conditions = data.defeat_conditions
	
	if "rewards" in data:
		encounter.rewards = EncounterRewards.from_dict(data.rewards)
	
	if "unlock_requirements" in data:
		encounter.unlock_requirements = data.unlock_requirements
	if "environment_modifiers" in data:
		encounter.environment_modifiers = data.environment_modifiers
	if "background_scene" in data:
		encounter.background_scene = data.background_scene
	if "music_track" in data:
		encounter.music_track = data.music_track
	if "is_boss_encounter" in data:
		encounter.is_boss_encounter = data.is_boss_encounter
	if "is_optional" in data:
		encounter.is_optional = data.is_optional
	if "next_encounters" in data:
		var next_array: Array[String] = []
		for enc in data.next_encounters:
			next_array.append(str(enc))
		encounter.next_encounters = next_array
	if "tags" in data:
		var tags_array: Array[String] = []
		for tag in data.tags:
			tags_array.append(str(tag))
		encounter.tags = tags_array
	
	return encounter