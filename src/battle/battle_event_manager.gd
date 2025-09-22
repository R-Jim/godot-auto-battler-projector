class_name BattleEventManager
extends Node

const BattleEvent = preload("res://src/battle/battle_event.gd")
const BattleUnit = preload("res://src/battle/battle_unit.gd")
const BattleContext = preload("res://src/battle/battle_context.gd")
const BattleSkill = preload("res://src/battle/battle_skill.gd")
const SkillActivationObserver = preload("res://src/skills/skill_activation_observer.gd")
const SkillCast = preload("res://src/skills/skill_cast.gd")

var _context: BattleContext = null
var _skill_observer: SkillActivationObserver = null
var _events: Array[BattleEvent] = []

func _build_read_payload(source: BattleUnit, targets: Array[BattleUnit]) -> Dictionary:
    var target_snapshots: Array[Dictionary] = []
    for target in targets:
        if target == null or not target is BattleUnit:
            continue
        target_snapshots.append(target.capture_battle_state())

    return {
        "source": source.capture_battle_state() if source else {},
        "targets": target_snapshots
    }

func _duplicate_dictionary(values: Dictionary) -> Dictionary:
    if values.is_empty():
        return {}
    return values.duplicate(true)

func set_battle_context(context: BattleContext) -> void:
    _context = context

func connect_skill_observer(observer: SkillActivationObserver) -> void:
    if _skill_observer:
        _skill_observer.disconnect("skill_initiated", _on_skill_initiated)
        _skill_observer.disconnect("cast_progress_updated", _on_cast_progress_updated)
        _skill_observer.disconnect("skill_completed", _on_skill_completed)
        _skill_observer.disconnect("skill_interrupted", _on_skill_interrupted)
    
    _skill_observer = observer
    if _skill_observer:
        _skill_observer.connect("skill_initiated", _on_skill_initiated)
        _skill_observer.connect("cast_progress_updated", _on_cast_progress_updated)
        _skill_observer.connect("skill_completed", _on_skill_completed)
        _skill_observer.connect("skill_interrupted", _on_skill_interrupted)



func get_events() -> Array[BattleEvent]:
    return _events.duplicate()

func get_events_in_turn_order(round: int) -> Array[BattleEvent]:
    var round_events = _events.filter(func(e): return e.round == round)
    round_events.sort_custom(func(a, b): return a.turn_order > b.turn_order)
    return round_events

func record_skill_cast_start(source: BattleUnit, targets: Array, skill: BattleSkill, resources_claimed: Dictionary = {}) -> void:
    var normalized_targets: Array[BattleUnit] = []
    for target in targets:
        if target is BattleUnit:
            normalized_targets.append(target)

    var first_target_name: String = ""
    if normalized_targets.size() > 0:
        first_target_name = normalized_targets[0].name

    var event = BattleEvent.new()
    event.setup(
        BattleEvent.EventType.SKILL_CAST_STARTED,
        source.name,
        first_target_name,
        {
            "read": _build_read_payload(source, normalized_targets),
            "write": {
                "skill": {
                    "name": skill.skill_name,
                    "path": skill.resource_path
                },
                "resources_claimed": _duplicate_dictionary(resources_claimed)
            }
        },
        _context.current_round if _context else -1,
        source.get_turn_order() if source else -1
    )
    _events.append(event)

func record_skill_cast_progress(source: BattleUnit, progress: float) -> void:
    var empty_targets: Array[BattleUnit] = []
    var event = BattleEvent.new()
    event.setup(
        BattleEvent.EventType.SKILL_CAST_PROGRESS,
        source.name,
        "",
        {
            "read": _build_read_payload(source, empty_targets),
            "write": {
                "progress": progress
            }
        },
        _context.current_round if _context else -1,
        source.get_turn_order() if source else -1
    )
    _events.append(event)

func record_skill_cast_complete(source: BattleUnit, targets: Array, skill: BattleSkill, execution_log: Array[Dictionary]) -> void:
    var normalized_targets: Array[BattleUnit] = []
    for target in targets:
        if target is BattleUnit:
            normalized_targets.append(target)

    var first_target_name: String = ""
    if normalized_targets.size() > 0:
        first_target_name = normalized_targets[0].name

    var event = BattleEvent.new()
    event.setup(
        BattleEvent.EventType.SKILL_CAST_COMPLETE,
        source.name,
        first_target_name,
        {
            "read": _build_read_payload(source, normalized_targets),
            "write": {
                "skill": {
                    "name": skill.skill_name,
                    "path": skill.resource_path
                },
                "execution": execution_log.duplicate(true)
            }
        },
        _context.current_round if _context else -1,
        source.get_turn_order() if source else -1
    )
    _events.append(event)

func record_skill_cast_interrupt(source: BattleUnit, progress: float, resources_refunded: Dictionary = {}) -> void:
    var empty_targets: Array[BattleUnit] = []
    var event = BattleEvent.new()
    event.setup(
        BattleEvent.EventType.SKILL_CAST_INTERRUPT,
        source.name,
        "",
        {
            "read": _build_read_payload(source, empty_targets),
            "write": {
                "progress": progress,
                "resources_refunded": _duplicate_dictionary(resources_refunded)
            }
        },
        _context.current_round if _context else -1,
        source.get_turn_order() if source else -1
    )
    _events.append(event)

func _on_skill_initiated(cast: SkillCast) -> void:
    record_skill_cast_start(cast.caster, cast.targets, cast.skill, cast.claimed_resources)

func _on_cast_progress_updated(source: BattleUnit, progress: float) -> void:
    record_skill_cast_progress(source, progress)

func _on_skill_completed(cast: SkillCast) -> void:
    record_skill_cast_complete(cast.caster, cast.targets, cast.skill, cast.get_execution_log())

func _on_skill_interrupted(cast: SkillCast) -> void:
    record_skill_cast_interrupt(cast.caster, cast.get_cast_progress(), cast.get_refunded_resources())

func record_skill_cast(source: BattleUnit, targets: Array, skill: BattleSkill, skill_data: Dictionary) -> void:
    var normalized_targets: Array[BattleUnit] = []
    for target in targets:
        if target is BattleUnit:
            normalized_targets.append(target)

    var first_target_name: String = ""
    if normalized_targets.size() > 0:
        first_target_name = normalized_targets[0].name

    var event = BattleEvent.new()
    event.setup(
        BattleEvent.EventType.SKILL_CAST,
        source.name,
        first_target_name,
        {
            "read": _build_read_payload(source, normalized_targets),
            "write": {
                "skill": {
                    "name": skill.skill_name,
                    "path": skill.resource_path
                },
                "data": _duplicate_dictionary(skill_data)
            }
        },
        _context.current_round if _context else -1,
        source.get_turn_order() if source else -1
    )
    _events.append(event)
