# CardinalOfBlood.gd
# Major Boss of World 4: The Crimson Cathedral.
# Adaptive Focus: Exploits heal timing, potion greed, and low-HP desperation.
class_name CardinalOfBlood
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
	PHASE_1_SANGUINE_PRIEST,
	PHASE_2_BLOOD_ARCHON
}

enum BossState {
	IDLE,
	REPOSITION,
	BLOOD_SPEAR,
	SANGUINE_SIPHON,
	HEMORRHAGE_SEAL,
	EXCOMMUNICATION,
	STAGGER,
	PHASE_TRANSITION,
	DEFEATED
}

signal boss_health_changed(current: float, max_val: float)
signal boss_phase_transition(phase: int)
signal boss_defeated()

@export var max_health: float = 3000.0
@export var defense: int = 40
@export var base_speed: float = 95.0
@export var charge_speed: float = 240.0
@export var xp_reward: float = 1500.0

var current_health: float = 3000.0
var current_phase: BossPhase = BossPhase.PHASE_1_SANGUINE_PRIEST
var current_state: BossState = BossState.IDLE
var target_player: CharacterBody2D = null
var facing_direction: int = -1

# Attack resources
var blood_spear_attack: AttackData
var sanguine_siphon_attack: AttackData
var hemorrhage_seal_attack: AttackData
var excommunication_attack: AttackData

# State & adaptation
var state_timer: float = 0.0
var attack_cooldown: float = 1.5
var cooldown_timer: float = 0.0
var is_telegraphing: bool = false
var current_attack_data: AttackData = null

var adaptation_budget: int = 100
var observed_heals_count: int = 0
var last_observed_player_hp_ratio: float = 1.0
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
	
	personality = BossPersonality.new(0.75, 0.85, 0.70, 0.90)
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
	
	EventBus.player_healed.connect(_on_observed_player_healed)
	EventBus.player_damaged.connect(_on_observed_player_damaged)
	EventBus.enemy_spawned.emit("cardinal_of_blood", "Cardinal of Blood", global_position)
	boss_health_changed.emit(current_health, max_health)

func _load_attacks() -> void:
	if ResourceLoader.exists("res://data/attacks/boss/cardinal_blood_spear.tres"):
		blood_spear_attack = load("res://data/attacks/boss/cardinal_blood_spear.tres")
	if ResourceLoader.exists("res://data/attacks/boss/cardinal_sanguine_siphon.tres"):
		sanguine_siphon_attack = load("res://data/attacks/boss/cardinal_sanguine_siphon.tres")
	if ResourceLoader.exists("res://data/attacks/boss/cardinal_hemorrhage_seal.tres"):
		hemorrhage_seal_attack = load("res://data/attacks/boss/cardinal_hemorrhage_seal.tres")
	if ResourceLoader.exists("res://data/attacks/boss/cardinal_excommunication.tres"):
		excommunication_attack = load("res://data/attacks/boss/cardinal_excommunication.tres")

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
		BossState.BLOOD_SPEAR, BossState.SANGUINE_SIPHON, BossState.HEMORRHAGE_SEAL, BossState.EXCOMMUNICATION:
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
		BossState.BLOOD_SPEAR:
			current_attack_data = blood_spear_attack
			_position_hitbox(Vector2(35.0, -20.0))
		BossState.SANGUINE_SIPHON:
			current_attack_data = sanguine_siphon_attack
			_position_hitbox(Vector2(20.0, -15.0))
		BossState.HEMORRHAGE_SEAL:
			current_attack_data = hemorrhage_seal_attack
			_position_hitbox(Vector2(0.0, -10.0))
		BossState.EXCOMMUNICATION:
			current_attack_data = excommunication_attack
			_position_hitbox(Vector2(45.0, -22.0))
		BossState.PHASE_TRANSITION:
			velocity = Vector2.ZERO
			if hurtbox: hurtbox.is_invulnerable = true
			_show_text_popup("BLOOD ASCENSION!", Color("#e11d48"))
			EventBus.boss_phase_changed.emit("cardinal_of_blood", 2)
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
	
	if current_phase == BossPhase.PHASE_1_SANGUINE_PRIEST and current_health <= (max_health * 0.50):
		current_phase = BossPhase.PHASE_2_BLOOD_ARCHON
		boss_phase_transition.emit(2)
		change_boss_state(BossState.PHASE_TRANSITION)
		return
	
	if cooldown_timer <= 0.0 and state_timer >= 0.5:
		_select_adaptive_action()

