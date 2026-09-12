# BrambleBeast.gd
# Quadruped predator with lunging charge and bleeding pounce.
class_name BrambleBeast
extends "res://scripts/enemies/BaseEnemy.gd"

var pounce_cooldown: float = 0.0

func _ready() -> void:
	enemy_id = "bramble_beast"
	enemy_name = "Bramble Beast"
	max_health = 75.0
	defense = 10
	move_speed = 70.0
	chase_speed = 120.0
	xp_reward = 35.0
	max_poise = 35.0
	detection_radius = 200.0
	attack_range = 42.0
	attack_cooldown = 2.2
	
	if not default_attack_data and ResourceLoader.exists("res://data/attacks/enemies/beast_pounce.tres"):
		default_attack_data = load("res://data/attacks/enemies/beast_pounce.tres")
	
	super._ready()

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
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		if hitbox:
			hitbox.deactivate()
	elif state_timer >= startup and state_timer < (startup + active):
		is_telegraphing = false
		if hitbox and not hitbox._is_active:
			# Leap forward toward player
			velocity.x = facing_direction * 180.0
			velocity.y = -120.0
			_position_hitbox_forward()
			hitbox.activate(attack_data)
	elif state_timer >= (startup + active) and state_timer < (startup + active + recovery):
		if hitbox:
			hitbox.deactivate()
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	else:
		if hitbox:
			hitbox.deactivate()
		cooldown_timer = attack_cooldown
		change_state(State.CHASE)

func _draw() -> void:
	var beast_col = Color("#3f2e18") if current_state != State.HURT else Color("#ffffff")
	var moss_col = Color("#22c55e")
	
	# Quadruped Body
	draw_rect(Rect2(-14, -16, 28, 12), beast_col)
	# Moss spines on spine
	draw_line(Vector2(-10, -18), Vector2(-10, -16), moss_col, 2.0)
	draw_line(Vector2(-4, -20), Vector2(-4, -16), moss_col, 2.5)
	draw_line(Vector2(2, -18), Vector2(2, -16), moss_col, 2.0)
	
	# Legs
	draw_rect(Rect2(-12, -4, 4, 8), beast_col.darkened(0.2))
	draw_rect(Rect2(8, -4, 4, 8), beast_col.darkened(0.2))
	
	# Head & Glowing Red Beast Eye
	draw_rect(Rect2(facing_direction * 12, -18, 6, 8), beast_col)
	draw_circle(Vector2(facing_direction * 15, -15), 2.0, Color("#ef4444"))
	
	# Telegraph Warning
	if is_telegraphing:
		draw_circle(Vector2(0, -28), 4.0, Color("#ff0055"))
		draw_line(Vector2(-10, -28), Vector2(10, -28), Color("#ff0055"), 2.0)
	
	# Stagger Stars
	if current_state == State.STAGGER:
		draw_circle(Vector2(-6, -26), 2.5, Color("#fbbf24"))
		draw_circle(Vector2(6, -26), 2.5, Color("#fbbf24"))
