# ProgressionManager.gd
# Manages Character Level (1-50), World Level (1-7), and Boss Mastery (0-10).
class_name ProgressionManager
extends RefCounted

signal character_level_changed(new_level: int)
signal world_level_changed(new_world_level: int)
signal boss_mastery_updated(boss_id: String, new_mastery: int, rank_title: String)

const MIN_WORLD_LEVEL: int = 1
const MAX_WORLD_LEVEL: int = 7
const MAX_BOSS_MASTERY: int = 10

var world_level: int = 1

# Boss Mastery Records: boss_id -> Dictionary {
#   "kills": int,
#   "no_damage_kills": int,
#   "mastery_level": int (0-10),
#   "mastery_points": int,
#   "unlocked_perks": Array[String]
# }
var boss_mastery_records: Dictionary = {
	"hollow_stag": {
		"kills": 0, "no_damage_kills": 0, "mastery_level": 0, "mastery_points": 0, "unlocked_perks": []
	},
	"drowned_knight": {
		"kills": 0, "no_damage_kills": 0, "mastery_level": 0, "mastery_points": 0, "unlocked_perks": []
	},
	"drowned_matriarch": {
		"kills": 0, "no_damage_kills": 0, "mastery_level": 0, "mastery_points": 0, "unlocked_perks": []
	},
	"ash_king": {
		"kills": 0, "no_damage_kills": 0, "mastery_level": 0, "mastery_points": 0, "unlocked_perks": []
	},
	"cardinal_of_blood": {
		"kills": 0, "no_damage_kills": 0, "mastery_level": 0, "mastery_points": 0, "unlocked_perks": []
	},
	"the_architect": {
		"kills": 0, "no_damage_kills": 0, "mastery_level": 0, "mastery_points": 0, "unlocked_perks": []
	},
	"the_dream_eater": {
		"kills": 0, "no_damage_kills": 0, "mastery_level": 0, "mastery_points": 0, "unlocked_perks": []
	},
	"null": {
		"kills": 0, "no_damage_kills": 0, "mastery_level": 0, "mastery_points": 0, "unlocked_perks": []
	}
}

# --- World Level Scaling ---
func set_world_level(level: int) -> bool:
	if level < MIN_WORLD_LEVEL or level > MAX_WORLD_LEVEL:
		return false
	world_level = level
	world_level_changed.emit(world_level)
	return true

func get_enemy_hp_multiplier() -> float:
	return 1.0 + (float(world_level - 1) * 0.40)

func get_enemy_damage_multiplier() -> float:
	return 1.0 + (float(world_level - 1) * 0.35)

func get_world_xp_multiplier() -> float:
	return 1.0 + (float(world_level - 1) * 0.50)

func get_world_loot_rarity_multiplier() -> float:
	return 1.0 + (float(world_level - 1) * 0.30)

# --- Boss Mastery Tracking ---
func record_boss_defeat(boss_id: String, took_damage: bool = true, fight_duration: float = 60.0) -> Dictionary:
	var id: String = boss_id.to_lower()
	if not boss_mastery_records.has(id):
		boss_mastery_records[id] = {
			"kills": 0, "no_damage_kills": 0, "mastery_level": 0, "mastery_points": 0, "unlocked_perks": []
		}
	
	var record: Dictionary = boss_mastery_records[id]
	record["kills"] += 1
	
	var points_earned: int = 100 * world_level
	if not took_damage:
		record["no_damage_kills"] += 1
		points_earned += 150 * world_level
	
	if fight_duration < 90.0:
		points_earned += 50
		
	record["mastery_points"] += points_earned
	
	# Evaluate mastery level: 250 pts per level
	var old_level: int = record["mastery_level"]
	var new_level: int = mini(MAX_BOSS_MASTERY, int(floor(record["mastery_points"] / 250.0)))
	
	if new_level > old_level:
		record["mastery_level"] = new_level
		_unlock_mastery_perks(id, new_level)
		boss_mastery_updated.emit(id, new_level, get_mastery_rank_title(new_level))
	
	return {
		"boss_id": id,
		"points_earned": points_earned,
		"current_points": record["mastery_points"],
		"mastery_level": record["mastery_level"],
		"leveled_up": new_level > old_level
	}

func get_boss_mastery_level(boss_id: String) -> int:
	var id: String = boss_id.to_lower()
	if boss_mastery_records.has(id):
		return boss_mastery_records[id]["mastery_level"]
	return 0

func get_mastery_rank_title(level: int) -> String:
	match level:
		0: return "Uninitiated"
		1, 2: return "Observer"
		3, 4: return "Challenger"
		5, 6: return "Subjugator"
		7, 8: return "Dominator"
		9: return "Eclipse Conqueror"
		10: return "Null Transcendent"
		_: return "Master"

func _unlock_mastery_perks(boss_id: String, level: int) -> void:
	var record: Dictionary = boss_mastery_records[boss_id]
	var perk_name: String = ""
	match level:
		3: perk_name = "%s_essence_resonance" % boss_id
		5: perk_name = "%s_counter_sight" % boss_id
		7: perk_name = "%s_relic_infusion" % boss_id
		10: perk_name = "%s_master_conqueror" % boss_id
	if perk_name != "" and not record["unlocked_perks"].has(perk_name):
		record["unlocked_perks"].append(perk_name)

# --- Serialization ---
func to_dict() -> Dictionary:
	return {
		"world_level": world_level,
		"boss_mastery_records": boss_mastery_records.duplicate(true)
	}

func from_dict(data: Dictionary) -> void:
	world_level = data.get("world_level", 1)
	if data.has("boss_mastery_records"):
		for k in data["boss_mastery_records"]:
			boss_mastery_records[k] = data["boss_mastery_records"][k]
