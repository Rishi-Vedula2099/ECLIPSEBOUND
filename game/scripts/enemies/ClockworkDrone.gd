# ClockworkDrone.gd
# World 5 hovering mechanical drone that zaps intruders with high-voltage electricity.
class_name ClockworkDrone
extends "res://scripts/enemies/BaseEnemy.gd"

var rotor_angle: float = 0.0

func _ready() -> void:
	enemy_id = "clockwork_drone"
	enemy_name = "Clockwork Drone"
	max_health = 80.0
	defense = 16
	move_speed = 70.0
	chase_speed = 110.0
	xp_reward = 60.0
	max_poise = 30.0
	detection_radius = 210.0
	attack_range = 100.0
	attack_cooldown = 1.8
	
	if not default_attack_data and ResourceLoader.exists("res://data/attacks/enemies/drone_zap.tres"):
		default_attack_data = load("res://data/attacks/enemies/drone_zap.tres")
	
	super._ready()

func _setup_utility_actions() -> void:
	var zap_action = UtilityAction.new("Shock_Pulse", 1.4, attack_cooldown)
	zap_action.add_consideration(func(ctx):
		var dist = ctx.get("distance", 999.0)
		return UtilityAI.curve_linear(dist, 30.0, 120.0)
	)
	utility_ai.add_action(zap_action)

func _physics_process(delta: float) -> void:
	rotor_angle += delta * 12.0
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
	var brass_col = Color("#d97706") if current_state != State.HURT else Color("#ffffff")
	var electric_col = Color("#38bdf8")
	
	# Brass chassis
	draw_rect(Rect2(-10, -22, 20, 14), brass_col)
	# Central optical lens
	draw_circle(Vector2(facing_direction * 2, -15), 4.0, Color("#1e293b"))
	draw_circle(Vector2(facing_direction * 2, -15), 2.0, electric_col)
	
	# Rotating rotor blades on top
	var rx = cos(rotor_angle) * 12.0
	draw_line(Vector2(-rx, -24), Vector2(rx, -24), Color("#94a3b8"), 2.0)
	
	# Underside stun prong
	draw_line(Vector2(0, -8), Vector2(0, -4), electric_col, 2.0)
	
	# Telegraph Warning
	if is_telegraphing:
		draw_circle(Vector2(0, -32), 4.0, Color("#0284c7"))
		draw_line(Vector2(-8, -32), Vector2(8, -32), Color("#0284c7"), 2.0)
