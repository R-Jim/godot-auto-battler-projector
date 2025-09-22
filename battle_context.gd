class_name BattleContext
extends RefCounted

# Core battle state
var all_units: Array[BattleUnit] = []
var active_casts: Array[SkillCast] = []
var skill_history: Array[Dictionary] = []
var battle_start_time: float = 0.0
var current_round: int = 0

# Battle configuration
var encounter_id: String = ""
var encounter_modifiers: Array = []
var environmental_effects: Dictionary = {}

# References
var rule_processor = null

# Cached computations (invalidated on update)
var _cache_valid: bool = false
var _team_states: Dictionary = {}
var _battle_phase: String = ""
var _team_advantages: Dictionary = {}

func _init() -> void:
	battle_start_time = Time.get_unix_time_from_system()

func update_state(units: Array[BattleUnit], casts: Array[SkillCast], history: Array[Dictionary]) -> void:
	all_units = units
	active_casts = casts
	skill_history = history
	_cache_valid = false

func get_unit_context(unit: BattleUnit) -> Dictionary:
	if not _cache_valid:
		_rebuild_cache()
	
	var allies = all_units.filter(func(u): return u.team == unit.team and u.is_alive())
	var enemies = all_units.filter(func(u): return u.team != unit.team and u.is_alive())
	
	return {
		"unit": unit,
		"allies": allies,
		"enemies": enemies,
		"team_state": _team_states.get(unit.team, {}),
		"enemy_team_state": _get_enemy_team_state(unit.team),
		"battle_phase": _battle_phase,
		"battle_time": get_battle_elapsed_time(),
		"round": current_round,
		"encounter_id": encounter_id,
		"encounter_modifiers": encounter_modifiers,
		"environmental_effects": environmental_effects,
		"rule_processor": rule_processor,
		"active_casts": _get_relevant_casts(unit),
		"recent_skills": _get_recent_skills(5),
		"team_advantage": _team_advantages.get(unit.team, 0.0)
	}

func get_battle_elapsed_time() -> float:
	return Time.get_unix_time_from_system() - battle_start_time

func get_battle_phase() -> String:
	if not _cache_valid:
		_rebuild_cache()
	return _battle_phase

func get_team_state(team: int) -> Dictionary:
	if not _cache_valid:
		_rebuild_cache()
	return _team_states.get(team, {})

func add_environmental_effect(effect_id: String, effect_data: Dictionary) -> void:
	environmental_effects[effect_id] = effect_data
	_cache_valid = false

func remove_environmental_effect(effect_id: String) -> void:
	environmental_effects.erase(effect_id)
	_cache_valid = false

# Analysis methods
func count_units_with_status(status: String, team: int = -1) -> int:
	var count = 0
	for unit in all_units:
		if unit.is_alive() and (team == -1 or unit.team == team):
			if unit.has_status(status):
				count += 1
	return count

func get_average_health_percentage(team: int = -1) -> float:
	var total_health_percent = 0.0
	var unit_count = 0
	
	for unit in all_units:
		if unit.is_alive() and (team == -1 or unit.team == team):
			total_health_percent += unit.get_health_percentage()
			unit_count += 1
	
	return total_health_percent / max(1, unit_count)

func get_team_dps_estimate(team: int) -> float:
	var total_dps = 0.0
	
	for unit in all_units:
		if unit.team == team and unit.is_alive():
			var attack = unit.get_projected_stat("attack")
			var speed = unit.get_projected_stat("speed")
			# Rough DPS estimate
			var attacks_per_second = speed / 10.0  # Assuming base attack rate
			total_dps += attack * attacks_per_second
	
	return total_dps

func find_combo_opportunities() -> Array[Dictionary]:
	var opportunities: Array[Dictionary] = []
	
	# Check recent skills for combo setup
	for i in range(skill_history.size() - 1, -1, -1):
		var historical = skill_history[i]
		var time_since = Time.get_unix_time_from_system() - historical.time
		
		# Only consider recent skills (last 3 seconds)
		if time_since > 3.0:
			break
		
		# Look for combo opportunities
		for unit in all_units:
			if not unit.is_alive():
				continue
			
			for skill in unit.skills:
				if skill.can_use(unit):
					var combo_potential = _check_combo_potential(historical.skill, skill)
					if combo_potential > 0:
						opportunities.append({
							"unit": unit,
							"skill": skill,
							"combo_with": historical.skill,
							"score": combo_potential
						})
	
	return opportunities

# Private methods
func _rebuild_cache() -> void:
	_calculate_team_states()
	_calculate_battle_phase()
	_calculate_team_advantages()
	_cache_valid = true

func _calculate_team_states() -> void:
	_team_states.clear()
	
	# Group units by team
	var teams: Dictionary = {}
	for unit in all_units:
		if not teams.has(unit.team):
			teams[unit.team] = []
		teams[unit.team].append(unit)
	
	# Calculate state for each team
	for team in teams:
		var team_units = teams[team]
		var alive_units = team_units.filter(func(u): return u.is_alive())
		
		_team_states[team] = {
			"unit_count": alive_units.size(),
			"total_health": _calculate_total_health(alive_units),
			"average_health_percent": get_average_health_percentage(team),
			"total_attack": _calculate_total_stat(alive_units, "attack"),
			"total_defense": _calculate_total_stat(alive_units, "defense"),
			"average_speed": _calculate_average_stat(alive_units, "speed"),
			"has_healer": _team_has_role(alive_units, "healer"),
			"has_tank": _team_has_role(alive_units, "tank"),
			"status_counts": _count_team_statuses(alive_units)
		}

