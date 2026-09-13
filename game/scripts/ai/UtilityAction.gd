# UtilityAction.gd
# Data and evaluation logic for an individual Utility AI action.
class_name UtilityAction
extends RefCounted

var action_name: String = "ACTION"
var base_weight: float = 1.0
var cooldown: float = 0.0
var current_cooldown_timer: float = 0.0

# Considerations: array of Callable functions returning float between 0.0 and 1.0
var considerations: Array[Callable] = []

func _init(aname: String = "ACTION", weight: float = 1.0, cd: float = 0.0) -> void:
	action_name = aname
	base_weight = weight
	cooldown = cd
	current_cooldown_timer = 0.0

func add_consideration(c: Callable) -> void:
	considerations.append(c)

func evaluate_score(context: Dictionary) -> float:
	if current_cooldown_timer > 0.0:
		return 0.0
	
	var score: float = base_weight
	for c in considerations:
		var factor: float = clampf(float(c.call(context)), 0.0, 1.0)
		score *= factor
		if score <= 0.001:
			return 0.0
	return score

func trigger() -> void:
	current_cooldown_timer = cooldown

func update_cooldown(delta: float) -> void:
	if current_cooldown_timer > 0.0:
		current_cooldown_timer = maxf(0.0, current_cooldown_timer - delta)
