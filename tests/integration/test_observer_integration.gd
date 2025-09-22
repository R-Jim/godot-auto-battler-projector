extends GutTest

var battle: AutoBattler
var team1: Array[BattleUnit] = []
var team2: Array[BattleUnit] = []
var rule_processor

func before_each() -> void:
    # Create RuleProcessor if not exists
    if not get_node_or_null("/root/RuleProcessor"):
        var BattleRuleProcessorScript = load("res://battle_rule_processor.gd")
        rule_processor = BattleRuleProcessorScript.new()
        rule_processor.name = "RuleProcessor"
        get_tree().root.add_child(rule_processor)
    
    battle = AutoBattler.new()
    battle.use_observer_system = true  # Enable new system
    add_child(battle)
    
    # Create team 1
    for i in range(2):
        var unit = BattleUnit.new()
        unit.unit_name = "Team1_Unit%d" % (i + 1)
        unit.team = 1
        unit.stats = {
            "health": 100.0,
            "max_health": 100.0,
            "attack": 20.0,
            "defense": 5.0,
            "speed": 5.0 + i * 2,  # Varying speeds
            "mana": 50.0
        }
        
        for stat_name in unit.stats.keys():
            unit.stat_projectors[stat_name] = StatProjector.new()
        
        # Add a basic skill
        var skill = BattleSkill.new()
        skill.skill_name = "Attack"
        skill.base_damage = 25.0
        skill.target_type = "single_enemy"
        skill.resource_cost = 10.0
        skill.resource_type = "mana"
        unit.skills.append(skill)
        
        team1.append(unit)
    
    # Create team 2
    for i in range(2):
        var unit = BattleUnit.new()
        unit.unit_name = "Team2_Unit%d" % (i + 1)
        unit.team = 2
        unit.stats = {
            "health": 80.0,
            "max_health": 80.0,
            "attack": 15.0,
            "defense": 3.0,
            "speed": 4.0 + i * 2,
            "mana": 40.0
        }
        
        for stat_name in unit.stats.keys():
            unit.stat_projectors[stat_name] = StatProjector.new()
        
        # Add skills
        var skill = BattleSkill.new()
        skill.skill_name = "Quick Strike"
        skill.base_damage = 20.0
        skill.target_type = "single_enemy"
        skill.resource_cost = 8.0
        skill.resource_type = "mana"
        unit.skills.append(skill)
        
        team2.append(unit)

func after_each() -> void:
    if battle:
        battle.stop_battle()
        battle.queue_free()
    
    for unit in team1:
        if unit and is_instance_valid(unit):
            unit.queue_free()
    team1.clear()
    
    for unit in team2:
        if unit and is_instance_valid(unit):
            unit.queue_free()
    team2.clear()
    
    # Clean up RuleProcessor if we created it
    if rule_processor and is_instance_valid(rule_processor):
        rule_processor.queue_free()
        rule_processor = null

func test_observer_battle_starts() -> void:
    watch_signals(battle)
    
    battle.start_battle(team1, team2)
    
    assert_signal_emitted(battle, "battle_started")
    assert_not_null(battle.skill_observer, "Skill observer should be created")
    assert_eq(battle.skill_observer.observed_units.size(), 4, "All units should be observed")

func test_skills_activate_automatically() -> void:
    battle.start_battle(team1, team2)
    
    # Wait for evaluation interval to pass
    await get_tree().create_timer(0.2).timeout
    
    # Check that skills are being evaluated
    assert_gt(battle.skill_observer.active_casts.size() + battle.skill_observer._skill_history.size(), 0, 
        "Skills should be activating")

func test_battle_ends_correctly() -> void:
    watch_signals(battle)
    
    battle.start_battle(team1, team2)
    
    # Instantly defeat team 2
    for unit in team2:
        unit.stats.health = 0
        unit.unit_died.emit()
    
    assert_signal_emitted_with_parameters(battle, "battle_ended", [1], "Team 1 should win")
    assert_false(battle.is_battle_active)

