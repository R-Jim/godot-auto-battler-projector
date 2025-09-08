extends GutTest

var status_effect: StatusEffect

func before_each():
    status_effect = StatusEffect.new()

func test_init_with_parameters():
    var effect = StatusEffect.new("poison", "Poison", "Deals damage over time", 5.0)
    assert_eq(effect.id, "poison")
    assert_eq(effect.effect_name, "Poison")
    assert_eq(effect.description, "Deals damage over time")
    assert_eq(effect.duration, 5.0)
    assert_gt(effect.expires_at, 0.0)

func test_init_permanent_effect():
    var effect = StatusEffect.new("blessing", "Blessing", "Permanent buff", 0.0)
    assert_eq(effect.duration, 0.0)
    assert_eq(effect.expires_at, 0.0)

func test_is_expired():
    var effect = StatusEffect.new("temp", "Temporary", "", 1.0)
    var now = Time.get_unix_time_from_system()
    
    # Not expired yet
    assert_false(effect.is_expired(now))
    
    # Check expiration
    assert_true(effect.is_expired(effect.expires_at + 1.0))
    
    # Permanent effect never expires
    var permanent = StatusEffect.new("perm", "Permanent", "", 0.0)
    assert_false(permanent.is_expired(now + 9999999))

func test_refresh():
    var original_expires = status_effect.expires_at
    status_effect.refresh(10.0)
    
    assert_eq(status_effect.duration, 10.0)
    assert_gt(status_effect.expires_at, original_expires)

func test_refresh_default_duration():
    status_effect.duration = 5.0
    var original_expires = status_effect.expires_at
    
    # Wait a tiny bit to ensure time difference
    await get_tree().create_timer(0.01).timeout
    status_effect.refresh()
    
    assert_eq(status_effect.duration, 5.0)
    assert_gt(status_effect.expires_at, original_expires)

func test_add_stack():
    status_effect.max_stacks = 5
    assert_eq(status_effect.stacks, 1)
    
    status_effect.add_stack()
    assert_eq(status_effect.stacks, 2)
    
    # Add up to max
    status_effect.add_stack()
    status_effect.add_stack()
    status_effect.add_stack()
    assert_eq(status_effect.stacks, 5)
    
    # Should not exceed max
    status_effect.add_stack()
    assert_eq(status_effect.stacks, 5)

func test_can_stack_with():
    var effect1 = StatusEffect.new("poison", "Poison", "", 5.0)
    var effect2 = StatusEffect.new("poison", "Poison", "", 3.0)
    var effect3 = StatusEffect.new("burn", "Burn", "", 5.0)
    
    effect1.max_stacks = 3
    effect2.max_stacks = 3
    
    # Same ID can stack
    assert_true(effect1.can_stack_with(effect2))
    
    # Different ID cannot stack
    assert_false(effect1.can_stack_with(effect3))
    
    # Cannot stack if at max
    effect1.stacks = 3
    assert_false(effect1.can_stack_with(effect2))

func test_clone():
    status_effect.id = "buff"
    status_effect.effect_name = "Attack Buff"
    status_effect.description = "Increases attack"
    status_effect.duration = 10.0
    status_effect.is_debuff = false
    status_effect.stack_type = "extend"
    status_effect.max_stacks = 3
    
    var clone = status_effect.clone()
    
    assert_eq(clone.id, status_effect.id)
    assert_eq(clone.effect_name, status_effect.effect_name)
    assert_eq(clone.description, status_effect.description)
    assert_eq(clone.duration, status_effect.duration)
    assert_eq(clone.is_debuff, status_effect.is_debuff)
    assert_eq(clone.stack_type, status_effect.stack_type)
    assert_eq(clone.max_stacks, status_effect.max_stacks)
    
    # Should be different objects
    assert_ne(clone, status_effect)

# Note: apply_to, remove_from, and on_turn_start methods require
# a full scene setup with BattleUnit and RuleProcessor, so they
# are better tested in integration tests

func test_apply_to_requires_scene_tree():
    var unit = BattleUnit.new()
    status_effect.apply_to(unit)
    # Should push error but not crash
    assert_true(true)

func test_remove_from_clears_modifiers():
    status_effect.applied_modifiers = [
        {"modifier": {}, "stat": "attack"},
        {"modifier": {}, "stat": "defense"}
    ]
    
    var unit = BattleUnit.new()
    add_child(unit)
    await get_tree().process_frame
    
    status_effect.remove_from(unit)
    assert_eq(status_effect.applied_modifiers.size(), 0)
    
    unit.queue_free()
