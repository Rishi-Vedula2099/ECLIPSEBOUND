# BaseEnemy.gd
# Universal data-driven enemy base class for ECLIPSEBOUND.
# Implements 2D kinematic navigation, perception, state machine, utility scoring, stagger, and XP drop.
class_name BaseEnemy
extends CharacterBody2D

const AttackData = preload("res://scripts/combat/AttackData.gd")
const Hitbox = preload("res://scripts/combat/Hitbox.gd")
const Hurtbox = preload("res://scripts/combat/Hurtbox.gd")
const CombatSystemRef = preload("res://scripts/combat/CombatSystem.gd")

enum State {
	IDLE,
	PATROL,
	DETECT,
	CHASE,
	ATTACK,
	HURT,
	STAGGER,
	DEAD
}

signal state_changed(old_state: State, new_state: State)
signal enemy_died(enemy_id: String, xp_amount: float)

@export_group("Stats")
@export var enemy_id: String = "enemy_base"
@export var enemy_name: String = "Base Enemy"
@export var max_health: float = 60.0
@export var defense: int = 8
@export var move_speed: float = 65.0
@export var chase_speed: float = 95.0
@export var xp_reward: float = 25.0
@export var max_poise: float = 30.0

@export_group("Perception & Range")
@export var detection_radius: float = 180.0
@export var attack_range: float = 36.0
@export var lose_target_radius: float = 260.0
@export var attack_cooldown: float = 1.8

@export_group("Combat")
@export var default_attack_data: AttackData

# Internal references & state
var current_health: float = 60.0
var current_poise: float = 30.0
var current_state: State = State.IDLE
var target_player: CharacterBody2D = null
var facing_direction: int = 1

var state_timer: float = 0.0
var cooldown_timer: float = 0.0
var patrol_direction: int = 1
var patrol_timer: float = 0.0
var is_telegraphing: bool = false
var is_staggered: bool = false

@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var float_label: Label = $FloatingText

func _ready() -> void:
	current_health = max_health
	current_poise = max_poise
	
	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)
		hurtbox.parry_successful.connect(_on_parried_by_player)
		hurtbox.defense_stat = defense
		hurtbox.entity_owner = self
	
	if hitbox:
		hitbox.attacker_owner = self
		if default_attack_data:
			hitbox.attack_data = default_attack_data
	
	if float_label:
		float_label.visible = false
	
	CombatSystem.parry_resolved.connect(_on_global_parry_resolved)
	EventBus.enemy_spawned.emit(enemy_id, enemy_name, global_position)

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		_apply_gravity(delta)
		move_and_slide()
		return
	
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
	
	# Regenerate poise when not under attack
	if current_state != State.HURT and current_state != State.STAGGER and current_poise < max_poise:
		current_poise = min(max_poise, current_poise + 10.0 * delta)
	
	# State execution
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.PATROL:
			_process_patrol(delta)
		State.DETECT:
			_process_detect(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)
		State.HURT:
			_process_hurt(delta)
		State.STAGGER:
			_process_stagger(delta)
	
	_apply_gravity(delta)
	move_and_slide()
	_update_visual_orientation()
	queue_redraw()

func change_state(new_state: State) -> void:
	var old_state = current_state
	current_state = new_state
	state_timer = 0.0
	
	if old_state == State.ATTACK:
		is_telegraphing = false
		if hitbox:
			hitbox.deactivate()
	
	match new_state:
		State.IDLE:
			velocity.x = 0.0
		State.DETECT:
			velocity.x = 0.0
			is_telegraphing = true # Alert indicator
		State.DEAD:
			velocity.x = 0.0
			if hurtbox:
				hurtbox.is_invulnerable = true
			if hitbox:
				hitbox.deactivate()
			EventBus.enemy_died.emit(enemy_id, enemy_name)
			EventBus.xp_gained.emit(xp_reward, xp_reward, 1)
			_on_death()
	
	state_changed.emit(old_state, new_state)

func _process_idle(delta: float) -> void:
	state_timer += delta
	_scan_for_player()
	if target_player:
		change_state(State.DETECT)
		return
	if state_timer >= 2.0:
		change_state(State.PATROL)

func _process_patrol(delta: float) -> void:
	state_timer += delta
	_scan_for_player()
	if target_player:
		change_state(State.DETECT)
		return
	
	velocity.x = patrol_direction * move_speed
	facing_direction = patrol_direction
	
	if state_timer >= 3.0 or is_on_wall():
		patrol_direction *= -1
		change_state(State.IDLE)

func _process_detect(delta: float) -> void:
	state_timer += delta
	if not target_player:
		change_state(State.IDLE)
		return
	# 0.3s alert pause before charging
	if state_timer >= 0.3:
		is_telegraphing = false
		change_state(State.CHASE)

