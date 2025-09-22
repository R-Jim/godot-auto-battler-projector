extends GutTest

const BattleEventManager = preload("res://battle_event_manager.gd")
const BattleEvent = preload("res://battle_event.gd")
const BattleUnit = preload("res://battle_unit.gd")
const BattleSkill = preload("res://battle_skill.gd")
const BattleContext = preload("res://battle_context.gd")
const SkillActivationObserver = preload("res://skill_activation_observer.gd")

var event_manager: BattleEventManager
var battle_context: BattleContext
var skill_observer: SkillActivationObserver
var test_unit: BattleUnit
var target_unit: BattleUnit
var test_skill: BattleSkill

func before_each():
    # Setup event manager and context
    event_manager = BattleEventManager.new()
    battle_context = BattleContext.new()
    skill_observer = SkillActivationObserver.new()
    add_child(event_manager)
    
    # Setup test units
    test_unit = BattleUnit.new()
    test_unit.name = "test_unit"
    test_unit.stats.initiative = 10.0
    test_unit.stats.mana = 100.0
    
    target_unit = BattleUnit.new()
    target_unit.name = "target_unit"
    target_unit.stats.initiative = 5.0
    target_unit.stats.health = 100.0
    
    # Setup battle context
    battle_context.all_units = [test_unit, target_unit]
    battle_context.current_round = 1
    
    # Setup test skill
    test_skill = BattleSkill.new()
    test_skill.skill_name = "Fireball"
    test_skill.resource_path = "res://skills/fireball.gd"
    test_skill.cast_time = 1.0
    test_skill.resource_cost = 20.0
    test_skill.resource_type = "mana"
    test_skill.base_damage = 25.0
    
    # Connect systems
    event_manager.set_battle_context(battle_context)
    event_manager.connect_skill_observer(skill_observer)

func test_skill_cast_sequence():
    # Start casting skill
    var cast = test_skill.prepare_cast(test_unit)
    var targets: Array[BattleUnit] = []
    targets.append(target_unit)
    cast.targets = targets
    cast.claim_resources()  # This triggers SKILL_CAST_STARTED
    skill_observer.emit_signal("skill_initiated", cast)
    
    # Verify cast started event
    var events = event_manager.get_events()
    assert_eq(events.size(), 1, "Should have one event")
    assert_eq(events[0].event_type, BattleEvent.EventType.SKILL_CAST_STARTED)
    var start_write = events[0].data["write"]
    assert_eq(start_write["resources_claimed"]["mana"], 20.0)
    
    # Update progress
    skill_observer.emit_signal("cast_progress_updated", test_unit, 0.5)
    events = event_manager.get_events()
    assert_eq(events.size(), 2, "Should have progress event")
    assert_eq(events[1].event_type, BattleEvent.EventType.SKILL_CAST_PROGRESS)
    var progress_write = events[1].data["write"]
    assert_eq(progress_write["progress"], 0.5)
    
    # Complete cast
    cast.execute(null)  # No rule processor needed for test
    skill_observer.emit_signal("skill_completed", cast)
    events = event_manager.get_events()
    assert_eq(events.size(), 3, "Should have complete event")
    assert_eq(events[2].event_type, BattleEvent.EventType.SKILL_CAST_COMPLETE)
    var complete_write = events[2].data["write"]
    assert_eq(complete_write["execution"].size(), 1, "Execution log should contain target result")
    assert_eq(complete_write["execution"][0]["write"]["effect"]["effect_type"], "damage")
    
    # Verify ordering through round sequence
    var round_events = event_manager.get_events_in_turn_order(battle_context.current_round)
    var source_events = round_events.filter(func(e): return e.source_unit_id == test_unit.name)
    assert_eq(source_events.size(), 3, "All events should be recorded for the source unit")
    assert_eq(source_events[0].event_type, BattleEvent.EventType.SKILL_CAST_STARTED)
    assert_eq(source_events[1].event_type, BattleEvent.EventType.SKILL_CAST_PROGRESS)
    assert_eq(source_events[2].event_type, BattleEvent.EventType.SKILL_CAST_COMPLETE)

func test_skill_interrupt():
    # Start casting
    var cast = test_skill.prepare_cast(test_unit)
    var targets: Array[BattleUnit] = []
    targets.append(target_unit)
    cast.targets = targets
    cast.claim_resources()
    skill_observer.emit_signal("skill_initiated", cast)
    
    # Update progress
    skill_observer.emit_signal("cast_progress_updated", test_unit, 0.3)
    
    # Interrupt cast
    cast.interrupt()
    skill_observer.emit_signal("skill_interrupted", cast)
    
    # Verify events ordering within the round
    var round_events = event_manager.get_events_in_turn_order(battle_context.current_round)
    var source_events = round_events.filter(func(e): return e.source_unit_id == test_unit.name)
    assert_eq(source_events.size(), 3, "Should have start, progress, and interrupt events")
    assert_eq(source_events[2].event_type, BattleEvent.EventType.SKILL_CAST_INTERRUPT)
    var interrupt_write = source_events[2].data["write"]
    assert_true(is_equal_approx(interrupt_write["progress"], cast.get_cast_progress()))
    assert_eq(interrupt_write["resources_refunded"]["mana"], 20.0)

func test_turn_order():
    # Set different initiatives
    test_unit.stats.initiative = 15.0
    target_unit.stats.initiative = 10.0
    var third_unit = BattleUnit.new()
    third_unit.name = "third_unit"
    third_unit.stats.initiative = 5.0
    battle_context.all_units.append(third_unit)
    
    # Cast skills in different order
    var cast1 = test_skill.prepare_cast(third_unit)  # Lowest initiative
    var targets1: Array[BattleUnit] = []
    targets1.append(target_unit)
    cast1.targets = targets1
    cast1.claim_resources()
    skill_observer.emit_signal("skill_initiated", cast1)
    
    var cast2 = test_skill.prepare_cast(test_unit)  # Highest initiative
    var targets2: Array[BattleUnit] = []
    targets2.append(target_unit)
    cast2.targets = targets2
    cast2.claim_resources()
    skill_observer.emit_signal("skill_initiated", cast2)
    
    # Get events in turn order
    var round_events = event_manager.get_events_in_turn_order(1)
    assert_eq(round_events[0].source_unit_id, "test_unit", "Highest initiative should go first")
    assert_eq(round_events[1].source_unit_id, "third_unit", "Lowest initiative should go last")
