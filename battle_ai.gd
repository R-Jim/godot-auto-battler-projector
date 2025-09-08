class_name BattleAI
extends RefCounted

enum AIType {
    AGGRESSIVE,
    DEFENSIVE,
    BALANCED,
    SUPPORT,
    RANDOM
}

@export var ai_type: AIType = AIType.BALANCED
@export var skill_preference: float = 0.7
@export var target_lowest_health: float = 0.6
@export var heal_threshold: float = 0.5

func choose_action(unit: BattleUnit, allies: Array[BattleUnit], enemies: Array[BattleUnit]) -> Dictionary:
    var valid_enemies = enemies.filter(func(u): return u.is_alive())
    var valid_allies = allies.filter(func(u): return u.is_alive())
    
    if valid_enemies.is_empty():
        return {"type": "wait"}
    
    var available_skills = _get_available_skills(unit)
    
    if available_skills.is_empty() or randf() > skill_preference:
        return {
            "type": "attack",
            "target": _choose_target(valid_enemies, unit)
        }
    
    var action = _choose_skill_action(unit, available_skills, valid_enemies, valid_allies)
    return action

func _get_available_skills(unit: BattleUnit) -> Array[BattleSkill]:
    var available: Array[BattleSkill] = []
    for skill in unit.skills:
        if skill.can_use(unit):
            available.append(skill)
    return available

func _choose_skill_action(unit: BattleUnit, skills: Array[BattleSkill], enemies: Array[BattleUnit], allies: Array[BattleUnit]) -> Dictionary:
    var best_action = {"type": "attack", "target": null}
    var best_score = -INF
    
    for skill in skills:
        var targets = skill.get_targets(unit, allies, enemies)
        if targets.is_empty():
            continue
        
        var score = _evaluate_skill_action(unit, skill, targets)
        if score > best_score:
            best_score = score
            best_action = {
                "type": "skill",
                "skill": skill,
                "target": _select_best_target(skill, targets, unit)
            }
    
    if best_action.target == null and not enemies.is_empty():
        best_action.target = enemies[0]
    
    return best_action

func _evaluate_skill_action(unit: BattleUnit, skill: BattleSkill, potential_targets: Array[BattleUnit]) -> float:
    var score = 0.0
    
    score += skill.base_damage * 0.1
    
    match skill.target_type:
        "all_enemies":
            score += potential_targets.size() * 20
        "single_enemy":
            score += 10
        "single_ally":
            var needs_healing = potential_targets.filter(func(t): return t.get_health_percentage() < heal_threshold)
            score += needs_healing.size() * 15
        "self":
            if unit.get_health_percentage() < heal_threshold:
                score += 25
    
    match ai_type:
        AIType.AGGRESSIVE:
            if skill.damage_type in ["physical", "magical", "fire", "ice"]:
                score *= 1.5
        AIType.DEFENSIVE:
            if skill.target_type in ["self", "single_ally", "all_allies"]:
                score *= 1.5
        AIType.SUPPORT:
            if skill.target_type in ["single_ally", "all_allies"]:
                score *= 2.0
    
    if skill.damage_type == "fire":
        for target in potential_targets:
            if "frozen" in target.get_status_list():
                score += 20
    
    return score

func _select_best_target(skill: BattleSkill, targets: Array[BattleUnit], caster: BattleUnit) -> Variant:
    if targets.is_empty():
        return null
    
    if targets.size() == 1:
        return targets[0]
    
    match skill.target_type:
        "single_enemy", "random_enemy":
            return _choose_target(targets, caster)
        "single_ally":
            targets.sort_custom(func(a, b): return a.get_health_percentage() < b.get_health_percentage())
            return targets[0]
        "all_enemies", "all_allies":
            return targets
        _:
            return targets[0]

func _choose_target(enemies: Array[BattleUnit], unit: BattleUnit) -> BattleUnit:
    if enemies.is_empty():
        return null
    
    match ai_type:
        AIType.AGGRESSIVE:
            if randf() < target_lowest_health:
                enemies.sort_custom(func(a, b): return a.stats.health < b.stats.health)
            else:
                enemies.sort_custom(func(a, b): return a.get_projected_stat("attack") > b.get_projected_stat("attack"))
        
        AIType.DEFENSIVE:
            enemies.sort_custom(func(a, b): return a.get_projected_stat("attack") > b.get_projected_stat("attack"))
        
        AIType.BALANCED:
            if randf() < 0.5:
                enemies.sort_custom(func(a, b): return a.stats.health < b.stats.health)
            else:
                enemies.sort_custom(func(a, b): return _threat_score(a) > _threat_score(b))
        
        AIType.RANDOM:
            enemies.shuffle()
    
    return enemies[0]

func _threat_score(unit: BattleUnit) -> float:
    var attack = unit.get_projected_stat("attack")
    var health_percent = unit.get_health_percentage()
    var speed = unit.get_projected_stat("speed")
    
    return attack * (1.0 + health_percent) * (1.0 + speed * 0.1)

static func create(type: AIType) -> BattleAI:
    var ai = BattleAI.new()
    ai.ai_type = type
    
    match type:
        AIType.AGGRESSIVE:
            ai.skill_preference = 0.8
            ai.target_lowest_health = 0.8
            ai.heal_threshold = 0.3
        AIType.DEFENSIVE:
            ai.skill_preference = 0.6
            ai.target_lowest_health = 0.4
            ai.heal_threshold = 0.7
        AIType.SUPPORT:
            ai.skill_preference = 0.9
            ai.target_lowest_health = 0.3
            ai.heal_threshold = 0.6
        AIType.BALANCED:
            ai.skill_preference = 0.7
            ai.target_lowest_health = 0.6
            ai.heal_threshold = 0.5
        AIType.RANDOM:
            ai.skill_preference = randf()
            ai.target_lowest_health = randf()
            ai.heal_threshold = randf()
    
    return ai
