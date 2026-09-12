# Hurtbox.gd
# Collision receiver for receiving attacks, handling i-frames, and resolving parries.
class_name Hurtbox
extends Area2D

const AttackData = preload("res://scripts/combat/AttackData.gd")

signal damage_received(incoming_attack: AttackData, attacker_position: Vector2, result: Dictionary)
signal parry_successful(incoming_attack: AttackData, is_perfect: bool, attacker_hitbox: Area2D)
signal hit_ignored_invulnerable(incoming_attack: AttackData)

@export var is_invulnerable: bool = false
@export var is_parrying: bool = false
@export var is_perfect_parrying: bool = false
@export var defense_stat: int = 10
@export var entity_owner: Node2D

func _ready() -> void:
	if not entity_owner and get_parent() is Node2D:
		entity_owner = get_parent()

func receive_hit(attack_data: AttackData, attacker_hitbox: Area2D, attacker_pos: Vector2) -> Dictionary:
	# 1. Check Invulnerability (Dodge i-frames)
	if is_invulnerable:
		hit_ignored_invulnerable.emit(attack_data)
		return {"status": "evaded", "damage": 0.0}
	
	# 2. Check Parry
	if is_parrying and attack_data.can_be_parried:
		var perfect: bool = is_perfect_parrying
		parry_successful.emit(attack_data, perfect, attacker_hitbox)
		return {
			"status": "parried",
			"perfect": perfect,
			"damage": 0.0,
			"attacker_staggered": true
		}
	
	# 3. Calculate Damage using CombatSystem
	var damage_res: Dictionary = CombatSystem.calculate_damage(attack_data, defense_stat)
	damage_received.emit(attack_data, attacker_pos, damage_res)
	return damage_res
