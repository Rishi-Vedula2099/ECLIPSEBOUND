# BehavioralFingerprint.gd
# Tracks observable player signals across 6 categories using Exponentially Weighted
# Moving Averages (EWMA) and Bayesian confidence updates with temporal & failure decay.
class_name BehavioralFingerprint
extends RefCounted

signal fingerprint_updated(signals: Dictionary)
signal habit_confidence_decayed(signal_name: String, new_confidence: float)

# EWMA smoothing factor alpha (higher = more reactive, lower = more stable history)
const DEFAULT_ALPHA: float = 0.20

# ---------------------------------------------------------
# 1. Observable Signal State across 6 Categories
# ---------------------------------------------------------

# Category 1: Offense
var light_attacks_count: int = 0
var heavy_attacks_count: int = 0
var light_heavy_ratio: float = 0.5 # 0.0 = all heavy, 1.0 = all light
var avg_combo_length: float = 2.0
var total_attacks: int = 0
var combat_duration: float = 0.0
var attack_rate: float = 0.0 # Attacks per second

# Category 2: Defense
var total_incoming_attacks: int = 0
var dodges_executed: int = 0
var parries_executed: int = 0
var blocks_executed: int = 0
var hits_taken: int = 0
var dodge_rate: float = 0.0
var parry_rate: float = 0.0
var block_rate: float = 0.0
var damage_taken_sum: float = 0.0
var damage_taken_per_hit: float = 0.0

# Category 3: Positioning
var time_in_melee: float = 0.0 # < 80px
var time_in_mid: float = 0.0   # 80-200px
var time_in_ranged: float = 0.0 # > 200px
var primary_distance_preference: String = "MID" # "MELEE", "MID", "RANGED"
var retreat_hp_threshold: float = 0.30 # HP % when player begins actively retreating

# Category 4: Mobility
var dash_count: int = 0
var dash_frequency: float = 0.0 # Dashes per minute
var dodge_counts: Dictionary = {"LEFT": 0, "RIGHT": 0, "BACKWARD": 0}
var dodge_direction_bias: String = "NONE"
var dodge_direction_confidence: float = 0.0

# Category 5: Abilities & Items
var skill_uses: int = 0
var skill_frequency: float = 0.0
var cooldown_readiness_latencies: Array = []
var avg_cooldown_latency: float = 1.0 # Delay after CD ready before casting
var heal_uses: int = 0
var heal_hp_triggers: Array = []
var avg_heal_hp_threshold: float = 0.35 # Mean HP % when player sips potion
var greedy_heal_count: int = 0 # Heals popped inside danger radius

# Category 6: Build & Risk
var active_weapon: String = "longsword"
var active_artifact_set: String = "verdant_guardian"
var low_hp_attacks: int = 0
var low_hp_duration: float = 0.0
var low_hp_aggression: float = 0.5 # Attack frequency while under 30% HP

# Tracking metadata
var alpha: float = DEFAULT_ALPHA
var last_decay_timestamp: float = 0.0


func _init(p_alpha: float = DEFAULT_ALPHA) -> void:
	alpha = clampf(p_alpha, 0.05, 0.5)


# ---------------------------------------------------------
# Signal Ingestion & EWMA Updates
# ---------------------------------------------------------

func record_attack(is_heavy: bool, combo_step: int) -> void:
	total_attacks += 1
	if is_heavy:
		heavy_attacks_count += 1
	else:
		light_attacks_count += 1

	var instantaneous_ratio: float = 1.0 if not is_heavy else 0.0
	light_heavy_ratio = (alpha * instantaneous_ratio) + ((1.0 - alpha) * light_heavy_ratio)
	avg_combo_length = (alpha * float(combo_step)) + ((1.0 - alpha) * avg_combo_length)
	_recalculate_attack_rate()
	emit_signal("fingerprint_updated", get_fingerprint_dict())


func record_incoming_hit_resolved(outcome: String, damage: float = 0.0) -> void:
	# outcome: "dodge", "parry", "block", "hit_taken"
	total_incoming_attacks += 1
	var is_dodge: float = 1.0 if outcome == "dodge" else 0.0
	var is_parry: float = 1.0 if outcome == "parry" else 0.0
	var is_block: float = 1.0 if outcome == "block" else 0.0

	if outcome == "dodge": dodges_executed += 1
	elif outcome == "parry": parries_executed += 1
	elif outcome == "block": blocks_executed += 1
	elif outcome == "hit_taken":
		hits_taken += 1
		damage_taken_sum += damage
		damage_taken_per_hit = damage_taken_sum / max(1, hits_taken)

	dodge_rate = (alpha * is_dodge) + ((1.0 - alpha) * dodge_rate)
	parry_rate = (alpha * is_parry) + ((1.0 - alpha) * parry_rate)
	block_rate = (alpha * is_block) + ((1.0 - alpha) * block_rate)
	emit_signal("fingerprint_updated", get_fingerprint_dict())


func record_dodge(direction: String) -> void:
	dash_count += 1
	var dir_key: String = direction.to_upper()
	if not dodge_counts.has(dir_key):
		dir_key = "RIGHT"
	dodge_counts[dir_key] += 1

	# Bayesian confidence update: P(Dir) = (count + 1) / (N + K)
	var total_dodges: int = dodge_counts["LEFT"] + dodge_counts["RIGHT"] + dodge_counts["BACKWARD"]
	var max_dir: String = "RIGHT"
	var max_count: int = 0
	for d in dodge_counts.keys():
		if dodge_counts[d] > max_count:
			max_count = dodge_counts[d]
			max_dir = d

	dodge_direction_bias = max_dir
	# K = 3 directions prior
	dodge_direction_confidence = float(max_count + 1) / float(total_dodges + 3)
	emit_signal("fingerprint_updated", get_fingerprint_dict())


