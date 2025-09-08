extends Node2D

@onready var auto_battler: AutoBattler = $AutoBattler
@onready var team1_container: VBoxContainer = $UI/BattleInfo/Team1
@onready var team2_container: VBoxContainer = $UI/BattleInfo/Team2
@onready var battle_log: RichTextLabel = $UI/BattleLog
@onready var start_button: Button = $UI/StartButton

var team1_units: Array[BattleUnit] = []
var team2_units: Array[BattleUnit] = []

func _ready() -> void:
	_create_teams()
	_setup_ui()
	_connect_signals()

func _create_teams() -> void:
	team1_units = [
		_create_warrior("Knight", 1),
		_create_mage("Fire Mage", 1),
		_create_healer("Cleric", 1)
	]
	
	team2_units = [
		_create_warrior("Barbarian", 2),
		_create_archer("Ranger", 2),
		_create_mage("Ice Mage", 2)
	]
	
	for unit in team1_units:
		add_child(unit)
		unit.position = Vector2(100, 100 + team1_units.find(unit) * 100)
	
	for unit in team2_units:
		add_child(unit)
		unit.position = Vector2(500, 100 + team2_units.find(unit) * 100)

func _create_warrior(unit_name: String, team: int) -> BattleUnit:
	var unit = BattleUnit.new()
	unit.unit_name = unit_name
	unit.team = team
	unit.stats = {
		"health": 150.0,
		"max_health": 150.0,
		"attack": 15.0,
		"defense": 10.0,
		"speed": 3.0,
		"initiative": 0.0
	}
	
	var basic_attack = BattleSkill.new()
	basic_attack.skill_name = "Sword Strike"
	basic_attack.base_damage = 20.0
	basic_attack.damage_type = "physical"
	basic_attack.target_type = "single_enemy"
	unit.add_skill(basic_attack)
	
	var shield_bash = BattleSkill.new()
	shield_bash.skill_name = "shield_bash"
	shield_bash.base_damage = 10.0
	shield_bash.damage_type = "physical"
	shield_bash.target_type = "single_enemy"
	shield_bash.cooldown = 3.0
	unit.add_skill(shield_bash)
	
	var sword = Equipment.create_weapon("Iron Sword", 5.0, "common")
	unit.equip_item("weapon", sword)
	
	var armor = Equipment.create_armor("Iron Armor", 3.0, "common")
	unit.equip_item("armor", armor)
	
	return unit

func _create_mage(unit_name: String, team: int) -> BattleUnit:
	var unit = BattleUnit.new()
	unit.unit_name = unit_name
	unit.team = team
	unit.stats = {
		"health": 80.0,
		"max_health": 80.0,
		"attack": 25.0,
		"defense": 3.0,
		"speed": 5.0,
		"initiative": 0.0,
		"mana": 100.0,
		"max_mana": 100.0
	}
	
	if unit_name.contains("Fire"):
		var fireball = BattleSkill.new()
		fireball.skill_name = "Fireball"
		fireball.base_damage = 30.0
		fireball.damage_type = "fire"
		fireball.target_type = "single_enemy"
		fireball.resource_cost = 10.0
		fireball.resource_type = "mana"
		unit.add_skill(fireball)
	else:
		var frost_bolt = BattleSkill.new()
		frost_bolt.skill_name = "Frost Bolt"
		frost_bolt.base_damage = 25.0
		frost_bolt.damage_type = "ice"
		frost_bolt.target_type = "single_enemy"
		frost_bolt.resource_cost = 10.0
		frost_bolt.resource_type = "mana"
		unit.add_skill(frost_bolt)
	
	var staff = Equipment.create_weapon("Magic Staff", 8.0, "uncommon")
	unit.equip_item("weapon", staff)
	
	return unit

func _create_healer(unit_name: String, team: int) -> BattleUnit:
	var unit = BattleUnit.new()
	unit.unit_name = unit_name
	unit.team = team
	unit.stats = {
		"health": 100.0,
		"max_health": 100.0,
		"attack": 8.0,
		"defense": 6.0,
		"speed": 4.0,
		"initiative": 0.0,
		"mana": 80.0,
		"max_mana": 80.0
	}
	
	var heal = BattleSkill.new()
	heal.skill_name = "Heal"
	heal.base_damage = -25.0
	heal.damage_type = "holy"
	heal.target_type = "single_ally"
	heal.resource_cost = 15.0
	heal.resource_type = "mana"
	unit.add_skill(heal)
	
	var holy_light = BattleSkill.new()
	holy_light.skill_name = "Holy Light"
	holy_light.base_damage = 15.0
	holy_light.damage_type = "holy"
	holy_light.target_type = "single_enemy"
	unit.add_skill(holy_light)
	
	return unit

