# ArtifactSetData.gd
# Resource contract for the 7-world artifact set identities and set bonuses.
class_name ArtifactSetData
extends Resource

@export var set_id: String = "verdant"
@export var set_name: String = "Verdant Guardian"
@export var world_id: int = 1
@export var description: String = "Ancient natural power attuned to living forest flora."

@export var bonus_2_desc: String = "+15% Max HP"
@export var bonus_4_desc: String = "10% HP/Stamina restore on parry"
@export var bonus_6_desc: String = "20% DMG reduction near roots"
@export var bonus_8_desc: String = "+50% Nature crit dmg"

# Stat modifier values for calculation engines
@export var bonus_2_stat_type: String = "max_hp_pct"
@export var bonus_2_stat_value: float = 0.15

@export var bonus_4_stat_type: String = "parry_restore_pct"
@export var bonus_4_stat_value: float = 0.10

@export var bonus_6_stat_type: String = "damage_reduction_pct"
@export var bonus_6_stat_value: float = 0.20

@export var bonus_8_stat_type: String = "crit_damage_pct"
@export var bonus_8_stat_value: float = 0.50

func get_active_bonuses(pieces_equipped: int) -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	if pieces_equipped >= 2:
		active.append({"tier": 2, "description": bonus_2_desc, "type": bonus_2_stat_type, "value": bonus_2_stat_value})
	if pieces_equipped >= 4:
		active.append({"tier": 4, "description": bonus_4_desc, "type": bonus_4_stat_type, "value": bonus_4_stat_value})
	if pieces_equipped >= 6:
		active.append({"tier": 6, "description": bonus_6_desc, "type": bonus_6_stat_type, "value": bonus_6_stat_value})
	if pieces_equipped >= 8:
		active.append({"tier": 8, "description": bonus_8_desc, "type": bonus_8_stat_type, "value": bonus_8_stat_value})
	return active

func to_dict() -> Dictionary:
	return {
		"set_id": set_id,
		"set_name": set_name,
		"world_id": world_id,
		"bonus_2": bonus_2_desc,
		"bonus_4": bonus_4_desc,
		"bonus_6": bonus_6_desc,
		"bonus_8": bonus_8_desc
	}
