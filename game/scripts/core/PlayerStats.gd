# PlayerStats.gd
# Pure data & calculation logic for ECLIPSEBOUND 8-stat RPG system.
class_name PlayerStats
extends Resource

# 8 Core Attributes
@export var vit: int = 10  # Health / Survivability
@export var str_stat: int = 10  # Physical Damage
@export var arc: int = 10  # Ability / Elemental Damage
@export var def: int = 10  # Damage Reduction
@export var agi: int = 10  # Movement & Dodge Efficiency
@export var crt: int = 10  # Critical Chance / Damage
@export var res: int = 10  # Status Resistance
@export var lck: int = 10  # Loot & Special Effect Weighting

@export var level: int = 1
@export var current_xp: float = 0.0

# Formula Constants
const BASE_XP_REQ: float = 100.0
const XP_GROWTH_FACTOR: float = 1.45

# Derived Stat Calculations
func get_max_health() -> float:
	return 100.0 + (vit * 12.5)

func get_physical_attack() -> float:
	return 15.0 + (str_stat * 2.8)

func get_ability_attack() -> float:
	return 12.0 + (arc * 3.2)

func get_defense_reduction() -> float:
	# Soft-capped defense formula: Armor / (Armor + 100)
	var armor: float = def * 4.0
	return armor / (armor + 100.0)

func get_move_speed_multiplier() -> float:
	return 1.0 + (agi * 0.015)

func get_critical_chance() -> float:
	# Returns percentage between 5% and 75%
	return clamp(0.05 + (crt * 0.008), 0.05, 0.75)

func get_critical_multiplier() -> float:
	return 1.5 + (crt * 0.02)

func get_xp_required_for_next_level() -> float:
	return BASE_XP_REQ * pow(level, XP_GROWTH_FACTOR)

func calculate_earned_xp(base_xp: float, difficulty_mult: float, performance_mult: float) -> float:
	return base_xp * difficulty_mult * clamp(performance_mult, 0.5, 3.0)

func add_xp(amount: float) -> bool:
	current_xp += amount
	var leveled_up: bool = false
	while current_xp >= get_xp_required_for_next_level() and level < 50:
		current_xp -= get_xp_required_for_next_level()
		level += 1
		leveled_up = true
	return leveled_up
