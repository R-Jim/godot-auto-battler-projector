extends GutTest

var observer = null  # SkillActivationObserver
var unit1 = null  # BattleUnit
var unit2 = null  # BattleUnit
var skill = null  # BattleSkill
var rule_processor = null  # BattleRuleProcessor

func before_each() -> void:
	var SkillActivationObserver = load("res://skill_activation_observer.gd")
	observer = SkillActivationObserver.new()
	
	# Create test units
	var BattleUnit = load("res://battle_unit.gd")
	unit1 = BattleUnit.new()
	unit1.unit_name = "Unit1"
	unit1.team = 1
	unit1.stats = {
		"health": 100.0,
		"max_health": 100.0,
		"attack": 20.0,
		"defense": 10.0,
		"speed": 5.0,
		"mana": 50.0
	}
	
	# Initialize projectors
	var StatProjector = load("res://stat_projector.gd")
	for stat_name in unit1.stats.keys():
		unit1.stat_projectors[stat_name] = StatProjector.new()
	
	unit2 = BattleUnit.new()
	unit2.unit_name = "Unit2"
	unit2.team = 2
	unit2.stats = {
		"health": 80.0,
		"max_health": 80.0,
		"attack": 15.0,
		"defense": 5.0,
		"speed": 8.0
	}
	
	for stat_name in unit2.stats.keys():
		unit2.stat_projectors[stat_name] = StatProjector.new()
	
	# Create test skill
	var BattleSkill = load("res://battle_skill.gd")
	skill = BattleSkill.new()
	skill.skill_name = "Test Attack"
	skill.base_damage = 30.0
	skill.target_type = "single_enemy"
	skill.resource_cost = 10.0
	skill.resource_type = "mana"
	
	unit1.skills.append(skill)
	
	# Mock rule processor
	var BattleRuleProcessor = load("res://battle_rule_processor.gd")
	rule_processor = BattleRuleProcessor.new()
	rule_processor.skip_auto_load = true
	rule_processor.rules = []
	
	observer.rule_processor = rule_processor
	
	# Watch observer signals
	watch_signals(observer)

func after_each() -> void:
	if unit1:
		unit1.queue_free()
	if unit2:
		unit2.queue_free()
	if observer:
		observer.queue_free()

func test_observe_unit() -> void:
	observer.observe_unit(unit1)
	
	assert_eq(observer.observed_units.size(), 1)
	assert_has(observer.observed_units, unit1)

func test_stop_observing() -> void:
	observer.observe_unit(unit1)
	observer.observe_unit(unit2)
	
	observer.stop_observing(unit1)
	
	assert_eq(observer.observed_units.size(), 1)
	assert_has(observer.observed_units, unit2)
	assert_does_not_have(observer.observed_units, unit1)

func test_skill_evaluation_threshold() -> void:
	observer.skill_evaluator.activation_threshold = 50.0
	observer.observe_unit(unit1)
	observer.observe_unit(unit2)
	
	# Force evaluation
	observer._check_skill_activations()
	
	# Should not activate if score is below threshold
	assert_eq(observer.active_casts.size(), 0)

func test_concurrent_casts_disabled() -> void:
	observer.enable_concurrent_casts = false
	observer.observe_unit(unit1)
	observer.observe_unit(unit2)
	
	# Create a cast manually
	var cast = skill.prepare_cast(unit1)
	cast.targets = [unit2]
	observer.active_casts.append(cast)
	
	# Should not create another cast for same unit
	observer._check_skill_activations()
	
	assert_eq(observer.active_casts.size(), 1)

func test_unit_death_cleanup() -> void:
	observer.observe_unit(unit1)
	observer.observe_unit(unit2)
	
	assert_eq(observer.observed_units.size(), 2)
	
	# Simulate unit death
	unit1.unit_died.emit()
	
	assert_eq(observer.observed_units.size(), 1)
	assert_does_not_have(observer.observed_units, unit1)

func test_cast_progress_tracking() -> void:
	var cast_skill = skill.clone()
	cast_skill.cast_time = 2.0
	
	var cast = cast_skill.prepare_cast(unit1)
	cast.cast_start_time = Time.get_unix_time_from_system()
	observer.active_casts.append(cast)
	
	# Initial progress should be 0
	assert_almost_eq(cast.get_cast_progress(), 0.0, 0.1)
	
	# Simulate time passing
	cast.cast_start_time -= 1.0  # 1 second passed
	assert_almost_eq(cast.get_cast_progress(), 0.5, 0.1)
	
	# Complete cast
	cast.cast_start_time -= 1.0  # 2 seconds total
	assert_eq(cast.get_cast_progress(), 1.0)

func test_reaction_trigger() -> void:
	var BattleSkill = load("res://battle_skill.gd")
	var reaction_skill = BattleSkill.new()
	reaction_skill.skill_name = "Counter"
	reaction_skill.base_damage = 20.0
	reaction_skill.target_type = "single_enemy"
	reaction_skill.tags.assign(["reaction", "on_damaged"])
	reaction_skill.reaction_chance = 1.0  # 100% for testing
	
	unit2.skills.append(reaction_skill)
	observer.observe_unit(unit1)
	observer.observe_unit(unit2)
	
	# Trigger reaction check
	observer.trigger_reaction_check("on_damaged", unit1, {"damage": 10.0})
	
	# Should create a reaction cast
	assert_signal_emitted(observer, "skill_initiated")