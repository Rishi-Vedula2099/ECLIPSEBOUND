# EncounterData.gd
# Structured data resource defining wave compositions and encounter pools for Worlds.
class_name EncounterData
extends Resource

@export var encounter_id: String = ""
@export var world_id: int = 1
@export var encounter_name: String = ""
@export var wave_count: int = 3
@export var minion_pool: Array[String] = []
@export var elite_pool: Array[String] = []
@export var max_simultaneous_enemies: int = 6
@export var base_clear_xp: float = 150.0
@export var difficulty_rating: float = 1.0
