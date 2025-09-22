class_name SkillEvaluator
extends RefCounted

# Scoring weights configurable per AI type
var scoring_weights: Dictionary = {
    "damage_efficiency": 1.0,
    "resource_efficiency": 0.8,
    "combo_potential": 1.2,
    "situational_bonus": 1.5,
    "target_priority": 1.0,
    "timing_bonus": 0.9,
    "risk_assessment": 0.7
}

# Minimum score threshold for skill activation
var activation_threshold: float = 30.0

# Debug mode for logging decisions
var debug_mode: bool = false

func evaluate_skills(unit: BattleUnit, context: Dictionary) -> BattleSkill:
    var evaluations: Array[Dictionary] = []
    
    # Set AI-specific weights
    _apply_ai_weights(unit)
    
    for skill in unit.skills:
        if not skill.can_use(unit):
            continue
        
        var score = _calculate_skill_score(skill, unit, context)
        
        if score >= activation_threshold:
            evaluations.append({
                "skill": skill,
                "score": score,
                "breakdown": _get_last_score_breakdown()
            })
    
    evaluations.sort_custom(func(a, b): return a.score > b.score)
    
    if debug_mode and not evaluations.is_empty():
        _log_evaluation_results(unit, evaluations)
    
    return evaluations[0].skill if not evaluations.is_empty() else null

func _calculate_skill_score(skill: BattleSkill, unit: BattleUnit, context: Dictionary) -> float:
    var scores = {}
    
    # 1. Damage Efficiency Score
    scores["damage_efficiency"] = _evaluate_damage_efficiency(skill, unit, context)
    
    # 2. Resource Efficiency Score
    scores["resource_efficiency"] = _evaluate_resource_efficiency(skill, unit, context)
    
    # 3. Combo Potential Score
    scores["combo_potential"] = _evaluate_combo_potential(skill, unit, context)
    
    # 4. Situational Bonus Score
    scores["situational_bonus"] = _evaluate_situational_factors(skill, unit, context)
    
    # 5. Target Priority Score
    scores["target_priority"] = _evaluate_target_priority(skill, unit, context)
    
    # 6. Timing Bonus Score
    scores["timing_bonus"] = _evaluate_timing_factors(skill, unit, context)
    
    # 7. Risk Assessment Score
    scores["risk_assessment"] = _evaluate_risk_factors(skill, unit, context)
    
    # Apply weights and calculate total
    var total_score: float = 0.0
    for factor in scores:
        total_score += scores[factor] * scoring_weights.get(factor, 1.0)
    
    # Store breakdown for debugging
    _last_score_breakdown = scores
    _last_total_score = total_score
    
    return total_score

func _evaluate_damage_efficiency(skill: BattleSkill, unit: BattleUnit, context: Dictionary) -> float:
    var score: float = 0.0
    
    # Base damage consideration
    score += skill.base_damage * 0.5
    
    # Calculate expected damage with modifiers
    var damage_projector = StatProjector.new()
    
    # Copy caster's attack modifiers if applicable
    if unit.stat_projectors.has("attack"):
        for mod in unit.stat_projectors["attack"].list_modifiers():
            var new_mod = StatProjector.StatModifier.new(
                mod.id,
                mod.op,
                mod.value,
                mod.priority,
                mod.applies_to,
                mod.expires_at_unix
            )
            damage_projector.add_modifier(new_mod)
    
    var potential_targets = skill.get_targets(unit, context.allies, context.enemies)
    var total_expected_damage: float = 0.0
    
    for target in potential_targets:
        # Build target-specific context
        var skill_context = {
            "skill_name": skill.skill_name,
            "skill_damage_type": skill.damage_type,
            "caster_health_percentage": unit.get_health_percentage(),
            "caster_team": unit.team,
            "target_health_percentage": target.get_health_percentage(),
            "target_status": target.get_status_list(),
            "target_team": target.team
        }
        
        # Get contextual modifiers
        if context.has("rule_processor") and context.rule_processor:
            var mods = context.rule_processor.get_modifiers_for_context(skill_context)
            for mod in mods:
                damage_projector.add_modifier(mod)
        
        var final_damage = damage_projector.calculate_stat(skill.base_damage)
        
        # Account for defense
        if target.stat_projectors.has("defense"):
            var defense = target.get_projected_stat("defense")
            final_damage = max(1.0, final_damage - defense)
        
        # Weight by target value
        var target_value = _calculate_target_value(target, context)
        total_expected_damage += final_damage * target_value
    
    # Normalize score (0-100 range)
    return min(100.0, total_expected_damage / 10.0)

