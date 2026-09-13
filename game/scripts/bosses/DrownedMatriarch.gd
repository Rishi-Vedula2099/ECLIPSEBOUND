# DrownedMatriarch.gd
# Major Boss of World 2: The Drowned Woods.
# Adaptive Focus: Dodge direction (left vs right) and distance preference.
class_name DrownedMatriarch
extends CharacterBody2D

const AttackData = preload("res://scripts/combat/AttackData.gd")
const Hitbox = preload("res://scripts/combat/Hitbox.gd")
const Hurtbox = preload("res://scripts/combat/Hurtbox.gd")
const BossPersonality = preload("res://scripts/ai/BossPersonality.gd")
const CurrentFightMemory = preload("res://scripts/ai/CurrentFightMemory.gd")
const PersistentMemoryProfile = preload("res://scripts/ai/PersistentMemoryProfile.gd")
const AdaptationBudget = preload("res://scripts/ai/AdaptationBudget.gd")
const UtilityAI = preload("res://scripts/ai/UtilityAI.gd")
const TelegraphSystem = preload("res://scripts/ai/TelegraphSystem.gd")
const FairnessEngine = preload("res://scripts/ai/FairnessEngine.gd")

enum BossPhase {
	PHASE_1_WATER_SPIRIT,
	PHASE_2_ABYSSAL_KRAKEN
}

enum BossState {
	IDLE,
	REPOSITION,
	TIDAL_CLEAVE,
	WHIRLPOOL_SURGE,
	ABYSSAL_TORRENT,
	DEPTH_SLAM,
	STAGGER,
	PHASE_TRANSITION,
	DEFEATED
}

signal boss_health_changed(current: float, max_val: float)
signal boss_phase_transition(phase: int)
signal boss_defeated()

@export var max_health: float = 1400.0
@export var defense: int = 25
@export var base_speed: float = 85.0
@export var charge_speed: float = 220.0
@export var xp_reward: float = 750.0

var current_health: float = 1400.0
var current_phase: BossPhase = BossPhase.PHASE_1_WATER_SPIRIT
var current_state: BossState = BossState.IDLE
var target_player: CharacterBody2D = null
var facing_direction: int = -1

# Attack resources
var tidal_cleave_attack: AttackData
var whirlpool_surge_attack: AttackData
var abyssal_torrent_attack: AttackData
var depth_slam_attack: AttackData

# State & adaptation
var state_timer: float = 0.0
var attack_cooldown: float = 1.6
var cooldown_timer: float = 0.0
var is_telegraphing: bool = false
var current_attack_data: AttackData = null

var adaptation_budget: int = 100
var observed_left_dodges: int = 0
var observed_right_dodges: int = 0
var observed_total_attacks: int = 0
var current_tactic: String = "Standard"

var personality: BossPersonality = null
var fight_memory: CurrentFightMemory = null
var persistent_profile: PersistentMemoryProfile = null
var budget_regulator: AdaptationBudget = null
var utility_ai: UtilityAI = null
var telegraph_system: TelegraphSystem = null
var fairness_engine: RefCounted = null

@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var float_label: Label = $FloatingText

func _ready() -> void:
	current_health = max_health
	_load_attacks()
	
	personality = BossPersonality.new(0.60, 0.70, 0.50, 0.75)
	fight_memory = CurrentFightMemory.new()
	persistent_profile = PersistentMemoryProfile.new()
	budget_regulator = AdaptationBudget.new(100)
	utility_ai = UtilityAI.new()
	telegraph_system = TelegraphSystem.new()
	fairness_engine = FairnessEngine.new()
	
	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)
		hurtbox.parry_successful.connect(_on_parried_by_player)
		hurtbox.defense_stat = defense
		hurtbox.entity_owner = self
	
	if hitbox:
		hitbox.attacker_owner = self
	
	if float_label:
		float_label.visible = false
	
	EventBus.player_dodged.connect(_on_observed_player_dodge)
	EventBus.player_attacked.connect(_on_observed_player_attack)
	EventBus.enemy_spawned.emit("drowned_matriarch", "Drowned Matriarch", global_position)
	boss_health_changed.emit(current_health, max_health)

func _load_attacks() -> void:
	if ResourceLoader.exists("res://data/attacks/boss/matriarch_tidal_cleave.tres"):
		tidal_cleave_attack = load("res://data/attacks/boss/matriarch_tidal_cleave.tres")
	if ResourceLoader.exists("res://data/attacks/boss/matriarch_whirlpool.tres"):
		whirlpool_surge_attack = load("res://data/attacks/boss/matriarch_whirlpool.tres")
	if ResourceLoader.exists("res://data/attacks/boss/matriarch_abyssal_torrent.tres"):
		abyssal_torrent_attack = load("res://data/attacks/boss/matriarch_abyssal_torrent.tres")
	if ResourceLoader.exists("res://data/attacks/boss/matriarch_depth_slam.tres"):
		depth_slam_attack = load("res://data/attacks/boss/matriarch_depth_slam.tres")

