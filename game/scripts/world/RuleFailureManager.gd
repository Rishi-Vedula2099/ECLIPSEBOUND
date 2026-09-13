# RuleFailureManager.gd
# World 7 signature mechanic: Rule Failure temporary physics shifts and reality glitches.
class_name RuleFailureManager
extends Node2D

enum FailureGlitch {
	STABLE,             # Baseline physics
	INVERTED_GRAVITY,   # Gravity flipped upward (-980.0)
	TIME_DILATION,      # Global time scale 0.50 slow-motion
	FRICTION_COLLAPSE,  # Zero surface friction / ice sliding
	CORRUPTED_HITBOXES  # Glitch phase shifts causing erratic damage amplification
}

signal rule_failure_triggered(glitch: FailureGlitch, duration: float)
signal rule_failure_resolved()

@export var current_glitch: FailureGlitch = FailureGlitch.STABLE
@export var glitch_duration: float = 4.0
@export var is_chaos_mode: bool = true
@export var glitch_interval: float = 14.0

var interval_timer: float = 0.0
var active_glitch_timer: float = 0.0

func _physics_process(delta: float) -> void:
	if is_chaos_mode:
		if current_glitch == FailureGlitch.STABLE:
			interval_timer += delta
			if interval_timer >= glitch_interval:
				interval_timer = 0.0
				_trigger_random_rule_failure()
		else:
			active_glitch_timer += delta
			if active_glitch_timer >= glitch_duration:
				_restore_physics_rules()
	queue_redraw()

func trigger_specific_glitch(glitch: FailureGlitch, duration: float = 4.0) -> void:
	current_glitch = glitch
	glitch_duration = duration
	active_glitch_timer = 0.0
	rule_failure_triggered.emit(current_glitch, glitch_duration)

func _trigger_random_rule_failure() -> void:
	var glitches = [
		FailureGlitch.INVERTED_GRAVITY,
		FailureGlitch.TIME_DILATION,
		FailureGlitch.FRICTION_COLLAPSE,
		FailureGlitch.CORRUPTED_HITBOXES
	]
	var chosen = glitches[randi() % glitches.size()]
	trigger_specific_glitch(chosen, 4.0)

func _restore_physics_rules() -> void:
	current_glitch = FailureGlitch.STABLE
	active_glitch_timer = 0.0
	rule_failure_resolved.emit()

func get_gravity_multiplier() -> float:
	match current_glitch:
		FailureGlitch.INVERTED_GRAVITY:
			return -1.0
		_:
			return 1.0

func get_time_scale() -> float:
	match current_glitch:
		FailureGlitch.TIME_DILATION:
			return 0.5
		_:
			return 1.0

func _draw() -> void:
	if current_glitch == FailureGlitch.STABLE:
		# Idle NULL void rift
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 16, Color(0.3, 0.1, 0.4, 0.4), 1.0)
		return
	
	# Active glitch fractal rendering
	var glitch_col = Color(1.0, 0.0, 0.5, 0.8)
	draw_rect(Rect2(-25, -25, 50, 50), Color(0.05, 0.0, 0.1, 0.6), true)
	draw_line(Vector2(-30, 0), Vector2(30, 0), glitch_col, 2.0)
	draw_line(Vector2(0, -30), Vector2(0, 30), glitch_col, 2.0)
	
	# Corrupted digital artifacts
	for i in range(5):
		var rx = (randi() % 40) - 20
		var ry = (randi() % 40) - 20
		draw_rect(Rect2(rx, ry, 6, 2), Color(0.2, 1.0, 0.8, 0.7))
