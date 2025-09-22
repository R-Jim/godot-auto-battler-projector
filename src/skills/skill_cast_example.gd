extends Node
# Example of using the two-phase skill casting system

class_name SkillCastExample

var pending_casts: Array[SkillCast] = []
var rule_processor

func _ready() -> void:
	rule_processor = get_node("/root/RuleProcessor")

func try_cast_skill(caster: BattleUnit, skill: BattleSkill, targets: Array[BattleUnit]) -> String:
	# Phase 1: Prepare and claim resources
	var cast = skill.prepare_cast(caster)
	for target in targets:
		cast.targets.append(target)
	
	if not cast.claim_resources():
		var reason = skill.get_unusable_reason(caster)
		return "Cannot cast %s: %s" % [skill.skill_name, reason]
	
	# Add to pending casts
	pending_casts.append(cast)
	
	# Connect signals
	cast.cast_completed.connect(_on_cast_completed.bind(cast))
	cast.cast_cancelled.connect(_on_cast_cancelled.bind(cast))
	
	# If skill has cast time, wait for it
	if skill.cast_time > 0:
		create_tween().tween_callback(_check_cast_ready.bind(cast)).set_delay(skill.cast_time)
		return "Casting %s... (%.1f seconds)" % [skill.skill_name, skill.cast_time]
	else:
		# Instant cast
		_execute_cast(cast)
		return "%s cast successfully!" % skill.skill_name

func _check_cast_ready(cast: SkillCast) -> void:
	if cast.is_ready() and cast in pending_casts:
		_execute_cast(cast)

func _execute_cast(cast: SkillCast) -> void:
	# Phase 2: Execute the skill
	if cast.execute(rule_processor):
		print("%s executed successfully on %d targets" % [cast.skill.skill_name, cast.targets.size()])
	else:
		print("Failed to execute %s" % cast.skill.skill_name)
	
	pending_casts.erase(cast)

func interrupt_cast(cast: SkillCast) -> void:
	if cast in pending_casts:
		cast.interrupt()
		pending_casts.erase(cast)
		print("%s was interrupted!" % cast.skill.skill_name)

func interrupt_all_casts_for_unit(unit: BattleUnit) -> void:
	for cast in pending_casts:
		if cast.caster == unit:
			interrupt_cast(cast)

func _on_cast_completed(cast: SkillCast) -> void:
	print("%s completed!" % cast.skill.skill_name)

func _on_cast_cancelled(cast: SkillCast) -> void:
	print("%s was cancelled!" % cast.skill.skill_name)

# Example: Handle unit death
func _on_unit_died(unit: BattleUnit) -> void:
	# Cancel all pending casts for dead unit
	interrupt_all_casts_for_unit(unit)
	
	# Remove dead unit from any pending cast targets
	for cast in pending_casts:
		cast.targets.erase(unit)

# Example: Try to cast multiple skills at once
func demonstrate_race_condition_prevention() -> void:
	var mage = preload("res://src/battle/battle_unit.gd").new()
	mage.stats = {"mana": 50.0}
	mage.stat_projectors["mana"] = StatProjector.new()
	
	var fireball = BattleSkill.new()
	fireball.skill_name = "Fireball"
	fireball.resource_cost = 30.0
	fireball.resource_type = "mana"
	
	var frostbolt = BattleSkill.new()
	frostbolt.skill_name = "Frostbolt"
	frostbolt.resource_cost = 25.0
	frostbolt.resource_type = "mana"
	
	var dummy_targets = []
	
	# Try to cast both spells
	print("Mage has 50 mana")
	print(try_cast_skill(mage, fireball, dummy_targets))  # Should succeed
	print(try_cast_skill(mage, frostbolt, dummy_targets))  # Should fail
	
	# Output:
	# Mage has 50 mana
	# Fireball cast successfully!
	# Cannot cast Frostbolt: insufficient mana (20.0/25.0 available, 30.0 locked)
