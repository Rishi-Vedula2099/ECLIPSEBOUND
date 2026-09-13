# SkillNode.gd
# Data resource representing an individual skill or passive perk in the 4 branches.
class_name SkillNode
extends Resource

@export var skill_id: String = "warden_aegis"
@export var skill_name: String = "Aegis Stance"
@export_enum("WARDEN", "REAVER", "ARCANE", "VOID") var branch: String = "WARDEN"
@export var tier: int = 1  # Tier 1 to 4
@export var max_rank: int = 3
@export var current_rank: int = 0
@export var required_branch_points: int = 0
@export var prerequisite_skill_id: String = ""
@export_multiline var description: String = "Reduces stamina consumed while blocking or parrying by 10% per rank."

# Stat modifiers granted per rank: stat_name -> float value
@export var stat_modifiers_per_rank: Dictionary = {}

# Special mechanics flag (e.g. "cheat_death", "bleed_on_crit", "void_slip")
@export var special_perk_id: String = ""

func is_unlocked() -> bool:
	return current_rank > 0

func is_maxed() -> bool:
	return current_rank >= max_rank

func can_unlock(branch_total_invested: int, prerequisite_rank: int) -> bool:
	if current_rank >= max_rank:
		return false
	if branch_total_invested < required_branch_points:
		return false
	if prerequisite_skill_id != "" and prerequisite_rank <= 0:
		return false
	return true
