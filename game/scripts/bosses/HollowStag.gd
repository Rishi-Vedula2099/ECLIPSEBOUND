# HollowStag.gd
# Major Boss of World 1: The Verdant March.
# Implements multi-phase behavior, telegraph discipline, and 100-point fairness budget adaptation.
class_name HollowStag
extends CharacterBody2D

const AttackData = preload("res://scripts/combat/AttackData.gd")
const Hitbox = preload("res://scripts/combat/Hitbox.gd")
const Hurtbox = preload("res://scripts/combat/Hurtbox.gd")

enum BossPhase {
	PHASE_1_FOREST_DEITY,
	PHASE_2_CORRUPTED_ECLIPSE
}

enum BossState {
	INTRO,
	IDLE,
	REPOSITION,
	ANTLER_SWEEP,
	GALLOP_CHARGE,
	ROOT_ERUPTION,
	ECLIPSE_BEAM,
	STAGGER,
	PHASE_TRANSITION,
	DEFEATED
}

signal boss_health_changed(current: float, max_val: float)
signal boss_phase_transition(phase: int)
signal boss_defeated()

@export var max_health: float = 900.0
@export var defense: int = 20
@export var base_speed: float = 90.0
@export var charge_speed: float = 240.0
@export var xp_reward: float = 500.0

var current_health: float = 900.0
var current_phase: BossPhase = BossPhase.PHASE_1_FOREST_DEITY
var current_state: BossState = BossState.IDLE
var target_player: CharacterBody2D = null
var facing_direction: int = -1

# Attack resources
var antler_sweep_attack: AttackData
var gallop_charge_attack: AttackData
var root_eruption_attack: AttackData
var eclipse_beam_attack: AttackData

# State timers
var state_timer: float = 0.0
var attack_cooldown: float = 1.6
var cooldown_timer: float = 0.0
var is_telegraphing: bool = false
var current_attack_data: AttackData = null

# --- 100-Point Adaptive Fairness Engine ---
var adaptation_budget: int = 100
var observed_player_parries: int = 0
var observed_player_dodges: int = 0
var observed_player_attacks: int = 0
var current_tactic: String = "Standard"

@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var float_label: Label = $FloatingText

func _ready() -> void:
	current_health = max_health
	_load_attack_resources()
	
	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)
		hurtbox.parry_successful.connect(_on_parried_by_player)
		hurtbox.defense_stat = defense
		hurtbox.entity_owner = self
	
	if hitbox:
		hitbox.attacker_owner = self
	
	if float_label:
		float_label.visible = false
	
	# Connect to player actions for behavioral fingerprinting
	EventBus.player_parried.connect(_on_observed_player_parry)
	EventBus.player_dodged.connect(_on_observed_player_dodge)
	EventBus.player_attacked.connect(_on_observed_player_attack)
	
	EventBus.enemy_spawned.emit("hollow_stag", "The Hollow Stag", global_position)
	boss_health_changed.emit(current_health, max_health)

func _load_attack_resources() -> void:
	if ResourceLoader.exists("res://data/attacks/boss/stag_antler_sweep.tres"):
		antler_sweep_attack = load("res://data/attacks/boss/stag_antler_sweep.tres")
	if ResourceLoader.exists("res://data/attacks/boss/stag_gallop_charge.tres"):
		gallop_charge_attack = load("res://data/attacks/boss/stag_gallop_charge.tres")
	if ResourceLoader.exists("res://data/attacks/boss/stag_root_eruption.tres"):
		root_eruption_attack = load("res://data/attacks/boss/stag_root_eruption.tres")
	if ResourceLoader.exists("res://data/attacks/boss/stag_eclipse_beam.tres"):
		eclipse_beam_attack = load("res://data/attacks/boss/stag_eclipse_beam.tres")

