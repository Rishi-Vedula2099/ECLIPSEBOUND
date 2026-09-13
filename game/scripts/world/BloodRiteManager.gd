# BloodRiteManager.gd
# World 4 signature mechanic: Sanguine sacrifice choices altering encounter dynamics.
class_name BloodRiteManager
extends Node2D

enum RiteType {
	NONE,
	SANGUINE_POWER,   # Sacrifice 25% max HP -> Gain +35% attack damage for 30s
	VAMPIRIC_COVEN,   # Sacrifice 40% max HP -> Gain 15% lifesteal on hit
	CURSED_OFFERING   # Sacrifice 50% max HP -> Enemies drop double loot, but inflict Bleed
}

signal rite_activated(rite: RiteType, hp_cost_ratio: float, buff_duration: float)
signal blood_pool_stepped(entity: CharacterBody2D, is_active: bool)

@export var altar_id: String = "cathedral_altar_01"
@export var active_rite: RiteType = RiteType.NONE
@export var buff_remaining_time: float = 0.0
@export var damage_multiplier: float = 1.0
@export var lifesteal_percent: float = 0.0

var is_altar_used: bool = false

func _physics_process(delta: float) -> void:
	if buff_remaining_time > 0.0:
		buff_remaining_time -= delta
		if buff_remaining_time <= 0.0:
			_clear_rite_buffs()

func offer_sacrifice(player: CharacterBody2D, rite: RiteType) -> bool:
	if is_altar_used or rite == RiteType.NONE:
		return false
	
	var hp_cost_pct = 0.0
	match rite:
		RiteType.SANGUINE_POWER:
			hp_cost_pct = 0.25
			damage_multiplier = 1.35
			lifesteal_percent = 0.0
			buff_remaining_time = 30.0
		RiteType.VAMPIRIC_COVEN:
			hp_cost_pct = 0.40
			damage_multiplier = 1.10
			lifesteal_percent = 0.15
			buff_remaining_time = 45.0
		RiteType.CURSED_OFFERING:
			hp_cost_pct = 0.50
			damage_multiplier = 1.50
			lifesteal_percent = 0.05
			buff_remaining_time = 60.0
	
	active_rite = rite
	is_altar_used = true
	
	# Apply HP sacrifice to player
	if player and "current_health" in player:
		var sacrifice_amount = player.max_health * hp_cost_pct
		player.current_health = max(1.0, player.current_health - sacrifice_amount)
	
	rite_activated.emit(rite, hp_cost_pct, buff_remaining_time)
	return true

func _clear_rite_buffs() -> void:
	active_rite = RiteType.NONE
	damage_multiplier = 1.0
	lifesteal_percent = 0.0
	buff_remaining_time = 0.0

func _draw() -> void:
	# Gothic blood chalice & stone altar
	var stone_col = Color(0.18, 0.15, 0.18)
	var blood_col = Color(0.85, 0.05, 0.15, 0.9) if not is_altar_used else Color(0.3, 0.1, 0.1, 0.5)
	
	# Pedestal
	draw_rect(Rect2(-16, -24, 32, 24), stone_col)
	# Chalice basin
	draw_arc(Vector2(0, -28), 12.0, 0.0, PI, 12, stone_col.lightened(0.2), 3.0)
	# Glowing blood liquid
	draw_circle(Vector2(0, -26), 6.0, blood_col)
