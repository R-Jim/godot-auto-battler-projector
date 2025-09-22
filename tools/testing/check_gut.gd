extends Node

func _ready():
	print("Checking GUT installation...")
	
	# Check if GutTest class can be loaded
	var test_script = load("res://addons/gut/test.gd")
	if test_script:
		print("✓ test.gd loaded successfully")
		print("  Class name: ", test_script.get_class())
	else:
		print("✗ Failed to load test.gd")
		
	# Check if we can instantiate GutTest
	if ClassDB.class_exists("GutTest"):
		print("✓ GutTest class exists in ClassDB")
	else:
		print("✗ GutTest class not found in ClassDB")
		
	# Try to load a test file
	var test_file = load("res://tests/unit/test_gut_setup.gd")
	if test_file:
		print("✓ Test file loaded successfully")
	else:
		print("✗ Failed to load test file")
		
	print("\nGUT check complete!")