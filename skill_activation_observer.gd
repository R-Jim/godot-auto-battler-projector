class_name SkillActivationObserver
extends Node

signal skill_ready(unit: BattleUnit, skill: BattleSkill)
signal skill_initiated(cast: SkillCast)
signal skill_completed(cast: SkillCast)
signal skill_interrupted(cast: SkillCast)
signal cast_progress_updated(unit: BattleUnit, progress: float)

var observed_units: Array[BattleUnit] = []
var active_casts: Array[SkillCast] = []
var time_scale: float = 1.0
var skill_evaluator = null  # SkillEvaluator
var action_queue = null  # UnitActionQueue
var battle_context = null  # BattleContext
var rule_processor = null  # BattleRuleProcessor

# Configuration
@export var enable_concurrent_casts: bool = true
@export var max_concurrent_casts_per_unit: int = 1
@export var evaluation_interval: float = 0.1  # How often to check for new skills

var _evaluation_timer: float = 0.0
var _skill_history: Array[Dictionary] = []

func _ready() -> void:
	skill_evaluator = load("res://skill_evaluator.gd").new()
	action_queue = load("res://unit_action_queue.gd").new()
	battle_context = load("res://battle_context.gd").new()
	
	# Get rule processor if available
	rule_processor = get_node_or_null("/root/RuleProcessor")
	if rule_processor:
		battle_context.rule_processor = rule_processor

func _process(delta: float) -> void:
	if observed_units.is_empty():
		return
	
	var scaled_delta = delta * time_scale
	
	# Update active casts
	_update_active_casts(scaled_delta)
	
	# Check for new skill activations
	_evaluation_timer += scaled_delta
	if _evaluation_timer >= evaluation_interval:
		_evaluation_timer = 0.0
		_check_skill_activations()

func observe_unit(unit: BattleUnit) -> void:
	if not observed_units.has(unit):
		observed_units.append(unit)
		unit.stat_changed.connect(_on_unit_stat_changed.bind(unit))
		unit.unit_died.connect(_on_unit_died.bind(unit))
		action_queue.register_unit(unit)

func stop_observing(unit: BattleUnit) -> void:
	if not is_instance_valid(unit):
		return
		
	observed_units.erase(unit)
	if unit.stat_changed.is_connected(_on_unit_stat_changed):
		unit.stat_changed.disconnect(_on_unit_stat_changed)
	if unit.unit_died.is_connected(_on_unit_died):
		unit.unit_died.disconnect(_on_unit_died)
	action_queue.unregister_unit(unit)
	
	# Cancel any active casts
	var casts_to_cancel = active_casts.filter(func(c): return c.caster == unit)
	for cast in casts_to_cancel:
		_interrupt_cast(cast)

func _update_active_casts(delta: float) -> void:
	var completed_casts: Array[SkillCast] = []
	
	for cast in active_casts:
		if cast.is_cancelled:
			continue
		
		# Update cast progress
		var prev_progress = cast.get_cast_progress()
		cast.cast_start_time -= delta  # Progress time forward
		var new_progress = cast.get_cast_progress()
		
		if new_progress != prev_progress:
			cast_progress_updated.emit(cast.caster, new_progress)
		
		# Check if ready to execute
		if cast.is_ready():
			completed_casts.append(cast)
	
	# Execute completed casts
	for cast in completed_casts:
		_execute_cast(cast)

func _check_skill_activations() -> void:
	# Update battle context
	_update_battle_context()
	
	# Get action order from queue
	var unit_order = action_queue.get_action_order()
	
	for unit_data in unit_order:
		var unit = unit_data["unit"]
		if not is_instance_valid(unit) or not unit.is_alive():
			continue
		
		# Skip if unit has max concurrent casts
		if not enable_concurrent_casts and _has_active_cast(unit):
			continue
		
		if enable_concurrent_casts:
			var active_count = _count_active_casts(unit)
			if active_count >= max_concurrent_casts_per_unit:
				continue
		
		# Evaluate available skills
		var best_skill = _evaluate_unit_skills(unit)
		if best_skill:
			_initiate_skill_cast(unit, best_skill)

