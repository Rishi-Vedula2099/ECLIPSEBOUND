# CraftingManager.gd
# Implements the 5-stage crafting lifecycle: Craft -> Upgrade -> Reforge -> Reroll -> Transmute.
class_name CraftingManager
extends RefCounted

const ArtifactData = preload("res://scripts/artifacts/ArtifactData.gd")
const WeaponData = preload("res://scripts/weapons/WeaponData.gd")
const InventoryManager = preload("res://scripts/inventory/InventoryManager.gd")

signal item_crafted(item: Resource, recipe_id: String)
signal item_upgraded(item: Resource, new_level: int)
signal item_reforged(item: Resource)
signal item_affix_rerolled(item: Resource, affix_index: int)
signal items_transmuted(result_item: Resource)

var inventory: InventoryManager = null

# Available craft recipes: recipe_id -> Dictionary
var recipes: Dictionary = {
	"recipe_verdant_helm": {
		"result_type": "artifact",
		"slot": "Helm",
		"set_id": "Verdant Guardian",
		"rarity": "Rare",
		"materials": {"gold": 250, "verdant_shard": 15},
		"base_stats": {"vit": 8, "def": 6}
	},
	"recipe_verdant_armour": {
		"result_type": "artifact",
		"slot": "Armour",
		"set_id": "Verdant Guardian",
		"rarity": "Rare",
		"materials": {"gold": 400, "verdant_shard": 25},
		"base_stats": {"vit": 12, "def": 10}
	},
	"recipe_stag_blade": {
		"result_type": "weapon",
		"weapon_class": "Longsword",
		"rarity": "Rare",
		"materials": {"gold": 500, "verdant_shard": 30},
		"base_damage": 34.0,
		"str_scaling": 1.4,
		"arc_scaling": 1.1
	}
}

func _init(inv: InventoryManager = null) -> void:
	inventory = inv

# --- 1. CRAFT ---
func craft_item(recipe_id: String) -> Resource:
	if not inventory or not recipes.has(recipe_id):
		return null
	
	var recipe: Dictionary = recipes[recipe_id]
	var costs: Dictionary = recipe["materials"]
	
	# Verify materials
	for mat in costs.keys():
		if inventory.get_material_count(mat) < costs[mat]:
			return null
	
	# Deduct materials
	for mat in costs.keys():
		inventory.spend_material(mat, costs[mat])
	
	var result: Resource = null
	if recipe["result_type"] == "artifact":
		var art = ArtifactData.new()
		art.artifact_id = recipe_id.replace("recipe_", "")
		art.artifact_name = recipe.get("name", "Forged Relic")
		art.slot = recipe.get("slot", "Helm")
		art.rarity = recipe.get("rarity", "Rare")
		art.set_id = recipe.get("set_id", "Verdant Guardian")
		var stats = recipe.get("base_stats", {})
		art.bonus_vit = stats.get("vit", 0)
		art.bonus_str = stats.get("str", 0)
		art.bonus_arc = stats.get("arc", 0)
		art.bonus_def = stats.get("def", 0)
		art.bonus_agi = stats.get("agi", 0)
		art.bonus_crt = stats.get("crt", 0)
		art.bonus_res = stats.get("res", 0)
		art.bonus_lck = stats.get("lck", 0)
		art.substats = [
			{"stat": "str", "value": 3},
			{"stat": "def", "value": 3}
		]
		result = art
	else:
		var wep = WeaponData.new()
		wep.weapon_id = recipe_id.replace("recipe_", "")
		wep.weapon_name = "Forged Weapon"
		wep.weapon_class = recipe.get("weapon_class", "Longsword")
		wep.rarity = recipe.get("rarity", "Rare")
		wep.base_damage = recipe.get("base_damage", 30.0)
		wep.str_scaling = recipe.get("str_scaling", 1.0)
		wep.arc_scaling = recipe.get("arc_scaling", 1.0)
		result = wep
	
	inventory.add_item(result)
	item_crafted.emit(result, recipe_id)
	return result

# --- 2. UPGRADE (+1 to +10) ---
func get_upgrade_cost(item: Resource) -> Dictionary:
	if not ("upgrade_level" in item) or item.upgrade_level >= 10:
		return {}
	var lvl = item.upgrade_level
	return {
		"gold": 150 * (lvl + 1),
		"verdant_shard": 5 * (lvl + 1)
	}

func can_upgrade(item: Resource) -> bool:
	if not inventory or not ("upgrade_level" in item) or item.upgrade_level >= 10:
		return false
	var costs = get_upgrade_cost(item)
	for mat in costs.keys():
		if inventory.get_material_count(mat) < costs[mat]:
			return false
	return true

