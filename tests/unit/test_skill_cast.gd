extends GutTest

var caster: BattleUnit
var target: BattleUnit
var skill: BattleSkill
var rule_processor: BattleRuleProcessor

func before_each() -> void:
    caster = BattleUnit.new()
    caster.stats = {
        "health": 100.0,
        "max_health": 100.0,
        "attack": 20.0,
        "defense": 10.0,
        "speed": 5.0,
        "mana": 50.0
    }
    
    # Initialize projectors for stats
    for stat_name in caster.stats.keys():
        caster.stat_projectors[stat_name] = StatProjector.new()
    
    target = BattleUnit.new()
    target.stats = {
        "health": 80.0,
        "max_health": 80.0,
        "attack": 15.0,
        "defense": 5.0,
        "speed": 6.0
    }
    
    for stat_name in target.stats.keys():
        target.stat_projectors[stat_name] = StatProjector.new()
    
    skill = BattleSkill.new()
    skill.skill_name = "Test Spell"
    skill.base_damage = 30.0
    skill.resource_cost = 20.0
    skill.resource_type = "mana"
    skill.cooldown = 5.0
    
    rule_processor = BattleRuleProcessor.new()
    rule_processor.skip_auto_load = true
    rule_processor.rules = []

func test_skill_cast_claims_resources() -> void:
    # Create a skill cast
    var cast = skill.prepare_cast(caster)
    
    # Claim resources
    assert_true(cast.claim_resources())
    assert_true(cast.is_committed)
    
    # Verify resources are locked
    assert_eq(caster.get_locked_resource("mana"), 20.0)
    assert_eq(caster.get_available_resource("mana"), 30.0)  # 50 - 20 locked
    assert_eq(caster.stats.mana, 50.0)  # Not deducted yet

func test_skill_cast_prevents_double_claiming() -> void:
    var cast = skill.prepare_cast(caster)
    
    # First claim should succeed
    assert_true(cast.claim_resources())
    
    # Second claim should fail
    assert_false(cast.claim_resources())

func test_skill_cast_prevents_overclaiming() -> void:
    # Create two expensive skills
    var skill1 = skill.clone()
    skill1.resource_cost = 30.0
    
    var skill2 = skill.clone()
    skill2.resource_cost = 30.0
    
    var cast1 = skill1.prepare_cast(caster)
    var cast2 = skill2.prepare_cast(caster)
    
    # First cast should succeed
    assert_true(cast1.claim_resources())
    assert_eq(caster.get_locked_resource("mana"), 30.0)
    
    # Second cast should fail (would need 60 total, only have 50)
    assert_false(cast2.claim_resources())
    assert_eq(caster.get_locked_resource("mana"), 30.0)  # Still just 30

func test_skill_cast_refund() -> void:
    var cast = skill.prepare_cast(caster)
    
    # Claim resources
    assert_true(cast.claim_resources())
    assert_eq(caster.get_locked_resource("mana"), 20.0)
    
    # Refund
    cast.refund()
    assert_false(cast.is_committed)
    assert_true(cast.is_cancelled)
    assert_eq(caster.get_locked_resource("mana"), 0.0)
    assert_eq(caster.stats.mana, 50.0)  # Unchanged

func test_skill_cast_execute() -> void:
    var cast = skill.prepare_cast(caster)
    cast.targets.append(target)
    
    # Claim resources
    assert_true(cast.claim_resources())
    
    # Execute
    assert_true(cast.execute(rule_processor))
    
    # Verify resources were consumed
    assert_eq(caster.stats.mana, 30.0)  # 50 - 20
    assert_eq(caster.get_locked_resource("mana"), 0.0)
    
    # Verify cooldown was set
    assert_true(skill.is_on_cooldown())

func test_skill_cast_execute_without_claim_fails() -> void:
    var cast = skill.prepare_cast(caster)
    cast.targets = [target]
    
    # Try to execute without claiming
    assert_false(cast.execute(rule_processor))

func test_skill_cast_interrupt() -> void:
    var cast = skill.prepare_cast(caster)
    
    # Claim resources
    assert_true(cast.claim_resources())
    assert_eq(caster.get_locked_resource("mana"), 20.0)
    
    # Interrupt
    cast.interrupt()
    assert_false(cast.is_committed)
    assert_true(cast.is_cancelled)
    assert_eq(caster.get_locked_resource("mana"), 0.0)

func test_skill_cast_cooldown_check() -> void:
    var cast1 = skill.prepare_cast(caster)
    cast1.targets = [target]
    
    # First cast
    assert_true(cast1.claim_resources())
    assert_true(cast1.execute(rule_processor))
    
    # Second cast should fail due to cooldown
    var cast2 = skill.prepare_cast(caster)
    assert_false(cast2.claim_resources())

func test_skill_cast_no_resources_required() -> void:
    # Create a free skill
    skill.resource_cost = 0.0
    
    var cast = skill.prepare_cast(caster)
    
    # Should be able to claim without resources
    assert_true(cast.claim_resources())
    assert_eq(caster.get_locked_resource("mana"), 0.0)

func test_multiple_resource_types() -> void:
    # Add a second resource
    caster.stats["rage"] = 30.0
    caster.stat_projectors["rage"] = StatProjector.new()
    
    # Create skill that uses rage
    var rage_skill = skill.clone()
    rage_skill.resource_type = "rage"
    rage_skill.resource_cost = 15.0
    
    # Cast both skills
    var mana_cast = skill.prepare_cast(caster)
    var rage_cast = rage_skill.prepare_cast(caster)
    
    assert_true(mana_cast.claim_resources())
    assert_true(rage_cast.claim_resources())
    
    assert_eq(caster.get_locked_resource("mana"), 20.0)
    assert_eq(caster.get_locked_resource("rage"), 15.0)

func test_cast_progress() -> void:
    skill.cast_time = 2.0  # 2 second cast
    
    var cast = skill.prepare_cast(caster)
    
    # Before claiming
    assert_eq(cast.get_cast_progress(), 0.0)
    
    # After claiming
    assert_true(cast.claim_resources())
    
    # Immediate check (might be slightly > 0 due to execution time)
    assert_almost_eq(cast.get_cast_progress(), 0.0, 0.1)
    
    # Not ready yet
    assert_false(cast.is_ready())

func test_instant_cast() -> void:
    skill.cast_time = 0.0  # Instant cast
    
    var cast = skill.prepare_cast(caster)
    assert_true(cast.claim_resources())
    
    # Should be ready immediately
    assert_eq(cast.get_cast_progress(), 1.0)
    assert_true(cast.is_ready())
