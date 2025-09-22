extends Node

signal player_data_loaded()
signal player_data_saved()

var player_data: PlayerData
var auto_save_timer: Timer
var is_dirty: bool = false

const AUTO_SAVE_INTERVAL = 60.0

func _init() -> void:
    player_data = PlayerData.new()

func _ready() -> void:
    setup_auto_save()
    load_player_data()
    
    if player_data:
        player_data.level_up.connect(_on_player_level_up)
        player_data.gold_changed.connect(_on_gold_changed)
        player_data.encounter_completed.connect(_on_encounter_completed)

func setup_auto_save() -> void:
    auto_save_timer = Timer.new()
    auto_save_timer.wait_time = AUTO_SAVE_INTERVAL
    auto_save_timer.timeout.connect(_on_auto_save_timeout)
    auto_save_timer.autostart = true
    add_child(auto_save_timer)

func load_player_data() -> void:
    var loaded_data = SaveManager.load_game()
    
    if loaded_data != null:
        player_data = loaded_data
    else:
        player_data = PlayerData.new()
        create_starter_units()
    
    player_data_loaded.emit()

func create_starter_units() -> void:
    var starter_units = [
        {"unit_id": "starter_warrior", "template_id": "player_warrior"},
        {"unit_id": "starter_archer", "template_id": "player_archer"},
        {"unit_id": "starter_healer", "template_id": "player_healer"}
    ]
    
    for unit_info in starter_units:
        var unit_data = UnitData.new(unit_info.unit_id, unit_info.template_id)
        player_data.add_unit_to_roster(unit_data)

func save_player_data() -> void:
    if SaveManager.save_game(player_data):
        player_data_saved.emit()
        is_dirty = false

func _on_auto_save_timeout() -> void:
    if is_dirty:
        save_player_data()

func _on_player_level_up(new_level: int) -> void:
    is_dirty = true
    print("Player reached level %d!" % new_level)

func _on_gold_changed(new_amount: int) -> void:
    is_dirty = true

func _on_encounter_completed(encounter_id: String) -> void:
    is_dirty = true
    save_player_data()

func apply_encounter_rewards(rewards: EncounterRewards) -> void:
    if rewards.experience > 0:
        player_data.add_experience(rewards.experience)
    
    if rewards.gold > 0:
        player_data.add_gold(rewards.gold)
    
    for item in rewards.items:
        player_data.add_item(item)
    
    for unit_id in rewards.unlock_units:
        player_data.unlock_unit(unit_id)
    
    for encounter_id in rewards.unlock_encounters:
        player_data.unlock_encounter(encounter_id)
    
    for achievement_id in rewards.achievement_progress:
        player_data.update_achievement_progress(
            achievement_id, 
            rewards.achievement_progress[achievement_id]
        )
    
    is_dirty = true

func distribute_unit_experience(units: Array[BattleUnit], experience_pool: int) -> void:
    var alive_units = []
    for unit in units:
        if unit.stats.health > 0:
            alive_units.append(unit)
    
    if alive_units.is_empty():
        return
    
    var experience_per_unit = experience_pool / alive_units.size()
    
    for unit in alive_units:
        var unit_data = player_data.get_unit_data(unit.unit_name)
        if unit_data != null:
            unit_data.add_experience(experience_per_unit)
            unit_data.record_battle()
            is_dirty = true

func upgrade_unit_skill(unit_id: String, skill_id: String) -> bool:
    var unit_data = player_data.get_unit_data(unit_id)
    if unit_data != null:
        if unit_data.upgrade_skill(skill_id):
            is_dirty = true
            return true
    return false

func equip_item_to_unit(unit_id: String, item_id: String, slot: String) -> bool:
    var unit_data = player_data.get_unit_data(unit_id)
    if unit_data != null:
        unit_data.equip_item(slot, item_id)
        is_dirty = true
        return true
    return false

func get_active_team(max_size: int = -1) -> Array[UnitData]:
    if max_size == -1:
        max_size = player_data.team_size_limit
    
    var team: Array[UnitData] = []
    var count = 0
    
    for unit_data in player_data.unit_roster:
        if count >= max_size:
            break
        team.append(unit_data)
        count += 1
    
    return team

func create_battle_units_from_team() -> Array[BattleUnit]:
    var team = get_active_team()
    var battle_units: Array[BattleUnit] = []
    
    for unit_data in team:
        var battle_unit = UnitFactory.create_from_template(
            unit_data.template_id,
            unit_data.unit_level,
            1
        )
        
        if battle_unit != null:
            battle_unit.unit_name = unit_data.unit_id
            
            var level_multiplier = unit_data.get_stat_multiplier()
            for stat in battle_unit.stats:
                if stat != "health" and stat != "max_health":
                    battle_unit.stats[stat] *= level_multiplier
            
            battle_units.append(battle_unit)
    
    # Apply standard formation for player team
    UnitFactory.apply_formation(battle_units, "line", Vector2(200, 300))
    
    return battle_units

func _exit_tree() -> void:
    if is_dirty:
        save_player_data()
