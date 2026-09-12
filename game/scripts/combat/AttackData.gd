# AttackData.gd
# Data-driven combat attack specification resource for ECLIPSEBOUND.
class_name AttackData
extends Resource

@export var attack_name: String = "Basic Attack"
@export var damage: float = 15.0
@export var stamina_cost: float = 12.0
@export var startup_time: float = 0.10   # Seconds before active hit window
@export var active_time: float = 0.12    # Seconds hitbox remains active
@export var recovery_time: float = 0.18  # Seconds player is locked in recovery
@export var knockback_force: Vector2 = Vector2(120.0, -40.0)

# Elemental & Status Effects
@export_enum("Physical", "Void", "Fire", "Frost", "Lightning", "Poison") var element: String = "Physical"
@export_enum("None", "Burn", "Bleed", "Freeze", "Shock", "Poison", "Curse", "Corruption", "Stagger", "Slow", "Silence") var status_effect: String = "None"
@export var status_duration: float = 3.0
@export var status_potency: float = 5.0

# Combat Rules
@export var can_be_parried: bool = true
@export var breaks_guard: bool = false
@export var screen_shake_intensity: float = 0.2
