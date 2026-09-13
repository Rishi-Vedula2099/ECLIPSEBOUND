# InventoryManager.gd
# Inventory storage, filtering, sorting, locking, favoriting, batch salvage, and auto-salvage.
class_name InventoryManager
extends RefCounted

const ArtifactData = preload("res://scripts/artifacts/ArtifactData.gd")
const WeaponData = preload("res://scripts/weapons/WeaponData.gd")

signal item_added(item: Resource)
signal item_removed(item: Resource)
signal inventory_updated()
signal item_salvaged(item: Resource, materials_yielded: Dictionary)

const MAX_CAPACITY: int = 100

# Gear items array: Array[Resource]
var items: Array[Resource] = []

# Materials pouch: material_id -> int
var materials: Dictionary = {
	"gold": 500,
	"verdant_shard": 10,
	"drowned_pearl": 0,
	"ashen_ore": 0,
	"crimson_ichor": 0,
	"machinist_gear": 0,
	"dream_dust": 0,
	"void_crystal": 0,
	"reforge_stone": 5,
	"transmute_catalyst": 2
}

# Auto-salvage preferences
var auto_salvage_settings: Dictionary = {
	"enabled": false,
	"auto_salvage_common": true,
	"auto_salvage_uncommon": false,
	"auto_salvage_rare": false
}

func get_item_count() -> int:
	return items.size()

func is_full() -> bool:
	return items.size() >= MAX_CAPACITY

func add_item(item: Resource) -> bool:
	if not item:
		return false
	
	# Check auto-salvage
	if auto_salvage_settings["enabled"] and _should_auto_salvage(item):
		salvage_item(item)
		return true
	
	if is_full():
		return false
		
	items.append(item)
	item_added.emit(item)
	inventory_updated.emit()
	return true

func remove_item(item: Resource) -> bool:
	var idx = items.find(item)
	if idx != -1:
		items.remove_at(idx)
		item_removed.emit(item)
		inventory_updated.emit()
		return true
	return false

func toggle_lock(item: Resource) -> bool:
	if "is_locked" in item:
		item.is_locked = not item.is_locked
		inventory_updated.emit()
		return item.is_locked
	return false

func toggle_favorite(item: Resource) -> bool:
	if "is_favorite" in item:
		item.is_favorite = not item.is_favorite
		inventory_updated.emit()
		return item.is_favorite
	return false

func filter_items(criteria: Dictionary) -> Array[Resource]:
	var result: Array[Resource] = []
	for item in items:
		var matches = true
		if criteria.has("type"):
			var is_art = item is ArtifactData
			var is_wep = item is WeaponData
			if criteria["type"] == "artifact" and not is_art: matches = false
			elif criteria["type"] == "weapon" and not is_wep: matches = false
			
		if matches and criteria.has("slot") and item is ArtifactData:
			if item.slot != criteria["slot"]: matches = false
			
		if matches and criteria.has("rarity") and "rarity" in item:
			if item.rarity != criteria["rarity"]: matches = false
			
		if matches and criteria.has("weapon_class") and item is WeaponData:
			if item.weapon_class != criteria["weapon_class"]: matches = false
			
		if matches and criteria.has("set_id") and item is ArtifactData:
			if item.set_id != criteria["set_id"]: matches = false
			
		if matches and criteria.has("is_favorite") and "is_favorite" in item:
			if item.is_favorite != criteria["is_favorite"]: matches = false
			
		if matches and criteria.has("is_locked") and "is_locked" in item:
			if item.is_locked != criteria["is_locked"]: matches = false
			
		if matches:
			result.append(item)
	return result

