# PlayerStats.gd
# Pure data & calculation logic for ECLIPSEBOUND 8-stat RPG system.
class_name PlayerStats
extends Resource

signal stats_changed()
signal level_up(new_level: int, unspent_stat_points: int, unspent_skill_points: int)

# 8 Core Attributes (Base values)
@export var vit: int = 10  # Health / Survivability
@export var str_stat: int = 10  # Physical Damage
@export var arc: int = 10  # Ability / Elemental Damage
@export var def: int = 10  # Damage Reduction
@export var agi: int = 10  # Movement & Dodge Efficiency
@export var crt: int = 10  # Critical Chance / Damage
@export var res: int = 10  # Status Resistance
@export var lck: int = 10  # Loot & Special Effect Weighting

# Leveling & Progression
@export var level: int = 1
@export var current_xp: float = 0.0
@export var unspent_stat_points: int = 0
@export var unspent_skill_points: int = 0

# Bonus offsets (from equipment, temporary buffs, artifacts)
var bonus_vit: int = 0
var bonus_str: int = 0
var bonus_arc: int = 0
var bonus_def: int = 0
var bonus_agi: int = 0
var bonus_crt: int = 0
var bonus_res: int = 0
var bonus_lck: int = 0

# Percentage modifiers
var attack_multiplier: float = 1.0
var defense_multiplier: float = 1.0
var max_hp_multiplier: float = 1.0
var crit_damage_modifier: float = 0.0

# Formula Constants
const MAX_LEVEL: int = 50
const BASE_XP_REQ: float = 100.0
const XP_GROWTH_FACTOR: float = 1.45
const STAT_POINTS_PER_LEVEL: int = 3
const SKILL_POINTS_PER_LEVEL: int = 1

# --- Effective Core Attribute Getters ---
func get_effective_vit() -> int:
	return maxi(1, vit + bonus_vit)

func get_effective_str() -> int:
	return maxi(1, str_stat + bonus_str)

func get_effective_arc() -> int:
	return maxi(1, arc + bonus_arc)

func get_effective_def() -> int:
	return maxi(1, def + bonus_def)

func get_effective_agi() -> int:
	return maxi(1, agi + bonus_agi)

func get_effective_crt() -> int:
	return maxi(1, crt + bonus_crt)

func get_effective_res() -> int:
	return maxi(1, res + bonus_res)

func get_effective_lck() -> int:
	return maxi(1, lck + bonus_lck)

# --- Derived Stat Calculations ---
func get_max_health() -> float:
	var base_hp: float = 100.0 + (get_effective_vit() * 12.5)
	return base_hp * max_hp_multiplier

func get_health_regen_rate() -> float:
	return 1.0 + (get_effective_vit() * 0.15)

func get_physical_attack() -> float:
	var base_atk: float = 15.0 + (get_effective_str() * 2.8)
	return base_atk * attack_multiplier

func get_ability_attack() -> float:
	var base_arc: float = 12.0 + (get_effective_arc() * 3.2)
	return base_arc * attack_multiplier

func get_defense_reduction() -> float:
	# Soft-capped defense formula: Armor / (Armor + 100)
	var armor: float = get_effective_def() * 4.0 * defense_multiplier
	return armor / (armor + 100.0)

func get_move_speed_multiplier() -> float:
	return 1.0 + (get_effective_agi() * 0.015)

func get_dash_stamina_cost_multiplier() -> float:
	# AGI reduces dash stamina cost up to 40% reduction
	var reduction: float = clampf(get_effective_agi() * 0.006, 0.0, 0.40)
	return 1.0 - reduction

func get_critical_chance() -> float:
	# Returns percentage between 5% and 75%
	return clampf(0.05 + (get_effective_crt() * 0.008), 0.05, 0.75)

func get_critical_multiplier() -> float:
	# Base 1.5x + 2% per CRT point + extra modifiers
	return 1.5 + (get_effective_crt() * 0.02) + crit_damage_modifier