func _evaluate_resource_efficiency(skill: BattleSkill, unit: BattleUnit, context: Dictionary) -> float:
    if skill.resource_cost <= 0:
        return 100.0  # Free skills have perfect efficiency
    
    var current_resource = unit.stats.get(skill.resource_type, 0.0)
    var available_resource = unit.get_available_resource(skill.resource_type)
    var max_resource = unit.stats.get("max_" + skill.resource_type, 100.0)
    
    if max_resource <= 0:
        return 0.0
    
    var resource_percentage = available_resource / max_resource
    var cost_ratio = skill.resource_cost / max_resource
    
    var efficiency: float = 0.0
    
    # High efficiency when: low cost, high resources, or critical situation
    if resource_percentage > 0.7:
        # Abundant resources - efficiency based on damage per resource
        efficiency = (skill.base_damage / skill.resource_cost) * 10.0
    elif resource_percentage > 0.3:
        # Moderate resources - balanced approach
        efficiency = 50.0 + (resource_percentage - 0.3) * 50.0
    else:
        # Low resources - only use if critical
        var urgency = _calculate_battle_urgency(context)
        efficiency = urgency * (1.0 - cost_ratio) * 100.0
    
    return clamp(efficiency, 0.0, 100.0)

func _evaluate_combo_potential(skill: BattleSkill, unit: BattleUnit, context: Dictionary) -> float:
    var score: float = 0.0
    
    if not context.has("skill_history"):
        return score
    
    var recent_skills = context.skill_history.slice(-5) if context.skill_history.size() > 5 else context.skill_history
    
    for historical in recent_skills:
        # Self-combo potential
        if historical.caster == unit:
            var combo_score = _check_skill_combo_score(historical.skill, skill)
            score += combo_score * 1.5
        # Team combo potential
        elif historical.caster.team == unit.team:
            var synergy_score = _check_skill_synergy_score(historical.skill, skill)
            score += synergy_score
    
    # Check if skill enables future combos
    var enables_combos = _count_enabled_combos(skill, context)
    score += enables_combos * 10.0
    
    return score

func _evaluate_situational_factors(skill: BattleSkill, unit: BattleUnit, context: Dictionary) -> float:
    var score: float = 0.0
    
    # Battle phase consideration
    var battle_phase = _determine_battle_phase(context)
    
    # Match skill tags to battle phase
    match battle_phase:
        "opening":
            if skill.has_tag("setup") or skill.has_tag("buff"):
                score += 30.0
        "mid_game":
            if skill.has_tag("sustain") or skill.has_tag("control"):
                score += 20.0
        "end_game":
            if skill.has_tag("finisher") or skill.has_tag("burst"):
                score += 40.0
    
    # Health-based bonuses
    var health_percent = unit.get_health_percentage()
    if health_percent < 0.3 and skill.has_tag("desperation"):
        score += 35.0
    elif health_percent > 0.8 and skill.has_tag("aggressive"):
        score += 20.0
    
    # Status effect synergies
    var status_bonus = _calculate_status_synergy(skill, unit, context)
    score += status_bonus
    
    return score

func _evaluate_target_priority(skill: BattleSkill, unit: BattleUnit, context: Dictionary) -> float:
    var targets = skill.get_targets(unit, context.allies, context.enemies)
    if targets.is_empty():
        return 0.0
    
    var priority_score: float = 0.0
    
    for target in targets:
        var target_priority = _calculate_single_target_priority(target, skill, context)
        priority_score += target_priority
    
    # Multi-target bonus
    if targets.size() > 1:
        priority_score *= (1.0 + min(0.5, targets.size() * 0.1))
    
    return min(100.0, priority_score / max(1, targets.size()))

