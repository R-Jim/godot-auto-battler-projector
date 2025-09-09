class_name EncounterManager
extends Node

signal encounter_started(encounter: Encounter)
signal encounter_completed(encounter: Encounter, victory: bool, rewards: EncounterRewards)
signal wave_started(wave_number: int, wave: Wave)
signal wave_completed(wave_number: int)
signal all_waves_completed()
signal encounter_failed(reason: String)
signal campaign_progress_updated(completed_encounters: Array[String])

@export var encounter_data_path: String = "res://data/encounters.json"
@export var player_team_size: int = 4
@export var difficulty_mode: DifficultyScaler.DifficultyMode = DifficultyScaler.DifficultyMode.NORMAL

var current_encounter: Encounter
var current_wave_index: int = -1
var player_team: Array[BattleUnit] = []
var encounter_history: Array[String] = []
var total_score: int = 0
var session_stats: Dictionary = {}
var available_encounters: Dictionary = {}
var completed_encounters: Array[String] = []
var unlocked_encounters: Array[String] = []
var player_data: Dictionary = {}

var auto_battler: AutoBattler
var is_encounter_active: bool = false

func set_auto_battler(battler: AutoBattler) -> void:
    auto_battler = battler
var wave_results: Array[Dictionary] = []
var encounter_start_time: float = 0.0
var perfect_waves: int = 0
var total_enemy_count: int = 0
var enemies_defeated: int = 0

func _ready() -> void:
    set_process(false)
    load_encounters()
    
    # Only look for AutoBattler if not already set
    if not auto_battler:
        # Try to find AutoBattler as sibling first (for test scenes)
        auto_battler = get_node_or_null("../AutoBattler")
        if not auto_battler:
            # Try as global singleton
            auto_battler = get_node_or_null("/root/AutoBattler")
        if not auto_battler:
            # Create one if not found
            push_warning("AutoBattler not found! Creating one...")
            auto_battler = AutoBattler.new()
            auto_battler.name = "AutoBattler"
            add_child(auto_battler)

func load_encounters() -> void:
    var file = FileAccess.open(encounter_data_path, FileAccess.READ)
    if not file:
        push_error("Failed to load encounters from: " + encounter_data_path)
        return
    
    var json_text = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    var parse_result = json.parse(json_text)
    
    if parse_result != OK:
        push_error("Failed to parse encounters JSON: " + json.get_error_message())
        return
    
    var data = json.data
    if "encounters" in data:
        for encounter_data in data.encounters:
            var encounter = Encounter.from_dict(encounter_data)
            available_encounters[encounter.encounter_id] = encounter
        
        print("Loaded ", available_encounters.size(), " encounters")

func start_encounter(encounter_id: String, team: Array[BattleUnit]) -> bool:
    if is_encounter_active:
        push_error("An encounter is already active!")
        return false
    
    if encounter_id not in available_encounters:
        push_error("Encounter not found: " + encounter_id)
        return false
    
    current_encounter = available_encounters[encounter_id]
    
    if not current_encounter.is_unlocked(player_data):
        push_error("Encounter is locked: " + encounter_id)
        return false
    
    player_team = team
    current_wave_index = -1
    is_encounter_active = true
    wave_results.clear()
    perfect_waves = 0
    total_enemy_count = current_encounter.get_total_enemies()
    enemies_defeated = 0
    encounter_start_time = Time.get_ticks_msec() / 1000.0
    
    _initialize_session_stats()
    
    encounter_started.emit(current_encounter)
    
    _start_next_wave()
    return true

func stop_encounter() -> void:
    if not is_encounter_active:
        return
    
    is_encounter_active = false
    current_wave_index = -1
    
    if auto_battler.is_battle_active:
        auto_battler.stop_battle()

func _start_next_wave() -> void:
    if not is_encounter_active:
        return
    
    current_wave_index += 1
    
    if current_wave_index >= current_encounter.waves.size():
        _complete_encounter(true)
        return
    
    var wave = current_encounter.waves[current_wave_index]
    wave_started.emit(current_wave_index + 1, wave)
    
    await get_tree().create_timer(wave.spawn_delay).timeout
    
    _start_wave_battle(wave)

