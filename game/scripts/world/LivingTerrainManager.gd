# LivingTerrainManager.gd
# World 1 signature mechanic: Dynamic root growth reacting to combat and sealing/opening routes.
class_name LivingTerrainManager
extends Node2D

signal root_barrier_extended(barrier_id: String)
signal root_barrier_retracted(barrier_id: String)

@export var barrier_id: String = "boss_arena_gate"
@export var is_extended: bool = false
@export var barrier_height: float = 64.0
@export var barrier_width: float = 16.0

@onready var collision_shape: CollisionShape2D = $StaticBody2D/CollisionShape2D

var current_growth_ratio: float = 0.0
var target_growth_ratio: float = 0.0

func _ready() -> void:
	if is_extended:
		target_growth_ratio = 1.0
		current_growth_ratio = 1.0
	else:
		target_growth_ratio = 0.0
		current_growth_ratio = 0.0
	_update_collision()

func _physics_process(delta: float) -> void:
	if not is_equal_approx(current_growth_ratio, target_growth_ratio):
		current_growth_ratio = move_toward(current_growth_ratio, target_growth_ratio, 2.0 * delta)
		_update_collision()
		queue_redraw()

func extend_barrier() -> void:
	is_extended = true
	target_growth_ratio = 1.0
	root_barrier_extended.emit(barrier_id)

func retract_barrier() -> void:
	is_extended = false
	target_growth_ratio = 0.0
	root_barrier_retracted.emit(barrier_id)

func _update_collision() -> void:
	if collision_shape:
		# Enable collision when roots are grown past 50%
		collision_shape.set_deferred("disabled", current_growth_ratio < 0.5)

func _draw() -> void:
	if current_growth_ratio <= 0.05:
		return
	
	var root_col = Color("#3f2e18")
	var leaf_col = Color("#15803d")
	var height = barrier_height * current_growth_ratio
	
	# Tangled root trunk
	draw_line(Vector2(-4, 0), Vector2(-4, -height), root_col, 5.0)
	draw_line(Vector2(4, 0), Vector2(4, -height), root_col, 5.0)
	draw_line(Vector2(0, 0), Vector2(0, -height), root_col.darkened(0.2), 6.0)
	
	# Interlocking horizontal branches
	for y in range(8, int(height), 12):
		draw_line(Vector2(-8, -y), Vector2(8, -y - 4), root_col, 3.0)
		draw_circle(Vector2(-6, -y - 2), 2.0, leaf_col)
		draw_circle(Vector2(6, -y - 6), 2.0, leaf_col)
