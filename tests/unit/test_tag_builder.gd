extends GutTest

var tag_builder

func before_each():
	tag_builder = Node.new()
	tag_builder.set_script(load("res://tag_builder.gd"))
	tag_builder.rules = []  # Override file loading

func test_validate_rule_valid():
	var rule = {
		"conditions": {"property": "health", "op": "gt", "value": 50},
		"tags": ["healthy"],
		"priority": 1
	}
	assert_true(tag_builder._validate_rule(rule))

func test_validate_rule_missing_conditions():
	var rule = {
		"tags": ["healthy"],
		"priority": 1
	}
	assert_false(tag_builder._validate_rule(rule))

func test_validate_rule_missing_tags():
	var rule = {
		"conditions": {"property": "health", "op": "gt", "value": 50},
		"priority": 1
	}
	assert_false(tag_builder._validate_rule(rule))

func test_validate_rule_invalid_tags_type():
	var rule = {
		"conditions": {"property": "health", "op": "gt", "value": 50},
		"tags": "not_an_array",
		"priority": 1
	}
	assert_false(tag_builder._validate_rule(rule))

func test_validate_rule_invalid_priority_type():
	var rule = {
		"conditions": {"property": "health", "op": "gt", "value": 50},
		"tags": ["healthy"],
		"priority": "not_an_int"
	}
	assert_false(tag_builder._validate_rule(rule))

func test_check_eq_operator():
	var cond = {"property": "name", "op": "eq", "value": "player"}
	var props = {"name": "player"}
	assert_true(tag_builder._check(cond, props))
	
	props = {"name": "enemy"}
	assert_false(tag_builder._check(cond, props))

func test_check_gt_operator():
	var cond = {"property": "health", "op": "gt", "value": 50}
	var props = {"health": 75}
	assert_true(tag_builder._check(cond, props))
	
	props = {"health": 50}
	assert_false(tag_builder._check(cond, props))
	
	props = {"health": 25}
	assert_false(tag_builder._check(cond, props))

func test_check_lt_operator():
	var cond = {"property": "health", "op": "lt", "value": 30}
	var props = {"health": 25}
	assert_true(tag_builder._check(cond, props))
	
	props = {"health": 30}
	assert_false(tag_builder._check(cond, props))
	
	props = {"health": 50}
	assert_false(tag_builder._check(cond, props))

func test_check_regex_operator():
	var cond = {"property": "name", "op": "regex", "value": "^player_\\d+$"}
	var props = {"name": "player_1"}
	assert_true(tag_builder._check(cond, props))
	
	props = {"name": "player_123"}
	assert_true(tag_builder._check(cond, props))
	
	props = {"name": "enemy_1"}
	assert_false(tag_builder._check(cond, props))
	
	props = {"name": "player_abc"}
	assert_false(tag_builder._check(cond, props))

func test_check_regex_non_string():
	var cond = {"property": "level", "op": "regex", "value": "\\d+"}
	var props = {"level": 42}  # Non-string value
	assert_false(tag_builder._check(cond, props))

func test_check_unsupported_operator():
	var cond = {"property": "health", "op": "unknown", "value": 50}
	var props = {"health": 75}
	assert_false(tag_builder._check(cond, props))

func test_check_missing_property():
	var cond = {"property": "mana", "op": "gt", "value": 0}
	var props = {"health": 100}  # mana property missing
	assert_false(tag_builder._check(cond, props))

func test_eval_and_conditions_all_true():
	var cond = {
		"and": [
			{"property": "health", "op": "gt", "value": 50},
			{"property": "level", "op": "gt", "value": 10}
		]
	}
	var props = {"health": 75, "level": 15}
	assert_true(tag_builder._eval(cond, props))

func test_eval_and_conditions_one_false():
	var cond = {
		"and": [
			{"property": "health", "op": "gt", "value": 50},
			{"property": "level", "op": "gt", "value": 20}
		]
	}
	var props = {"health": 75, "level": 15}
	assert_false(tag_builder._eval(cond, props))

func test_eval_or_conditions_one_true():
	var cond = {
		"or": [
			{"property": "health", "op": "lt", "value": 30},
			{"property": "level", "op": "gt", "value": 10}
		]
	}
	var props = {"health": 75, "level": 15}
	assert_true(tag_builder._eval(cond, props))

func test_eval_or_conditions_all_false():
	var cond = {
		"or": [
			{"property": "health", "op": "lt", "value": 30},
			{"property": "level", "op": "gt", "value": 20}
		]
	}
	var props = {"health": 75, "level": 15}
	assert_false(tag_builder._eval(cond, props))

