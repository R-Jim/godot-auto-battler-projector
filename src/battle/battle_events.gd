extends Node

enum EventType {
    SKILL_CAST
}

var events: Array = []

signal event_recorded(event: Dictionary)

func record_skill_cast(caster: BattleUnit, targets: Array[BattleUnit], skill: BattleSkill, data: Dictionary = {}) -> void:
    var timestamp := Time.get_unix_time_from_system()
    var read_payload := {
        "source": caster.capture_battle_state(),
        "targets": targets.map(func(t): return t.capture_battle_state())
    }

    var write_payload := {
        "skill": {
            "name": skill.skill_name,
            "path": skill.resource_path
        },
        "data": data.duplicate(true) if not data.is_empty() else {}
    }

    var event := {
        "type": EventType.SKILL_CAST,
        "timestamp": timestamp,
        "caster": caster.name,
        "targets": targets.map(func(t): return t.name),
        "payload": {
            "read": read_payload,
            "write": write_payload
        }
    }

    events.append(event)
    event_recorded.emit(event)

func get_events() -> Array:
    return events.duplicate(true)

func clear_events() -> void:
    events.clear()

# Load/Save events for replay
func save_events(path: String) -> Error:
    var file = FileAccess.open(path, FileAccess.WRITE)
    if not file:
        push_error("Failed to open file for writing: " + path)
        return FileAccess.get_open_error()
        
    file.store_string(JSON.stringify(events))
    return OK

func load_events(path: String) -> Error:
    var file = FileAccess.open(path, FileAccess.READ)
    if not file:
        push_error("Failed to open file for reading: " + path)
        return FileAccess.get_open_error()
        
    var json = JSON.parse_string(file.get_as_text())
    if json == null:
        push_error("Failed to parse events JSON from file: " + path)
        return ERR_PARSE_ERROR
        
    events = json
    return OK
