# NullBoss.gd
# Major Boss of World 7: The NULL Realm.
# Adaptive Focus: Complete campaign memory integration synthesizing all 6 worlds' adaptations.
class_name NullBoss
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
	PHASE_1_ANOMALY,
	PHASE_2_ENTROPIC_COLLAPSE
}

enum BossState {
	IDLE,
	REPOSITION,
	GLITCH_STRIKE,
	MEMORY_ECHO,
	VOID_SINGULARITY,
	EXECUTION_ERROR,
	STAGGER,
	PHASE_TRANSITION,
	DEFEATED
}

signal boss_health_changed(current: float, max_val: float)
signal boss_phase_transition(phase: int)
signal boss_defeated()

@export var max_health: float = 6500.0
@export var defense: int = 60
@export var base_speed: float = 110.0
@export var charge_speed: float = 280.0
@export var xp_reward: float = 3500.0

var current_health: float = 6500.0
var current_phase: BossPhase = BossPhase.PHASE_1_ANOMALY
var current_state: BossState = BossState.IDLE
var target_player: CharacterBody2D = null
var facing_direction: int = -1

# Attack resources
var glitch_strike_attack: AttackData
var memory_echo_attack: AttackData
var void_singularity_attack: AttackData
var execution_error_attack: AttackData

# State & adaptation
var state_timer: float = 0.0
var attack_cooldown: float = 1.3
var cooldown_timer: float = 0.0
var is_telegraphing: bool = false
var current_attack_data: AttackData = null

var adaptation_budget: int = 100
var campaign_parry_ratio: float = 0.35
var campaign_dodge_bias: float = 0.50
var campaign_melee_intensity: float = 0.50
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
	
	personality = BossPersonality.new(0.95, 0.95, 0.90, 1.0)
	fight_memory = CurrentFightMemory.new()
	persistent_profile = PersistentMemoryProfile.new()
	budget_regulator = AdaptationBudget.new(100)
	utility_ai = UtilityAI.new()
	telegraph_system = TelegraphSystem.new()
	fairness_engine = FairnessEngine.new()
	
	# Load campaign-wide memory traits
	campaign_parry_ratio = persistent_profile.get_habit("parry_frequency", 0.40)
	campaign_dodge_bias = persistent_profile.get_habit("dodge_frequency", 0.50)
	
	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)
		hurtbox.parry_successful.connect(_on_parried_by_player)
		hurtbox.defense_stat = defense
		hurtbox.entity_owner = self
	
	if hitbox:
		hitbox.attacker_owner = self
	
	if float_label:
		float_label.visible = false
	
	EventBus.player_parried.connect(_on_observed_player_parry)
	EventBus.player_dodged.connect(_on_observed_player_dodge)
	EventBus.enemy_spawned.emit("null", "NULL", global_position)
	boss_health_changed.emit(current_health, max_health)

func _load_attacks() -> void:
	if ResourceLoader.exists("res://data/attacks/boss/null_glitch_strike.tres"):
		glitch_strike_attack = load("res://data/attacks/boss/null_glitch_strike.tres")
	if ResourceLoader.exists("res://data/attacks/boss/null_memory_echo.tres"):
		memory_echo_attack = load("res://data/attacks/boss/null_memory_echo.tres")
	if ResourceLoader.exists("res://data/attacks/boss/null_void_singularity.tres"):
		void_singularity_attack = load("res://data/attacks/boss/null_void_singularity.tres")
	if ResourceLoader.exists("res://data/attacks/boss/null_execution_error.tres"):
		execution_error_attack = load("res://data/attacks/boss/null_execution_error.tres")

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
		BossState.GLITCH_STRIKE, BossState.MEMORY_ECHO, BossState.VOID_SINGULARITY, BossState.EXECUTION_ERROR:
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
		BossState.GLITCH_STRIKE:
			current_attack_data = glitch_strike_attack
			_position_hitbox(Vector2(35.0, -18.0))
		BossState.MEMORY_ECHO:
			current_attack_data = memory_echo_attack
			_position_hitbox(Vector2(40.0, -20.0))
		BossState.VOID_SINGULARITY:
			current_attack_data = void_singularity_attack
			_position_hitbox(Vector2(0.0, -10.0))
		BossState.EXECUTION_ERROR:
			current_attack_data = execution_error_attack
			_position_hitbox(Vector2(50.0, -25.0))
		BossState.PHASE_TRANSITION:
			velocity = Vector2.ZERO
			if hurtbox: hurtbox.is_invulnerable = true
			_show_text_popup("TOTAL SYSTEM FAILURE!", Color("#ff007f"))
			EventBus.boss_phase_changed.emit("null", 2)
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
	
	if current_phase == BossPhase.PHASE_1_ANOMALY and current_health <= (max_health * 0.50):
		current_phase = BossPhase.PHASE_2_ENTROPIC_COLLAPSE
		boss_phase_transition.emit(2)
		change_boss_state(BossState.PHASE_TRANSITION)
		return
	
	if cooldown_timer <= 0.0 and state_timer >= 0.40:
		_select_adaptive_action()

