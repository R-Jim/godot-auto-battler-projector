class_name BattleSkill
extends RefCounted

@export var skill_name: String = "Skill"
@export var description: String = ""
@export var base_damage: float = 10.0
@export var damage_type: String = "physical"
@export var target_type: String = "single_enemy"
@export var cooldown: float = 0.0
@export var resource_cost: float = 0.0
@export var resource_type: String = "mana"
@export var cast_time: float = 0.0

var last_used_time: float = 0.0

func is_on_cooldown() -> bool:
    if cooldown <= 0:
        return false
    var now = Time.get_unix_time_from_system()
    return now < (last_used_time + cooldown)

func can_use(caster: BattleUnit) -> bool:
    if is_on_cooldown():
        return false
    
    if resource_cost > 0:
        if not caster.stats.has(resource_type):
            return false
        var available = caster.get_available_resource(resource_type)
        if available < resource_cost:
            return false
    
    return true

func get_unusable_reason(caster: BattleUnit) -> String:
    if is_on_cooldown():
        var now = Time.get_unix_time_from_system()
        var remaining = last_used_time + cooldown - now
        return "on cooldown for %.1f more seconds (last_used: %.1f, now: %.1f, cooldown: %.1f)" % [remaining, last_used_time, now, cooldown]
    
    if resource_cost > 0:
        if not caster.stats.has(resource_type):
            return "caster missing resource type '%s'" % resource_type
        var available = caster.get_available_resource(resource_type)
        var locked = caster.get_locked_resource(resource_type)
        if available < resource_cost:
            if locked > 0:
                return "insufficient %s (%.0f/%.0f available, %.0f locked)" % [resource_type, available, resource_cost, locked]
            else:
                return "insufficient %s (%.0f/%.0f)" % [resource_type, available, resource_cost]
    
    return ""

func use(caster: BattleUnit) -> void:
    # Legacy method - now just marks skill as used for backward compatibility
    # Actual resource handling should go through SkillCast
    if not can_use(caster):
        var reason = get_unusable_reason(caster)
        push_error("BattleSkill: Cannot use '%s' - %s" % [skill_name, reason])
        return
    
    # For backward compatibility - immediate execution without cast system
    if resource_cost > 0 and caster.stats.has(resource_type):
        var available = caster.get_available_resource(resource_type)
        if available >= resource_cost:
            caster.stats[resource_type] -= resource_cost
            caster.stat_changed.emit(resource_type, caster.stats[resource_type])
        else:
            push_error("BattleSkill: Race condition detected - resource no longer available")
            return
    
    # Always set last_used_time if we successfully use the skill
    last_used_time = Time.get_unix_time_from_system()

func prepare_cast(caster: BattleUnit) -> SkillCast:
    var cast = SkillCast.new(self, caster)
    return cast

func execute_on_target(caster: BattleUnit, target: BattleUnit, rule_processor: BattleRuleProcessor) -> void:
    # Execute the skill effect on a specific target (no cooldown/resource check)
    var context = _build_context(caster, target)
    var contextual_modifiers = rule_processor.get_modifiers_for_context(context)
    
    var damage_projector = StatProjector.new()
    
    if caster.stat_projectors.has("attack"):
        for mod in caster.stat_projectors["attack"].list_modifiers():
            var new_mod = StatProjector.StatModifier.new(
                mod.id,
                mod.op,
                mod.value,
                mod.priority,
                mod.applies_to,
                mod.expires_at_unix
            )
            damage_projector.add_modifier(new_mod)
    
    for mod in contextual_modifiers:
        if mod is StatProjector.StatModifier:
            damage_projector.add_modifier(mod)
        else:
            push_error("Invalid modifier type in contextual_modifiers: " + str(typeof(mod)))
    
    var final_damage = damage_projector.calculate_stat(base_damage)
    
    _apply_effects(caster, target, final_damage)

func execute(caster: BattleUnit, target: BattleUnit, rule_processor: BattleRuleProcessor) -> void:
    # Legacy method for single-target skills - uses immediate execution
    if not can_use(caster):
        return
    
    use(caster)
    execute_on_target(caster, target, rule_processor)

func _build_context(caster: BattleUnit, target: BattleUnit) -> Dictionary:
    return {
        "skill_name": skill_name,
        "skill_damage_type": damage_type,
        "caster_health_percentage": caster.get_health_percentage(),
        "caster_team": caster.team,
        "caster_status": caster.get_status_list(),
        "target_health_percentage": target.get_health_percentage(),
        "target_team": target.team,
        "target_status": target.get_status_list()
    }

func _apply_effects(caster: BattleUnit, target: BattleUnit, damage: float) -> void:
    match target_type:
        "single_enemy":
            if target and target.is_alive():
                target.take_damage(damage)
        "self":
            caster.heal(damage)
        "single_ally":
            if target and target.is_alive():
                target.heal(damage)
        _:
            target.take_damage(damage)

func get_targets(caster: BattleUnit, allies: Array[BattleUnit], enemies: Array[BattleUnit]) -> Array[BattleUnit]:
    var valid_targets: Array[BattleUnit] = []
    
    match target_type:
        "single_enemy":
            valid_targets = enemies.filter(func(u): return u.is_alive())
        "all_enemies":
            valid_targets = enemies.filter(func(u): return u.is_alive())
        "single_ally":
            valid_targets = allies.filter(func(u): return u.is_alive())
        "all_allies":
            valid_targets = allies.filter(func(u): return u.is_alive())
        "self":
            valid_targets = [caster]
        "random_enemy":
            var alive_enemies = enemies.filter(func(u): return u.is_alive())
            if not alive_enemies.is_empty():
                valid_targets = [alive_enemies[randi() % alive_enemies.size()]]
        "lowest_health_enemy":
            var alive_enemies = enemies.filter(func(u): return u.is_alive())
            if not alive_enemies.is_empty():
                alive_enemies.sort_custom(func(a, b): return a.stats.health < b.stats.health)
                valid_targets = [alive_enemies[0]]
        "lowest_health_ally":
            var alive_allies = allies.filter(func(u): return u.is_alive())
            if not alive_allies.is_empty():
                alive_allies.sort_custom(func(a, b): return a.stats.health < b.stats.health)
                valid_targets = [alive_allies[0]]
    
    return valid_targets

func clone() -> BattleSkill:
    var new_skill = BattleSkill.new()
    new_skill.skill_name = skill_name
    new_skill.description = description
    new_skill.base_damage = base_damage
    new_skill.damage_type = damage_type
    new_skill.target_type = target_type
    new_skill.cooldown = cooldown
    new_skill.resource_cost = resource_cost
    new_skill.resource_type = resource_type
    new_skill.cast_time = cast_time
    return new_skill
