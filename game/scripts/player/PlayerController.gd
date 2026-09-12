# PlayerController.gd
# Kinematic Player Controller for ECLIPSEBOUND.
# Implements responsive 2D platforming, state machine, data-driven combat, i-frame dashing, parrying, and telemetry hooks.
class_name PlayerController
extends CharacterBody2D

const AttackData = preload("res://scripts/combat/AttackData.gd")
const Hitbox = preload("res://scripts/combat/Hitbox.gd")
const Hurtbox = preload("res://scripts/combat/Hurtbox.gd")
const PlayerStats = preload("res://scripts/core/PlayerStats.gd")

# State Machine Enum
enum State {
	IDLE,
	RUN,
	JUMP,
	FALL,
	DASH,
	ATTACK_LIGHT_1,
	ATTACK_LIGHT_2,
	ATTACK_HEAVY,
	ABILITY,
	PARRY,
	HURT,
	STAGGER,
	DEAD
}

# --- Signals ---
signal state_changed(old_state: State, new_state: State)
signal health_changed(current: float, max_val: float)
signal stamina_changed(current: float, max_val: float)
signal energy_changed(current: float, max_val: float)
signal player_respawned(checkpoint_pos: Vector2)

# --- Physics & Movement Tuning Constants ---
@export_group("Movement")
@export var max_run_speed: float = 160.0
@export var acceleration: float = 1200.0
@export var deceleration: float = 1400.0
@export var air_acceleration: float = 800.0
@export var air_deceleration: float = 600.0

@export_group("Jump & Gravity")
@export var jump_velocity: float = -340.0
@export var jump_cut_multiplier: float = 0.45
@export var fall_gravity_multiplier: float = 1.35
@export var terminal_fall_speed: float = 450.0
@export var coyote_time_max: float = 0.12
@export var jump_buffer_max: float = 0.12

@export_group("Dash / Dodge")
@export var dash_speed: float = 320.0
@export var dash_duration: float = 0.22
@export var dash_iframe_start: float = 0.02
@export var dash_iframe_end: float = 0.20
@export var dash_stamina_cost: float = 20.0

@export_group("Resources")
@export var max_health: float = 225.0
@export var max_stamina: float = 100.0
@export var max_energy: float = 100.0
@export var stamina_regen_rate: float = 35.0
@export var energy_regen_rate: float = 10.0

# --- Combat Attack References ---
@export_group("Combat Attacks")
@export var attack_light_1_data: AttackData
@export var attack_light_2_data: AttackData
@export var attack_heavy_data: AttackData
@export var ability_data: AttackData

# --- Node References ---
@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var visual_node: Node2D = $Visuals

# --- Internal State Variables ---
var current_state: State = State.IDLE
var current_health: float = 225.0
var current_stamina: float = 100.0
var current_energy: float = 100.0
var facing_direction: int = 1 # 1 = right, -1 = left

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var state_timer: float = 0.0
var dash_timer: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT

var combo_queued: bool = false
var current_attack_data: AttackData = null
var is_dead: bool = false

var stats: PlayerStats = null

func _ready() -> void:
	stats = PlayerStats.new()
	max_health = stats.get_max_health()
	current_health = max_health
	current_stamina = max_stamina
	current_energy = max_energy
	
	# Connect hurtbox signals
	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)
		hurtbox.parry_successful.connect(_on_parry_successful)
		hurtbox.hit_ignored_invulnerable.connect(_on_hit_ignored_invulnerable)
		hurtbox.defense_stat = stats.def
	
	# Load default attack resources if not set in inspector
	_load_default_attacks()
	
	EventBus.player_spawned.emit(self)

