# VerdantGuardianElite.gd
# Elite armored sentry with frontal shield guard stance and heavy sweeping cleave.
class_name VerdantGuardianElite
extends "res://scripts/enemies/BaseEnemy.gd"

@export var is_shielding: bool = false
var shield_timer: float = 0.0

func _ready() -> void:
	enemy_id = "verdant_guardian_elite"
	enemy_name = "Verdant Guardian Elite"
	max_health = 180.0
	defense = 22
	move_speed = 40.0
	chase_speed = 60.0
	xp_reward = 80.0
	max_poise = 60.0
	detection_radius = 240.0
	attack_range = 48.0
	attack_cooldown = 2.4
	
	if not default_attack_data and ResourceLoader.exists("res://data/attacks/enemies/elite_cleave.tres"):
		default_attack_data = load("res://data/attacks/enemies/elite_cleave.tres")
	
	super._ready()

func _process_chase(delta: float) -> void:
	# Periodically raise tower shield while approaching
	shield_timer += delta
	is_shielding = (fmod(shield_timer, 4.0) < 2.0)
	super._process_chase(delta)

func _on_damage_received(incoming_attack: AttackData, attacker_pos: Vector2, result: Dictionary) -> void:
	# Frontal guard blocks non-guard-breaking attacks
	var attacker_is_in_front = (sign(attacker_pos.x - global_position.x) == facing_direction)
	if is_shielding and attacker_is_in_front and not incoming_attack.breaks_guard:
		_show_text_popup("GUARD BLOCKED!", Color("#38bdf8"))
		# Minor poise reduction only
		current_poise -= 10.0
		if current_poise <= 0.0:
			is_shielding = false
			is_staggered = true
			change_state(State.STAGGER)
		return
	
	super._on_damage_received(incoming_attack, attacker_pos, result)

func _draw() -> void:
	var stone_col = Color("#475569") if current_state != State.HURT else Color("#ffffff")
	var moss_col = Color("#15803d")
	
	# Heavy stone body
	draw_rect(Rect2(-12, -32, 24, 32), stone_col)
	# Moss patches
	draw_rect(Rect2(-10, -28, 8, 8), moss_col)
	draw_rect(Rect2(2, -18, 8, 6), moss_col)
	
	# Glowing runic eye
	draw_circle(Vector2(facing_direction * 6, -24), 3.0, Color("#38bdf8"))
	
	# Tower Shield (when active)
	if is_shielding:
		var shield_x = facing_direction * 14
		draw_rect(Rect2(shield_x - 3, -36, 6, 36), Color("#0284c7"))
		draw_line(Vector2(shield_x, -36), Vector2(shield_x, 0), Color("#e0f2fe"), 2.0)
	
	# Massive Greatsword
	draw_line(Vector2(-facing_direction * 8, -34), Vector2(facing_direction * 16, -10), Color("#94a3b8"), 3.0)
	
	# Telegraph Warning
	if is_telegraphing:
		draw_circle(Vector2(0, -42), 4.5, Color("#ff0055"))
		draw_line(Vector2(-12, -42), Vector2(12, -42), Color("#ff0055"), 2.5)
	
	# Stagger Stars
	if current_state == State.STAGGER:
		draw_circle(Vector2(-6, -40), 3.0, Color("#fbbf24"))
		draw_circle(Vector2(6, -40), 3.0, Color("#fbbf24"))
