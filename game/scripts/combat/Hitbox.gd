# Hitbox.gd
# Collision dispatcher representing active damage windows and attack delivery.
class_name Hitbox
extends Area2D

const AttackData = preload("res://scripts/combat/AttackData.gd")
const Hurtbox = preload("res://scripts/combat/Hurtbox.gd")

signal hit_registered(target_hurtbox: Hurtbox, result: Dictionary)

@export var attack_data: AttackData
@export var attacker_owner: Node2D

var _targets_hit_this_swing: Array[Hurtbox] = []
var _is_active: bool = false

func _ready() -> void:
	if not attacker_owner and get_parent() is Node2D:
		attacker_owner = get_parent()
	area_entered.connect(_on_area_entered)
	deactivate()

func activate(custom_attack_data: AttackData = null) -> void:
	if custom_attack_data:
		attack_data = custom_attack_data
	_targets_hit_this_swing.clear()
	_is_active = true
	monitoring = true
	monitorable = true
	# Immediate check for overlapping hurtboxes on activation frame
	var overlapping = get_overlapping_areas()
	for area in overlapping:
		_process_target_area(area)

func deactivate() -> void:
	_is_active = false
	monitoring = false
	monitorable = false
	_targets_hit_this_swing.clear()

func _on_area_entered(area: Area2D) -> void:
	if not _is_active:
		return
	_process_target_area(area)

func _process_target_area(area: Area2D) -> void:
	if area is Hurtbox and area != null and attack_data != null:
		var hurtbox: Hurtbox = area as Hurtbox
		if hurtbox in _targets_hit_this_swing:
			return # Avoid hitting the same hurtbox twice within the same swing
		
		# Prevent hitting self
		if hurtbox.entity_owner == attacker_owner:
			return
		
		_targets_hit_this_swing.append(hurtbox)
		var attacker_pos: Vector2 = attacker_owner.global_position if attacker_owner else global_position
		var result: Dictionary = hurtbox.receive_hit(attack_data, self, attacker_pos)
		hit_registered.emit(hurtbox, result)
