# TestArena.gd
# Interactive test arena proving combat, platforming, hazards, checkpoints, and save/load.
class_name TestArena
extends Node2D

const PlayerController = preload("res://scripts/player/PlayerController.gd")
const CheckpointShrine = preload("res://scripts/world/CheckpointShrine.gd")
const TrainingDummy = preload("res://scripts/enemies/TrainingDummy.gd")
const GameCamera2D = preload("res://scripts/core/GameCamera2D.gd")
const AttackData = preload("res://scripts/combat/AttackData.gd")

@onready var player: PlayerController = $Player
@onready var shrine: CheckpointShrine = $CheckpointShrine
@onready var dummy: TrainingDummy = $TrainingDummy
@onready var camera: GameCamera2D = $GameCamera2D

func _ready() -> void:
	# Add player to player group for global lookups
	player.add_to_group("player")
	
	# Connect player death to respawn sequence
	EventBus.player_died.connect(_on_player_died)
	
	# Try loading existing save or set checkpoint to initial shrine
	if SaveManager.has_save(1):
		var save_data = SaveManager.load_game(1)
		if not save_data.is_empty() and save_data.has("player"):
			player.load_save_state(save_data["player"])
	else:
		SaveManager.active_checkpoint_id = shrine.shrine_id
		SaveManager.active_checkpoint_position = shrine.global_position

func _on_player_died(_cause: String, _death_pos: Vector2) -> void:
	# 1.5 second delay before respawning at active checkpoint
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(player):
			player.respawn(SaveManager.active_checkpoint_position)
			if is_instance_valid(dummy):
				dummy.reset_dummy()
	)

func _on_hazard_body_entered(body: Node2D) -> void:
	if body is PlayerController and not body.is_dead:
		# Hazard damage
		var hazard_attack = AttackData.new()
		hazard_attack.attack_name = "Void Spikes"
		hazard_attack.damage = 40.0
		hazard_attack.knockback_force = Vector2(0.0, -260.0)
		body.hurtbox.receive_hit(hazard_attack, null, body.global_position + Vector2(0, 10))

func _draw() -> void:
	# Atmospheric background gradient & moonlit ruin backdrop
	draw_rect(Rect2(-100, -200, 1200, 500), Color("#0a0d14"), true) # Deep void sky
	
	# Distant Eclipse Moon
	draw_circle(Vector2(240, 40), 28.0, Color("#1e1b4b")) # Moon silhouette
	draw_arc(Vector2(240, 40), 28.0, -0.8, 1.2, 16, Color("#a855f7"), 2.0) # Eclipse rim glow
	
	# Arena Stone Floor Decor
	draw_rect(Rect2(0, 210, 800, 60), Color("#1e293b"), true) # Base foundation
	draw_line(Vector2(0, 210), Vector2(800, 210), Color("#00e5a3"), 2.0) # Ancient moss rim
	
	# Platform 1
	draw_rect(Rect2(180, 150, 100, 10), Color("#334155"), true)
	draw_line(Vector2(180, 150), Vector2(280, 150), Color("#64748b"), 1.5)
	
	# Platform 2
	draw_rect(Rect2(340, 110, 110, 10), Color("#334155"), true)
	draw_line(Vector2(340, 110), Vector2(450, 110), Color("#64748b"), 1.5)
	
	# Hazard Spikes (between x=520 and x=620)
	for x in range(520, 620, 10):
		draw_line(Vector2(x, 210), Vector2(x + 5, 195), Color("#ef4444"), 2.0)
		draw_line(Vector2(x + 5, 195), Vector2(x + 10, 210), Color("#ef4444"), 2.0)