func _load_default_attacks() -> void:
	if not attack_light_1_data and ResourceLoader.exists("res://data/attacks/player_light_1.tres"):
		attack_light_1_data = load("res://data/attacks/player_light_1.tres")
	if not attack_light_2_data and ResourceLoader.exists("res://data/attacks/player_light_2.tres"):
		attack_light_2_data = load("res://data/attacks/player_light_2.tres")
	if not attack_heavy_data and ResourceLoader.exists("res://data/attacks/player_heavy_1.tres"):
		attack_heavy_data = load("res://data/attacks/player_heavy_1.tres")
	if not ability_data and ResourceLoader.exists("res://data/attacks/player_ability_void_slash.tres"):
		ability_data = load("res://data/attacks/player_ability_void_slash.tres")

func _physics_process(delta: float) -> void:
	if is_dead:
		_apply_gravity(delta)
		move_and_slide()
		return
	
	# Resource Regen
	_regen_resources(delta)
	
	# Timers
	if coyote_timer > 0.0:
		coyote_timer -= delta
	if jump_buffer_timer > 0.0:
		jump_buffer_timer -= delta
	
	# Input reading for buffered actions
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_max
	
	# State processing
	match current_state:
		State.IDLE, State.RUN:
			_process_ground_state(delta)
		State.JUMP, State.FALL:
			_process_air_state(delta)
		State.DASH:
			_process_dash_state(delta)
		State.ATTACK_LIGHT_1, State.ATTACK_LIGHT_2, State.ATTACK_HEAVY, State.ABILITY:
			_process_attack_state(delta)
		State.PARRY:
			_process_parry_state(delta)
		State.HURT:
			_process_hurt_state(delta)
		State.STAGGER:
			_process_stagger_state(delta)
	
	move_and_slide()
	_update_visuals()

# --- State Transitions ---

func change_state(new_state: State) -> void:
	var old_state: State = current_state
	current_state = new_state
	state_timer = 0.0
	
	# Exit logic
	if old_state == State.DASH and hurtbox:
		hurtbox.is_invulnerable = false
	if old_state == State.PARRY and hurtbox:
		hurtbox.is_parrying = false
		hurtbox.is_perfect_parrying = false
	if hitbox:
		hitbox.deactivate()
	
	# Enter logic
	match new_state:
		State.DASH:
			dash_timer = dash_duration
			velocity = dash_direction * dash_speed
			velocity.y = 0.0 # Horizontal dodge
			if hurtbox:
				hurtbox.is_invulnerable = true
			EventBus.player_dodged.emit(dash_direction, false)
		
		State.PARRY:
			velocity.x = 0.0
			if hurtbox:
				hurtbox.is_parrying = true
				hurtbox.is_perfect_parrying = true
		
		State.ATTACK_LIGHT_1:
			velocity.x = facing_direction * 40.0
			combo_queued = false
			_begin_attack(attack_light_1_data)
			EventBus.player_attacked.emit("rebellion", "light_1", global_position)
		
		State.ATTACK_LIGHT_2:
			velocity.x = facing_direction * 70.0
			combo_queued = false
			_begin_attack(attack_light_2_data)
			EventBus.player_attacked.emit("rebellion", "light_2", global_position)
		
		State.ATTACK_HEAVY:
			velocity.x = facing_direction * 30.0
			_begin_attack(attack_heavy_data)
			EventBus.player_attacked.emit("rebellion", "heavy", global_position)
		
		State.ABILITY:
			velocity.x = facing_direction * 90.0
			_begin_attack(ability_data)
			EventBus.player_attacked.emit("void_blade", "ability", global_position)
		
		State.DEAD:
			is_dead = true
			velocity = Vector2.ZERO
			if hurtbox:
				hurtbox.is_invulnerable = true
			EventBus.player_died.emit("combat", global_position)
	
	state_changed.emit(old_state, new_state)

# --- Ground & Air State Movement ---

