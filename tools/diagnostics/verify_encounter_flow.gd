extends Node

# Quick test to verify encounter flow
func _ready() -> void:
	print("=== Testing Encounter Flow ===")
	
	# Load templates
	UnitFactory.load_templates()
	
	# Create test units
	var team1_unit = UnitFactory.create_from_template("player_warrior", 1, 1)
	var team2_unit = UnitFactory.create_from_template("goblin", 1, 2)
	
	if team1_unit and team2_unit:
		print("✓ Units created successfully")
		print("  Team1: %s (HP: %d)" % [team1_unit.unit_name, team1_unit.stats.health])
		print("  Team2: %s (HP: %d)" % [team2_unit.unit_name, team2_unit.stats.health])
	else:
		print("✗ Failed to create units")
		
	# Test battle setup
	var auto_battler = AutoBattler.new()
	add_child(auto_battler)
	
	# Create teams
	var team1: Array[BattleUnit] = [team1_unit]
	var team2: Array[BattleUnit] = [team2_unit]
	
	# Connect to battle signals
	auto_battler.battle_started.connect(func(): print("✓ Battle started"))
	auto_battler.round_started.connect(func(r): print("  Round %d started" % r))
	auto_battler.turn_started.connect(func(u): print("    %s's turn" % u.unit_name))
	auto_battler.battle_ended.connect(func(w): print("✓ Battle ended - Team %d wins!" % w))
	
	# Start battle
	print("\nStarting test battle...")
	auto_battler.start_battle(team1, team2)
	
	# Wait a bit then exit
	await get_tree().create_timer(5.0).timeout
	print("\n=== Test Complete ===")
	get_tree().quit()