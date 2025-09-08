extends GutTest

var battle_skill: BattleSkill

func before_each():
	battle_skill = BattleSkill.new()

func test_default_values():
	assert_eq(battle_skill.skill_name, "Skill")
	assert_eq(battle_skill.description, "")
	assert_eq(battle_skill.base_damage, 10.0)
	assert_eq(battle_skill.damage_type, "physical")
	assert_eq(battle_skill.target_type, "single_enemy")
	assert_eq(battle_skill.cooldown, 0.0)
	assert_eq(battle_skill.resource_cost, 0.0)
	assert_eq(battle_skill.resource_type, "mana")
	assert_eq(battle_skill.last_used_time, 0.0)

func test_is_on_cooldown():
	battle_skill.cooldown = 5.0
	
	# Not on cooldown initially
	assert_false(battle_skill.is_on_cooldown())
	
	# Simulate using the skill
	battle_skill.last_used_time = Time.get_unix_time_from_system()
	assert_true(battle_skill.is_on_cooldown())
	
	# Simulate cooldown expired
	battle_skill.last_used_time = Time.get_unix_time_from_system() - 6.0
	assert_false(battle_skill.is_on_cooldown())

func test_is_on_cooldown_no_cooldown():
	battle_skill.cooldown = 0.0
	battle_skill.last_used_time = Time.get_unix_time_from_system()
	assert_false(battle_skill.is_on_cooldown())

func test_can_use_basic():
	var caster = BattleUnit.new()
	add_child(caster)
	await get_tree().process_frame
	
	assert_true(battle_skill.can_use(caster))
	
	caster.queue_free()

func test_can_use_with_cooldown():
	var caster = BattleUnit.new()
	add_child(caster)
	await get_tree().process_frame
	
	battle_skill.cooldown = 3.0
	battle_skill.last_used_time = Time.get_unix_time_from_system()
	
	assert_false(battle_skill.can_use(caster))
	
	caster.queue_free()

func test_can_use_with_resource_cost():
	var caster = BattleUnit.new()
	add_child(caster)
	await get_tree().process_frame
	
	# Add mana to caster's stats
	caster.stats["mana"] = 50.0
	caster.projectors["mana"] = PropertyProjector.new()
	
	battle_skill.resource_cost = 30.0
	assert_true(battle_skill.can_use(caster))
	
	battle_skill.resource_cost = 60.0
	assert_false(battle_skill.can_use(caster))
	
	caster.queue_free()

func test_can_use_missing_resource():
	var caster = BattleUnit.new()
	add_child(caster)
	await get_tree().process_frame
	
	# Caster doesn't have mana stat
	battle_skill.resource_cost = 10.0
	battle_skill.resource_type = "mana"
	
	assert_false(battle_skill.can_use(caster))
	
	caster.queue_free()

func test_clone():
	battle_skill.skill_name = "Fireball"
	battle_skill.description = "Launches a fireball"
	battle_skill.base_damage = 50.0
	battle_skill.damage_type = "fire"
	battle_skill.target_type = "single_enemy"
	battle_skill.cooldown = 3.0
	battle_skill.resource_cost = 20.0
	battle_skill.resource_type = "mana"
	
	var clone = battle_skill.clone()
	
	assert_eq(clone.skill_name, battle_skill.skill_name)
	assert_eq(clone.description, battle_skill.description)
	assert_eq(clone.base_damage, battle_skill.base_damage)
	assert_eq(clone.damage_type, battle_skill.damage_type)
	assert_eq(clone.target_type, battle_skill.target_type)
	assert_eq(clone.cooldown, battle_skill.cooldown)
	assert_eq(clone.resource_cost, battle_skill.resource_cost)
	assert_eq(clone.resource_type, battle_skill.resource_type)
	
	# Clone should not copy last_used_time
	assert_eq(clone.last_used_time, 0.0)
	
	# Should be different objects
	assert_ne(clone, battle_skill)

func test_get_targets_single_enemy():
	var caster = BattleUnit.new()
	var ally1 = BattleUnit.new()
	var enemy1 = BattleUnit.new()
	var enemy2 = BattleUnit.new()
	
	battle_skill.target_type = "single_enemy"
	var targets = battle_skill.get_targets(caster, [caster, ally1], [enemy1, enemy2])
	
	assert_eq(targets.size(), 2)
	assert_true(targets.has(enemy1))
	assert_true(targets.has(enemy2))