func _process_ground_state(delta: float) -> void:
	if not is_on_floor():
		coyote_timer = coyote_time_max
		change_state(State.FALL)
		return
	
	coyote_timer = coyote_time_max
	
	# Attacks & Actions check
	if _check_combat_inputs():
		return
	
	# Jump
	if jump_buffer_timer > 0.0:
		jump_buffer_timer = 0.0
		_do_jump()
		return
	
	# Horizontal Movement
	var move_input: float = Input.get_axis("move_left", "move_right")
	if abs(move_input) > 0.1:
		facing_direction = 1 if move_input > 0 else -1
		velocity.x = move_toward(velocity.x, move_input * max_run_speed, acceleration * delta)
		if current_state != State.RUN:
			change_state(State.RUN)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		if current_state != State.IDLE:
			change_state(State.IDLE)

func _process_air_state(delta: float) -> void:
	_apply_gravity(delta)
	
	# Variable jump cut (holding jump gives full height, releasing cuts upward velocity)
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier
	
	# Air horizontal movement
	var move_input: float = Input.get_axis("move_left", "move_right")
	if abs(move_input) > 0.1:
		facing_direction = 1 if move_input > 0 else -1
		velocity.x = move_toward(velocity.x, move_input * max_run_speed, air_acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, air_deceleration * delta)
	
	# Landed
	if is_on_floor():
		if jump_buffer_timer > 0.0:
			jump_buffer_timer = 0.0
			_do_jump()
		else:
			change_state(State.IDLE)
		return
	
	# Coyote Jump
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		_do_jump()
		return
	
	# Mid-air attacks or dash
	if _check_combat_inputs():
		return

func _do_jump() -> void:
	velocity.y = jump_velocity
	change_state(State.JUMP)

func _apply_gravity(delta: float) -> void:
	var grav: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
	if velocity.y > 0.0:
		grav *= fall_gravity_multiplier # Snappy falling
	velocity.y = min(velocity.y + grav * delta, terminal_fall_speed)
	if velocity.y > 0.0 and current_state == State.JUMP:
		change_state(State.FALL)

# --- Combat Input & Action Handlers ---

func _check_combat_inputs() -> bool:
	# Dash
	if Input.is_action_just_pressed("dash") and current_stamina >= dash_stamina_cost:
		current_stamina -= dash_stamina_cost
		stamina_changed.emit(current_stamina, max_stamina)
		var dir_x: float = Input.get_axis("move_left", "move_right")
		if abs(dir_x) > 0.1:
			dash_direction = Vector2(1.0 if dir_x > 0 else -1.0, 0.0)
			facing_direction = int(dash_direction.x)
		else:
			dash_direction = Vector2(facing_direction, 0.0)
		change_state(State.DASH)
		return true
	
	# Parry
	if Input.is_action_just_pressed("parry") and is_on_floor() and current_stamina >= 10.0:
		current_stamina -= 10.0
		stamina_changed.emit(current_stamina, max_stamina)
		change_state(State.PARRY)
		return true
	
	# Light Attack
	if Input.is_action_just_pressed("attack_light") and attack_light_1_data:
		if current_stamina >= attack_light_1_data.stamina_cost:
			current_stamina -= attack_light_1_data.stamina_cost
			stamina_changed.emit(current_stamina, max_stamina)
			change_state(State.ATTACK_LIGHT_1)
			return true
	
	# Heavy Attack
	if Input.is_action_just_pressed("attack_heavy") and attack_heavy_data:
		if current_stamina >= attack_heavy_data.stamina_cost:
			current_stamina -= attack_heavy_data.stamina_cost
			stamina_changed.emit(current_stamina, max_stamina)
			change_state(State.ATTACK_HEAVY)
			return true
	
	# Ability (Void Slash)
	if Input.is_action_just_pressed("ability") and ability_data:
		if current_energy >= 25.0:
			current_energy -= 25.0
			energy_changed.emit(current_energy, max_energy)
			change_state(State.ABILITY)
			return true
	
	return false

func _process_dash_state(delta: float) -> void:
	dash_timer -= delta
	state_timer += delta
	
	# Update i-frame active window
	if hurtbox:
		hurtbox.is_invulnerable = (state_timer >= dash_iframe_start and state_timer <= dash_iframe_end)
	
	if dash_timer <= 0.0:
		if is_on_floor():
			change_state(State.IDLE)
		else:
			change_state(State.FALL)