func _evaluate_timing_factors(skill: BattleSkill, unit: BattleUnit, context: Dictionary) -> float:
    var score: float = 50.0  # Base timing score
    
    # Cast time consideration
    if skill.cast_time > 0:
        var interruption_risk = _calculate_interruption_risk(unit, skill.cast_time, context)
        score -= interruption_risk * 20.0
        
        # But reward if unit has protection
        if unit.has_status("protected") or unit.has_status("barrier"):
            score += 15.0
    
    # Cooldown efficiency - prefer skills that will be available again soon
    if skill.cooldown > 0:
        var cooldown_score = 30.0 / (1.0 + skill.cooldown * 0.1)
        score += cooldown_score
    
    # Speed advantage
    var avg_enemy_speed = _calculate_average_enemy_speed(context)
    var speed_advantage = unit.get_projected_stat("speed") - avg_enemy_speed
    if speed_advantage > 0:
        score += min(20.0, speed_advantage * 2.0)
    
    return clamp(score, 0.0, 100.0)

func _evaluate_risk_factors(skill: BattleSkill, unit: BattleUnit, context: Dictionary) -> float:
    var risk_score: float = 100.0  # Start with no risk
    
    # Self-damage skills
    if skill.has_tag("self_damage"):
        var health_percentage = unit.get_health_percentage()
        risk_score -= (1.0 - health_percentage) * 50.0
    
    # Resource depletion
    if skill.resource_cost > 0:
        var remaining = unit.get_available_resource(skill.resource_type)
        if skill.resource_cost > remaining * 0.5:
            risk_score -= 30.0
    
    # Vulnerable during cast
    if skill.cast_time > 0 and not unit.has_status("protected"):
        risk_score -= 20.0
    
    return clamp(risk_score, 0.0, 100.0)

# Helper functions
func _apply_ai_weights(unit: BattleUnit) -> void:
    if not unit.has_meta("ai_type"):
        return
    
    var BattleAI = load("res://src/battle/battle_ai.gd")
    var ai_type = unit.get_meta("ai_type")
    match ai_type:
        BattleAI.AIType.AGGRESSIVE:
            scoring_weights["damage_efficiency"] = 1.5
            scoring_weights["risk_assessment"] = 0.5
        BattleAI.AIType.DEFENSIVE:
            scoring_weights["risk_assessment"] = 1.2
            scoring_weights["timing_bonus"] = 1.1
        BattleAI.AIType.SUPPORT:
            scoring_weights["target_priority"] = 1.3
            scoring_weights["combo_potential"] = 1.0
        BattleAI.AIType.BALANCED:
            # Keep default weights
            pass

func _calculate_target_value(target: BattleUnit, context: Dictionary) -> float:
    var value: float = 1.0
    
    # Higher value for low health enemies (finish them)
    var health_percent = target.get_health_percentage()
    if health_percent < 0.3:
        value *= 1.5
    
    # Higher value for high threat enemies
    var threat = target.get_projected_stat("attack") * health_percent
    value *= (1.0 + threat / 100.0)
    
    # Higher value for enemies with dangerous buffs
    if target.has_status("enraged") or target.has_status("blessed"):
        value *= 1.3
    
    return value

func _calculate_battle_urgency(context: Dictionary) -> float:
    var urgency: float = 0.5  # Base urgency
    
    # Check allied health
    var allies_low_health = 0
    for ally in context.allies:
        if ally.get_health_percentage() < 0.3:
            allies_low_health += 1
    
    urgency += allies_low_health * 0.2
    
    # Check enemy advantage
    var enemy_count = context.enemies.size()
    var ally_count = context.allies.size()
    if enemy_count > ally_count:
        urgency += 0.2 * (enemy_count - ally_count)
    
    return clamp(urgency, 0.0, 1.0)

func _check_skill_combo_score(skill1: BattleSkill, skill2: BattleSkill) -> float:
    # Check for known combos
    if skill1.damage_type == "fire" and skill2.damage_type == "oil":
        return 30.0
    if skill1.has_tag("setup") and skill2.has_tag("payoff"):
        return 25.0
    if skill1.has_tag("stun") and skill2.has_tag("heavy_damage"):
        return 35.0
    
    return 0.0