func _create_archer(unit_name: String, team: int) -> BattleUnit:
	var unit = BattleUnit.new()
	unit.unit_name = unit_name
	unit.team = team
	unit.stats = {
		"health": 100.0,
		"max_health": 100.0,
		"attack": 18.0,
		"defense": 5.0,
		"speed": 7.0,
		"initiative": 0.0
	}
	
	var arrow_shot = BattleSkill.new()
	arrow_shot.skill_name = "Arrow Shot"
	arrow_shot.base_damage = 22.0
	arrow_shot.damage_type = "physical"
	arrow_shot.target_type = "single_enemy"
	unit.add_skill(arrow_shot)
	
	var critical_strike = BattleSkill.new()
	critical_strike.skill_name = "critical_strike"
	critical_strike.base_damage = 30.0
	critical_strike.damage_type = "physical"
	critical_strike.target_type = "single_enemy"
	critical_strike.cooldown = 4.0
	unit.add_skill(critical_strike)
	
	var bow = Equipment.create_weapon("Longbow", 7.0, "common")
	unit.equip_item("weapon", bow)
	
	return unit

func _setup_ui() -> void:
	for unit in team1_units:
		var label = Label.new()
		label.text = "%s - HP: %.0f/%.0f" % [unit.unit_name, unit.stats.health, unit.stats.max_health]
		label.name = unit.unit_name
		team1_container.add_child(label)
	
	for unit in team2_units:
		var label = Label.new()
		label.text = "%s - HP: %.0f/%.0f" % [unit.unit_name, unit.stats.health, unit.stats.max_health]
		label.name = unit.unit_name
		team2_container.add_child(label)

func _connect_signals() -> void:
	start_button.pressed.connect(_on_start_button_pressed)
	
	auto_battler.battle_started.connect(_on_battle_started)
	auto_battler.battle_ended.connect(_on_battle_ended)
	auto_battler.round_started.connect(_on_round_started)
	auto_battler.turn_started.connect(_on_turn_started)
	auto_battler.action_performed.connect(_on_action_performed)
	
	for unit in team1_units + team2_units:
		unit.stat_changed.connect(_on_unit_stat_changed.bind(unit))
		unit.unit_died.connect(_on_unit_died.bind(unit))

func _on_start_button_pressed() -> void:
	start_button.disabled = true
	battle_log.clear()
	battle_log.append_text("[color=green]Starting battle![/color]\n")
	auto_battler.start_battle(team1_units, team2_units)

func _on_battle_started() -> void:
	battle_log.append_text("Battle has begun!\n")

func _on_battle_ended(winner_team: int) -> void:
	battle_log.append_text("\n[color=yellow]Battle ended! Team %d wins![/color]\n" % winner_team)
	start_button.disabled = false

func _on_round_started(round_number: int) -> void:
	battle_log.append_text("\n[color=cyan]Round %d[/color]\n" % round_number)

func _on_turn_started(unit: BattleUnit) -> void:
	battle_log.append_text("  • %s's turn\n" % unit.unit_name)

func _on_action_performed(unit: BattleUnit, action: Dictionary) -> void:
	match action.type:
		"skill":
			if action.target is BattleUnit:
				battle_log.append_text("    → %s uses %s on %s\n" % [
					unit.unit_name,
					action.skill.skill_name,
					action.target.unit_name
				])
			else:
				battle_log.append_text("    → %s uses %s\n" % [
					unit.unit_name,
					action.skill.skill_name
				])
		"attack":
			battle_log.append_text("    → %s attacks %s\n" % [
				unit.unit_name,
				action.target.unit_name
			])
		"defend":
			battle_log.append_text("    → %s defends\n" % unit.unit_name)

func _on_unit_stat_changed(stat_name: String, new_value: float, unit: BattleUnit) -> void:
	if stat_name == "health":
		var container = team1_container if unit.team == 1 else team2_container
		var label = container.get_node(unit.unit_name)
		if label:
			label.text = "%s - HP: %.0f/%.0f" % [
				unit.unit_name,
				unit.stats.health,
				unit.stats.max_health
			]
			
			if unit.get_health_percentage() < 0.3:
				label.modulate = Color.RED
			elif unit.get_health_percentage() < 0.6:
				label.modulate = Color.YELLOW
			else:
				label.modulate = Color.WHITE

func _on_unit_died(unit: BattleUnit) -> void:
	battle_log.append_text("    [color=red]✗ %s has been defeated![/color]\n" % unit.unit_name)
	var container = team1_container if unit.team == 1 else team2_container
	var label = container.get_node(unit.unit_name)
	if label:
		label.modulate = Color(0.5, 0.5, 0.5)