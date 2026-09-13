# Boot.gd
# Entry point scene for ECLIPSEBOUND. Initializes core services and launches into TestArena.
extends Node2D

func _ready() -> void:
	call_deferred("_launch_arena")

func _launch_arena() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/VerdantMarchWorld.tscn")

func _draw() -> void:
	draw_rect(Rect2(0, 0, 480, 270), Color("#0a0814"), true)
	draw_circle(Vector2(240, 135), 40.0, Color("#7928ca", 0.3))
