# TrainingDummy.gd
# Interactive training dummy for testing hit detection, damage math, combos, i-frames, and parries.
class_name TrainingDummy
extends CharacterBody2D

const AttackData = preload("res://scripts/combat/AttackData.gd")
const Hitbox = preload("res://scripts/combat/Hitbox.gd")
const Hurtbox = preload("res://scripts/combat/Hurtbox.gd")

signal dummy_hit(damage: float, is_critical: bool, effect: String)
signal dummy_staggered(duration: float)

@export var max_health: float = 500.0
@export var defense: int = 15
@export var attack_interval: float = 3.5 # Attacks periodically to let player practice parrying & dodging
@export var attack_data: AttackData

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Hitbox
@onready var float_label: Label = $FloatingText

var current_health: float = 500.0
var attack_timer: float = 0.0
var is_telegraphing: bool = false
var is_staggered: bool = false
var stagger_timer: float = 0.0

func _ready() -> void:
	current_health = max_health
	if not attack_data and ResourceLoader.exists("res://data/attacks/dummy_attack.tres"):
		attack_data = load("res://data/attacks/dummy_attack.tres")
	
	if hurtbox:
		hurtbox.damage_received.connect(_on_damage_received)
		hurtbox.defense_stat = defense
	
	if hitbox:
		hitbox.attack_data = attack_data
	
	if float_label:
		float_label.visible = false
	
	CombatSystem.parry_resolved.connect(_on_parry_resolved)

func _physics_process(delta: float) -> void:
	# Stagger recovery
	if is_staggered:
		stagger_timer -= delta
		if stagger_timer <= 0.0:
			is_staggered = false
			queue_redraw()
		return
	
	# Attack cycle
	attack_timer += delta
	if attack_timer >= (attack_interval - 0.5) and not is_telegraphing:
		# Start telegraph warning
		is_telegraphing = true
		queue_redraw()
	
	if attack_timer >= attack_interval:
		attack_timer = 0.0
		is_telegraphing = false
		_execute_attack()

func _execute_attack() -> void:
	if is_staggered or not hitbox or not attack_data:
		return
	
	hitbox.activate(attack_data)
	queue_redraw()
	
	# Deactivate hitbox after active duration
	get_tree().create_timer(attack_data.active_time).timeout.connect(func():
		if is_instance_valid(hitbox):
			hitbox.deactivate()
			queue_redraw()
	)

func _on_damage_received(_incoming_attack: AttackData, _attacker_pos: Vector2, result: Dictionary) -> void:
	var dmg: float = result.get("final_damage", 15.0)
	var is_crit: bool = result.get("is_critical", false)
	var effect: String = result.get("status_effect", "None")
	
	current_health = max(0.0, current_health - dmg)
	CombatSystem.register_hit_landed()
	
	# Apply status effect if present
	if effect != "None" and effect != "":
		CombatSystem.apply_status_effect(self, effect, result.get("status_duration", 3.0), result.get("status_potency", 5.0))
	
	_show_damage_number(dmg, is_crit, effect)
	dummy_hit.emit(dmg, is_crit, effect)
	
	if current_health <= 0.0:
		# Reset dummy after short delay
		get_tree().create_timer(1.5).timeout.connect(reset_dummy)
	
	queue_redraw()

func _on_parry_resolved(success: bool, is_perfect: bool, attacker: Node2D) -> void:
	if attacker == self and success:
		# Player parried our attack! Stagger dummy
		is_staggered = true
		is_telegraphing = false
		stagger_timer = 1.5 if is_perfect else 0.8
		if hitbox:
			hitbox.deactivate()
		_show_text("PARRIED!" if not is_perfect else "PERFECT PARRY!", Color("#00f5d4"))
		dummy_staggered.emit(stagger_timer)
		queue_redraw()

func take_dot_damage(effect_name: String, amount: float) -> void:
	current_health = max(0.0, current_health - amount)
	_show_damage_number(amount, false, effect_name)
	queue_redraw()

func _show_damage_number(amount: float, is_crit: bool, effect: String) -> void:
	var text: String = str(amount)
	if is_crit:
		text += " CRIT!"
	if effect != "None" and effect != "":
		text += " [" + effect + "]"
	_show_text(text, Color("#ff3860") if is_crit else Color("#fbbf24"))

func _show_text(text: String, color: Color) -> void:
	if float_label:
		float_label.text = text
		float_label.modulate = color
		float_label.visible = true
		float_label.position.y = -48.0
		var tween = create_tween()
		tween.tween_property(float_label, "position:y", -64.0, 0.6)
		tween.tween_callback(func(): if is_instance_valid(float_label): float_label.visible = false)

func reset_dummy() -> void:
	current_health = max_health
	is_staggered = false
	is_telegraphing = false
	attack_timer = 0.0
	queue_redraw()

func _draw() -> void:
	# Wooden post & straw torso
	draw_rect(Rect2(-3, -36, 6, 36), Color("#78350f")) # Wood pole
	draw_rect(Rect2(-10, -28, 20, 18), Color("#d97706")) # Straw target body
	
	# Target rings
	draw_circle(Vector2(0, -19), 6.0, Color("#ef4444"))
	draw_circle(Vector2(0, -19), 3.0, Color("#ffffff"))
	
	# Telegraph warning flash
	if is_telegraphing:
		draw_circle(Vector2(0, -42), 4.0, Color("#ef4444"))
		draw_line(Vector2(-12, -42), Vector2(12, -42), Color("#ef4444"), 2.0)
	
	# Stagger stars
	if is_staggered:
		draw_circle(Vector2(-6, -42), 2.5, Color("#fbbf24"))
		draw_circle(Vector2(6, -42), 2.5, Color("#fbbf24"))
	
	# Attack active aura
	if hitbox and hitbox._is_active:
		draw_arc(Vector2(-14, -18), 16.0, -1.0, 1.0, 8, Color("#ef4444"), 3.0)
