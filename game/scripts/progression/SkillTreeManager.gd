# SkillTreeManager.gd
# Manages the 4 Skill Branches: WARDEN, REAVER, ARCANE, and VOID.
class_name SkillTreeManager
extends RefCounted

const SkillNode = preload("res://scripts/progression/SkillNode.gd")
const PlayerStats = preload("res://scripts/core/PlayerStats.gd")

signal skill_unlocked(branch: String, skill_id: String, new_rank: int)
signal skill_tree_reset()

const BRANCHES: Array[String] = ["WARDEN", "REAVER", "ARCANE", "VOID"]

# Storage: skill_id -> SkillNode
var skills: Dictionary = {}

func _init() -> void:
	_register_default_skills()

func _register_default_skills() -> void:
	# ================= WARDEN BRANCH =================
	_add_skill("warden_iron_skin", "Iron Skin", "WARDEN", 1, 3, 0, "", "Increases DEF by 5 per rank.", {"def": 5})
	_add_skill("warden_aegis_stance", "Aegis Stance", "WARDEN", 1, 3, 0, "", "Reduces parry and block stamina cost by 10% per rank.", {}, "aegis_stance")
	_add_skill("warden_vital_spring", "Vital Spring", "WARDEN", 1, 3, 0, "", "Increases VIT by 4 and HP regen by 10% per rank.", {"vit": 4})
	
	_add_skill("warden_deflective_bulwark", "Deflective Bulwark", "WARDEN", 2, 2, 3, "warden_aegis_stance", "Increases parry active window by 25%.", {}, "parry_window_extend")
	_add_skill("warden_stalwart_barrier", "Stalwart Barrier", "WARDEN", 2, 3, 3, "warden_iron_skin", "Grants +20 Max HP per rank.", {"vit": 3, "def": 3})
	_add_skill("warden_rooted_guard", "Rooted Guard", "WARDEN", 2, 2, 3, "", "Reduces incoming damage by 10% when stationary.", {}, "rooted_guard")
	
	_add_skill("warden_resilient_mending", "Resilient Mending", "WARDEN", 3, 2, 7, "warden_stalwart_barrier", "While below 30% HP, restores 2% max HP every second.", {}, "low_hp_regen")
	_add_skill("warden_retaliation_pulse", "Retaliation Pulse", "WARDEN", 3, 2, 7, "warden_deflective_bulwark", "Perfect parries release a shockwave dealing physical damage.", {}, "parry_shockwave")
	_add_skill("warden_stone_poise", "Stone Poise", "WARDEN", 3, 1, 7, "", "Provides full immunity to light attack stagger.", {}, "stone_poise")
	
	_add_skill("warden_living_citadel", "Living Citadel", "WARDEN", 4, 1, 12, "warden_resilient_mending", "Fatal damage grants 3s invulnerability and 25% HP restore (180s cd).", {}, "living_citadel")

	# ================= REAVER BRANCH =================
	_add_skill("reaver_honed_edge", "Honed Edge", "REAVER", 1, 3, 0, "", "Increases STR by 5 per rank.", {"str": 5})
	_add_skill("reaver_blood_rush", "Blood Rush", "REAVER", 1, 3, 0, "", "Increases attack speed by 4% per rank.", {}, "blood_rush")
	_add_skill("reaver_precision", "Precision", "REAVER", 1, 3, 0, "", "Increases CRT by 4 per rank.", {"crt": 4})
	
	_add_skill("reaver_serrated_edge", "Serrated Edge", "REAVER", 2, 2, 3, "reaver_honed_edge", "Critical hits inflict Bleed dealing damage over 4s.", {}, "bleed_on_crit")
	_add_skill("reaver_relentless_flurry", "Relentless Flurry", "REAVER", 2, 2, 3, "reaver_blood_rush", "Consecutive attacks reduce dash stamina cost by 15%.", {}, "relentless_flurry")
	_add_skill("reaver_heavy_impact", "Heavy Impact", "REAVER", 2, 3, 3, "", "Increases poise knockback and heavy attack damage by 15% per rank.", {}, "heavy_impact")
	
	_add_skill("reaver_combo_overdrive", "Combo Overdrive", "REAVER", 3, 2, 7, "reaver_serrated_edge", "Combo finisher attacks deal +40% bonus damage.", {}, "combo_finisher_boost")
	_add_skill("reaver_carnage_synergy", "Carnage Synergy", "REAVER", 3, 2, 7, "reaver_relentless_flurry", "Killing a foe boosts move and attack speed by 20% for 5s.", {}, "carnage_speed")
	_add_skill("reaver_savage_cleave", "Savage Cleave", "REAVER", 3, 3, 7, "reaver_precision", "Increases critical strike damage multiplier by +15% per rank.", {}, "savage_cleave")
	
	_add_skill("reaver_executioner_mark", "Executioner's Mark", "REAVER", 4, 1, 12, "reaver_combo_overdrive", "Enemies below 20% HP take 100% bonus damage as true damage.", {}, "executioner_mark")

	# ================= ARCANE BRANCH =================
	_add_skill("arcane_mind_focus", "Mind Focus", "ARCANE", 1, 3, 0, "", "Increases ARC by 5 per rank.", {"arc": 5})
	_add_skill("arcane_aether_flow", "Aether Flow", "ARCANE", 1, 3, 0, "", "Increases energy regeneration rate by 15% per rank.", {}, "aether_flow")
	_add_skill("arcane_elemental_potency", "Elemental Potency", "ARCANE", 1, 3, 0, "", "Increases RES by 4 and elemental status duration by 10% per rank.", {"res": 4})
	
	_add_skill("arcane_attunement", "Aether Attunement", "ARCANE", 2, 2, 3, "arcane_mind_focus", "Reduces ability energy costs by 15% per rank.", {}, "energy_cost_cut")
	_add_skill("arcane_elemental_surge", "Elemental Surge", "ARCANE", 2, 2, 3, "arcane_elemental_potency", "Abilities inflict Elemental Vulnerability (+15% damage).", {}, "elemental_surge")
	_add_skill("arcane_frost_veil", "Frost Veil", "ARCANE", 2, 2, 3, "arcane_aether_flow", "Dashing leaves an icy trail slowing pursuing enemies.", {}, "frost_veil")
	
	_add_skill("arcane_chrono_flux", "Chrono Flux", "ARCANE", 3, 2, 7, "arcane_attunement", "Reduces ability cooldowns by 20%.", {}, "chrono_flux")
	_add_skill("arcane_astral_resonation", "Astral Resonation", "ARCANE", 3, 2, 7, "arcane_elemental_surge", "When energy is >80%, attacks deal 20% bonus arcane damage.", {}, "astral_boost")
	_add_skill("arcane_spark_conduit", "Spark Conduit", "ARCANE", 3, 2, 7, "", "Shock status jumps to 2 additional nearby targets.", {}, "spark_conduit")
	
	_add_skill("arcane_supernova_burst", "Supernova Burst", "ARCANE", 4, 1, 12, "arcane_chrono_flux", "Using an ability triggers cascading shockwaves dealing 120% ARC damage.", {}, "supernova_burst")

	# ================= VOID BRANCH =================
	_add_skill("void_entropy_touch", "Entropy Touch", "VOID", 1, 3, 0, "", "Attacks apply 1 stack of Corruption to targets.", {}, "entropy_touch")
	_add_skill("void_shadow_step", "Shadow Step", "VOID", 1, 3, 0, "", "Increases AGI by 4 and dash distance by 15% per rank.", {"agi": 4})
	_add_skill("void_risk_calc", "Risk Calculation", "VOID", 1, 3, 0, "", "Increases CRT by 3 and LCK by 5 per rank.", {"crt": 3, "lck": 5})
	
	_add_skill("void_abyssal_pact", "Abyssal Pact", "VOID", 2, 2, 3, "void_entropy_touch", "While below 35% HP, all damage is increased by +35%.", {}, "abyssal_pact")
	_add_skill("void_corruptive_siphon", "Corruptive Siphon", "VOID", 2, 2, 3, "void_risk_calc", "Attacks heal for 5% damage dealt, but max HP is reduced by 10%.", {}, "corruptive_siphon")
	_add_skill("void_glitch_telegraph", "Rule Distortion", "VOID", 2, 2, 3, "void_shadow_step", "Extends dash invulnerability window (i-frames) by 0.04s per rank.", {}, "extended_iframes")
	
	_add_skill("void_phase_slip", "Phase Slip", "VOID", 3, 2, 7, "void_glitch_telegraph", "Dashing phases through enemies, staggering and afflicting Void Rend.", {}, "phase_slip")
	_add_skill("void_null_inversion", "Null Inversion", "VOID", 3, 1, 7, "void_abyssal_pact", "Cures lethal status effects and grants 4s invulnerability (120s cd).", {}, "null_inversion")
	_add_skill("void_chaos_matrix", "Chaos Matrix", "VOID", 3, 2, 7, "void_corruptive_siphon", "Critical hits have a 25% chance to spawn an Echo Slice.", {}, "chaos_matrix")
	
	_add_skill("void_eclipse_singularity", "Eclipse Singularity", "VOID", 4, 1, 12, "void_phase_slip", "Killing an enemy generates a gravity singularity pulling foes and detonating.", {}, "singularity")