func _evaluate_unit_skills(unit: BattleUnit) -> BattleSkill:
	# Build evaluation context
	var context = battle_context.get_unit_context(unit)
	context["skill_history"] = _skill_history
	
	# Get allies and enemies
	var allies = observed_units.filter(func(u): return is_instance_valid(u) and u.team == unit.team and u.is_alive())
	var enemies = observed_units.filter(func(u): return is_instance_valid(u) and u.team != unit.team and u.is_alive())
	
	context["allies"] = allies
	context["enemies"] = enemies
	context["unit"] = unit
	
	# Evaluate skills
	return skill_evaluator.evaluate_skills(unit, context)

func _initiate_skill_cast(unit: BattleUnit, skill: BattleSkill) -> void:
	# Create skill cast
	var cast = skill.prepare_cast(unit)
	
	# Try to claim resources
	if not cast.claim_resources():
		return
	
	# Get targets
	var allies = observed_units.filter(func(u): return is_instance_valid(u) and u.team == unit.team and u.is_alive())
	var enemies = observed_units.filter(func(u): return is_instance_valid(u) and u.team != unit.team and u.is_alive())
	
	cast.targets = skill.get_targets(unit, allies, enemies)
	
	if cast.targets.is_empty():
		cast.refund()
		return
	
	# Add to active casts
	active_casts.append(cast)
	skill_initiated.emit(cast)
	
	# Record in history
	_skill_history.append({
		"skill": skill,
		"caster": unit,
		"time": Time.get_unix_time_from_system(),
		"targets": cast.targets
	})
	
	# Limit history size
	if _skill_history.size() > 20:
		_skill_history.pop_front()

func _execute_cast(cast: SkillCast) -> void:
	if cast.is_cancelled:
		return
	
	# Check if caster is still valid
	if not is_instance_valid(cast.caster):
		active_casts.erase(cast)
		return
	
	# Execute the skill
	if cast.execute(rule_processor):
		skill_completed.emit(cast)
	
	# Remove from active casts
	active_casts.erase(cast)

func _interrupt_cast(cast: SkillCast) -> void:
	cast.interrupt()
	active_casts.erase(cast)
	skill_interrupted.emit(cast)

func _has_active_cast(unit: BattleUnit) -> bool:
	return active_casts.any(func(c): return c.caster == unit and not c.is_cancelled)

func _count_active_casts(unit: BattleUnit) -> int:
	return active_casts.filter(func(c): return c.caster == unit and not c.is_cancelled).size()

func _update_battle_context() -> void:
	battle_context.update_state(observed_units, active_casts, _skill_history)

func _on_unit_stat_changed(stat_name: String, new_value: float, unit: BattleUnit) -> void:
	# Re-evaluate if speed changed
	if stat_name == "speed":
		action_queue.update_unit_priority(unit)

func _on_unit_died(unit: BattleUnit) -> void:
	stop_observing(unit)

# Reaction system support
func trigger_reaction_check(event: String, source: BattleUnit, data: Dictionary) -> void:
	for unit in observed_units:
		if unit == source or not is_instance_valid(unit) or not unit.is_alive():
			continue
		
		var reaction_skills = unit.skills.filter(func(s): return s.has_tag("reaction") and s.has_tag(event))
		for skill in reaction_skills:
			if skill.can_use(unit) and randf() < skill.reaction_chance:
				data["reaction_trigger"] = event
				data["reaction_source"] = source
				_initiate_skill_cast(unit, skill)

# Helper to get cast progress for UI
func get_unit_cast_progress(unit: BattleUnit) -> float:
	for cast in active_casts:
		if cast.caster == unit and not cast.is_cancelled:
			return cast.get_cast_progress()
	return 0.0

func get_active_cast(unit: BattleUnit) -> SkillCast:
	for cast in active_casts:
		if cast.caster == unit and not cast.is_cancelled:
			return cast
	return null