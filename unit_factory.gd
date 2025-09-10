class_name UnitFactory
extends RefCounted

static var unit_templates: Dictionary = {}
static var templates_loaded: bool = false

static func load_templates(path: String = "res://data/unit_templates.json") -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to load unit templates from: " + path)
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		push_error("Failed to parse unit templates JSON: " + json.get_error_message())
		return
	
	var data = json.data
	if "unit_templates" in data:
		for template in data.unit_templates:
			if "id" in template:
				unit_templates[template.id] = template
		templates_loaded = true
		print("Loaded ", unit_templates.size(), " unit templates")

static func create_from_template(template_id: String, level: int, team: int, difficulty_modifiers: Dictionary = {}) -> BattleUnit:
	if not templates_loaded:
		load_templates()
	
	if template_id not in unit_templates:
		push_error("Unit template not found: " + template_id)
		return _create_default_unit(team)
	
	var template = unit_templates[template_id]
	var unit = BattleUnit.new()
	
	unit.unit_name = template.get("name_prefix", "Enemy") + " " + template.get("name", "Unit")
	unit.team = team
	
	var base_stats = template.get("base_stats", {})
	var stat_modifiers = template.get("stat_modifiers", {})
	var level_scaling = template.get("level_scaling", {})
	
	# Update stats instead of replacing the dictionary
	unit.stats.health = _calculate_stat(base_stats.get("health", 100.0), stat_modifiers.get("health", 1.0), level, level_scaling.get("health", 0.1))
	unit.stats.max_health = unit.stats.health
	unit.stats.attack = _calculate_stat(base_stats.get("attack", 10.0), stat_modifiers.get("attack", 1.0), level, level_scaling.get("attack", 0.08))
	unit.stats.defense = _calculate_stat(base_stats.get("defense", 5.0), stat_modifiers.get("defense", 1.0), level, level_scaling.get("defense", 0.06))
	unit.stats.speed = _calculate_stat(base_stats.get("speed", 5.0), stat_modifiers.get("speed", 1.0), level, level_scaling.get("speed", 0.04))
	unit.stats.initiative = 0.0
	
	if "mana" in base_stats:
		unit.stats["mana"] = _calculate_stat(base_stats.get("mana", 50.0), stat_modifiers.get("mana", 1.0), level, level_scaling.get("mana", 0.08))
		unit.stats["max_mana"] = unit.stats["mana"]
	
	if "skills" in template:
		for skill_id in template.skills:
			var skill = _create_skill_from_id(skill_id, level)
			if skill:
				unit.add_skill(skill)
	
	# AI type would need to be stored as a property on the unit or handled elsewhere
	# For now, we'll skip it since BattleUnit doesn't have ai_type property
	
	# Status immunities and tags would also need to be added to BattleUnit
	# For now, we'll skip these as well
	
	if "equipment" in template:
		for slot in template.equipment:
			var equipment_data = template.equipment[slot]
			var equipment = _create_equipment_from_data(equipment_data, level)
			if equipment:
				unit.equip_item(slot, equipment)
	
	if not difficulty_modifiers.is_empty():
		DifficultyScaler.apply_difficulty_to_unit(unit, difficulty_modifiers)
	
	return unit

static func _calculate_stat(base_value: float, modifier: float, level: int, scaling: float) -> float:
	var level_bonus = 1.0 + ((level - 1) * scaling)
	return base_value * modifier * level_bonus

static func _create_skill_from_id(skill_id: String, level: int) -> BattleSkill:
	var skill_templates = {
		"basic_attack": {
			"name": "Basic Attack",
			"base_damage": 10.0,
			"damage_type": "physical",
			"target_type": "single_enemy"
		},
		"arrow_shot": {
			"name": "Arrow Shot",
			"base_damage": 15.0,
			"damage_type": "physical",
			"target_type": "single_enemy"
		},
		"fireball": {
			"name": "Fireball",
			"base_damage": 20.0,
			"damage_type": "fire",
			"target_type": "single_enemy",
			"resource_cost": 10.0,
			"resource_type": "mana"
		},
		"frost_bolt": {
			"name": "Frost Bolt",
			"base_damage": 18.0,
			"damage_type": "ice",
			"target_type": "single_enemy",
			"resource_cost": 10.0,
			"resource_type": "mana"
		},
		"poison_strike": {
			"name": "Poison Strike",
			"base_damage": 12.0,
			"damage_type": "poison",
			"target_type": "single_enemy",
			"cooldown": 3.0
		},
		"cleave": {
			"name": "Cleave",
			"base_damage": 8.0,
			"damage_type": "physical",
			"target_type": "all_enemies",
			"cooldown": 4.0
		},
		"heal": {
			"name": "Heal",
			"base_damage": -20.0,
			"damage_type": "holy",
			"target_type": "lowest_health_ally",
			"resource_cost": 15.0,
			"resource_type": "mana"
		}
	}
	
	if skill_id not in skill_templates:
		return null
	
	var template = skill_templates[skill_id]
	var skill = BattleSkill.new()
	
	skill.skill_name = template.get("name", "Skill")
	skill.base_damage = template.get("base_damage", 10.0) * (1.0 + (level - 1) * 0.1)
	skill.damage_type = template.get("damage_type", "physical")
	skill.target_type = template.get("target_type", "single_enemy")
	skill.cooldown = template.get("cooldown", 0.0)
	skill.resource_cost = template.get("resource_cost", 0.0)
	skill.resource_type = template.get("resource_type", "mana")
	
	return skill

