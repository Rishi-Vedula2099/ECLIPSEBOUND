# PersistentMemoryProfile.gd
# Stores cross-fight aggregated player habits for persistent boss encounters.
class_name PersistentMemoryProfile
extends RefCounted

var boss_id: String = "hollow_stag"
var encounter_attempts: int = 0
var historical_parry_rate: float = 0.35
var historical_dodge_bias: String = "right"
var historical_dodge_confidence: float = 0.55
var average_reaction_ms: float = 240.0
var low_hp_aggression: float = 0.50

func record_encounter_summary(attempts: int, parry_rate: float, dodge_bias: String, dodge_conf: float, avg_reaction: float) -> void:
	encounter_attempts = attempts
	# Exponentially weighted moving average update
	historical_parry_rate = lerpf(historical_parry_rate, parry_rate, 0.35)
	historical_dodge_bias = dodge_bias
	historical_dodge_confidence = lerpf(historical_dodge_confidence, dodge_conf, 0.40)
	average_reaction_ms = lerpf(average_reaction_ms, avg_reaction, 0.25)

func to_dict() -> Dictionary:
	return {
		"boss_id": boss_id,
		"encounter_attempts": encounter_attempts,
		"historical_parry_rate": historical_parry_rate,
		"historical_dodge_bias": historical_dodge_bias,
		"historical_dodge_confidence": historical_dodge_confidence,
		"average_reaction_ms": average_reaction_ms,
		"low_hp_aggression": low_hp_aggression
	}

func from_dict(data: Dictionary) -> void:
	boss_id = data.get("boss_id", "hollow_stag")
	encounter_attempts = data.get("encounter_attempts", 0)
	historical_parry_rate = data.get("historical_parry_rate", 0.35)
	historical_dodge_bias = data.get("historical_dodge_bias", "right")
	historical_dodge_confidence = data.get("historical_dodge_confidence", 0.55)
	average_reaction_ms = data.get("average_reaction_ms", 240.0)
	low_hp_aggression = data.get("low_hp_aggression", 0.50)
