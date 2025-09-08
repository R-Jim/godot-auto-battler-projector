extends Node2D

@onready var auto_battler: AutoBattler = $AutoBattler
@onready var battlefield: Node2D = $Battlefield
@onready var ui_layer: CanvasLayer = $UILayer

# UI Elements
@onready var team1_panel: PanelContainer = $UILayer/BattleUI/HSplitContainer/Team1Panel
@onready var team2_panel: PanelContainer = $UILayer/BattleUI/HSplitContainer/Team2Panel
@onready var battle_log: RichTextLabel = $UILayer/BattleUI/BattleLogPanel/ScrollContainer/BattleLog
@onready var control_panel: PanelContainer = $UILayer/BattleUI/ControlPanel
@onready var start_button: Button = $UILayer/BattleUI/ControlPanel/HBoxContainer/StartButton
@onready var pause_button: Button = $UILayer/BattleUI/ControlPanel/HBoxContainer/PauseButton
@onready var speed_slider: HSlider = $UILayer/BattleUI/ControlPanel/HBoxContainer/SpeedContainer/SpeedSlider
@onready var speed_label: Label = $UILayer/BattleUI/ControlPanel/HBoxContainer/SpeedContainer/SpeedLabel
@onready var round_label: Label = $UILayer/BattleUI/TopBar/RoundLabel
@onready var turn_label: Label = $UILayer/BattleUI/TopBar/TurnLabel

var team1_units: Array[BattleUnit] = []
var team2_units: Array[BattleUnit] = []
var unit_visuals: Dictionary = {}

func _ready() -> void:
	_setup_ui()
	_create_teams()
	_setup_battlefield()
	_connect_signals()
	
	# Set initial battle speed
	_on_speed_slider_changed(speed_slider.value)

func _setup_ui() -> void:
	start_button.text = "Start Battle"
	pause_button.text = "Pause"
	pause_button.disabled = true
	speed_slider.min_value = 0.1
	speed_slider.max_value = 2.0
	speed_slider.value = 1.0
	speed_slider.step = 0.1

func _create_teams() -> void:
	# Team 1 - Heroes
	var knight = _create_warrior("Sir Galahad", 1)
	var fire_mage = _create_mage("Pyra", 1, "fire")
	var cleric = _create_healer("Brother Marcus", 1)
	var ranger = _create_archer("Artemis", 1)
	
	team1_units = [knight, fire_mage, cleric, ranger]
	
	# Team 2 - Monsters
	var barbarian = _create_warrior("Gruk", 2)
	barbarian.stats.health = 180.0
	barbarian.stats.max_health = 180.0
	
	var ice_mage = _create_mage("Frost Witch", 2, "ice")
	var shadow_priest = _create_healer("Dark Cultist", 2)
	shadow_priest.stats.attack = 12.0
	
	var assassin = _create_archer("Shadow", 2)
	assassin.stats.speed = 9.0
	
	team2_units = [barbarian, ice_mage, shadow_priest, assassin]
	
	# Add all units to scene
	for unit in team1_units + team2_units:
		battlefield.add_child(unit)

func _setup_battlefield() -> void:
	# Position Team 1 on the left
	for i in range(team1_units.size()):
		var unit = team1_units[i]
		unit.position = Vector2(150, 100 + i * 120)
		
		# Create and setup visual
		var visual = UnitVisual.new()
		visual.setup(unit)
		unit.add_child(visual)
		unit_visuals[unit] = visual
		
		# Add to UI panel
		_add_unit_to_panel(unit, team1_panel.get_node("VBoxContainer/TeamList"))
	
	# Position Team 2 on the right
	for i in range(team2_units.size()):
		var unit = team2_units[i]
		unit.position = Vector2(650, 100 + i * 120)
		
		# Create and setup visual
		var visual = UnitVisual.new()
		visual.setup(unit)
		unit.add_child(visual)
		unit_visuals[unit] = visual
		
		# Add to UI panel
		_add_unit_to_panel(unit, team2_panel.get_node("VBoxContainer/TeamList"))

func _add_unit_to_panel(unit: BattleUnit, container: VBoxContainer) -> void:
	var unit_info = HBoxContainer.new()
	unit_info.name = unit.unit_name
	
	var name_label = Label.new()
	name_label.text = unit.unit_name
	name_label.custom_minimum_size.x = 120
	unit_info.add_child(name_label)
	
	var hp_bar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.custom_minimum_size = Vector2(100, 20)
	hp_bar.max_value = unit.stats.max_health
	hp_bar.value = unit.stats.health
	hp_bar.show_percentage = false
	unit_info.add_child(hp_bar)
	
	var hp_label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.text = "%d/%d" % [int(unit.stats.health), int(unit.stats.max_health)]
	hp_label.custom_minimum_size.x = 60
	unit_info.add_child(hp_label)
	
	container.add_child(unit_info)

