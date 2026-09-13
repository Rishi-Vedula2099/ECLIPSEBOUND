# WeaponData.gd
# Data resource for weapon classes, base attack ratings, scaling, and mastery tracking.
class_name WeaponData
extends Resource

@export var weapon_id: String = "stag_horn_blade"
@export var weapon_name: String = "Stag Horn Blade"
@export_enum("Longsword", "Twin Blades", "Great Hammer", "Scythe", "Bow", "Arcane Staff", "Void Blade") var weapon_class: String = "Longsword"
@export var base_damage: float = 34.0
@export var str_scaling: float = 1.4
@export var arc_scaling: float = 1.1
@export var crit_bonus: float = 0.08
@export var element: String = "Physical"
@export_multiline var special_perk: String = "Perfect parries release a burst of verdant nature spikes dealing 30% weapon damage."
