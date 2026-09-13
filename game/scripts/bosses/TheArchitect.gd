# TheArchitect.gd
# Major Boss of World 5: The Broken Machine.
# Adaptive Focus: Deep historical profiling & machine pattern optimization.
class_name TheArchitect
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
	PHASE_1_CLOCKWORK_PRIME,
	PHASE_2_OVERCHARGED_CORE
}

enum BossState {
	IDLE,
	REPOSITION,
	COGWHEEL_CRUSH,
	CIRCUIT_SURGE,
	CLOCKWORK_LASER,
	DRONE_PROTOCOL,
	STAGGER,
	PHASE_TRANSITION,
	DEFEATED
}

signal boss_health_changed(current: float, max_val: float)
signal boss_phase_transition(phase: int)
signal boss_defeated()

@export var max_health: float = 3800.0
@export var defense: int = 45
@export var base_speed: float = 75.0
@export var charge_speed: float = 210.0
@export var xp_reward: float = 2000.0

var current_health: float = 3800.0
var current_phase: BossPhase = BossPhase.PHASE_1_CLOCKWORK_PRIME
var current_state: BossState = BossState.IDLE
var target_player: CharacterBody2D = null
var facing_direction: int = -1

# Attack resources
var cogwheel_crush_attack: AttackData
var circuit_surge_attack: AttackData
var clockwork_laser_attack: AttackData
var drone_protocol_attack: AttackData

# State & adaptation
var state_timer: float = 0.0
var attack_cooldown: float = 1.6
var cooldown_timer: float = 0.0
var is_telegraphing: bool = false
var current_attack_data: AttackData = null

var adaptation_budget: int = 100
var historical_player_parry_habit: float = 0.0
var historical_player_dodge_habit: float = 0.0
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
	
	personality = BossPersonality.new(0.50, 0.90, 0.90, 0.95)
	fight_memory = CurrentFightMemory.new()
	persistent_profile = PersistentMemoryProfile.new()
	budget_regulator = AdaptationBudget.new(100)
	utility_ai = UtilityAI.new()
	telegraph_system = TelegraphSystem.new()
	fairness_engine = FairnessEngine.new()
	
	# Seed historical profiling metrics
	historical_player_parry_habit = persistent_profile.get_habit("parry_frequency", 0.35)
	historical_player_dodge_habit = persistent_profile.get_habit("dodge_frequency", 0.45)
	
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
	EventBus.enemy_spawned.emit("the_architect", "THE ARCHITECT", global_position)
	boss_health_changed.emit(current_health, max_health)

func _load_attacks() -> void:
	if ResourceLoader.exists("res://data/attacks/boss/architect_cogwheel_crush.tres"):
		cogwheel_crush_attack = load("res://data/attacks/boss/architect_cogwheel_crush.tres")
	if ResourceLoader.exists("res://data/attacks/boss/architect_circuit_surge.tres"):
		circuit_surge_attack = load("res://data/attacks/boss/architect_circuit_surge.tres")
	if ResourceLoader.exists("res://data/attacks/boss/architect_clockwork_laser.tres"):
		clockwork_laser_attack = load("res://data/attacks/boss/architect_clockwork_laser.tres")
	if ResourceLoader.exists("res://data/attacks/boss/architect_drone_protocol.tres"):
		drone_protocol_attack = load("res://data/attacks/boss/architect_drone_protocol.tres")

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
		BossState.COGWHEEL_CRUSH, BossState.CIRCUIT_SURGE, BossState.CLOCKWORK_LASER, BossState.DRONE_PROTOCOL:
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
		BossState.COGWHEEL_CRUSH:
			current_attack_data = cogwheel_crush_attack
			_position_hitbox(Vector2(32.0, -15.0))
		BossState.CIRCUIT_SURGE:
			current_attack_data = circuit_surge_attack
			_position_hitbox(Vector2(0.0, -10.0))
		BossState.CLOCKWORK_LASER:
			current_attack_data = clockwork_laser_attack
			_position_hitbox(Vector2(50.0, -25.0))
		BossState.DRONE_PROTOCOL:
			current_attack_data = drone_protocol_attack
			_position_hitbox(Vector2(30.0, -30.0))
		BossState.PHASE_TRANSITION:
			velocity = Vector2.ZERO
			if hurtbox: hurtbox.is_invulnerable = true
			_show_text_popup("CORE OVERDRIVE ACTIVATED!", Color("#eab308"))
			EventBus.boss_phase_changed.emit("the_architect", 2)
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
	
	if current_phase == BossPhase.PHASE_1_CLOCKWORK_PRIME and current_health <= (max_health * 0.50):
		current_phase = BossPhase.PHASE_2_OVERCHARGED_CORE
		boss_phase_transition.emit(2)
		change_boss_state(BossState.PHASE_TRANSITION)
		return
	
	if cooldown_timer <= 0.0 and state_timer >= 0.5:
		_select_adaptive_action()

