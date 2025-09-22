class_name EncounterRewards
extends Resource

@export var experience: int = 0
@export var gold: int = 0
@export var items: Array[String] = []
@export var unlock_units: Array[String] = []
@export var unlock_skills: Array[String] = []
@export var unlock_encounters: Array[String] = []
@export var achievement_progress: Dictionary = {}
@export var performance_bonuses: Dictionary = {}

func _init(
	_experience: int = 0,
	_gold: int = 0,
	_items: Array = [],
	_unlock_units: Array = [],
	_unlock_skills: Array = [],
	_unlock_encounters: Array = []
) -> void:
	experience = _experience
	gold = _gold
	
	# Convert to typed arrays
	var items_array: Array[String] = []
	for item in _items:
		items_array.append(str(item))
	items = items_array
	
	var units_array: Array[String] = []
	for unit in _unlock_units:
		units_array.append(str(unit))
	unlock_units = units_array
	
	var skills_array: Array[String] = []
	for skill in _unlock_skills:
		skills_array.append(str(skill))
	unlock_skills = skills_array
	
	var encounters_array: Array[String] = []
	for enc in _unlock_encounters:
		encounters_array.append(str(enc))
	unlock_encounters = encounters_array

func apply_performance_multiplier(multiplier: float) -> void:
	experience = int(experience * multiplier)
	gold = int(gold * multiplier)

func merge_with(other: EncounterRewards) -> void:
	experience += other.experience
	gold += other.gold
	items.append_array(other.items)
	unlock_units.append_array(other.unlock_units)
	unlock_skills.append_array(other.unlock_skills)
	unlock_encounters.append_array(other.unlock_encounters)
	
	for key in other.achievement_progress:
		if key in achievement_progress:
			achievement_progress[key] += other.achievement_progress[key]
		else:
			achievement_progress[key] = other.achievement_progress[key]

func get_performance_bonus(bonus_type: String) -> EncounterRewards:
	if bonus_type in performance_bonuses:
		var bonus_data = performance_bonuses[bonus_type]
		var bonus = EncounterRewards.new()
		
		if "experience" in bonus_data:
			bonus.experience = bonus_data.experience
		if "gold" in bonus_data:
			bonus.gold = bonus_data.gold
		if "items" in bonus_data:
			var items_array: Array[String] = []
			for item in bonus_data.items:
				items_array.append(str(item))
			bonus.items = items_array
		
		return bonus
	
	return null

func to_dict() -> Dictionary:
	return {
		"experience": experience,
		"gold": gold,
		"items": items,
		"unlock_units": unlock_units,
		"unlock_skills": unlock_skills,
		"unlock_encounters": unlock_encounters,
		"achievement_progress": achievement_progress,
		"performance_bonuses": performance_bonuses
	}

static func from_dict(data: Dictionary) -> EncounterRewards:
	var rewards = EncounterRewards.new()
	
	if "experience" in data:
		rewards.experience = data.experience
	if "gold" in data:
		rewards.gold = data.gold
	if "items" in data:
		var items_array: Array[String] = []
		for item in data.items:
			items_array.append(str(item))
		rewards.items = items_array
	if "unlock_units" in data:
		var units_array: Array[String] = []
		for unit in data.unlock_units:
			units_array.append(str(unit))
		rewards.unlock_units = units_array
	if "unlock_skills" in data:
		var skills_array: Array[String] = []
		for skill in data.unlock_skills:
			skills_array.append(str(skill))
		rewards.unlock_skills = skills_array
	if "unlock_encounters" in data:
		var encounters_array: Array[String] = []
		for encounter in data.unlock_encounters:
			encounters_array.append(str(encounter))
		rewards.unlock_encounters = encounters_array
	if "achievement_progress" in data:
		rewards.achievement_progress = data.achievement_progress
	if "performance_bonuses" in data:
		rewards.performance_bonuses = data.performance_bonuses
	
	return rewards