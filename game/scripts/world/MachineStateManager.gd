# MachineStateManager.gd
# World 5 signature mechanic: Powering and destroying systems altering industrial hazards.
class_name MachineStateManager
extends Node2D

enum PowerState {
	NORMAL,     # Baseline factory operation
	OVERDRIVE,  # Conveyors fast, high-frequency electric sparks, doors open
	LOCKDOWN,   # Forcefields active, security turrets active, doors sealed
	VENTING     # Steam bursts venting across walkways, reducing visibility
}

signal power_state_changed(new_state: PowerState)
signal system_overloaded(system_name: String)

@export var current_state: PowerState = PowerState.NORMAL
@export var cycle_duration: float = 8.0
@export var is_auto_cycling: bool = true

@export var conveyor_speed: float = 80.0
@export var is_electric_floor_hot: bool = false
@export var is_forcefield_sealed: bool = false
@export var steam_hazard_active: bool = false

var timer: float = 0.0

func _ready() -> void:
	_apply_state_effects()

func _physics_process(delta: float) -> void:
	if is_auto_cycling:
		timer += delta
		if timer >= cycle_duration:
			timer = 0.0
			_cycle_to_next_state()
	queue_redraw()

func set_power_state(state: PowerState) -> void:
	current_state = state
	timer = 0.0
	_apply_state_effects()
	power_state_changed.emit(current_state)

func _cycle_to_next_state() -> void:
	var next_state = (int(current_state) + 1) % 4
	set_power_state(next_state as PowerState)

func _apply_state_effects() -> void:
	match current_state:
		PowerState.NORMAL:
			conveyor_speed = 80.0
			is_electric_floor_hot = false
			is_forcefield_sealed = false
			steam_hazard_active = false
		PowerState.OVERDRIVE:
			conveyor_speed = 180.0
			is_electric_floor_hot = true
			is_forcefield_sealed = false
			steam_hazard_active = false
		PowerState.LOCKDOWN:
			conveyor_speed = 0.0
			is_electric_floor_hot = false
			is_forcefield_sealed = true
			steam_hazard_active = false
		PowerState.VENTING:
			conveyor_speed = 60.0
			is_electric_floor_hot = false
			is_forcefield_sealed = false
			steam_hazard_active = true

func _draw() -> void:
	# Draw clockwork generator icon & power grid status
	var gear_col = Color(0.6, 0.45, 0.2)
	draw_circle(Vector2.ZERO, 16.0, gear_col)
	draw_circle(Vector2.ZERO, 6.0, Color(0.1, 0.1, 0.12))
	
	# Teeth
	for i in range(8):
		var angle = (float(i) / 8.0) * TAU
		var tooth_pos = Vector2(cos(angle), sin(angle)) * 18.0
		draw_rect(Rect2(tooth_pos.x - 2, tooth_pos.y - 2, 4, 4), gear_col)
	
	# State indicator LED
	var led_col = Color.GREEN
	match current_state:
		PowerState.OVERDRIVE: led_col = Color.ORANGE
		PowerState.LOCKDOWN: led_col = Color.RED
		PowerState.VENTING: led_col = Color.CYAN
	draw_circle(Vector2(0, -26), 4.0, led_col)
