# CrimsonCathedralWorld.gd
# World 4 Campaign Level: The Crimson Cathedral.
# Core Mechanic: Blood Rites sacrifice choices altering encounters.
class_name CrimsonCathedralWorld
extends Node2D

const PlayerController = preload("res://scripts/player/PlayerController.gd")
const BloodRiteManager = preload("res://scripts/world/BloodRiteManager.gd")
const CardinalOfBlood = preload("res://scripts/bosses/CardinalOfBlood.gd")
const GameCamera2D = preload("res://scripts/core/GameCamera2D.gd")

@onready var player: PlayerController = $Player
@onready var camera: GameCamera2D = $GameCamera2D
@onready var cardinal_of_blood: CardinalOfBlood = $CardinalOfBlood

var is_boss_fight_active: bool = false
var is_world_completed: bool = false

func _ready() -> void:
	player.add_to_group("player")
	EventBus.world_changed.emit(4, "The Crimson Cathedral")
	AudioManager.set_music_state("exploration")
	
	EventBus.player_died.connect(_on_player_died)
	
	if cardinal_of_blood:
		cardinal_of_blood.boss_defeated.connect(_on_boss_defeated)
		cardinal_of_blood.boss_phase_transition.connect(_on_boss_phase_transition)

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
		"world_id": 4,
		"unlocked_flags": ["world_4_completed", "crimson_rite_unlocked"],
		"bosses_defeated": ["cardinal_of_blood"]
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
	# Gothic Cathedral Flagstone
	draw_rect(Rect2(0, 240, 4800, 100), Color("#18060c"), true)
	draw_line(Vector2(0, 240), Vector2(4800, 240), Color("#e11d48"), 2.0)
	
	# Blood River Streams & Reflections
	for i in range(12):
		var fx = 400 + (i * 150)
		var fy = 242
		draw_line(Vector2(fx, fy), Vector2(fx + 60, fy), Color("#9f1239", 0.9), 3.0)
