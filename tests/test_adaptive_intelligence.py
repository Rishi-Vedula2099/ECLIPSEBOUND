# tests/test_adaptive_intelligence.py
"""
Unit tests for ECLIPSEBOUND Phase 5 — Adaptive Game Intelligence & Fairness Engine.
Validates Player Behavioral Fingerprint (EWMA & Bayesian confidence), 6 Signal Categories,
Temporal/Failure Decay, 100-Point Budget Ceiling, and 6 Strict Category Constraints.
"""

import pytest
import math
from typing import Dict, Any, List
import sys
import os

# Add backend directory to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'backend')))

from app.schemas.telemetry import (
    PlayerFingerprint,
    TelemetryEvent,
    FairnessAuditRequest,
    FairnessAuditResult,
)
from app.services.fingerprint_service import FingerprintService, TOTAL_BUDGET, CATEGORY_CAPS


# ============================================================================
# 1. Behavioral Fingerprint Simulation & Math Tests
# ============================================================================

class BehavioralFingerprintPy:
    def __init__(self, alpha: float = 0.20):
        self.alpha = alpha
        # Offense
        self.light_heavy_ratio = 0.5
        self.avg_combo_length = 2.0
        self.total_attacks = 0
        # Defense
        self.dodge_rate = 0.5
        self.parry_rate = 0.5
        self.damage_taken_sum = 0.0
        self.hits_taken = 0
        self.damage_per_hit = 0.0
        # Positioning
        self.time_melee = 0.0
        self.time_mid = 0.0
        self.time_ranged = 0.0
        self.primary_distance_pref = "MID"
        # Mobility
        self.dodge_counts = {"LEFT": 0, "RIGHT": 0, "BACKWARD": 0}
        self.dodge_direction_bias = "NONE"
        self.dodge_direction_confidence = 0.33
        # Risk
        self.low_hp_aggression = 0.5

    def record_attack(self, is_heavy: bool, combo_step: int):
        self.total_attacks += 1
        inst_ratio = 0.0 if is_heavy else 1.0
        self.light_heavy_ratio = (self.alpha * inst_ratio) + ((1.0 - self.alpha) * self.light_heavy_ratio)
        self.avg_combo_length = (self.alpha * combo_step) + ((1.0 - self.alpha) * self.avg_combo_length)

    def record_hit_resolved(self, outcome: str, damage: float = 0.0):
        is_dodge = 1.0 if outcome == "dodge" else 0.0
        is_parry = 1.0 if outcome == "parry" else 0.0
        self.dodge_rate = (self.alpha * is_dodge) + ((1.0 - self.alpha) * self.dodge_rate)
        self.parry_rate = (self.alpha * is_parry) + ((1.0 - self.alpha) * self.parry_rate)
        if outcome == "hit_taken":
            self.hits_taken += 1
            self.damage_taken_sum += damage
            self.damage_per_hit = self.damage_taken_sum / self.hits_taken

    def record_dodge(self, direction: str):
        direction = direction.upper()
        if direction not in self.dodge_counts:
            direction = "RIGHT"
        self.dodge_counts[direction] += 1
        total = sum(self.dodge_counts.values())
        best_dir = max(self.dodge_counts, key=lambda k: self.dodge_counts[k])
        self.dodge_direction_bias = best_dir
        # Bayesian prior with K=3
        self.dodge_direction_confidence = (self.dodge_counts[best_dir] + 1) / (total + 3)

    def record_positioning(self, distance: float, delta: float):
        if distance < 80.0:
            self.time_melee += delta
        elif distance <= 200.0:
            self.time_mid += delta
        else:
            self.time_ranged += delta

        if self.time_melee >= self.time_mid and self.time_melee >= self.time_ranged:
            self.primary_distance_pref = "MELEE"
        elif self.time_mid >= self.time_melee and self.time_mid >= self.time_ranged:
            self.primary_distance_pref = "MID"
        else:
            self.primary_distance_pref = "RANGED"

    def decay_on_counter_failure(self):
        # Strict rule: 50% confidence decay on counter failure
        self.dodge_direction_confidence = max(0.15, self.dodge_direction_confidence * 0.50)
        self.parry_rate = max(0.10, self.parry_rate * 0.70)

    def apply_temporal_decay(self, delta: float, half_life: float = 60.0):
        decay_factor = 0.5 ** (delta / half_life)
        self.light_heavy_ratio = 0.5 + (self.light_heavy_ratio - 0.5) * decay_factor
        self.dodge_rate = 0.5 + (self.dodge_rate - 0.5) * decay_factor
        self.parry_rate = 0.5 + (self.parry_rate - 0.5) * decay_factor
        self.dodge_direction_confidence = max(0.33, self.dodge_direction_confidence * decay_factor)