func get_status_resistance() -> float:
	# Resistance factor: reduces status duration & buildup (up to 70%)
	return clampf((get_effective_res() * 0.012), 0.0, 0.70)

func get_loot_luck_multiplier() -> float:
	# 1.0 at 10 LCK, scales upwards to boost rare/corrupted drops
	return 1.0 + ((get_effective_lck() - 10) * 0.025)

# --- Progression & XP Methods ---
func get_xp_required_for_next_level() -> float:
	return BASE_XP_REQ * pow(level, XP_GROWTH_FACTOR)

func calculate_earned_xp(base_xp: float, difficulty_mult: float, performance_mult: float) -> float:
	return base_xp * difficulty_mult * clampf(performance_mult, 0.5, 3.0)

func add_xp(amount: float) -> bool:
	current_xp += amount
	var leveled_up: bool = false
	while current_xp >= get_xp_required_for_next_level() and level < MAX_LEVEL:
		current_xp -= get_xp_required_for_next_level()
		level += 1
		unspent_stat_points += STAT_POINTS_PER_LEVEL
		unspent_skill_points += SKILL_POINTS_PER_LEVEL
		leveled_up = true
		level_up.emit(level, unspent_stat_points, unspent_skill_points)
	
	if leveled_up:
		stats_changed.emit()
	return leveled_up

func allocate_stat(stat_name: String, points: int = 1) -> bool:
	if unspent_stat_points < points or points <= 0:
		return false
	
	match stat_name.to_lower():
		"vit": vit += points
		"str", "str_stat": str_stat += points
		"arc": arc += points
		"def": def += points
		"agi": agi += points
		"crt": crt += points
		"res": res += points
		"lck": lck += points
		_: return false
	
	unspent_stat_points -= points
	stats_changed.emit()
	return true

func set_equipment_bonuses(bonuses: Dictionary) -> void:
	bonus_vit = bonuses.get("vit", 0)
	bonus_str = bonuses.get("str", 0)
	bonus_arc = bonuses.get("arc", 0)
	bonus_def = bonuses.get("def", 0)
	bonus_agi = bonuses.get("agi", 0)
	bonus_crt = bonuses.get("crt", 0)
	bonus_res = bonuses.get("res", 0)
	bonus_lck = bonuses.get("lck", 0)
	
	max_hp_multiplier = bonuses.get("max_hp_multiplier", 1.0)
	attack_multiplier = bonuses.get("attack_multiplier", 1.0)
	defense_multiplier = bonuses.get("defense_multiplier", 1.0)
	crit_damage_modifier = bonuses.get("crit_damage_modifier", 0.0)
	stats_changed.emit()

func respec_stats() -> void:
	var total_allocated: int = (vit - 10) + (str_stat - 10) + (arc - 10) + (def - 10) + \
		(agi - 10) + (crt - 10) + (res - 10) + (lck - 10)
	unspent_stat_points += maxi(0, total_allocated)
	vit = 10
	str_stat = 10
	arc = 10
	def = 10
	agi = 10
	crt = 10
	res = 10
	lck = 10
	stats_changed.emit()

func to_dict() -> Dictionary:
	return {
		"level": level,
		"current_xp": current_xp,
		"unspent_stat_points": unspent_stat_points,
		"unspent_skill_points": unspent_skill_points,
		"vit": vit,
		"str": str_stat,
		"arc": arc,
		"def": def,
		"agi": agi,
		"crt": crt,
		"res": res,
		"lck": lck
	}

func from_dict(data: Dictionary) -> void:
	level = data.get("level", 1)
	current_xp = data.get("current_xp", 0.0)
	unspent_stat_points = data.get("unspent_stat_points", 0)
	unspent_skill_points = data.get("unspent_skill_points", 0)
	vit = data.get("vit", 10)
	str_stat = data.get("str", 10)
	arc = data.get("arc", 10)
	def = data.get("def", 10)
	agi = data.get("agi", 10)
	crt = data.get("crt", 10)
	res = data.get("res", 10)
	lck = data.get("lck", 10)
	stats_changed.emit()
