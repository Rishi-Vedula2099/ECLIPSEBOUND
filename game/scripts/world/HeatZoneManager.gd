# HeatZoneManager.gd
# World 3 signature mechanic: Dynamic shifting thermal hazards punishing camping.
class_name HeatZoneManager
extends Area2D

enum HeatState {
	DORMANT,   # Cool embers, 0 damage
	WARNING,   # Glowing fissures, telegraphing imminent eruption
	ACTIVE,    # Open magma vents, continuous heat buildup & damage
	ERUPTION   # Massive geyser burst, heavy fire damage and knockback
}

signal heat_state_changed(zone_id: String, new_state: HeatState)
signal entity_burned(entity: CharacterBody2D, damage: float)

@export var zone_id: String = "ashen_vent_01"
@export var dormant_duration: float = 4.0
@export var warning_duration: float = 1.5
@export var active_duration: float = 3.0
@export var eruption_duration: float = 1.0

@export var active_dps: float = 20.0
@export var eruption_damage: float = 65.0
@export var zone_radius: float = 75.0

var current_state: HeatState = HeatState.DORMANT
var state_timer: float = 0.0
var overlapping_entities: Array[CharacterBody2D] = []

func _ready() -> void:
	collision_layer = 0
	collision_mask = 4  # Player
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	state_timer += delta
	_update_zone_lifecycle(delta)
	
	if current_state == HeatState.ACTIVE:
		for body in overlapping_entities:
			if is_instance_valid(body):
				var dmg = active_dps * delta
				entity_burned.emit(body, dmg)
				if body.has_method("receive_damage"):
					body.receive_damage(dmg, global_position)
	queue_redraw()

func _update_zone_lifecycle(_delta: float) -> void:
	match current_state:
		HeatState.DORMANT:
			if state_timer >= dormant_duration:
				_set_state(HeatState.WARNING)
		HeatState.WARNING:
			if state_timer >= warning_duration:
				_set_state(HeatState.ACTIVE)
		HeatState.ACTIVE:
			if state_timer >= active_duration:
				_set_state(HeatState.ERUPTION)
		HeatState.ERUPTION:
			if state_timer >= eruption_duration:
				_set_state(HeatState.DORMANT)

func _set_state(new_state: HeatState) -> void:
	current_state = new_state
	state_timer = 0.0
	heat_state_changed.emit(zone_id, current_state)
	
	if current_state == HeatState.ERUPTION:
		_trigger_eruption_burst()

func _trigger_eruption_burst() -> void:
	for body in overlapping_entities:
		if is_instance_valid(body):
			entity_burned.emit(body, eruption_damage)
			if body.has_method("receive_damage"):
				body.receive_damage(eruption_damage, global_position)
			# Apply upward thermal launch
			if "velocity" in body:
				body.velocity.y = -350.0

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and not overlapping_entities.has(body):
		overlapping_entities.append(body)

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		overlapping_entities.erase(body)

func _draw() -> void:
	match current_state:
		HeatState.DORMANT:
			draw_circle(Vector2.ZERO, zone_radius, Color(0.2, 0.1, 0.05, 0.25))
			draw_arc(Vector2.ZERO, zone_radius, 0.0, TAU, 16, Color(0.4, 0.2, 0.1, 0.4), 1.5)
		HeatState.WARNING:
			var pulse = 0.5 + 0.5 * sin(state_timer * 10.0)
			draw_circle(Vector2.ZERO, zone_radius, Color(0.9, 0.4, 0.0, 0.35 + pulse * 0.2))
			draw_arc(Vector2.ZERO, zone_radius, 0.0, TAU, 24, Color(1.0, 0.5, 0.0, 0.8), 2.5)
		HeatState.ACTIVE:
			draw_circle(Vector2.ZERO, zone_radius, Color(0.9, 0.2, 0.0, 0.65))
			draw_arc(Vector2.ZERO, zone_radius, 0.0, TAU, 24, Color(1.0, 0.2, 0.0, 0.95), 3.0)
		HeatState.ERUPTION:
			draw_circle(Vector2.ZERO, zone_radius * 1.15, Color(1.0, 0.9, 0.2, 0.85))
			draw_line(Vector2(0, 0), Vector2(0, -90), Color(1.0, 0.6, 0.1, 0.9), 12.0)
