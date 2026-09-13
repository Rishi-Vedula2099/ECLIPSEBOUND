# ArtifactManager.gd
# Manages 8-piece artifact slots and evaluates multi-piece set bonuses.
class_name ArtifactManager
extends RefCounted

const ArtifactData = preload("res://scripts/artifacts/ArtifactData.gd")

signal artifacts_changed()
signal set_bonus_activated(set_id: String, piece_count: int, description: String)

const SLOTS: Array[String] = [
	"Helm", "Armour", "Gloves", "Boots",
	"Necklace", "Bracelet", "Ring", "Earpiece"
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
		"agi": 0, "crt": 0, "res": 0, "lck": 0
	}
	for slot in equipped_artifacts.keys():
		var a: ArtifactData = equipped_artifacts[slot]
		if a:
			totals["vit"] += a.bonus_vit
			totals["str"] += a.bonus_str
			totals["arc"] += a.bonus_arc
			totals["def"] += a.bonus_def
			totals["agi"] += a.bonus_agi
			totals["crt"] += a.bonus_crt
			totals["res"] += a.bonus_res
			totals["lck"] += a.bonus_lck
	return totals

# Evaluate Verdant Guardian Set Bonuses
func get_active_verdant_bonuses() -> Dictionary:
	var counts = get_set_counts()
	var count = counts.get("Verdant Guardian", 0)
	return {
		"2_piece_max_hp_bonus": count >= 2,       # +15% Health
		"4_piece_verdant_bloom": count >= 4,      # 10% HP/Stamina restore on perfect parry
		"6_piece_living_fortitude": count >= 6,   # 20% Damage reduction near roots
		"8_piece_wrath_of_forest": count >= 8,    # 50% Bonus nature damage on critical strike
		"active_count": count
	}
