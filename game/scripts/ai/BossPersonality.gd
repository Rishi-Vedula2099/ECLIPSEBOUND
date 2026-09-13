# BossPersonality.gd
# Manages personality parameters for adaptive boss combat decision weighting.
class_name BossPersonality
extends RefCounted

# Personality weights (0.0 to 1.0)
var aggression: float = 0.5   # Weight given to gap-closing and relentless offense
var patience: float = 0.5     # Weight given to defensive postures and spacing
var reactiveness: float = 0.5 # Weight given to countering observed player patterns
var cunning: float = 0.5      # Weight given to feints, delays, and area traps

func _init(agg: float = 0.5, pat: float = 0.5, react: float = 0.5, cun: float = 0.5) -> void:
	aggression = clampf(agg, 0.0, 1.0)
	patience = clampf(pat, 0.0, 1.0)
	reactiveness = clampf(react, 0.0, 1.0)
	cunning = clampf(cun, 0.0, 1.0)

func get_offensive_bias() -> float:
	return 0.7 + (aggression * 0.6)

func get_spacing_bias() -> float:
	return 0.7 + (patience * 0.6)

func get_counter_bias() -> float:
	return 0.7 + (reactiveness * 0.6)

func get_feint_chance() -> float:
	return cunning * 0.40  # up to 40% feint chance

func to_dict() -> Dictionary:
	return {
		"aggression": aggression,
		"patience": patience,
		"reactiveness": reactiveness,
		"cunning": cunning
	}

func from_dict(data: Dictionary) -> void:
	aggression = data.get("aggression", 0.5)
	patience = data.get("patience", 0.5)
	reactiveness = data.get("reactiveness", 0.5)
	cunning = data.get("cunning", 0.5)
