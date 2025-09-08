# Lean Property Projection (Godot 4)

> Minimal, single-responsibility rewrite that actually works. Drops Godot 3 compatibility, removes fake caching/transactions, and uses clear contracts.

---
## File: `Modifier.gd`
```gdscript
extends RefCounted
class_name Modifier

# Minimal, explicit, predictable
# Usage examples:
#   Modifier.new(5.0, Type.ADD, ["attack"], 10, 3)   # +5 attack for 3s, priority 10
#   Modifier.new(0.2, Type.MUL, ["defense"])         # +20% defense (relative input)
#   Modifier.new(1.2, Type.MUL, ["attack"])          # +20% attack (absolute multiplier)

enum Type { ADD, MUL }

var value: float
var type: int
var priority: int = 0
var applies_to: PackedStringArray
var expires_at_unix: int = 0 # 0 => never

func _init(
    _value: float,
    _type: int,
    _applies_to: PackedStringArray = PackedStringArray(),
    _priority: int = 0,
    duration_seconds: int = 0
) -> void:
    value = _value
    type = _type
    priority = _priority
    applies_to = _applies_to

    # Normalize multiplicative semantics: accept deltas in (-1,1), or absolute multipliers >= 1.0
    if type == Type.MUL:
        if value > -1.0 and value < 1.0:
            value = 1.0 + value
        assert(value > 0.0, "Multiplicative modifier must be > 0.0")

    if duration_seconds > 0:
        expires_at_unix = Time.get_unix_time_from_system() + int(duration_seconds)

func applies(prop: StringName) -> bool:
    # Empty applies_to => applies to all properties
    return applies_to.is_empty() or applies_to.has(String(prop))

func is_expired(now_unix: int) -> bool:
    return expires_at_unix > 0 and now_unix >= expires_at_unix
```

---
## File: `Unit.gd`
```gdscript
extends Node
class_name Unit

# Minimal stat container + modifier bag
var stats: Dictionary = {}            # StringName -> float
var modifiers: Array[Modifier] = []   # Always kept sorted by priority (ASC)

func get_stat(prop: StringName) -> float:
    return float(stats.get(prop, 0.0))

func set_stat(prop: StringName, v: float) -> void:
    stats[prop] = v

func add_modifier(m: Modifier) -> void:
    if modifiers.has(m):
        return
    modifiers.append(m)
    modifiers.sort_custom(Callable(self, "_by_priority"))

func remove_modifier(m: Modifier) -> void:
    modifiers.erase(m)

func modifiers_for(prop: StringName) -> Array[Modifier]:
    var out: Array[Modifier] = []
    for mod in modifiers:
        if mod.applies(prop):
            out.append(mod)
    return out

func _by_priority(a: Modifier, b: Modifier) -> bool:
    return a.priority < b.priority
```

---
## File: `ProjectionEngine.gd`
```gdscript
extends Node
class_name ProjectionEngine

# Stateless, deterministic projection. No caching (cheap to recompute, avoids staleness).
func project(unit: Unit, prop: StringName) -> float:
    assert(unit != null, "ProjectionEngine.project: unit is null")
    var base := unit.get_stat(prop)

    var add_total := 0.0
    var mul_total := 1.0

    # Modifiers already sorted by priority at insert-time
    for m in unit.modifiers_for(prop):
        match m.type:
            Modifier.Type.ADD:
                add_total += m.value
            Modifier.Type.MUL:
                mul_total *= m.value
            _:
                push_error("Unknown modifier type: %s" % [m.type])

    return (base + add_total) * mul_total
```

---
## File: `EventBus.gd` (optional but actually useful)
```gdscript
extends Node
class_name EventBus

# Tiny pub/sub without Godot dynamic signal machinery.
# Subscribe with:   EventBus.subscribe("damage", func(payload): print(payload))
# Emit with:        EventBus.emit("damage", {"amount": 10})

var _subs: Dictionary = {} # StringName -> Array[Callable]

func subscribe(name: StringName, cb: Callable) -> void:
    var arr: Array = _subs.get(name, [])
    if not arr.has(cb):
        arr.append(cb)
    _subs[name] = arr

func unsubscribe(name: StringName, cb: Callable) -> void:
    if not _subs.has(name):
        return
    _subs[name].erase(cb)
    if (_subs[name] as Array).is_empty():
        _subs.erase(name)

func emit(name: StringName, payload: Dictionary = {}) -> void:
    var arr: Array = _subs.get(name, [])
    # Copy to avoid mutation during iteration
    for cb in arr.duplicate():
        if cb.is_valid():
            cb.call(payload)
```

---
## File: `UnitManager.gd`
```gdscript
extends Node
class_name UnitManager

@export var projection_engine: ProjectionEngine
var units: Array[Unit] = []

func _ready() -> void:
    assert(projection_engine != null, "UnitManager requires a ProjectionEngine")

func _process(_delta: float) -> void:
    _expire_modifiers()

func register(u: Unit) -> void:
    if not units.has(u):
        units.append(u)

func unregister(u: Unit) -> void:
    units.erase(u)

func computed_stat(u: Unit, prop: StringName) -> float:
    return projection_engine.project(u, prop)

func _expire_modifiers() -> void:
    var now := Time.get_unix_time_from_system()
    for u in units:
        var keep: Array[Modifier] = []
        for m in u.modifiers:
            if not m.is_expired(now):
                keep.append(m)
        u.modifiers = keep
```

---
## (Optional) File: `Example.gd` — quick smoke test
```gdscript
extends Node

@onready var engine := ProjectionEngine.new()
@onready var mgr := UnitManager.new()

func _ready() -> void:
    add_child(engine)
    add_child(mgr)
    mgr.projection_engine = engine

    var u := Unit.new()
    u.set_stat("attack", 10.0)

    # +5 flat attack for 5s, priority 0
    u.add_modifier(Modifier.new(5.0, Modifier.Type.ADD, ["attack"], 0, 5))
    # +20% attack (relative input 0.2 => x1.2)
    u.add_modifier(Modifier.new(0.2, Modifier.Type.MUL, ["attack"], 10))

    mgr.register(u)

    var projected := mgr.computed_stat(u, "attack")
    print("Projected attack:", projected) # Expected: (10 + 5) * 1.2 = 18.0
```

---
## Design Notes
- **Godot 4 only.** Simpler, clearer APIs.
- **No silent failure.** `assert` for programmer errors; predictable fallbacks for runtime states.
- **Deterministic modifier ordering.** Sorted on insert via priority.
- **No cache.** Computation is trivial; avoids invalidation headaches.
- **Explicit scoping.** `Modifier.applies_to` controls which properties are affected.
- **Simple expiry.** Manager prunes expired modifiers each frame (cheap; O(n)).

## Next Steps (if needed)
- Add unit tests with GUT or WAT.
- Extend `Unit` to typed fields (e.g., `attack`, `defense`) if you prefer compile-time checks.
- Add stacking rules (e.g., cap total multiplier, clamp additive ranges).
- Emit gameplay events via `EventBus` when modifiers are added/removed or when stats are computed for UI refreshes.