func _check_skill_synergy_score(skill1: BattleSkill, skill2: BattleSkill) -> float:
    # Team synergies
    if skill1.has_tag("debuff") and skill2.has_tag("exploit_debuff"):
        return 20.0
    if skill1.target_type == "all_allies" and skill2.has_tag("aoe"):
        return 15.0
    
    return 0.0

func _count_enabled_combos(skill: BattleSkill, context: Dictionary) -> int:
    var combo_count = 0
    
    # Count allies who could combo off this skill
    for ally in context.allies:
        for ally_skill in ally.skills:
            if _check_skill_synergy_score(skill, ally_skill) > 0:
                combo_count += 1
    
    return combo_count

func _determine_battle_phase(context: Dictionary) -> String:
    # Determine battle phase based on various factors
    var total_health_percent = 0.0
    var unit_count = 0
    
    for unit in context.allies + context.enemies:
        total_health_percent += unit.get_health_percentage()
        unit_count += 1
    
    var avg_health = total_health_percent / max(1, unit_count)
    
    if avg_health > 0.8:
        return "opening"
    elif avg_health > 0.4:
        return "mid_game"
    else:
        return "end_game"

func _calculate_single_target_priority(target: BattleUnit, skill: BattleSkill, context: Dictionary) -> float:
    var priority: float = 50.0  # Base priority
    
    # Priority adjustments
    if target.get_health_percentage() < 0.2 and skill.base_damage > target.stats.health:
        priority += 40.0  # Can finish them
    
    if target.has_status("channeling"):
        priority += 30.0  # Interrupt important casts
    
    if target.team != context.unit.team:  # Enemy
        var threat_level = target.get_projected_stat("attack")
        priority += threat_level * 0.5
    else:  # Ally
        if skill.target_type in ["single_ally", "all_allies"]:
            if target.get_health_percentage() < 0.3:
                priority += 35.0
    
    return priority

func _calculate_status_synergy(skill: BattleSkill, unit: BattleUnit, context: Dictionary) -> float:
    var synergy_score: float = 0.0
    
    # Check for status effect combos
    for enemy in context.enemies:
        for status in enemy.get_status_list():
            if status == "frozen" and skill.damage_type == "fire":
                synergy_score += 25.0
            elif status == "wet" and skill.damage_type == "lightning":
                synergy_score += 20.0
            elif status == "stunned" and skill.has_tag("execute"):
                synergy_score += 30.0
    
    return synergy_score

func _calculate_interruption_risk(unit: BattleUnit, cast_time: float, context: Dictionary) -> float:
    var risk: float = 0.0
    
    # Count enemies that could interrupt
    var interrupters = 0
    for enemy in context.enemies:
        if enemy.get_projected_stat("speed") > unit.get_projected_stat("speed"):
            interrupters += 1
    
    risk = interrupters * 10.0 * cast_time
    
    return min(50.0, risk)

func _calculate_average_enemy_speed(context: Dictionary) -> float:
    if context.enemies.is_empty():
        return 0.0
    
    var total_speed: float = 0.0
    for enemy in context.enemies:
        total_speed += enemy.get_projected_stat("speed")
    
    return total_speed / context.enemies.size()

# Debug helpers
var _last_score_breakdown: Dictionary = {}
var _last_total_score: float = 0.0

func _get_last_score_breakdown() -> Dictionary:
    return _last_score_breakdown.duplicate()

func _log_evaluation_results(unit: BattleUnit, evaluations: Array) -> void:
    print("\n=== Skill Evaluation for %s ===" % unit.unit_name)
    for i in range(min(3, evaluations.size())):
        var eval = evaluations[i]
        print("%d. %s (Score: %.1f)" % [i+1, eval.skill.skill_name, eval.score])
        print("   Breakdown:")
        for factor in eval.breakdown:
            print("   - %s: %.1f" % [factor, eval.breakdown[factor]])
