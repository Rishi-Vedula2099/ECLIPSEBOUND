# DrownedWoodsWorld.gd
# World 2 Campaign Level: The Drowned Woods.
# Core Mechanic: Water Depth altering movement and visibility.
class_name DrownedWoodsWorld
extends Node2D

const PlayerController = preload("res://scripts/player/PlayerController.gd")
const WaterDepthManager = preload("res://scripts/world/WaterDepthManager.gd")
const DrownedMatriarch = preload("res://scripts/bosses/DrownedMatriarch.gd")
const GameCamera2D = preload("res://scripts/core/GameCamera2D.gd")

@onready var player: PlayerController = $Player
@onready var camera: GameCamera2D = $GameCamera2D
@onready var water_depth_manager: WaterDepthManager = $WaterDepthManager
@onready var drowned_matriarch: DrownedMatriarch = $DrownedMatriarch

var is_boss_fight_active: bool = false
var is_world_completed: bool = false

func _ready() -> void:
	player.add_to_group("player")
	EventBus.world_changed.emit(2, "The Drowned Woods")
	AudioManager.set_music_state("exploration")
	
	EventBus.player_died.connect(_on_player_died)
	
	if drowned_matriarch:
		drowned_matriarch.boss_defeated.connect(_on_boss_defeated)
		drowned_matriarch.boss_phase_transition.connect(_on_boss_phase_transition)

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
		"world_id": 2,
		"unlocked_flags": ["world_2_completed", "drowned_oath_unlocked"],
		"bosses_defeated": ["drowned_matriarch"]
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
	# Submerged ground & dark water bed
	draw_rect(Rect2(0, 240, 4800, 100), Color("#071924"), true)
	draw_line(Vector2(0, 240), Vector2(4800, 240), Color("#0284c7"), 2.0)
	
	# Atmospheric swamp mist motes
	for i in range(16):
		var fx = 500 + (i * 120)
		var fy = 160 + sin(i) * 20
		draw_circle(Vector2(fx, fy), 2.0, Color("#38bdf8", 0.4))