func _add_skill(id: String, sname: String, branch: String, tier: int, max_rank: int, req_points: int, prereq: String, desc: String, stat_mods: Dictionary = {}, perk_id: String = "") -> void:
	var node = SkillNode.new()
	node.skill_id = id
	node.skill_name = sname
	node.branch = branch
	node.tier = tier
	node.max_rank = max_rank
	node.current_rank = 0
	node.required_branch_points = req_points
	node.prerequisite_skill_id = prereq
	node.description = desc
	node.stat_modifiers_per_rank = stat_mods
	node.special_perk_id = perk_id
	skills[id] = node

func get_invested_points_in_branch(branch_name: String) -> int:
	var total: int = 0
	for id in skills.keys():
		var node: SkillNode = skills[id]
		if node.branch.to_upper() == branch_name.to_upper():
			total += node.current_rank
	return total

func can_unlock_skill(skill_id: String) -> bool:
	if not skills.has(skill_id):
		return false
	var node: SkillNode = skills[skill_id]
	var branch_pts: int = get_invested_points_in_branch(node.branch)
	var prereq_rank: int = 1
	if node.prerequisite_skill_id != "":
		prereq_rank = get_skill_rank(node.prerequisite_skill_id)
	return node.can_unlock(branch_pts, prereq_rank)