class TestBehavioralFingerprint:
    def test_ewma_attack_and_defense_updates(self):
        fp = BehavioralFingerprintPy(alpha=0.20)
        # 5 consecutive light attacks: ratio starts at 0.5, asymptotically approaches 1.0
        for _ in range(5):
            fp.record_attack(is_heavy=False, combo_step=3)
        assert fp.light_heavy_ratio > 0.65
        assert fp.avg_combo_length > 2.2

        # 3 parries: parry rate increases
        for _ in range(3):
            fp.record_hit_resolved("parry")
        assert fp.parry_rate > 0.60

        # Hit taken: damage per hit calculated
        fp.record_hit_resolved("hit_taken", damage=50.0)
        assert fp.damage_per_hit == 50.0

    def test_bayesian_dodge_direction_and_counter_decay(self):
        fp = BehavioralFingerprintPy()
        # Record 6 RIGHT dodges and 1 LEFT dodge
        for _ in range(6):
            fp.record_dodge("RIGHT")
        fp.record_dodge("LEFT")

        assert fp.dodge_direction_bias == "RIGHT"
        # Total = 7, Best = 6 -> (6 + 1) / (7 + 3) = 7 / 10 = 0.70
        assert round(fp.dodge_direction_confidence, 2) == 0.70

        # Simulate boss deploying counter tactic and failing (player punishes boss)
        prev_conf = fp.dodge_direction_confidence
        fp.decay_on_counter_failure()
        assert fp.dodge_direction_confidence == prev_conf * 0.50

    def test_positioning_residence_preference(self):
        fp = BehavioralFingerprintPy()
        # 5 seconds at 50px (Melee)
        fp.record_positioning(50.0, 5.0)
        assert fp.primary_distance_pref == "MELEE"

        # 8 seconds at 150px (Mid) -> Now Mid dominates
        fp.record_positioning(150.0, 8.0)
        assert fp.primary_distance_pref == "MID"

    def test_temporal_decay_toward_baseline(self):
        fp = BehavioralFingerprintPy()
        fp.light_heavy_ratio = 0.95
        # 60s elapsed (one half-life) -> (0.95 - 0.5) * 0.5 = 0.225 -> ratio approx 0.725
        fp.apply_temporal_decay(60.0, half_life=60.0)
        assert abs(fp.light_heavy_ratio - 0.725) < 0.05


# ============================================================================
# 2. Fairness Engine & Strict Category Constraint Tests
# ============================================================================

