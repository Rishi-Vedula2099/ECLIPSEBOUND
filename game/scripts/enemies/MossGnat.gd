# MossGnat.gd
# Aerial swooping enemy that hovers above the ground and drops slowing pollen spores.
class_name MossGnat
extends "res://scripts/enemies/BaseEnemy.gd"

var hover_altitude: float = 48.0
var flight_wobble: float = 0.0

func _ready() -> void:
	enemy_id = "moss_gnat"
	enemy_name = "Moss Gnat"
	max_health = 35.0
	defense = 4
	move_speed = 50.0
	chase_speed = 85.0
	xp_reward = 25.0
	max_poise = 15.0
	detection_radius = 220.0
	attack_range = 60.0
	attack_cooldown = 2.5
	
	if not default_attack_data and ResourceLoader.exists("res://data/attacks/enemies/gnat_spore.tres"):
		default_attack_data = load("res://data/attacks/enemies/gnat_spore.tres")
	
	super._ready()

func _apply_gravity(_delta: float) -> void:
	# Aerial flight bypasses gravity; maintains hover altitude
	pass

func _process_chase(delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		target_player = null
		change_state(State.IDLE)
		return
	
	var dist = global_position.distance_to(target_player.global_position)
	if dist > lose_target_radius:
		target_player = null
		change_state(State.IDLE)
		return
	
	facing_direction = int(sign(target_player.global_position.x - global_position.x))
	
	flight_wobble += delta * 5.0
	var target_pos = target_player.global_position + Vector2(facing_direction * -30.0, -hover_altitude + sin(flight_wobble) * 8.0)
	
	velocity = global_position.direction_to(target_pos) * chase_speed
	
	if dist <= attack_range and cooldown_timer <= 0.0:
		change_state(State.ATTACK)

func _process_attack(delta: float) -> void:
	state_timer += delta
	var attack_data = default_attack_data
	if not attack_data:
		change_state(State.CHASE)
		return
	
	var startup = attack_data.startup_time
	var active = attack_data.active_time
	var recovery = attack_data.recovery_time
	
	if state_timer < startup:
		is_telegraphing = true
		velocity = Vector2.ZERO
		if hitbox:
			hitbox.deactivate()
	elif state_timer >= startup and state_timer < (startup + active):
		is_telegraphing = false
		if hitbox and not hitbox._is_active:
			# Swoop dive
			velocity = Vector2(facing_direction * 120.0, 140.0)
			_position_hitbox_forward()
			hitbox.activate(attack_data)
	elif state_timer >= (startup + active) and state_timer < (startup + active + recovery):
		if hitbox:
			hitbox.deactivate()
		# Pull upward after swoop
		velocity = Vector2(0.0, -100.0)
	else:
		if hitbox:
			hitbox.deactivate()
		cooldown_timer = attack_cooldown
		change_state(State.CHASE)

func _draw() -> void:
	var col = Color("#84cc16") if current_state != State.HURT else Color("#ffffff")
	# Gnat thorax & abdomen
	draw_circle(Vector2(0, 0), 6.0, col)
	draw_circle(Vector2(facing_direction * -5, 2), 4.0, Color("#4d7c0f"))
	# Glowing yellow-green eye
	draw_circle(Vector2(facing_direction * 4, -2), 2.0, Color("#fef08a"))
	
	# Translucent wings
	draw_line(Vector2(-2, -2), Vector2(-8, -12), Color(1, 1, 1, 0.7), 2.0)
	draw_line(Vector2(2, -2), Vector2(8, -12), Color(1, 1, 1, 0.7), 2.0)
	
	# Telegraph flash
	if is_telegraphing:
		draw_circle(Vector2(0, -16), 3.5, Color("#eab308"))
