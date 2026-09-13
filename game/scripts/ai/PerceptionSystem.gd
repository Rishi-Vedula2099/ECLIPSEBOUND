# PerceptionSystem.gd
# Modular perception system for ECLIPSEBOUND enemies and bosses.
# Provides Vision Cone (FOV angle, range, raycasting), Hearing (acoustic radius), Proximity circle, and Target Memory decay.
class_name PerceptionSystem
extends Node2D

signal target_detected(target: Node2D)
signal target_lost(last_known_position: Vector2)
signal sound_heard(sound_type: String, source_position: Vector2)

@export_group("Vision Cone")
@export var vision_range: float = 180.0
@export var vision_fov_deg: float = 110.0  # Field of view in degrees (e.g. 110 deg cone)
@export var requires_line_of_sight: bool = false
@export var sight_collision_mask: int = 1  # Environment layer

@export_group("Hearing")
@export var hearing_radius: float = 240.0
@export var hearing_enabled: bool = true

@export_group("Proximity")
@export var proximity_radius: float = 48.0  # 360 degree immediate blind-spot protection

@export_group("Memory Decay")
@export var memory_duration: float = 3.5  # Seconds to remember last known position

var current_target: Node2D = null
var last_known_position: Vector2 = Vector2.ZERO
var memory_timer: float = 0.0
var has_target: bool = false

func _process(delta: float) -> void:
	if has_target and not is_instance_valid(current_target):
		_lose_target()
		return

	if memory_timer > 0.0:
		memory_timer -= delta
		if memory_timer <= 0.0 and not has_direct_awareness():
			_lose_target()

func update_perception(potential_target: Node2D, facing_dir: int) -> bool:
	if not potential_target or not is_instance_valid(potential_target):
		if has_target:
			_lose_target()
		return false

	var to_target: Vector2 = potential_target.global_position - global_position
	var dist: float = to_target.length()

	# 1. Proximity Check (360 degree immediate circle)
	if dist <= proximity_radius:
		_acquire_target(potential_target)
		return true

	# 2. Vision Cone Check
	if dist <= vision_range:
		var forward_vector: Vector2 = Vector2.RIGHT if facing_dir >= 0 else Vector2.LEFT
		var angle_to_target_deg: float = rad_to_deg(forward_vector.angle_to(to_target.normalized()))
		
		if absf(angle_to_target_deg) <= (vision_fov_deg * 0.5):
			# Within cone angle
			if not requires_line_of_sight or _has_line_of_sight(potential_target.global_position):
				_acquire_target(potential_target)
				return true

	# If outside direct awareness, rely on target memory timer
	if has_target:
		if dist > (vision_range * 1.5):  # Escape distance
			_lose_target()
			return false
		return memory_timer > 0.0

	return false

func report_sound(sound_type: String, sound_pos: Vector2, sound_volume: float = 1.0) -> bool:
	if not hearing_enabled:
		return false
		
	var dist: float = (sound_pos - global_position).length()
	var effective_radius: float = hearing_radius * sound_volume
	
	if dist <= effective_radius:
		sound_heard.emit(sound_type, sound_pos)
		last_known_position = sound_pos
		memory_timer = memory_duration
		return true
		
	return false

func has_direct_awareness() -> bool:
	if not current_target or not is_instance_valid(current_target):
		return false
	var dist: float = (current_target.global_position - global_position).length()
	return dist <= proximity_radius or dist <= vision_range

func _acquire_target(target: Node2D) -> void:
	current_target = target
	last_known_position = target.global_position
	memory_timer = memory_duration
	if not has_target:
		has_target = true
		target_detected.emit(target)

func _lose_target() -> void:
	has_target = false
	current_target = null
	target_lost.emit(last_known_position)

func _has_line_of_sight(target_pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	if not space_state:
		return true
	var query = PhysicsRayQueryParameters2D.create(global_position, target_pos, sight_collision_mask)
	var result = space_state.intersect_ray(query)
	return result.is_empty()
