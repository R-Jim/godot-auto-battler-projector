extends GutTest

var projector: StatProjector

func before_each():
    projector = StatProjector.new()
    watch_signals(projector)

func test_add_modifier_returns_modifier():
    var mod = StatProjector.StatModifier.new("test", StatProjector.ModifierOp.ADD, 10.0, 0, [], -1.0)
    var result = projector.add_modifier(mod)
    assert_eq(result, mod)
    assert_signal_emitted(projector, "stat_calculation_changed")

func test_add_modifier_with_empty_id_fails():
    var mod = StatProjector.StatModifier.new("", StatProjector.ModifierOp.ADD, 10.0, 0, [], -1.0)
    var result = projector.add_modifier(mod)
    assert_null(result)

func test_calculate_stat_with_no_modifiers():
    var base = 100.0
    var result = projector.calculate_stat(base)
    assert_eq(result, base)

func test_calculate_stat_with_flat_modifier():
    var base = 100.0
    projector.add_flat_modifier("buff", 50.0)
    var result = projector.calculate_stat(base)
    assert_eq(result, 150.0)

func test_calculate_stat_with_percentage_modifier():
    var base = 100.0
    projector.add_percentage_modifier("double", 2.0)
    var result = projector.calculate_stat(base)
    assert_eq(result, 200.0)

func test_calculate_stat_with_override_modifier():
    var base = 100.0
    projector.set_override("override", 75.0)
    var result = projector.calculate_stat(base)
    assert_eq(result, 75.0)

func test_modifier_priority_ordering():
    var base = 100.0
    # Higher priority executes first
    projector.add_percentage_modifier("mul_high", 2.0, 10)  # Priority 10
    projector.add_flat_modifier("add_low", 50.0, 5)    # Priority 5
    var result = projector.calculate_stat(base)
    # High priority mul first: 100 * 2 = 200
    # Then low priority add: 200 + 50 = 250
    assert_eq(result, 250.0)

func test_modifier_insertion_order_tiebreaker():
    var base = 100.0
    projector.add_flat_modifier("first", 10.0, 5)
    projector.add_flat_modifier("second", 20.0, 5)
    var result = projector.calculate_stat(base)
    # Both have same priority, so insertion order matters
    # 100 + 10 + 20 = 130
    assert_eq(result, 130.0)

func test_remove_modifier_by_instance():
    var base = 100.0
    var mod = projector.add_flat_modifier("buff", 50.0)
    assert_eq(projector.calculate_stat(base), 150.0)
    
    projector.remove_modifier(mod)
    assert_eq(projector.calculate_stat(base), 100.0)
    assert_signal_emitted(projector, "stat_calculation_changed")

func test_remove_modifiers_by_id():
    var base = 100.0
    projector.add_flat_modifier("buff", 20.0)
    projector.add_flat_modifier("buff", 30.0)
    projector.add_flat_modifier("debuff", -10.0)
    
    var removed = projector.remove_modifiers_by_id("buff")
    assert_eq(removed.size(), 2)
    assert_eq(projector.calculate_stat(base), 90.0)  # 100 - 10

func test_remove_modifiers_by_applies_to():
    var base = 100.0
    projector.add_flat_modifier("buff1", 10.0, 0, ["physical"])
    projector.add_flat_modifier("buff2", 20.0, 0, ["magical"])
    projector.add_flat_modifier("buff3", 30.0, 0, ["physical", "fire"])
    
    var removed = projector.remove_modifiers_by_applies_to("physical")
    assert_eq(removed.size(), 2)
    assert_eq(projector.calculate_stat(base), 120.0)  # 100 + 20

func test_prune_expired_modifiers():
    var base = 100.0
    var current_time = Time.get_unix_time_from_system()
    
    projector.add_flat_modifier("permanent", 10.0, 0, [], -1.0)
    projector.add_flat_modifier("expired", 20.0, 0, [], current_time - 1.0)
    projector.add_flat_modifier("future", 30.0, 0, [], current_time + 1000.0)
    
    var removed = projector.prune_expired(current_time)
    assert_eq(removed.size(), 1)
    assert_eq(projector.calculate_stat(base), 140.0)  # 100 + 10 + 30

func test_clear_all_modifiers():
    projector.add_flat_modifier("buff1", 10.0)
    projector.add_flat_modifier("buff2", 20.0)
    projector.add_percentage_modifier("mul", 2.0)
    
    projector.clear()
    assert_eq(projector.calculate_stat(100.0), 100.0)
    assert_signal_emitted(projector, "stat_calculation_changed")