func test_get_targets_all_enemies():
	var caster = BattleUnit.new()
	var enemy1 = BattleUnit.new()
	var enemy2 = BattleUnit.new()
	var enemy3 = BattleUnit.new()
	enemy3.stats.health = 0  # Dead
	
	battle_skill.target_type = "all_enemies"
	var targets = battle_skill.get_targets(caster, [caster], [enemy1, enemy2, enemy3])
	
	assert_eq(targets.size(), 2)  # Only alive enemies
	assert_true(targets.has(enemy1))
	assert_true(targets.has(enemy2))
	assert_false(targets.has(enemy3))

func test_get_targets_self():
	var caster = BattleUnit.new()
	var ally = BattleUnit.new()
	var enemy = BattleUnit.new()
	
	battle_skill.target_type = "self"
	var targets = battle_skill.get_targets(caster, [caster, ally], [enemy])
	
	assert_eq(targets.size(), 1)
	assert_eq(targets[0], caster)

func test_get_targets_single_ally():
	var caster = BattleUnit.new()
	var ally1 = BattleUnit.new()
	var ally2 = BattleUnit.new()
	var enemy = BattleUnit.new()
	
	battle_skill.target_type = "single_ally"
	var targets = battle_skill.get_targets(caster, [caster, ally1, ally2], [enemy])
	
	assert_eq(targets.size(), 3)  # All allies including caster
	assert_true(targets.has(caster))
	assert_true(targets.has(ally1))
	assert_true(targets.has(ally2))

func test_get_targets_random_enemy():
	var caster = BattleUnit.new()
	var enemy1 = BattleUnit.new()
	var enemy2 = BattleUnit.new()
	var enemy3 = BattleUnit.new()
	
	battle_skill.target_type = "random_enemy"
	var targets = battle_skill.get_targets(caster, [caster], [enemy1, enemy2, enemy3])
	
	assert_eq(targets.size(), 1)
	assert_true(targets[0] == enemy1 or targets[0] == enemy2 or targets[0] == enemy3)

func test_get_targets_lowest_health_enemy():
	var caster = BattleUnit.new()
	add_child(caster)
	
	var enemy1 = BattleUnit.new()
	enemy1.stats.health = 100.0
	add_child(enemy1)
	
	var enemy2 = BattleUnit.new()
	enemy2.stats.health = 50.0
	add_child(enemy2)
	
	var enemy3 = BattleUnit.new()
	enemy3.stats.health = 75.0
	add_child(enemy3)
	
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	battle_skill.target_type = "lowest_health_enemy"
	var targets = battle_skill.get_targets(caster, [caster], [enemy1, enemy2, enemy3])
	
	assert_eq(targets.size(), 1)
	assert_eq(targets[0], enemy2)  # Has lowest health (50)
	
	caster.queue_free()
	enemy1.queue_free()
	enemy2.queue_free()
	enemy3.queue_free()

func test_get_targets_lowest_health_ally():
	var caster = BattleUnit.new()
	caster.stats.health = 80.0
	add_child(caster)
	
	var ally1 = BattleUnit.new()
	ally1.stats.health = 30.0
	add_child(ally1)
	
	var ally2 = BattleUnit.new()
	ally2.stats.health = 60.0
	add_child(ally2)
	
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	battle_skill.target_type = "lowest_health_ally"
	var targets = battle_skill.get_targets(caster, [caster, ally1, ally2], [])
	
	assert_eq(targets.size(), 1)
	assert_eq(targets[0], ally1)  # Has lowest health (30)
	
	caster.queue_free()
	ally1.queue_free()
	ally2.queue_free()

func test_build_context():
	var caster = BattleUnit.new()
	caster.team = 1
	caster.stats.health = 75.0
	add_child(caster)
	
	var target = BattleUnit.new()
	target.team = 2
	target.stats.health = 50.0
	add_child(target)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Add some status effects
	var poison = StatusEffect.new("poison", "Poison", "", 5.0)
	var buff = StatusEffect.new("buff", "Buff", "", 10.0)
	caster.add_status_effect(poison)
	target.add_status_effect(buff)
	
	battle_skill.skill_name = "Test Skill"
	battle_skill.damage_type = "fire"
	
	var context = battle_skill._build_context(caster, target)
	
	assert_eq(context.skill_name, "Test Skill")
	assert_eq(context.skill_damage_type, "fire")
	assert_eq(context.caster_health_percentage, 0.75)
	assert_eq(context.caster_team, 1)
	assert_eq(context.caster_status.size(), 1)
	assert_true(context.caster_status.has("poison"))
	assert_eq(context.target_health_percentage, 0.5)
	assert_eq(context.target_team, 2)
	assert_eq(context.target_status.size(), 1)
	assert_true(context.target_status.has("buff"))
	
	caster.queue_free()
	target.queue_free()

# Note: execute() and _apply_effects() require BattleRuleProcessor
# which is better tested in integration tests