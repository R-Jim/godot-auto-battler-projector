extends GutTest

func before_each():
    BattleEvents.clear_events()

func test_record_skill_cast():
    # Create test unit and skill
    var test_unit = BattleUnit.new()
    test_unit.name = "test_unit"
    test_unit.stats.mana = 100.0
    
    var target_unit = BattleUnit.new()
    target_unit.name = "target_unit"
    target_unit.stats.health = 100.0
    
    var test_skill = BattleSkill.new()
    test_skill.skill_name = "Fireball"
    test_skill.resource_path = "res://skills/fireball.gd"
    test_skill.resource_cost = 20.0
    test_skill.resource_type = "mana"
    test_skill.base_damage = 25.0
    
    # Record skill cast
    var targets: Array[BattleUnit] = []
    targets.append(target_unit)
    BattleEvents.record_skill_cast(
        test_unit,
        targets,
        test_skill,
        {"damage": 25.0}
    )
    
    # Verify event
    var events = BattleEvents.get_events()
    assert_eq(events.size(), 1, "Should have one event")
    
    var event = events[0]
    assert_eq(event.type, BattleEvents.EventType.SKILL_CAST)
    assert_eq(event.caster, "test_unit")
    assert_eq(event.targets[0], "target_unit")
    var payload = event.payload
    var read_payload = payload["read"]
    var write_payload = payload["write"]
    assert_eq(write_payload["skill"]["name"], "Fireball")
    assert_eq(write_payload["data"]["damage"], 25.0)
    assert_eq(read_payload["source"]["projected_stats"]["mana"], 100.0)
    assert_eq(read_payload["targets"][0]["projected_stats"]["health"], 100.0)

func test_save_load_events():
    # Create test unit and skill
    var test_unit = BattleUnit.new()
    test_unit.name = "test_unit"
    test_unit.stats.mana = 100.0
    
    var target_unit = BattleUnit.new()
    target_unit.name = "target_unit"
    target_unit.stats.health = 100.0
    
    var test_skill = BattleSkill.new()
    test_skill.skill_name = "Fireball"
    test_skill.resource_path = "res://skills/fireball.gd"
    test_skill.resource_cost = 20.0
    test_skill.resource_type = "mana"
    test_skill.base_damage = 25.0
    
    # Record some events
    var targets: Array[BattleUnit] = []
    targets.append(target_unit)
    BattleEvents.record_skill_cast(
        test_unit,
        targets,
        test_skill,
        {"damage": 25.0}
    )
    
    # Save events
    var temp_path = "user://test_events.json"
    var err = BattleEvents.save_events(temp_path)
    assert_eq(err, OK, "Should save events successfully")
    
    # Clear events
    BattleEvents.clear_events()
    assert_eq(BattleEvents.get_events().size(), 0, "Events should be cleared")
    
    # Load events
    err = BattleEvents.load_events(temp_path)
    assert_eq(err, OK, "Should load events successfully")
    
    # Verify loaded events
    var events = BattleEvents.get_events()
    assert_eq(events.size(), 1, "Should restore one event")
    assert_eq(events[0].payload["write"]["skill"]["name"], "Fireball")
