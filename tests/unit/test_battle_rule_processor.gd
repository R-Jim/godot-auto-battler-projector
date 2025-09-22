extends GutTest

const BattleRuleProcessorScript = preload("res://src/battle/battle_rule_processor.gd")

var processor

func before_each():
	processor = BattleRuleProcessorScript.new()
	processor.rules = []  # Clear rules to avoid file loading

func test_string_to_op():
	assert_eq(processor._string_to_op("ADD"), StatProjector.ModifierOp.ADD)
	assert_eq(processor._string_to_op("add"), StatProjector.ModifierOp.ADD)
	assert_eq(processor._string_to_op("MUL"), StatProjector.ModifierOp.MUL)
	assert_eq(processor._string_to_op("mul"), StatProjector.ModifierOp.MUL)
	assert_eq(processor._string_to_op("SET"), StatProjector.ModifierOp.SET)
	assert_eq(processor._string_to_op("set"), StatProjector.ModifierOp.SET)
	
	# Unknown op defaults to ADD
	assert_eq(processor._string_to_op("unknown"), StatProjector.ModifierOp.ADD)

func test_create_modifier_from_data():
	var mod_data = {
		"id": "test_mod",
		"op": "ADD",
		"value": 10.0,
		"priority": 5,
		"applies_to": ["attack", "defense"]
	}
	
	var modifier = processor._create_modifier_from_data(mod_data)
	assert_not_null(modifier)
	assert_eq(modifier.id, "test_mod")
	assert_eq(modifier.op, StatProjector.ModifierOp.ADD)
	assert_eq(modifier.value, 10.0)
	assert_eq(modifier.priority, 5)
	assert_eq(modifier.applies_to, ["attack", "defense"])

func test_create_modifier_with_duration():
	var mod_data = {
		"id": "temp_mod",
		"op": "MUL",
		"value": 1.5,
		"duration": 10.0
	}
	
	var now = Time.get_unix_time_from_system()
	var modifier = processor._create_modifier_from_data(mod_data)
	assert_not_null(modifier)
	assert_gt(modifier.expires_at_unix, now)
	assert_lt(modifier.expires_at_unix, now + 11.0)

func test_create_modifier_missing_fields():
	var mod_data = {
		"id": "bad_mod",
		"value": 10.0
		# Missing "op"
	}
	
	var modifier = processor._create_modifier_from_data(mod_data)
	assert_null(modifier)

func test_check_condition_eq():
	var cond = {"property": "team", "op": "eq", "value": 1}
	assert_true(processor._check_condition(cond, {"team": 1}))
	assert_false(processor._check_condition(cond, {"team": 2}))

func test_check_condition_neq():
	var cond = {"property": "status", "op": "neq", "value": "poisoned"}
	assert_true(processor._check_condition(cond, {"status": "healthy"}))
	assert_false(processor._check_condition(cond, {"status": "poisoned"}))

func test_check_condition_numeric():
	var context = {"health": 50, "level": 10}
	
	# Greater than
	assert_true(processor._check_condition({"property": "health", "op": "gt", "value": 30}, context))
	assert_false(processor._check_condition({"property": "health", "op": "gt", "value": 50}, context))
	
	# Less than
	assert_true(processor._check_condition({"property": "level", "op": "lt", "value": 20}, context))
	assert_false(processor._check_condition({"property": "level", "op": "lt", "value": 5}, context))
	
	# Greater equals
	assert_true(processor._check_condition({"property": "health", "op": "gte", "value": 50}, context))
	assert_true(processor._check_condition({"property": "health", "op": "gte", "value": 30}, context))
	
	# Less equals
	assert_true(processor._check_condition({"property": "level", "op": "lte", "value": 10}, context))
	assert_true(processor._check_condition({"property": "level", "op": "lte", "value": 20}, context))

func test_check_condition_contains():
	# Array contains
	var cond = {"property": "status_list", "op": "contains", "value": "poisoned"}
	assert_true(processor._check_condition(cond, {"status_list": ["poisoned", "burned"]}))
	assert_false(processor._check_condition(cond, {"status_list": ["stunned", "frozen"]}))
	
	# String contains
	cond = {"property": "name", "op": "contains", "value": "Fire"}
	assert_true(processor._check_condition(cond, {"name": "Fire Dragon"}))
	assert_false(processor._check_condition(cond, {"name": "Ice Dragon"}))

func test_check_condition_in():
	var cond = {"property": "damage_type", "op": "in", "value": ["fire", "ice", "lightning"]}
	assert_true(processor._check_condition(cond, {"damage_type": "fire"}))
	assert_false(processor._check_condition(cond, {"damage_type": "physical"}))

func test_check_condition_regex():
	var cond = {"property": "name", "op": "regex", "value": "^Elite .*"}
	assert_true(processor._check_condition(cond, {"name": "Elite Guard"}))
	assert_true(processor._check_condition(cond, {"name": "Elite Mage"}))
	assert_false(processor._check_condition(cond, {"name": "Guard Elite"}))

