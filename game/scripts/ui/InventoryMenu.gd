# InventoryMenu.gd
# In-game RPG menu providing Equipment, Inventory, Skill Tree, Weapon Mastery, and Crafting tabs.
class_name InventoryMenu
extends CanvasLayer

signal menu_closed()

const PlayerStats = preload("res://scripts/core/PlayerStats.gd")
const ArtifactManager = preload("res://scripts/progression/ArtifactManager.gd")
const SkillTreeManager = preload("res://scripts/progression/SkillTreeManager.gd")
const WeaponMasteryManager = preload("res://scripts/weapons/WeaponMasteryManager.gd")
const InventoryManager = preload("res://scripts/inventory/InventoryManager.gd")
const CraftingManager = preload("res://scripts/inventory/CraftingManager.gd")
const ArtifactData = preload("res://scripts/artifacts/ArtifactData.gd")
const WeaponData = preload("res://scripts/weapons/WeaponData.gd")

@onready var tab_container: TabContainer = $Control/Panel/TabContainer
@onready var stat_labels_container: VBoxContainer = $Control/Panel/TabContainer/Equipment/MarginContainer/HBoxContainer/StatsPanel/ScrollContainer/StatsList
@onready var unspent_stat_pts_label: Label = $Control/Panel/TabContainer/Equipment/MarginContainer/HBoxContainer/StatsPanel/UnspentStatPointsLabel
@onready var unspent_skill_pts_label: Label = $Control/Panel/TabContainer/Skills/MarginContainer/VBoxContainer/HeaderHBox/UnspentSkillPointsLabel
@onready var gold_label: Label = $Control/Panel/Header/GoldLabel

var stats: PlayerStats = null
var artifact_mgr: ArtifactManager = null
var skill_mgr: SkillTreeManager = null
var mastery_mgr: WeaponMasteryManager = null
var inventory_mgr: InventoryManager = null
var crafting_mgr: CraftingManager = null

var is_open: bool = false

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Fallback initialization if not provided externally
	if not stats: stats = PlayerStats.new()
	if not artifact_mgr: artifact_mgr = ArtifactManager.new()
	if not skill_mgr: skill_mgr = SkillTreeManager.new()
	if not mastery_mgr: mastery_mgr = WeaponMasteryManager.new()
	if not inventory_mgr: inventory_mgr = InventoryManager.new()
	if not crafting_mgr: crafting_mgr = CraftingManager.new(inventory_mgr)
	
	_connect_signals()
	refresh_all_views()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if is_open:
			close_menu()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I or event.keycode == KEY_TAB:
			toggle_menu()
			get_viewport().set_input_as_handled()

func toggle_menu() -> void:
	if is_open:
		close_menu()
	else:
		open_menu()

func open_menu() -> void:
	is_open = true
	visible = true
	get_tree().paused = true
	refresh_all_views()

func close_menu() -> void:
	is_open = false
	visible = false
	get_tree().paused = false
	menu_closed.emit()

func _connect_signals() -> void:
	if stats:
		stats.stats_changed.connect(refresh_equipment_and_stats)
	if artifact_mgr:
		artifact_mgr.artifacts_changed.connect(refresh_equipment_and_stats)
	if skill_mgr:
		skill_mgr.skill_unlocked.connect(func(_b, _s, _r): refresh_skill_tree())
		skill_mgr.skill_tree_reset.connect(refresh_skill_tree)
	if inventory_mgr:
		inventory_mgr.inventory_updated.connect(refresh_inventory_grid)

func refresh_all_views() -> void:
	refresh_equipment_and_stats()
	refresh_inventory_grid()
	refresh_skill_tree()
	refresh_weapon_mastery()
	refresh_crafting_panel()

func refresh_equipment_and_stats() -> void:
	if not stats or not is_inside_tree():
		return
		
	# Update currency label
	if gold_label and inventory_mgr:
		gold_label.text = "Gold: %d  |  Verdant Shards: %d" % [
			inventory_mgr.get_material_count("gold"),
			inventory_mgr.get_material_count("verdant_shard")
		]
	
	# Update unspent points
	if unspent_stat_pts_label:
		unspent_stat_pts_label.text = "Unspent Stat Points: %d" % stats.unspent_stat_points
	
	# Synchronize artifact bonuses into stats
	if artifact_mgr:
		stats.set_equipment_bonuses(artifact_mgr.get_total_stat_bonuses())

func refresh_inventory_grid() -> void:
	# Handled via UI updates when slots are refreshed
	pass

func refresh_skill_tree() -> void:
	if not stats or not skill_mgr or not is_inside_tree():
		return
	if unspent_skill_pts_label:
		unspent_skill_pts_label.text = "Unspent Skill Points: %d" % stats.unspent_skill_points

func refresh_weapon_mastery() -> void:
	pass

func refresh_crafting_panel() -> void:
	pass

func _on_allocate_stat_pressed(stat_name: String) -> void:
	if stats:
		stats.allocate_stat(stat_name, 1)

func _on_respec_stats_pressed() -> void:
	if stats:
		stats.respec_stats()

func _on_respec_skills_pressed() -> void:
	if skill_mgr and stats:
		skill_mgr.reset_skills(stats)
		refresh_skill_tree()
