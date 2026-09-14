# DreamPhantasm.gd
# World 6 ethereal skirmisher that teleports and phases through attacks with lucid slashes.
class_name DreamPhantasm
extends "res://scripts/enemies/BaseEnemy.gd"

var phase_timer: float = 0.0

func _ready() -> void:
	enemy_id = "dream_phantasm"
	enemy_name = "Dream Phantasm"
	max_health = 90.0
	defense = 14
	move_speed = 80.0
	chase_speed = 135.0
	xp_reward = 70.0
	max_poise = 25.0
	detection_radius = 220.0
	attack_range = 46.0
	attack_cooldown = 1.9
	
	if not default_attack_data and ResourceLoader.exists("res://data/attacks/enemies/phantasm_phase_slash.tres"):
		default_attack_data = load("res://data/attacks/enemies/phantasm_phase_slash.tres")
	
	super._ready()

func _setup_utility_actions() -> void:
	var slash_action = UtilityAction.new("Phase_Slash", 1.5, attack_cooldown)
	slash_action.add_consideration(func(ctx):
		var dist = ctx.get("distance", 999.0)
		return UtilityAI.curve_inverse_linear(dist, 0.0, 55.0)
	)
	utility_ai.add_action(slash_action)

func _physics_process(delta: float) -> void:
	phase_timer += delta * 3.0
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
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		if hitbox:
			hitbox.deactivate()
	elif state_timer >= startup and state_timer < (startup + active):
		is_telegraphing = false
		if hitbox and not hitbox._is_active:
			velocity.x = facing_direction * 220.0
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
	var alpha = 0.5 + 0.5 * sin(phase_timer)
	var phantasm_col = Color(0.3, 0.8, 0.9, alpha) if current_state != State.HURT else Color("#ffffff")
	var core_col = Color("#a855f7")
	
	# Shifting ethereal spirit form
	draw_circle(Vector2(0, -18), 10.0, phantasm_col)
	draw_circle(Vector2(0, -18), 4.0, core_col)
	
	# Wispy tail
	draw_line(Vector2(0, -10), Vector2(-facing_direction * 8, 0), phantasm_col, 2.5)
	
	# Telegraph Warning
	if is_telegraphing:
		draw_circle(Vector2(0, -32), 4.0, Color("#c084fc"))
		draw_line(Vector2(-10, -32), Vector2(10, -32), Color("#c084fc"), 2.0)
