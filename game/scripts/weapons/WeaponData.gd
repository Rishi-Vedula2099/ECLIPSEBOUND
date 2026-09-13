# WeaponData.gd
# Data resource for weapon classes, base attack ratings, scaling, and mastery tracking.
class_name WeaponData
extends Resource

@export var weapon_id: String = "stag_horn_blade"
@export var weapon_name: String = "Stag Horn Blade"
@export_enum("Longsword", "Twin Blades", "Great Hammer", "Scythe", "Bow", "Arcane Staff", "Void Blade") var weapon_class: String = "Longsword"
@export_enum("Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Corrupted") var rarity: String = "Rare"

@export var base_damage: float = 34.0
@export var str_scaling: float = 1.4
@export var arc_scaling: float = 1.1
@export var agi_scaling: float = 0.0
@export var crit_bonus: float = 0.08
@export var attack_speed_multiplier: float = 1.0
@export var stamina_cost_multiplier: float = 1.0
@export var element: String = "Physical"

# Upgrade tier (+0 to +10)
@export var upgrade_level: int = 0

# Special class perk
@export_multiline var special_perk: String = "Perfect parries release a burst of verdant nature spikes dealing 30% weapon damage."

# Milestone perks unlocked at mastery ranks 3, 5, 7, 10
@export var milestone_perks: Dictionary = {
	3: "Posture Breaker: Stagger threshold reduced by 15%",
	5: "Resonant Edge: Attribute scaling increased by 15%",
	7: "Kinetic Momentum: Consecutive attacks grant +5% damage (stacks 4x)",
	10: "Transcendence: Unleashes an elemental phantom strike on finisher"
}

func get_effective_base_damage() -> float:
	# Each upgrade level adds 10% base damage
	return base_damage * (1.0 + (upgrade_level * 0.10))

func calculate_scaled_damage(player_str: int, player_arc: int, player_agi: int, mastery_level: int = 0) -> float:
	var scaling_boost: float = 1.15 if mastery_level >= 5 else 1.0
	var dmg: float = get_effective_base_damage()
	dmg += (float(player_str) * str_scaling * scaling_boost)
	dmg += (float(player_arc) * arc_scaling * scaling_boost)
	dmg += (float(player_agi) * agi_scaling * scaling_boost)
	return dmg
