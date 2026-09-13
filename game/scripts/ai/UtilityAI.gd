# UtilityAI.gd
# Modular Utility AI engine for ECLIPSEBOUND enemies and bosses.
# Evaluates registered actions using normalized response curves based on distance, HP, target threat, and player behavior frequencies.
class_name UtilityAI
extends RefCounted

const UtilityAction = preload("res://scripts/ai/UtilityAction.gd")

var actions: Array = []

func add_action(action) -> void:
	actions.append(action)

func update(delta: float) -> void:
	for a in actions:
		if a.has_method("update_cooldown"):
			a.update_cooldown(delta)

func select_best_action(context: Dictionary):
	var best_action = null
	var best_score: float = -1.0
	
	for a in actions:
		if a.has_method("evaluate_score"):
			var score = a.evaluate_score(context)
			if score > best_score and score > 0.0:
				best_score = score
				best_action = a
			
	return best_action

# --- Response Curve Helper Math ---

static func curve_linear(val: float, min_val: float, max_val: float) -> float:
	if max_val <= min_val:
		return 0.0
	return clampf((val - min_val) / (max_val - min_val), 0.0, 1.0)

static func curve_inverse_linear(val: float, min_val: float, max_val: float) -> float:
	return 1.0 - curve_linear(val, min_val, max_val)

static func curve_smoothstep(val: float, min_val: float, max_val: float) -> float:
	var t = curve_linear(val, min_val, max_val)
	return t * t * (3.0 - 2.0 * t)

static func curve_bell(val: float, center: float, spread: float) -> float:
	var diff = absf(val - center)
	if diff >= spread:
		return 0.0
	return 1.0 - (diff / spread)
