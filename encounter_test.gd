extends Node2D

@onready var encounter_manager: EncounterManager = $EncounterManager
@onready var auto_battler: AutoBattler = $AutoBattler
@onready var ui_layer: CanvasLayer = $UILayer
@onready var encounter_info: PanelContainer = $UILayer/EncounterUI/EncounterInfo
@onready var wave_info: Label = $UILayer/EncounterUI/EncounterInfo/VBox/WaveInfo
@onready var encounter_title: Label = $UILayer/EncounterUI/EncounterInfo/VBox/EncounterTitle
@onready var encounter_list: ItemList = $UILayer/EncounterUI/EncounterSelection/VBox/EncounterList
@onready var start_button: Button = $UILayer/EncounterUI/EncounterSelection/VBox/StartButton
@onready var difficulty_selector: OptionButton = $UILayer/EncounterUI/EncounterSelection/VBox/DifficultySelector
@onready var rewards_panel: PanelContainer = $UILayer/RewardsPanel
@onready var rewards_text: RichTextLabel = $UILayer/RewardsPanel/VBox/RewardsText

var player_team: Array[BattleUnit] = []
var selected_encounter_id: String = ""

func _ready() -> void:
	_setup_ui()
	_create_player_team()
	_load_available_encounters()
	_connect_signals()
	
	rewards_panel.visible = false

func _setup_ui() -> void:
	for mode in DifficultyScaler.DifficultyMode:
		difficulty_selector.add_item(DifficultyScaler.get_difficulty_name(DifficultyScaler.DifficultyMode[mode]))
	difficulty_selector.selected = DifficultyScaler.DifficultyMode.NORMAL
	
	start_button.disabled = true

func _create_player_team() -> void:
	var knight = _create_warrior("Knight", 1)
	var mage = _create_mage("Wizard", 1)
	var healer = _create_healer("Cleric", 1)
	var archer = _create_archer("Ranger", 1)
	
	player_team = [knight, mage, healer, archer]

func _load_available_encounters() -> void:
	encounter_list.clear()
	
	if not encounter_manager:
		encounter_manager = EncounterManager.new()
		add_child(encounter_manager)
		encounter_manager.auto_battler = auto_battler
	
	encounter_manager.set_player_data({
		"level": 5,
		"completed_encounters": [],
		"inventory": ["health_potion"]
	})
	
	var encounters = encounter_manager.get_available_encounters()
	for encounter in encounters:
		var text = "%s (Level %d)" % [encounter.encounter_name, encounter.difficulty_level]
		if encounter.is_boss_encounter:
			text += " [BOSS]"
		if encounter.is_optional:
			text += " [OPTIONAL]"
		
		encounter_list.add_item(text)
		encounter_list.set_item_metadata(encounter_list.get_item_count() - 1, encounter.encounter_id)
		
		var color = Color.WHITE
		match encounter.difficulty_level:
			1: color = Color.GREEN
			2: color = Color.YELLOW
			3: color = Color.ORANGE
			4: color = Color.RED
			5: color = Color.PURPLE
		
		encounter_list.set_item_custom_fg_color(encounter_list.get_item_count() - 1, color)

func _connect_signals() -> void:
	encounter_list.item_selected.connect(_on_encounter_selected)
	start_button.pressed.connect(_on_start_encounter)
	difficulty_selector.item_selected.connect(_on_difficulty_changed)
	
	encounter_manager.encounter_started.connect(_on_encounter_started)
	encounter_manager.encounter_completed.connect(_on_encounter_completed)
	encounter_manager.wave_started.connect(_on_wave_started)
	encounter_manager.wave_completed.connect(_on_wave_completed)
	encounter_manager.encounter_failed.connect(_on_encounter_failed)

func _on_encounter_selected(index: int) -> void:
	selected_encounter_id = encounter_list.get_item_metadata(index)
	start_button.disabled = false
	
	var encounter = encounter_manager.available_encounters[selected_encounter_id]
	encounter_title.text = encounter.encounter_name
	wave_info.text = "Waves: %d\nEstimated Duration: %.1f minutes\nDifficulty: %s" % [
		encounter.waves.size(),
		encounter.calculate_estimated_duration() / 60.0,
		"⭐".repeat(encounter.get_difficulty_stars())
	]

