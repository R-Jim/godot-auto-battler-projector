extends GutTest

const BattleEvent = preload("res://battle_event.gd")

var test_event: BattleEvent

func before_each():
    test_event = BattleEvent.new()

func test_event_setup():
    # Setup basic event
    test_event.setup(
        BattleEvent.EventType.SKILL_CAST,
        "unit1",
        "unit2",
        {
            "read": {
                "source": {},
                "targets": []
            },
            "write": {
                "skill": {"name": "Fireball"},
                "damage": 25.0
            }
        },
        1,  # round
        0   # turn order
    )
    
    # Verify setup
    assert_eq(test_event.event_type, BattleEvent.EventType.SKILL_CAST)
    assert_eq(test_event.source_unit_id, "unit1")
    assert_eq(test_event.target_unit_id, "unit2")
    assert_eq(test_event.data["write"]["skill"]["name"], "Fireball")
    assert_eq(test_event.round, 1)
    assert_eq(test_event.turn_order, 0)

func test_event_serialization():
    # Setup event
    test_event.setup(
        BattleEvent.EventType.SKILL_CAST,
        "unit1",
        "unit2",
        {
            "read": {
                "source": {},
                "targets": []
            },
            "write": {
                "skill": {"name": "Fireball"},
                "damage": 25.0
            }
        },
        1,
        0
    )
    
    # Serialize
    var serialized = test_event.serialize()
    
    # Create new event and deserialize
    var new_event = BattleEvent.new()
    new_event.deserialize(serialized)
    
    # Verify deserialized data
    assert_eq(new_event.event_type, test_event.event_type)
    assert_eq(new_event.source_unit_id, test_event.source_unit_id)
    assert_eq(new_event.data["write"]["skill"]["name"], test_event.data["write"]["skill"]["name"])
    assert_eq(new_event.round, test_event.round)
    assert_eq(new_event.turn_order, test_event.turn_order)