func _physics_process(delta: float) -> void:
	if current_state == BossState.DEFEATED:
		_apply_gravity(delta)
		move_and_slide()
		return
	
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
	
	_locate_player()
	
	match current_state:
		BossState.IDLE:
			_process_idle(delta)
		BossState.REPOSITION:
			_process_reposition(delta)
		BossState.ANTLER_SWEEP, BossState.GALLOP_CHARGE, BossState.ROOT_ERUPTION, BossState.ECLIPSE_BEAM:
			_process_attack(delta)
		BossState.PHASE_TRANSITION:
			_process_phase_transition(delta)
		BossState.STAGGER:
			_process_stagger(delta)
	
	_apply_gravity(delta)
	move_and_slide()
	_update_orientation()
	queue_redraw()

func change_boss_state(new_state: BossState) -> void:
	current_state = new_state
	state_timer = 0.0
	
	if hitbox:
		hitbox.deactivate()
	is_telegraphing = false
	
	match new_state:
		BossState.IDLE:
			velocity.x = 0.0
		BossState.ANTLER_SWEEP:
			current_attack_data = antler_sweep_attack
			_position_hitbox(Vector2(28.0, -20.0))
		BossState.GALLOP_CHARGE:
			current_attack_data = gallop_charge_attack
			_position_hitbox(Vector2(32.0, -16.0))
		BossState.ROOT_ERUPTION:
			current_attack_data = root_eruption_attack
			_position_hitbox(Vector2(20.0, -10.0))
		BossState.ECLIPSE_BEAM:
			current_attack_data = eclipse_beam_attack
			_position_hitbox(Vector2(45.0, -22.0))
		BossState.PHASE_TRANSITION:
			velocity = Vector2.ZERO
			if hurtbox:
				hurtbox.is_invulnerable = true
			_show_text_popup("ECLIPSE AWAKENING!", Color("#a855f7"))
			EventBus.boss_phase_changed.emit("hollow_stag", 2)
		BossState.DEFEATED:
			velocity = Vector2.ZERO
			if hurtbox:
				hurtbox.is_invulnerable = true
			boss_defeated.emit()
			EventBus.xp_gained.emit(xp_reward, xp_reward, 1)

func _process_idle(delta: float) -> void:
	state_timer += delta
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	
	if not target_player:
		return
	
	# Check for Phase 2 HP trigger (50%)
	if current_phase == BossPhase.PHASE_1_FOREST_DEITY and current_health <= (max_health * 0.50):
		current_phase = BossPhase.PHASE_2_CORRUPTED_ECLIPSE
		boss_phase_transition.emit(2)
		change_boss_state(BossState.PHASE_TRANSITION)
		return
	
	# Select next tactical action when cooldown expires
	if cooldown_timer <= 0.0 and state_timer >= 0.5:
		_select_tactical_action()

func _select_tactical_action() -> void:
	if not target_player:
		return
	
	var dist: float = global_position.distance_to(target_player.global_position)
	
	# --- 100-Point Adaptive Budget Evaluation ---
	var parry_ratio: float = float(observed_player_parries) / max(1.0, float(observed_player_attacks))
	var dodge_ratio: float = float(observed_player_dodges) / max(1.0, float(observed_player_attacks))
	
	# Adaptation Tactic 1: Attack Counter (20 pts)
	# If player relies heavily on parrying (>40% parry ratio) and in Phase 2, use unparryable Eclipse Beam
	if parry_ratio > 0.40 and current_phase == BossPhase.PHASE_2_CORRUPTED_ECLIPSE and adaptation_budget >= 20:
		adaptation_budget -= 20
		current_tactic = "Counter: Unparryable Eclipse Beam"
		EventBus.boss_adapted.emit("hollow_stag", "Eclipse Beam", "Player exhibits high parry frequency (%.2f)" % parry_ratio)
		change_boss_state(BossState.ECLIPSE_BEAM)
		return
	
	# Adaptation Tactic 2: Position Prediction (15 pts)
	# If player maintains distance or frequently dodges away, execute Galloping Charge
	if (dist > 110.0 or dodge_ratio > 0.50) and adaptation_budget >= 15:
		adaptation_budget -= 15
		current_tactic = "Position: Gallop Gap-Closer"
		EventBus.boss_adapted.emit("hollow_stag", "Gallop Charge", "Player spacing preference (dist %.1f)" % dist)
		change_boss_state(BossState.GALLOP_CHARGE)
		return
	
	# Adaptation Tactic 3: Pattern Recognition (20 pts)
	# If player is in close melee range, alternate Antler Sweep or Root Eruption
	if dist <= 75.0:
		if randf() < 0.55:
			change_boss_state(BossState.ANTLER_SWEEP)
		else:
			change_boss_state(BossState.ROOT_ERUPTION)
		return
	
	# Default fallback: Reposition toward player
	change_boss_state(BossState.REPOSITION)