func _on_difficulty_changed(index: int) -> void:
	encounter_manager.difficulty_mode = index

func _on_start_encounter() -> void:
	if selected_encounter_id.is_empty():
		return
	
	start_button.disabled = true
	encounter_list.visible = false
	
	for unit in player_team:
		unit.stats.health = unit.stats.max_health
		if "mana" in unit.stats:
			unit.stats.mana = unit.stats.max_mana
		unit.clear_status_effects()
	
	encounter_manager.start_encounter(selected_encounter_id, player_team)

func _on_encounter_started(encounter: Encounter) -> void:
	print("Starting encounter: ", encounter.encounter_name)
	encounter_title.text = encounter.encounter_name
	wave_info.text = "Preparing for battle..."

func _on_wave_started(wave_number: int, wave: Wave) -> void:
	wave_info.text = "Wave %d/%d: %s" % [
		wave_number,
		encounter_manager.current_encounter.waves.size(),
		wave.wave_name if not wave.wave_name.is_empty() else "Wave " + str(wave_number)
	]

func _on_wave_completed(wave_number: int) -> void:
	print("Wave %d completed!" % wave_number)

func _on_encounter_completed(encounter: Encounter, victory: bool, rewards: EncounterRewards) -> void:
	print("Encounter completed! Victory: ", victory)
	
	if victory:
		encounter_title.text = "Victory!"
		wave_info.text = "You have completed %s!" % encounter.encounter_name
	else:
		encounter_title.text = "Defeat"
		wave_info.text = "Your party was defeated..."
	
	_show_rewards(rewards, victory)
	
	await get_tree().create_timer(3.0).timeout
	
	encounter_list.visible = true
	start_button.disabled = false
	_load_available_encounters()

func _on_encounter_failed(reason: String) -> void:
	print("Encounter failed: ", reason)
	encounter_title.text = "Failed"
	wave_info.text = reason

func _show_rewards(rewards: EncounterRewards, victory: bool) -> void:
	rewards_panel.visible = true
	rewards_text.clear()
	
	if victory:
		rewards_text.append_text("[color=yellow][b]REWARDS[/b][/color]\n\n")
		
		if rewards.experience > 0:
			rewards_text.append_text("✨ Experience: +%d\n" % rewards.experience)
		
		if rewards.gold > 0:
			rewards_text.append_text("💰 Gold: +%d\n" % rewards.gold)
		
		if not rewards.items.is_empty():
			rewards_text.append_text("\n[b]Items:[/b]\n")
			for item in rewards.items:
				rewards_text.append_text("  • %s\n" % item)
		
		if not rewards.unlock_encounters.is_empty():
			rewards_text.append_text("\n[b]New Encounters Unlocked![/b]\n")
		
		var performance = encounter_manager.get_player_performance()
		rewards_text.append_text("\n[b]Performance:[/b]\n")
		rewards_text.append_text("Win Rate: %.1f%%\n" % (performance.win_rate * 100))
		rewards_text.append_text("Perfect Waves: %d\n" % encounter_manager.perfect_waves)
	else:
		rewards_text.append_text("[color=red][b]DEFEAT[/b][/color]\n\n")
		rewards_text.append_text("Consolation rewards:\n")
		rewards_text.append_text("✨ Experience: +%d\n" % rewards.experience)
		rewards_text.append_text("💰 Gold: +%d\n" % rewards.gold)

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
	
	var fireball = BattleSkill.new()
	fireball.skill_name = "Fireball"
	fireball.base_damage = 30.0
	fireball.damage_type = "fire"
	fireball.target_type = "single_enemy"
	fireball.resource_cost = 10.0
	fireball.resource_type = "mana"
	unit.add_skill(fireball)
	
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
	
	return unit