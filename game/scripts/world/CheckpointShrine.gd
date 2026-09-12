# CheckpointShrine.gd
# Interactive checkpoint shrine that heals the player, updates respawn point, and saves game state.
class_name CheckpointShrine
extends Area2D

const PlayerController = preload("res://scripts/player/PlayerController.gd")

signal shrine_activated(shrine_id: String, shrine_position: Vector2)

@export var shrine_id: String = "verdant_shrine_01"
@export var is_active: bool = false

@onready var prompt_label: Label = $PromptLabel

var _player_in_range = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt_label:
		prompt_label.visible = false
	
	if SaveManager.active_checkpoint_id == shrine_id:
		is_active = true

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_just_pressed("jump"): # Or interact key
		activate_shrine(_player_in_range)

func activate_shrine(player: PlayerController) -> void:
	is_active = true
	SaveManager.active_checkpoint_id = shrine_id
	SaveManager.active_checkpoint_position = global_position
	
	# Heal and restore player
	player.current_health = player.max_health
	player.current_stamina = player.max_stamina
	player.current_energy = player.max_energy
	player.health_changed.emit(player.current_health, player.max_health)
	player.stamina_changed.emit(player.current_stamina, player.max_stamina)
	player.energy_changed.emit(player.current_energy, player.max_energy)
	
	# Save game
	SaveManager.save_game(1, player)
	shrine_activated.emit(shrine_id, global_position)
	
	if prompt_label:
		prompt_label.text = "SHRINE RESTORED"
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerController:
		_player_in_range = body
		if prompt_label:
			prompt_label.text = "[W / SPACE] Rest at Shrine"
			prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body is PlayerController:
		_player_in_range = null
		if prompt_label:
			prompt_label.visible = false

func _draw() -> void:
	# Shrine monolith drawing
	var shrine_col: Color = Color("#00e5a3") if is_active else Color("#64748b")
	# Base pedestal
	draw_rect(Rect2(-16, -6, 32, 6), Color("#1e293b"))
	# Monolith pillar
	draw_rect(Rect2(-8, -32, 16, 26), Color("#334155"))
	# Glowing runic crystal core
	draw_circle(Vector2(0, -20), 4.0, shrine_col)
	if is_active:
		draw_arc(Vector2(0, -20), 8.0, 0.0, TAU, 12, Color(shrine_col, 0.4), 1.5)
