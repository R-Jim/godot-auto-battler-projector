extends Node

func _ready():
	print("Initializing GUT Test Runner...")
	
	# Create GUT instance
	var gut = preload("res://addons/gut/gut.gd").new()
	add_child(gut)
	
	# Configure GUT
	gut.add_directory("res://tests")
	gut.set_include_subdirs(true)
	gut.set_log_level(1)
	gut.set_should_exit(true)
	gut.set_should_exit_on_success(false)
	
	# Connect to test finished signal
	gut.end_run.connect(_on_tests_finished)
	
	# Run tests
	print("Running tests...")
	gut.test_scripts()

func _on_tests_finished():
	print("Tests completed!")
	# Let Godot handle the exit
	get_tree().quit()