func _calculate_battle_phase() -> String:
	var elapsed_time = get_battle_elapsed_time()
	var avg_health = get_average_health_percentage()
	
	# Phase based on multiple factors
	if elapsed_time < 5.0 and avg_health > 0.9:
		_battle_phase = "opening"
	elif avg_health < 0.4 or elapsed_time > 60.0:
		_battle_phase = "end_game"
	else:
		_battle_phase = "mid_game"
	
	# Override based on unit counts
	var total_alive = all_units.filter(func(u): return u.is_alive()).size()
	var total_units = all_units.size()
	
	if float(total_alive) / float(total_units) < 0.5:
		_battle_phase = "end_game"
	
	return _battle_phase

func _calculate_team_advantages() -> void:
	_team_advantages.clear()
	
	# Get unique teams
	var teams: Array[int] = []
	for unit in all_units:
		if not teams.has(unit.team):
			teams.append(unit.team)
	
	# Calculate relative advantages
	for team in teams:
		var team_state = _team_states.get(team, {})
		var enemy_states = []
		
		for other_team in teams:
			if other_team != team:
				enemy_states.append(_team_states.get(other_team, {}))
		
		if enemy_states.is_empty():
			_team_advantages[team] = 1.0
			continue
		
		# Calculate advantage based on multiple factors
		var advantage = 1.0
		
		# Unit count advantage
		var team_units = team_state.get("unit_count", 0)
		var enemy_units = 0
		for enemy_state in enemy_states:
			enemy_units += enemy_state.get("unit_count", 0)
		
		if enemy_units > 0:
			advantage *= float(team_units) / float(enemy_units)
		
		# Health advantage
		var team_health = team_state.get("average_health_percent", 0)
		var enemy_health = 0
		for enemy_state in enemy_states:
			enemy_health += enemy_state.get("average_health_percent", 0)
		enemy_health /= max(1, enemy_states.size())
		
		if enemy_health > 0:
			advantage *= team_health / enemy_health
		
		# Power advantage
		var team_power = team_state.get("total_attack", 0)
		var enemy_power = 0
		for enemy_state in enemy_states:
			enemy_power += enemy_state.get("total_attack", 0)
		
		if enemy_power > 0:
			advantage *= team_power / enemy_power
		
		_team_advantages[team] = clamp(advantage, 0.1, 10.0)

func _get_enemy_team_state(unit_team: int) -> Dictionary:
	var enemy_state = {}
	
	for team in _team_states:
		if team != unit_team:
			# Merge enemy team states
			var state = _team_states[team]
			for key in state:
				if not enemy_state.has(key):
					enemy_state[key] = state[key]
				else:
					# Aggregate values
					if typeof(state[key]) == TYPE_INT or typeof(state[key]) == TYPE_FLOAT:
						enemy_state[key] += state[key]
	
	return enemy_state

func _get_relevant_casts(for_unit: BattleUnit) -> Array[SkillCast]:
	var relevant: Array[SkillCast] = []
	
	for cast in active_casts:
		# Include own casts
		if cast.caster == for_unit:
			relevant.append(cast)
			continue
		
		# Include enemy casts targeting this unit or allies
		if cast.caster.team != for_unit.team:
			if cast.targets.has(for_unit):
				relevant.append(cast)
			else:
				# Check if targeting allies
				for target in cast.targets:
					if target.team == for_unit.team:
						relevant.append(cast)
						break
	
	return relevant

func _get_recent_skills(count: int) -> Array[Dictionary]:
	if skill_history.size() <= count:
		return skill_history
	
	return skill_history.slice(-count)

func _calculate_total_health(units: Array) -> float:
	var total = 0.0
	for unit in units:
		total += unit.stats.health
	return total

func _calculate_total_stat(units: Array, stat: String) -> float:
	var total = 0.0
	for unit in units:
		total += unit.get_projected_stat(stat)
	return total

func _calculate_average_stat(units: Array, stat: String) -> float:
	if units.is_empty():
		return 0.0
	
	return _calculate_total_stat(units, stat) / units.size()

func _team_has_role(units: Array, role: String) -> bool:
	for unit in units:
		if unit.has_tag(role):
			return true
		# Check skills for role
		for skill in unit.skills:
			if skill.has_tag(role):
				return true
	return false

func _count_team_statuses(units: Array) -> Dictionary:
	var counts = {}
	
	for unit in units:
		for status in unit.get_status_list():
			counts[status] = counts.get(status, 0) + 1
	
	return counts

func _check_combo_potential(skill1: BattleSkill, skill2: BattleSkill) -> float:
	# Basic combo scoring - can be expanded
	if skill1.damage_type == "fire" and skill2.damage_type == "oil":
		return 30.0
	if skill1.has_tag("setup") and skill2.has_tag("payoff"):
		return 25.0
	if skill1.has_tag("stun") and skill2.has_tag("heavy_damage"):
		return 35.0
	
	return 0.0

# Debugging
func debug_print_state() -> void:
	print("\n=== Battle Context ===")
	print("Phase: %s, Time: %.1fs, Round: %d" % [_battle_phase, get_battle_elapsed_time(), current_round])
	print("\nTeam States:")
	for team in _team_states:
		var state = _team_states[team]
		print("  Team %d:" % team)
		print("    Units: %d, Avg HP: %.1f%%" % [state.unit_count, state.average_health_percent * 100])
		print("    Power: %.1f, Defense: %.1f" % [state.total_attack, state.total_defense])
		print("    Advantage: %.2f" % _team_advantages.get(team, 1.0))
	
	print("\nActive Casts: %d" % active_casts.size())
	print("Recent Skills: %d" % skill_history.size())
