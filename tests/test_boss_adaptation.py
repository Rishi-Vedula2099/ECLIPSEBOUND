# tests/test_boss_adaptation.py
"""Unit tests verifying Hollow Stag boss multi-phase transition, 100-point fairness budget, and telegraph constraints."""
import os
import re
import pytest


class HollowStagPy:
    """Python reference mirroring HollowStag.gd adaptive decision engine."""

    def __init__(self, max_hp=900.0):
        self.max_hp = max_hp
        self.current_hp = max_hp
        self.phase = 1
        self.adaptation_budget = 100
        self.observed_parries = 0
        self.observed_dodges = 0
        self.observed_attacks = 0

    def receive_damage(self, amount: float):
        self.current_hp = max(0.0, self.current_hp - amount)
        if self.phase == 1 and self.current_hp <= (self.max_hp * 0.50):
            self.phase = 2
            self.adaptation_budget = 100  # Replenish for Phase 2
            return "PHASE_TRANSITION"
        return "DAMAGED"

    def select_tactical_action(self, player_dist: float) -> str:
        parry_ratio = float(self.observed_parries) / max(1.0, float(self.observed_attacks))
        dodge_ratio = float(self.observed_dodges) / max(1.0, float(self.observed_attacks))

        # Tactic 1: Attack Counter (20 pts) in Phase 2 against parry spam
        if parry_ratio > 0.40 and self.phase == 2 and self.adaptation_budget >= 20:
            self.adaptation_budget -= 20
            return "ECLIPSE_BEAM"

        # Tactic 2: Position Prediction (15 pts) against spacing or dodge spam
        if (player_dist > 110.0 or dodge_ratio > 0.50) and self.adaptation_budget >= 15:
            self.adaptation_budget -= 15
            return "GALLOP_CHARGE"

        # Tactic 3: Close Melee Pattern
        if player_dist <= 75.0:
            return "ANTLER_SWEEP"

        return "REPOSITION"


# --- Test Cases ---

def test_boss_phase_transition_at_50_percent_hp():
    boss = HollowStagPy(max_hp=900.0)
    assert boss.phase == 1

    # Damage to 60% HP
    res = boss.receive_damage(360.0)
    assert boss.current_hp == 540.0
    assert boss.phase == 1
    assert res == "DAMAGED"

    # Damage past 50% HP threshold (450 HP)
    res2 = boss.receive_damage(100.0)
    assert boss.current_hp == 440.0
    assert boss.phase == 2
    assert res2 == "PHASE_TRANSITION"
    assert boss.adaptation_budget == 100


def test_fairness_budget_deduction_and_counter_actions():
    boss = HollowStagPy()
    boss.phase = 2
    boss.observed_attacks = 10
    boss.observed_parries = 6  # 60% parry ratio > 40%

    # High parry ratio triggers Eclipse Beam and spends 20 pts
    action = boss.select_tactical_action(player_dist=80.0)
    assert action == "ECLIPSE_BEAM"
    assert boss.adaptation_budget == 80

    # When player stops parrying and maintains range, triggers Gallop Charge and spends 15 pts
    boss.observed_parries = 1  # 10% parry ratio <= 40%
    action2 = boss.select_tactical_action(player_dist=150.0)
    assert action2 == "GALLOP_CHARGE"
    assert boss.adaptation_budget == 65


def test_budget_exhaustion_prevents_excessive_counter_tactics():
    boss = HollowStagPy()
    boss.phase = 2
    boss.observed_attacks = 10
    boss.observed_parries = 8
    boss.adaptation_budget = 10  # Insufficient budget (< 20 pts)

    # Cannot trigger Eclipse Beam (20 pts needed); falls back to close pattern or reposition
    action = boss.select_tactical_action(player_dist=60.0)
    assert action == "ANTLER_SWEEP"
    assert boss.adaptation_budget == 10  # Budget unchanged


def test_boss_attack_resources_meet_350ms_telegraph_rule():
    """Verify all authored boss attacks have startup_time >= 0.35s (350ms fairness guarantee)."""
    attacks_dir = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "game", "data", "attacks", "boss")
    )
    assert os.path.isdir(attacks_dir), f"Boss attacks directory not found: {attacks_dir}"

    for f in os.listdir(attacks_dir):
        if f.endswith(".tres"):
            filepath = os.path.join(attacks_dir, f)
            with open(filepath, "r", encoding="utf-8") as stream:
                content = stream.read()
            match = re.search(r"startup_time\s*=\s*([0-9.]+)", content)
            assert match, f"startup_time not found in {f}"
            startup = float(match.group(1))
            assert startup >= 0.35, f"Attack {f} violates 350ms telegraph rule (startup was {startup}s)"
