"""
Unit tests for ECLIPSEBOUND Phase 4 — Enemy & Boss AI Framework.
Validates Perception Systems, Utility AI, Behavior Trees, Boss Personality,
Fight Memory, Persistent Habit Tracking, and 100-Point Adaptation Budget.
"""

import pytest
import math
from typing import List, Dict, Any, Callable


# ============================================================================
# 1. Perception System Simulation & Math Tests
# ============================================================================

class PerceptionSystemPy:
    def __init__(self, vision_range: float = 300.0, fov_deg: float = 90.0, hearing_range: float = 180.0, proximity_range: float = 50.0):
        self.vision_range = vision_range
        self.fov_deg = fov_deg
        self.hearing_range = hearing_range
        self.proximity_range = proximity_range
        self.memory_duration = 3.0
        self.memory_timer = 0.0
        self.can_see_target = False
        self.can_hear_target = False
        self.in_proximity = False
        self.target_known = False

    def update_perception(self, enemy_pos: tuple, enemy_facing: tuple, target_pos: tuple, target_noise_level: float = 0.0, delta: float = 0.1):
        dx = target_pos[0] - enemy_pos[0]
        dy = target_pos[1] - enemy_pos[1]
        dist = math.hypot(dx, dy)

        # Proximity (360 degrees)
        self.in_proximity = dist <= self.proximity_range

        # Hearing
        effective_hearing = self.hearing_range * max(0.2, target_noise_level)
        self.can_hear_target = dist <= effective_hearing

        # Vision cone
        if dist <= self.vision_range and dist > 0.0001:
            # Angle between enemy_facing and to_target
            facing_mag = math.hypot(enemy_facing[0], enemy_facing[1])
            if facing_mag > 0:
                dot = (dx * enemy_facing[0] + dy * enemy_facing[1]) / (dist * facing_mag)
                dot = max(-1.0, min(1.0, dot))
                angle_deg = math.degrees(math.acos(dot))
                self.can_see_target = angle_deg <= (self.fov_deg / 2.0)
            else:
                self.can_see_target = False
        else:
            self.can_see_target = False

        if self.can_see_target or self.can_hear_target or self.in_proximity:
            self.target_known = True
            self.memory_timer = self.memory_duration
        else:
            if self.memory_timer > 0:
                self.memory_timer -= delta
                if self.memory_timer <= 0:
                    self.target_known = False
            else:
                self.target_known = False

        return self.target_known


class TestPerceptionSystem:
    def test_vision_cone_detection(self):
        sensor = PerceptionSystemPy(vision_range=300.0, fov_deg=90.0)
        enemy_pos = (0, 0)
        enemy_facing = (1, 0) # Facing Right

        # Target directly in front (dist 100) -> Should see
        assert sensor.update_perception(enemy_pos, enemy_facing, (100, 0)) is True
        assert sensor.can_see_target is True

        # Target at 40 degrees offset (within 45 deg half-FOV) -> Should see
        offset_x = 100 * math.cos(math.radians(40))
        offset_y = 100 * math.sin(math.radians(40))
        assert sensor.update_perception(enemy_pos, enemy_facing, (offset_x, offset_y)) is True
        assert sensor.can_see_target is True

        # Target at 60 degrees offset (outside 45 deg half-FOV) -> Should NOT see via vision
        offset_x2 = 100 * math.cos(math.radians(60))
        offset_y2 = 100 * math.sin(math.radians(60))
        sensor.update_perception(enemy_pos, enemy_facing, (offset_x2, offset_y2))
        assert sensor.can_see_target is False

    def test_hearing_and_proximity_detection(self):
        sensor = PerceptionSystemPy(vision_range=300.0, hearing_range=150.0, proximity_range=40.0)
        enemy_pos = (0, 0)
        enemy_facing = (1, 0)

        # Behind enemy (angle 180), within proximity (30px) -> Detected
        assert sensor.update_perception(enemy_pos, enemy_facing, (-30, 0)) is True
        assert sensor.in_proximity is True
        assert sensor.can_see_target is False

        # Behind enemy (angle 180), dist 100px, noise 1.0 (within hearing 150px) -> Detected
        assert sensor.update_perception(enemy_pos, enemy_facing, (-100, 0), target_noise_level=1.0) is True
        assert sensor.can_hear_target is True

        # Behind enemy, dist 100px, noise 0.1 (effective hearing = 150 * 0.2 = 30px) -> Not heard
        sensor.update_perception(enemy_pos, enemy_facing, (-100, 0), target_noise_level=0.1)
        assert sensor.can_hear_target is False

    def test_memory_decay(self):
        sensor = PerceptionSystemPy(vision_range=100.0)
        sensor.update_perception((0, 0), (1, 0), (50, 0))
        assert sensor.target_known is True
        assert sensor.memory_timer == 3.0

        # Target vanishes, tick 1.5s -> still known
        sensor.update_perception((0, 0), (1, 0), (500, 0), delta=1.5)
        assert sensor.target_known is True
        assert sensor.memory_timer == 1.5

        # Tick 2.0s -> decays to 0, target forgotten
        sensor.update_perception((0, 0), (1, 0), (500, 0), delta=2.0)
        assert sensor.target_known is False


