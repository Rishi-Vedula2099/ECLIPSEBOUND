# DrownedLurker.gd
# World 2 aquatic stalker enemy that moves silently through water depth and ambushes the player.
class_name DrownedLurker
extends "res://scripts/enemies/BaseEnemy.gd"

func _ready() -> void:
	enemy_id = "drowned_lurker"
	enemy_name = "Drowned Lurker"
	max_health = 95.0
	defense = 12
	move_speed = 75.0
	chase_speed = 125.0
	xp_reward = 45.0
	max_poise = 40.0
	detection_radius = 220.0
	attack_range = 44.0
	attack_cooldown = 2.0
	
	if not default_attack_data and ResourceLoader.exists("res://data/attacks/enemies/lurker_ambush.tres"):
		default_attack_data = load("res://data/attacks/enemies/lurker_ambush.tres")
	
	super._ready()

func _setup_utility_actions() -> void:
	var ambush_action = UtilityAction.new("Ambush_Strike", 1.4, attack_cooldown)
	ambush_action.add_consideration(func(ctx):
		var dist = ctx.get("distance", 999.0)
		return UtilityAI.curve_inverse_linear(dist, 0.0, 50.0)
	)
	utility_ai.add_action(ambush_action)

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
			velocity.x = facing_direction * 190.0
			velocity.y = -80.0
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
	var body_col = Color("#0c4a6e") if current_state != State.HURT else Color("#ffffff")
	var eye_col = Color("#38bdf8")
	
	# Hunched aquatic body
	draw_rect(Rect2(-14, -18, 28, 16), body_col)
	# Barnacle clusters
	draw_circle(Vector2(-6, -14), 2.5, Color("#0369a1"))
	draw_circle(Vector2(4, -16), 2.0, Color("#0369a1"))
	
	# Legs / flippers
	draw_rect(Rect2(-12, -2, 6, 6), body_col.darkened(0.3))
	draw_rect(Rect2(6, -2, 6, 6), body_col.darkened(0.3))
	
	# Head & Glowing cyan bioluminescent eyes
	draw_circle(Vector2(facing_direction * 12, -12), 2.5, eye_col)
	
	# Telegraph Warning
	if is_telegraphing:
		draw_circle(Vector2(0, -28), 4.0, Color("#06b6d4"))
		draw_line(Vector2(-10, -28), Vector2(10, -28), Color("#06b6d4"), 2.0)
	
	# Stagger Indicator
	if current_state == State.STAGGER:
		draw_circle(Vector2(-6, -26), 2.5, Color("#fbbf24"))
		draw_circle(Vector2(6, -26), 2.5, Color("#fbbf24"))
