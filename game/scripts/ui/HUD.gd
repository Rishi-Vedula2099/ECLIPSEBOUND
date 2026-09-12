# HUD.gd
# Pixel-art HUD controller for health, stamina, energy, combos, and status badges.
class_name HUD
extends CanvasLayer

@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/TopBars/HealthBar
@onready var health_ghost_bar: ProgressBar = $MarginContainer/VBoxContainer/TopBars/HealthBar/GhostBar
@onready var stamina_bar: ProgressBar = $MarginContainer/VBoxContainer/TopBars/StaminaBar
@onready var energy_bar: ProgressBar = $MarginContainer/VBoxContainer/TopBars/EnergyBar
@onready var combo_label: Label = $MarginContainer/VBoxContainer/ComboContainer/ComboLabel
@onready var combo_bar: ProgressBar = $MarginContainer/VBoxContainer/ComboContainer/ComboBar
@onready var status_container: HBoxContainer = $MarginContainer/VBoxContainer/StatusContainer

var target_hp: float = 225.0
var max_hp: float = 225.0

func _ready() -> void:
	CombatSystem.combo_updated.connect(_on_combo_updated)
	CombatSystem.combo_reset.connect(_on_combo_reset)
	CombatSystem.status_applied.connect(_on_status_applied)
	
	# Connect to player spawned
	EventBus.player_spawned.connect(_on_player_spawned)

func _process(delta: float) -> void:
	# Ghost health bar catches up smoothly
	if health_ghost_bar and health_ghost_bar.value > health_bar.value:
		health_ghost_bar.value = move_toward(health_ghost_bar.value, health_bar.value, 45.0 * delta)
	
	# Combo bar decay visualization
	if combo_bar and CombatSystem.current_combo > 0:
		combo_bar.value = (CombatSystem.combo_timer / CombatSystem.COMBO_TIMEOUT) * 100.0

func _on_player_spawned(player: Node2D) -> void:
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)
	if player.has_signal("stamina_changed"):
		player.stamina_changed.connect(_on_stamina_changed)
	if player.has_signal("energy_changed"):
		player.energy_changed.connect(_on_energy_changed)

func _on_health_changed(current: float, max_val: float) -> void:
	max_hp = max_val
	target_hp = current
	if health_bar:
		health_bar.max_value = max_val
		health_bar.value = current
	if health_ghost_bar:
		health_ghost_bar.max_value = max_val

func _on_stamina_changed(current: float, max_val: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = max_val
		stamina_bar.value = current

func _on_energy_changed(current: float, max_val: float) -> void:
	if energy_bar:
		energy_bar.max_value = max_val
		energy_bar.value = current

func _on_combo_updated(count: int, bonus: float) -> void:
	if combo_label:
		combo_label.text = "COMBO x%d (+%d%%)" % [count, int((bonus - 1.0) * 100.0)]
		combo_label.visible = true
	if combo_bar:
		combo_bar.visible = true

func _on_combo_reset() -> void:
	if combo_label:
		combo_label.visible = false
	if combo_bar:
		combo_bar.visible = false

func _on_status_applied(_target: Node2D, status_name: String, _duration: float) -> void:
	if status_container:
		# Flash status indicator badge
		var badge = Label.new()
		badge.text = "[" + status_name + "]"
		badge.modulate = Color("#ff3860")
		status_container.add_child(badge)
		# Auto remove after 2.5s
		get_tree().create_timer(2.5).timeout.connect(func(): if is_instance_valid(badge): badge.queue_free())
