class_name BattleRuleProcessor
extends Node

const StatProjector = preload("res://stat_projector.gd")

var rules: Array = []
var skip_auto_load: bool = false
static var test_instance: Node = null

func _ready() -> void:
    test_instance = self
    if skip_auto_load:
        return
        
    # Load default rules
    var file = FileAccess.open("res://battle_rules.json", FileAccess.READ)
    if not file:
        push_error("Failed to load battle_rules.json")
        return
    
    var json = JSON.parse_string(file.get_as_text())
    if json == null:
        push_error("Failed to parse battle_rules.json")
        return
    
    print("Loaded %d rules" % json.size())
    
    rules.append_array(json)

func add_temporary_rule(rule: Dictionary) -> void:
    if not _validate_rule(rule):
        push_warning("BattleRuleProcessor: Rule missing required fields ('conditions' and/or 'modifiers'). Rule data: " + str(rule))
        return
    rules.append(rule)

func get_modifiers_for_context(context: Dictionary) -> Array:
    var modifiers: Array = []
    
    for rule in rules:
        if not _validate_rule(rule):
            push_warning("BattleRuleProcessor: Rule missing required fields ('conditions' and/or 'modifiers'). Rule data: " + str(rule))
            continue
        
        if _eval_conditions(rule.conditions, context):
            for modifier_data in rule.modifiers:
                var mod = _create_modifier_from_data(modifier_data)
                if mod != null:
                    modifiers.append(mod)
    
    return modifiers

func _check_condition(cond: Dictionary, context: Dictionary) -> bool:
    return _eval_conditions(cond, context)

func _validate_rule(rule: Dictionary) -> bool:
    return rule.has("conditions") and rule.has("modifiers")

func _eval_conditions(cond: Dictionary, context: Dictionary) -> bool:
    # Handle logical operators first
    if cond.has("and"):
        var conditions = cond["and"]
        if not conditions is Array:
            push_error("BattleRuleProcessor: 'and' operator requires array of conditions. Got: " + str(conditions))
            return false
        for subcond in conditions:
            if not _eval_conditions(subcond, context):
                return false
        return true
    
    if cond.has("or"):
        var conditions = cond["or"]
        if not conditions is Array:
            push_error("BattleRuleProcessor: 'or' operator requires array of conditions. Got: " + str(conditions))
            return false
        for subcond in conditions:
            if _eval_conditions(subcond, context):
                return true
        return false
    
    if cond.has("not"):
        return not _eval_conditions(cond["not"], context)
    
    # Handle property checks
    var property = cond.get("property", "")
    var op = cond.get("op", "eq")
    var value = cond.get("value", null)
    
    if property.is_empty():
        push_error("BattleRuleProcessor: Missing 'property' in condition: " + str(cond))
        return false
    
    # Allow looking up values by property reference
    if value is String and value.begins_with("$"):
        var ref_prop = value.substr(1)
        if not context.has(ref_prop):
            return false
        value = context[ref_prop]
    
    if not context.has(property):
        # Property not present in this context; treat as non-match
        return false
    
    var actual = context[property]
    
    match op:
        "eq":
            return actual == value
        "neq":
            return actual != value
        "gt":
            return actual > value
        "gte":
            return actual >= value
        "lt":
            return actual < value
        "lte":
            return actual <= value
        "contains":
            if actual is Array:
                return actual.has(value)
            if actual is String:
                return actual.contains(value)
            push_error("BattleRuleProcessor: 'contains' operator requires array or string. Got: " + str(typeof(actual)))
            return false
        "in":
            if not value is Array:
                push_error("BattleRuleProcessor: 'in' operator requires array value. Got: " + str(typeof(value)))
                return false
            return value.has(actual)
        "regex":
            if not actual is String:
                push_error("BattleRuleProcessor: 'regex' operator requires string value. Got: " + str(typeof(actual)))
                return false
            var regex = RegEx.new()
            regex.compile(value)
            return regex.search(actual) != null
        _:
            push_error("BattleRuleProcessor: Unknown operator '%s' in condition. Valid operators: eq, neq, gt, gte, lt, lte, contains, in, regex. Full condition: %s" % [op, str(cond)])
            return false

func _create_modifier_from_data(data: Dictionary) -> StatProjector.StatModifier:
    # Validate required fields
    var required = ["id", "op", "value"]
    var missing = required.filter(func(f): return not data.has(f))
    if not missing.is_empty():
        push_error("BattleRuleProcessor: Invalid modifier data - missing required fields: " + str(missing) + ". Modifier data: " + str(data))
        return null
    
    # Create modifier
    var expires_at: float = data.get("expires_at", -1.0)
    if expires_at < 0.0 and data.has("duration"):
        expires_at = Time.get_unix_time_from_system() + float(data.get("duration", 0.0))

    return StatProjector.StatModifier.new(
        data.id,
        _string_to_op(data.op),
        float(data.value),
        data.get("priority", 0),
        data.get("applies_to", []),
        expires_at
    )

func _string_to_op(op_str: String) -> int:
    op_str = op_str.to_upper()
    match op_str:
        "ADD": return StatProjector.ModifierOp.ADD
        "MUL": return StatProjector.ModifierOp.MUL
        "SET": return StatProjector.ModifierOp.SET
        _:
            push_warning("BattleRuleProcessor: Unknown operation '%s'. Defaulting to ADD." % op_str)
            return StatProjector.ModifierOp.ADD  # Default to ADD for unknown operations

func _exit_tree() -> void:
    if test_instance == self:
        test_instance = null
