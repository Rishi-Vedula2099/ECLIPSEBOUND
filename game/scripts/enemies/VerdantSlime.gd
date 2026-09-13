# VerdantSlime.gd
# Common forest enemy with hopping movement and poisonous acid splash.
class_name VerdantSlime
extends "res://scripts/enemies/BaseEnemy.gd"

var hop_timer: float = 0.0
var is_hopping: bool = false

func _ready() -> void:
	enemy_id = "verdant_slime"
	enemy_name = "Verdant Slime"
	max_health = 45.0
	defense = 6
	move_speed = 45.0
	chase_speed = 70.0
	xp_reward = 20.0
	max_poise = 20.0
	detection_radius = 160.0
	attack_range = 28.0
	attack_cooldown = 2.0
	
	if not default_attack_data and ResourceLoader.exists("res://data/attacks/enemies/slime_acid.tres"):
		default_attack_data = load("res://data/attacks/enemies/slime_acid.tres")
	
	super._ready()

func _setup_utility_actions() -> void:
	# Action 1: Acid Lunge (close acid splash)
	var acid_action = UtilityAction.new("Acid_Lunge", 1.3, attack_cooldown)
	acid_action.add_consideration(func(ctx):
		var dist = ctx.get("distance", 999.0)
		return UtilityAI.curve_inverse_linear(dist, 0.0, 32.0)
	)
	utility_ai.add_action(acid_action)
	
	# Action 2: Swarm Jump (gap closing hop)
	var hop_action = UtilityAction.new("Swarm_Hop", 1.0, 1.0)
	hop_action.add_consideration(func(ctx):
		var dist = ctx.get("distance", 999.0)
		return UtilityAI.curve_linear(dist, 30.0, 120.0)
	)
	utility_ai.add_action(hop_action)

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
	
	# Attack check
	if dist <= attack_range and cooldown_timer <= 0.0:
		change_state(State.ATTACK)
		return
	
	# Slime hop movement cycle
	hop_timer += delta
	if is_on_floor():
		if hop_timer >= 0.7:
			hop_timer = 0.0
			velocity.y = -180.0
			velocity.x = facing_direction * chase_speed
			is_hopping = true
		else:
			velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
			is_hopping = false

func _draw() -> void:
	# Gelatinous emerald body
	var body_col = Color("#10b981") if current_state != State.HURT else Color("#ffffff")
	var wobble_y: float = -2.0 if is_hopping else 0.0
	
	# Slime base blob
	draw_circle(Vector2(0, -10 + wobble_y), 10.0, body_col)
	# Darker core nucleus
	draw_circle(Vector2(0, -10 + wobble_y), 5.0, Color("#047857"))
	# Bioluminescent eye
	draw_circle(Vector2(facing_direction * 4, -12 + wobble_y), 2.5, Color("#a7f3d0"))
	
	# Telegraph warning spark
	if is_telegraphing:
		draw_circle(Vector2(0, -26), 3.5, Color("#ef4444"))
		draw_line(Vector2(-8, -26), Vector2(8, -26), Color("#ef4444"), 2.0)
	
	# Stagger stars
	if current_state == State.STAGGER:
		draw_circle(Vector2(-5, -24), 2.0, Color("#fbbf24"))
		draw_circle(Vector2(5, -24), 2.0, Color("#fbbf24"))
