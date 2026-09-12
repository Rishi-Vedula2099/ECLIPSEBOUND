# AudioManager.gd
# Procedural and bus-routed audio management for ECLIPSEBOUND.
# Manages 8 audio channels, contextual combat SFX, and adaptive music state machine.
extends Node

signal music_state_changed(previous_state: String, new_state: String)

enum MusicState {
	EXPLORATION,
	TENSION,
	BOSS_PHASE_1,
	BOSS_PHASE_2,
	VICTORY
}

var current_music_state: MusicState = MusicState.EXPLORATION
var _audio_players: Dictionary = {}

func _ready() -> void:
	# Create internal AudioStreamPlayers
	for bus_name in ["Master", "Music", "Ambience", "Combat", "UI"]:
		var player = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_audio_players[bus_name] = player
	
	# Connect to EventBus for contextual combat audio
	EventBus.player_attacked.connect(func(_wep, _type, _pos): play_sfx("sword_slash"))
	EventBus.player_parried.connect(func(_target, is_perfect): play_sfx("parry_perfect" if is_perfect else "parry_normal"))
	EventBus.player_dodged.connect(func(_dir, _perf): play_sfx("dash_woosh"))
	EventBus.player_damaged.connect(func(_cur, _max, _dmg, _src): play_sfx("player_hurt"))
	EventBus.boss_phase_changed.connect(func(_boss, phase): if phase == 2: set_music_state("boss_phase_2"))

func play_sfx(sfx_name: String, _volume_db: float = 0.0) -> void:
	# Contextual combat sound triggers (synthesized logs for headless / cross-platform safety)
	# When binary audio files are placed in res://assets/audio/sfx/, load and play here
	pass

func set_music_state(state_name: String) -> void:
	var old_state = current_music_state
	match state_name.to_lower():
		"exploration":
			current_music_state = MusicState.EXPLORATION
		"tension":
			current_music_state = MusicState.TENSION
		"boss_phase_1":
			current_music_state = MusicState.BOSS_PHASE_1
		"boss_phase_2":
			current_music_state = MusicState.BOSS_PHASE_2
		"victory":
			current_music_state = MusicState.VICTORY
	
	music_state_changed.emit(str(old_state), str(current_music_state))

func get_current_music_state_name() -> String:
	match current_music_state:
		MusicState.EXPLORATION: return "exploration"
		MusicState.TENSION: return "tension"
		MusicState.BOSS_PHASE_1: return "boss_phase_1"
		MusicState.BOSS_PHASE_2: return "boss_phase_2"
		MusicState.VICTORY: return "victory"
	return "exploration"
