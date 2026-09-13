# State.gd
# Base state class for the modular ECLIPSEBOUND finite state machine.
class_name State
extends RefCounted

var state_name: String = "STATE"
var state_machine: RefCounted = null
var actor: CharacterBody2D = null

func enter() -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass
