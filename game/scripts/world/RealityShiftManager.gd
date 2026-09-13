# RealityShiftManager.gd
# World 6 signature mechanic: Reality Shifts altering traversal, platforms, and gravity.
class_name RealityShiftManager
extends Node2D

enum RealmDimension {
	LUCID_DREAM,   # Normal floating geometry, low-gravity jumps, cyan runes
	NIGHTMARE      # Collapsed geometry, high gravity, purple void spikes, inverted paths
}

signal realm_shifted(dimension: RealmDimension, gravity_scale: float)
signal ethereal_platform_toggled(is_lucid: bool)

@export var current_dimension: RealmDimension = RealmDimension.LUCID_DREAM
@export var auto_shift_enabled: bool = false
@export var shift_interval: float = 12.0
@export var lucid_gravity_scale: float = 0.75
@export var nightmare_gravity_scale: float = 1.35

var shift_timer: float = 0.0

func _ready() -> void:
	_apply_dimension_effects()

func _physics_process(delta: float) -> void:
	if auto_shift_enabled:
		shift_timer += delta
		if shift_timer >= shift_interval:
			shift_timer = 0.0
			toggle_reality()
	queue_redraw()

func set_dimension(dimension: RealmDimension) -> void:
	current_dimension = dimension
	shift_timer = 0.0
	_apply_dimension_effects()

func toggle_reality() -> void:
	var next_dim = RealmDimension.NIGHTMARE if current_dimension == RealmDimension.LUCID_DREAM else RealmDimension.LUCID_DREAM
	set_dimension(next_dim)

func _apply_dimension_effects() -> void:
	var is_lucid = (current_dimension == RealmDimension.LUCID_DREAM)
	var grav = lucid_gravity_scale if is_lucid else nightmare_gravity_scale
	realm_shifted.emit(current_dimension, grav)
	ethereal_platform_toggled.emit(is_lucid)

func _draw() -> void:
	var is_lucid = (current_dimension == RealmDimension.LUCID_DREAM)
	var rune_col = Color(0.2, 0.8, 0.9, 0.6) if is_lucid else Color(0.8, 0.2, 0.9, 0.6)
	
	# Dream portal distortion ring
	draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 24, rune_col, 2.0)
	draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 16, rune_col.lightened(0.3), 1.5)
	
	# Shifting dream motes
	for i in range(6):
		var angle = (float(i) / 6.0) * TAU + (shift_timer * 1.5)
		var mote_pos = Vector2(cos(angle), sin(angle)) * 24.0
		draw_circle(mote_pos, 2.0, rune_col)
