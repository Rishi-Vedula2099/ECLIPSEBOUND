# TheDreamEater.gd
# Major Boss of World 6: The Forgotten Dream.
# Adaptive Focus: Movement timing, dash cadence, and ability rhythms.
class_name TheDreamEater
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
	PHASE_1_DREAM_WEAVER,
	PHASE_2_LUCID_NIGHTMARE
}

enum BossState {
	IDLE,
	REPOSITION,
	MIRAGE_STRIKE,
	REALITY_TEAR,
	NIGHTMARE_SPIKES,
	LUCIDITY_COLLAPSE,
	STAGGER,
	PHASE_TRANSITION,
	DEFEATED
}

signal boss_health_changed(current: float, max_val: float)
signal boss_phase_transition(phase: int)
signal boss_defeated()

@export var max_health: float = 4800.0
@export var defense: int = 50
@export var base_speed: float = 100.0
@export var charge_speed: float = 260.0
@export var xp_reward: float = 2600.0

var current_health: float = 4800.0
var current_phase: BossPhase = BossPhase.PHASE_1_DREAM_WEAVER
var current_state: BossState = BossState.IDLE
var target_player: CharacterBody2D = null
var facing_direction: int = -1

# Attack resources
var mirage_strike_attack: AttackData
var reality_tear_attack: AttackData
var nightmare_spikes_attack: AttackData
var lucidity_collapse_attack: AttackData

# State & adaptation
var state_timer: float = 0.0
var attack_cooldown: float = 1.4
var cooldown_timer: float = 0.0
var is_telegraphing: bool = false
var current_attack_data: AttackData = null

var adaptation_budget: int = 100
var observed_player_dash_intervals: Array[float] = []
var last_player_dash_timestamp: float = 0.0
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
	
	personality = BossPersonality.new(0.85, 0.75, 0.80, 0.90)
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
	EventBus.enemy_spawned.emit("the_dream_eater", "The Dream Eater", global_position)
	boss_health_changed.emit(current_health, max_health)

func _load_attacks() -> void:
	if ResourceLoader.exists("res://data/attacks/boss/dream_mirage_strike.tres"):
		mirage_strike_attack = load("res://data/attacks/boss/dream_mirage_strike.tres")
	if ResourceLoader.exists("res://data/attacks/boss/dream_reality_tear.tres"):
		reality_tear_attack = load("res://data/attacks/boss/dream_reality_tear.tres")
	if ResourceLoader.exists("res://data/attacks/boss/dream_nightmare_spikes.tres"):
		nightmare_spikes_attack = load("res://data/attacks/boss/dream_nightmare_spikes.tres")
	if ResourceLoader.exists("res://data/attacks/boss/dream_lucidity_collapse.tres"):
		lucidity_collapse_attack = load("res://data/attacks/boss/dream_lucidity_collapse.tres")

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
		BossState.MIRAGE_STRIKE, BossState.REALITY_TEAR, BossState.NIGHTMARE_SPIKES, BossState.LUCIDITY_COLLAPSE:
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
		BossState.MIRAGE_STRIKE:
			current_attack_data = mirage_strike_attack
			_position_hitbox(Vector2(32.0, -18.0))
		BossState.REALITY_TEAR:
			current_attack_data = reality_tear_attack
			_position_hitbox(Vector2(45.0, -22.0))
		BossState.NIGHTMARE_SPIKES:
			current_attack_data = nightmare_spikes_attack
			_position_hitbox(Vector2(0.0, 0.0))
		BossState.LUCIDITY_COLLAPSE:
			current_attack_data = lucidity_collapse_attack
			_position_hitbox(Vector2(40.0, -20.0))
		BossState.PHASE_TRANSITION:
			velocity = Vector2.ZERO
			if hurtbox: hurtbox.is_invulnerable = true
			_show_text_popup("NIGHTMARE AWAKENING!", Color("#c084fc"))
			EventBus.boss_phase_changed.emit("the_dream_eater", 2)
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
	
	if current_phase == BossPhase.PHASE_1_DREAM_WEAVER and current_health <= (max_health * 0.50):
		current_phase = BossPhase.PHASE_2_LUCID_NIGHTMARE
		boss_phase_transition.emit(2)
		change_boss_state(BossState.PHASE_TRANSITION)
		return
	
	if cooldown_timer <= 0.0 and state_timer >= 0.45:
		_select_adaptive_action()

