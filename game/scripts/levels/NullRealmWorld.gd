# NullRealmWorld.gd
# World 7 Campaign Level: The NULL Realm.
# Core Mechanic: Rule Failure temporary physics shifts.
class_name NullRealmWorld
extends Node2D

const PlayerController = preload("res://scripts/player/PlayerController.gd")
const RuleFailureManager = preload("res://scripts/world/RuleFailureManager.gd")
const NullBoss = preload("res://scripts/bosses/NullBoss.gd")
const GameCamera2D = preload("res://scripts/core/GameCamera2D.gd")

@onready var player: PlayerController = $Player
@onready var camera: GameCamera2D = $GameCamera2D
@onready var null_boss: NullBoss = $NullBoss

var is_boss_fight_active: bool = false
var is_world_completed: bool = false

func _ready() -> void:
	player.add_to_group("player")
	EventBus.world_changed.emit(7, "The NULL Realm")
	AudioManager.set_music_state("exploration")
	
	EventBus.player_died.connect(_on_player_died)
	
	if null_boss:
		null_boss.boss_defeated.connect(_on_boss_defeated)
		null_boss.boss_phase_transition.connect(_on_boss_phase_transition)

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
		"world_id": 7,
		"unlocked_flags": ["world_7_completed", "nullborn_unlocked", "campaign_completed"],
		"bosses_defeated": ["null"]
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
	# Void Abyss floor
	draw_rect(Rect2(0, 240, 4800, 100), Color("#050508"), true)
	draw_line(Vector2(0, 240), Vector2(4800, 240), Color("#ff007f"), 2.0)
	
	# Digital Glitch Artifacts
	for i in range(18):
		var fx = 280 + (i * 95)
		draw_rect(Rect2(fx, 236, 12, 3), Color("#00ffff", 0.6))
