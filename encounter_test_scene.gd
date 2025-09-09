extends Node2D

@onready var encounter_manager: EncounterManager = $EncounterManager
@onready var auto_battler: AutoBattler = $AutoBattler
@onready var battlefield: Node2D = $Battlefield

# UI Components
@onready var ui_layer: CanvasLayer = $UILayer
@onready var encounter_info: PanelContainer = $UILayer/EncounterUI/TopPanel
@onready var encounter_title: Label = $UILayer/EncounterUI/TopPanel/VBox/EncounterTitle
@onready var wave_info: Label = $UILayer/EncounterUI/TopPanel/VBox/WaveInfo
@onready var stats_panel: PanelContainer = $UILayer/EncounterUI/StatsPanel
@onready var stats_text: RichTextLabel = $UILayer/EncounterUI/StatsPanel/StatsText

# Selection UI
@onready var selection_panel: PanelContainer = $UILayer/SelectionUI/SelectionPanel
@onready var encounter_list: ItemList = $UILayer/SelectionUI/SelectionPanel/VBox/EncounterList
@onready var encounter_details: RichTextLabel = $UILayer/SelectionUI/SelectionPanel/VBox/EncounterDetails
@onready var start_button: Button = $UILayer/SelectionUI/SelectionPanel/VBox/ButtonContainer/StartButton
@onready var difficulty_selector: OptionButton = $UILayer/SelectionUI/SelectionPanel/VBox/ButtonContainer/DifficultySelector

# Battle UI
@onready var team1_panel: VBoxContainer = $UILayer/BattleUI/Team1Panel/VBox
@onready var team2_panel: VBoxContainer = $UILayer/BattleUI/Team2Panel/VBox
@onready var battle_log: RichTextLabel = $UILayer/BattleUI/BattleLog/ScrollContainer/BattleLog
@onready var wave_progress: ProgressBar = $UILayer/BattleUI/WaveProgress

# Results UI
@onready var results_panel: PanelContainer = $UILayer/ResultsUI/ResultsPanel
@onready var results_text: RichTextLabel = $UILayer/ResultsUI/ResultsPanel/VBox/ResultsText
@onready var continue_button: Button = $UILayer/ResultsUI/ResultsPanel/VBox/ContinueButton

var player_team: Array[BattleUnit] = []
var unit_visuals: Dictionary = {}
var selected_encounter_id: String = ""
var current_wave_enemies: Array[BattleUnit] = []

func _ready() -> void:
    # Verify all UI nodes are loaded
    var ui_nodes = {
        "encounter_manager": encounter_manager,
        "auto_battler": auto_battler,
        "ui_layer": ui_layer,
        "encounter_info": encounter_info,
        "encounter_title": encounter_title,
        "wave_info": wave_info,
        "stats_panel": stats_panel,
        "stats_text": stats_text,
        "selection_panel": selection_panel,
        "encounter_list": encounter_list,
        "start_button": start_button,
        "difficulty_selector": difficulty_selector,
        "team1_panel": team1_panel,
        "team2_panel": team2_panel,
        "battle_log": battle_log,
        "wave_progress": wave_progress,
        "results_panel": results_panel
    }
    
    for node_name in ui_nodes:
        if not ui_nodes[node_name]:
            push_error("UI node not found: " + node_name)
    
    _setup_ui()
    _create_player_team()
    _load_encounters()
    _connect_signals()
    
    # Start with selection screen
    _show_selection_screen()

func _setup_ui() -> void:
    # Setup difficulty selector
    for mode in DifficultyScaler.DifficultyMode:
        difficulty_selector.add_item(DifficultyScaler.get_difficulty_name(DifficultyScaler.DifficultyMode[mode]))
    difficulty_selector.selected = DifficultyScaler.DifficultyMode.NORMAL
    
    start_button.disabled = true
    wave_progress.max_value = 100
    wave_progress.value = 0