func test_check_condition_value_reference():
	var cond = {"property": "health", "op": "lt", "value": "$max_health"}
	var context = {"health": 50, "max_health": 100}
	assert_true(processor._check_condition(cond, context))
	
	context = {"health": 100, "max_health": 100}
	assert_false(processor._check_condition(cond, context))

func test_check_condition_missing_property():
	var cond = {"property": "mana", "op": "gt", "value": 0}
	assert_false(processor._check_condition(cond, {"health": 100}))

func test_check_condition_invalid_op():
	var cond = {"property": "health", "op": "invalid_op", "value": 50}
	assert_false(processor._check_condition(cond, {"health": 100}))

func test_eval_conditions_simple():
	var cond = {"property": "team", "op": "eq", "value": 1}
	assert_true(processor._eval_conditions(cond, {"team": 1}))
	assert_false(processor._eval_conditions(cond, {"team": 2}))

func test_eval_conditions_and():
	var cond = {
		"and": [
			{"property": "team", "op": "eq", "value": 1},
			{"property": "health", "op": "gt", "value": 50}
		]
	}
	
	assert_true(processor._eval_conditions(cond, {"team": 1, "health": 75}))
	assert_false(processor._eval_conditions(cond, {"team": 2, "health": 75}))
	assert_false(processor._eval_conditions(cond, {"team": 1, "health": 25}))

func test_eval_conditions_or():
	var cond = {
		"or": [
			{"property": "health", "op": "lt", "value": 30},
			{"property": "status", "op": "eq", "value": "poisoned"}
		]
	}
	
	assert_true(processor._eval_conditions(cond, {"health": 20, "status": "healthy"}))
	assert_true(processor._eval_conditions(cond, {"health": 100, "status": "poisoned"}))
	assert_false(processor._eval_conditions(cond, {"health": 100, "status": "healthy"}))

func test_eval_conditions_not():
	var cond = {
		"not": {"property": "team", "op": "eq", "value": 2}
	}
	
	assert_true(processor._eval_conditions(cond, {"team": 1}))
	assert_false(processor._eval_conditions(cond, {"team": 2}))

func test_eval_conditions_nested():
	var cond = {
		"and": [
			{"property": "type", "op": "eq", "value": "unit"},
			{
				"or": [
					{"property": "health", "op": "lt", "value": 30},
					{
						"and": [
							{"property": "team", "op": "eq", "value": 2},
							{"property": "status", "op": "contains", "value": "buff"}
						]
					}
				]
			}
		]
	}
	
	# Unit with low health
	assert_true(processor._eval_conditions(cond, {
		"type": "unit",
		"health": 20,
		"team": 1,
		"status": []
	}))
	
	# Unit on team 2 with buff
	assert_true(processor._eval_conditions(cond, {
		"type": "unit",
		"health": 100,
		"team": 2,
		"status": ["buff_attack", "buff_defense"]
	}))
	
	# Not a unit
	assert_false(processor._eval_conditions(cond, {
		"type": "hero",
		"health": 20,
		"team": 1,
		"status": []
	}))

func test_get_modifiers_for_context():
	processor.rules = [
		{
			"conditions": {"property": "health", "op": "lt", "value": 30},
			"modifiers": [
				{"id": "low_health_buff", "op": "MUL", "value": 1.5, "priority": 10}
			]
		},
		{
			"conditions": {
				"and": [
					{"property": "team", "op": "eq", "value": 1},
					{"property": "status", "op": "contains", "value": "rage"}
				]
			},
			"modifiers": [
				{"id": "rage_attack", "op": "ADD", "value": 20, "applies_to": ["attack"]},
				{"id": "rage_defense", "op": "MUL", "value": 0.8, "applies_to": ["defense"]}
			]
		}
	]
	
	# Test low health
	var modifiers = processor.get_modifiers_for_context({"health": 20, "team": 2, "status": []})
	assert_eq(modifiers.size(), 1)
	assert_eq(modifiers[0].id, "low_health_buff")
	
	# Test rage on team 1
	modifiers = processor.get_modifiers_for_context({"health": 100, "team": 1, "status": ["rage"]})
	assert_eq(modifiers.size(), 2)
	
	var mod_ids = []
	for mod in modifiers:
		mod_ids.append(mod.id)
	assert_true(mod_ids.has("rage_attack"))
	assert_true(mod_ids.has("rage_defense"))
	
	# Test both conditions
	modifiers = processor.get_modifiers_for_context({"health": 20, "team": 1, "status": ["rage"]})
	assert_eq(modifiers.size(), 3)

func test_get_modifiers_invalid_rule():
	processor.rules = [
		{
			# Missing "modifiers" key
			"conditions": {"property": "health", "op": "lt", "value": 30}
		},
		{
			# Valid rule
			"conditions": {"property": "team", "op": "eq", "value": 1},
			"modifiers": [
				{"id": "team_buff", "op": "ADD", "value": 10}
			]
		}
	]
	
	var modifiers = processor.get_modifiers_for_context({"health": 20, "team": 1})
	assert_eq(modifiers.size(), 1)  # Only the valid rule's modifier
	assert_eq(modifiers[0].id, "team_buff")
