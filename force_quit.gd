extends SceneTree

func _init() -> void:
	# Force quit after a small delay to ensure other scripts run
	create_timer(0.1).timeout.connect(func(): quit(0))