func _select_adaptive_action() -> void:
	if not target_player:
		return
	
	var dist: float = global_position.distance_to(target_player.global_position)
	
	# Adaptive Focus: Deep Historical Profiling
	# Tactic 1: If historical profile indicates high parry habit (>0.40) & budget allows, fire unparryable Clockwork Laser (20 pts)
	if historical_player_parry_habit > 0.40 and adaptation_budget >= 20:
		adaptation_budget -= 20
		current_tactic = "Counter: Clockwork Laser from Historical Profile"
		EventBus.boss_adapted.emit("the_architect", "Clockwork Laser", "Historical profile indicates parry habit (%.2f)" % historical_player_parry_habit)
		change_boss_state(BossState.CLOCKWORK_LASER)
		return
	
	# Tactic 2: If player has high dodge mobility, spawn Drone Protocol to restrict escape vectors (15 pts)
	if historical_player_dodge_habit > 0.50 and adaptation_budget >= 15:
		adaptation_budget -= 15
		current_tactic = "Counter: Drone Zone Restriction"
		EventBus.boss_adapted.emit("the_architect", "Drone Protocol", "Player mobility profile exploitation")
		change_boss_state(BossState.DRONE_PROTOCOL)
		return
	
	if dist <= 70.0:
		change_boss_state(BossState.COGWHEEL_CRUSH)
		return
	
	if dist > 100.0:
		change_boss_state(BossState.CIRCUIT_SURGE)
		return
	
	change_boss_state(BossState.REPOSITION)

func _process_reposition(delta: float) -> void:
	state_timer += delta
	if not target_player:
		change_boss_state(BossState.IDLE)
		return
	
	var dist: float = global_position.distance_to(target_player.global_position)
	var speed = base_speed * (1.25 if current_phase == BossPhase.PHASE_2_OVERCHARGED_CORE else 1.0)
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
			if current_state == BossState.COGWHEEL_CRUSH:
				velocity.x = facing_direction * charge_speed
	elif state_timer >= (startup + active) and state_timer < (startup + active + recovery):
		if hitbox: hitbox.deactivate()
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	else:
		if hitbox: hitbox.deactivate()
		cooldown_timer = attack_cooldown * (0.80 if current_phase == BossPhase.PHASE_2_OVERCHARGED_CORE else 1.0)
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
	historical_player_parry_habit += 0.05
	if persistent_profile:
		persistent_profile.update_habit("parry_frequency", historical_player_parry_habit)
	if is_perfect:
		_show_text_popup("PERFECT PARRY!", Color("#00f5d4"))
		change_boss_state(BossState.STAGGER)
	else:
		_show_text_popup("PARRIED!", Color("#eab308"))

func _on_observed_player_parry(_target: String, is_perfect: bool) -> void:
	historical_player_parry_habit += 0.02

func _position_hitbox(offset_pos: Vector2) -> void:
	if hitbox:
		hitbox.position = Vector2(facing_direction * offset_pos.x, offset_pos.y)

func _show_damage_popup(amount: float, is_crit: bool, effect: String) -> void:
	var msg = str(amount)
	if is_crit: msg += " CRIT!"
	if effect != "None" and effect != "": msg += " [" + effect + "]"
	_show_text_popup(msg, Color("#ff1744") if is_crit else Color("#eab308"))

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
	var is_phase_2 = (current_phase == BossPhase.PHASE_2_OVERCHARGED_CORE)
	var brass_col = Color("#78350f") if not is_phase_2 else Color("#451a03")
	var spark_col = Color("#eab308") if not is_phase_2 else Color("#06b6d4")
	
	if current_state == BossState.DEFEATED:
		draw_rect(Rect2(-26, -5, 52, 10), Color(brass_col, 0.5))
		return
	
	# Massive Clockwork Torso
	draw_rect(Rect2(-26, -44, 52, 38), brass_col)
	draw_circle(Vector2(facing_direction * 10, -25), 10.0, spark_col)
	
	# Rotating Core Cog
	draw_arc(Vector2(0, -25), 14.0, 0.0, TAU, 12, brass_col.lightened(0.3), 3.0)
	
	# Heavy Mechanical Piston Legs
	draw_rect(Rect2(-20, -6, 10, 24), brass_col.darkened(0.2))
	draw_rect(Rect2(10, -6, 10, 24), brass_col.darkened(0.2))
	
	# Armored Optic Head
	draw_rect(Rect2(facing_direction * 16, -58, 18, 16), brass_col)
	draw_line(Vector2(facing_direction * 16, -50), Vector2(facing_direction * 34, -50), spark_col, 2.5)
	
	# Phase 2 Dynamo Arcs
	if is_phase_2:
		draw_arc(Vector2(0, -25), 42.0, -1.8, 1.8, 14, Color("#06b6d4", 0.6), 3.0)
	
	# Telegraph Warning
	if is_telegraphing:
		draw_circle(Vector2(0, -72), 6.0, Color("#ef4444"))
		draw_arc(Vector2(0, -25), 36.0, 0.0, TAU, 16, Color("#ef4444", 0.8), 2.5)