func _physics_process(delta: float) -> void:
	if current_state == BossState.DEFEATED:
		_apply_gravity(delta)
		move_and_slide()
		return
	
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
	
	if budget_regulator:
		budget_regulator.update(delta)
		adaptation_budget = budget_regulator.current_budget
	
	_locate_player()
	
	match current_state:
		BossState.IDLE:
			_process_idle(delta)
		BossState.REPOSITION:
			_process_reposition(delta)
		BossState.TIDAL_CLEAVE, BossState.WHIRLPOOL_SURGE, BossState.ABYSSAL_TORRENT, BossState.DEPTH_SLAM:
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
		BossState.TIDAL_CLEAVE:
			current_attack_data = tidal_cleave_attack
			_position_hitbox(Vector2(30.0, -20.0))
		BossState.WHIRLPOOL_SURGE:
			current_attack_data = whirlpool_surge_attack
			_position_hitbox(Vector2(0.0, -10.0))
		BossState.ABYSSAL_TORRENT:
			current_attack_data = abyssal_torrent_attack
			_position_hitbox(Vector2(45.0, -25.0))
		BossState.DEPTH_SLAM:
			current_attack_data = depth_slam_attack
			_position_hitbox(Vector2(20.0, 0.0))
		BossState.PHASE_TRANSITION:
			velocity = Vector2.ZERO
			if hurtbox: hurtbox.is_invulnerable = true
			_show_text_popup("ABYSSAL TRANSFORMATION!", Color("#38bdf8"))
			EventBus.boss_phase_changed.emit("drowned_matriarch", 2)
		BossState.DEFEATED:
			velocity = Vector2.ZERO
			if hurtbox: hurtbox.is_invulnerable = true
			boss_defeated.emit()
			EventBus.xp_gained.emit(xp_reward, xp_reward, 1)

func _process_idle(delta: float) -> void:
	state_timer += delta
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	
	if not target_player:
		return
	
	if current_phase == BossPhase.PHASE_1_WATER_SPIRIT and current_health <= (max_health * 0.50):
		current_phase = BossPhase.PHASE_2_ABYSSAL_KRAKEN
		boss_phase_transition.emit(2)
		change_boss_state(BossState.PHASE_TRANSITION)
		return
	
	if cooldown_timer <= 0.0 and state_timer >= 0.5:
		_select_adaptive_action()

func _select_adaptive_action() -> void:
	if not target_player:
		return
	
	var dist: float = global_position.distance_to(target_player.global_position)
	var total_dodges = observed_left_dodges + observed_right_dodges
	
	# Adaptive Focus: Dodge Direction & Spacing Preference
	# Tactic 1: If player rolls heavily left or right, execute wide-arc Tidal Cleave sweeping their favored exit direction
	if total_dodges >= 3 and adaptation_budget >= 15:
		var left_ratio = float(observed_left_dodges) / float(total_dodges)
		if left_ratio > 0.65 or left_ratio < 0.35:
			adaptation_budget -= 15
			current_tactic = "Counter: Direction-Predicted Tidal Wave"
			EventBus.boss_adapted.emit("drowned_matriarch", "Tidal Cleave", "Player dodge direction bias (left ratio %.2f)" % left_ratio)
			change_boss_state(BossState.TIDAL_CLEAVE)
			return
	
	# Tactic 2: If player is kiting at long range (>120px), trigger Abyssal Torrent
	if dist > 120.0 and adaptation_budget >= 20 and current_phase == BossPhase.PHASE_2_ABYSSAL_KRAKEN:
		adaptation_budget -= 20
		current_tactic = "Counter: Anti-Kite Abyssal Torrent"
		EventBus.boss_adapted.emit("drowned_matriarch", "Abyssal Torrent", "Player distance preference (dist %.1f)" % dist)
		change_boss_state(BossState.ABYSSAL_TORRENT)
		return
	
	# Close range options
	if dist <= 70.0:
		if randf() < 0.5:
			change_boss_state(BossState.WHIRLPOOL_SURGE)
		else:
			change_boss_state(BossState.DEPTH_SLAM)
		return
	
	change_boss_state(BossState.REPOSITION)

func _process_reposition(delta: float) -> void:
	state_timer += delta
	if not target_player:
		change_boss_state(BossState.IDLE)
		return
	
	var dist: float = global_position.distance_to(target_player.global_position)
	var speed = base_speed * (1.30 if current_phase == BossPhase.PHASE_2_ABYSSAL_KRAKEN else 1.0)
	velocity.x = facing_direction * speed
	if dist <= 65.0 or state_timer >= 2.0:
		change_boss_state(BossState.IDLE)