func test_eval_nested_conditions():
	var cond = {
		"and": [
			{"property": "type", "op": "eq", "value": "player"},
			{
				"or": [
					{"property": "health", "op": "lt", "value": 30},
					{"property": "armor", "op": "eq", "value": 0}
				]
			}
		]
	}
	
	# Player with low health
	var props = {"type": "player", "health": 20, "armor": 50}
	assert_true(tag_builder._eval(cond, props))
	
	# Player with no armor
	props = {"type": "player", "health": 100, "armor": 0}
	assert_true(tag_builder._eval(cond, props))
	
	# Player with health and armor
	props = {"type": "player", "health": 100, "armor": 50}
	assert_false(tag_builder._eval(cond, props))
	
	# Enemy with low health (type check fails)
	props = {"type": "enemy", "health": 20, "armor": 0}
	assert_false(tag_builder._eval(cond, props))

func test_get_tags_simple():
	tag_builder.rules = [
		{
			"conditions": {"property": "health", "op": "lt", "value": 30},
			"tags": ["low_health", "vulnerable"],
			"priority": 1
		}
	]
	
	var tags = tag_builder.get_tags({"health": 20})
	assert_eq(tags.size(), 2)
	assert_true(tags.has("low_health"))
	assert_true(tags.has("vulnerable"))
	
	tags = tag_builder.get_tags({"health": 50})
	assert_eq(tags.size(), 0)

func test_get_tags_multiple_rules():
	tag_builder.rules = [
		{
			"conditions": {"property": "health", "op": "lt", "value": 30},
			"tags": ["low_health"],
			"priority": 1
		},
		{
			"conditions": {"property": "type", "op": "eq", "value": "boss"},
			"tags": ["boss", "strong"],
			"priority": 2
		},
		{
			"conditions": {"property": "level", "op": "gt", "value": 50},
			"tags": ["high_level", "strong"],
			"priority": 3
		}
	]
	
	var props = {"health": 20, "type": "boss", "level": 60}
	var tags = tag_builder.get_tags(props)
	
	# Should have all unique tags
	assert_eq(tags.size(), 4)
	assert_true(tags.has("low_health"))
	assert_true(tags.has("boss"))
	assert_true(tags.has("strong"))  # Only once despite being in two rules
	assert_true(tags.has("high_level"))

func test_get_tags_no_duplicates():
	tag_builder.rules = [
		{
			"conditions": {"property": "type", "op": "eq", "value": "player"},
			"tags": ["friendly", "player"],
			"priority": 1
		},
		{
			"conditions": {"property": "team", "op": "eq", "value": 1},
			"tags": ["friendly", "ally"],
			"priority": 2
		}
	]
	
	var props = {"type": "player", "team": 1}
	var tags = tag_builder.get_tags(props)
	
	assert_eq(tags.size(), 3)
	assert_true(tags.has("friendly"))  # Should appear only once
	assert_true(tags.has("player"))
	assert_true(tags.has("ally"))
	
	# Verify "friendly" appears exactly once
	var friendly_count = 0
	for tag in tags:
		if tag == "friendly":
			friendly_count += 1
	assert_eq(friendly_count, 1)

func test_get_tags_complex_scenario():
	tag_builder.rules = [
		{
			"conditions": {
				"and": [
					{"property": "type", "op": "eq", "value": "unit"},
					{"property": "health", "op": "lt", "value": 30}
				]
			},
			"tags": ["critical_unit"],
			"priority": 10
		},
		{
			"conditions": {
				"or": [
					{"property": "status", "op": "eq", "value": "poisoned"},
					{"property": "status", "op": "eq", "value": "burning"}
				]
			},
			"tags": ["debuffed", "needs_cleanse"],
			"priority": 5
		},
		{
			"conditions": {"property": "name", "op": "regex", "value": "Elite"},
			"tags": ["elite", "strong"],
			"priority": 3
		}
	]
	
	# Test unit with multiple matching conditions
	var props = {
		"type": "unit",
		"health": 20,
		"status": "poisoned",
		"name": "Elite Guard"
	}
	var tags = tag_builder.get_tags(props)
	
	assert_eq(tags.size(), 5)
	assert_true(tags.has("critical_unit"))
	assert_true(tags.has("debuffed"))
	assert_true(tags.has("needs_cleanse"))
	assert_true(tags.has("elite"))
	assert_true(tags.has("strong"))