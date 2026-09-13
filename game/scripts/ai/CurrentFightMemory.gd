# CurrentFightMemory.gd
# In-memory circular buffer tracking recent combat events and calculating rolling player habit metrics.
class_name CurrentFightMemory
extends RefCounted

const MAX_EVENT_BUFFER: int = 50

# Circular event buffer: array of {"timestamp": float, "type": String, "data": Dictionary}
var event_buffer: Array[Dictionary] = []

# Aggregate metrics for the active fight
var total_parries: int = 0
var total_dodges: int = 0
var total_light_attacks: int = 0
var total_heavy_attacks: int = 0
var total_abilities: int = 0
var total_heals: int = 0
var dodge_directions: Dictionary = {"left": 0, "right": 0}

func record_event(event_type: String, data: Dictionary = {}) -> void:
	var entry: Dictionary = {
		"timestamp": Time.get_unix_time_from_system(),
		"type": event_type,
		"data": data.duplicate(true)
	}
	
	event_buffer.append(entry)
	if event_buffer.size() > MAX_EVENT_BUFFER:
		event_buffer.pop_front()
	
	# Update aggregates
	match event_type:
		"parry": total_parries += 1
		"dodge":
			total_dodges += 1
			var dir = data.get("direction", "right").to_lower()
			if dir.contains("left") or dir == "left":
				dodge_directions["left"] += 1
			else:
				dodge_directions["right"] += 1
		"attack_light": total_light_attacks += 1
		"attack_heavy": total_heavy_attacks += 1
		"ability": total_abilities += 1
		"heal": total_heals += 1

func get_parry_frequency() -> float:
	var total_actions = total_light_attacks + total_heavy_attacks + total_parries + total_dodges
	if total_actions <= 0:
		return 0.0
	return float(total_parries) / float(total_actions)

func get_dodge_direction_bias() -> String:
	if dodge_directions["left"] > dodge_directions["right"]:
		return "left"
	return "right"

func get_dodge_bias_confidence() -> float:
	var total_dir_dodges = dodge_directions["left"] + dodge_directions["right"]
	if total_dir_dodges < 3:
		return 0.5
	var dominant = max(dodge_directions["left"], dodge_directions["right"])
	return float(dominant) / float(total_dir_dodges)

func get_recent_event_count(event_type: String, window_seconds: float = 10.0) -> int:
	var current_time = Time.get_unix_time_from_system()
	var count: int = 0
	for ev in event_buffer:
		if ev["type"] == event_type and (current_time - ev["timestamp"]) <= window_seconds:
			count += 1
	return count

func clear() -> void:
	event_buffer.clear()
	total_parries = 0
	total_dodges = 0
	total_light_attacks = 0
	total_heavy_attacks = 0
	total_abilities = 0
	total_heals = 0
	dodge_directions = {"left": 0, "right": 0}
