# WaterDepthManager.gd
# World 2 signature mechanic: Water Depth altering player movement & fog visibility.
class_name WaterDepthManager
extends Area2D

enum DepthTier {
	SHALLOW,    # Ankle-deep: 10% movement slow, minimal fog
	DEEP,       # Waist-deep: 30% movement slow, 40% dash distance reduction, moderate fog
	SUBMERGED   # Fully submerged: 50% movement slow, altered buoyancy, heavy black water fog
}

signal depth_changed(tier: DepthTier, depth_ratio: float)

@export var depth_tier: DepthTier = DepthTier.DEEP
@export var surface_y: float = 200.0
@export var max_depth: float = 120.0
@export var water_color: Color = Color(0.02, 0.08, 0.12, 0.75)
@export var fog_density: float = 0.55

var affected_bodies: Array[CharacterBody2D] = []

func _ready() -> void:
	collision_layer = 0
	collision_mask = 4  # Layer 3 (Player) and Layer 4 (Enemy)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	for body in affected_bodies:
		if is_instance_valid(body):
			_apply_water_physics(body, delta)
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and not affected_bodies.has(body):
		affected_bodies.append(body)
		depth_changed.emit(depth_tier, get_depth_ratio(body.global_position.y))

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		affected_bodies.erase(body)

func get_depth_ratio(body_y: float) -> float:
	var submerged_amount = clampf((body_y - surface_y) / max_depth, 0.0, 1.0)
	return submerged_amount

func get_speed_multiplier(body_y: float) -> float:
	var ratio = get_depth_ratio(body_y)
	match depth_tier:
		DepthTier.SHALLOW:
			return 1.0 - (0.15 * ratio)
		DepthTier.DEEP:
			return 1.0 - (0.35 * ratio)
		DepthTier.SUBMERGED:
			return 1.0 - (0.55 * ratio)
	return 1.0

func get_dash_efficiency(body_y: float) -> float:
	var ratio = get_depth_ratio(body_y)
	match depth_tier:
		DepthTier.SHALLOW:
			return 0.90
		DepthTier.DEEP:
			return 0.65
		DepthTier.SUBMERGED:
			return 0.40
	return 1.0

func _apply_water_physics(body: CharacterBody2D, delta: float) -> void:
	var ratio = get_depth_ratio(body.global_position.y)
	var speed_mult = get_speed_multiplier(body.global_position.y)
	
	# Apply liquid drag
	body.velocity.x *= (1.0 - (0.40 * ratio * delta))
	
	# Buoyancy counteracting gravity when submerged
	if ratio > 0.4:
		var buoyancy = 380.0 * ratio
		body.velocity.y -= buoyancy * delta

func _draw() -> void:
	# Draw dark water body
	var rect = Rect2(Vector2(-1000, surface_y), Vector2(6000, max_depth + 200))
	draw_rect(rect, water_color, true)
	
	# Murky surface ripple
	var surface_col = Color(0.1, 0.35, 0.45, 0.8)
	draw_line(Vector2(-1000, surface_y), Vector2(5000, surface_y), surface_col, 2.0)
