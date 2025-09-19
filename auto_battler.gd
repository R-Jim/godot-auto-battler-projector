class_name AutoBattler
extends Node2D

const UnitVisual = preload("res://unit_visual.gd")

signal battle_started
signal battle_ended(winner_team: int)
signal round_started(round_number: int)
signal round_ended(round_number: int)
signal turn_started(active_unit: BattleUnit)
signal turn_ended(active_unit: BattleUnit)
signal action_performed(unit: BattleUnit, action: Dictionary)

@export var turn_delay: float = 0.5
@export var max_rounds: int = 100
# Feature flag for new system
@export var use_observer_system: bool = false

var team1: Array[BattleUnit] = []
var team2: Array[BattleUnit] = []

var is_battle_active: bool = false
var current_round: int = 0
var turn_queue: Array = []
var active_unit: BattleUnit = null

var rule_processor: BattleRuleProcessor
var battle_context: Dictionary = {}

# New observer system components
var skill_observer = null  # SkillActivationObserver
var observer_battle_context = null  # BattleContext

func _ready() -> void:
    if not rule_processor:
        rule_processor = get_node_or_null("/root/RuleProcessor")
        if not rule_processor:
            push_error("RuleProcessor not found! Make sure it's an autoload.")
    
    if use_observer_system:
        _setup_observer_system()

func start_battle(_team1: Array[BattleUnit], _team2: Array[BattleUnit]) -> void:
    if is_battle_active:
        push_error("Battle already in progress")
        return
    
    team1 = _team1
    team2 = _team2
    
    # Add units to scene tree and create visuals
    for i in range(team1.size()):
        var unit = team1[i]
        add_child(unit)
        _setup_unit_visual(unit)
        # Position team1 units on the left
        unit.position = Vector2(100, 100 + i * 120)
        
    for i in range(team2.size()):
        var unit = team2[i]
        add_child(unit)
        _setup_unit_visual(unit)
        # Position team2 units on the right
        unit.position = Vector2(700, 100 + i * 120)
    
    for unit in team1 + team2:
        unit.unit_died.connect(_on_unit_died.bind(unit))
    
    is_battle_active = true
    current_round = 0
    battle_started.emit()
    
    if use_observer_system:
        _start_observer_battle()
    else:
        await get_tree().create_timer(0.1).timeout
        _start_round()

func _setup_unit_visual(unit: BattleUnit) -> void:
    if not is_instance_valid(unit):
        return
        
    # Create and attach visual component if not present
    var visual = unit.get_node_or_null("UnitVisual")
    if not visual:
        visual = UnitVisual.new()
        visual.name = "UnitVisual"
        unit.add_child(visual)
        visual.setup(unit)

func _start_round() -> void:
    if not is_battle_active:
        return
    
    current_round += 1
    
    if current_round > max_rounds:
        _end_battle(0)
        return
    
    round_started.emit(current_round)
    
    turn_queue.clear()
    for unit in team1 + team2:
        if is_instance_valid(unit) and unit.is_alive():
            var initiative = unit.roll_initiative()
            turn_queue.append({"unit": unit, "initiative": initiative})
    
    turn_queue.sort_custom(_sort_by_initiative)
    
    await get_tree().create_timer(0.1).timeout
    _process_next_turn()

func _sort_by_initiative(a: Dictionary, b: Dictionary) -> bool:
    return a.initiative > b.initiative

func _process_next_turn() -> void:
    if not is_battle_active:
        return
    
    if turn_queue.is_empty():
        round_ended.emit(current_round)
        if _check_battle_end():
            return
        await get_tree().create_timer(0.2).timeout
        _start_round()
        return
    
    var turn_data = turn_queue.pop_front()
    active_unit = turn_data.unit
    
    if not is_instance_valid(active_unit) or not active_unit.is_alive():
        _process_next_turn()
        return
    
    turn_started.emit(active_unit)
    
    _process_status_effects(active_unit)
    
    if not is_instance_valid(active_unit) or not active_unit.is_alive():
        turn_ended.emit(active_unit)
        await get_tree().create_timer(turn_delay).timeout
        _process_next_turn()
        return
    
    var allies = _get_allies(active_unit)
    var enemies = _get_enemies(active_unit)
    
    if enemies.is_empty():
        turn_ended.emit(active_unit)
        await get_tree().create_timer(turn_delay).timeout
        _process_next_turn()
        return
    
    var ai = BattleAI.new()
    var action = ai.choose_action(active_unit, allies, enemies)
    
    if action.has("skill") and action.skill != null:
        await _execute_skill(active_unit, action.skill, action.target)
    elif action.has("type") and action.type == "defend":
        await _execute_defend(active_unit)
    else:
        await _execute_basic_attack(active_unit, action.target)
    
    turn_ended.emit(active_unit)
    
    await get_tree().create_timer(turn_delay).timeout
    _process_next_turn()

func _get_allies(unit: BattleUnit) -> Array[BattleUnit]:
    if team1.has(unit):
        return team1.filter(func(u): return is_instance_valid(u) and u.is_alive())
    else:
        return team2.filter(func(u): return is_instance_valid(u) and u.is_alive())

func _get_enemies(unit: BattleUnit) -> Array[BattleUnit]:
    if team1.has(unit):
        return team2.filter(func(u): return is_instance_valid(u) and u.is_alive())
    else:
        return team1.filter(func(u): return is_instance_valid(u) and u.is_alive())