func _create_player_team() -> void:
    # Create a balanced team
    var knight = _create_unit("Sir Galahad", 1, {
        "health": 150.0, "max_health": 150.0,
        "attack": 15.0, "defense": 10.0, "speed": 4.0
    }, ["Sword Strike", "Shield Bash"])
    
    var mage = _create_unit("Merlin", 1, {
        "health": 80.0, "max_health": 80.0,
        "attack": 25.0, "defense": 3.0, "speed": 5.0,
        "mana": 100.0, "max_mana": 100.0
    }, ["Fireball", "Frost Bolt"])
    
    var healer = _create_unit("Elena", 1, {
        "health": 100.0, "max_health": 100.0,
        "attack": 8.0, "defense": 6.0, "speed": 4.0,
        "mana": 80.0, "max_mana": 80.0
    }, ["Heal", "Bless"])
    
    var archer = _create_unit("Robin", 1, {
        "health": 100.0, "max_health": 100.0,
        "attack": 18.0, "defense": 5.0, "speed": 7.0
    }, ["Arrow Shot", "Multi Shot"])
    
    player_team = [knight, mage, healer, archer]
    
    # Add to battlefield
    for i in range(player_team.size()):
        var unit = player_team[i]
        battlefield.add_child(unit)
        unit.position = Vector2(200, 150 + i * 100)
        _create_unit_visual(unit, team1_panel)

func _create_unit(unit_name: String, team: int, stats: Dictionary, skill_names: Array[String]) -> BattleUnit:
    var unit = BattleUnit.new()
    unit.unit_name = unit_name
    unit.team = team
    unit.stats = stats
    unit.stats["initiative"] = 0.0
    
    # Add skills
    for skill_name in skill_names:
        unit.add_skill(_create_skill(skill_name))
    
    return unit

func _create_skill(skill_name: String) -> BattleSkill:
    var skill = BattleSkill.new()
    
    match skill_name:
        "Sword Strike":
            skill.skill_name = skill_name
            skill.base_damage = 20.0
            skill.damage_type = "physical"
            skill.target_type = "single_enemy"
        
        "Shield Bash":
            skill.skill_name = skill_name
            skill.base_damage = 10.0
            skill.damage_type = "physical"
            skill.target_type = "single_enemy"
            skill.cooldown = 3.0
        
        "Fireball":
            skill.skill_name = skill_name
            skill.base_damage = 30.0
            skill.damage_type = "fire"
            skill.target_type = "single_enemy"
            skill.resource_cost = 10.0
            skill.resource_type = "mana"
        
        "Frost Bolt":
            skill.skill_name = skill_name
            skill.base_damage = 25.0
            skill.damage_type = "ice"
            skill.target_type = "single_enemy"
            skill.resource_cost = 10.0
            skill.resource_type = "mana"
        
        "Heal":
            skill.skill_name = skill_name
            skill.base_damage = -30.0
            skill.damage_type = "holy"
            skill.target_type = "lowest_health_ally"
            skill.resource_cost = 15.0
            skill.resource_type = "mana"
        
        "Bless":
            skill.skill_name = skill_name
            skill.base_damage = 0.0
            skill.damage_type = "holy"
            skill.target_type = "single_ally"
            skill.resource_cost = 20.0
            skill.resource_type = "mana"
            skill.cooldown = 5.0
        
        "Arrow Shot":
            skill.skill_name = skill_name
            skill.base_damage = 22.0
            skill.damage_type = "physical"
            skill.target_type = "single_enemy"
        
        "Multi Shot":
            skill.skill_name = skill_name
            skill.base_damage = 15.0
            skill.damage_type = "physical"
            skill.target_type = "all_enemies"
            skill.cooldown = 4.0
        
        _:
            skill.skill_name = "Basic Attack"
            skill.base_damage = 10.0
            skill.damage_type = "physical"
            skill.target_type = "single_enemy"
    
    return skill

