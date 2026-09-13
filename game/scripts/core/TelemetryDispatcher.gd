# TelemetryDispatcher.gd
# Non-blocking combat and behavioral telemetry batch queue conforming to ADR-003.
# Dispatches events to local BehavioralFingerprint and flushes JSON batches to FastAPI backend.
class_name TelemetryDispatcher
extends Node

signal batch_flushed(event_count: int, success: bool)

const MAX_BATCH_SIZE: int = 50
const FLUSH_INTERVAL_SEC: float = 2.0

@export var backend_url: String = "http://127.0.0.1:8000/telemetry/events"
@export var player_id: String = "player_local"
@export var session_id: String = "session_default"

var event_queue: Array = []
var flush_timer: float = 0.0
var http_request: HTTPRequest = null
var fingerprint: RefCounted = null


func _ready() -> void:
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	session_id = "session_%d" % int(Time.get_unix_time_from_system())


func set_fingerprint(p_fingerprint: RefCounted) -> void:
	fingerprint = p_fingerprint


func _process(delta: float) -> void:
	flush_timer += delta
	if flush_timer >= FLUSH_INTERVAL_SEC or event_queue.size() >= MAX_BATCH_SIZE:
		flush_batch()


func emit_telemetry_event(event_type: String, data: Dictionary = {}) -> void:
	var entry = {
		"event": event_type,
		"player_id": player_id,
		"session_id": session_id,
		"timestamp": Time.get_unix_time_from_system(),
		"data": data,
	}
	event_queue.append(entry)

	# Ingest into local real-time BehavioralFingerprint if attached
	if fingerprint != null:
		_ingest_into_fingerprint(event_type, data)

	if event_queue.size() >= MAX_BATCH_SIZE:
		flush_batch()


func flush_batch() -> void:
	flush_timer = 0.0
	if event_queue.is_empty():
		return

	var batch_payload = {
		"events": event_queue.duplicate(true)
	}
	event_queue.clear()

	var json_str = JSON.stringify(batch_payload)
	var headers = ["Content-Type: application/json"]

	if http_request != null and http_request.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		var err = http_request.request(backend_url, headers, HTTPClient.METHOD_POST, json_str)
		if err != OK:
			push_warning("TelemetryDispatcher: Failed to send batch request (%d)" % err)


func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var success = (response_code == 200 or response_code == 201)
	emit_signal("batch_flushed", MAX_BATCH_SIZE, success)


func _ingest_into_fingerprint(event_type: String, data: Dictionary) -> void:
	match event_type:
		"player_attack":
			var is_heavy: bool = data.get("type", "light") == "heavy"
			var combo_step: int = data.get("combo_step", 1)
			fingerprint.record_attack(is_heavy, combo_step)

		"player_dodge":
			var dir: String = data.get("direction", "RIGHT")
			fingerprint.record_dodge(dir)

		"hit_resolved":
			var outcome: String = data.get("outcome", "hit_taken")
			var dmg: float = data.get("damage", 0.0)
			fingerprint.record_incoming_hit_resolved(outcome, dmg)

		"player_heal":
			var hp_ratio: float = data.get("hp_ratio", 0.3)
			var dist: float = data.get("enemy_distance", 150.0)
			fingerprint.record_heal_event(hp_ratio, dist)