func _process_reposition(delta: float) -> void:
	state_timer += delta
	if not target_player:
		change_boss_state(BossState.IDLE)
		return
	
	var dist: float = global_position.distance_to(target_player.global_position)
	var speed = base_speed * (1.35 if current_phase == BossPhase.PHASE_2_CORRUPTED_ECLIPSE else 1.0)
	velocity.x = facing_direction * speed
	
	if dist <= 65.0 or state_timer >= 2.0:
		change_boss_state(BossState.IDLE)

func _process_attack(delta: float) -> void:
	state_timer += delta
	if not current_attack_data:
		change_boss_state(BossState.IDLE)
		return
	
	var startup: float = current_attack_data.startup_time
	var active: float = current_attack_data.active_time
	var recovery: float = current_attack_data.recovery_time
	
	# 1. Startup & Authored Telegraph (>= 350ms rule)
	if state_timer < startup:
		is_telegraphing = true
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		if hitbox:
			hitbox.deactivate()
	# 2. Active Hit Window
	elif state_timer >= startup and state_timer < (startup + active):
		is_telegraphing = false
		if hitbox and not hitbox._is_active:
			hitbox.activate(current_attack_data)
			# Movement burst during gallop charge
			if current_state == BossState.GALLOP_CHARGE:
				velocity.x = facing_direction * charge_speed
	# 3. Recovery Phase
	elif state_timer >= (startup + active) and state_timer < (startup + active + recovery):
		if hitbox:
			hitbox.deactivate()
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	# 4. Attack Complete
	else:
		if hitbox:
			hitbox.deactivate()
		cooldown_timer = attack_cooldown * (0.75 if current_phase == BossPhase.PHASE_2_CORRUPTED_ECLIPSE else 1.0)
		change_boss_state(BossState.IDLE)

func _process_phase_transition(delta: float) -> void:
	state_timer += delta
	velocity = Vector2.ZERO
	if state_timer >= 2.0:
		if hurtbox:
			hurtbox.is_invulnerable = false
		# Replenish adaptation budget for Phase 2
		adaptation_budget = 100
		change_boss_state(BossState.IDLE)

func _process_stagger(delta: float) -> void:
	state_timer += delta
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	if state_timer >= 1.5:
		change_boss_state(BossState.IDLE)

func _locate_player() -> void:
	if not target_player or not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target_player = players[0]
	
	if target_player and is_instance_valid(target_player):
		var dir = sign(target_player.global_position.x - global_position.x)
		if dir != 0.0 and current_state != BossState.GALLOP_CHARGE:
			facing_direction = int(dir)

func _on_damage_received(incoming: AttackData, _attacker_pos: Vector2, result: Dictionary) -> void:
	if current_state == BossState.DEFEATED:
		return
	
	var dmg: float = result.get("final_damage", 10.0)
	var is_crit: bool = result.get("is_critical", false)
	var effect: String = result.get("status_effect", "None")
	
	current_health = max(0.0, current_health - dmg)
	boss_health_changed.emit(current_health, max_health)
	
	if effect != "None" and effect != "":
		CombatSystem.apply_status_effect(self, effect, result.get("status_duration", 3.0), result.get("status_potency", 5.0))
	
	_show_damage_popup(dmg, is_crit, effect)
	
	if current_health <= 0.0:
		change_boss_state(BossState.DEFEATED)

