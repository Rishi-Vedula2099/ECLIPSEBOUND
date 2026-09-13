# VerdantMarchWorld.gd
# World 1 Vertical Slice: The Verdant March.
# Integrates 6 level segments, common enemies, elite, miniboss, The Hollow Stag, Living Terrain, and checkpoints.
class_name VerdantMarchWorld
extends Node2D

const PlayerController = preload("res://scripts/player/PlayerController.gd")
const CheckpointShrine = preload("res://scripts/world/CheckpointShrine.gd")
const LivingTerrainManager = preload("res://scripts/world/LivingTerrainManager.gd")
const HollowStag = preload("res://scripts/bosses/HollowStag.gd")
const GameCamera2D = preload("res://scripts/core/GameCamera2D.gd")

@onready var player: PlayerController = $Player
@onready var camera: GameCamera2D = $GameCamera2D
@onready var boss_arena_gate_left: LivingTerrainManager = $BossArenaGateLeft
@onready var boss_arena_gate_right: LivingTerrainManager = $BossArenaGateRight
@onready var hollow_stag: HollowStag = $HollowStag

var is_boss_fight_active: bool = false
var is_world_completed: bool = false

func _ready() -> void:
	player.add_to_group("player")
	EventBus.world_changed.emit(1, "The Verdant March")
	AudioManager.set_music_state("exploration")
	
	EventBus.player_died.connect(_on_player_died)
	
	if hollow_stag:
		hollow_stag.boss_defeated.connect(_on_boss_defeated)
		hollow_stag.boss_phase_transition.connect(_on_boss_phase_transition)

func _on_boss_arena_trigger_entered(body: Node2D) -> void:
	if body is PlayerController and not is_boss_fight_active and not is_world_completed:
		is_boss_fight_active = true
		AudioManager.set_music_state("boss_phase_1")
		# Seal boss arena with Living Terrain dynamic roots
		if boss_arena_gate_left:
			boss_arena_gate_left.extend_barrier()
		if boss_arena_gate_right:
			boss_arena_gate_right.extend_barrier()

func _on_boss_phase_transition(phase: int) -> void:
	if phase == 2:
		AudioManager.set_music_state("boss_phase_2")

func _on_boss_defeated() -> void:
	is_boss_fight_active = false
	is_world_completed = true
	AudioManager.set_music_state("victory")
	
	# Open living root barriers
	if boss_arena_gate_left:
		boss_arena_gate_left.retract_barrier()
	if boss_arena_gate_right:
		boss_arena_gate_right.retract_barrier()
	
	# Record progression flag
	SaveManager.save_game(1, player, {
		"world_id": 1,
		"unlocked_flags": ["world_1_completed", "stag_horn_blade_unlocked"],
		"bosses_defeated": ["hollow_stag"]
	})

func _on_player_died(_cause: String, _death_pos: Vector2) -> void:
	# Reset boss arena state on player death
	if is_boss_fight_active:
		is_boss_fight_active = false
		if boss_arena_gate_left:
			boss_arena_gate_left.retract_barrier()
		if boss_arena_gate_right:
			boss_arena_gate_right.retract_barrier()
		AudioManager.set_music_state("exploration")
	
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(player):
			player.respawn(SaveManager.active_checkpoint_position)
	)

func _draw() -> void:
	# Continuous ground line & stone base across entire 4600px level span
	draw_rect(Rect2(0, 240, 4800, 100), Color("#1e293b"), true)
	draw_line(Vector2(0, 240), Vector2(4800, 240), Color("#00e5a3"), 2.0)
	
	# Ambient firefly motes in Segments 2 & 6
	for i in range(12):
		var fx = 700 + (i * 80)
		var fy = 180 + sin(i) * 30
		draw_circle(Vector2(fx, fy), 1.5, Color("#64ffda", 0.8))
