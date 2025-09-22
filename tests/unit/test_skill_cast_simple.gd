extends GutTest

func test_skill_cast_basic_functionality() -> void:
	# Create units manually
	var caster = preload("res://src/battle/battle_unit.gd").new()
	caster.name = "Caster"
	caster.stats = {
		"health": 100.0,
		"max_health": 100.0,
		"attack": 20.0,
		"defense": 10.0,
		"speed": 5.0,
		"mana": 50.0
	}
	
	# Initialize projectors
	var StatProjectorClass = preload("res://src/skills/stat_projector.gd")
	for stat_name in caster.stats.keys():
		caster.stat_projectors[stat_name] = StatProjectorClass.new()
	
	var target = preload("res://src/battle/battle_unit.gd").new()
	target.name = "Target"
	target.stats = {
		"health": 80.0,
		"max_health": 80.0,
		"attack": 15.0,
		"defense": 5.0,
		"speed": 6.0
	}
	
	for stat_name in target.stats.keys():
		target.stat_projectors[stat_name] = StatProjectorClass.new()
	
	# Create skill
	var skill = preload("res://src/battle/battle_skill.gd").new()
	skill.skill_name = "Test Spell"
	skill.base_damage = 30.0
	skill.resource_cost = 20.0
	skill.resource_type = "mana"
	skill.cooldown = 5.0
	
	# Test 1: Can create skill cast
	var SkillCastClass = preload("res://src/skills/skill_cast.gd")
	var cast = SkillCastClass.new(skill, caster)
	assert_not_null(cast)
	assert_eq(cast.skill, skill)
	assert_eq(cast.caster, caster)
	
	# Test 2: Claim resources
	assert_true(cast.claim_resources())
	assert_true(cast.is_committed)
	assert_eq(caster.get_locked_resource("mana"), 20.0)
	assert_eq(caster.get_available_resource("mana"), 30.0)
	
	# Test 3: Cannot double claim
	var cast2 = SkillCastClass.new(skill, caster)
	assert_true(cast2.claim_resources())  # Should succeed - different cast
	assert_false(cast.claim_resources())  # Should fail - already claimed
	
	# Test 4: Refund works
	cast.refund()
	assert_false(cast.is_committed)
	assert_true(cast.is_cancelled)
	assert_eq(caster.get_locked_resource("mana"), 20.0)  # Still locked from cast2
	
	# Clean up cast2
	cast2.refund()
	assert_eq(caster.get_locked_resource("mana"), 0.0)

func test_resource_race_condition_prevention() -> void:
	# Setup
	var StatProjectorClass = preload("res://src/skills/stat_projector.gd")
	var caster = preload("res://src/battle/battle_unit.gd").new()
	caster.stats = {"mana": 50.0}
	caster.stat_projectors["mana"] = StatProjectorClass.new()
	
	var SkillCastClass = preload("res://src/skills/skill_cast.gd")
	
	# Create two expensive skills
	var skill1 = preload("res://src/battle/battle_skill.gd").new()
	skill1.skill_name = "Expensive Spell 1"
	skill1.resource_cost = 30.0
	skill1.resource_type = "mana"
	
	var skill2 = preload("res://src/battle/battle_skill.gd").new()
	skill2.skill_name = "Expensive Spell 2"
	skill2.resource_cost = 30.0
	skill2.resource_type = "mana"
	
	# Try to cast both
	var cast1 = SkillCastClass.new(skill1, caster)
	var cast2 = SkillCastClass.new(skill2, caster)
	
	# First should succeed
	assert_true(cast1.claim_resources())
	assert_eq(caster.get_available_resource("mana"), 20.0)
	
	# Second should fail - not enough resources
	assert_false(cast2.claim_resources())
	assert_eq(caster.get_locked_resource("mana"), 30.0)  # Only first spell locked

func test_instant_vs_cast_time() -> void:
	# Setup
	var StatProjectorClass = preload("res://src/skills/stat_projector.gd")
	var caster = preload("res://src/battle/battle_unit.gd").new()
	caster.stats = {"mana": 100.0}
	caster.stat_projectors["mana"] = StatProjectorClass.new()
	
	var SkillCastClass = preload("res://src/skills/skill_cast.gd")
	
	# Instant cast skill
	var instant_skill = preload("res://src/battle/battle_skill.gd").new()
	instant_skill.skill_name = "Instant"
	instant_skill.cast_time = 0.0
	
	var instant_cast = SkillCastClass.new(instant_skill, caster)
	assert_true(instant_cast.claim_resources())
	assert_true(instant_cast.is_ready())
	
	# Cast time skill
	var slow_skill = preload("res://src/battle/battle_skill.gd").new()
	slow_skill.skill_name = "Slow Cast"
	slow_skill.cast_time = 2.0
	
	var slow_cast = SkillCastClass.new(slow_skill, caster)
	assert_true(slow_cast.claim_resources())
	assert_false(slow_cast.is_ready())
	assert_almost_eq(slow_cast.get_cast_progress(), 0.0, 0.1)