func test_has_modifier():
    assert_false(projector.has_modifier("test"))
    projector.add_flat_modifier("test", 10.0)
    assert_true(projector.has_modifier("test"))

func test_get_modifiers_for_id():
    projector.add_flat_modifier("buff", 10.0)
    projector.add_flat_modifier("buff", 20.0)
    projector.add_flat_modifier("other", 30.0)
    
    var buff_mods = projector.get_modifiers_for_id("buff")
    assert_eq(buff_mods.size(), 2)
    
    var other_mods = projector.get_modifiers_for_id("other")
    assert_eq(other_mods.size(), 1)
    
    var none_mods = projector.get_modifiers_for_id("nonexistent")
    assert_eq(none_mods.size(), 0)

func test_list_modifiers():
    var mod1 = projector.add_flat_modifier("buff1", 10.0)
    var mod2 = projector.add_percentage_modifier("mul", 2.0)
    
    var all_mods = projector.list_modifiers()
    assert_eq(all_mods.size(), 2)
    assert_true(all_mods.has(mod1))
    assert_true(all_mods.has(mod2))

func test_applies_to_filter():
    var base = 100.0
    projector.add_flat_modifier("physical_buff", 20.0, 0, ["physical"])
    projector.add_flat_modifier("magical_buff", 30.0, 0, ["magical"])
    projector.add_flat_modifier("general_buff", 10.0, 0, [])  # Applies to all
    
    # No filter - all modifiers apply
    assert_eq(projector.calculate_stat(base), 160.0)  # 100 + 20 + 30 + 10
    
    # Physical filter
    assert_eq(projector.calculate_stat(base, "physical"), 130.0)  # 100 + 20 + 10
    
    # Magical filter
    assert_eq(projector.calculate_stat(base, "magical"), 140.0)  # 100 + 30 + 10
    
    # Unknown filter - only general modifiers apply
    assert_eq(projector.calculate_stat(base, "fire"), 110.0)  # 100 + 10

func test_complex_modifier_chain():
    var base = 100.0
    # Order matters! Higher priority first
    projector.set_override("override", 50.0, 20)        # Pri 20: Set to 50
    projector.add_percentage_modifier("double", 2.0, 15)    # Pri 15: 50 * 2 = 100  
    projector.add_flat_modifier("buff", 25.0, 10)       # Pri 10: 100 + 25 = 125
    projector.add_percentage_modifier("reduce", 0.8, 5)     # Pri 5: 125 * 0.8 = 100
    
    var result = projector.calculate_stat(base)
    assert_eq(result, 100.0)

func test_signal_payload_structure():
    var base = 100.0
    # Get initial projection to set _last_base
    var initial = projector.calculate_stat(base)
    assert_eq(initial, base)
    
    projector.connect("stat_calculation_changed", _on_stat_calculation_changed_test)
    
    # Test add
    gut.p("=== Testing add signal ===")
    _test_payload = null
    var mod = projector.add_flat_modifier("test", 50.0)
    assert_not_null(_test_payload)
    assert_eq(_test_payload.old_value, 100.0)
    assert_eq(_test_payload.added.size(), 1)
    assert_eq(_test_payload.added[0], mod)
    assert_eq(_test_payload.removed.size(), 0)
    
    # Test remove
    gut.p("=== Testing remove signal ===")
    _test_payload = null
    projector.remove_modifier(mod)
    assert_not_null(_test_payload)
    assert_eq(_test_payload.old_value, 150.0)
    assert_eq(_test_payload.added.size(), 0)
    assert_eq(_test_payload.removed.size(), 1)
    assert_eq(_test_payload.removed[0], mod)

var _test_payload = null
func _on_stat_calculation_changed_test(payload: Dictionary):
    _test_payload = payload

func test_modifier_validation():
    # Test with null
    var result = projector.add_modifier(null)
    assert_null(result)
    
    # Remove null should not crash
    projector.remove_modifier(null)
    assert_true(true)  # If we got here, it didn't crash

func test_cache_invalidation_on_base_change():
    projector.add_percentage_modifier("double", 2.0)
    
    var result1 = projector.calculate_stat(100.0)
    assert_eq(result1, 200.0)
    
    var result2 = projector.calculate_stat(50.0)
    assert_eq(result2, 100.0)
    
    # Should recalculate with new base
    var result3 = projector.calculate_stat(100.0)
    assert_eq(result3, 200.0)
