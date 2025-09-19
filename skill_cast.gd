class_name SkillCast
extends RefCounted

signal cast_started
signal cast_completed
signal cast_cancelled

var skill: BattleSkill
var caster: BattleUnit
var targets: Array = []  # Array of BattleUnit
var claimed_resources: Dictionary = {}
var cast_start_time: float = -1.0
var is_committed: bool = false
var is_cancelled: bool = false

func _init(_skill: BattleSkill = null, _caster: BattleUnit = null) -> void:
    skill = _skill
    caster = _caster

func claim_resources() -> bool:
    if not skill or not caster:
        push_error("SkillCast: Missing skill or caster")
        return false
    
    if is_committed:
        push_error("SkillCast: Resources already claimed")
        return false
    
    # Check cooldown
    if skill.is_on_cooldown():
        return false
    
    # Atomically check and reserve resources
    if skill.resource_cost > 0:
        var resource_type = skill.resource_type
        var current = caster.stats.get(resource_type, 0.0)
        
        # Check if we have enough including any locked resources
        var locked = caster.get_locked_resource(resource_type)
        var available = current - locked
        
        if available < skill.resource_cost:
            return false
        
        # Reserve the resource
        caster.lock_resource(resource_type, skill.resource_cost)
        claimed_resources[resource_type] = skill.resource_cost
    
    is_committed = true
    cast_start_time = Time.get_unix_time_from_system()
    cast_started.emit()
    
    return true

func refund() -> void:
    if not is_committed or is_cancelled:
        return
    
    # Return locked resources
    for resource_type in claimed_resources:
        var amount = claimed_resources[resource_type]
        caster.unlock_resource(resource_type, amount)
    
    claimed_resources.clear()
    is_committed = false
    is_cancelled = true
    cast_cancelled.emit()

func execute(rule_processor: BattleRuleProcessor) -> bool:
    if not is_committed:
        push_error("SkillCast: Attempting to execute uncommitted cast")
        return false
    
    if is_cancelled:
        push_error("SkillCast: Attempting to execute cancelled cast")
        return false
    
    # Check if caster is still valid
    if not is_instance_valid(caster):
        push_error("SkillCast: Caster is no longer valid")
        return false
    
    # Deduct the locked resources
    for resource_type in claimed_resources:
        var amount = claimed_resources[resource_type]
        caster.unlock_resource(resource_type, amount)
        caster.stats[resource_type] -= amount
        caster.stat_changed.emit(resource_type, caster.stats[resource_type])
    
    # Execute skill on all targets
    for target in targets:
        if is_instance_valid(target) and target.is_alive():
            skill.execute_on_target(caster, target, rule_processor)
    
    # Mark skill as used (for cooldown)
    skill.last_used_time = Time.get_unix_time_from_system()
    
    # Clean up
    claimed_resources.clear()
    is_committed = false
    cast_completed.emit()
    
    return true

func get_cast_progress() -> float:
    if cast_start_time < 0:
        return 0.0
    
    if skill.cast_time <= 0:
        return 1.0
    
    var elapsed = Time.get_unix_time_from_system() - cast_start_time
    return min(1.0, elapsed / skill.cast_time)

func is_ready() -> bool:
    return get_cast_progress() >= 1.0

func interrupt() -> void:
    if is_committed and not is_cancelled:
        refund()

func get_claimed_resource_amount(resource_type: String) -> float:
    return claimed_resources.get(resource_type, 0.0)