# ============================================================================
# 2. Utility AI & Response Curves Tests
# ============================================================================

def curve_linear(x: float, min_val: float, max_val: float) -> float:
    if max_val <= min_val: return 0.0
    return max(0.0, min(1.0, (x - min_val) / (max_val - min_val)))

def curve_inverse_linear(x: float, min_val: float, max_val: float) -> float:
    return 1.0 - curve_linear(x, min_val, max_val)

def curve_bell(x: float, peak: float, width: float) -> float:
    if width <= 0.001: return 0.0
    dist = abs(x - peak)
    if dist >= width: return 0.0
    return 1.0 - (dist / width)

class UtilityActionPy:
    def __init__(self, action_id: str, weight: float = 1.0, cooldown: float = 2.0):
        self.action_id = action_id
        self.weight = weight
        self.cooldown = cooldown
        self.current_cd = 0.0
        self.considerations: List[Callable[[Dict[str, Any]], float]] = []

    def score(self, context: Dict[str, Any]) -> float:
        if self.current_cd > 0:
            return 0.0
        if not self.considerations:
            return self.weight
        product = 1.0
        for c in self.considerations:
            val = max(0.0, min(1.0, c(context)))
            product *= val
            if product <= 0.001:
                return 0.0
        return product * self.weight


class TestUtilityAI:
    def test_response_curves(self):
        # Linear: [0, 100]
        assert curve_linear(0, 0, 100) == 0.0
        assert curve_linear(50, 0, 100) == 0.5
        assert curve_linear(100, 0, 100) == 1.0
        assert curve_linear(150, 0, 100) == 1.0

        # Inverse linear: [0, 100]
        assert curve_inverse_linear(0, 0, 100) == 1.0
        assert curve_inverse_linear(50, 0, 100) == 0.5
        assert curve_inverse_linear(100, 0, 100) == 0.0

        # Bell curve: peak at 100, width 50
        assert curve_bell(100, 100, 50) == 1.0
        assert curve_bell(75, 100, 50) == 0.5
        assert curve_bell(125, 100, 50) == 0.5
        assert curve_bell(160, 100, 50) == 0.0

    def test_action_evaluation_and_selection(self):
        # Melee action: prefers short distance
        melee = UtilityActionPy("melee_bite", weight=1.2)
        melee.considerations.append(lambda ctx: curve_inverse_linear(ctx["distance"], 20, 80))

        # Ranged action: prefers medium-long distance
        ranged = UtilityActionPy("spore_spit", weight=1.0)
        ranged.considerations.append(lambda ctx: curve_linear(ctx["distance"], 60, 200))

        # Close range (dist = 30) -> Melee should win
        ctx_close = {"distance": 30}
        score_melee = melee.score(ctx_close)
        score_ranged = ranged.score(ctx_close)
        assert score_melee > score_ranged
        assert score_ranged == 0.0

        # Long range (dist = 180) -> Ranged should win
        ctx_far = {"distance": 180}
        assert ranged.score(ctx_far) > melee.score(ctx_far)

    def test_cooldown_invalidation(self):
        action = UtilityActionPy("dash_strike", cooldown=3.0)
        action.considerations.append(lambda ctx: 1.0)
        assert action.score({}) == 1.0

        # Incur cooldown
        action.current_cd = 2.5
        assert action.score({}) == 0.0


