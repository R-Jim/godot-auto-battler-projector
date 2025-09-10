extends Node

@onready var encounter_manager: EncounterManager = $EncounterManager
@onready var auto_battler: AutoBattler = $AutoBattler
@onready var player_hud: PlayerHUD = $PlayerHUD
@onready var encounter_list: ItemList = $EncounterList
@onready var start_button: Button = $StartButton
@onready var save_button: Button = $SaveButton
@onready var load_button: Button = $LoadButton
@onready var add_exp_button: Button = $AddExpButton
@onready var add_gold_button: Button = $AddGoldButton
@onready var results_label: RichTextLabel = $ResultsLabel

var progression_manager: Node

func _ready() -> void:
	progression_manager = get_node_or_null("/root/ProgressionManager")
	
	encounter_manager.set_auto_battler(auto_battler)
	encounter_manager.set_progression_manager(progression_manager)
	
	_setup_ui()
	_connect_signals()
	_ensure_player_has_units()
	_populate_encounter_list()

func _setup_ui() -> void:
	start_button.pressed.connect(_on_start_pressed)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	add_exp_button.pressed.connect(_on_add_exp_pressed)
	add_gold_button.pressed.connect(_on_add_gold_pressed)

func _connect_signals() -> void:
	encounter_manager.encounter_started.connect(_on_encounter_started)
	encounter_manager.encounter_completed.connect(_on_encounter_completed)
	encounter_manager.wave_started.connect(_on_wave_started)
	encounter_manager.wave_completed.connect(_on_wave_completed)

func _populate_encounter_list() -> void:
	encounter_list.clear()
	
	for encounter_id in encounter_manager.available_encounters:
		var encounter = encounter_manager.available_encounters[encounter_id]
		var can_play = progression_manager.player_data.can_play_encounter(encounter)
		var is_completed = encounter_id in progression_manager.player_data.completed_encounters
		
		var display_name = encounter.encounter_name
		if not can_play:
			display_name += " [LOCKED]"
		elif is_completed:
			display_name += " [COMPLETED]"
		
		encounter_list.add_item(display_name)
		var idx = encounter_list.get_item_count() - 1
		encounter_list.set_item_metadata(idx, encounter_id)
		
		if not can_play:
			encounter_list.set_item_disabled(idx, true)

func _on_start_pressed() -> void:
	var selected = encounter_list.get_selected_items()
	if selected.is_empty():
		results_label.text = "[color=red]Please select an encounter[/color]"
		return
	
	var idx = selected[0]
	var encounter_id = encounter_list.get_item_metadata(idx)
	
	results_label.text = "Starting encounter: " + encounter_id
	
	if encounter_manager.start_encounter(encounter_id):
		start_button.disabled = true
	else:
		results_label.text = "[color=red]Failed to start encounter[/color]"

func _on_save_pressed() -> void:
	progression_manager.save_player_data()
	results_label.text = "[color=green]Game saved![/color]"

func _on_load_pressed() -> void:
	progression_manager.load_player_data()
	player_hud._update_display()
	_populate_encounter_list()
	results_label.text = "[color=green]Game loaded![/color]"

func _on_add_exp_pressed() -> void:
	progression_manager.player_data.add_experience(500)
	results_label.text = "[color=yellow]+500 Experience![/color]"

func _on_add_gold_pressed() -> void:
	progression_manager.player_data.add_gold(100)
	results_label.text = "[color=yellow]+100 Gold![/color]"

func _on_encounter_started(encounter: Encounter) -> void:
	results_label.text = "Encounter started: " + encounter.encounter_name
	print("Encounter started: %s with %d waves" % [encounter.encounter_name, encounter.waves.size()])

func _on_encounter_completed(encounter: Encounter, victory: bool, rewards: EncounterRewards) -> void:
	start_button.disabled = false
	
	var text = "\n[b]Encounter Complete![/b]\n"
	if victory:
		text += "[color=green]VICTORY![/color]\n"
		text += "Rewards:\n"
		if rewards.experience > 0:
			text += "- Experience: %d\n" % rewards.experience
		if rewards.gold > 0:
			text += "- Gold: %d\n" % rewards.gold
		if not rewards.items.is_empty():
			text += "- Items: %s\n" % ", ".join(rewards.items)
		if not rewards.unlock_units.is_empty():
			text += "- Unlocked Units: %s\n" % ", ".join(rewards.unlock_units)
		if not rewards.unlock_encounters.is_empty():
			text += "- Unlocked Encounters: %s\n" % ", ".join(rewards.unlock_encounters)
	else:
		text += "[color=red]DEFEAT![/color]\n"
		text += "Better luck next time!\n"
	
	results_label.append_text(text)
	
	_populate_encounter_list()
	
	await get_tree().create_timer(0.5).timeout
	progression_manager.save_player_data()

func _on_wave_started(wave_number: int, wave: Wave) -> void:
	results_label.append_text("\n[color=cyan]Wave %d started: %s[/color]" % [wave_number, wave.wave_name])

func _on_wave_completed(wave_number: int) -> void:
	results_label.append_text("\n[color=green]Wave %d completed![/color]" % wave_number)

func _ensure_player_has_units() -> void:
	# Check if player has any units in their roster
	if progression_manager.player_data.unit_roster.is_empty():
		results_label.text = "[color=yellow]No units found. Creating default team...[/color]\n"
		
		# Create a default team of player units
		var starter_units = ["player_warrior", "player_rogue", "player_mage"]
		
		for i in range(starter_units.size()):
			var template_id = starter_units[i]
			var unit_id = "unit_%d" % i
			var unit_data = UnitData.new(unit_id, template_id)
			unit_data.custom_name = template_id.capitalize().replace("_", " ")
			progression_manager.player_data.add_unit_to_roster(unit_data)
			
		results_label.append_text("[color=green]Created %d starter units![/color]\n" % starter_units.size())
		progression_manager.save_player_data()