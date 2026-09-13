# StateMachine.gd
# Modular hierarchical finite state machine for enemies, bosses, and interactive entities.
class_name StateMachine
extends Node

const StateRef = preload("res://scripts/ai/State.gd")

signal state_changed(old_state_name: String, new_state_name: String)

@export var initial_state_name: String = "IDLE"

var current_state: State = null
var current_state_name: String = ""
var states: Dictionary = {}
var actor: CharacterBody2D = null

func initialize(host_actor: CharacterBody2D) -> void:
	actor = host_actor
	for sname in states.keys():
		states[sname].actor = host_actor
		states[sname].state_machine = self
	
	if states.has(initial_state_name):
		change_state(initial_state_name)

func add_state(sname: String, state_instance: State) -> void:
	state_instance.state_name = sname
	state_instance.state_machine = self
	if actor:
		state_instance.actor = actor
	states[sname] = state_instance

func change_state(new_state_name: String) -> bool:
	if not states.has(new_state_name):
		push_warning("StateMachine: Attempted transition to unregistered state: %s" % new_state_name)
		return false
	
	var old_name = current_state_name
	if current_state:
		current_state.exit()
	
	current_state_name = new_state_name
	current_state = states[new_state_name]
	current_state.enter()
	
	state_changed.emit(old_name, new_state_name)
	return true

func update(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func physics_update(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func handle_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)
