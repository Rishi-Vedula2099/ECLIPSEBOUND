# PauseMenu.gd
# In-game pause overlay with save/load and resume controls.
class_name PauseMenu
extends CanvasLayer

@onready var panel: Control = $PanelContainer
@onready var resume_btn: Button = $PanelContainer/VBoxContainer/ResumeButton
@onready var save_btn: Button = $PanelContainer/VBoxContainer/SaveButton
@onready var load_btn: Button = $PanelContainer/VBoxContainer/LoadButton
@onready var quit_btn: Button = $PanelContainer/VBoxContainer/QuitButton
@onready var status_label: Label = $PanelContainer/VBoxContainer/StatusLabel

var is_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	resume_btn.pressed.connect(toggle_pause)
	save_btn.pressed.connect(_on_save_pressed)
	load_btn.pressed.connect(_on_load_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_just_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	is_paused = not is_paused
	panel.visible = is_paused
	get_tree().paused = is_paused
	if is_paused:
		resume_btn.grab_focus()
		status_label.text = ""

func _on_save_pressed() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var success: bool = SaveManager.save_game(1, player)
	status_label.text = "Game Saved Successfully!" if success else "Failed to Save Game!"

func _on_load_pressed() -> void:
	var data: Dictionary = SaveManager.load_game(1)
	if data.is_empty():
		status_label.text = "No save data found!"
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("load_save_state"):
		player.load_save_state(data.get("player", {}))
	
	status_label.text = "Game Loaded!"
	toggle_pause()

func _on_quit_pressed() -> void:
	get_tree().quit()
