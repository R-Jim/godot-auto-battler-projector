extends GutTest

var encounter: Encounter
var wave: Wave
var rewards: EncounterRewards
var unit_factory: UnitFactory

func before_each() -> void:
    encounter = Encounter.new()
    wave = Wave.new()
    rewards = EncounterRewards.new()

func test_wave_creation() -> void:
    wave.wave_type = Wave.WaveType.STANDARD
    wave.add_enemy_unit("bandit_warrior", 2, 1)
    wave.add_enemy_unit("bandit_archer", 1, 2)
    
    assert_eq(wave.get_total_enemy_count(), 3)
    assert_eq(wave.get_enemy_types().size(), 2)
    assert_true("bandit_warrior" in wave.get_enemy_types())
    assert_true("bandit_archer" in wave.get_enemy_types())

func test_wave_victory_conditions() -> void:
    wave.victory_condition = Wave.VictoryCondition.ELIMINATE_ALL
    var state = {"enemies_alive": 0}
    assert_true(wave.check_victory_condition(state))
    
    state.enemies_alive = 1
    assert_false(wave.check_victory_condition(state))
    
    wave.victory_condition = Wave.VictoryCondition.SURVIVE_TIME
    wave.survival_time = 30.0
    state = {"elapsed_time": 35.0}
    assert_true(wave.check_victory_condition(state))
    
    state.elapsed_time = 25.0
    assert_false(wave.check_victory_condition(state))

func test_encounter_creation() -> void:
    encounter.encounter_id = "test_encounter"
    encounter.encounter_name = "Test Encounter"
    encounter.difficulty_level = 2
    
    encounter.add_wave(wave)
    var wave2 = Wave.new()
    encounter.add_wave(wave2)
    
    assert_eq(encounter.get_wave_count(), 2)
    assert_eq(encounter.get_wave(0), wave)
    assert_eq(encounter.get_wave(1), wave2)
    assert_null(encounter.get_wave(5))

func test_encounter_unlock_requirements() -> void:
    encounter.unlock_requirements = {
        "completed_encounters": ["tutorial"],
        "player_level": 5
    }
    
    var player_data = {
        "completed_encounters": ["tutorial"],
        "level": 5
    }
    assert_true(encounter.is_unlocked(player_data))
    
    player_data.level = 3
    assert_false(encounter.is_unlocked(player_data))
    
    player_data.level = 5
    player_data.completed_encounters = []
    assert_false(encounter.is_unlocked(player_data))

func test_rewards_system() -> void:
    rewards.experience = 100
    rewards.gold = 50
    var items_array: Array[String] = ["potion", "sword"]
    rewards.items = items_array
    
    rewards.apply_performance_multiplier(1.5)
    assert_eq(rewards.experience, 150)
    assert_eq(rewards.gold, 75)
    assert_eq(rewards.items.size(), 2)
    
    var bonus_rewards = EncounterRewards.new()
    bonus_rewards.experience = 50
    bonus_rewards.gold = 25
    var bonus_items: Array[String] = ["gem"]
    bonus_rewards.items = bonus_items
    
    rewards.merge_with(bonus_rewards)
    assert_eq(rewards.experience, 200)
    assert_eq(rewards.gold, 100)
    assert_eq(rewards.items.size(), 3)
    assert_true("gem" in rewards.items)

func test_difficulty_scaling() -> void:
    var easy_mods = DifficultyScaler.get_difficulty_modifiers(DifficultyScaler.DifficultyMode.EASY)
    var normal_mods = DifficultyScaler.get_difficulty_modifiers(DifficultyScaler.DifficultyMode.NORMAL)
    var hard_mods = DifficultyScaler.get_difficulty_modifiers(DifficultyScaler.DifficultyMode.HARD)
    
    assert_lt(easy_mods.enemy_health, normal_mods.enemy_health)
    assert_lt(normal_mods.enemy_health, hard_mods.enemy_health)
    
    assert_lt(easy_mods.enemy_damage, normal_mods.enemy_damage)
    assert_gt(hard_mods.reward_multiplier, normal_mods.reward_multiplier)

func test_adaptive_difficulty() -> void:
    var player_performance = {
        "win_rate": 0.9,
        "avg_remaining_health": 0.8,
        "avg_completion_time": 0.7,
        "unit_death_rate": 0.05
    }
    
    var adaptive_mods = DifficultyScaler.get_adaptive_modifiers(player_performance)
    assert_gt(adaptive_mods.enemy_health, 1.0)
    assert_gt(adaptive_mods.enemy_damage, 1.0)
    assert_gt(adaptive_mods.reward_multiplier, 1.0)
    
    player_performance.win_rate = 0.3
    player_performance.avg_remaining_health = 0.2
    player_performance.unit_death_rate = 0.6
    player_performance.avg_completion_time = 1.2  # Slower completion time
    
    adaptive_mods = DifficultyScaler.get_adaptive_modifiers(player_performance)
    assert_lt(adaptive_mods.enemy_health, 1.0)
    assert_lt(adaptive_mods.enemy_damage, 1.0)

func test_unit_factory_stat_calculation() -> void:
    var base_value = 100.0
    var modifier = 1.2
    var level = 5
    var scaling = 0.1
    
    var final_value = UnitFactory._calculate_stat(base_value, modifier, level, scaling)
    var expected = base_value * modifier * (1.0 + (level - 1) * scaling)
    assert_almost_eq(final_value, expected, 0.01)

func test_wave_serialization() -> void:
    wave.wave_type = Wave.WaveType.BOSS
    wave.wave_name = "Boss Wave"
    wave.add_enemy_unit("boss_unit", 1, 5)
    wave.victory_condition = Wave.VictoryCondition.DEFEAT_TARGET
    wave.time_limit = 120.0
    
    var dict = wave.to_dict()
    assert_eq(dict.wave_type, "BOSS")
    assert_eq(dict.wave_name, "Boss Wave")
    assert_eq(dict.enemy_units.size(), 1)
    assert_eq(dict.victory_condition, "DEFEAT_TARGET")
    assert_eq(dict.time_limit, 120.0)
    
    var wave2 = Wave.from_dict(dict)
    assert_eq(wave2.wave_type, Wave.WaveType.BOSS)
    assert_eq(wave2.wave_name, "Boss Wave")
    assert_eq(wave2.enemy_units.size(), 1)
    assert_eq(wave2.victory_condition, Wave.VictoryCondition.DEFEAT_TARGET)

func test_encounter_serialization() -> void:
    encounter.encounter_id = "test_enc"
    encounter.encounter_name = "Test Encounter"
    encounter.difficulty_level = 3
    encounter.is_boss_encounter = true
    encounter.add_wave(wave)
    
    rewards.experience = 1000
    rewards.gold = 500
    encounter.rewards = rewards
    
    var dict = encounter.to_dict()
    assert_eq(dict.encounter_id, "test_enc")
    assert_eq(dict.difficulty_level, 3)
    assert_true(dict.is_boss_encounter)
    assert_eq(dict.waves.size(), 1)
    assert_eq(dict.rewards.experience, 1000)
    
    var encounter2 = Encounter.from_dict(dict)
    assert_eq(encounter2.encounter_id, "test_enc")
    assert_eq(encounter2.difficulty_level, 3)
    assert_true(encounter2.is_boss_encounter)
    assert_eq(encounter2.waves.size(), 1)
    assert_eq(encounter2.rewards.experience, 1000)