func sort_items(mode: String = "power") -> void:
	match mode.to_lower():
		"power":
			items.sort_custom(func(a, b):
				var pa = a.get_power_score() if a.has_method("get_power_score") else 0
				var pb = b.get_power_score() if b.has_method("get_power_score") else 0
				return pa > pb
			)
		"rarity":
			var rank = {"Common": 1, "Uncommon": 2, "Rare": 3, "Epic": 4, "Legendary": 5, "Mythic": 6, "Corrupted": 7}
			items.sort_custom(func(a, b):
				var ra = rank.get(a.rarity, 0) if "rarity" in a else 0
				var rb = rank.get(b.rarity, 0) if "rarity" in b else 0
				return ra > rb
			)
		"name":
			items.sort_custom(func(a, b):
				var na = a.artifact_name if a is ArtifactData else (a.weapon_name if a is WeaponData else "")
				var nb = b.artifact_name if b is ArtifactData else (b.weapon_name if b is WeaponData else "")
				return na < nb
			)
	inventory_updated.emit()

func salvage_item(item: Resource) -> Dictionary:
	if not item:
		return {}
	if "is_locked" in item and item.is_locked:
		return {}  # Cannot salvage locked items
	
	var yielded: Dictionary = {}
	var rarity = item.rarity if "rarity" in item else "Common"
	
	match rarity:
		"Common":
			yielded["gold"] = 50
			yielded["verdant_shard"] = 2
		"Uncommon":
			yielded["gold"] = 120
			yielded["verdant_shard"] = 5
		"Rare":
			yielded["gold"] = 300
			yielded["verdant_shard"] = 10
			yielded["reforge_stone"] = 1
		"Epic":
			yielded["gold"] = 750
			yielded["verdant_shard"] = 25
			yielded["reforge_stone"] = 2
		"Legendary":
			yielded["gold"] = 2000
			yielded["verdant_shard"] = 50
			yielded["reforge_stone"] = 5
			yielded["transmute_catalyst"] = 1
		"Mythic", "Corrupted":
			yielded["gold"] = 5000
			yielded["void_crystal"] = 2
			yielded["reforge_stone"] = 10
			yielded["transmute_catalyst"] = 2
	
	for mat in yielded.keys():
		add_material(mat, yielded[mat])
	
	remove_item(item)
	item_salvaged.emit(item, yielded)
	return yielded

func batch_salvage(salvage_list: Array[Resource]) -> Dictionary:
	var total_yielded: Dictionary = {}
	for item in salvage_list:
		if "is_locked" in item and item.is_locked:
			continue
		var y = salvage_item(item)
		for k in y.keys():
			total_yielded[k] = total_yielded.get(k, 0) + y[k]
	return total_yielded

func _should_auto_salvage(item: Resource) -> bool:
	if not ("rarity" in item):
		return false
	if item.rarity == "Common" and auto_salvage_settings["auto_salvage_common"]:
		return true
	if item.rarity == "Uncommon" and auto_salvage_settings["auto_salvage_uncommon"]:
		return true
	if item.rarity == "Rare" and auto_salvage_settings["auto_salvage_rare"]:
		return true
	return false

# --- Materials Management ---
func add_material(mat_id: String, count: int) -> void:
	materials[mat_id] = materials.get(mat_id, 0) + count
	inventory_updated.emit()

func spend_material(mat_id: String, count: int) -> bool:
	if materials.get(mat_id, 0) >= count and count >= 0:
		materials[mat_id] -= count
		inventory_updated.emit()
		return true
	return false

func get_material_count(mat_id: String) -> int:
	return materials.get(mat_id, 0)

# --- Serialization ---
func to_dict() -> Dictionary:
	var serialized_items: Array = []
	for it in items:
		if it is ArtifactData:
			var d = it.to_dict()
			d["_class"] = "ArtifactData"
			serialized_items.append(d)
	return {
		"items": serialized_items,
		"materials": materials.duplicate(true),
		"auto_salvage_settings": auto_salvage_settings.duplicate(true)
	}

func from_dict(data: Dictionary) -> void:
	items.clear()
	if data.has("materials"):
		materials = data["materials"].duplicate(true)
	if data.has("auto_salvage_settings"):
		auto_salvage_settings = data["auto_salvage_settings"].duplicate(true)
	if data.has("items"):
		for d in data["items"]:
			if d.get("_class") == "ArtifactData":
				items.append(ArtifactData.from_dict(d))
	inventory_updated.emit()
