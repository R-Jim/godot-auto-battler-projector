extends GutTest

const BattleEvent = preload("res://src/battle/battle_event.gd")

func test_event_setup():
    var event = BattleEvent.new()
    event.setup(
        BattleEvent.EventType.SKILL_CAST,
        "caster",
        "target",
        {
            "read": {
                "source": {"projected_stats": {"health": 100}},
                "targets": [{"projected_stats": {"health": 80}}]
            },
            "write": {
                "skill": {"name": "Test Skill"}
            }
        }
    )
    
    assert_eq(event.event_type, BattleEvent.EventType.SKILL_CAST)
    assert_eq(event.source_unit_id, "caster")
    assert_eq(event.target_unit_id, "target")
    assert_eq(event.data["write"]["skill"]["name"], "Test Skill")
    assert_eq(event.data["read"]["source"]["projected_stats"]["health"], 100)

func test_event_serialization():
    var event = BattleEvent.new()
    event.setup(
        BattleEvent.EventType.SKILL_CAST,
        "caster",
        "target",
        {
            "read": {
                "source": {"projected_stats": {"health": 100}},
                "targets": []
            },
            "write": {
                "skill": {"name": "Test Skill"}
            }
        }
    )
    
    var serialized = event.serialize()
    
    var new_event = BattleEvent.new()
    new_event.deserialize(serialized)
    
    assert_eq(new_event.event_type, event.event_type)
    assert_eq(new_event.source_unit_id, event.source_unit_id)
    assert_eq(new_event.data["write"]["skill"]["name"], event.data["write"]["skill"]["name"])
    assert_eq(new_event.data["read"]["source"]["projected_stats"]["health"], event.data["read"]["source"]["projected_stats"]["health"])
