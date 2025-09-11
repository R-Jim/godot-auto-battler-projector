extends Node
# Demonstration of the two-phase skill casting system
# This script can be attached to a Node in a scene to test the functionality

func _ready() -> void:
	print("=== Two-Phase Skill Casting System Demo ===")
	demo_basic_casting()
	print("")
	demo_race_condition_prevention()
	print("")
	demo_interrupt_handling()

func demo_basic_casting() -> void:
	print("\n1. Basic Skill Casting:")
	
	# Create a unit with mana
	var unit = create_test_unit("Mage", {"mana": 100.0})
	print("  Mage starts with 100 mana")
	
	# Create a skill that costs 30 mana
	var fireball = create_test_skill("Fireball", 30.0, "mana")
	
	# Phase 1: Prepare cast and claim resources
	var cast = fireball.prepare_cast(unit)
	if cast.claim_resources():
		print("  ✓ Fireball cast prepared, 30 mana locked")
		print("    Available mana: %.0f" % unit.get_available_resource("mana"))
		print("    Locked mana: %.0f" % unit.get_locked_resource("mana"))
		print("    Total mana: %.0f" % unit.stats.mana)
		
		# Phase 2: Execute the skill
		# In real usage, this would happen after cast time or when ready
		var dummy_processor = create_dummy_rule_processor()
		cast.targets.append(create_test_unit("Dummy", {}))
		
		if cast.execute(dummy_processor):
			print("  ✓ Fireball executed successfully!")
			print("    Remaining mana: %.0f" % unit.stats.mana)
	else:
		print("  ✗ Failed to cast Fireball")

func demo_race_condition_prevention() -> void:
	print("\n2. Race Condition Prevention:")
	
	var mage = create_test_unit("Mage", {"mana": 50.0})
	print("  Mage starts with 50 mana")
	
	# Create two expensive spells
	var meteor = create_test_skill("Meteor", 35.0, "mana")
	var blizzard = create_test_skill("Blizzard", 30.0, "mana")
	
	# Try to cast both spells
	var cast1 = meteor.prepare_cast(mage)
	var cast2 = blizzard.prepare_cast(mage)
	
	if cast1.claim_resources():
		print("  ✓ Meteor cast prepared (35 mana locked)")
		print("    Available: %.0f, Locked: %.0f" % [mage.get_available_resource("mana"), mage.get_locked_resource("mana")])
	
	if not cast2.claim_resources():
		print("  ✓ Blizzard correctly prevented (not enough mana)")
		print("    Race condition avoided - cannot overspend resources")
	else:
		print("  ✗ ERROR: Blizzard should have been prevented!")

func demo_interrupt_handling() -> void:
	print("\n3. Cast Interruption and Refund:")
	
	var priest = create_test_unit("Priest", {"mana": 80.0})
	print("  Priest starts with 80 mana")
	
	var heal = create_test_skill("Greater Heal", 40.0, "mana")
	heal.cast_time = 3.0  # 3 second cast time
	
	var cast = heal.prepare_cast(priest)
	if cast.claim_resources():
		print("  ✓ Greater Heal cast started (40 mana locked)")
		print("    Cast time: %.1f seconds" % heal.cast_time)
		print("    Available mana: %.0f" % priest.get_available_resource("mana"))
		
		# Simulate interruption
		print("  ! Priest gets stunned - interrupting cast")
		cast.interrupt()
		
		print("  ✓ Cast interrupted and mana refunded")
		print("    Available mana: %.0f (back to full)" % priest.get_available_resource("mana"))
		print("    Cast cancelled: %s" % str(cast.is_cancelled))

# Helper functions
func create_test_unit(unit_name: String, resources: Dictionary) -> Node:
	var unit = Node.new()
	unit.name = unit_name
	unit.set_script(preload("res://battle_unit.gd"))
	
	# Initialize basic stats
	unit.stats = {
		"health": 100.0,
		"max_health": 100.0,
		"attack": 10.0,
		"defense": 5.0,
		"speed": 5.0
	}
	
	# Add any additional resources
	for resource in resources:
		unit.stats[resource] = resources[resource]
	
	# Initialize projectors
	for stat_name in unit.stats:
		unit.stat_projectors[stat_name] = load("res://stat_projector.gd").new()
	
	# Initialize other required properties
	unit.skills = []
	unit.status_effects = []
	unit.equipment = {}
	unit.locked_resources = {}
	
	return unit

func create_test_skill(skill_name: String, cost: float, resource: String) -> RefCounted:
	var skill = preload("res://battle_skill.gd").new()
	skill.skill_name = skill_name
	skill.base_damage = 50.0
	skill.resource_cost = cost
	skill.resource_type = resource
	skill.cooldown = 0.0
	skill.cast_time = 0.0  # Instant by default
	return skill

func create_dummy_rule_processor() -> Node:
	var processor = Node.new()
	processor.set_script(preload("res://battle_rule_processor.gd"))
	processor.skip_auto_load = true
	processor.rules = []
	return processor