func _create_unit_visual(unit: BattleUnit, panel: VBoxContainer) -> void:
    var unit_display = PanelContainer.new()
    unit_display.custom_minimum_size = Vector2(250, 80)
    
    var vbox = VBoxContainer.new()
    unit_display.add_child(vbox)
    
    var name_label = Label.new()
    name_label.text = unit.unit_name
    name_label.add_theme_font_size_override("font_size", 16)
    vbox.add_child(name_label)
    
    var hp_container = HBoxContainer.new()
    vbox.add_child(hp_container)
    
    var hp_label = Label.new()
    hp_label.text = "HP: "
    hp_container.add_child(hp_label)
    
    var hp_bar = ProgressBar.new()
    hp_bar.name = "HPBar"
    hp_bar.custom_minimum_size = Vector2(150, 20)
    hp_bar.max_value = unit.stats.max_health
    hp_bar.value = unit.stats.health
    hp_bar.show_percentage = false
    hp_container.add_child(hp_bar)
    
    var hp_value = Label.new()
    hp_value.name = "HPValue"
    hp_value.text = " %d/%d" % [int(unit.stats.health), int(unit.stats.max_health)]
    hp_container.add_child(hp_value)
    
    if "mana" in unit.stats:
        var mana_container = HBoxContainer.new()
        vbox.add_child(mana_container)
        
        var mana_label = Label.new()
        mana_label.text = "MP: "
        mana_container.add_child(mana_label)
        
        var mana_bar = ProgressBar.new()
        mana_bar.name = "MPBar"
        mana_bar.custom_minimum_size = Vector2(150, 15)
        mana_bar.max_value = unit.stats.max_mana
        mana_bar.value = unit.stats.mana
        mana_bar.show_percentage = false
        mana_bar.modulate = Color(0.4, 0.4, 1.0)
        mana_container.add_child(mana_bar)
        
        var mana_value = Label.new()
        mana_value.name = "MPValue"
        mana_value.text = " %d/%d" % [int(unit.stats.mana), int(unit.stats.max_mana)]
        mana_container.add_child(mana_value)
    
    panel.add_child(unit_display)
    unit_visuals[unit] = unit_display

func _load_encounters() -> void:
    encounter_manager.set_player_data({
        "level": 5,
        "completed_encounters": []
    })
    
    var encounters = encounter_manager.get_available_encounters()
    
    encounter_list.clear()
    for encounter in encounters:
        var text = encounter.encounter_name
        if encounter.is_boss_encounter:
            text += " [BOSS]"
        encounter_list.add_item(text)
        encounter_list.set_item_metadata(encounter_list.get_item_count() - 1, encounter.encounter_id)
        
        # Color by difficulty
        var color = Color.WHITE
        match encounter.difficulty_level:
            1: color = Color.GREEN
            2: color = Color.YELLOW  
            3: color = Color.ORANGE
            4: color = Color.RED
            5: color = Color.PURPLE
        encounter_list.set_item_custom_fg_color(encounter_list.get_item_count() - 1, color)

func _connect_signals() -> void:
    # Connect AutoBattler to EncounterManager
    encounter_manager.auto_battler = auto_battler
    
    # UI signals
    encounter_list.item_selected.connect(_on_encounter_selected)
    start_button.pressed.connect(_on_start_encounter)
    difficulty_selector.item_selected.connect(_on_difficulty_changed)
    continue_button.pressed.connect(_on_continue_pressed)
    
    # Encounter signals
    encounter_manager.encounter_started.connect(_on_encounter_started)
    encounter_manager.encounter_completed.connect(_on_encounter_completed)
    encounter_manager.wave_started.connect(_on_wave_started)
    encounter_manager.wave_completed.connect(_on_wave_completed)
    encounter_manager.encounter_failed.connect(_on_encounter_failed)
    
    # Battle signals
    auto_battler.battle_started.connect(_on_battle_started)
    auto_battler.battle_ended.connect(_on_battle_ended)
    auto_battler.turn_started.connect(_on_turn_started)
    auto_battler.action_performed.connect(_on_action_performed)
    
    # Unit signals
    for unit in player_team:
        unit.stat_changed.connect(_on_unit_stat_changed.bind(unit))
        unit.unit_died.connect(_on_unit_died.bind(unit))

func _on_encounter_selected(index: int) -> void:
    selected_encounter_id = encounter_list.get_item_metadata(index)
    start_button.disabled = false
    
    var encounter = encounter_manager.available_encounters[selected_encounter_id]
    
    encounter_details.clear()
    encounter_details.append_text("[b]%s[/b]\n" % encounter.encounter_name)
    encounter_details.append_text("\n%s\n" % encounter.description)
    encounter_details.append_text("\n[b]Waves:[/b] %d\n" % encounter.waves.size())
    encounter_details.append_text("[b]Difficulty:[/b] %s\n" % "⭐".repeat(encounter.get_difficulty_stars()))
    encounter_details.append_text("[b]Duration:[/b] ~%.1f minutes\n" % (encounter.calculate_estimated_duration() / 60.0))
    
    if encounter.rewards:
        encounter_details.append_text("\n[b]Rewards:[/b]\n")
        if encounter.rewards.experience > 0:
            encounter_details.append_text("• XP: %d\n" % encounter.rewards.experience)
        if encounter.rewards.gold > 0:
            encounter_details.append_text("• Gold: %d\n" % encounter.rewards.gold)
        if not encounter.rewards.items.is_empty():
            encounter_details.append_text("• Items: %s\n" % ", ".join(encounter.rewards.items))