func record_positioning(distance: float, delta: float) -> void:
	combat_duration += delta
	if distance < 80.0:
		time_in_melee += delta
	elif distance <= 200.0:
		time_in_mid += delta
	else:
		time_in_ranged += delta

	var total_time: float = time_in_melee + time_in_mid + time_in_ranged
	if total_time > 0.001:
		if time_in_melee >= time_in_mid and time_in_melee >= time_in_ranged:
			primary_distance_preference = "MELEE"
		elif time_in_mid >= time_in_melee and time_in_mid >= time_in_ranged:
			primary_distance_preference = "MID"
		else:
			primary_distance_preference = "RANGED"

	_recalculate_attack_rate()


func record_heal_event(hp_ratio: float, enemy_distance: float) -> void:
	heal_uses += 1
	heal_hp_triggers.append(hp_ratio)
	avg_heal_hp_threshold = (alpha * hp_ratio) + ((1.0 - alpha) * avg_heal_hp_threshold)
	if enemy_distance < 100.0:
		greedy_heal_count += 1
	emit_signal("fingerprint_updated", get_fingerprint_dict())


func record_skill_activation(latency_since_ready: float = 0.5) -> void:
	skill_uses += 1
	cooldown_readiness_latencies.append(latency_since_ready)
	avg_cooldown_latency = (alpha * latency_since_ready) + ((1.0 - alpha) * avg_cooldown_latency)


func record_low_hp_state(is_low_hp: bool, delta: float, did_attack: bool) -> void:
	if is_low_hp:
		low_hp_duration += delta
		if did_attack:
			low_hp_attacks += 1
		var instant_aggression: float = 1.0 if did_attack else 0.0
		low_hp_aggression = (alpha * instant_aggression) + ((1.0 - alpha) * low_hp_aggression)


# ---------------------------------------------------------
# Temporal Decay & Counter-Failure Penalty
# ---------------------------------------------------------

# If an adaptive counter fails (e.g. boss anticipated right dodge, but player dodged left or punished boss),
# decay the confidence by 50% immediately to prevent rigid exploitation.
func decay_on_counter_failure(tactic_name: String) -> void:
	if tactic_name == "position_prediction" or tactic_name == "pattern_recognition":
		dodge_direction_confidence = max(0.15, dodge_direction_confidence * 0.50)
		emit_signal("habit_confidence_decayed", tactic_name, dodge_direction_confidence)
	elif tactic_name == "attack_counter":
		parry_rate = max(0.10, parry_rate * 0.70)
		emit_signal("habit_confidence_decayed", tactic_name, parry_rate)
	emit_signal("fingerprint_updated", get_fingerprint_dict())


func apply_temporal_decay(delta: float, half_life_sec: float = 60.0) -> void:
	# Gradually decays extreme biases toward baseline 0.5 using half-life decay
	var decay_factor: float = pow(0.5, delta / half_life_sec)
	light_heavy_ratio = 0.5 + (light_heavy_ratio - 0.5) * decay_factor
	dodge_rate = 0.5 + (dodge_rate - 0.5) * decay_factor
	parry_rate = 0.5 + (parry_rate - 0.5) * decay_factor
	low_hp_aggression = 0.5 + (low_hp_aggression - 0.5) * decay_factor
	dodge_direction_confidence = max(0.33, dodge_direction_confidence * decay_factor)


func _recalculate_attack_rate() -> void:
	if combat_duration > 0.5:
		attack_rate = float(total_attacks) / combat_duration
		dash_frequency = (float(dash_count) / combat_duration) * 60.0
		skill_frequency = (float(skill_uses) / combat_duration) * 60.0


# ---------------------------------------------------------
# Export Dictionary
# ---------------------------------------------------------

func get_fingerprint_dict() -> Dictionary:
	return {
		"offense": {
			"light_heavy_ratio": light_heavy_ratio,
			"avg_combo_length": avg_combo_length,
			"attack_rate": attack_rate,
			"total_attacks": total_attacks,
		},
		"defense": {
			"dodge_rate": dodge_rate,
			"parry_rate": parry_rate,
			"block_rate": block_rate,
			"damage_taken_per_hit": damage_taken_per_hit,
		},
		"positioning": {
			"distance_preference": primary_distance_preference,
			"time_melee": time_in_melee,
			"time_mid": time_in_mid,
			"time_ranged": time_in_ranged,
			"retreat_hp_threshold": retreat_hp_threshold,
		},
		"mobility": {
			"dash_frequency": dash_frequency,
			"dodge_direction_bias": dodge_direction_bias,
			"dodge_confidence": dodge_direction_confidence,
		},
		"abilities": {
			"skill_frequency": skill_frequency,
			"avg_cooldown_latency": avg_cooldown_latency,
			"avg_heal_hp_threshold": avg_heal_hp_threshold,
			"greedy_heals": greedy_heal_count,
		},
		"risk": {
			"weapon": active_weapon,
			"artifact_set": active_artifact_set,
			"low_hp_aggression": low_hp_aggression,
		}
	}
