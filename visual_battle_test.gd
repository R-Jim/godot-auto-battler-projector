extends Node2D

@onready var auto_battler: Node2D = $AutoBattler
@onready var start_button: Button = $UI/StartButton
@onready var result_label: Label = $UI/ResultLabel

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	
	# Connect battler signals
	auto_battler.battle_started.connect(_on_battle_started)
	auto_battler.battle_ended.connect(_on_battle_ended)
	auto_battler.round_started.connect(_on_round_started)
	auto_battler.action_performed.connect(_on_action_performed)

func _on_start_pressed() -> void:
	result_label.text = "Creating teams..."
	
	# Create test teams
	var team1: Array[BattleUnit] = []
	var team2: Array[BattleUnit] = []
	
	# Create team 1 units
	for i in range(3):
		var unit = BattleUnit.new()
		unit.unit_name = "Player %d" % (i + 1)
		unit.team = 1
		unit.stats = {
			"health": 100.0,
			"max_health": 100.0,
			"attack": 15.0 + i * 5,
			"defense": 5.0 + i * 2,
			"speed": 5.0 + i
		}
		team1.append(unit)
	
	# Create team 2 units
	for i in range(3):
		var unit = BattleUnit.new()
		unit.unit_name = "Enemy %d" % (i + 1)
		unit.team = 2
		unit.stats = {
			"health": 80.0,
			"max_health": 80.0,
			"attack": 12.0 + i * 3,
			"defense": 3.0 + i * 2,
			"speed": 4.0 + i
		}
		team2.append(unit)
	
	# Start the battle
	auto_battler.start_battle(team1, team2)
	start_button.disabled = true

func _on_battle_started() -> void:
	result_label.text = "Battle started!"

func _on_battle_ended(winner_team: int, _stats: Dictionary) -> void:
	if winner_team == 0:
		result_label.text = "Battle ended in a draw!"
	else:
		result_label.text = "Team %d wins!" % winner_team
	start_button.disabled = false

func _on_round_started(round_num: int) -> void:
	result_label.text = "Round %d started" % round_num

func _on_action_performed(unit: BattleUnit, action: Dictionary) -> void:
	var action_text = ""
	if action.has("type"):
		match action.type:
			"attack":
				if action.has("target"):
					action_text = "%s attacks %s" % [unit.unit_name, action.target.unit_name]
			"skill":
				if action.has("skill") and action.has("target"):
					action_text = "%s uses %s" % [unit.unit_name, action.skill.skill_name]
			"defend":
				action_text = "%s defends" % unit.unit_name
	
	if action_text:
		result_label.text = action_text