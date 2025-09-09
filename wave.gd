class_name Wave
extends Resource

enum WaveType { STANDARD, BOSS, SURVIVAL, TIMED, ENDLESS, OBJECTIVE }
enum VictoryCondition { ELIMINATE_ALL, SURVIVE_TIME, DEFEAT_TARGET, PROTECT_ALLY, CUSTOM }

@export var wave_type: WaveType = WaveType.STANDARD
@export var enemy_units: Array[Dictionary] = []
@export var formation: String = "default"
@export var wave_modifiers: Array[Dictionary] = []
@export var spawn_delay: float = 2.0
@export var victory_condition: VictoryCondition = VictoryCondition.ELIMINATE_ALL
@export var time_limit: float = 0.0
@export var survival_time: float = 0.0
@export var protect_target_id: String = ""
@export var custom_victory_script: String = ""
@export var wave_name: String = ""
@export var wave_description: String = ""
@export var pre_wave_dialogue: Array[Dictionary] = []
@export var post_wave_dialogue: Array[Dictionary] = []

func _init(
    _wave_type: WaveType = WaveType.STANDARD,
    _enemy_units: Array[Dictionary] = []
) -> void:
    wave_type = _wave_type
    enemy_units = _enemy_units

func add_enemy_unit(template_id: String, count: int = 1, level: int = 1, position: String = "") -> void:
    enemy_units.append({
        "template_id": template_id,
        "count": count,
        "level": level,
        "position": position,
        "modifiers": []
    })

func add_wave_modifier(modifier: Dictionary) -> void:
    wave_modifiers.append(modifier)

func get_total_enemy_count() -> int:
    var total = 0
    for unit_data in enemy_units:
        total += unit_data.get("count", 1)
    return total

func get_enemy_types() -> Array[String]:
    var types: Array[String] = []
    for unit_data in enemy_units:
        if "template_id" in unit_data and unit_data.template_id not in types:
            types.append(unit_data.template_id)
    return types

func check_victory_condition(battle_state: Dictionary) -> bool:
    match victory_condition:
        VictoryCondition.ELIMINATE_ALL:
            return battle_state.get("enemies_alive", 1) == 0
        
        VictoryCondition.SURVIVE_TIME:
            return battle_state.get("elapsed_time", 0.0) >= survival_time
        
        VictoryCondition.DEFEAT_TARGET:
            var target_defeated = true
            for enemy in battle_state.get("enemies", []):
                if enemy.get("template_id", "") == protect_target_id and enemy.get("alive", true):
                    target_defeated = false
                    break
            return target_defeated
        
        VictoryCondition.PROTECT_ALLY:
            var ally_alive = false
            for ally in battle_state.get("allies", []):
                if ally.get("id", "") == protect_target_id and ally.get("alive", false):
                    ally_alive = true
                    break
            return ally_alive
        
        VictoryCondition.CUSTOM:
            return battle_state.get("custom_victory", false)
    
    return false

func to_dict() -> Dictionary:
    return {
        "wave_type": WaveType.keys()[wave_type],
        "enemy_units": enemy_units,
        "formation": formation,
        "wave_modifiers": wave_modifiers,
        "spawn_delay": spawn_delay,
        "victory_condition": VictoryCondition.keys()[victory_condition],
        "time_limit": time_limit,
        "survival_time": survival_time,
        "protect_target_id": protect_target_id,
        "custom_victory_script": custom_victory_script,
        "wave_name": wave_name,
        "wave_description": wave_description,
        "pre_wave_dialogue": pre_wave_dialogue,
        "post_wave_dialogue": post_wave_dialogue
    }

static func from_dict(data: Dictionary) -> Wave:
    var wave = Wave.new()
    
    if "wave_type" in data:
        var type_string = data.wave_type.to_upper()
        if type_string in WaveType:
            wave.wave_type = WaveType[type_string]
    
    if "enemy_units" in data:
        wave.enemy_units.clear()
        for unit_data in data.enemy_units:
            if unit_data is Dictionary:
                wave.enemy_units.append(unit_data)
    
    if "formation" in data:
        wave.formation = data.formation
    
    if "wave_modifiers" in data:
        wave.wave_modifiers.clear()
        for modifier in data.wave_modifiers:
            if modifier is Dictionary:
                wave.wave_modifiers.append(modifier)
    
    if "spawn_delay" in data:
        wave.spawn_delay = data.spawn_delay
    
    if "victory_condition" in data:
        var condition_string = data.victory_condition.to_upper()
        if condition_string in VictoryCondition:
            wave.victory_condition = VictoryCondition[condition_string]
    
    if "time_limit" in data:
        wave.time_limit = data.time_limit
    
    if "survival_time" in data:
        wave.survival_time = data.survival_time
    
    if "protect_target_id" in data:
        wave.protect_target_id = data.protect_target_id
    
    if "custom_victory_script" in data:
        wave.custom_victory_script = data.custom_victory_script
    
    if "wave_name" in data:
        wave.wave_name = data.wave_name
    
    if "wave_description" in data:
        wave.wave_description = data.wave_description
    
    if "pre_wave_dialogue" in data:
        wave.pre_wave_dialogue.clear()
        for dialogue in data.pre_wave_dialogue:
            if dialogue is Dictionary:
                wave.pre_wave_dialogue.append(dialogue)
    
    if "post_wave_dialogue" in data:
        wave.post_wave_dialogue.clear()
        for dialogue in data.post_wave_dialogue:
            if dialogue is Dictionary:
                wave.post_wave_dialogue.append(dialogue)
    
    return wave
