class_name BattleRuleProcessor
extends Node
# Note: This class is autoloaded as "RuleProcessor"

# Static reference for test environments
static var test_instance: BattleRuleProcessor = null

var rules: Array = []
var skip_auto_load: bool = false

func _ready() -> void:
    if not skip_auto_load:
        load_rules()
    
    # Set test instance if in test environment
    if skip_auto_load:
        BattleRuleProcessor.test_instance = self

func load_rules() -> void:
    var file_path = "res://battle_rules.json"
    if not FileAccess.file_exists(file_path):
        push_warning("Rules file not found: " + file_path)
        return
    
    var file = FileAccess.open(file_path, FileAccess.READ)
    if not file:
        push_error("Failed to open rules file: " + file_path)
        return
    
    var json_text = file.get_as_text()
    file.close()
    
    var parsed = JSON.parse_string(json_text)
    if typeof(parsed) == TYPE_ARRAY:
        rules = parsed
        print("Loaded " + str(rules.size()) + " rules")
    else:
        push_error("Invalid rules format: must be array")

func get_modifiers_for_context(context: Dictionary) -> Array:
    var result: Array[PropertyProjector.Modifier] = []
    
    for rule in rules:
        if not rule.has("conditions") or not rule.has("modifiers"):
            continue
        
        if _eval_conditions(rule.conditions, context):
            for mod_data in rule.modifiers:
                var modifier = _create_modifier_from_data(mod_data)
                if modifier:
                    result.append(modifier)
    
    return result

func _create_modifier_from_data(mod_data: Dictionary):
    if not mod_data.has("id") or not mod_data.has("op") or not mod_data.has("value"):
        push_error("Invalid modifier data: missing required fields")
        return null
    
    var op = _string_to_op(mod_data.op)
    var priority = mod_data.get("priority", 0)
    var applies_to = mod_data.get("applies_to", [])
    var expires_at = mod_data.get("expires_at_unix", -1.0)
    
    if mod_data.has("duration") and mod_data.duration > 0:
        expires_at = Time.get_unix_time_from_system() + mod_data.duration
    
    return PropertyProjector.Modifier.new(
        mod_data.id,
        op,
        mod_data.value,
        priority,
        applies_to,
        expires_at
    )

func _string_to_op(op_str: String) -> int:
    match op_str.to_upper():
        "ADD": return PropertyProjector.Modifier.Op.ADD
        "MUL": return PropertyProjector.Modifier.Op.MUL
        "SET": return PropertyProjector.Modifier.Op.SET
        _: 
            push_error("Unknown operation: " + op_str)
            return PropertyProjector.Modifier.Op.ADD

func _eval_conditions(cond: Dictionary, context: Dictionary) -> bool:
    if cond.has("and"):
        if typeof(cond.and) != TYPE_ARRAY:
            return false
        for c in cond.and:
            if not _eval_conditions(c, context):
                return false
        return true
    
    elif cond.has("or"):
        if typeof(cond.or) != TYPE_ARRAY:
            return false
        for c in cond.or:
            if _eval_conditions(c, context):
                return true
        return false
    
    elif cond.has("not"):
        return not _eval_conditions(cond.not, context)
    
    else:
        return _check_condition(cond, context)

func _check_condition(cond: Dictionary, context: Dictionary) -> bool:
    var property = cond.get("property", "")
    var op = cond.get("op", "")
    var value = cond.get("value")
    
    if property.is_empty():
        push_error("Condition missing property field")
        return false
    
    if not context.has(property):
        return false
    
    var context_value = context[property]
    
    # Check if value is a reference to another property (starts with $)
    if typeof(value) == TYPE_STRING and value.begins_with("$"):
        var ref_property = value.substr(1)
        if context.has(ref_property):
            value = context[ref_property]
    
    match op:
        "eq", "equals":
            return context_value == value
        
        "neq", "not_equals":
            return context_value != value
        
        "gt", "greater":
            if typeof(context_value) in [TYPE_INT, TYPE_FLOAT] and typeof(value) in [TYPE_INT, TYPE_FLOAT]:
                return context_value > value
            return false
        
        "gte", "greater_equals":
            if typeof(context_value) in [TYPE_INT, TYPE_FLOAT] and typeof(value) in [TYPE_INT, TYPE_FLOAT]:
                return context_value >= value
            return false
        
        "lt", "less":
            if typeof(context_value) in [TYPE_INT, TYPE_FLOAT] and typeof(value) in [TYPE_INT, TYPE_FLOAT]:
                return context_value < value
            return false
        
        "lte", "less_equals":
            if typeof(context_value) in [TYPE_INT, TYPE_FLOAT] and typeof(value) in [TYPE_INT, TYPE_FLOAT]:
                return context_value <= value
            return false
        
        "contains", "has":
            if typeof(context_value) == TYPE_ARRAY:
                # If checking array of strings, check if any string contains the value
                if typeof(value) == TYPE_STRING:
                    for item in context_value:
                        if typeof(item) == TYPE_STRING and item.find(value) >= 0:
                            return true
                # Otherwise check for exact match
                return context_value.has(value)
            elif typeof(context_value) == TYPE_STRING and typeof(value) == TYPE_STRING:
                return context_value.find(value) >= 0
            return false
        
        "in":
            if typeof(value) == TYPE_ARRAY:
                return value.has(context_value)
            return false
        
        "regex":
            if typeof(context_value) == TYPE_STRING and typeof(value) == TYPE_STRING:
                var regex = RegEx.new()
                regex.compile(value)
                return regex.search(context_value) != null
            return false
        
        _:
            push_error("Unknown operator: " + op)
            return false

func reload_rules() -> void:
    rules.clear()
    load_rules()
