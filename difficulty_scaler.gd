class_name DifficultyScaler
extends RefCounted

enum DifficultyMode {
    EASY = 0,
    NORMAL = 1,
    HARD = 2,
    NIGHTMARE = 3,
    ADAPTIVE = 4
}

static func get_difficulty_modifiers(mode: DifficultyMode, encounter_number: int = 0) -> Dictionary:
    var base_modifiers = {
        DifficultyMode.EASY: {
            "enemy_health": 0.7,
            "enemy_damage": 0.8,
            "enemy_defense": 0.8,
            "enemy_speed": 0.9,
            "reward_multiplier": 0.8,
            "enemy_skill_chance": 0.6,
            "enemy_crit_chance": 0.5
        },
        DifficultyMode.NORMAL: {
            "enemy_health": 1.0,
            "enemy_damage": 1.0,
            "enemy_defense": 1.0,
            "enemy_speed": 1.0,
            "reward_multiplier": 1.0,
            "enemy_skill_chance": 0.8,
            "enemy_crit_chance": 1.0
        },
        DifficultyMode.HARD: {
            "enemy_health": 1.3,
            "enemy_damage": 1.2,
            "enemy_defense": 1.1,
            "enemy_speed": 1.1,
            "reward_multiplier": 1.5,
            "enemy_skill_chance": 1.0,
            "enemy_crit_chance": 1.2
        },
        DifficultyMode.NIGHTMARE: {
            "enemy_health": 1.6,
            "enemy_damage": 1.5,
            "enemy_defense": 1.3,
            "enemy_speed": 1.2,
            "reward_multiplier": 2.0,
            "enemy_skill_chance": 1.0,
            "enemy_crit_chance": 1.5
        },
        DifficultyMode.ADAPTIVE: {
            "enemy_health": 1.0,
            "enemy_damage": 1.0,
            "enemy_defense": 1.0,
            "enemy_speed": 1.0,
            "reward_multiplier": 1.0,
            "enemy_skill_chance": 0.8,
            "enemy_crit_chance": 1.0
        }
    }
    
    var modifiers = base_modifiers[mode].duplicate()
    
    if mode != DifficultyMode.ADAPTIVE:
        var progression_multiplier = 1.0 + (encounter_number * 0.05)
        progression_multiplier = min(progression_multiplier, 2.0)
        
        modifiers.enemy_health *= progression_multiplier
        modifiers.enemy_damage *= sqrt(progression_multiplier)
    
    return modifiers

static func get_adaptive_modifiers(player_performance: Dictionary) -> Dictionary:
    var modifiers = {
        "enemy_health": 1.0,
        "enemy_damage": 1.0,
        "enemy_defense": 1.0,
        "enemy_speed": 1.0,
        "reward_multiplier": 1.0,
        "enemy_skill_chance": 0.8,
        "enemy_crit_chance": 1.0
    }
    
    var win_rate = player_performance.get("win_rate", 0.5)
    var avg_unit_health = player_performance.get("avg_remaining_health", 0.5)
    var avg_completion_time = player_performance.get("avg_completion_time", 1.0)
    var death_rate = player_performance.get("unit_death_rate", 0.25)
    
    if win_rate > 0.8:
        modifiers.enemy_health *= 1.1
        modifiers.enemy_damage *= 1.05
        modifiers.reward_multiplier *= 1.1
    elif win_rate < 0.4:
        modifiers.enemy_health *= 0.9
        modifiers.enemy_damage *= 0.95
        modifiers.reward_multiplier *= 0.95
    
    if avg_unit_health > 0.7:
        modifiers.enemy_damage *= 1.1
        modifiers.enemy_skill_chance = min(modifiers.enemy_skill_chance + 0.1, 1.0)
    elif avg_unit_health < 0.3:
        modifiers.enemy_damage *= 0.9
    
    if avg_completion_time < 0.8:
        modifiers.enemy_health *= 1.15
        modifiers.enemy_defense *= 1.1
        modifiers.reward_multiplier *= 1.15
    elif avg_completion_time > 1.5:
        modifiers.enemy_defense *= 0.9
        modifiers.enemy_speed *= 1.1
    
    if death_rate > 0.5:
        modifiers.enemy_damage *= 0.85
        modifiers.enemy_crit_chance *= 0.8
    elif death_rate < 0.1:
        modifiers.enemy_crit_chance *= 1.2
        modifiers.reward_multiplier *= 1.2
    
    return modifiers

static func apply_difficulty_to_unit(unit: BattleUnit, modifiers: Dictionary) -> void:
    if "enemy_health" in modifiers:
        var health_mod = StatProjector.StatModifier.new(
            "difficulty_health",
            StatProjector.StatModifier.Op.MUL,
            modifiers.enemy_health,
            5,
            ["max_health", "health"],
            -1.0  # No expiration
        )
        unit.stat_projectors["max_health"].add_modifier(health_mod)
        unit.stat_projectors["health"].add_modifier(health_mod)
        unit.stats.health = unit.get_projected_stat("max_health")
    
    if "enemy_damage" in modifiers:
        var damage_mod = StatProjector.StatModifier.new(
            "difficulty_damage",
            StatProjector.StatModifier.Op.MUL,
            modifiers.enemy_damage,
            5,
            ["attack"],
            -1.0  # No expiration
        )
        unit.stat_projectors["attack"].add_modifier(damage_mod)
    
    if "enemy_defense" in modifiers:
        var defense_mod = StatProjector.StatModifier.new(
            "difficulty_defense",
            StatProjector.StatModifier.Op.MUL,
            modifiers.enemy_defense,
            5,
            ["defense"],
            -1.0  # No expiration
        )
        unit.stat_projectors["defense"].add_modifier(defense_mod)
    
    if "enemy_speed" in modifiers:
        var speed_mod = StatProjector.StatModifier.new(
            "difficulty_speed",
            StatProjector.StatModifier.Op.MUL,
            modifiers.enemy_speed,
            5,
            ["speed"],
            -1.0  # No expiration
        )
        unit.stat_projectors["speed"].add_modifier(speed_mod)

static func get_difficulty_name(mode: DifficultyMode) -> String:
    match mode:
        DifficultyMode.EASY:
            return "Easy"
        DifficultyMode.NORMAL:
            return "Normal"
        DifficultyMode.HARD:
            return "Hard"
        DifficultyMode.NIGHTMARE:
            return "Nightmare"
        DifficultyMode.ADAPTIVE:
            return "Adaptive"
    return "Unknown"

static func get_difficulty_color(mode: DifficultyMode) -> Color:
    match mode:
        DifficultyMode.EASY:
            return Color.GREEN
        DifficultyMode.NORMAL:
            return Color.WHITE
        DifficultyMode.HARD:
            return Color.ORANGE
        DifficultyMode.NIGHTMARE:
            return Color.RED
        DifficultyMode.ADAPTIVE:
            return Color.CYAN
    return Color.WHITE