func _execute_skill(caster: BattleUnit, skill: BattleSkill, target) -> void:
    action_performed.emit(caster, {"type": "skill", "skill": skill, "target": target})
    
    if target is BattleUnit:
        skill.execute(caster, target, rule_processor)
    elif target is Array:
        # For multi-target skills, use the skill once and apply to all targets
        skill.use(caster)
        for t in target:
            if t is BattleUnit and is_instance_valid(t) and t.is_alive():
                skill.execute_on_target(caster, t, rule_processor)
    
    await get_tree().create_timer(0.3).timeout

func _execute_basic_attack(attacker: BattleUnit, target: BattleUnit) -> void:
    if not is_instance_valid(target) or not target.is_alive():
        return
    
    action_performed.emit(attacker, {"type": "attack", "target": target})
    
    var damage = attacker.get_projected_stat("attack")
    target.take_damage(damage)
    
    await get_tree().create_timer(0.2).timeout

func _execute_defend(unit: BattleUnit) -> void:
    action_performed.emit(unit, {"type": "defend"})
    
    var StatProjector = load("res://stat_projector.gd")
    var defense_mod = StatProjector.StatModifier.new(
        "defend_action",
        StatProjector.StatModifier.Op.MUL,
        1.5,
        50,
        ["defense"],
        Time.get_unix_time_from_system() + 1.0
    )
    unit.stat_projectors["defense"].add_modifier(defense_mod)
    
    await get_tree().create_timer(0.2).timeout

func _process_status_effects(unit: BattleUnit) -> void:
    var now = Time.get_unix_time_from_system()
    
    for projector in unit.stat_projectors.values():
        projector.prune_expired(now)
    
    var to_remove: Array[StatusEffect] = []
    for status in unit.status_effects:
        if status.is_expired(now):
            to_remove.append(status)
        else:
            status.on_turn_start(unit)
    
    for status in to_remove:
        unit.remove_status_effect(status)

func _check_battle_end() -> bool:
    var team1_alive_count = team1.filter(func(u): return is_instance_valid(u) and u.is_alive()).size()
    var team2_alive_count = team2.filter(func(u): return is_instance_valid(u) and u.is_alive()).size()
    
    if team1_alive_count == 0 or team2_alive_count == 0:
        var winner = 1 if team1_alive_count > 0 else 2
        _end_battle(winner)
        return true
    
    return false

func _end_battle(winner_team: int) -> void:
    is_battle_active = false
    battle_ended.emit(winner_team)
    
    for unit in team1 + team2:
        if unit.unit_died.is_connected(_on_unit_died):
            unit.unit_died.disconnect(_on_unit_died)

func _on_unit_died(unit: BattleUnit) -> void:
    if _check_battle_end():
        return

# Observer system methods
func _setup_observer_system() -> void:
    var SkillActivationObserver = load("res://skill_activation_observer.gd")
    skill_observer = SkillActivationObserver.new()
    skill_observer.name = "SkillObserver"
    add_child(skill_observer)
    
    var BattleContext = load("res://battle_context.gd")
    observer_battle_context = BattleContext.new()
    observer_battle_context.rule_processor = rule_processor
    
    skill_observer.battle_context = observer_battle_context
    skill_observer.rule_processor = rule_processor
    
    # Connect signals
    skill_observer.skill_initiated.connect(_on_skill_initiated)
    skill_observer.skill_completed.connect(_on_skill_completed)
    skill_observer.skill_interrupted.connect(_on_skill_interrupted)
    skill_observer.cast_progress_updated.connect(_on_cast_progress_updated)

func _start_observer_battle() -> void:
    # Register all units with observer
    for unit in team1 + team2:
        skill_observer.observe_unit(unit)
    
    # Set encounter context if available
    if battle_context.has("encounter_id"):
        observer_battle_context.encounter_id = battle_context.encounter_id
    if battle_context.has("encounter_modifiers"):
        observer_battle_context.encounter_modifiers = battle_context.encounter_modifiers
    
    # Observer system handles all timing automatically
    # Just monitor for battle end
    
func _on_skill_initiated(cast: SkillCast) -> void:
    # Convert to turn signals for compatibility
    turn_started.emit(cast.caster)
    
func _on_skill_completed(cast: SkillCast) -> void:
    # Emit action performed for compatibility
    var action = {
        "type": "skill",
        "skill": cast.skill,
        "targets": cast.targets
    }
    action_performed.emit(cast.caster, action)
    turn_ended.emit(cast.caster)
    
    # Check battle end
    if _check_battle_end():
        if skill_observer:
            skill_observer.queue_free()
            skill_observer = null

func _on_skill_interrupted(cast: SkillCast) -> void:
    # Handle interrupted casts
    turn_ended.emit(cast.caster)
    
func _on_cast_progress_updated(unit: BattleUnit, progress: float) -> void:
    # Could emit signal for UI updates
    pass

func stop_battle() -> void:
    is_battle_active = false
    turn_queue.clear()
    active_unit = null
    
    if use_observer_system and skill_observer:
        # Stop observing all units
        for unit in team1 + team2:
            if is_instance_valid(unit):
                skill_observer.stop_observing(unit)
        
        skill_observer.queue_free()
        skill_observer = null
