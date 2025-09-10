class_name PlayerHUD
extends Control

@onready var level_label: Label = $VBoxContainer/TopBar/LevelLabel
@onready var exp_bar: ProgressBar = $VBoxContainer/TopBar/ExpBar
@onready var gold_label: Label = $VBoxContainer/TopBar/GoldLabel
@onready var team_container: HBoxContainer = $VBoxContainer/TeamContainer

var progression_manager: Node

func _ready() -> void:
    progression_manager = get_node_or_null("/root/ProgressionManager")
    
    if progression_manager.player_data:
        _connect_signals()
        _update_display()

func _connect_signals() -> void:
    var player_data = progression_manager.player_data
    player_data.level_up.connect(_on_level_up)
    player_data.experience_gained.connect(_on_experience_gained)
    player_data.gold_changed.connect(_on_gold_changed)

func _update_display() -> void:
    var player_data = progression_manager.player_data
    
    level_label.text = "Level %d" % player_data.player_level
    
    var current_exp = player_data.current_experience
    var next_level_exp = player_data.get_experience_for_next_level()
    exp_bar.value = (float(current_exp) / float(next_level_exp)) * 100.0
    exp_bar.tooltip_text = "%d / %d XP" % [current_exp, next_level_exp]
    
    gold_label.text = "Gold: %d" % player_data.gold
    
    _update_team_display()

func _update_team_display() -> void:
    for child in team_container.get_children():
        child.queue_free()
    
    var team = progression_manager.get_active_team()
    
    for unit_data in team:
        var unit_panel = _create_unit_panel(unit_data)
        team_container.add_child(unit_panel)

func _create_unit_panel(unit_data: UnitData) -> Panel:
    var panel = Panel.new()
    panel.custom_minimum_size = Vector2(120, 100)
    
    var vbox = VBoxContainer.new()
    panel.add_child(vbox)
    
    var name_label = Label.new()
    name_label.text = unit_data.get_display_name()
    vbox.add_child(name_label)
    
    var level_label_unit = Label.new()
    level_label_unit.text = "Lv. %d" % unit_data.unit_level
    vbox.add_child(level_label_unit)
    
    var exp_bar_unit = ProgressBar.new()
    exp_bar_unit.custom_minimum_size.y = 10
    var current = unit_data.current_experience
    var next_exp = unit_data.get_experience_for_next_level()
    if next_exp > 0:
        exp_bar_unit.value = (float(current) / float(next_exp)) * 100.0
        exp_bar_unit.tooltip_text = "%d / %d XP" % [current, next_exp]
    else:
        exp_bar_unit.value = 100.0
        exp_bar_unit.tooltip_text = "Max Level"
    vbox.add_child(exp_bar_unit)
    
    var stats_label = Label.new()
    stats_label.text = "Battles: %d\nKills: %d" % [unit_data.total_battles, unit_data.total_kills]
    stats_label.add_theme_font_size_override("font_size", 10)
    vbox.add_child(stats_label)
    
    return panel

func _on_level_up(new_level: int) -> void:
    _update_display()
    
    var popup = AcceptDialog.new()
    popup.dialog_text = "Level Up!\nYou reached level %d!" % new_level
    popup.title = "Level Up"
    add_child(popup)
    popup.popup_centered()
    popup.confirmed.connect(func(): popup.queue_free())

func _on_experience_gained(_amount: int) -> void:
    _update_display()

func _on_gold_changed(_new_amount: int) -> void:
    _update_display()
