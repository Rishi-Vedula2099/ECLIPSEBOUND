# AdaptationBudget.gd
# 100-Point Fairness Regulator for ECLIPSEBOUND Boss Encounters.
# Strictly limits and regulates adaptive boss countermeasures within hard fairness bounds.
class_name AdaptationBudget
extends RefCounted

signal budget_changed(current_budget: int, max_budget: int)
signal tactic_spent(tactic_name: String, cost: int, remaining: int)
signal fairness_warning(tactic_name: String, reason: String)

const MAX_BUDGET: int = 100
const MIN_TELEGRAPH_MS: float = 350.0  # Strict fairness guarantee: >= 350ms reaction window

# Canonical Tactic Costs
const TACTIC_COSTS: Dictionary = {
	"attack_counter": 20,       # Countering repeated player attacks
	"position_prediction": 15,  # Aiming into player's favored dodge vector
	"pattern_recognition": 20,  # Disrupting light attack / parry spam
	"defense_adjustment": 15,   # Stance hardening or shield raise
	"spawn_adjustment": 10,     # Adding minions to disrupt kiting
	"phase_adjustment": 20      # Enrage / beam activation
}

var current_budget: int = 100
var replenish_rate: float = 3.0  # Points regenerated per second
var budget_accumulator: float = 0.0

func _init(start_budget: int = 100) -> void:
	current_budget = mini(MAX_BUDGET, start_budget)

func update(delta: float) -> void:
	if current_budget < MAX_BUDGET:
		budget_accumulator += replenish_rate * delta
		if budget_accumulator >= 1.0:
			var pts = int(budget_accumulator)
			current_budget = mini(MAX_BUDGET, current_budget + pts)
			budget_accumulator -= float(pts)
			budget_changed.emit(current_budget, MAX_BUDGET)

func get_cost(tactic_name: String) -> int:
	return TACTIC_COSTS.get(tactic_name.to_lower(), 20)

func can_afford(tactic_name: String) -> bool:
	var cost = get_cost(tactic_name)
	return current_budget >= cost

func spend_points(tactic_name: String, declared_telegraph_ms: float = 400.0) -> bool:
	# Enforce 350ms minimum telegraph fairness constraint
	if declared_telegraph_ms < MIN_TELEGRAPH_MS:
		fairness_warning.emit(tactic_name, "Telegraph %.1f ms violates the 350ms fairness guarantee" % declared_telegraph_ms)
		return false
	
	var cost = get_cost(tactic_name)
	if current_budget < cost:
		return false
	
	current_budget -= cost
	tactic_spent.emit(tactic_name, cost, current_budget)
	budget_changed.emit(current_budget, MAX_BUDGET)
	return true

func reset_budget(amount: int = MAX_BUDGET) -> void:
	current_budget = mini(MAX_BUDGET, amount)
	budget_accumulator = 0.0
	budget_changed.emit(current_budget, MAX_BUDGET)

func refund_points(amount: int) -> void:
	current_budget = mini(MAX_BUDGET, current_budget + amount)
	budget_changed.emit(current_budget, MAX_BUDGET)