func _select_adaptive_action() -> void:
	if not target_player:
		return
	
	var dist: float = global_position.distance_to(target_player.global_position)
	
	# Adaptive Focus: Exploits heal timing and low-HP desperation
	# Tactic 1: If player recently healed, execute Sanguine Siphon to punish recovery (20 pts)
	if observed_heals_count > 0 and adaptation_budget >= 20:
		adaptation_budget -= 20
		observed_heals_count = 0
		current_tactic = "Counter: Heal Intercept Siphon"
		EventBus.boss_adapted.emit("cardinal_of_blood", "Sanguine Siphon", "Player heal observed; punishing recovery frame")
		change_boss_state(BossState.SANGUINE_SIPHON)
		return
	
	# Tactic 2: If player is low HP (<35%) and rushing in greedily, drop Hemorrhage Seal trap (20 pts)
	if last_observed_player_hp_ratio < 0.35 and dist <= 80.0 and adaptation_budget >= 20:
		adaptation_budget -= 20
		current_tactic = "Counter: Hemorrhage Trap against low-HP greed"
		EventBus.boss_adapted.emit("cardinal_of_blood", "Hemorrhage Seal", "Player greed exploitation at low HP")
		change_boss_state(BossState.HEMORRHAGE_SEAL)
		return
	
	# Phase 2 unparryable blast
	if current_phase == BossPhase.PHASE_2_BLOOD_ARCHON and dist > 90.0 and randf() < 0.45:
		change_boss_state(BossState.EXCOMMUNICATION)
		return
	
	if dist <= 75.0:
		change_boss_state(BossState.BLOOD_SPEAR)
		return
	
	change_boss_state(BossState.REPOSITION)

func _process_reposition(delta: float) -> void:
	state_timer += delta
	if not target_player:
		change_boss_state(BossState.IDLE)
		return
	
	var dist: float = global_position.distance_to(target_player.global_position)
	var speed = base_speed * (1.30 if current_phase == BossPhase.PHASE_2_BLOOD_ARCHON else 1.0)
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
			if current_state == BossState.BLOOD_SPEAR:
				velocity.x = facing_direction * charge_speed
	elif state_timer >= (startup + active) and state_timer < (startup + active + recovery):
		if hitbox: hitbox.deactivate()
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	else:
		if hitbox: hitbox.deactivate()
		cooldown_timer = attack_cooldown * (0.80 if current_phase == BossPhase.PHASE_2_BLOOD_ARCHON else 1.0)
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
		_show_text_popup("PARRIED!", Color("#fb7185"))

func _on_observed_player_healed(_curr: float, _max: float, _amt: float) -> void:
	observed_heals_count += 1

func _on_observed_player_damaged(curr: float, max_val: float, _dmg: float, _src: String) -> void:
	if max_val > 0.0:
		last_observed_player_hp_ratio = curr / max_val

func _position_hitbox(offset_pos: Vector2) -> void:
	if hitbox:
		hitbox.position = Vector2(facing_direction * offset_pos.x, offset_pos.y)

func _show_damage_popup(amount: float, is_crit: bool, effect: String) -> void:
	var msg = str(amount)
	if is_crit: msg += " CRIT!"
	if effect != "None" and effect != "": msg += " [" + effect + "]"
	_show_text_popup(msg, Color("#ff1744") if is_crit else Color("#fb7185"))

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
	var is_phase_2 = (current_phase == BossPhase.PHASE_2_BLOOD_ARCHON)
	var robe_col = Color("#3b0712") if not is_phase_2 else Color("#1a0006")
	var blood_col = Color("#e11d48") if not is_phase_2 else Color("#ff0044")
	
	if current_state == BossState.DEFEATED:
		draw_rect(Rect2(-24, -5, 48, 10), Color(robe_col, 0.5))
		return
	
	# Flowing Crimson Vestments
	draw_rect(Rect2(-20, -40, 40, 36), robe_col)
	draw_circle(Vector2(facing_direction * 8, -24), 8.0, blood_col)
	
	# Ornate Mitre / Crown
	draw_rect(Rect2(facing_direction * 14, -54, 16, 16), robe_col)
	draw_line(Vector2(facing_direction * 14, -54), Vector2(facing_direction * 22, -72), blood_col, 3.0)
	draw_line(Vector2(facing_direction * 30, -54), Vector2(facing_direction * 22, -72), blood_col, 3.0)
	
	# Sanguine Crozier Staff
	draw_line(Vector2(facing_direction * 24, 6), Vector2(facing_direction * 28, -50), Color("#d97706"), 3.0)
	draw_circle(Vector2(facing_direction * 28, -52), 6.0, blood_col)
	
	# Phase 2 Blood Wings
	if is_phase_2:
		draw_line(Vector2(0, -30), Vector2(-40, -50), blood_col, 3.5)
		draw_line(Vector2(0, -30), Vector2(40, -50), blood_col, 3.5)
	
	# Telegraph Warning
	if is_telegraphing:
		draw_circle(Vector2(0, -72), 6.0, Color("#ef4444"))
		draw_arc(Vector2(0, -25), 35.0, 0.0, TAU, 16, Color("#ef4444", 0.8), 2.5)
