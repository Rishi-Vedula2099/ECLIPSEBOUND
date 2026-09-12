# GameCamera2D.gd
# Smooth tracking camera with look-ahead and trauma-based screen shake.
class_name GameCamera2D
extends Camera2D

@export var target: Node2D
@export var follow_speed: float = 8.0
@export var look_ahead_distance: float = 32.0
@export var look_ahead_speed: float = 4.0

# Trauma Screen Shake Parameters
@export var trauma_decay: float = 1.4
@export var max_offset: Vector2 = Vector2(8.0, 6.0)
@export var max_roll_degrees: float = 1.5

var trauma: float = 0.0
var _current_look_ahead: float = 0.0
var _noise_y: float = 0.0

func _ready() -> void:
	make_current()
	CombatSystem.combo_updated.connect(func(_combo, _bonus): add_trauma(0.12))
	EventBus.player_damaged.connect(func(_cur, _max, dmg, _src): add_trauma(clamp(dmg * 0.02, 0.25, 0.8)))
	EventBus.player_parried.connect(func(_target, is_perfect): add_trauma(0.35 if is_perfect else 0.15))

func _process(delta: float) -> void:
	if not target:
		# Auto-locate player if target not assigned
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0]
		else:
			return
	
	# 1. Smooth look-ahead calculation
	var target_facing: float = 1.0
	if "facing_direction" in target:
		target_facing = float(target.facing_direction)
	elif target is CharacterBody2D and abs(target.velocity.x) > 10.0:
		target_facing = sign(target.velocity.x)
	
	var desired_look_ahead: float = target_facing * look_ahead_distance
	_current_look_ahead = move_toward(_current_look_ahead, desired_look_ahead, look_ahead_speed * look_ahead_distance * delta)
	
	# 2. Smooth target follow
	var desired_pos: Vector2 = target.global_position + Vector2(_current_look_ahead, -16.0)
	global_position = global_position.lerp(desired_pos, follow_speed * delta)
	
	# 3. Process Trauma Screen Shake
	if trauma > 0.0:
		trauma = max(0.0, trauma - trauma_decay * delta)
		_apply_shake(delta)
	else:
		offset = Vector2.ZERO
		rotation = 0.0

func add_trauma(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)

func _apply_shake(_delta: float) -> void:
	var shake_amount: float = trauma * trauma # Non-linear trauma falloff
	_noise_y += 1.0
	var offset_x: float = max_offset.x * shake_amount * randf_range(-1.0, 1.0)
	var offset_y: float = max_offset.y * shake_amount * randf_range(-1.0, 1.0)
	offset = Vector2(offset_x, offset_y)
	rotation_degrees = max_roll_degrees * shake_amount * randf_range(-1.0, 1.0)
