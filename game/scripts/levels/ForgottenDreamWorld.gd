# ForgottenDreamWorld.gd
# World 6 Campaign Level: The Forgotten Dream.
# Core Mechanic: Reality Shift traversal transformations.
class_name ForgottenDreamWorld
extends Node2D

const PlayerController = preload("res://scripts/player/PlayerController.gd")
const RealityShiftManager = preload("res://scripts/world/RealityShiftManager.gd")
const TheDreamEater = preload("res://scripts/bosses/TheDreamEater.gd")
const GameCamera2D = preload("res://scripts/core/GameCamera2D.gd")

@onready var player: PlayerController = $Player
@onready var camera: GameCamera2D = $GameCamera2D
@onready var the_dream_eater: TheDreamEater = $TheDreamEater

var is_boss_fight_active: bool = false
var is_world_completed: bool = false

func _ready() -> void:
	player.add_to_group("player")
	EventBus.world_changed.emit(6, "The Forgotten Dream")
	AudioManager.set_music_state("exploration")
	
	EventBus.player_died.connect(_on_player_died)
	
	if the_dream_eater:
		the_dream_eater.boss_defeated.connect(_on_boss_defeated)
		the_dream_eater.boss_phase_transition.connect(_on_boss_phase_transition)

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
		"world_id": 6,
		"unlocked_flags": ["world_6_completed", "dreamwoven_unlocked"],
		"bosses_defeated": ["the_dream_eater"]
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
	# Ethereal floating crystalline ground
	draw_rect(Rect2(0, 240, 4800, 100), Color("#1e1035"), true)
	draw_line(Vector2(0, 240), Vector2(4800, 240), Color("#c084fc"), 2.0)
	
	# Shifting Dream Runes
	for i in range(16):
		var fx = 320 + (i * 110)
		var fy = 170 + sin(i * 1.5) * 20
		draw_circle(Vector2(fx, fy), 2.0, Color("#e879f9", 0.5))
