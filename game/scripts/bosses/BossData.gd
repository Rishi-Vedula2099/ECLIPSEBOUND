# BossData.gd
# Structured data resource for ECLIPSEBOUND Major Boss definitions.
class_name BossData
extends Resource

@export var boss_id: String = ""
@export var boss_name: String = ""
@export var world_id: int = 1
@export var visual_theme: String = ""

@export_group("Combat Stats")
@export var max_health: float = 900.0
@export var defense: int = 20
@export var base_speed: float = 90.0
@export var charge_speed: float = 240.0
@export var xp_reward: float = 500.0

@export_group("Adaptation & AI")
@export var adaptive_focus: String = ""
@export var phases: Array[String] = []
@export var attack_names: Array[String] = []
@export var scene_path: String = ""
