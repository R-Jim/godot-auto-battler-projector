extends Node

# Tag system: stripped, validated, lean
# Input: JSON array of rules [{conditions:{}, tags:[..], priority:int}]
# Output: unique set of tags

var rules: Array = []

func _ready():
	var file := FileAccess.open("res://rules.json", FileAccess.READ)
	if file:
		var parsed = JSON.parse_string(file.get_as_text())
		if typeof(parsed) == TYPE_ARRAY:
			for rule in parsed:
				if _validate_rule(rule):
					rules.append(rule)
		else:
			push_error("Invalid rules format: must be array")

func _validate_rule(rule: Dictionary) -> bool:
	if not rule.has("conditions") or not rule.has("tags"):
		push_error("Rule missing keys: %s" % rule)
		return false
	if typeof(rule["tags"]) != TYPE_ARRAY:
		push_error("Tags must be array: %s" % rule)
		return false
	if typeof(rule.get("priority", 0)) != TYPE_INT:
		push_error("Priority must be int: %s" % rule)
		return false
	return true

func get_tags(properties: Dictionary) -> Array:
	var matched: Array = []
	for rule in rules:
		if _eval(rule["conditions"], properties):
			for tag in rule["tags"]:
				if tag not in matched:
					matched.append(tag)
	return matched

func _eval(cond: Dictionary, props: Dictionary) -> bool:
	if cond.has("and"):
		for c in cond["and"]:
			if not _eval(c, props):
				return false
		return true
	elif cond.has("or"):
		for c in cond["or"]:
			if _eval(c, props):
				return true
		return false
	else:
		return _check(cond, props)

func _check(cond: Dictionary, props: Dictionary) -> bool:
	var key = cond.get("property", "")
	if not props.has(key):
		return false
	var val = props[key]
	var op = cond.get("op", "")
	var target = cond.get("value")
	match op:
		"eq":
			return val == target
		"gt":
			return val > target
		"lt":
			return val < target
		"regex":
			if typeof(val) == TYPE_STRING and typeof(target) == TYPE_STRING:
				var regex = RegEx.new()
				regex.compile(target)
				return regex.search(val) != null
			return false
		_:
			push_error("Unsupported operator: %s" % op)
			return false
