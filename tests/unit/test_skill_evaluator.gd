extends GutTest

var evaluator = null  # SkillEvaluator
var unit = null  # BattleUnit
var enemy = null  # BattleUnit
var context: Dictionary

func before_each() -> void:
    var SkillEvaluator = load("res://src/skills/skill_evaluator.gd")
    evaluator = SkillEvaluator.new()
    
    # Create test unit
    var BattleUnit = load("res://src/battle/battle_unit.gd")
    unit = BattleUnit.new()
    unit.unit_name = "TestUnit"
    unit.team = 1
    unit.stats = {
        "health": 100.0,
        "max_health": 100.0,
        "attack": 20.0,
        "defense": 10.0,
        "speed": 5.0,
        "mana": 50.0,
        "max_mana": 100.0
    }
    
    var StatProjector = load("res://src/skills/stat_projector.gd")
    for stat_name in unit.stats.keys():
        unit.stat_projectors[stat_name] = StatProjector.new()
    
    # Create enemy
    enemy = BattleUnit.new()
    enemy.unit_name = "Enemy"
    enemy.team = 2
    enemy.stats = {
        "health": 50.0,
        "max_health": 80.0,
        "attack": 15.0,
        "defense": 5.0,
        "speed": 6.0
    }
    
    for stat_name in enemy.stats.keys():
        enemy.stat_projectors[stat_name] = StatProjector.new()
    
    # Base context
    context = {
        "unit": unit,
        "allies": [unit],
        "enemies": [enemy],
        "skill_history": []
    }

func after_each() -> void:
    if unit:
        unit.queue_free()
    if enemy:
        enemy.queue_free()

func test_free_skill_efficiency() -> void:
    var BattleSkill = load("res://src/battle/battle_skill.gd")
    var skill = BattleSkill.new()
    skill.skill_name = "Free Attack"
    skill.base_damage = 20.0
    skill.resource_cost = 0.0
    
    var score = evaluator._evaluate_resource_efficiency(skill, unit, context)
    assert_eq(score, 100.0, "Free skills should have perfect efficiency")

func test_damage_efficiency_calculation() -> void:
    var skill = BattleSkill.new()
    skill.skill_name = "Power Strike"
    skill.base_damage = 50.0
    skill.target_type = "single_enemy"
    
    var score = evaluator._evaluate_damage_efficiency(skill, unit, context)
    assert_gt(score, 0.0, "Damage efficiency should be positive")
    assert_true(score <= 100.0, "Damage efficiency should be capped at 100")

func test_ai_weight_application() -> void:
    unit.set_meta("ai_type", BattleAI.AIType.AGGRESSIVE)
    evaluator._apply_ai_weights(unit)
    
    assert_eq(evaluator.scoring_weights["damage_efficiency"], 1.5)
    assert_eq(evaluator.scoring_weights["risk_assessment"], 0.5)

func test_combo_potential_scoring() -> void:
    var skill1 = BattleSkill.new()
    skill1.skill_name = "Fire"
    skill1.damage_type = "fire"
    
    var skill2 = BattleSkill.new()
    skill2.skill_name = "Oil Splash"
    skill2.damage_type = "oil"
    
    context.skill_history = [{
        "skill": skill1,
        "caster": unit,
        "time": Time.get_unix_time_from_system() - 1.0,
        "targets": [enemy]
    }]
    
    var score = evaluator._evaluate_combo_potential(skill2, unit, context)
    assert_gt(score, 0.0, "Should detect fire-oil combo potential")

func test_battle_phase_determination() -> void:
    # Full health - should be opening
    var phase = evaluator._determine_battle_phase(context)
    assert_eq(phase, "opening")
    
    # Low health - should be end game
    unit.stats.health = 20.0
    enemy.stats.health = 15.0
    phase = evaluator._determine_battle_phase(context)
    assert_eq(phase, "end_game")

func test_target_priority_low_health() -> void:
    enemy.stats.health = 10.0  # Very low health
    
    var skill = BattleSkill.new()
    skill.base_damage = 15.0  # Can finish enemy
    
    var priority = evaluator._calculate_single_target_priority(enemy, skill, context)
    assert_gt(priority, 50.0, "Should have high priority for finishing blow")

func test_risk_assessment() -> void:
    var risky_skill = BattleSkill.new()
    risky_skill.skill_name = "Desperate Strike"
    risky_skill.tags.assign(["self_damage"])
    
    # Full health - low risk
    unit.stats.health = 100.0
    var risk_score = evaluator._evaluate_risk_factors(risky_skill, unit, context)
    assert_gt(risk_score, 50.0, "Risk should be acceptable at full health")
    
    # Low health - high risk
    unit.stats.health = 20.0
    risk_score = evaluator._evaluate_risk_factors(risky_skill, unit, context)
    assert_lt(risk_score, 50.0, "Risk should be high at low health")

func test_skill_evaluation_threshold() -> void:
    evaluator.activation_threshold = 50.0
    
    var weak_skill = BattleSkill.new()
    weak_skill.skill_name = "Weak Attack"
    weak_skill.base_damage = 5.0
    weak_skill.resource_cost = 20.0
    weak_skill.resource_type = "mana"
    
    unit.skills = [weak_skill]
    
    var chosen_skill = evaluator.evaluate_skills(unit, context)
    assert_null(chosen_skill, "Should not choose skills below threshold")

func test_timing_factor_cast_time() -> void:
    var instant_skill = BattleSkill.new()
    instant_skill.cast_time = 0.0
    
    var slow_skill = BattleSkill.new()
    slow_skill.cast_time = 3.0
    
    var instant_score = evaluator._evaluate_timing_factors(instant_skill, unit, context)
    var slow_score = evaluator._evaluate_timing_factors(slow_skill, unit, context)
    
    assert_gt(instant_score, slow_score, "Instant skills should score better than slow casts")

func test_situational_factors_tags() -> void:
    var setup_skill = BattleSkill.new()
    setup_skill.tags.assign(["setup"])
    
    var burst_skill = BattleSkill.new()
    burst_skill.tags.assign(["burst", "finisher"])
    
    # Opening phase
    context["battle_phase"] = "opening"
    var setup_score = evaluator._evaluate_situational_factors(setup_skill, unit, context)
    
    # End game phase
    context["battle_phase"] = "end_game"
    var burst_score = evaluator._evaluate_situational_factors(burst_skill, unit, context)
    
    assert_gt(setup_score, 0.0, "Setup skills should score well in opening")
    assert_gt(burst_score, 30.0, "Burst skills should score well in end game")
