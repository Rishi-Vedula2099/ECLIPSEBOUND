# TelegraphSystem.gd
# Multi-stage visual and audio telegraph coordinator enforcing the 350ms minimum reaction rule.
class_name TelegraphSystem
extends RefCounted

signal telegraph_started(attack_name: String, startup_duration: float)
signal attack_became_active(attack_name: String)
signal attack_finished(attack_name: String)

const MIN_TELEGRAPH_DURATION: float = 0.35  # 350ms minimum reaction rule

enum Phase {
	IDLE,
	STARTUP,
	ACTIVE,
	RECOVERY
}

var current_phase: Phase = Phase.IDLE
var current_timer: float = 0.0
var active_attack_name: String = ""

var startup_time: float = 0.45
var active_time: float = 0.20
var recovery_time: float = 0.50

func start_telegraph(attack_name: String, startup: float, active: float, recovery: float) -> bool:
	active_attack_name = attack_name
	startup_time = maxf(MIN_TELEGRAPH_DURATION, startup)
	active_time = active
	recovery_time = recovery
	
	current_phase = Phase.STARTUP
	current_timer = startup_time
	telegraph_started.emit(attack_name, startup_time)
	return true

func update(delta: float) -> Phase:
	if current_phase == Phase.IDLE:
		return Phase.IDLE
		
	current_timer -= delta
	if current_timer <= 0.0:
		match current_phase:
			Phase.STARTUP:
				current_phase = Phase.ACTIVE
				current_timer = active_time
				attack_became_active.emit(active_attack_name)
			Phase.ACTIVE:
				current_phase = Phase.RECOVERY
				current_timer = recovery_time
			Phase.RECOVERY:
				current_phase = Phase.IDLE
				attack_finished.emit(active_attack_name)
				
	return current_phase

func is_telegraphing() -> bool:
	return current_phase == Phase.STARTUP

func is_active() -> bool:
	return current_phase == Phase.ACTIVE

func is_in_recovery() -> bool:
	return current_phase == Phase.RECOVERY

func cancel() -> void:
	current_phase = Phase.IDLE
	current_timer = 0.0