func _process_attack(delta: float) -> void:
	state_timer += delta
	if not current_attack_data:
		change_boss_state(BossState.IDLE)
		return
	
	var startup = current_attack_data.startup_time
	var active = current_attack_data.active_time
	var recovery = current_attack_data.recovery_time
	
	if state_timer < startup:
		is_telegraphing = true
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		if hitbox: hitbox.deactivate()
	elif state_timer >= startup and state_timer < (startup + active):
		is_telegraphing = false
		if hitbox and not hitbox._is_active:
			hitbox.activate(current_attack_data)
			if current_state == BossState.DEPTH_SLAM:
				velocity.x = facing_direction * charge_speed
	elif state_timer >= (startup + active) and state_timer < (startup + active + recovery):
		if hitbox: hitbox.deactivate()
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	else:
		if hitbox: hitbox.deactivate()
		cooldown_timer = attack_cooldown * (0.80 if current_phase == BossPhase.PHASE_2_ABYSSAL_KRAKEN else 1.0)
		change_boss_state(BossState.IDLE)

func _process_phase_transition(delta: float) -> void:
	state_timer += delta
	velocity = Vector2.ZERO
	if state_timer >= 2.0:
		if hurtbox: hurtbox.is_invulnerable = false
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
		if dir != 0.0:
			facing_direction = int(dir)

func _on_damage_received(incoming: AttackData, _pos: Vector2, result: Dictionary) -> void:
	if current_state == BossState.DEFEATED:
		return
	var dmg: float = result.get("final_damage", 10.0)
	var is_crit: bool = result.get("is_critical", false)
	var effect: String = result.get("status_effect", "None")
	
	current_health = max(0.0, current_health - dmg)
	boss_health_changed.emit(current_health, max_health)
	_show_damage_popup(dmg, is_crit, effect)
	if current_health <= 0.0:
		change_boss_state(BossState.DEFEATED)

func _on_parried_by_player(_incoming: AttackData, is_perfect: bool, _hitbox_node: Area2D) -> void:
	if is_perfect:
		_show_text_popup("PERFECT PARRY!", Color("#00f5d4"))
		change_boss_state(BossState.STAGGER)
	else:
		_show_text_popup("PARRIED!", Color("#38bdf8"))

func _on_observed_player_dodge(dir: Vector2, _perfect: bool) -> void:
	if dir.x < 0:
		observed_left_dodges += 1
	else:
		observed_right_dodges += 1
	if fight_memory:
		fight_memory.record_event("dodge", {"direction": "left" if dir.x < 0 else "right"})

func _on_observed_player_attack(_weapon: String, type: String, _pos: Vector2) -> void:
	observed_total_attacks += 1
	if fight_memory:
		fight_memory.record_event(type if type != "" else "attack_light")

func _position_hitbox(offset_pos: Vector2) -> void:
	if hitbox:
		hitbox.position = Vector2(facing_direction * offset_pos.x, offset_pos.y)

func _show_damage_popup(amount: float, is_crit: bool, effect: String) -> void:
	var msg = str(amount)
	if is_crit: msg += " CRIT!"
	if effect != "None" and effect != "": msg += " [" + effect + "]"
	_show_text_popup(msg, Color("#ff3860") if is_crit else Color("#38bdf8"))

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
	var is_phase_2 = (current_phase == BossPhase.PHASE_2_ABYSSAL_KRAKEN)
	var body_col = Color("#0f3044") if not is_phase_2 else Color("#09182b")
	var highlight_col = Color("#38bdf8") if not is_phase_2 else Color("#0284c7")
	
	if current_state == BossState.DEFEATED:
		draw_rect(Rect2(-25, -5, 50, 10), Color(body_col, 0.5))
		return
	
	# Sunken Siren Body
	draw_rect(Rect2(-20, -38, 40, 32), body_col)
	draw_circle(Vector2(facing_direction * 10, -22), 7.0, highlight_col)
	
	# Ghostly Water Robes / Tentacles
	draw_line(Vector2(-16, -6), Vector2(-22, 16), body_col.lightened(0.1), 4.0)
	draw_line(Vector2(0, -6), Vector2(0, 18), body_col.lightened(0.1), 4.0)
	draw_line(Vector2(16, -6), Vector2(22, 16), body_col.lightened(0.1), 4.0)
	
	# Head & Veil
	draw_rect(Rect2(facing_direction * 14, -50, 16, 16), body_col)
	draw_circle(Vector2(facing_direction * 22, -42), 2.5, Color("#67e8f9"))
	
	# Phase 2 Tentacle Aura
	if is_phase_2:
		draw_arc(Vector2(0, -24), 40.0, -2.0, 2.0, 14, Color("#0284c7", 0.5), 3.0)
	
	# Telegraph Warning
	if is_telegraphing:
		draw_circle(Vector2(0, -66), 6.0, Color("#ef4444"))
		draw_arc(Vector2(0, -24), 34.0, 0.0, TAU, 16, Color("#ef4444", 0.8), 2.5)
