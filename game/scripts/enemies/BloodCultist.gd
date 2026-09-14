# BloodCultist.gd
# World 4 ranged heretic priest casting sanguine bolts and draining blood.
class_name BloodCultist
extends "res://scripts/enemies/BaseEnemy.gd"

func _ready() -> void:
	enemy_id = "blood_cultist"
	enemy_name = "Blood Cultist"
	max_health = 110.0
	defense = 14
	move_speed = 60.0
	chase_speed = 90.0
	xp_reward = 55.0
	max_poise = 30.0
	detection_radius = 230.0
	attack_range = 130.0
	attack_cooldown = 2.1
	
	if not default_attack_data and ResourceLoader.exists("res://data/attacks/enemies/cultist_sanguine_bolt.tres"):
		default_attack_data = load("res://data/attacks/enemies/cultist_sanguine_bolt.tres")
	
	super._ready()

func _setup_utility_actions() -> void:
	var bolt_action = UtilityAction.new("Cast_Sanguine_Bolt", 1.5, attack_cooldown)
	bolt_action.add_consideration(func(ctx):
		var dist = ctx.get("distance", 999.0)
		return UtilityAI.curve_linear(dist, 50.0, 150.0)
	)
	utility_ai.add_action(bolt_action)

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
		velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
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
	var robe_col = Color("#581c87") if current_state != State.HURT else Color("#ffffff")
	var blood_col = Color("#e11d48")
	
	# Robed cultist silhouette
	draw_polygon([
		Vector2(-10, 0),
		Vector2(10, 0),
		Vector2(6, -26),
		Vector2(-6, -26)
	], [robe_col])
	
	# Hood & Mask
	draw_circle(Vector2(0, -28), 7.0, robe_col.darkened(0.2))
	draw_circle(Vector2(facing_direction * 3, -28), 1.5, blood_col)
	
	# Sacrificial Dagger / Staff
	draw_line(Vector2(facing_direction * 10, -24), Vector2(facing_direction * 10, -4), Color("#cbd5e1"), 2.0)
	draw_circle(Vector2(facing_direction * 10, -26), 3.0, blood_col)
	
	# Telegraph Warning
	if is_telegraphing:
		draw_circle(Vector2(0, -40), 4.0, Color("#be123c"))
		draw_line(Vector2(-10, -40), Vector2(10, -40), Color("#be123c"), 2.0)