func _process_parry_state(delta: float) -> void:
	state_timer += delta
	# Perfect parry window: first 0.15s, regular parry window up to 0.35s
	if hurtbox:
		hurtbox.is_perfect_parrying = (state_timer <= 0.15)
		hurtbox.is_parrying = (state_timer <= 0.35)
	
	# Hold or release parry stance
	if state_timer >= 0.45 or not Input.is_action_pressed("parry"):
		change_state(State.IDLE)

func _begin_attack(data: AttackData) -> void:
	current_attack_data = data
	state_timer = 0.0
	_position_hitbox_for_facing()

func _position_hitbox_for_facing() -> void:
	if hitbox:
		# Hitbox positioned forward based on facing direction
		hitbox.position = Vector2(facing_direction * 18.0, -8.0)

func _process_attack_state(delta: float) -> void:
	state_timer += delta
	if not current_attack_data:
		change_state(State.IDLE)
		return
	
	# Light combo chaining buffer
	if Input.is_action_just_pressed("attack_light") and current_state == State.ATTACK_LIGHT_1:
		combo_queued = true
	
	var startup: float = current_attack_data.startup_time
	var active: float = current_attack_data.active_time
	var recovery: float = current_attack_data.recovery_time
	
	# 1. Startup phase
	if state_timer < startup:
		if hitbox:
			hitbox.deactivate()
	# 2. Active hit window
	elif state_timer >= startup and state_timer < (startup + active):
		if hitbox and not hitbox._is_active:
			hitbox.activate(current_attack_data)
	# 3. Recovery phase
	elif state_timer >= (startup + active) and state_timer < (startup + active + recovery):
		if hitbox:
			hitbox.deactivate()
		# Can chain combo into light 2 during recovery if queued
		if combo_queued and current_state == State.ATTACK_LIGHT_1 and current_stamina >= attack_light_2_data.stamina_cost:
			current_stamina -= attack_light_2_data.stamina_cost
			stamina_changed.emit(current_stamina, max_stamina)
			change_state(State.ATTACK_LIGHT_2)
			return
	# 4. Attack complete
	else:
		if hitbox:
			hitbox.deactivate()
		if is_on_floor():
			change_state(State.IDLE)
		else:
			change_state(State.FALL)

func _process_hurt_state(delta: float) -> void:
	state_timer += delta
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	_apply_gravity(delta)
	if state_timer >= 0.25:
		change_state(State.IDLE)

func _process_stagger_state(delta: float) -> void:
	state_timer += delta
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	_apply_gravity(delta)
	if state_timer >= 1.0: # 1 second posture stagger
		change_state(State.IDLE)

# --- Damage, Parry, and Hit Handlers ---

func _on_damage_received(incoming: AttackData, attacker_pos: Vector2, result: Dictionary) -> void:
	if is_dead:
		return
	
	var dmg: float = result.get("final_damage", 10.0)
	current_health = max(0.0, current_health - dmg)
	health_changed.emit(current_health, max_health)
	EventBus.player_damaged.emit(current_health, max_health, dmg, incoming.attack_name)
	
	# Apply Knockback
	var kb_dir: float = 1.0 if (global_position.x - attacker_pos.x) >= 0.0 else -1.0
	var kb_force: Vector2 = incoming.knockback_force
	velocity = Vector2(kb_dir * kb_force.x, kb_force.y)
	
	if current_health <= 0.0:
		change_state(State.DEAD)
	else:
		if incoming.breaks_guard:
			change_state(State.STAGGER)
		else:
			change_state(State.HURT)

func _on_parry_successful(incoming: AttackData, is_perfect: bool, attacker_hitbox: Area2D) -> void:
	# Refill stamina on parry
	current_stamina = min(max_stamina, current_stamina + (40.0 if is_perfect else 20.0))
	stamina_changed.emit(current_stamina, max_stamina)
	
	EventBus.player_parried.emit(incoming.attack_name, is_perfect)
	CombatSystem.parry_resolved.emit(true, is_perfect, attacker_hitbox.attacker_owner if attacker_hitbox else null)
	
	# Briefly flash or bounce
	velocity.x = -facing_direction * 30.0

