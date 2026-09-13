# FairnessEngine.gd
# Central authority enforcing the 100-Point Fairness Budget and strict anti-frustration
# constraints across all bosses and adaptive encounters in ECLIPSEBOUND.
class_name FairnessEngine
extends RefCounted

signal adaptation_approved(tactic_id: String, cost: int, category: String)
signal adaptation_rejected(tactic_id: String, reason: String)
signal budget_depleted()
signal fairness_violation_flagged(rule: String, details: Dictionary)

const TOTAL_BUDGET: int = 100
const MIN_TELEGRAPH_WINDOW_MS: int = 350
const MIN_PATTERN_CONFIDENCE: float = 0.75

# Category maximum point caps as defined in Phase 5 roadmap
const CATEGORY_CAPS: Dictionary = {
	"attack_counter": 20,
	"position_prediction": 15,
	"pattern_recognition": 20,
	"defense_adjustment": 15,
	"spawn_adjustment": 10,
	"phase_adjustment": 20,
}

# Approved minion encounter pools per world
const APPROVED_SPAWN_POOLS: Dictionary = {
	1: ["BrambleBeast", "MossGnat", "VerdantSlime"],
	2: ["DrownedMatriarchMinion", "BogCreeper"],
}

# Currently active adaptations: { tactic_id: { category, cost, metadata } }
var active_adaptations: Dictionary = {}
var allocated_points: int = 0

# Last spawn timestamp for spawn rate-limiting
var last_spawn_timestamp: float = 0.0
const MIN_SPAWN_INTERVAL_SEC: float = 12.0


func get_available_budget() -> int:
	return TOTAL_BUDGET - allocated_points


# ---------------------------------------------------------
# Adaptation Request Evaluation (Pre-Flight Audit)
# ---------------------------------------------------------

# Returns Dictionary: { "approved": bool, "reason": String }
func request_adaptation(
	tactic_id: String,
	category: String,
	point_cost: int,
	metadata: Dictionary = {}
) -> Dictionary:
	# 1. Validate category existence
	if not CATEGORY_CAPS.has(category):
		var err = "Invalid adaptation category: %s" % category
		emit_signal("adaptation_rejected", tactic_id, err)
		return {"approved": false, "reason": err}

	# 2. Validate category cost limit
	var max_cat_cost: int = CATEGORY_CAPS[category]
	if point_cost > max_cat_cost:
		var err = "Point cost %d exceeds category '%s' max ceiling of %d" % [point_cost, category, max_cat_cost]
		emit_signal("adaptation_rejected", tactic_id, err)
		return {"approved": false, "reason": err}

	# 3. Check overall 100-point budget ceiling
	if (allocated_points + point_cost) > TOTAL_BUDGET:
		var err = "100-Point Budget Exhausted! (Allocated: %d, Requested: %d, Cap: %d)" % [allocated_points, point_cost, TOTAL_BUDGET]
		emit_signal("adaptation_rejected", tactic_id, err)
		emit_signal("budget_depleted")
		return {"approved": false, "reason": err}

	# 4. Enforce strict category-specific constraints
	var constraint_check = _check_category_constraints(category, metadata)
	if not constraint_check["approved"]:
		emit_signal("adaptation_rejected", tactic_id, constraint_check["reason"])
		emit_signal("fairness_violation_flagged", category, {"tactic_id": tactic_id, "reason": constraint_check["reason"]})
		return constraint_check

	# 5. Approve & Allocate
	active_adaptations[tactic_id] = {
		"category": category,
		"cost": point_cost,
		"metadata": metadata,
		"timestamp": Time.get_ticks_msec() / 1000.0,
	}
	allocated_points += point_cost
	emit_signal("adaptation_approved", tactic_id, point_cost, category)
	return {"approved": true, "reason": "Approved within fairness budget."}


func release_adaptation(tactic_id: String) -> bool:
	if not active_adaptations.has(tactic_id):
		return false
	var entry = active_adaptations[tactic_id]
	allocated_points = maxi(0, allocated_points - entry["cost"])
	active_adaptations.erase(tactic_id)
	return true


func release_all() -> void:
	active_adaptations.clear()
	allocated_points = 0


