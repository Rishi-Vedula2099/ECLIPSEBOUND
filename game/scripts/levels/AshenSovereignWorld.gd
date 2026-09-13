# AshenSovereignWorld.gd
# World 3 Campaign Level: The Ashen Sovereign.
# Core Mechanic: Heat Zones dynamic shifting environmental hazards.
class_name AshenSovereignWorld
extends Node2D

const PlayerController = preload("res://scripts/player/PlayerController.gd")
const HeatZoneManager = preload("res://scripts/world/HeatZoneManager.gd")
const AshKing = preload("res://scripts/bosses/AshKing.gd")
const GameCamera2D = preload("res://scripts/core/GameCamera2D.gd")

@onready var player: PlayerController = $Player
@onready var camera: GameCamera2D = $GameCamera2D
@onready var ash_king: AshKing = $AshKing

var is_boss_fight_active: bool = false
var is_world_completed: bool = false

func _ready() -> void:
	player.add_to_group("player")
	EventBus.world_changed.emit(3, "The Ashen Sovereign")
	AudioManager.set_music_state("exploration")
	
	EventBus.player_died.connect(_on_player_died)
	
	if ash_king:
		ash_king.boss_defeated.connect(_on_boss_defeated)
		ash_king.boss_phase_transition.connect(_on_boss_phase_transition)

func _on_boss_arena_trigger_entered(body: Node2D) -> void:
	if body is PlayerController and not is_boss_fight_active and not is_world_completed:
		is_boss_fight_active = true
		AudioManager.set_music_state("boss_phase_1")

func _on_boss_phase_transition(phase: int) -> void:
	if phase == 2:
		AudioManager.set_music_state("boss_phase_2")

func _on_boss_defeated() -> void:
	is_boss_fight_active = false
	is_world_completed = true
	AudioManager.set_music_state("victory")
	
	SaveManager.save_game(1, player, {
		"world_id": 3,
		"unlocked_flags": ["world_3_completed", "ashen_sovereign_unlocked"],
		"bosses_defeated": ["ash_king"]
	})

func _on_player_died(_cause: String, _death_pos: Vector2) -> void:
	if is_boss_fight_active:
		is_boss_fight_active = false
		AudioManager.set_music_state("exploration")
	
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(player):
			player.respawn(SaveManager.active_checkpoint_position)
	)

func _draw() -> void:
	# Obsidian ground & volcanic floor
	draw_rect(Rect2(0, 240, 4800, 100), Color("#1c0a06"), true)
	draw_line(Vector2(0, 240), Vector2(4800, 240), Color("#ea580c"), 2.0)
	
	# Floating embers
	for i in range(20):
		var fx = 300 + (i * 100)
		var fy = 150 + cos(i) * 25
		draw_circle(Vector2(fx, fy), 1.5, Color("#f97316", 0.7))