# ============================================================================
# 3. Behavior Tree Framework Tests
# ============================================================================

class NodeStatus:
    SUCCESS = 0
    FAILURE = 1
    RUNNING = 2

class BTNodePy:
    def tick(self, blackboard: dict) -> int:
        raise NotImplementedError

class SequencePy(BTNodePy):
    def __init__(self, children: List[BTNodePy]):
        self.children = children

    def tick(self, blackboard: dict) -> int:
        for child in self.children:
            res = child.tick(blackboard)
            if res != NodeStatus.SUCCESS:
                return res
        return NodeStatus.SUCCESS

class SelectorPy(BTNodePy):
    def __init__(self, children: List[BTNodePy]):
        self.children = children

    def tick(self, blackboard: dict) -> int:
        for child in self.children:
            res = child.tick(blackboard)
            if res != NodeStatus.FAILURE:
                return res
        return NodeStatus.FAILURE

class ActionPy(BTNodePy):
    def __init__(self, fn: Callable[[dict], int]):
        self.fn = fn

    def tick(self, blackboard: dict) -> int:
        return self.fn(blackboard)


class TestBehaviorTree:
    def test_sequence_short_circuit_on_failure(self):
        executed = []
        node = SequencePy([
            ActionPy(lambda bb: executed.append(1) or NodeStatus.SUCCESS),
            ActionPy(lambda bb: executed.append(2) or NodeStatus.FAILURE),
            ActionPy(lambda bb: executed.append(3) or NodeStatus.SUCCESS),
        ])
        status = node.tick({})
        assert status == NodeStatus.FAILURE
        assert executed == [1, 2] # 3 was never reached

    def test_selector_fallback_to_first_success(self):
        executed = []
        node = SelectorPy([
            ActionPy(lambda bb: executed.append("attempt_melee") or NodeStatus.FAILURE),
            ActionPy(lambda bb: executed.append("attempt_charge") or NodeStatus.SUCCESS),
            ActionPy(lambda bb: executed.append("attempt_idle") or NodeStatus.SUCCESS),
        ])
        status = node.tick({})
        assert status == NodeStatus.SUCCESS
        assert executed == ["attempt_melee", "attempt_charge"]


# ============================================================================
# 4. Boss Personality & Fight Memory Tests
# ============================================================================

class CurrentFightMemoryPy:
    def __init__(self, max_events: int = 50):
        self.max_events = max_events
        self.events: List[Dict[str, Any]] = []

    def record_event(self, event_type: str, data: Dict[str, Any]):
        self.events.append({"type": event_type, "data": data})
        if len(self.events) > self.max_events:
            self.events.pop(0)

    def get_parry_frequency(self) -> float:
        attacks = [e for e in self.events if e["type"] in ["player_parry", "player_hit_taken", "player_dodged"]]
        if not attacks: return 0.0
        parries = [e for e in attacks if e["type"] == "player_parry"]
        return len(parries) / len(attacks)

    def get_dodge_bias(self) -> Dict[str, Any]:
        dodges = [e for e in self.events if e["type"] == "player_dodge"]
        if not dodges:
            return {"primary_direction": "NONE", "confidence": 0.0}
        counts = {"LEFT": 0, "RIGHT": 0, "BACKWARD": 0}
        for d in dodges:
            direction = d["data"].get("direction", "NONE")
            if direction in counts:
                counts[direction] += 1
        best_dir = max(counts, key=lambda k: counts[k])
        confidence = counts[best_dir] / len(dodges)
        return {"primary_direction": best_dir, "confidence": confidence}


