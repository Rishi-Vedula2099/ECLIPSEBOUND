# WorldData.gd
# Data resource contract for ECLIPSEBOUND 7-world campaign architecture.
class_name WorldData
extends Resource

@export var world_id: int = 1
@export var world_name: String = "The Verdant March"
@export var visual_identity: String = "Ancient ruins, mossy stone, giant roots, moonlit forest"
@export var core_mechanic: String = "Living Terrain"
@export var set_identity: String = "Verdant Guardian"
@export var major_boss_id: String = "hollow_stag"
@export var major_boss_name: String = "The Hollow Stag"
@export var adaptive_focus: String = "Parry frequency & spacing counters"
@export var ambient_color: Color = Color(0.08, 0.18, 0.12, 1.0)
@export var base_xp: float = 500.0
@export var recommended_level: int = 1
@export var level_scene_path: String = "res://scenes/levels/VerdantMarchWorld.tscn"

func to_dict() -> Dictionary:
	return {
		"world_id": world_id,
		"world_name": world_name,
		"visual_identity": visual_identity,
		"core_mechanic": core_mechanic,
		"set_identity": set_identity,
		"major_boss_id": major_boss_id,
		"major_boss_name": major_boss_name,
		"adaptive_focus": adaptive_focus,
		"ambient_color": ambient_color.to_html(),
		"base_xp": base_xp,
		"recommended_level": recommended_level,
		"level_scene_path": level_scene_path
	}
