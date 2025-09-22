extends RefCounted
class_name BattleEvent

enum EventType {
    SKILL_CAST,          # Complete skill execution with state snapshot
    SKILL_CAST_STARTED,  # Initial skill cast
    SKILL_CAST_PROGRESS, # Cast progress update
    SKILL_CAST_COMPLETE, # Cast completed successfully
    SKILL_CAST_INTERRUPT # Cast was interrupted
}

var event_type: EventType
var timestamp: float
var source_unit_id: String
var target_unit_id: String
var data: Dictionary
var round: int = -1
var turn_order: int = -1

func _init() -> void:
    timestamp = Time.get_unix_time_from_system()
    source_unit_id = ""
    target_unit_id = ""
    data = {}

func setup(type: EventType, source: String, target: String = "", event_data: Dictionary = {}, round: int = -1, turn_order: int = -1) -> void:
    event_type = type
    source_unit_id = source
    target_unit_id = target
    data = event_data.duplicate(true)
    self.round = round
    self.turn_order = turn_order

func serialize() -> Dictionary:
    return {
        "type": event_type,
        "timestamp": timestamp,
        "source": source_unit_id,
        "target": target_unit_id,
        "data": data.duplicate(true),
        "round": round,
        "turn_order": turn_order
    }

func deserialize(dict: Dictionary) -> void:
    event_type = dict["type"]
    timestamp = dict["timestamp"]
    source_unit_id = dict["source"]
    target_unit_id = dict["target"]
    data = dict["data"].duplicate(true)
    round = dict["round"]
    turn_order = dict["turn_order"]
