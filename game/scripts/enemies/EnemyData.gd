# EnemyData.gd
# Structured data resource for ECLIPSEBOUND standard & elite enemy definitions.
class_name EnemyData
extends Resource

@export var enemy_id: String = ""
@export var enemy_name: String = ""
@export var world_id: int = 1
@export var tier: String = "common" # "common", "flying", "bruiser", "elite"

@export_group("Stats")
@export var max_health: float = 60.0
@export var defense: int = 8
@export var move_speed: float = 65.0
@export var chase_speed: float = 95.0
@export var xp_reward: float = 25.0
@export var max_poise: float = 30.0

@export_group("Perception & Range")
@export var detection_radius: float = 180.0
@export var attack_range: float = 36.0
@export var attack_cooldown: float = 1.8
@export var attack_data_path: String = ""
@export var scene_path: String = ""