func _start_wave_battle(wave: Wave) -> void:
    var difficulty_modifiers = DifficultyScaler.get_difficulty_modifiers(difficulty_mode, encounter_history.size())
    
    var enemy_team: Array[BattleUnit] = []
    for unit_data in wave.enemy_units:
        var units = UnitFactory.create_unit_group(
            unit_data.template_id,
            unit_data.get("count", 1),
            unit_data.get("level", 1),
            2,
            difficulty_modifiers
        )
        enemy_team.append_array(units)
    
    if "formation" in wave and not wave.formation.is_empty():
        UnitFactory.apply_formation(enemy_team, wave.formation, Vector2(600, 300))
    
    for modifier in current_encounter.environment_modifiers:
        auto_battler.rule_processor.add_temporary_rule(modifier)
    
    for modifier in wave.wave_modifiers:
        auto_battler.rule_processor.add_temporary_rule(modifier)
    
    auto_battler.battle_context = {
        "encounter_id": current_encounter.encounter_id,
        "wave_number": current_wave_index + 1,
        "wave_type": Wave.WaveType.keys()[wave.wave_type],
        "difficulty_mode": DifficultyScaler.DifficultyMode.keys()[difficulty_mode]
    }
    
    auto_battler.battle_started.connect(_on_wave_battle_started, CONNECT_ONE_SHOT)
    auto_battler.battle_ended.connect(_on_wave_battle_ended.bind(wave), CONNECT_ONE_SHOT)
    auto_battler.turn_ended.connect(_on_turn_ended.bind(wave), CONNECT_ONE_SHOT)
    
    auto_battler.start_battle(player_team, enemy_team)

func _on_wave_battle_started() -> void:
    session_stats.waves_started += 1

func _on_wave_battle_ended(winner_team: int, wave: Wave) -> void:
    var victory = winner_team == 1
    var wave_time = Time.get_ticks_msec() / 1000.0 - encounter_start_time
    
    var units_lost = 0
    var total_health = 0.0
    var max_total_health = 0.0
    
    for unit in player_team:
        if not unit.is_alive():
            units_lost += 1
            session_stats.units_lost += 1
        else:
            total_health += unit.stats.health
        max_total_health += unit.stats.max_health
    
    var health_percentage = total_health / max_total_health if max_total_health > 0 else 0.0
    
    wave_results.append({
        "wave_index": current_wave_index,
        "victory": victory,
        "time": wave_time,
        "units_lost": units_lost,
        "health_remaining": health_percentage,
        "enemies_defeated": _count_defeated_enemies()
    })
    
    if victory:
        session_stats.waves_completed += 1
        if units_lost == 0:
            perfect_waves += 1
        
        wave_completed.emit(current_wave_index + 1)
        
        await get_tree().create_timer(2.0).timeout
        
        _start_next_wave()
    else:
        _complete_encounter(false)

func _on_turn_ended(unit: BattleUnit, wave: Wave) -> void:
    if wave.wave_type == Wave.WaveType.TIMED or wave.wave_type == Wave.WaveType.SURVIVAL:
        var elapsed = Time.get_ticks_msec() / 1000.0 - encounter_start_time
        var battle_state = {
            "elapsed_time": elapsed,
            "enemies_alive": _count_alive_enemies(),
            "allies": player_team.map(func(u): return {"id": u.unit_name, "alive": u.is_alive()}),
            "enemies": auto_battler.team2.map(func(u): return {"template_id": u.unit_name, "alive": u.is_alive()})
        }
        
        if wave.check_victory_condition(battle_state):
            auto_battler._end_battle(1)