func _connect_signals() -> void:
	# UI signals
	start_button.pressed.connect(_on_start_button_pressed)
	pause_button.pressed.connect(_on_pause_button_pressed)
	speed_slider.value_changed.connect(_on_speed_slider_changed)
	
	# Battle signals
	auto_battler.battle_started.connect(_on_battle_started)
	auto_battler.battle_ended.connect(_on_battle_ended)
	auto_battler.round_started.connect(_on_round_started)
	auto_battler.turn_started.connect(_on_turn_started)
	auto_battler.action_performed.connect(_on_action_performed)
	
	# Unit signals
	for unit in team1_units + team2_units:
		unit.stat_changed.connect(_on_unit_stat_changed.bind(unit))
		unit.unit_died.connect(_on_unit_died.bind(unit))

func _on_start_button_pressed() -> void:
	battle_log.clear()
	_log_message("[color=green][b]Battle Starting![/b][/color]")
	start_button.disabled = true
	pause_button.disabled = false
	auto_battler.start_battle(team1_units, team2_units)

func _on_pause_button_pressed() -> void:
	get_tree().paused = not get_tree().paused
	pause_button.text = "Resume" if get_tree().paused else "Pause"

func _on_speed_slider_changed(value: float) -> void:
	Engine.time_scale = value
	speed_label.text = "Speed: %.1fx" % value

func _on_battle_started() -> void:
	_log_message("Heroes face off against Monsters!")

func _on_battle_ended(winner_team: int) -> void:
	var winner_name = "Heroes" if winner_team == 1 else "Monsters"
	_log_message("\n[color=yellow][b]Battle Ended! %s Win![/b][/color]" % winner_name)
	start_button.disabled = false
	pause_button.disabled = true

func _on_round_started(round_number: int) -> void:
	round_label.text = "Round %d" % round_number
	_log_message("\n[color=cyan][b]Round %d[/b][/color]" % round_number)

func _on_turn_started(unit: BattleUnit) -> void:
	turn_label.text = "%s's Turn" % unit.unit_name
	
	# Highlight active unit
	for u in unit_visuals:
		var visual = unit_visuals[u]
		if u == unit:
			visual.scale = Vector2(1.2, 1.2)
			visual.modulate.a = 1.0
		else:
			visual.scale = Vector2(1.0, 1.0)
			visual.modulate.a = 0.7

func _on_action_performed(unit: BattleUnit, action: Dictionary) -> void:
	var visual = unit_visuals.get(unit)
	
	match action.type:
		"skill":
			if visual:
				visual.play_skill_animation(action.skill.skill_name)
			
			if action.target is BattleUnit:
				_log_message("  • %s uses [color=yellow]%s[/color] on %s" % [
					unit.unit_name,
					action.skill.skill_name,
					action.target.unit_name
				])
				
				# Show damage on target
				await get_tree().create_timer(0.2).timeout
				var target_visual = unit_visuals.get(action.target)
				if target_visual and action.skill.base_damage > 0:
					target_visual.play_hurt_animation()
					target_visual.show_damage_number(action.skill.base_damage)
				elif target_visual and action.skill.base_damage < 0:
					target_visual.play_heal_animation()
					target_visual.show_damage_number(action.skill.base_damage)
			
		"attack":
			if visual:
				visual.play_attack_animation()
			
			_log_message("  • %s attacks %s" % [unit.unit_name, action.target.unit_name])
			
			await get_tree().create_timer(0.2).timeout
			var target_visual = unit_visuals.get(action.target)
			if target_visual:
				target_visual.play_hurt_animation()
				target_visual.show_damage_number(unit.get_projected_stat("attack"))
		
		"defend":
			_log_message("  • %s defends" % unit.unit_name)

func _on_unit_stat_changed(stat_name: String, new_value: float, unit: BattleUnit) -> void:
	if stat_name == "health":
		var panel = team1_panel if unit.team == 1 else team2_panel
		var unit_info = panel.get_node("VBoxContainer/TeamList/" + unit.unit_name)
		if unit_info:
			var hp_bar = unit_info.get_node("HPBar")
			var hp_label = unit_info.get_node("HPLabel")
			hp_bar.value = unit.stats.health
			hp_label.text = "%d/%d" % [int(unit.stats.health), int(unit.stats.max_health)]

