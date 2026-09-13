# WeaponMasteryManager.gd
# Tracks combat actions across 7 weapon classes, leveling Weapon Mastery (1-10) and unlocking milestone perks.
class_name WeaponMasteryManager
extends RefCounted

signal weapon_mastery_leveled(weapon_class: String, new_level: int, milestone_perk: String)
signal weapon_action_recorded(weapon_class: String, action_type: String, new_total: int)

const WEAPON_CLASSES: Array[String] = [
	"Longsword", "Twin Blades", "Great Hammer",
	"Scythe", "Bow", "Arcane Staff", "Void Blade"
]

const MAX_MASTERY_LEVEL: int = 10
const XP_PER_MASTERY_LEVEL: int = 500

# Storage: weapon_class -> Dictionary
var mastery_data: Dictionary = {}

func _init() -> void:
	_init_default_data()

func _init_default_data() -> void:
	for wclass in WEAPON_CLASSES:
		mastery_data[wclass] = {
			"kills": 0,
			"boss_kills": 0,
			"parries": 0,
			"perfect_hits": 0,
			"mastery_xp": 0,
			"mastery_level": 1,
			"unlocked_milestones": []
		}

func record_kill(wclass: String, is_boss: bool = false) -> void:
	if not mastery_data.has(wclass):
		return
	var record = mastery_data[wclass]
	record["kills"] += 1
	var xp_gain = 25
	if is_boss:
		record["boss_kills"] += 1
		xp_gain = 250
	_add_mastery_xp(wclass, xp_gain)
	weapon_action_recorded.emit(wclass, "kill", record["kills"])

func record_parry(wclass: String) -> void:
	if not mastery_data.has(wclass):
		return
	var record = mastery_data[wclass]
	record["parries"] += 1
	_add_mastery_xp(wclass, 40)
	weapon_action_recorded.emit(wclass, "parry", record["parries"])

func record_perfect_hit(wclass: String) -> void:
	if not mastery_data.has(wclass):
		return
	var record = mastery_data[wclass]
	record["perfect_hits"] += 1
	_add_mastery_xp(wclass, 15)
	weapon_action_recorded.emit(wclass, "perfect_hit", record["perfect_hits"])

func _add_mastery_xp(wclass: String, amount: int) -> void:
	var record = mastery_data[wclass]
	if record["mastery_level"] >= MAX_MASTERY_LEVEL:
		return
	record["mastery_xp"] += amount
	var expected_level = mini(MAX_MASTERY_LEVEL, 1 + int(floor(record["mastery_xp"] / float(XP_PER_MASTERY_LEVEL))))
	if expected_level > record["mastery_level"]:
		var old_level = record["mastery_level"]
		record["mastery_level"] = expected_level
		for lvl in range(old_level + 1, expected_level + 1):
			_check_milestone_unlock(wclass, lvl)

func _check_milestone_unlock(wclass: String, level: int) -> void:
	var record = mastery_data[wclass]
	var milestone_desc = ""
	match level:
		3: milestone_desc = "Mastery III: Signature Technique"
		5: milestone_desc = "Mastery V: Resonant Scaling (+15% attribute scaling)"
		7: milestone_desc = "Mastery VII: Kinetic Flow"
		10: milestone_desc = "Mastery X: Transcendence Finisher"
	
	if milestone_desc != "" and not record["unlocked_milestones"].has(level):
		record["unlocked_milestones"].append(level)
		weapon_mastery_leveled.emit(wclass, level, milestone_desc)

func get_mastery_level(wclass: String) -> int:
	if mastery_data.has(wclass):
		return mastery_data[wclass]["mastery_level"]
	return 1

func get_mastery_record(wclass: String) -> Dictionary:
	if mastery_data.has(wclass):
		return mastery_data[wclass]
	return {}

func has_milestone(wclass: String, milestone_level: int) -> bool:
	if mastery_data.has(wclass):
		return mastery_data[wclass]["unlocked_milestones"].has(milestone_level)
	return false

# --- Serialization ---
func to_dict() -> Dictionary:
	return mastery_data.duplicate(true)

func from_dict(data: Dictionary) -> void:
	for wclass in data.keys():
		if mastery_data.has(wclass):
			mastery_data[wclass] = data[wclass]
