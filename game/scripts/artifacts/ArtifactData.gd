# ArtifactData.gd
# Data resource for the 8-piece artifact RPG equipment system.
class_name ArtifactData
extends Resource

@export var artifact_id: String = "verdant_helm"
@export var artifact_name: String = "Verdant Crown"
@export_enum("Helm", "Armour", "Gloves", "Boots", "Necklace", "Bracelet", "Ring", "Earpiece") var slot: String = "Helm"
@export_enum("Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Corrupted") var rarity: String = "Rare"
@export var set_id: String = "Verdant Guardian"

# 8 Core Primary Attribute Bonuses
@export var bonus_vit: int = 0
@export var bonus_str: int = 0
@export var bonus_arc: int = 0
@export var bonus_def: int = 0
@export var bonus_agi: int = 0
@export var bonus_crt: int = 0
@export var bonus_res: int = 0
@export var bonus_lck: int = 0

# Upgrade level (+0 to +10)
@export var upgrade_level: int = 0

# Substats list: Array of {"stat": "str", "value": 3}
@export var substats: Array[Dictionary] = []

# Corrupted traits
@export var is_corrupted: bool = false
@export var corrupted_affix: Dictionary = {}

# Inventory state
@export var is_locked: bool = false
@export var is_favorite: bool = false

@export_multiline var description: String = "Ancient relic pulsating with living forest roots."

func get_upgrade_multiplier() -> float:
	return 1.0 + (float(upgrade_level) * 0.10)

func get_total_stat(stat_name: String) -> int:
	var base_val: int = 0
	match stat_name.to_lower():
		"vit": base_val = bonus_vit
		"str": base_val = bonus_str
		"arc": base_val = bonus_arc
		"def": base_val = bonus_def
		"agi": base_val = bonus_agi
		"crt": base_val = bonus_crt
		"res": base_val = bonus_res
		"lck": base_val = bonus_lck
	
	var total: int = int(round(float(base_val) * get_upgrade_multiplier()))
	for sub in substats:
		if sub.get("stat", "").to_lower() == stat_name.to_lower():
			total += int(sub.get("value", 0))
	return total

func get_power_score() -> int:
	var score: int = 0
	for s in ["vit", "str", "arc", "def", "agi", "crt", "res", "lck"]:
		score += get_total_stat(s) * 10
	score += upgrade_level * 50
	match rarity:
		"Common": score += 20
		"Uncommon": score += 60
		"Rare": score += 120
		"Epic": score += 200
		"Legendary": score += 320
		"Mythic": score += 500
		"Corrupted": score += 450
	return score

func to_dict() -> Dictionary:
	return {
		"artifact_id": artifact_id,
		"artifact_name": artifact_name,
		"slot": slot,
		"rarity": rarity,
		"set_id": set_id,
		"bonus_vit": bonus_vit,
		"bonus_str": bonus_str,
		"bonus_arc": bonus_arc,
		"bonus_def": bonus_def,
		"bonus_agi": bonus_agi,
		"bonus_crt": bonus_crt,
		"bonus_res": bonus_res,
		"bonus_lck": bonus_lck,
		"upgrade_level": upgrade_level,
		"substats": substats.duplicate(true),
		"is_corrupted": is_corrupted,
		"corrupted_affix": corrupted_affix.duplicate(true),
		"is_locked": is_locked,
		"is_favorite": is_favorite,
		"description": description
	}

static func from_dict(data: Dictionary) -> Resource:
	var script_res = load("res://scripts/artifacts/ArtifactData.gd")
	var art = script_res.new()
	art.artifact_id = data.get("artifact_id", "artifact")
	art.artifact_name = data.get("artifact_name", "Unknown Artifact")
	art.slot = data.get("slot", "Helm")
	art.rarity = data.get("rarity", "Rare")
	art.set_id = data.get("set_id", "")
	art.bonus_vit = data.get("bonus_vit", 0)
	art.bonus_str = data.get("bonus_str", 0)
	art.bonus_arc = data.get("bonus_arc", 0)
	art.bonus_def = data.get("bonus_def", 0)
	art.bonus_agi = data.get("bonus_agi", 0)
	art.bonus_crt = data.get("bonus_crt", 0)
	art.bonus_res = data.get("bonus_res", 0)
	art.bonus_lck = data.get("bonus_lck", 0)
	art.upgrade_level = data.get("upgrade_level", 0)
	if data.has("substats"):
		art.substats = data["substats"].duplicate(true)
	art.is_corrupted = data.get("is_corrupted", false)
	if data.has("corrupted_affix"):
		art.corrupted_affix = data["corrupted_affix"].duplicate(true)
	art.is_locked = data.get("is_locked", false)
	art.is_favorite = data.get("is_favorite", false)
	art.description = data.get("description", "")
	return art
