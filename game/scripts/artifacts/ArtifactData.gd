# ArtifactData.gd
# Data resource for the 8-piece artifact RPG equipment system.
class_name ArtifactData
extends Resource

@export var artifact_id: String = "verdant_helm"
@export var artifact_name: String = "Verdant Crown"
@export_enum("Helm", "Armour", "Gloves", "Boots", "Necklace", "Bracelet", "Ring", "Earpiece") var slot: String = "Helm"
@export_enum("Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Corrupted") var rarity: String = "Rare"
@export var set_id: String = "Verdant Guardian"

# 8 Core Attribute Bonuses
@export var bonus_vit: int = 0
@export var bonus_str: int = 0
@export var bonus_arc: int = 0
@export var bonus_def: int = 0
@export var bonus_agi: int = 0
@export var bonus_crt: int = 0
@export var bonus_res: int = 0
@export var bonus_lck: int = 0

@export_multiline var description: String = "Ancient relic pulsating with living forest roots."