func _on_unit_died(unit: BattleUnit) -> void:
	_log_message("    [color=red]✗ %s has fallen![/color]" % unit.unit_name)
	
	var panel = team1_panel if unit.team == 1 else team2_panel
	var unit_info = panel.get_node("VBoxContainer/TeamList/" + unit.unit_name)
	if unit_info:
		unit_info.modulate = Color(0.5, 0.5, 0.5)

func _log_message(text: String) -> void:
	battle_log.append_text(text + "\n")

# Unit creation methods
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
	
	# Basic attack skill
	var basic_attack = BattleSkill.new()
	basic_attack.skill_name = "Sword Strike"
	basic_attack.base_damage = 20.0
	basic_attack.damage_type = "physical"
	basic_attack.target_type = "single_enemy"
	unit.add_skill(basic_attack)
	
	# Shield bash skill
	var shield_bash = BattleSkill.new()
	shield_bash.skill_name = "shield_bash"
	shield_bash.base_damage = 10.0
	shield_bash.damage_type = "physical"
	shield_bash.target_type = "single_enemy"
	shield_bash.cooldown = 3.0
	unit.add_skill(shield_bash)
	
	# Equipment
	var sword = Equipment.create_weapon("Iron Sword", 5.0, "common")
	unit.equip_item("weapon", sword)
	
	var armor = Equipment.create_armor("Iron Armor", 3.0, "common")
	unit.equip_item("armor", armor)
	
	return unit

func _create_mage(unit_name: String, team: int, element: String = "fire") -> BattleUnit:
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
	
	if element == "fire":
		var fireball = BattleSkill.new()
		fireball.skill_name = "Fireball"
		fireball.base_damage = 30.0
		fireball.damage_type = "fire"
		fireball.target_type = "single_enemy"
		fireball.resource_cost = 10.0
		fireball.resource_type = "mana"
		unit.add_skill(fireball)
		
		# Apply burning status
		var burn_spell = BattleSkill.new()
		burn_spell.skill_name = "Ignite"
		burn_spell.base_damage = 15.0
		burn_spell.damage_type = "fire"
		burn_spell.target_type = "single_enemy"
		burn_spell.resource_cost = 15.0
		burn_spell.resource_type = "mana"
		burn_spell.cooldown = 4.0
		unit.add_skill(burn_spell)
	else:
		var frost_bolt = BattleSkill.new()
		frost_bolt.skill_name = "Frost Bolt"
		frost_bolt.base_damage = 25.0
		frost_bolt.damage_type = "ice"
		frost_bolt.target_type = "single_enemy"
		frost_bolt.resource_cost = 10.0
		frost_bolt.resource_type = "mana"
		unit.add_skill(frost_bolt)
		
		# Freeze spell
		var freeze = BattleSkill.new()
		freeze.skill_name = "Freeze"
		freeze.base_damage = 10.0
		freeze.damage_type = "ice"
		freeze.target_type = "single_enemy"
		freeze.resource_cost = 20.0
		freeze.resource_type = "mana"
		freeze.cooldown = 5.0
		unit.add_skill(freeze)
	
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
	heal.base_damage = -30.0
	heal.damage_type = "holy"
	heal.target_type = "lowest_health_ally"
	heal.resource_cost = 15.0
	heal.resource_type = "mana"
	unit.add_skill(heal)
	
	var holy_light = BattleSkill.new()
	holy_light.skill_name = "Holy Light"
	holy_light.base_damage = 15.0
	holy_light.damage_type = "holy"
	holy_light.target_type = "single_enemy"
	unit.add_skill(holy_light)
	
	var bless = BattleSkill.new()
	bless.skill_name = "Bless"
	bless.base_damage = 0.0
	bless.damage_type = "holy"
	bless.target_type = "single_ally"
	bless.resource_cost = 20.0
	bless.resource_type = "mana"
	bless.cooldown = 6.0
	unit.add_skill(bless)
	
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
	
	var volley = BattleSkill.new()
	volley.skill_name = "Volley"
	volley.base_damage = 15.0
	volley.damage_type = "physical"
	volley.target_type = "all_enemies"
	volley.cooldown = 6.0
	unit.add_skill(volley)
	
	var bow = Equipment.create_weapon("Longbow", 7.0, "common")
	unit.equip_item("weapon", bow)
	
	return unit