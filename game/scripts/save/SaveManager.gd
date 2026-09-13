# SaveManager.gd
# Versioned JSON save and load system with SHA-256 integrity verification.
extends Node

signal game_saved(slot: int, success: bool)
signal game_loaded(slot: int, data: Dictionary)
signal save_corrupted(slot: int, error_msg: String)

const CURRENT_SAVE_VERSION: String = "1.0.0"
const SAVE_PATH_TEMPLATE: String = "user://save_slot_%d.json"
const BACKUP_PATH_TEMPLATE: String = "user://save_slot_%d.bak"

var active_slot: int = 1
var active_checkpoint_id: String = "shrine_start"
var active_checkpoint_position: Vector2 = Vector2(100.0, 200.0)

func get_save_path(slot: int) -> String:
	return SAVE_PATH_TEMPLATE % slot

func get_backup_path(slot: int) -> String:
	return BACKUP_PATH_TEMPLATE % slot

func has_save(slot: int = 1) -> bool:
	return FileAccess.file_exists(get_save_path(slot))

func save_game(slot: int = 1, player_node: Node2D = null, custom_world_data: Dictionary = {}) -> bool:
	var path: String = get_save_path(slot)
	var backup_path: String = get_backup_path(slot)
	
	# If an existing file exists, create a backup
	if FileAccess.file_exists(path):
		var existing_content: String = FileAccess.get_file_as_string(path)
		var b_file = FileAccess.open(backup_path, FileAccess.WRITE)
		if b_file:
			b_file.store_string(existing_content)
			b_file.close()
	
	var player_dict: Dictionary = _extract_player_data(player_node)
	var world_dict: Dictionary = {
		"world_id": custom_world_data.get("world_id", 1),
		"world_level": custom_world_data.get("world_level", 1),
		"checkpoint_id": active_checkpoint_id,
		"checkpoint_position": {
			"x": active_checkpoint_position.x,
			"y": active_checkpoint_position.y
		},
		"unlocked_flags": custom_world_data.get("unlocked_flags", ["starter_shrine_unlocked"]),
		"bosses_defeated": custom_world_data.get("bosses_defeated", []),
		"boss_mastery": custom_world_data.get("boss_mastery", {})
	}
	
	var root_dict: Dictionary = {
		"version": CURRENT_SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"player": player_dict,
		"world": world_dict
	}
	
	# Compute checksum over stringified content
	var payload_json: String = JSON.stringify(root_dict, "\t")
	var checksum: String = payload_json.sha256_text()
	root_dict["checksum"] = checksum
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Failed to open save file for write at " + path)
		game_saved.emit(slot, false)
		return false
	
	file.store_string(JSON.stringify(root_dict, "\t"))
	file.close()
	
	game_saved.emit(slot, true)
	return true

func load_game(slot: int = 1) -> Dictionary:
	var path: String = get_save_path(slot)
	if not FileAccess.file_exists(path):
		# Attempt fallback to backup
		path = get_backup_path(slot)
		if not FileAccess.file_exists(path):
			return {}
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("SaveManager: Failed to read save file at " + path)
		return {}
	
	var content: String = file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		save_corrupted.emit(slot, "Invalid JSON structure")
		return {}
	
	var data: Dictionary = parsed
	if not data.has("version") or not data.has("player") or not data.has("world"):
		save_corrupted.emit(slot, "Missing required top-level save fields")
		return {}
	
	# Verify checksum
	var saved_checksum: String = data.get("checksum", "")
	var verify_dict: Dictionary = data.duplicate(true)
	verify_dict.erase("checksum")
	var calculated_checksum: String = JSON.stringify(verify_dict, "\t").sha256_text()
	
	if saved_checksum != "" and saved_checksum != calculated_checksum:
		push_warning("SaveManager: Checksum mismatch. Save file may be corrupted or modified.")
		# Check if backup exists and is valid
		var backup_data: Dictionary = _load_backup(slot)
		if not backup_data.is_empty():
			data = backup_data
	
	# Update active checkpoint
	if data["world"].has("checkpoint_id"):
		active_checkpoint_id = data["world"]["checkpoint_id"]
	if data["world"].has("checkpoint_position"):
		var cp = data["world"]["checkpoint_position"]
		active_checkpoint_position = Vector2(cp.get("x", 100.0), cp.get("y", 200.0))
	
	game_loaded.emit(slot, data)
	return data

func _load_backup(slot: int) -> Dictionary:
	var b_path: String = get_backup_path(slot)
	if not FileAccess.file_exists(b_path):
		return {}
	var b_file = FileAccess.open(b_path, FileAccess.READ)
	if not b_file:
		return {}
	var b_content: String = b_file.get_as_text()
	b_file.close()
	var b_parsed = JSON.parse_string(b_content)
	return b_parsed if typeof(b_parsed) == TYPE_DICTIONARY else {}

func _extract_player_data(player_node: Node2D) -> Dictionary:
	if not player_node:
		return get_default_player_data()
	
	if player_node.has_method("get_save_state"):
		return player_node.get_save_state()
	
	var pos: Vector2 = player_node.global_position
	var level: int = 1
	var xp: float = 0.0
	var hp: float = 225.0
	var max_hp: float = 225.0
	var stamina: float = 100.0
	var energy: float = 100.0
	var stats: Dictionary = {
		"vit": 10, "str": 10, "arc": 10, "def": 10,
		"agi": 10, "crt": 10, "res": 10, "lck": 10
	}
	
	return {
		"level": level,
		"xp": xp,
		"current_hp": hp,
		"max_hp": max_hp,
		"stamina": stamina,
		"energy": energy,
		"position": {"x": pos.x, "y": pos.y},
		"stats": stats,
		"equipped_weapon": "stag_horn_blade",
		"artifacts": [],
		"skills": {},
		"weapon_mastery": {},
		"inventory": {"items": [], "materials": {}}
	}

func get_default_player_data() -> Dictionary:
	return {
		"level": 1,
		"xp": 0.0,
		"current_hp": 225.0,
		"max_hp": 225.0,
		"stamina": 100.0,
		"energy": 100.0,
		"position": {"x": 100.0, "y": 200.0},
		"stats": {
			"vit": 10, "str": 10, "arc": 10, "def": 10,
			"agi": 10, "crt": 10, "res": 10, "lck": 10
		},
		"equipped_weapon": "stag_horn_blade",
		"artifacts": [],
		"skills": {},
		"weapon_mastery": {},
		"inventory": {"items": [], "materials": {}}
	}