func _on_hit_ignored_invulnerable(_incoming: AttackData) -> void:
	# Perfect dodge detection window
	if dash_timer > (dash_duration * 0.5):
		EventBus.player_dodged.emit(dash_direction, true)

func take_dot_damage(effect_name: String, amount: float) -> void:
	if is_dead:
		return
	current_health = max(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)
	EventBus.player_damaged.emit(current_health, max_health, amount, effect_name)
	if current_health <= 0.0:
		change_state(State.DEAD)

func _regen_resources(delta: float) -> void:
	# Stamina Regen (only when not attacking, dashing, or parrying)
	if current_state in [State.IDLE, State.RUN, State.JUMP, State.FALL]:
		if current_stamina < max_stamina:
			current_stamina = min(max_stamina, current_stamina + stamina_regen_rate * delta)
			stamina_changed.emit(current_stamina, max_stamina)
	
	# Energy Regen
	if current_energy < max_energy:
		current_energy = min(max_energy, current_energy + energy_regen_rate * delta)
		energy_changed.emit(current_energy, max_energy)

func respawn(respawn_position: Vector2) -> void:
	is_dead = false
	current_health = max_health
	current_stamina = max_stamina
	current_energy = max_energy
	global_position = respawn_position
	velocity = Vector2.ZERO
	if hurtbox:
		hurtbox.is_invulnerable = false
		hurtbox.is_parrying = false
	change_state(State.IDLE)
	health_changed.emit(current_health, max_health)
	stamina_changed.emit(current_stamina, max_stamina)
	energy_changed.emit(current_energy, max_energy)
	player_respawned.emit(respawn_position)

# --- Save / Load Hooks ---

func get_save_state() -> Dictionary:
	return {
		"level": stats.level if stats else 1,
		"xp": stats.current_xp if stats else 0.0,
		"current_hp": current_health,
		"max_hp": max_health,
		"stamina": current_stamina,
		"energy": current_energy,
		"position": {"x": global_position.x, "y": global_position.y},
		"stats": {
			"vit": stats.vit if stats else 10,
			"str": stats.str_stat if stats else 10,
			"arc": stats.arc if stats else 10,
			"def": stats.def if stats else 10,
			"agi": stats.agi if stats else 10,
			"crt": stats.crt if stats else 10,
			"res": stats.res if stats else 10,
			"lck": stats.lck if stats else 10
		},
		"equipped_weapon": "rebellion",
		"artifacts": []
	}

func load_save_state(data: Dictionary) -> void:
	if data.has("current_hp"):
		current_health = data["current_hp"]
	if data.has("max_hp"):
		max_health = data["max_hp"]
	if data.has("stamina"):
		current_stamina = data["stamina"]
	if data.has("energy"):
		current_energy = data["energy"]
	if data.has("position"):
		var p = data["position"]
		global_position = Vector2(p.get("x", 100.0), p.get("y", 200.0))
	if data.has("stats") and stats:
		var s = data["stats"]
		stats.vit = s.get("vit", 10)
		stats.str_stat = s.get("str", 10)
		stats.arc = s.get("arc", 10)
		stats.def = s.get("def", 10)
		stats.agi = s.get("agi", 10)
		stats.crt = s.get("crt", 10)
		stats.res = s.get("res", 10)
		stats.lck = s.get("lck", 10)
	health_changed.emit(current_health, max_health)
	stamina_changed.emit(current_stamina, max_stamina)
	energy_changed.emit(current_energy, max_energy)

# --- Procedural Visual Presentation ---

func _update_visuals() -> void:
	if visual_node:
		visual_node.scale.x = float(facing_direction)
		visual_node.queue_redraw()