func _select_adaptive_action() -> void:
	if not target_player:
		return
	
	var dist: float = global_position.distance_to(target_player.global_position)
	
	# Adaptive Focus: Movement timing & ability rhythms
	# Tactic 1: If player dodges rhythmically, strike precisely at end of i-frame window with Mirage Strike (15 pts)
	if observed_player_dash_intervals.size() >= 2 and adaptation_budget >= 15:
		adaptation_budget -= 15
		current_tactic = "Counter: Dash Recovery Window Strike"
		EventBus.boss_adapted.emit("the_dream_eater", "Mirage Strike", "Player dash cadence rhythmic predictability")
		change_boss_state(BossState.MIRAGE_STRIKE)
		return
	
	# Tactic 2: If in Phase 2 and player is keeping distance, trigger Lucidity Collapse (20 pts)
	if current_phase == BossPhase.PHASE_2_LUCID_NIGHTMARE and dist > 90.0 and adaptation_budget >= 20:
		adaptation_budget -= 20
		current_tactic = "Counter: Lucidity Collapse Reality Rift"
		EventBus.boss_adapted.emit("the_dream_eater", "Lucidity Collapse", "Punishing kiting during nightmare phase")
		change_boss_state(BossState.LUCIDITY_COLLAPSE)
		return
	
	if dist <= 65.0:
		change_boss_state(BossState.NIGHTMARE_SPIKES)
		return
	
	if dist > 85.0:
		change_boss_state(BossState.REALITY_TEAR)
		return
	
	change_boss_state(BossState.REPOSITION)

func _process_reposition(delta: float) -> void:
	state_timer += delta
	if not target_player:
		change_boss_state(BossState.IDLE)
		return
	
	var dist: float = global_position.distance_to(target_player.global_position)
	var speed = base_speed * (1.30 if current_phase == BossPhase.PHASE_2_LUCID_NIGHTMARE else 1.0)
	velocity.x = facing_direction * speed
	if dist <= 60.0 or state_timer >= 1.8:
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
			if current_state == BossState.MIRAGE_STRIKE:
				velocity.x = facing_direction * charge_speed
	elif state_timer >= (startup + active) and state_timer < (startup + active + recovery):
		if hitbox: hitbox.deactivate()
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	else:
		if hitbox: hitbox.deactivate()
		cooldown_timer = attack_cooldown * (0.75 if current_phase == BossPhase.PHASE_2_LUCID_NIGHTMARE else 1.0)
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
		_show_text_popup("PARRIED!", Color("#c084fc"))

func _on_observed_player_dodge(_dir: Vector2, _perfect: bool) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	if last_player_dash_timestamp > 0.0:
		var interval = now - last_player_dash_timestamp
		observed_player_dash_intervals.append(interval)
		if observed_player_dash_intervals.size() > 6:
			observed_player_dash_intervals.pop_front()
	last_player_dash_timestamp = now

func _position_hitbox(offset_pos: Vector2) -> void:
	if hitbox:
		hitbox.position = Vector2(facing_direction * offset_pos.x, offset_pos.y)

func _show_damage_popup(amount: float, is_crit: bool, effect: String) -> void:
	var msg = str(amount)
	if is_crit: msg += " CRIT!"
	if effect != "None" and effect != "": msg += " [" + effect + "]"
	_show_text_popup(msg, Color("#ff1744") if is_crit else Color("#c084fc"))

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
	var is_phase_2 = (current_phase == BossPhase.PHASE_2_LUCID_NIGHTMARE)
	var dream_col = Color("#3b0764") if not is_phase_2 else Color("#18022b")
	var rune_col = Color("#c084fc") if not is_phase_2 else Color("#f43f5e")
	
	if current_state == BossState.DEFEATED:
		draw_rect(Rect2(-24, -5, 48, 10), Color(dream_col, 0.5))
		return
	
	# Phantasmal Floating Cloak
	draw_rect(Rect2(-22, -42, 44, 36), dream_col)
	draw_circle(Vector2(facing_direction * 8, -25), 8.0, rune_col)
	
	# Shifting Illusion Horns
	draw_line(Vector2(facing_direction * 14, -52), Vector2(facing_direction * 26, -70), rune_col, 3.0)
	draw_line(Vector2(facing_direction * 22, -52), Vector2(facing_direction * 34, -68), rune_col, 2.5)
	
	# Ethereal Tendrils
	draw_line(Vector2(-12, -6), Vector2(-18, 14), dream_col.lightened(0.2), 3.0)
	draw_line(Vector2(12, -6), Vector2(18, 14), dream_col.lightened(0.2), 3.0)
	
	# Phase 2 Reality Distortion Halo
	if is_phase_2:
		draw_arc(Vector2(0, -25), 44.0, 0.0, TAU, 18, Color("#f43f5e", 0.5), 2.5)
	
	# Telegraph Warning
	if is_telegraphing:
		draw_circle(Vector2(0, -74), 6.0, Color("#ef4444"))
		draw_arc(Vector2(0, -25), 36.0, 0.0, TAU, 16, Color("#ef4444", 0.8), 2.5)
