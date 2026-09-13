# ElderRootBeast.gd
# Miniboss guarding the entrance to the Hollow Stag's grove.
# Features ground stomps, high poise, and living root spikes.
class_name ElderRootBeast
extends "res://scripts/enemies/BaseEnemy.gd"

signal miniboss_defeated()

func _ready() -> void:
	enemy_id = "elder_root_beast"
	enemy_name = "Elder Root Beast"
	max_health = 320.0
	defense = 16
	move_speed = 55.0
	chase_speed = 80.0
	xp_reward = 150.0
	max_poise = 80.0
	detection_radius = 280.0
	attack_range = 54.0
	attack_cooldown = 2.0
	
	if not default_attack_data and ResourceLoader.exists("res://data/attacks/enemies/miniboss_stomp.tres"):
		default_attack_data = load("res://data/attacks/enemies/miniboss_stomp.tres")
	
	super._ready()

func _setup_utility_actions() -> void:
	# Action 1: Seismic Stomp (close shockwave)
	var stomp_action = UtilityAction.new("Seismic_Stomp", 1.6, attack_cooldown)
	stomp_action.add_consideration(func(ctx):
		var dist = ctx.get("distance", 999.0)
		return UtilityAI.curve_inverse_linear(dist, 0.0, 60.0)
	)
	utility_ai.add_action(stomp_action)
	
	# Action 2: Heavy Cleave (crushing melee sweep)
	var sweep_action = UtilityAction.new("Root_Sweep", 1.2, 1.5)
	sweep_action.add_consideration(func(ctx):
		var dist = ctx.get("distance", 999.0)
		return UtilityAI.curve_bell(dist, 40.0, 25.0)
	)
	utility_ai.add_action(sweep_action)

func _on_death() -> void:
	miniboss_defeated.emit()
	super._on_death()

func _draw() -> void:
	var col = Color("#292524") if current_state != State.HURT else Color("#ffffff")
	var root_col = Color("#854d0e")
	
	# Massive quad root beast body
	draw_rect(Rect2(-24, -28, 48, 24), col)
	# Knotted roots along back
	draw_line(Vector2(-18, -32), Vector2(-12, -28), root_col, 3.5)
	draw_line(Vector2(-6, -35), Vector2(0, -28), root_col, 4.0)
	draw_line(Vector2(6, -33), Vector2(14, -28), root_col, 3.5)
	
	# Massive wooden limbs
	draw_rect(Rect2(-20, -4, 8, 12), root_col)
	draw_rect(Rect2(12, -4, 8, 12), root_col)
	
	# Glowing Amber Horns
	draw_line(Vector2(facing_direction * 18, -28), Vector2(facing_direction * 30, -42), Color("#f59e0b"), 3.5)
	
	# Telegraph Warning
	if is_telegraphing:
		draw_circle(Vector2(0, -44), 5.0, Color("#ef4444"))
		draw_line(Vector2(-18, -44), Vector2(18, -44), Color("#ef4444"), 3.0)
	
	# Stagger Stars
	if current_state == State.STAGGER:
		draw_circle(Vector2(-10, -42), 3.0, Color("#fbbf24"))
		draw_circle(Vector2(10, -42), 3.0, Color("#fbbf24"))