func upgrade_item(item: Resource) -> bool:
	if not can_upgrade(item):
		return false
	var costs = get_upgrade_cost(item)
	for mat in costs.keys():
		inventory.spend_material(mat, costs[mat])
	item.upgrade_level += 1
	item_upgraded.emit(item, item.upgrade_level)
	return true

# --- 3. REFORGE (Reroll substat magnitudes) ---
func get_reforge_cost() -> Dictionary:
	return {"gold": 200, "reforge_stone": 1}

func can_reforge(art: ArtifactData) -> bool:
	if not inventory or not art or art.substats.is_empty():
		return false
	var costs = get_reforge_cost()
	for mat in costs.keys():
		if inventory.get_material_count(mat) < costs[mat]:
			return false
	return true

func reforge_item(art: ArtifactData) -> bool:
	if not can_reforge(art):
		return false
	var costs = get_reforge_cost()
	for mat in costs.keys():
		inventory.spend_material(mat, costs[mat])
	
	# Reroll each substat value between 2 and 8
	for sub in art.substats:
		sub["value"] = randi_range(3, 8)
	
	item_reforged.emit(art)
	return true

# --- 4. REROLL (Replace a selected substat with a random one) ---
func get_reroll_cost() -> Dictionary:
	return {"gold": 350, "reforge_stone": 2}

func can_reroll_affix(art: ArtifactData, affix_index: int) -> bool:
	if not inventory or not art or affix_index < 0 or affix_index >= art.substats.size():
		return false
	var costs = get_reroll_cost()
	for mat in costs.keys():
		if inventory.get_material_count(mat) < costs[mat]:
			return false
	return true

func reroll_affix(art: ArtifactData, affix_index: int) -> bool:
	if not can_reroll_affix(art, affix_index):
		return false
	var costs = get_reroll_cost()
	for mat in costs.keys():
		inventory.spend_material(mat, costs[mat])
	
	var possible_stats = ["vit", "str", "arc", "def", "agi", "crt", "res", "lck"]
	var new_stat = possible_stats[randi() % possible_stats.size()]
	art.substats[affix_index]["stat"] = new_stat
	art.substats[affix_index]["value"] = randi_range(3, 8)
	
	item_affix_rerolled.emit(art, affix_index)
	return true

# --- 5. TRANSMUTE (Combine 3 artifacts of same rarity -> higher tier or Corrupted) ---
func get_transmute_cost() -> Dictionary:
	return {"gold": 1000, "transmute_catalyst": 1}

func can_transmute(artifacts_list: Array[ArtifactData]) -> bool:
	if not inventory or artifacts_list.size() != 3:
		return false
	var target_rarity = artifacts_list[0].rarity
	for a in artifacts_list:
		if not a or a.rarity != target_rarity or a.is_locked:
			return false
	var costs = get_transmute_cost()
	for mat in costs.keys():
		if inventory.get_material_count(mat) < costs[mat]:
			return false
	return true

func transmute_items(artifacts_list: Array[ArtifactData]) -> ArtifactData:
	if not can_transmute(artifacts_list):
		return null
	
	var costs = get_transmute_cost()
	for mat in costs.keys():
		inventory.spend_material(mat, costs[mat])
	
	var base_rarity = artifacts_list[0].rarity
	var chosen_slot = artifacts_list[randi() % 3].slot
	var chosen_set = artifacts_list[randi() % 3].set_id
	
	# Remove consumed items
	for a in artifacts_list:
		inventory.remove_item(a)
	
	# Determine upgraded rarity
	var next_rarity = "Rare"
	match base_rarity:
		"Common": next_rarity = "Uncommon"
		"Uncommon": next_rarity = "Rare"
		"Rare": next_rarity = "Epic"
		"Epic": next_rarity = "Legendary"
		"Legendary", "Mythic": next_rarity = "Mythic"
	
	# 25% chance of Corrupted transmutation
	var is_corrupt: bool = (randf() < 0.25)
	if is_corrupt:
		next_rarity = "Corrupted"
	
	var result = ArtifactData.new()
	result.artifact_id = "transmuted_%d" % int(Time.get_unix_time_from_system())
	result.artifact_name = "Transmuted %s" % chosen_slot
	result.slot = chosen_slot
	result.rarity = next_rarity
	result.set_id = chosen_set
	result.bonus_vit = randi_range(6, 14)
	result.bonus_str = randi_range(6, 14)
	result.bonus_def = randi_range(6, 14)
	result.substats = [
		{"stat": "crt", "value": randi_range(4, 8)},
		{"stat": "agi", "value": randi_range(4, 8)}
	]
	
	if is_corrupt:
		result.is_corrupted = true
		result.corrupted_affix = {
			"boon": "crit_damage",
			"boon_val": 0.45,
			"curse": "max_hp_penalty",
			"curse_val": -0.25
		}
	
	inventory.add_item(result)
	items_transmuted.emit(result)
	return result