class TestFairnessEngineRules:
    @pytest.fixture
    def service(self):
        return FingerprintService()

    def test_100_point_budget_ceiling(self, service):
        # 80 points already allocated
        req = FairnessAuditRequest(
            tactic_id="heavy_sweep",
            category="attack_counter",
            point_cost=20,
            current_allocated_points=85,
            metadata={"telegraph_ms": 400}
        )
        res = service.evaluate_fairness_audit(req)
        assert res.approved is False
        assert "budget exhausted" in res.reason.lower()

    def test_category_cost_caps(self, service):
        # Position prediction has max cap of 15 pts
        req = FairnessAuditRequest(
            tactic_id="overpriced_dash",
            category="position_prediction",
            point_cost=18,
            current_allocated_points=0,
            metadata={}
        )
        res = service.evaluate_fairness_audit(req)
        assert res.approved is False
        assert "exceeds category cap" in res.reason.lower()

    def test_attack_counter_350ms_rule(self, service):
        # Telegraph 300ms < 350ms minimum floor
        req_fail = FairnessAuditRequest(
            tactic_id="fast_counter",
            category="attack_counter",
            point_cost=20,
            current_allocated_points=0,
            metadata={"telegraph_ms": 300}
        )
        assert service.evaluate_fairness_audit(req_fail).approved is False

        # Telegraph 380ms >= 350ms -> Approved
        req_pass = FairnessAuditRequest(
            tactic_id="valid_counter",
            category="attack_counter",
            point_cost=20,
            current_allocated_points=0,
            metadata={"telegraph_ms": 380}
        )
        assert service.evaluate_fairness_audit(req_pass).approved is True

    def test_position_prediction_teleport_restriction(self, service):
        # Prohibit instant teleports behind player
        req = FairnessAuditRequest(
            tactic_id="behind_teleport",
            category="position_prediction",
            point_cost=15,
            current_allocated_points=0,
            metadata={"is_instant_teleport_behind": True}
        )
        res = service.evaluate_fairness_audit(req)
        assert res.approved is False
        assert "prohibited" in res.reason.lower()

    def test_pattern_recognition_confidence_threshold(self, service):
        # Confidence 0.65 < 0.75 threshold
        req_low = FairnessAuditRequest(
            tactic_id="pattern_counter",
            category="pattern_recognition",
            point_cost=20,
            current_allocated_points=0,
            metadata={"signal_confidence": 0.65}
        )
        assert service.evaluate_fairness_audit(req_low).approved is False

        # Confidence 0.85 >= 0.75 -> Approved
        req_high = FairnessAuditRequest(
            tactic_id="pattern_counter",
            category="pattern_recognition",
            point_cost=20,
            current_allocated_points=0,
            metadata={"signal_confidence": 0.85}
        )
        assert service.evaluate_fairness_audit(req_high).approved is True

    def test_defense_adjustment_invisible_iframes_restriction(self, service):
        # Invisible iframes prohibited
        req = FairnessAuditRequest(
            tactic_id="ghost_armor",
            category="defense_adjustment",
            point_cost=15,
            current_allocated_points=0,
            metadata={"has_invisible_iframes": True}
        )
        res = service.evaluate_fairness_audit(req)
        assert res.approved is False
        assert "invisible invulnerability" in res.reason.lower()

    def test_spawn_adjustment_approved_pool(self, service):
        # Invalid enemy type
        req_invalid = FairnessAuditRequest(
            tactic_id="spawn_dragon",
            category="spawn_adjustment",
            point_cost=10,
            current_allocated_points=0,
            metadata={"world_id": 1, "enemy_type": "VoidDragon"}
        )
        assert service.evaluate_fairness_audit(req_invalid).approved is False

        # Valid enemy type from World 1 pool
        req_valid = FairnessAuditRequest(
            tactic_id="spawn_gnats",
            category="spawn_adjustment",
            point_cost=10,
            current_allocated_points=0,
            metadata={"world_id": 1, "enemy_type": "MossGnat"}
        )
        assert service.evaluate_fairness_audit(req_valid).approved is True

    def test_phase_adjustment_hp_milestones(self, service):
        # Invalid HP (60% is not near 75%, 50%, or 25%)
        req_invalid = FairnessAuditRequest(
            tactic_id="phase_shift",
            category="phase_adjustment",
            point_cost=20,
            current_allocated_points=0,
            metadata={"boss_hp_percent": 60.0}
        )
        assert service.evaluate_fairness_audit(req_invalid).approved is False

        # Valid HP (50.0% is exact milestone)
        req_valid = FairnessAuditRequest(
            tactic_id="phase_shift",
            category="phase_adjustment",
            point_cost=20,
            current_allocated_points=0,
            metadata={"boss_hp_percent": 50.0}
        )
        assert service.evaluate_fairness_audit(req_valid).approved is True