func unlock_skill(skill_id: String, stats_ref: PlayerStats = null) -> bool:
	if not can_unlock_skill(skill_id):
		return false
	if stats_ref and stats_ref.unspent_skill_points < 1:
		return false
	
	var node: SkillNode = skills[skill_id]
	node.current_rank += 1
	if stats_ref:
		stats_ref.unspent_skill_points -= 1
	
	skill_unlocked.emit(node.branch, skill_id, node.current_rank)
	return true

func get_skill_rank(skill_id: String) -> int:
	if skills.has(skill_id):
		return skills[skill_id].current_rank
	return 0

func has_perk(perk_id: String) -> bool:
	for id in skills.keys():
		var node: SkillNode = skills[id]
		if node.special_perk_id == perk_id and node.current_rank > 0:
			return true
	return false

func get_total_stat_bonuses() -> Dictionary:
	var totals: Dictionary = {
		"vit": 0, "str": 0, "arc": 0, "def": 0,
		"agi": 0, "crt": 0, "res": 0, "lck": 0
	}
	for id in skills.keys():
		var node: SkillNode = skills[id]
		if node.current_rank > 0 and not node.stat_modifiers_per_rank.is_empty():
			for stat in node.stat_modifiers_per_rank.keys():
				var val: int = int(node.stat_modifiers_per_rank[stat] * node.current_rank)
				totals[stat] = totals.get(stat, 0) + val
	return totals

func reset_skills(stats_ref: PlayerStats = null) -> int:
	var total_refunded: int = 0
	for id in skills.keys():
		var node: SkillNode = skills[id]
		total_refunded += node.current_rank
		node.current_rank = 0
	
	if stats_ref:
		stats_ref.unspent_skill_points += total_refunded
	
	skill_tree_reset.emit()
	return total_refunded

# --- Serialization ---
func to_dict() -> Dictionary:
	var ranks: Dictionary = {}
	for id in skills.keys():
		if skills[id].current_rank > 0:
			ranks[id] = skills[id].current_rank
	return ranks

func from_dict(ranks: Dictionary) -> void:
	for id in skills.keys():
		skills[id].current_rank = ranks.get(id, 0)
