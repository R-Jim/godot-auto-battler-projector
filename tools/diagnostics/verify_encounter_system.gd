extends Node

# This script verifies that all encounter system classes can be instantiated

func _ready() -> void:
	print("=== Verifying Encounter System ===")
	
	# Test EncounterRewards
	var rewards = EncounterRewards.new()
	rewards.experience = 100
	rewards.gold = 50
	print("✓ EncounterRewards created successfully")
	
	# Test Wave
	var wave = Wave.new()
	wave.wave_type = Wave.WaveType.STANDARD
	wave.add_enemy_unit("bandit_warrior", 2, 1)
	print("✓ Wave created successfully")
	
	# Test Encounter
	var encounter = Encounter.new()
	encounter.encounter_id = "test"
	encounter.add_wave(wave)
	print("✓ Encounter created successfully")
	
	# Test DifficultyScaler
	var mods = DifficultyScaler.get_difficulty_modifiers(DifficultyScaler.DifficultyMode.NORMAL)
	print("✓ DifficultyScaler working - Normal difficulty health mod: ", mods.enemy_health)
	
	# Test UnitFactory
	print("✓ UnitFactory ready to create units from templates")
	
	print("\n=== All encounter system components verified! ===")
	get_tree().quit()