# TelemetryManager.gd
# Asynchronous batch telemetry emitter for ECLIPSEBOUND.
extends Node

@export var backend_url: String = "http://localhost:8000/telemetry/events"
@export var batch_flush_interval: float = 2.0
@export var max_batch_size: int = 50

var _event_queue: Array = []
var _flush_timer: Timer
var _http_request: HTTPRequest
var _session_id: String = ""
var _player_id: String = "player_local_01"

func _ready() -> void:
	_session_id = "session_" + str(Time.get_unix_time_from_system())
	
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)
	
	_flush_timer = Timer.new()
	_flush_timer.wait_time = batch_flush_interval
	_flush_timer.autostart = true
	_flush_timer.timeout.connect(_flush_queue)
	add_child(_flush_timer)
	
	# Connect to EventBus signals
	EventBus.player_attacked.connect(_on_player_attacked)
	EventBus.player_dodged.connect(_on_player_dodged)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.player_died.connect(_on_player_died)

func track_event(event_type: String, data: Dictionary) -> void:
	var payload: Dictionary = {
		"event": event_type,
		"player_id": _player_id,
		"session_id": _session_id,
		"timestamp": Time.get_unix_time_from_system(),
		"data": data
	}
	_event_queue.append(payload)
	EventBus.telemetry_event_emitted.emit(event_type, payload)
	
	if _event_queue.size() >= max_batch_size:
		_flush_queue()

func _flush_queue() -> void:
	if _event_queue.is_empty():
		return
	
	var batch: Array = _event_queue.duplicate()
	_event_queue.clear()
	
	var json_body: String = JSON.stringify({"events": batch})
	var headers: PackedStringArray = ["Content-Type: application/json"]
	_http_request.request(backend_url, headers, HTTPClient.METHOD_POST, json_body)

func _on_player_attacked(weapon_id: String, attack_type: String, position: Vector2) -> void:
	track_event("player_attack", {
		"weapon": weapon_id,
		"type": attack_type,
		"pos_x": position.x,
		"pos_y": position.y
	})

func _on_player_dodged(direction: Vector2, is_perfect: bool) -> void:
	track_event("player_dodge", {
		"dir_x": direction.x,
		"dir_y": direction.y,
		"perfect": is_perfect
	})

func _on_player_damaged(current_hp: float, max_hp: float, damage: float, source: String) -> void:
	track_event("player_damage", {
		"current_hp": current_hp,
		"max_hp": max_hp,
		"damage": damage,
		"source": source
	})

func _on_player_died(cause: String, position: Vector2) -> void:
	track_event("player_death", {
		"cause": cause,
		"pos_x": position.x,
		"pos_y": position.y
	})

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200 and response_code != 201:
		push_warning("Telemetry dispatch warning. Code: " + str(response_code))
