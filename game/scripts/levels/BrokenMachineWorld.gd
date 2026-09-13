# BrokenMachineWorld.gd
# World 5 Campaign Level: The Broken Machine.
# Core Mechanic: Machine State powering and destroying systems.
class_name BrokenMachineWorld
extends Node2D

const PlayerController = preload("res://scripts/player/PlayerController.gd")
const MachineStateManager = preload("res://scripts/world/MachineStateManager.gd")
const TheArchitect = preload("res://scripts/bosses/TheArchitect.gd")
const GameCamera2D = preload("res://scripts/core/GameCamera2D.gd")

@onready var player: PlayerController = $Player
@onready var camera: GameCamera2D = $GameCamera2D
@onready var the_architect: TheArchitect = $TheArchitect

var is_boss_fight_active: bool = false
var is_world_completed: bool = false

func _ready() -> void:
	player.add_to_group("player")
	EventBus.world_changed.emit(5, "The Broken Machine")
	AudioManager.set_music_state("exploration")
	
	EventBus.player_died.connect(_on_player_died)
	
	if the_architect:
		the_architect.boss_defeated.connect(_on_boss_defeated)
		the_architect.boss_phase_transition.connect(_on_boss_phase_transition)

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
		"world_id": 5,
		"unlocked_flags": ["world_5_completed", "machinists_core_unlocked"],
		"bosses_defeated": ["the_architect"]
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
	# Metal Industrial Grate Floor
	draw_rect(Rect2(0, 240, 4800, 100), Color("#171717"), true)
	draw_line(Vector2(0, 240), Vector2(4800, 240), Color("#d97706"), 2.0)
	
	# Electric Conduit Cables & Sparks
	for i in range(14):
		var fx = 350 + (i * 130)
		draw_line(Vector2(fx, 238), Vector2(fx + 20, 238), Color("#06b6d4"), 2.0)