class TestBossPersonalityAndMemory:
    def test_event_buffer_capping(self):
        mem = CurrentFightMemoryPy(max_events=10)
        for i in range(25):
            mem.record_event("player_attack", {"index": i})
        assert len(mem.events) == 10
        assert mem.events[0]["data"]["index"] == 15
        assert mem.events[-1]["data"]["index"] == 24

    def test_parry_frequency_and_dodge_bias(self):
        mem = CurrentFightMemoryPy()
        # 3 parries, 1 hit taken
        mem.record_event("player_parry", {})
        mem.record_event("player_parry", {})
        mem.record_event("player_hit_taken", {})
        mem.record_event("player_parry", {})
        assert mem.get_parry_frequency() == 0.75

        # 4 dodges: 3 RIGHT, 1 LEFT
        mem.record_event("player_dodge", {"direction": "RIGHT"})
        mem.record_event("player_dodge", {"direction": "RIGHT"})
        mem.record_event("player_dodge", {"direction": "LEFT"})
        mem.record_event("player_dodge", {"direction": "RIGHT"})

        bias = mem.get_dodge_bias()
        assert bias["primary_direction"] == "RIGHT"
        assert bias["confidence"] == 0.75


# ============================================================================
# 5. Adaptation Budget & Strict Fairness Guarantee (350ms Rule)
# ============================================================================

class AdaptationBudgetPy:
    def __init__(self, max_points: int = 100):
        self.max_points = max_points
        self.available_points = max_points
        self.active_tactics: Dict[str, Dict[str, Any]] = {}

    def activate_tactic(self, tactic_id: str, cost: int, min_reaction_ms: int) -> bool:
        # STRICT FAIRNESS GUARANTEE: minimum 350ms reaction window
        if min_reaction_ms < 350:
            raise ValueError(f"Fairness Violation: Tactic '{tactic_id}' telegraph ({min_reaction_ms}ms) < 350ms minimum floor!")

        if tactic_id in self.active_tactics:
            return True # already active

        if self.available_points < cost:
            return False # Budget exhausted! Boss cannot cheat.

        self.available_points -= cost
        self.active_tactics[tactic_id] = {"cost": cost, "min_reaction_ms": min_reaction_ms}
        return True

    def deactivate_tactic(self, tactic_id: str) -> bool:
        if tactic_id in self.active_tactics:
            cost = self.active_tactics[tactic_id]["cost"]
            self.available_points = min(self.max_points, self.available_points + cost)
            del self.active_tactics[tactic_id]
            return True
        return False


class TestAdaptationBudget:
    def test_budget_deduction_and_exhaustion(self):
        budget = AdaptationBudgetPy(max_points=100)
        # Activate 3 tactics totaling 80 points
        assert budget.activate_tactic("feint_cleave", 30, 400) is True
        assert budget.activate_tactic("anti_kite_charge", 30, 420) is True
        assert budget.activate_tactic("shockwave_pulse", 20, 380) is True
        assert budget.available_points == 20

        # Attempting a 25 point tactic must be REJECTED (fairness ceiling)
        assert budget.activate_tactic("overdrive_beam", 25, 360) is False
        assert budget.available_points == 20

        # Reclaim shockwave (20 pts) -> Now has 40 pts -> Can activate overdrive (25 pts)
        budget.deactivate_tactic("shockwave_pulse")
        assert budget.available_points == 40
        assert budget.activate_tactic("overdrive_beam", 25, 360) is True
        assert budget.available_points == 15

    def test_strict_350ms_telegraph_enforcement(self):
        budget = AdaptationBudgetPy()
        # Telegraph of 300ms violates the 350ms fairness guarantee
        with pytest.raises(ValueError, match="Fairness Violation"):
            budget.activate_tactic("instant_counter", 20, 300)
