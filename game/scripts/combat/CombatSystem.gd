# CombatSystem.gd
# Centralized combat resolution engine for ECLIPSEBOUND.
# Manages damage formulas, critical hits, status effects, parries, and combos.
extends Node

const AttackData = preload("res://scripts/combat/AttackData.gd")

signal combo_updated(current_combo: int, damage_multiplier: float)
signal combo_reset()
signal parry_resolved(success: bool, is_perfect: bool, attacker: Node2D)
signal status_applied(target: Node2D, status_name: String, duration: float)

# Combo System State
var current_combo: int = 0
var combo_timer: float = 0.0
const COMBO_TIMEOUT: float = 2.5
const COMBO_DAMAGE_SCALING_PER_HIT: float = 0.02
const MAX_COMBO_BONUS: float = 0.50

# Active Status Effects per entity: { entity_id: { status_name: { "duration": float, "potency": float, "tick_timer": float } } }
var _active_status_effects: Dictionary = {}

func _physics_process(delta: float) -> void:
	# Update combo decay
	if current_combo > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			reset_combo()
	
	# Update status effect ticks
	_process_status_effects(delta)

# --- Damage Calculations ---

func calculate_damage(attack: AttackData, target_defense: int, attacker_crit_stat: int = 10, rng_seed: int = 0) -> Dictionary:
	var base_dmg: float = attack.damage
	
	# 1. Combo scaling bonus
	var combo_mult: float = 1.0 + min(current_combo * COMBO_DAMAGE_SCALING_PER_HIT, MAX_COMBO_BONUS)
	base_dmg *= combo_mult
	
	# 2. Critical hit calculation
	var crit_chance: float = clamp(0.05 + (attacker_crit_stat * 0.008), 0.05, 0.75)
	var crit_multiplier: float = 1.5 + (attacker_crit_stat * 0.02)
	var is_crit: bool = (randf() < crit_chance) if rng_seed == 0 else false
	
	var post_crit_dmg: float = base_dmg * (crit_multiplier if is_crit else 1.0)
	
	# 3. Soft-capped Defense reduction: Armor / (Armor + 100)
	var armor: float = max(0.0, float(target_defense) * 4.0)
	var damage_reduction: float = armor / (armor + 100.0)
	var final_damage: float = max(1.0, post_crit_dmg * (1.0 - damage_reduction))
	
	return {
		"raw_damage": attack.damage,
		"final_damage": snapped(final_damage, 0.1),
		"is_critical": is_crit,
		"damage_reduction_ratio": snapped(damage_reduction, 0.001),
		"element": attack.element,
		"knockback": attack.knockback_force,
		"status_effect": attack.status_effect,
		"status_duration": attack.status_duration,
		"status_potency": attack.status_potency
	}

# --- Combo System ---

func register_hit_landed() -> void:
	current_combo += 1
	combo_timer = COMBO_TIMEOUT
	var bonus: float = 1.0 + min(current_combo * COMBO_DAMAGE_SCALING_PER_HIT, MAX_COMBO_BONUS)
	combo_updated.emit(current_combo, bonus)

func reset_combo() -> void:
	if current_combo > 0:
		current_combo = 0
		combo_timer = 0.0
		combo_reset.emit()

# --- Parry Evaluation ---

func evaluate_parry(time_into_parry: float, max_parry_window: float = 0.35, perfect_window: float = 0.15) -> Dictionary:
	if time_into_parry <= perfect_window:
		return {"success": true, "perfect": true, "damage_negation": 1.0, "stagger_attacker": true}
	elif time_into_parry <= max_parry_window:
		return {"success": true, "perfect": false, "damage_negation": 1.0, "stagger_attacker": false}
	return {"success": false, "perfect": false, "damage_negation": 0.0, "stagger_attacker": false}

# --- Status Effect System ---

func apply_status_effect(target: Node2D, status_name: String, duration: float, potency: float) -> void:
	if not target or status_name == "None" or status_name == "":
		return
	
	var entity_id: int = target.get_instance_id()
	if not _active_status_effects.has(entity_id):
		_active_status_effects[entity_id] = {}
	
	_active_status_effects[entity_id][status_name] = {
		"duration": duration,
		"potency": potency,
		"tick_timer": 0.0,
		"target_node": target
	}
	status_applied.emit(target, status_name, duration)

func is_affected_by(target: Node2D, status_name: String) -> bool:
	if not target:
		return false
	var entity_id: int = target.get_instance_id()
	return _active_status_effects.has(entity_id) and _active_status_effects[entity_id].has(status_name)

func _process_status_effects(delta: float) -> void:
	var expired_entities: Array = []
	
	for entity_id in _active_status_effects.keys():
		var effects: Dictionary = _active_status_effects[entity_id]
		var expired_effects: Array = []
		
		for effect_name in effects.keys():
			var data: Dictionary = effects[effect_name]
			var target_node: Node2D = data.get("target_node")
			
			if not is_instance_valid(target_node):
				expired_effects.append(effect_name)
				continue
			
			data["duration"] -= delta
			data["tick_timer"] += delta
			
			# Tick DoTs every 1.0 second
			if data["tick_timer"] >= 1.0:
				data["tick_timer"] -= 1.0
				_tick_status_damage(target_node, effect_name, data["potency"])
			
			if data["duration"] <= 0.0:
				expired_effects.append(effect_name)
		
		for eff in expired_effects:
			effects.erase(eff)
		
		if effects.is_empty():
			expired_entities.append(entity_id)
	
	for eid in expired_entities:
		_active_status_effects.erase(eid)

func _tick_status_damage(target: Node2D, effect_name: String, potency: float) -> void:
	if target.has_method("take_dot_damage"):
		target.take_dot_damage(effect_name, potency)