func _complete_encounter(victory: bool) -> void:
    is_encounter_active = false
    var completion_time = Time.get_ticks_msec() / 1000.0 - encounter_start_time
    
    auto_battler.rule_processor.clear_temporary_rules()
    
    var total_rewards = current_encounter.rewards.duplicate() if current_encounter.rewards else EncounterRewards.new()
    
    if victory:
        encounter_history.append(current_encounter.encounter_id)
        completed_encounters.append(current_encounter.encounter_id)
        
        for next_id in current_encounter.next_encounters:
            if next_id not in unlocked_encounters:
                unlocked_encounters.append(next_id)
        
        var score = _calculate_score(completion_time)
        total_score += score
        
        if perfect_waves == current_encounter.waves.size():
            var perfect_bonus = total_rewards.get_performance_bonus("no_deaths")
            if perfect_bonus:
                total_rewards.merge_with(perfect_bonus)
        
        if completion_time < current_encounter.calculate_estimated_duration() * 0.8:
            var time_bonus = total_rewards.get_performance_bonus("under_time")
            if time_bonus:
                total_rewards.merge_with(time_bonus)
        
        var difficulty_multiplier = DifficultyScaler.get_difficulty_modifiers(difficulty_mode, 0).reward_multiplier
        total_rewards.apply_performance_multiplier(difficulty_multiplier)
        
        session_stats.encounters_completed += 1
        campaign_progress_updated.emit(completed_encounters)
    else:
        session_stats.encounters_failed += 1
        encounter_failed.emit("Team was defeated")
        
        total_rewards.apply_performance_multiplier(0.2)
    
    all_waves_completed.emit()
    encounter_completed.emit(current_encounter, victory, total_rewards)

func _calculate_score(completion_time: float) -> int:
    var time_bonus = max(0, 1000 - int(completion_time * 10))
    var health_bonus = 0
    var alive_count = 0
    
    for unit in player_team:
        if unit.is_alive():
            alive_count += 1
            health_bonus += int(unit.stats.health / unit.stats.max_health * 100)
    
    var perfect_bonus = perfect_waves * 200
    var no_death_bonus = 1000 if alive_count == player_team.size() else 0
    var difficulty_multiplier = 1.0 + (int(difficulty_mode) * 0.5)
    
    var base_score = time_bonus + health_bonus + perfect_bonus + no_death_bonus
    return int(base_score * difficulty_multiplier)

func _count_defeated_enemies() -> int:
    return total_enemy_count - _count_alive_enemies()

func _count_alive_enemies() -> int:
    if not auto_battler or not auto_battler.is_battle_active:
        return 0
    
    return auto_battler.team2.filter(func(u): return u.is_alive()).size()

func _initialize_session_stats() -> void:
    session_stats = {
        "encounters_started": session_stats.get("encounters_started", 0) + 1,
        "encounters_completed": session_stats.get("encounters_completed", 0),
        "encounters_failed": session_stats.get("encounters_failed", 0),
        "waves_started": session_stats.get("waves_started", 0),
        "waves_completed": session_stats.get("waves_completed", 0),
        "units_lost": session_stats.get("units_lost", 0),
        "total_score": session_stats.get("total_score", 0) + total_score
    }

func get_player_performance() -> Dictionary:
    var total_encounters = session_stats.get("encounters_started", 1)
    var completed = session_stats.get("encounters_completed", 0)
    var total_waves = session_stats.get("waves_started", 1)
    var waves_won = session_stats.get("waves_completed", 0)
    var units_deployed = player_team.size() * total_encounters
    var units_lost = session_stats.get("units_lost", 0)
    
    return {
        "win_rate": float(completed) / float(total_encounters) if total_encounters > 0 else 0.0,
        "wave_win_rate": float(waves_won) / float(total_waves) if total_waves > 0 else 0.0,
        "unit_death_rate": float(units_lost) / float(units_deployed) if units_deployed > 0 else 0.0,
        "avg_remaining_health": _calculate_average_health(),
        "avg_completion_time": 1.0,
        "perfect_encounter_rate": float(perfect_waves) / float(total_waves) if total_waves > 0 else 0.0
    }

func _calculate_average_health() -> float:
    if wave_results.is_empty():
        return 1.0
    
    var total_health = 0.0
    for result in wave_results:
        total_health += result.get("health_remaining", 0.0)
    
    return total_health / float(wave_results.size())

func get_available_encounters() -> Array[Encounter]:
    var encounters: Array[Encounter] = []
    for encounter_id in available_encounters:
        var encounter = available_encounters[encounter_id]
        if encounter.is_unlocked(player_data):
            encounters.append(encounter)
    return encounters

func set_player_data(data: Dictionary) -> void:
    player_data = data
    if "completed_encounters" in data:
        var completed_array: Array[String] = []
        for enc in data.completed_encounters:
            completed_array.append(str(enc))
        completed_encounters = completed_array
    if "unlocked_encounters" in data:
        var unlocked_array: Array[String] = []
        for enc in data.unlocked_encounters:
            unlocked_array.append(str(enc))
        unlocked_encounters = unlocked_array
