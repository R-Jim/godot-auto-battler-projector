class_name UnitActionQueue
extends RefCounted

# Priority queue for managing unit action order
var priority_queue: Array[Dictionary] = []
var registered_units: Array[BattleUnit] = []

# Configuration
var base_action_delay: float = 1.0  # Base time between actions
var speed_scaling_factor: float = 0.1  # How much speed affects action rate

# Internal state
var _last_update_time: float = 0.0
var _unit_timers: Dictionary = {}  # Unit -> next action time

func register_unit(unit: BattleUnit) -> void:
    if not registered_units.has(unit):
        registered_units.append(unit)
        _unit_timers[unit] = 0.0
        _update_unit_in_queue(unit)

func unregister_unit(unit: BattleUnit) -> void:
    registered_units.erase(unit)
    _unit_timers.erase(unit)
    _remove_unit_from_queue(unit)

func update_unit_priority(unit: BattleUnit) -> void:
    if registered_units.has(unit):
        _update_unit_in_queue(unit)

func get_action_order() -> Array[Dictionary]:
    var current_time = Time.get_unix_time_from_system()
    var ready_units: Array[Dictionary] = []
    
    # Update all unit timers
    for unit in registered_units:
        if not unit.is_alive():
            continue
        
        if _is_unit_ready(unit, current_time):
            var priority = calculate_action_priority(unit)
            ready_units.append({
                "unit": unit,
                "priority": priority
            })
    
    # Sort by priority (higher first)
    ready_units.sort_custom(func(a, b): return a.priority > b.priority)
    
    # Update timers for units that will act
    for unit_data in ready_units:
        _reset_unit_timer(unit_data.unit, current_time)
    
    return ready_units

func calculate_action_priority(unit: BattleUnit) -> float:
    var speed = unit.get_projected_stat("speed")
    var initiative = unit.get_projected_stat("initiative")
    
    # Base priority from stats
    var base_priority = speed * 2.0 + initiative
    
    # Factor in current conditions
    var condition_modifier = _calculate_condition_modifier(unit)
    
    # Factor in skill readiness
    var skill_urgency = _calculate_skill_urgency(unit)
    
    return (base_priority * condition_modifier + skill_urgency) / 3.0

func get_next_actor() -> BattleUnit:
    var action_order = get_action_order()
    if action_order.is_empty():
        return null
    return action_order[0].unit

func get_time_until_next_action(unit: BattleUnit) -> float:
    if not _unit_timers.has(unit):
        return INF
    
    var current_time = Time.get_unix_time_from_system()
    var next_action_time = _unit_timers[unit]
    
    if current_time >= next_action_time:
        return _calculate_action_delay(unit)

    return max(0.0, next_action_time - current_time)

func force_unit_action(unit: BattleUnit) -> void:
    # Force a unit to act immediately (for reactions/interrupts)
    if registered_units.has(unit):
        _unit_timers[unit] = Time.get_unix_time_from_system()

# Internal methods
func _is_unit_ready(unit: BattleUnit, current_time: float) -> bool:
    if not _unit_timers.has(unit):
        return false
    
    return current_time >= _unit_timers[unit]

func _reset_unit_timer(unit: BattleUnit, current_time: float) -> void:
    _unit_timers[unit] = current_time + _calculate_action_delay(unit)

func _calculate_condition_modifier(unit: BattleUnit) -> float:
    var modifier: float = 1.0
    
    # Health-based urgency
    var health_percent = unit.get_health_percentage()
    if health_percent < 0.3:
        modifier *= 1.2  # Act faster when in danger
    
    # Status effects
    if unit.has_status("enraged"):
        modifier *= 1.3
    elif unit.has_status("stunned") or unit.has_status("frozen"):
        modifier *= 0.0  # Can't act
    
    return modifier

func _calculate_skill_urgency(unit: BattleUnit) -> float:
    var urgency: float = 0.0
    
    # Check if unit has important skills ready
    for skill in unit.skills:
        if not skill.can_use(unit):
            continue
        
        # High urgency for certain skill types
        if skill.has_tag("interrupt"):
            urgency = max(urgency, 50.0)
        elif skill.has_tag("emergency") and unit.get_health_percentage() < 0.3:
            urgency = max(urgency, 40.0)
        elif skill.has_tag("finisher"):
            # Check if any enemy is low health
            var has_low_health_enemy = false
            for other_unit in registered_units:
                if other_unit.team != unit.team and other_unit.get_health_percentage() < 0.2:
                    has_low_health_enemy = true
                    break
            
            if has_low_health_enemy:
                urgency = max(urgency, 35.0)
    
    return urgency

func _update_unit_in_queue(unit: BattleUnit) -> void:
    # This is called when a unit's priority might have changed
    # In our implementation, we recalculate on demand, so this is a no-op
    pass

func _remove_unit_from_queue(unit: BattleUnit) -> void:
    # Clean up any references to the unit
    # In our implementation, we check unit validity on demand
    pass

# Analysis methods for AI and debugging
func get_action_timeline(duration: float = 5.0) -> Array[Dictionary]:
    var timeline: Array[Dictionary] = []
    var current_time = Time.get_unix_time_from_system()
    var end_time = current_time + duration
    
    # Create a copy of current timers
    var simulated_timers = _unit_timers.duplicate()
    var simulated_time = current_time
    
    while simulated_time < end_time:
        # Find next unit to act
        var next_unit = null
        var next_time = INF
        
        for unit in registered_units:
            if not unit.is_alive():
                continue
            
            var unit_time = simulated_timers.get(unit, INF)
            if unit_time < next_time:
                next_time = unit_time
                next_unit = unit
        
        if next_unit == null or next_time > end_time:
            break
        
        # Record this action
        timeline.append({
            "time": next_time - current_time,
            "unit": next_unit,
            "priority": calculate_action_priority(next_unit)
        })
        
        # Update simulation
        simulated_time = next_time
        var delay = _calculate_action_delay(next_unit)
        simulated_timers[next_unit] = simulated_time + delay
    
    return timeline

func get_average_action_rate() -> float:
    if registered_units.is_empty():
        return 0.0
    
    var total_rate: float = 0.0
    
    for unit in registered_units:
        if unit.is_alive():
            var delay = _calculate_action_delay(unit)
            if delay > 0.0:
                total_rate += 1.0 / delay

    return total_rate / registered_units.size()

func _calculate_action_delay(unit: BattleUnit) -> float:
    var speed = unit.get_projected_stat("speed")
    var action_delay = base_action_delay / (1.0 + speed * speed_scaling_factor)

    if unit.has_status("haste"):
        action_delay *= 0.75
    elif unit.has_status("slow"):
        action_delay *= 1.5

    return max(0.0001, action_delay)

# Debug method
func debug_print_queue() -> void:
    print("\n=== Action Queue State ===")
    var action_order = get_action_order()
    
    if action_order.is_empty():
        print("No units ready to act")
    else:
        print("Ready units:")
        for i in range(min(5, action_order.size())):
            var data = action_order[i]
            print("  %d. %s (Priority: %.1f)" % [i+1, data.unit.unit_name, data.priority])
    
    print("\nNext action times:")
    var current_time = Time.get_unix_time_from_system()
    for unit in registered_units:
        if unit.is_alive():
            var time_until = get_time_until_next_action(unit)
            print("  %s: %.1fs" % [unit.unit_name, time_until])
