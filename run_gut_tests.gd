extends MainLoop

var _exit_code = 0

func _initialize():
	print("\n========== Running GUT Tests ==========\n")
	
	# Load and run GUT command line
	var gut_cmdln = load("res://addons/gut/gut_cmdln.gd")
	if gut_cmdln == null:
		push_error("Failed to load GUT command line script")
		_exit_code = 1
		return
		
	var gut = gut_cmdln.new()
	
	# Set up options
	gut.set_option("dirs", ["res://tests/unit", "res://tests/integration"])
	gut.set_option("should_exit", true)
	gut.set_option("log_level", 1)
	gut.set_option("include_subdirs", true)
	gut.set_option("prefix", "test_")
	gut.set_option("suffix", ".gd")
	
	# Run the tests
	gut._run_gutconfig()
	gut._run_tests()
	
	print("\n========== Tests Complete ==========\n")

func _process(_delta):
	return false  # Return false to exit

func _finalize():
	OS.set_exit_code(_exit_code)