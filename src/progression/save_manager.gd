class_name SaveManager
extends RefCounted

const SAVE_DIR = "user://saves/"
const SAVE_FILE = "autosave.sav"
const BACKUP_FILE = "autosave.bak"

static func save_game(player_data: PlayerData, slot: int = 0) -> bool:
	var save_path = SAVE_DIR + "save_slot_%d.sav" % slot
	if slot == 0:
		save_path = SAVE_DIR + SAVE_FILE
	
	var dir = DirAccess.open("user://")
	if not dir.dir_exists(SAVE_DIR):
		dir.make_dir_recursive(SAVE_DIR)
	
	if FileAccess.file_exists(save_path):
		var backup_path = save_path.replace(".sav", ".bak")
		dir.copy(save_path, backup_path)
	
	var save_file = FileAccess.open(save_path, FileAccess.WRITE)
	if save_file == null:
		push_error("Failed to open save file: " + save_path)
		return false
	
	var save_data = {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"player_data": player_data.to_save_dict()
	}
	
	save_file.store_var(save_data)
	save_file.close()
	
	return true

static func load_game(slot: int = 0) -> PlayerData:
	var save_path = SAVE_DIR + "save_slot_%d.sav" % slot
	if slot == 0:
		save_path = SAVE_DIR + SAVE_FILE
	
	if not FileAccess.file_exists(save_path):
		return null
	
	var save_file = FileAccess.open(save_path, FileAccess.READ)
	if save_file == null:
		push_error("Failed to open save file: " + save_path)
		return null
	
	var save_data = save_file.get_var()
	save_file.close()
	
	if not save_data is Dictionary:
		push_error("Invalid save file format")
		return null
	
	var version = save_data.get("version", 0)
	if version != 1:
		push_error("Unsupported save file version: " + str(version))
		return null
	
	var player_dict = save_data.get("player_data", {})
	if player_dict.is_empty():
		push_error("No player data in save file")
		return null
	
	return PlayerData.from_save_dict(player_dict)

static func delete_save(slot: int = 0) -> bool:
	var save_path = SAVE_DIR + "save_slot_%d.sav" % slot
	if slot == 0:
		save_path = SAVE_DIR + SAVE_FILE
	
	if FileAccess.file_exists(save_path):
		var dir = DirAccess.open(SAVE_DIR)
		if dir != null:
			dir.remove(save_path)
			var backup_path = save_path.replace(".sav", ".bak")
			if FileAccess.file_exists(backup_path):
				dir.remove(backup_path)
			return true
	
	return false

static func list_saves() -> Array[Dictionary]:
	var saves = []
	
	var dir = DirAccess.open(SAVE_DIR)
	if dir == null:
		return saves
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".sav") and not file_name.ends_with(".bak"):
			var save_info = get_save_info(SAVE_DIR + file_name)
			if save_info != null:
				saves.append(save_info)
		file_name = dir.get_next()
	
	return saves

static func get_save_info(save_path: String) -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	
	var save_file = FileAccess.open(save_path, FileAccess.READ)
	if save_file == null:
		return {}
	
	var save_data = save_file.get_var()
	save_file.close()
	
	if not save_data is Dictionary:
		return {}
	
	var player_dict = save_data.get("player_data", {})
	
	return {
		"path": save_path,
		"timestamp": save_data.get("timestamp", 0),
		"player_level": player_dict.get("player_level", 1),
		"gold": player_dict.get("gold", 0),
		"completed_encounters": player_dict.get("completed_encounters", []).size()
	}

static func has_save(slot: int = 0) -> bool:
	var save_path = SAVE_DIR + "save_slot_%d.sav" % slot
	if slot == 0:
		save_path = SAVE_DIR + SAVE_FILE
	
	return FileAccess.file_exists(save_path)

static func restore_from_backup(slot: int = 0) -> bool:
	var save_path = SAVE_DIR + "save_slot_%d.sav" % slot
	var backup_path = SAVE_DIR + "save_slot_%d.bak" % slot
	
	if slot == 0:
		save_path = SAVE_DIR + SAVE_FILE
		backup_path = SAVE_DIR + BACKUP_FILE
	
	if FileAccess.file_exists(backup_path):
		var dir = DirAccess.open(SAVE_DIR)
		if dir != null:
			dir.copy(backup_path, save_path)
			return true
	
	return false