func _on_parried_by_player(_incoming: AttackData, is_perfect: bool, _hitbox_node: Area2D) -> void:
	observed_player_parries += 1
	if is_perfect:
		_show_text_popup("PERFECT PARRY!", Color("#00f5d4"))
		change_boss_state(BossState.STAGGER)
	else:
		_show_text_popup("PARRIED!", Color("#38bdf8"))

func _on_observed_player_parry(_target: String, is_perfect: bool) -> void:
	observed_player_parries += (2 if is_perfect else 1)

func _on_observed_player_dodge(_dir: Vector2, _perfect: bool) -> void:
	observed_player_dodges += 1

func _on_observed_player_attack(_weapon: String, _type: String, _pos: Vector2) -> void:
	observed_player_attacks += 1

func _position_hitbox(offset_pos: Vector2) -> void:
	if hitbox:
		hitbox.position = Vector2(facing_direction * offset_pos.x, offset_pos.y)

func _show_damage_popup(amount: float, is_crit: bool, effect: String) -> void:
	var msg = str(amount)
	if is_crit:
		msg += " CRIT!"
	if effect != "None" and effect != "":
		msg += " [" + effect + "]"
	_show_text_popup(msg, Color("#ff3860") if is_crit else Color("#fbbf24"))

func _show_text_popup(msg: String, col: Color) -> void:
	if float_label:
		float_label.text = msg
		float_label.modulate = col
		float_label.visible = true
		float_label.position.y = -65.0
		var tween = create_tween()
		tween.tween_property(float_label, "position:y", -80.0, 0.6)
		tween.tween_callback(func(): if is_instance_valid(float_label): float_label.visible = false)

func _apply_gravity(delta: float) -> void:
	var grav: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
	velocity.y = min(velocity.y + grav * delta, 600.0)

func _update_orientation() -> void:
	if facing_direction != 0:
		scale.x = abs(scale.x) * facing_direction

func _draw() -> void:
	var is_phase_2 = (current_phase == BossPhase.PHASE_2_CORRUPTED_ECLIPSE)
	var body_col = Color("#382923") if not is_phase_2 else Color("#1e1028")
	var antler_col = Color("#eab308") if not is_phase_2 else Color("#c084fc")
	
	if current_state == BossState.DEFEATED:
		draw_rect(Rect2(-30, -10, 60, 10), Color(body_col, 0.5))
		return
	
	# Stag Torso & Shoulders
	draw_rect(Rect2(-26, -34, 52, 28), body_col)
	# Chest Fur & Rune Core
	draw_circle(Vector2(facing_direction * 14, -20), 8.0, Color("#16a34a") if not is_phase_2 else Color("#9333ea"))
	
	# Slender Hooved Legs
	draw_rect(Rect2(-20, -6, 6, 20), body_col.darkened(0.2))
	draw_rect(Rect2(14, -6, 6, 20), body_col.darkened(0.2))
	
	# Majestic Head & Eyes
	draw_rect(Rect2(facing_direction * 22, -44, 16, 18), body_col)
	draw_circle(Vector2(facing_direction * 30, -36), 3.0, Color("#fef08a") if not is_phase_2 else Color("#ff0055"))
	
	# Grand Antler Crown
	draw_line(Vector2(facing_direction * 24, -44), Vector2(facing_direction * 36, -68), antler_col, 3.5)
	draw_line(Vector2(facing_direction * 30, -56), Vector2(facing_direction * 42, -58), antler_col, 2.5)
	draw_line(Vector2(facing_direction * 34, -62), Vector2(facing_direction * 46, -72), antler_col, 2.5)
	
	# Phase 2 Eclipse Aura
	if is_phase_2:
		draw_arc(Vector2(0, -24), 38.0, -1.5, 1.5, 12, Color("#a855f7", 0.4), 2.0)
	
	# Telegraph Warning Ring (Min 350ms rule)
	if is_telegraphing:
		draw_circle(Vector2(0, -62), 6.0, Color("#ef4444"))
		draw_arc(Vector2(0, -20), 32.0, 0.0, TAU, 16, Color("#ef4444", 0.8), 2.5)