# ---------------------------------------------------------
# Category Constraint Verifiers
# ---------------------------------------------------------

func _check_category_constraints(category: String, meta: Dictionary) -> Dictionary:
	match category:
		"attack_counter":
			# Constraint: Authored telegraph required; minimum 350ms reaction window
			var telegraph_ms: int = meta.get("telegraph_ms", 0)
			if telegraph_ms < MIN_TELEGRAPH_WINDOW_MS:
				return {
					"approved": false,
					"reason": "Telegraph window (%d ms) violates strict >= %d ms reaction floor" % [telegraph_ms, MIN_TELEGRAPH_WINDOW_MS]
				}
			if not meta.get("has_authored_vfx", false):
				return {
					"approved": false,
					"reason": "Attack counter lacks authored high-contrast visual/audio tell"
				}

		"position_prediction":
			# Constraint: Bounded positioning bias; strictly no instant teleports behind player
			if meta.get("is_instant_teleport_behind", false):
				return {
					"approved": false,
					"reason": "Prohibited: Cannot instantly teleport behind player without anticipatory telegraph"
				}
			var bias_angle: float = meta.get("bias_angle_deg", 0.0)
			if absf(bias_angle) > 90.0:
				return {
					"approved": false,
					"reason": "Position prediction exceeds maximum bounded positioning bias (90 deg)"
				}

		"pattern_recognition":
			# Constraint: Requires high signal confidence (>0.75); decays if counter fails
			var confidence: float = meta.get("signal_confidence", 0.0)
			if confidence < MIN_PATTERN_CONFIDENCE:
				return {
					"approved": false,
					"reason": "Signal confidence (%.2f) below strict minimum threshold of %.2f" % [confidence, MIN_PATTERN_CONFIDENCE]
				}

		"defense_adjustment":
			# Constraint: Authored stance change; no invisible invulnerability
			if meta.get("has_invisible_iframes", false):
				return {
					"approved": false,
					"reason": "Prohibited: Defense adjustment cannot grant invisible invulnerability"
				}
			if not meta.get("has_stance_animation", false):
				return {
					"approved": false,
					"reason": "Defense adjustment requires explicit visual stance change"
				}

		"spawn_adjustment":
			# Constraint: Minion spawn compositions from approved encounter pools & rate-limited
			var world_id: int = meta.get("world_id", 1)
			var enemy_type: String = meta.get("enemy_type", "")
			var pool: Array = APPROVED_SPAWN_POOLS.get(world_id, [])
			if not pool.has(enemy_type):
				return {
					"approved": false,
					"reason": "Enemy type '%s' is not in approved spawn pool for World %d" % [enemy_type, world_id]
				}
			var now: float = Time.get_ticks_msec() / 1000.0
			if (now - last_spawn_timestamp) < MIN_SPAWN_INTERVAL_SEC:
				return {
					"approved": false,
					"reason": "Spawn adjustment rate-limited (minimum %ds interval)" % int(MIN_SPAWN_INTERVAL_SEC)
				}
			last_spawn_timestamp = now

		"phase_adjustment":
			# Constraint: Triggered strictly at HP thresholds (75%, 50%, 25%)
			var hp_percentage: float = meta.get("boss_hp_percent", 100.0)
			var valid_thresholds = [75.0, 50.0, 25.0]
			var matches_threshold: bool = false
			for th in valid_thresholds:
				if absf(hp_percentage - th) <= 2.0: # 2% tolerance band
					matches_threshold = true
					break
			if not matches_threshold:
				return {
					"approved": false,
					"reason": "Phase adjustment invalid at HP %.1f%%; must be within 2%% of 75%%, 50%%, or 25%%" % hp_percentage
				}

	return {"approved": true, "reason": "All category constraints satisfied."}


# ---------------------------------------------------------
# Audit State Summary
# ---------------------------------------------------------

func get_budget_state() -> Dictionary:
	return {
		"total_budget": TOTAL_BUDGET,
		"allocated_points": allocated_points,
		"available_points": get_available_budget(),
		"active_tactics_count": active_adaptations.size(),
		"active_tactics": active_adaptations.duplicate(true),
		"category_caps": CATEGORY_CAPS.duplicate(),
	}
