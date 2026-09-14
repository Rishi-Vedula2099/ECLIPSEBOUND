# CinderImp.gd
# World 3 fast airborne ember demon that lobs fireballs across heat zones.
class_name CinderImp
extends "res://scripts/enemies/BaseEnemy.gd"

var hover_offset: float = 0.0

func _ready() -> void:
	enemy_id = "cinder_imp"
	enemy_name = "Cinder Imp"
	max_health = 65.0
	defense = 10
	move_speed = 85.0
	chase_speed = 130.0
	xp_reward = 40.0
	max_poise = 25.0
	detection_radius = 240.0
	attack_range = 140.0
	attack_cooldown = 1.9
	
	if not default_attack_data and ResourceLoader.exists("res://data/attacks/enemies/cinder_fireball.tres"):
		default_attack_data = load("res://data/attacks/enemies/cinder_fireball.tres")
	
	super._ready()

func _setup_utility_actions() -> void:
	var shoot_action = UtilityAction.new("Cast_Fireball", 1.5, attack_cooldown)
	shoot_action.add_consideration(func(ctx):
		var dist = ctx.get("distance", 999.0)
		return UtilityAI.curve_linear(dist, 40.0, 160.0)
	)
	utility_ai.add_action(shoot_action)

func _physics_process(delta: float) -> void:
	hover_offset += delta * 4.0
	super._physics_process(delta)

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
			_position_hitbox_forward()
			hitbox.activate(attack_data)
	elif state_timer >= (startup + active) and state_timer < (startup + active + recovery):
		if hitbox:
			hitbox.deactivate()
	else:
		if hitbox:
			hitbox.deactivate()
		cooldown_timer = attack_cooldown
		change_state(State.CHASE)

func _draw() -> void:
	var imp_col = Color("#7f1d1d") if current_state != State.HURT else Color("#ffffff")
	var flame_col = Color("#f97316")
	
	# Small winged imp body
	var float_y = sin(hover_offset) * 4.0
	draw_circle(Vector2(0, -18 + float_y), 8.0, imp_col)
	
	# Bat wings
	draw_line(Vector2(-6, -20 + float_y), Vector2(-14, -26 + float_y), imp_col.darkened(0.2), 2.0)
	draw_line(Vector2(6, -20 + float_y), Vector2(14, -26 + float_y), imp_col.darkened(0.2), 2.0)
	
	# Horns & Fiery Eyes
	draw_line(Vector2(-3, -24 + float_y), Vector2(-5, -28 + float_y), Color("#450a0a"), 2.0)
	draw_line(Vector2(3, -24 + float_y), Vector2(5, -28 + float_y), Color("#450a0a"), 2.0)
	draw_circle(Vector2(facing_direction * 3, -19 + float_y), 1.5, flame_col)
	
	# Telegraph Warning
	if is_telegraphing:
		draw_circle(Vector2(0, -32 + float_y), 4.0, Color("#ea580c"))
		draw_line(Vector2(-8, -32 + float_y), Vector2(8, -32 + float_y), Color("#ea580c"), 2.0)
