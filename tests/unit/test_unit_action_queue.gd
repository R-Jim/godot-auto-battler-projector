extends GutTest

var queue: UnitActionQueue
var fast_unit: BattleUnit
var slow_unit: BattleUnit

func before_each() -> void:
	queue = UnitActionQueue.new()
	
	# Create fast unit
	fast_unit = BattleUnit.new()
	fast_unit.unit_name = "Fast"
	fast_unit.team = 1
	fast_unit.stats = {
		"health": 100.0,
		"max_health": 100.0,
		"speed": 10.0,
		"initiative": 5.0
	}
	
	for stat_name in fast_unit.stats.keys():
		fast_unit.stat_projectors[stat_name] = StatProjector.new()
	
	# Create slow unit
	slow_unit = BattleUnit.new()
	slow_unit.unit_name = "Slow"
	slow_unit.team = 2
	slow_unit.stats = {
		"health": 100.0,
		"max_health": 100.0,
		"speed": 3.0,
		"initiative": 2.0
	}
	
	for stat_name in slow_unit.stats.keys():
		slow_unit.stat_projectors[stat_name] = StatProjector.new()

func after_each() -> void:
	if fast_unit:
		fast_unit.queue_free()
	if slow_unit:
		slow_unit.queue_free()

func test_register_unit() -> void:
	queue.register_unit(fast_unit)
	
	assert_eq(queue.registered_units.size(), 1)
	assert_has(queue.registered_units, fast_unit)

func test_unregister_unit() -> void:
	queue.register_unit(fast_unit)
	queue.register_unit(slow_unit)
	
	queue.unregister_unit(fast_unit)
	
	assert_eq(queue.registered_units.size(), 1)
	assert_does_not_have(queue.registered_units, fast_unit)

func test_action_priority_calculation() -> void:
	var fast_priority = queue.calculate_action_priority(fast_unit)
	var slow_priority = queue.calculate_action_priority(slow_unit)
	
	assert_gt(fast_priority, slow_priority, "Fast unit should have higher priority")

func test_get_next_actor() -> void:
	queue.register_unit(fast_unit)
	queue.register_unit(slow_unit)
	
	# Force both units to be ready
	queue.force_unit_action(fast_unit)
	queue.force_unit_action(slow_unit)
	
	var next_actor = queue.get_next_actor()
	assert_eq(next_actor, fast_unit, "Fast unit should act first")

func test_action_delay_calculation() -> void:
	queue.base_action_delay = 1.0
	queue.speed_scaling_factor = 0.1
	queue.register_unit(fast_unit)
	queue.register_unit(slow_unit)
	
	# Force action and check delays
	queue.force_unit_action(fast_unit)
	queue.force_unit_action(slow_unit)
	
	# Get action order to trigger timer updates
	var action_order = queue.get_action_order()
	
	var fast_delay = queue.get_time_until_next_action(fast_unit)
	var slow_delay = queue.get_time_until_next_action(slow_unit)
	
	assert_lt(fast_delay, slow_delay, "Fast unit should have shorter delay")

func test_status_modifiers() -> void:
	# Add haste status
	var haste_status = StatusEffect.new()
	haste_status.id = "haste"
	fast_unit.add_status_effect(haste_status)
	
	# Add slow status
	var slow_status = StatusEffect.new()
	slow_status.id = "slow"
	slow_unit.add_status_effect(slow_status)
	
	var hasted_priority = queue.calculate_action_priority(fast_unit)
	var slowed_priority = queue.calculate_action_priority(slow_unit)
	
	# Priority calculations should reflect status effects
	assert_gt(hasted_priority, 0.0)
	assert_true(slowed_priority >= 0.0, "Slowed priority should be >= 0")  # Might be 0 if stunned

func test_dead_units_excluded() -> void:
	queue.register_unit(fast_unit)
	queue.register_unit(slow_unit)
	
	# Kill one unit
	slow_unit.stats.health = 0.0
	
	var action_order = queue.get_action_order()
	
	# Only alive units should be in action order
	assert_eq(action_order.size(), 1)
	assert_eq(action_order[0].unit, fast_unit)

func test_force_unit_action() -> void:
	queue.register_unit(fast_unit)
	
	# Initially unit should not be ready
	var initial_delay = queue.get_time_until_next_action(fast_unit)
	assert_gt(initial_delay, 0.0)
	
	# Force action
	queue.force_unit_action(fast_unit)
	
	# Unit should be ready immediately
	var action_order = queue.get_action_order()
	assert_eq(action_order.size(), 1)
	assert_eq(action_order[0].unit, fast_unit)

func test_average_action_rate() -> void:
	queue.register_unit(fast_unit)
	queue.register_unit(slow_unit)
	
	var avg_rate = queue.get_average_action_rate()
	assert_gt(avg_rate, 0.0, "Average action rate should be positive")

func test_action_timeline() -> void:
	queue.register_unit(fast_unit)
	queue.register_unit(slow_unit)
	
	var timeline = queue.get_action_timeline(5.0)
	
	assert_gt(timeline.size(), 0, "Timeline should have entries")
	
	# Fast unit should appear more often
	var fast_count = 0
	var slow_count = 0
	
	for entry in timeline:
		if entry.unit == fast_unit:
			fast_count += 1
		elif entry.unit == slow_unit:
			slow_count += 1
	
	assert_gt(fast_count, slow_count, "Fast unit should act more frequently")