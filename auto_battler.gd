class_name AutoBattler
extends Node

signal battle_started
signal battle_ended(winner_team: int)
signal round_started(round_number: int)
signal round_ended(round_number: int)
signal turn_started(active_unit: BattleUnit)
signal turn_ended(active_unit: BattleUnit)
signal action_performed(unit: BattleUnit, action: Dictionary)

@export var turn_delay: float = 0.5
@export var max_rounds: int = 100

var team1: Array[BattleUnit] = []
var team2: Array[BattleUnit] = []

var is_battle_active: bool = false
var current_round: int = 0
var turn_queue: Array = []
var active_unit: BattleUnit = null

var rule_processor: BattleRuleProcessor
var battle_context: Dictionary = {}

func _ready() -> void:
	if not rule_processor:
		rule_processor = get_node("/root/RuleProcessor")
		if not rule_processor:
			push_error("RuleProcessor not found! Make sure it's an autoload.")

func start_battle(_team1: Array[BattleUnit], _team2: Array[BattleUnit]) -> void:
	if is_battle_active:
		push_error("Battle already in progress")
		return
	
	team1 = _team1
	team2 = _team2
	
	for unit in team1 + team2:
		unit.unit_died.connect(_on_unit_died.bind(unit))
	
	is_battle_active = true
	current_round = 0
	battle_started.emit()
	
	await get_tree().create_timer(0.1).timeout
	_start_round()

func stop_battle() -> void:
	is_battle_active = false
	turn_queue.clear()
	active_unit = null

func _start_round() -> void:
	if not is_battle_active:
		return
	
	current_round += 1
	
	if current_round > max_rounds:
		_end_battle(0)
		return
	
	round_started.emit(current_round)
	
	turn_queue.clear()
	for unit in team1 + team2:
		if unit.is_alive():
			var initiative = unit.roll_initiative()
			turn_queue.append({"unit": unit, "initiative": initiative})
	
	turn_queue.sort_custom(_sort_by_initiative)
	
	await get_tree().create_timer(0.1).timeout
	_process_next_turn()

func _sort_by_initiative(a: Dictionary, b: Dictionary) -> bool:
	return a.initiative > b.initiative

func _process_next_turn() -> void:
	if not is_battle_active:
		return
	
	if turn_queue.is_empty():
		round_ended.emit(current_round)
		if _check_battle_end():
			return
		await get_tree().create_timer(0.2).timeout
		_start_round()
		return
	
	var turn_data = turn_queue.pop_front()
	active_unit = turn_data.unit
	
	if not active_unit.is_alive():
		_process_next_turn()
		return
	
	turn_started.emit(active_unit)
	
	_process_status_effects(active_unit)
	
	if not active_unit.is_alive():
		turn_ended.emit(active_unit)
		await get_tree().create_timer(turn_delay).timeout
		_process_next_turn()
		return
	
	var allies = _get_allies(active_unit)
	var enemies = _get_enemies(active_unit)
	
	if enemies.is_empty():
		turn_ended.emit(active_unit)
		await get_tree().create_timer(turn_delay).timeout
		_process_next_turn()
		return
	
	var ai = BattleAI.new()
	var action = ai.choose_action(active_unit, allies, enemies)
	
	if action.has("skill") and action.skill != null:
		await _execute_skill(active_unit, action.skill, action.target)
	elif action.has("type") and action.type == "defend":
		await _execute_defend(active_unit)
	else:
		await _execute_basic_attack(active_unit, action.target)
	
	turn_ended.emit(active_unit)
	
	await get_tree().create_timer(turn_delay).timeout
	_process_next_turn()

func _get_allies(unit: BattleUnit) -> Array[BattleUnit]:
	if team1.has(unit):
		return team1.filter(func(u): return u.is_alive())
	else:
		return team2.filter(func(u): return u.is_alive())

func _get_enemies(unit: BattleUnit) -> Array[BattleUnit]:
	if team1.has(unit):
		return team2.filter(func(u): return u.is_alive())
	else:
		return team1.filter(func(u): return u.is_alive())

func _execute_skill(caster: BattleUnit, skill: BattleSkill, target) -> void:
	action_performed.emit(caster, {"type": "skill", "skill": skill, "target": target})
	
	if target is BattleUnit:
		skill.execute(caster, target, rule_processor)
	elif target is Array:
		for t in target:
			if t is BattleUnit and t.is_alive():
				skill.execute(caster, t, rule_processor)
	
	await get_tree().create_timer(0.3).timeout

func _execute_basic_attack(attacker: BattleUnit, target: BattleUnit) -> void:
	if not target or not target.is_alive():
		return
	
	action_performed.emit(attacker, {"type": "attack", "target": target})
	
	var damage = attacker.get_projected_stat("attack")
	target.take_damage(damage)
	
	await get_tree().create_timer(0.2).timeout

func _execute_defend(unit: BattleUnit) -> void:
	action_performed.emit(unit, {"type": "defend"})
	
	var defense_mod = PropertyProjector.Modifier.new(
		"defend_action",
		PropertyProjector.Modifier.Op.MUL,
		1.5,
		50,
		["defense"],
		Time.get_unix_time_from_system() + 1.0
	)
	unit.projectors.defense.add_modifier(defense_mod)
	
	await get_tree().create_timer(0.2).timeout

func _process_status_effects(unit: BattleUnit) -> void:
	var now = Time.get_unix_time_from_system()
	
	for projector in unit.projectors.values():
		projector.prune_expired(now)
	
	var to_remove: Array[StatusEffect] = []
	for status in unit.status_effects:
		if status.is_expired(now):
			to_remove.append(status)
		else:
			status.on_turn_start(unit)
	
	for status in to_remove:
		unit.remove_status_effect(status)

func _check_battle_end() -> bool:
	var team1_alive = team1.filter(func(u): return u.is_alive()).size() > 0
	var team2_alive = team2.filter(func(u): return u.is_alive()).size() > 0
	
	if not team1_alive or not team2_alive:
		var winner = 1 if team1_alive else 2
		_end_battle(winner)
		return true
	
	return false

func _end_battle(winner_team: int) -> void:
	is_battle_active = false
	battle_ended.emit(winner_team)
	
	for unit in team1 + team2:
		if unit.unit_died.is_connected(_on_unit_died):
			unit.unit_died.disconnect(_on_unit_died)

func _on_unit_died(unit: BattleUnit) -> void:
	if _check_battle_end():
		return