func test_concurrent_casts() -> void:
    battle.start_battle(team1, team2)
    battle.skill_observer.enable_concurrent_casts = true
    battle.skill_observer.max_concurrent_casts_per_unit = 2
    
    # Give units skills with cast time
    for unit in team1:
        var cast_skill = BattleSkill.new()
        cast_skill.skill_name = "Cast Attack"
        cast_skill.base_damage = 10.0
        cast_skill.cast_time = 1.0  # 1 second cast time
        cast_skill.cooldown = 0.0
        cast_skill.resource_cost = 1.0
        cast_skill.resource_type = "mana"
        cast_skill.target_type = "single_enemy"
        unit.skills.append(cast_skill)
        unit.stats["mana"] = 100.0  # Plenty of mana
    
    # Wait for observer to process
    await get_tree().create_timer(0.3).timeout
    
    # Should have multiple active casts
    assert_gt(battle.skill_observer.active_casts.size(), 0, "Should have active casts")

func test_reaction_skills() -> void:
    # Add reaction skill to team 2
    var counter_skill = BattleSkill.new()
    counter_skill.skill_name = "Counter"
    counter_skill.base_damage = 15.0
    counter_skill.target_type = "single_enemy"
    counter_skill.tags.assign(["reaction", "on_damaged"])
    counter_skill.reaction_chance = 1.0
    counter_skill.resource_cost = 5.0
    counter_skill.resource_type = "mana"
    
    team2[0].skills.append(counter_skill)
    
    battle.start_battle(team1, team2)
    
    watch_signals(battle.skill_observer)
    
    # Trigger reaction by damaging unit
    battle.skill_observer.trigger_reaction_check("on_damaged", team1[0], {
        "damage": 10.0,
        "target": team2[0]
    })
    
    assert_signal_emitted(battle.skill_observer, "skill_initiated", "Reaction should trigger")

func test_skill_evaluation_respects_ai_type() -> void:
    # Set AI types before starting battle
    var BattleAI = load("res://battle_ai.gd")
    team1[0].set_meta("ai_type", BattleAI.AIType.AGGRESSIVE)
    team1[1].set_meta("ai_type", BattleAI.AIType.DEFENSIVE)
    
    battle.start_battle(team1, team2)
    
    # Force evaluation to trigger AI weight application
    var evaluator = battle.skill_observer.skill_evaluator
    var context = {
        "allies": team1,
        "enemies": team2,
        "unit": team1[0]
    }
    
    # Evaluate skills for aggressive unit
    evaluator.evaluate_skills(team1[0], context)
    
    # Check that evaluator applied AI weights for aggressive type
    assert_eq(evaluator.scoring_weights["damage_efficiency"], 1.5, 
        "Aggressive AI weights should be applied")

func test_cast_interruption() -> void:
    # Add a slow cast skill with enough mana
    var slow_skill = BattleSkill.new()
    slow_skill.skill_name = "Charged Attack"
    slow_skill.base_damage = 50.0
    slow_skill.cast_time = 2.0
    slow_skill.target_type = "single_enemy"
    slow_skill.resource_cost = 20.0
    slow_skill.resource_type = "mana"
    
    team1[0].skills = [slow_skill]  # Replace skills
    team1[0].stats["mana"] = 100.0  # Ensure enough mana
    
    battle.start_battle(team1, team2)
    
    # Wait for cast to start
    await get_tree().create_timer(0.2).timeout
    
    assert_gt(battle.skill_observer.active_casts.size(), 0, "Should have active casts")
    
    var cast = battle.skill_observer.active_casts[0]
    watch_signals(battle.skill_observer)
    
    # Interrupt the cast
    battle.skill_observer._interrupt_cast(cast)
    
    assert_signal_emitted(battle.skill_observer, "skill_interrupted")
    assert_true(cast.is_cancelled)

# Helper to wait for a specific number of frames
func wait_frames(frame_count: int, reason: String = "") -> void:
    for i in frame_count:
        await get_tree().process_frame