func _on_difficulty_changed(index: int) -> void:
    encounter_manager.difficulty_mode = index

func _on_start_encounter() -> void:
    if selected_encounter_id.is_empty():
        return
    
    # Reset player team
    for unit in player_team:
        unit.stats.health = unit.stats.max_health
        if "mana" in unit.stats:
            unit.stats.mana = unit.stats.max_mana
        unit.clear_status_effects()
        _update_unit_visual(unit)
    
    _show_battle_screen()
    battle_log.clear()
    _log_battle("[color=yellow][b]Starting Encounter...[/b][/color]")
    
    encounter_manager.start_encounter(selected_encounter_id, player_team)

func _on_encounter_started(encounter: Encounter) -> void:
    encounter_title.text = encounter.encounter_name
    wave_info.text = "Preparing for battle..."
    _update_stats()

func _on_wave_started(wave_number: int, wave: Wave) -> void:
    wave_info.text = "Wave %d/%d" % [wave_number, encounter_manager.current_encounter.waves.size()]
    
    var progress = float(wave_number - 1) / float(encounter_manager.current_encounter.waves.size()) * 100.0
    wave_progress.value = progress
    
    _log_battle("\n[color=cyan][b]Wave %d Starting![/b][/color]" % wave_number)
    if not wave.wave_name.is_empty():
        _log_battle("→ %s" % wave.wave_name)

func _on_wave_completed(wave_number: int) -> void:
    var progress = float(wave_number) / float(encounter_manager.current_encounter.waves.size()) * 100.0
    wave_progress.value = progress
    
    _log_battle("[color=green]Wave %d Complete![/color]" % wave_number)
    _update_stats()

func _on_encounter_completed(encounter: Encounter, victory: bool, rewards: EncounterRewards) -> void:
    _show_results_screen(encounter, victory, rewards)

func _on_encounter_failed(reason: String) -> void:
    _log_battle("[color=red]Encounter Failed: %s[/color]" % reason)

func _on_battle_started() -> void:
    # Clear enemy visuals
    for child in team2_panel.get_children():
        child.queue_free()
    
    # Create visuals for enemies
    current_wave_enemies = auto_battler.team2
    for enemy in current_wave_enemies:
        _create_unit_visual(enemy, team2_panel)

func _on_battle_ended(winner_team: int) -> void:
    var result = "Victory!" if winner_team == 1 else "Defeat!"
    _log_battle("\n[color=yellow][b]Wave %s[/b][/color]" % result)

func _on_turn_started(unit: BattleUnit) -> void:
    # Highlight active unit
    for u in unit_visuals:
        var visual = unit_visuals[u]
        if u == unit:
            visual.modulate = Color(1.2, 1.2, 1.2)
        else:
            visual.modulate = Color(0.8, 0.8, 0.8)

func _on_action_performed(unit: BattleUnit, action: Dictionary) -> void:
    var message = ""
    
    match action.type:
        "skill":
            if action.target is BattleUnit:
                message = "• %s uses [color=yellow]%s[/color] on %s" % [
                    unit.unit_name, action.skill.skill_name, action.target.unit_name
                ]
            elif action.target is Array:
                message = "• %s uses [color=yellow]%s[/color] on multiple targets" % [
                    unit.unit_name, action.skill.skill_name
                ]
        "attack":
            message = "• %s attacks %s" % [unit.unit_name, action.target.unit_name]
        "defend":
            message = "• %s defends" % unit.unit_name
    
    _log_battle(message)

func _on_unit_stat_changed(stat_name: String, new_value: float, unit: BattleUnit) -> void:
    _update_unit_visual(unit)

func _on_unit_died(unit: BattleUnit) -> void:
    _log_battle("  [color=red]✗ %s has fallen![/color]" % unit.unit_name)
    if unit in unit_visuals:
        unit_visuals[unit].modulate = Color(0.4, 0.4, 0.4)