static func _create_equipment_from_data(equipment_data: Dictionary, level: int) -> Equipment:
	var equipment = Equipment.new()
	
	equipment.equipment_name = equipment_data.get("name", "Equipment")
	equipment.slot = equipment_data.get("slot", "weapon")
	equipment.rarity = equipment_data.get("rarity", "common")
	equipment.level_requirement = max(1, level - 2)
	
	var stat_bonuses = equipment_data.get("stat_bonuses", {})
	for stat in stat_bonuses:
		var bonus = stat_bonuses[stat] * (1.0 + (level - 1) * 0.05)
		equipment.add_additive_stat(stat, bonus)
	
	return equipment

static func _create_default_unit(team: int) -> BattleUnit:
	var unit = BattleUnit.new()
	unit.unit_name = "Default Enemy"
	unit.team = team
	unit.stats = {
		"health": 100.0,
		"max_health": 100.0,
		"attack": 10.0,
		"defense": 5.0,
		"speed": 5.0,
		"initiative": 0.0
	}
	
	var basic_attack = BattleSkill.new()
	basic_attack.skill_name = "Basic Attack"
	basic_attack.base_damage = 10.0
	basic_attack.damage_type = "physical"
	basic_attack.target_type = "single_enemy"
	unit.add_skill(basic_attack)
	
	return unit

static func create_unit_group(template_id: String, count: int, level: int, team: int, difficulty_modifiers: Dictionary = {}) -> Array[BattleUnit]:
	var units: Array[BattleUnit] = []
	
	for i in range(count):
		var unit = create_from_template(template_id, level, team, difficulty_modifiers)
		if unit:
			if count > 1:
				unit.unit_name += " " + str(i + 1)
			units.append(unit)
	
	return units

static func apply_formation(units: Array[BattleUnit], formation: String, base_position: Vector2 = Vector2.ZERO) -> void:
	var formations = {
		"line_horizontal": _formation_line_horizontal,
		"line_vertical": _formation_line_vertical,
		"triangle": _formation_triangle,
		"square": _formation_square,
		"circle": _formation_circle,
		"wedge": _formation_wedge,
		"scattered": _formation_scattered
	}
	
	if formation in formations:
		formations[formation].call(units, base_position)
	else:
		_formation_default(units, base_position)

static func _formation_default(units: Array[BattleUnit], base_pos: Vector2) -> void:
	for i in range(units.size()):
		units[i].position = base_pos + Vector2(0, i * 120)

static func _formation_line_horizontal(units: Array[BattleUnit], base_pos: Vector2) -> void:
	var spacing = 100.0
	var total_width = (units.size() - 1) * spacing
	var start_x = base_pos.x - total_width / 2.0
	
	for i in range(units.size()):
		units[i].position = Vector2(start_x + i * spacing, base_pos.y)

static func _formation_line_vertical(units: Array[BattleUnit], base_pos: Vector2) -> void:
	var spacing = 120.0
	for i in range(units.size()):
		units[i].position = base_pos + Vector2(0, i * spacing)

static func _formation_triangle(units: Array[BattleUnit], base_pos: Vector2) -> void:
	if units.size() <= 1:
		units[0].position = base_pos
		return
	
	var row = 0
	var col = 0
	var max_in_row = 1
	var spacing = 100.0
	
	for i in range(units.size()):
		var x_offset = (col - (max_in_row - 1) / 2.0) * spacing
		units[i].position = base_pos + Vector2(x_offset, row * spacing)
		
		col += 1
		if col >= max_in_row:
			row += 1
			max_in_row += 1
			col = 0

static func _formation_square(units: Array[BattleUnit], base_pos: Vector2) -> void:
	var grid_size = ceil(sqrt(units.size()))
	var spacing = 100.0
	
	for i in range(units.size()):
		var row = i / int(grid_size)
		var col = i % int(grid_size)
		var x_offset = (col - (grid_size - 1) / 2.0) * spacing
		var y_offset = (row - (grid_size - 1) / 2.0) * spacing
		units[i].position = base_pos + Vector2(x_offset, y_offset)

static func _formation_circle(units: Array[BattleUnit], base_pos: Vector2) -> void:
	if units.size() <= 1:
		units[0].position = base_pos
		return
	
	var radius = 150.0
	var angle_step = TAU / units.size()
	
	for i in range(units.size()):
		var angle = i * angle_step
		var x = cos(angle) * radius
		var y = sin(angle) * radius
		units[i].position = base_pos + Vector2(x, y)

static func _formation_wedge(units: Array[BattleUnit], base_pos: Vector2) -> void:
	if units.size() <= 1:
		units[0].position = base_pos
		return
	
	units[0].position = base_pos
	
	var spacing = 100.0
	var row = 1
	var remaining = units.size() - 1
	var index = 1
	
	while remaining > 0:
		var in_this_row = min(row * 2, remaining)
		for i in range(in_this_row):
			var x_offset = (i - (in_this_row - 1) / 2.0) * spacing
			units[index].position = base_pos + Vector2(x_offset, row * spacing)
			index += 1
		remaining -= in_this_row
		row += 1

static func _formation_scattered(units: Array[BattleUnit], base_pos: Vector2) -> void:
	var area_size = Vector2(300, 300)
	
	for unit in units:
		var offset = Vector2(
			randf_range(-area_size.x / 2, area_size.x / 2),
			randf_range(-area_size.y / 2, area_size.y / 2)
		)
		unit.position = base_pos + offset