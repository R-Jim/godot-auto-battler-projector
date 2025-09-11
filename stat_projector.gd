class_name StatProjector
extends RefCounted

# Signal
# Emitted after modifiers are added or removed.
# The payload is a Dictionary: { "old_value": float, "added": Array[StatModifier], "removed": Array[StatModifier] }
signal stat_calculation_changed(payload: Dictionary)

# Nested Modifier Class
class StatModifier:
	enum Op { ADD, MUL, SET }

	var id: String
	var op: int
	var value: float
	var priority: int
	var applies_to: Array
	var expires_at_unix: float
	var insertion_index: int

	func _init(_id: String, _op: int, _value: float, _priority: int, _applies_to: Array, _expires_at_unix: float):
		id = _id
		op = _op
		value = _value
		priority = _priority
		applies_to = _applies_to
		expires_at_unix = _expires_at_unix
		insertion_index = -1

# Internal State
var _modifiers: Dictionary = {}
var _next_insert_index: int = 0
var _dirty: bool = true
var _sorted_modifier_list: Array = []
var _cached_calculations: Dictionary = {}
var _last_base: float = 0.0

# --- Public API ---

# Adds a modifier object and returns it.
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

# Removes a specific modifier instance.
func remove_modifier(mod_instance: StatModifier) -> void:
	if mod_instance == null:
		push_error("remove_modifier called with null")
		return
	if not mod_instance is StatModifier:
		push_error("remove_modifier expects a StatModifier object. Got: " + str(typeof(mod_instance)) + " - " + str(mod_instance))
		return
	_process_removals([mod_instance])

# Removes all modifiers with a given ID.
func remove_modifiers_by_id(id: String) -> Array:
	if not _modifiers.has(id):
		return []

	var to_remove: Array = _modifiers[id].duplicate()
	if to_remove.is_empty():
		return []

	_process_removals(to_remove)
	return to_remove

# Removes all modifiers whose 'applies_to' list contains the target. [cite: 13]
func remove_modifiers_by_applies_to(target) -> Array:
	var to_remove: Array = []
	for id in _modifiers.keys():
		for mod in _modifiers[id]:
			if mod.applies_to.has(target):
				to_remove.append(mod)

	if to_remove.is_empty():
		return []

	_process_removals(to_remove)
	return to_remove

# Prunes expired modifiers based on the provided UNIX timestamp.
func prune_expired(now_unix: float) -> Array:
	var to_remove: Array = []
	for id in _modifiers.keys():
		for mod in _modifiers[id]:
			if mod.expires_at_unix > 0.0 and mod.expires_at_unix <= now_unix:
				to_remove.append(mod)

	if to_remove.is_empty():
		return []

	_process_removals(to_remove)
	return to_remove

# Clears all modifiers from the projector. [cite: 16]
func clear() -> void:
	if _modifiers.is_empty():
		return

	var to_remove: Array = []
	for id in _modifiers.keys():
		for mod in _modifiers[id]:
			to_remove.append(mod)

	_process_removals(to_remove)

# --- Getters ---

# Calculates and returns the stat value after applying all modifiers.
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

# Legacy method name for backward compatibility
func get_projected_value(base: float = 0.0, applies_to_filter = null) -> float:
	return calculate_stat(base, applies_to_filter)

func has_modifier(id: String) -> bool:
	return _modifiers.has(id) # [cite: 8]

# Returns a shallow copy of the modifier list for a given ID. [cite: 21]
func get_modifiers_for_id(id: String) -> Array:
	if not _modifiers.has(id):
		return []
	return _modifiers[id].duplicate()

# Returns a list of all active modifiers.
func list_modifiers() -> Array:
	if _dirty:
		_rebuild_sorted_list()
	return _sorted_modifier_list.duplicate()

# --- Private Helpers ---

func _process_removals(removed_mods: Array) -> void:
	if removed_mods.is_empty():
		return

	var old_value = calculate_stat(_last_base)

	for mod in removed_mods: # [cite: 23]
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
				StatModifier.Op.SET: value = mod.value
				StatModifier.Op.MUL: value *= mod.value
				StatModifier.Op.ADD: value += mod.value
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

# --- Convenience Wrappers ---

func add_flat_modifier(id: String, amount: float, priority: int = 0, applies_to: Array = [], expires_at_unix: float = -1.0) -> StatModifier:
	var m = StatModifier.new(id, StatModifier.Op.ADD, amount, priority, applies_to, expires_at_unix)
	return add_modifier(m)

func add_percentage_modifier(id: String, factor: float, priority: int = 0, applies_to: Array = [], expires_at_unix: float = -1.0) -> StatModifier:
	var m = StatModifier.new(id, StatModifier.Op.MUL, factor, priority, applies_to, expires_at_unix)
	return add_modifier(m)

func set_override(id: String, value: float, priority: int = 0, applies_to: Array = [], expires_at_unix: float = -1.0) -> StatModifier:
	var m = StatModifier.new(id, StatModifier.Op.SET, value, priority, applies_to, expires_at_unix)
	return add_modifier(m)

# Legacy method names for backward compatibility
func add_additive(id: String, amount: float, priority: int = 0, applies_to: Array = [], expires_at_unix: float = -1.0) -> StatModifier:
	return add_flat_modifier(id, amount, priority, applies_to, expires_at_unix)

func add_multiplier(id: String, factor: float, priority: int = 0, applies_to: Array = [], expires_at_unix: float = -1.0) -> StatModifier:
	return add_percentage_modifier(id, factor, priority, applies_to, expires_at_unix)

func add_set(id: String, value: float, priority: int = 0, applies_to: Array = [], expires_at_unix: float = -1.0) -> StatModifier:
	return set_override(id, value, priority, applies_to, expires_at_unix)