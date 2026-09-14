# GlitchFragment.gd
# World 7 reality-distorting void glitch that erratically flickers and unleashes rule-breaking bursts.
class_name GlitchFragment
extends "res://scripts/enemies/BaseEnemy.gd"

var glitch_seed: float = 0.0

func _ready() -> void:
	enemy_id = "glitch_fragment"
	enemy_name = "Glitch Fragment"
	max_health = 130.0
	defense = 18
	move_speed = 90.0
	chase_speed = 150.0
	xp_reward = 90.0
	max_poise = 30.0
	detection_radius = 250.0
	attack_range = 48.0
	attack_cooldown = 1.7
	
	if not default_attack_data and ResourceLoader.exists("res://data/attacks/enemies/glitch_burst.tres"):
		default_attack_data = load("res://data/attacks/enemies/glitch_burst.tres")
	
	super._ready()

func _setup_utility_actions() -> void:
	var burst_action = UtilityAction.new("Glitch_Burst", 1.5, attack_cooldown)
	burst_action.add_consideration(func(ctx):
		var dist = ctx.get("distance", 999.0)
		return UtilityAI.curve_inverse_linear(dist, 0.0, 60.0)
	)
	utility_ai.add_action(burst_action)

func _physics_process(delta: float) -> void:
	glitch_seed += delta * 20.0
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
	var glitch_col = Color("#ec4899") if current_state != State.HURT else Color("#ffffff")
	var void_col = Color("#09090b")
	var cyan_col = Color("#06b6d4")
	
	# Fractured glitch block
	draw_rect(Rect2(-12, -26, 24, 24), void_col)
	draw_rect(Rect2(-10, -24, 20, 20), glitch_col, false, 2.0)
	
	# Erratic glitch artifact lines
	var off_x = sin(glitch_seed) * 4.0
	draw_line(Vector2(-14 + off_x, -16), Vector2(14 + off_x, -16), cyan_col, 1.5)
	draw_line(Vector2(off_x, -28), Vector2(off_x, -4), cyan_col, 1.5)
	
	# Telegraph Warning
	if is_telegraphing:
		draw_circle(Vector2(0, -38), 4.0, Color("#f43f5e"))
		draw_line(Vector2(-12, -38), Vector2(12, -38), Color("#f43f5e"), 2.0)