func _select_adaptive_action() -> void:
	if not target_player:
		return
	
	var dist: float = global_position.distance_to(target_player.global_position)
	
	# Adaptive Focus: Complete Campaign Memory Integration
	# Tactic 1: If player heavily parried through campaign (>0.35), trigger Execution Error unparryable blast (20 pts)
	if campaign_parry_ratio > 0.35 and adaptation_budget >= 20 and current_phase == BossPhase.PHASE_2_ENTROPIC_COLLAPSE:
		adaptation_budget -= 20
		current_tactic = "Counter: Campaign Parry Exploit -> Execution Error"
		EventBus.boss_adapted.emit("null", "Execution Error", "Integrated campaign parry ratio (%.2f)" % campaign_parry_ratio)
		change_boss_state(BossState.EXECUTION_ERROR)
		return
	
	# Tactic 2: If player prefers ranged spacing / kiting, trigger Void Singularity gravitational pull (20 pts)
	if dist > 95.0 and adaptation_budget >= 20:
		adaptation_budget -= 20
		current_tactic = "Counter: Void Singularity Gravity Well"
		EventBus.boss_adapted.emit("null", "Void Singularity", "Campaign distance & kiting habit counter")
		change_boss_state(BossState.VOID_SINGULARITY)
		return
	
	# Tactic 3: Memory Echo against aggressive approaches (15 pts)
	if dist <= 70.0 and adaptation_budget >= 15 and randf() < 0.5:
		adaptation_budget -= 15
		current_tactic = "Counter: Memory Echo Combo Counter"
		change_boss_state(BossState.MEMORY_ECHO)
		return
	
	if dist <= 80.0:
		change_boss_state(BossState.GLITCH_STRIKE)
		return
	
	change_boss_state(BossState.REPOSITION)

func _process_reposition(delta: float) -> void:
	state_timer += delta
	if not target_player:
		change_boss_state(BossState.IDLE)
		return
	
	var dist: float = global_position.distance_to(target_player.global_position)
	var speed = base_speed * (1.35 if current_phase == BossPhase.PHASE_2_ENTROPIC_COLLAPSE else 1.0)
	velocity.x = facing_direction * speed
	if dist <= 60.0 or state_timer >= 1.6:
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
			if current_state == BossState.GLITCH_STRIKE:
				velocity.x = facing_direction * charge_speed
	elif state_timer >= (startup + active) and state_timer < (startup + active + recovery):
		if hitbox: hitbox.deactivate()
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	else:
		if hitbox: hitbox.deactivate()
		cooldown_timer = attack_cooldown * (0.75 if current_phase == BossPhase.PHASE_2_ENTROPIC_COLLAPSE else 1.0)
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
	campaign_parry_ratio += 0.03
	if persistent_profile:
		persistent_profile.update_habit("parry_frequency", campaign_parry_ratio)
	if is_perfect:
		_show_text_popup("PERFECT PARRY!", Color("#00f5d4"))
		change_boss_state(BossState.STAGGER)
	else:
		_show_text_popup("PARRIED!", Color("#ff007f"))

func _on_observed_player_parry(_target: String, _is_perfect: bool) -> void:
	campaign_parry_ratio += 0.02

func _on_observed_player_dodge(_dir: Vector2, _perfect: bool) -> void:
	campaign_dodge_bias += 0.02

func _position_hitbox(offset_pos: Vector2) -> void:
	if hitbox:
		hitbox.position = Vector2(facing_direction * offset_pos.x, offset_pos.y)

func _show_damage_popup(amount: float, is_crit: bool, effect: String) -> void:
	var msg = str(amount)
	if is_crit: msg += " CRIT!"
	if effect != "None" and effect != "": msg += " [" + effect + "]"
	_show_text_popup(msg, Color("#ff0055") if is_crit else Color("#ff007f"))

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
	var is_phase_2 = (current_phase == BossPhase.PHASE_2_ENTROPIC_COLLAPSE)
	var void_col = Color("#000000")
	var glitch_col = Color("#ff007f") if not is_phase_2 else Color("#00ffff")
	
	if current_state == BossState.DEFEATED:
		draw_rect(Rect2(-24, -5, 48, 10), Color(void_col, 0.5))
		return
	
	# Fractured Geometric Silhouette
	draw_rect(Rect2(-24, -46, 48, 40), void_col)
	draw_rect(Rect2(-20, -42, 40, 32), glitch_col.darkened(0.6))
	
	# Central Eclipse Void Singularity
	draw_circle(Vector2(facing_direction * 6, -26), 9.0, void_col)
	draw_arc(Vector2(facing_direction * 6, -26), 11.0, 0.0, TAU, 16, glitch_col, 2.0)
	
	# Reality Shift Horns / Fractal Wings
	draw_line(Vector2(facing_direction * 14, -50), Vector2(facing_direction * 28, -76), glitch_col, 3.0)
	draw_line(Vector2(facing_direction * 24, -50), Vector2(facing_direction * 38, -72), glitch_col, 2.5)
	
	# Phase 2 Entropic Glitch Aura
	if is_phase_2:
		draw_arc(Vector2(0, -26), 46.0, 0.0, TAU, 24, Color("#ff007f", 0.6), 3.0)
		# Digital fracture shards
		for i in range(4):
			var rx = (i * 18) - 27
			draw_line(Vector2(rx, -48), Vector2(rx + 6, -10), Color("#00ffff", 0.8), 2.0)
	
	# Telegraph Warning
	if is_telegraphing:
		draw_circle(Vector2(0, -78), 7.0, Color("#ef4444"))
		draw_arc(Vector2(0, -26), 38.0, 0.0, TAU, 16, Color("#ef4444", 0.9), 3.0)
