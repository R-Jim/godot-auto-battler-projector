class_name PropertyProjector
extends RefCounted

# Signal
# Emitted after modifiers are added or removed.
# The payload is a Dictionary: { "old_value": float, "added": Array[Modifier], "removed": Array[Modifier] }
signal projection_changed(payload: Dictionary)

# Nested Modifier Class
class Modifier:
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
var _cached_master_list: Array = []
var _cached_values: Dictionary = {}
var _last_base: float = 0.0

# --- Public API ---

# Adds a modifier object and returns it.
func add_modifier(mod: Modifier) -> Modifier:
	if not mod is Modifier:
		push_error("add_modifier expects a Modifier object. Got: " + str(typeof(mod)) + " - " + str(mod))
		return null

	if mod.id.is_empty():
		push_error("Modifier must have a non-empty id.")
		return null

	var old_proj = get_projected_value(_last_base)

	mod.insertion_index = _next_insert_index
	_next_insert_index += 1

	if not _modifiers.has(mod.id):
		_modifiers[mod.id] = []
	_modifiers[mod.id].append(mod)

	_mark_dirty()

	projection_changed.emit({ "old_value": old_proj, "added": [mod], "removed": [] })
	return mod

# Removes a specific modifier instance.
func remove_modifier(mod_instance: Modifier) -> void:
	if mod_instance == null:
		push_error("remove_modifier called with null")
		return
	if not mod_instance is Modifier:
		push_error("remove_modifier expects a Modifier object. Got: " + str(typeof(mod_instance)) + " - " + str(mod_instance))
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

# Calculates and returns the projected value.
func get_projected_value(base: float = 0.0, applies_to_filter = null) -> float:
	if not is_equal_approx(base, _last_base):
		_cached_values.clear()
		_last_base = base

	var key = applies_to_filter if applies_to_filter != null else "##null##"
	if not _dirty and _cached_values.has(key):
		return _cached_values[key]

	if _dirty:
		_rebuild_master_list()

	var value = _calculate_value_from_master_list(base, applies_to_filter)
	_cached_values[key] = value
	_dirty = false
	return value

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
		_rebuild_master_list()
	return _cached_master_list.duplicate()

# --- Private Helpers ---

func _process_removals(removed_mods: Array) -> void:
	if removed_mods.is_empty():
		return

	var old_proj = get_projected_value(_last_base)

	for mod in removed_mods: # [cite: 23]
		if not mod is Modifier:
			push_error("_process_removals: Invalid modifier type: " + str(typeof(mod)))
			continue
		if _modifiers.has(mod.id):
			_modifiers[mod.id].erase(mod)
			if _modifiers[mod.id].is_empty():
				_modifiers.erase(mod.id)

	_mark_dirty()

	projection_changed.emit({ "old_value": old_proj, "added": [], "removed": removed_mods })

func _calculate_value_from_master_list(base: float, applies_to_filter) -> float:
	var value: float = base
	for mod in _cached_master_list:
		if applies_to_filter == null or mod.applies_to.is_empty() or mod.applies_to.has(applies_to_filter):
			match mod.op:
				Modifier.Op.SET: value = mod.value
				Modifier.Op.MUL: value *= mod.value
				Modifier.Op.ADD: value += mod.value
	return value

func _rebuild_master_list() -> void:
	_cached_master_list.clear()
	for id in _modifiers.keys():
		_cached_master_list.append_array(_modifiers[id])
	
	_cached_master_list.sort_custom(_modifier_compare)

func _modifier_compare(a: Modifier, b: Modifier) -> bool:
	if a.priority != b.priority:
		return a.priority > b.priority
	return a.insertion_index < b.insertion_index

func _mark_dirty() -> void:
	_dirty = true
	_cached_values.clear()

# --- Convenience Wrappers ---

func add_additive(id: String, amount: float, priority: int = 0, applies_to: Array = [], expires_at_unix: float = -1.0) -> Modifier:
	var m = Modifier.new(id, Modifier.Op.ADD, amount, priority, applies_to, expires_at_unix)
	return add_modifier(m)

func add_multiplier(id: String, factor: float, priority: int = 0, applies_to: Array = [], expires_at_unix: float = -1.0) -> Modifier:
	var m = Modifier.new(id, Modifier.Op.MUL, factor, priority, applies_to, expires_at_unix)
	return add_modifier(m)

func add_set(id: String, value: float, priority: int = 0, applies_to: Array = [], expires_at_unix: float = -1.0) -> Modifier:
	var m = Modifier.new(id, Modifier.Op.SET, value, priority, applies_to, expires_at_unix)
	return add_modifier(m)