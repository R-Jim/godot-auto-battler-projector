extends RefCounted
class_name StatProjector

enum ModifierOp { ADD, MUL, SET }

class StatModifier:
    var id: String = ""
    var op: int = ModifierOp.ADD
    var value: float = 0.0
    var priority: int = 0
    var applies_to: Array = []
    var expires_at_unix: float = -1.0
    var insertion_index: int = -1

    func _init(_id: String = "", _op: int = ModifierOp.ADD, _value: float = 0.0, _priority: int = 0, _applies_to: Array = [], _expires_at_unix: float = -1.0) -> void:
        id = _id
        op = _op
        value = _value
        priority = _priority
        applies_to = _applies_to
        expires_at_unix = _expires_at_unix

# Internal State
var _modifiers: Dictionary = {}
var _next_insert_index: int = 0
var _dirty: bool = true
var _sorted_modifier_list: Array = []
var _cached_calculations: Dictionary = {}
var _last_base: float = 0.0

# Signal
signal stat_calculation_changed(payload: Dictionary)

func add_modifier(mod: StatModifier) -> StatModifier:
    if not mod is StatModifier:
        push_error("add_modifier expects a StatModifier object. Got: " + str(typeof(mod)) + " - " + str(mod))
        return null

    if mod.id.is_empty():
        push_error("Modifier must have a non-empty id.")
        return null

    var old_value = calculate_stat(_last_base)

    mod.insertion_index = _next_insert_index
    _next_insert_index += 1

    if not _modifiers.has(mod.id):
        _modifiers[mod.id] = []
    _modifiers[mod.id].append(mod)

    _mark_dirty()
    stat_calculation_changed.emit({ "old_value": old_value, "added": [mod], "removed": [] })
    return mod

func remove_modifier(mod_instance: StatModifier) -> void:
    if mod_instance == null:
        push_error("remove_modifier called with null")
        return
    if not mod_instance is StatModifier:
        push_error("remove_modifier expects a StatModifier object. Got: " + str(typeof(mod_instance)) + " - " + str(mod_instance))
        return
    _process_removals([mod_instance])

func remove_modifiers_by_id(id: String) -> Array:
    if not _modifiers.has(id):
        return []

    var to_remove: Array = _modifiers[id].duplicate()
    if to_remove.is_empty():
        return []

    _process_removals(to_remove)
    return to_remove

func calculate_stat(base: float = 0.0, applies_to_filter = null) -> float:
    if not is_equal_approx(base, _last_base):
        _cached_calculations.clear()
        _last_base = base

    var key = applies_to_filter if applies_to_filter != null else "##null##"
    if not _dirty and _cached_calculations.has(key):
        return _cached_calculations[key]

    if _dirty:
        _rebuild_sorted_list()

    var value = _calculate_value_from_sorted_list(base, applies_to_filter)
    _cached_calculations[key] = value
    _dirty = false
    return value

func _process_removals(removed_mods: Array) -> void:
    if removed_mods.is_empty():
        return

    var old_value = calculate_stat(_last_base)

    for mod in removed_mods:
        if not mod is StatModifier:
            push_error("_process_removals: Invalid modifier type: " + str(typeof(mod)))
            continue
        if _modifiers.has(mod.id):
            _modifiers[mod.id].erase(mod)
            if _modifiers[mod.id].is_empty():
                _modifiers.erase(mod.id)

    _mark_dirty()
    stat_calculation_changed.emit({ "old_value": old_value, "added": [], "removed": removed_mods })

func _calculate_value_from_sorted_list(base: float, applies_to_filter) -> float:
    var value: float = base
    for mod in _sorted_modifier_list:
        if applies_to_filter == null or mod.applies_to.is_empty() or mod.applies_to.has(applies_to_filter):
            match mod.op:
                ModifierOp.SET: value = mod.value
                ModifierOp.MUL: value *= mod.value
                ModifierOp.ADD: value += mod.value
    return value

func _rebuild_sorted_list() -> void:
    _sorted_modifier_list.clear()
    for id in _modifiers.keys():
        _sorted_modifier_list.append_array(_modifiers[id])
    
    _sorted_modifier_list.sort_custom(_modifier_compare)

func _modifier_compare(a: StatModifier, b: StatModifier) -> bool:
    if a.priority != b.priority:
        return a.priority > b.priority
    return a.insertion_index < b.insertion_index

func _mark_dirty() -> void:
    _dirty = true
    _cached_calculations.clear()

# Convenience wrappers
func add_flat_modifier(id: String, amount: float, priority: int = 0, applies_to: Array = [], expires_at_unix: float = -1.0) -> StatModifier:
    var mod = StatModifier.new(id, ModifierOp.ADD, amount, priority, applies_to, expires_at_unix)
    return add_modifier(mod)

func add_percentage_modifier(id: String, factor: float, priority: int = 0, applies_to: Array = [], expires_at_unix: float = -1.0) -> StatModifier:
    var mod = StatModifier.new(id, ModifierOp.MUL, factor, priority, applies_to, expires_at_unix)
    return add_modifier(mod)

func set_override(id: String, value: float, priority: int = 0, applies_to: Array = [], expires_at_unix: float = -1.0) -> StatModifier:
    var mod = StatModifier.new(id, ModifierOp.SET, value, priority, applies_to, expires_at_unix)
    return add_modifier(mod)

func list_modifiers() -> Array:
    return _sorted_modifier_list.duplicate()

static func create_from_dict(dict: Dictionary) -> StatModifier:
    if not dict.has_all(["id", "op", "value"]):
        push_error("Invalid modifier data - missing required fields: " + str(["id", "op", "value"].filter(func(f): return not dict.has(f))))
        return null
    
    return StatModifier.new(
        dict["id"],
        dict["op"],
        dict["value"],
        dict.get("priority", 0),
        dict.get("applies_to", []),
        dict.get("expires_at", -1.0)
    )