func _on_continue_pressed() -> void:
    # Clean up the current encounter
    _cleanup_encounter()
    
    # Heal and restore player team
    for unit in player_team:
        # Restore health to max
        unit.stats.health = unit.get_projected_stat("max_health")
        
        # Restore mana if applicable
        if "mana" in unit.stats:
            unit.stats.mana = unit.get_projected_stat("max_mana") if unit.projectors.has("max_mana") else unit.stats.max_mana
        
        # Clear any status effects
        unit.clear_status_effects()
        
        # Update visual
        _update_unit_visual(unit)
    
    # Update player data with completion
    if encounter_manager.current_encounter and encounter_manager.is_encounter_active:
        var player_data = encounter_manager.player_data
        if not player_data.has("completed_encounters"):
            player_data["completed_encounters"] = []
        if encounter_manager.current_encounter.encounter_id not in player_data.completed_encounters:
            player_data.completed_encounters.append(encounter_manager.current_encounter.encounter_id)
        encounter_manager.set_player_data(player_data)
    
    # Return to selection screen
    _show_selection_screen()
    _load_encounters()
    
    # Clear selection
    selected_encounter_id = ""
    start_button.disabled = true

func _update_unit_visual(unit: BattleUnit) -> void:
    if unit not in unit_visuals:
        return
        
    var visual = unit_visuals[unit]
    var hp_bar = visual.find_child("HPBar", true, false)
    var hp_value = visual.find_child("HPValue", true, false)
    
    if hp_bar:
        hp_bar.value = unit.stats.health
    if hp_value:
        hp_value.text = " %d/%d" % [int(unit.stats.health), int(unit.stats.max_health)]
    
    if "mana" in unit.stats:
        var mp_bar = visual.find_child("MPBar", true, false)
        var mp_value = visual.find_child("MPValue", true, false)
        
        if mp_bar:
            mp_bar.value = unit.stats.mana
        if mp_value:
            mp_value.text = " %d/%d" % [int(unit.stats.mana), int(unit.stats.max_mana)]

func _update_stats() -> void:
    stats_text.clear()
    
    var performance = encounter_manager.get_player_performance()
    stats_text.append_text("[b]Session Stats:[/b]\n")
    stats_text.append_text("Win Rate: %.1f%%\n" % (performance.win_rate * 100))
    stats_text.append_text("Units Lost: %d\n" % encounter_manager.session_stats.get("units_lost", 0))
    stats_text.append_text("Perfect Waves: %d\n" % encounter_manager.perfect_waves)
    stats_text.append_text("Total Score: %d" % encounter_manager.total_score)

func _log_battle(message: String) -> void:
    battle_log.append_text(message + "\n")
    # Auto-scroll to bottom
    battle_log.scroll_to_line(battle_log.get_line_count() - 1)

func _show_selection_screen() -> void:
    # Ensure UILayer is visible
    if ui_layer:
        ui_layer.visible = true
    
    # Show selection UI
    var selection_ui = selection_panel.get_parent()
    if selection_ui:
        selection_ui.visible = true
    selection_panel.visible = true
    
    # Hide encounter UI
    var encounter_ui = encounter_info.get_parent()
    if encounter_ui:
        encounter_ui.visible = false
    encounter_info.visible = false
    stats_panel.visible = false
    
    # Hide battle UI
    var battle_ui = team1_panel.get_parent().get_parent() if team1_panel and team1_panel.get_parent() else null
    if battle_ui:
        battle_ui.visible = false
    team1_panel.get_parent().visible = false
    team2_panel.get_parent().visible = false
    battle_log.get_parent().visible = false
    wave_progress.visible = false
    
    # Hide results UI
    var results_ui = results_panel.get_parent()
    if results_ui:
        results_ui.visible = false
    results_panel.visible = false

