# ArtifactManager.gd
# Manages 8-piece artifact slots and evaluates multi-piece set bonuses across all 7 World sets.
class_name ArtifactManager
extends RefCounted

const ArtifactData = preload("res://scripts/artifacts/ArtifactData.gd")

signal artifacts_changed()
signal set_bonus_activated(set_id: String, piece_count: int, description: String)

const SLOTS: Array[String] = [
	"Helm", "Armour", "Gloves", "Boots",
	"Necklace", "Bracelet", "Ring", "Earpiece"
]

const SET_NAMES: Array[String] = [
	"Verdant Guardian",
	"Drowned Oath",
	"Ashen Sovereign",
	"Crimson Rite",
	"Machinist's Core",
	"Dreamwoven",
	"Nullborn"
]

# Currently equipped: slot_name -> ArtifactData
var equipped_artifacts: Dictionary = {}

func equip_artifact(artifact: ArtifactData) -> bool:
	if not artifact or not SLOTS.has(artifact.slot):
		return false
	equipped_artifacts[artifact.slot] = artifact
	artifacts_changed.emit()
	return true

func unequip_artifact(slot_name: String) -> ArtifactData:
	if equipped_artifacts.has(slot_name):
		var removed = equipped_artifacts[slot_name]
		equipped_artifacts.erase(slot_name)
		artifacts_changed.emit()
		return removed
	return null

func get_artifact_in_slot(slot_name: String) -> ArtifactData:
	return equipped_artifacts.get(slot_name, null)

func get_set_counts() -> Dictionary:
	var counts: Dictionary = {}
	for slot in equipped_artifacts.keys():
		var art: ArtifactData = equipped_artifacts[slot]
		if art and art.set_id != "":
			counts[art.set_id] = counts.get(art.set_id, 0) + 1
	return counts

func get_total_stat_bonuses() -> Dictionary:
	var totals: Dictionary = {
		"vit": 0, "str": 0, "arc": 0, "def": 0,
		"agi": 0, "crt": 0, "res": 0, "lck": 0,
		"max_hp_multiplier": 1.0,
		"attack_multiplier": 1.0,
		"defense_multiplier": 1.0,
		"crit_damage_modifier": 0.0
	}
	
	for slot in equipped_artifacts.keys():
		var a: ArtifactData = equipped_artifacts[slot]
		if a:
			totals["vit"] += a.get_total_stat("vit")
			totals["str"] += a.get_total_stat("str")
			totals["arc"] += a.get_total_stat("arc")
			totals["def"] += a.get_total_stat("def")
			totals["agi"] += a.get_total_stat("agi")
			totals["crt"] += a.get_total_stat("crt")
			totals["res"] += a.get_total_stat("res")
			totals["lck"] += a.get_total_stat("lck")
			
			# Check corrupted traits
			if a.is_corrupted and not a.corrupted_affix.is_empty():
				var boon = a.corrupted_affix.get("boon", "")
				var boon_val = float(a.corrupted_affix.get("boon_val", 0.0))
				var curse = a.corrupted_affix.get("curse", "")
				var curse_val = float(a.corrupted_affix.get("curse_val", 0.0))
				
				if boon == "crit_damage": totals["crit_damage_modifier"] += boon_val
				elif boon == "attack_boost": totals["attack_multiplier"] += boon_val
				
				if curse == "max_hp_penalty": totals["max_hp_multiplier"] += curse_val
				elif curse == "defense_penalty": totals["defense_multiplier"] += curse_val
	
	# Apply 2-piece set bonuses to stats
	var counts = get_set_counts()
	if counts.get("Verdant Guardian", 0) >= 2:
		totals["max_hp_multiplier"] += 0.15
	if counts.get("Nullborn", 0) >= 2:
		for k in ["vit", "str", "arc", "def", "agi", "crt", "res", "lck"]:
			totals[k] += 20
	if counts.get("Crimson Rite", 0) >= 2:
		totals["crit_damage_modifier"] += 0.15
	if counts.get("Ashen Sovereign", 0) >= 2:
		totals["def"] += 15
		totals["res"] += 20

	return totals

# Evaluate active bonuses for any set at 2, 4, 6, 8 pieces
func get_set_bonuses(set_name: String) -> Dictionary:
	var counts = get_set_counts()
	var count = counts.get(set_name, 0)
	return {
		"set_name": set_name,
		"count": count,
		"2_piece": count >= 2,
		"4_piece": count >= 4,
		"6_piece": count >= 6,
		"8_piece": count >= 8
	}

# Backward compatibility for existing World 1 Verdant Guardian
func get_active_verdant_bonuses() -> Dictionary:
	var b = get_set_bonuses("Verdant Guardian")
	return {
		"2_piece_max_hp_bonus": b["2_piece"],
		"4_piece_verdant_bloom": b["4_piece"],
		"6_piece_living_fortitude": b["6_piece"],
		"8_piece_wrath_of_forest": b["8_piece"],
		"active_count": b["count"]
	}

# Check if a specific high-tier set mechanic is active
func has_set_mechanic(set_name: String, threshold: int) -> bool:
	var counts = get_set_counts()
	return counts.get(set_name, 0) >= threshold

# --- Serialization ---
func to_array() -> Array:
	var list: Array = []
	for slot in equipped_artifacts.keys():
		var a: ArtifactData = equipped_artifacts[slot]
		if a:
			list.append(a.to_dict())
	return list

func from_array(list: Array) -> void:
	equipped_artifacts.clear()
	for item_dict in list:
		if typeof(item_dict) == TYPE_DICTIONARY:
			var a = ArtifactData.from_dict(item_dict)
			if SLOTS.has(a.slot):
				equipped_artifacts[a.slot] = a
	artifacts_changed.emit()