func _process_chase(delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		target_player = null
		change_state(State.IDLE)
		return
	
	var dist: float = global_position.distance_to(target_player.global_position)
	if dist > lose_target_radius:
		target_player = null
		change_state(State.IDLE)
		return
	
	# Determine direction
	var dir_to_player: float = sign(target_player.global_position.x - global_position.x)
	if dir_to_player != 0.0:
		facing_direction = int(dir_to_player)
	
	# Check attack range
	if dist <= attack_range and cooldown_timer <= 0.0:
		change_state(State.ATTACK)
		return
	
	velocity.x = facing_direction * chase_speed

func _process_attack(delta: float) -> void:
	state_timer += delta
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	
	var attack_data: AttackData = hitbox.attack_data if hitbox and hitbox.attack_data else default_attack_data
	if not attack_data:
		change_state(State.CHASE)
		return
	
	var startup: float = attack_data.startup_time
	var active: float = attack_data.active_time
	var recovery: float = attack_data.recovery_time
	
	# 1. Startup & Telegraph Flash (min 350ms rule)
	if state_timer < startup:
		is_telegraphing = true
		if hitbox:
			hitbox.deactivate()
	# 2. Active Damage Window
	elif state_timer >= startup and state_timer < (startup + active):
		is_telegraphing = false
		if hitbox and not hitbox._is_active:
			_position_hitbox_forward()
			hitbox.activate(attack_data)
	# 3. Recovery Phase
	elif state_timer >= (startup + active) and state_timer < (startup + active + recovery):
		if hitbox:
			hitbox.deactivate()
	# 4. Attack Complete
	else:
		if hitbox:
			hitbox.deactivate()
		cooldown_timer = attack_cooldown
		change_state(State.CHASE)

func _process_hurt(delta: float) -> void:
	state_timer += delta
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	if state_timer >= 0.22:
		change_state(State.CHASE if target_player else State.IDLE)

func _process_stagger(delta: float) -> void:
	state_timer += delta
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	if state_timer >= 1.2: # 1.2s posture break
		is_staggered = false
		current_poise = max_poise
		change_state(State.CHASE if target_player else State.IDLE)

func _position_hitbox_forward() -> void:
	if hitbox:
		hitbox.position.x = facing_direction * abs(hitbox.position.x)

func _scan_for_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p = players[0]
		if is_instance_valid(p) and not p.is_dead:
			var dist: float = global_position.distance_to(p.global_position)
			if dist <= detection_radius:
				target_player = p

func _on_damage_received(incoming_attack: AttackData, attacker_pos: Vector2, result: Dictionary) -> void:
	if current_state == State.DEAD:
		return
	
	var dmg: float = result.get("final_damage", 10.0)
	var is_crit: bool = result.get("is_critical", false)
	var effect: String = result.get("status_effect", "None")
	
	current_health = max(0.0, current_health - dmg)
	current_poise -= (dmg * 1.2 if incoming_attack.breaks_guard else dmg * 0.6)
	
	# Apply Knockback
	var kb_dir: float = 1.0 if (global_position.x - attacker_pos.x) >= 0.0 else -1.0
	var kb_force: Vector2 = incoming_attack.knockback_force * 0.75
	velocity = Vector2(kb_dir * kb_force.x, kb_force.y)
	
	# Status effect application
	if effect != "None" and effect != "":
		CombatSystem.apply_status_effect(self, effect, result.get("status_duration", 3.0), result.get("status_potency", 5.0))
	
	_show_damage_popup(dmg, is_crit, effect)
	EventBus.enemy_damaged.emit(enemy_id, dmg, is_crit)
	
	if current_health <= 0.0:
		change_state(State.DEAD)
	elif current_poise <= 0.0 or incoming_attack.breaks_guard:
		is_staggered = true
		change_state(State.STAGGER)
	else:
		change_state(State.HURT)

func _on_parried_by_player(_attack: AttackData, is_perfect: bool, _hitbox_node: Area2D) -> void:
	is_staggered = true
	state_timer = 0.0
	current_poise = 0.0
	_show_text_popup("PARRIED!" if not is_perfect else "POSTURE BROKEN!", Color("#00f5d4"))
	change_state(State.STAGGER)

func _on_global_parry_resolved(success: bool, is_perfect: bool, attacker: Node2D) -> void:
	if attacker == self and success:
		is_staggered = true
		state_timer = 0.0
		current_poise = 0.0
		_show_text_popup("PARRIED!", Color("#00f5d4"))
		change_state(State.STAGGER)

func take_dot_damage(effect_name: String, amount: float) -> void:
	if current_state == State.DEAD:
		return
	current_health = max(0.0, current_health - amount)
	_show_damage_popup(amount, false, effect_name)
	if current_health <= 0.0:
		change_state(State.DEAD)

func _show_damage_popup(amount: float, is_crit: bool, effect: String) -> void:
	var msg: String = str(amount)
	if is_crit:
		msg += " CRIT!"
	if effect != "None" and effect != "":
		msg += " [" + effect + "]"
	_show_text_popup(msg, Color("#ef4444") if is_crit else Color("#fbbf24"))

func _show_text_popup(msg: String, col: Color) -> void:
	if float_label:
		float_label.text = msg
		float_label.modulate = col
		float_label.visible = true
		float_label.position.y = -36.0
		var tween = create_tween()
		tween.tween_property(float_label, "position:y", -50.0, 0.5)
		tween.tween_callback(func(): if is_instance_valid(float_label): float_label.visible = false)

func _on_death() -> void:
	enemy_died.emit(enemy_id, xp_reward)
	# 0.8s fade out before removing from tree
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)

func _apply_gravity(delta: float) -> void:
	var grav: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
	velocity.y = min(velocity.y + grav * delta, 500.0)

func _update_visual_orientation() -> void:
	if facing_direction != 0:
		scale.x = abs(scale.x) * facing_direction