func _show_battle_screen() -> void:
    if not selection_panel:
        push_error("selection_panel is null")
        return
    if not encounter_info:
        push_error("encounter_info is null")
        return
    if not stats_panel:
        push_error("stats_panel is null")
        return
        
    # Ensure UILayer is visible
    if ui_layer:
        ui_layer.visible = true
    
    # Hide selection UI
    var selection_ui = selection_panel.get_parent()
    if selection_ui:
        selection_ui.visible = false
    selection_panel.visible = false
    
    # Show encounter UI
    var encounter_ui = encounter_info.get_parent()
    if encounter_ui:
        encounter_ui.visible = true
    encounter_info.visible = true
    stats_panel.visible = true
    
    # Show battle UI
    var battle_ui = team1_panel.get_parent().get_parent() if team1_panel and team1_panel.get_parent() else null
    if battle_ui:
        battle_ui.visible = true
    
    if team1_panel and team1_panel.get_parent():
        team1_panel.get_parent().visible = true
    else:
        push_error("team1_panel or its parent is null")
        
    if team2_panel and team2_panel.get_parent():
        team2_panel.get_parent().visible = true
    else:
        push_error("team2_panel or its parent is null")
        
    if battle_log and battle_log.get_parent():
        battle_log.get_parent().visible = true
    else:
        push_error("battle_log or its parent is null")
        
    if wave_progress:
        wave_progress.visible = true
    else:
        push_error("wave_progress is null")
        
    if results_panel:
        results_panel.visible = false
    else:
        push_error("results_panel is null")

func _show_results_screen(encounter: Encounter, victory: bool, rewards: EncounterRewards) -> void:
    # Hide battle UI elements
    if team1_panel and team1_panel.get_parent():
        team1_panel.get_parent().visible = false
    if team2_panel and team2_panel.get_parent():
        team2_panel.get_parent().visible = false
    if battle_log and battle_log.get_parent():
        battle_log.get_parent().visible = false
    wave_progress.visible = false
    
    # Show results panel
    var results_ui = results_panel.get_parent()
    if results_ui:
        results_ui.visible = true
    results_panel.visible = true
    
    # Ensure continue button is visible and enabled
    continue_button.visible = true
    continue_button.disabled = false
    continue_button.text = "Continue"
    
    results_text.clear()
    
    if victory:
        results_text.append_text("[center][color=yellow][b]VICTORY![/b][/color][/center]\n\n")
        results_text.append_text("You have completed [b]%s[/b]!\n\n" % encounter.encounter_name)
        
        results_text.append_text("[b]Rewards:[/b]\n")
        if rewards.experience > 0:
            results_text.append_text("✨ Experience: +%d\n" % rewards.experience)
        if rewards.gold > 0:
            results_text.append_text("💰 Gold: +%d\n" % rewards.gold)
        if not rewards.items.is_empty():
            results_text.append_text("📦 Items: %s\n" % ", ".join(rewards.items))
        
        results_text.append_text("\n[b]Performance:[/b]\n")
        results_text.append_text("Waves Completed: %d/%d\n" % [
            encounter_manager.current_wave_index + 1,
            encounter.waves.size()
        ])
        results_text.append_text("Units Lost: %d\n" % _count_dead_units())
        
        if not encounter.next_encounters.is_empty():
            results_text.append_text("\n[color=green]New encounters unlocked![/color]")
            
        # Add session statistics
        var session_stats = encounter_manager.session_stats
        if not session_stats.is_empty():
            results_text.append_text("\n\n[b]Session Progress:[/b]\n")
            results_text.append_text("Encounters Completed: %d\n" % session_stats.get("encounters_completed", 0))
            results_text.append_text("Total Score: %d\n" % session_stats.get("total_score", 0))
    else:
        results_text.append_text("[center][color=red][b]DEFEAT[/b][/color][/center]\n\n")
        results_text.append_text("Your party was defeated in [b]%s[/b].\n\n" % encounter.encounter_name)
        results_text.append_text("Better luck next time!\n\n")
        
        if rewards.experience > 0 or rewards.gold > 0:
            results_text.append_text("[b]Consolation Rewards:[/b]\n")
            if rewards.experience > 0:
                results_text.append_text("✨ Experience: +%d\n" % rewards.experience)
            if rewards.gold > 0:
                results_text.append_text("💰 Gold: +%d\n" % rewards.gold)
                
        continue_button.text = "Try Again"

func _count_dead_units() -> int:
    var count = 0
    for unit in player_team:
        if not unit.is_alive():
            count += 1
    return count

func _cleanup_encounter() -> void:
    # Clear enemy units
    for enemy in current_wave_enemies:
        if is_instance_valid(enemy):
            enemy.queue_free()
    current_wave_enemies.clear()
    
    # Clear enemy visuals from battlefield
    for child in battlefield.get_children():
        if child.name.begins_with("Enemy"):
            child.queue_free()
    
    # Clear enemy unit displays from team panel
    for child in team2_panel.get_children():
        child.queue_free()
    
    # Reset encounter manager state
    encounter_manager.is_encounter_active = false
