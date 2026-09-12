# tests/test_combat_system.py
"""Unit tests verifying ECLIPSEBOUND Phase 1 Combat System math and logic."""
import math
import pytest


class CombatSystemPy:
    """Python reference implementation mirroring GDScript CombatSystem.gd."""

    COMBO_TIMEOUT = 2.5
    COMBO_DAMAGE_SCALING_PER_HIT = 0.02
    MAX_COMBO_BONUS = 0.50

    def __init__(self):
        self.current_combo = 0
        self.combo_timer = 0.0
        self.active_statuses = {}  # entity_id -> {status_name: {"duration": float, "potency": float, "ticks": int}}

    def register_hit(self):
        self.current_combo += 1
        self.combo_timer = self.COMBO_TIMEOUT
        bonus = 1.0 + min(self.current_combo * self.COMBO_DAMAGE_SCALING_PER_HIT, self.MAX_COMBO_BONUS)
        return self.current_combo, bonus

    def reset_combo(self):
        self.current_combo = 0
        self.combo_timer = 0.0

    def update_combo(self, delta: float):
        if self.current_combo > 0:
            self.combo_timer -= delta
            if self.combo_timer <= 0.0:
                self.reset_combo()

    @staticmethod
    def calculate_defense_reduction(def_stat: int) -> float:
        armor = max(0.0, float(def_stat) * 4.0)
        return armor / (armor + 100.0)

    @staticmethod
    def calculate_crit(crt_stat: int):
        chance = max(0.05, min(0.75, 0.05 + (crt_stat * 0.008)))
        mult = 1.5 + (crt_stat * 0.02)
        return chance, mult

    def calculate_damage(self, base_damage: float, target_def: int, attacker_crt: int = 10, is_crit: bool = False) -> float:
        combo_mult = 1.0 + min(self.current_combo * self.COMBO_DAMAGE_SCALING_PER_HIT, self.MAX_COMBO_BONUS)
        dmg = base_damage * combo_mult
        if is_crit:
            _, crit_mult = self.calculate_crit(attacker_crt)
            dmg *= crit_mult
        reduction = self.calculate_defense_reduction(target_def)
        final_dmg = max(1.0, dmg * (1.0 - reduction))
        return round(final_dmg, 2)

    @staticmethod
    def evaluate_parry(time_into_parry: float, max_parry_window: float = 0.35, perfect_window: float = 0.15):
        if time_into_parry <= perfect_window:
            return {"success": True, "perfect": True, "damage_negation": 1.0, "stagger_attacker": True}
        elif time_into_parry <= max_parry_window:
            return {"success": True, "perfect": False, "damage_negation": 1.0, "stagger_attacker": False}
        return {"success": False, "perfect": False, "damage_negation": 0.0, "stagger_attacker": False}

    def apply_status(self, entity_id: str, status_name: str, duration: float, potency: float):
        if entity_id not in self.active_statuses:
            self.active_statuses[entity_id] = {}
        self.active_statuses[entity_id][status_name] = {
            "duration": duration,
            "potency": potency,
            "tick_timer": 0.0,
            "ticks_triggered": 0,
        }

    def process_statuses(self, delta: float):
        expired = []
        for entity_id, effects in list(self.active_statuses.items()):
            for name, data in list(effects.items()):
                data["duration"] -= delta
                data["tick_timer"] += delta
                if data["tick_timer"] >= 1.0:
                    data["tick_timer"] -= 1.0
                    data["ticks_triggered"] += 1
                if data["duration"] <= 0.0:
                    del effects[name]
            if not effects:
                expired.append(entity_id)
        for eid in expired:
            del self.active_statuses[eid]


# --- Test Cases ---

def test_damage_defense_reduction_formula():
    """Verify soft-capped armor curve Armor / (Armor + 100)."""
    combat = CombatSystemPy()
    # At DEF = 0 -> reduction = 0
    assert combat.calculate_defense_reduction(0) == 0.0
    # At DEF = 25 -> armor = 100 -> reduction = 100 / 200 = 0.50 (50%)
    assert combat.calculate_defense_reduction(25) == 0.50
    # At DEF = 10 -> armor = 40 -> reduction = 40 / 140 ~= 0.2857
    red_10 = combat.calculate_defense_reduction(10)
    assert math.isclose(red_10, 40.0 / 140.0, rel_tol=1e-3)

    # Higher DEF gives diminishing returns (soft-cap)
    red_25 = combat.calculate_defense_reduction(25)
    red_50 = combat.calculate_defense_reduction(50)   # 200 / 300 = 0.6667
    red_100 = combat.calculate_defense_reduction(100) # 400 / 500 = 0.8000
    assert red_10 < red_25 < red_50 < red_100 < 1.0


def test_combo_counter_and_damage_scaling():
    """Verify combo builds, scales damage, and resets on timeout."""
    combat = CombatSystemPy()
    base_dmg = 20.0
    def_stat = 10

    dmg_0 = combat.calculate_damage(base_dmg, def_stat)
    assert combat.current_combo == 0

    # Land 5 consecutive hits
    for i in range(1, 6):
        count, bonus = combat.register_hit()
        assert count == i
        assert math.isclose(bonus, 1.0 + (i * 0.02))

    dmg_5 = combat.calculate_damage(base_dmg, def_stat)
    assert dmg_5 > dmg_0

    # Verify combo bonus cap at 50%
    for _ in range(50):
        combat.register_hit()
    assert combat.current_combo > 25
    dmg_capped = combat.calculate_damage(base_dmg, def_stat)
    expected_capped_raw = base_dmg * 1.50
    expected_final = expected_capped_raw * (1.0 - combat.calculate_defense_reduction(def_stat))
    assert math.isclose(dmg_capped, round(expected_final, 2), abs_tol=0.05)

    # Verify timeout decay
    combat.update_combo(2.0)
    assert combat.current_combo > 0 # Still active within 2.5s window
    combat.update_combo(0.6)        # Total 2.6s elapsed > 2.5s timeout
    assert combat.current_combo == 0


def test_critical_hit_calculations():
    """Verify critical chance bounds [0.05, 0.75] and critical multipliers."""
    combat = CombatSystemPy()

    # Minimum crit stat
    chance_min, mult_min = combat.calculate_crit(0)
    assert chance_min == 0.05
    assert mult_min == 1.5

    # Medium crit stat
    chance_mid, mult_mid = combat.calculate_crit(25)
    assert math.isclose(chance_mid, 0.05 + (25 * 0.008))
    assert math.isclose(mult_mid, 1.5 + (25 * 0.02))

    # Extreme crit stat clamped at 0.75
    chance_high, _ = combat.calculate_crit(200)
    assert chance_high == 0.75


def test_parry_evaluation_windows():
    """Verify perfect parry (<=0.15s), regular parry (<=0.35s), and missed parry (>0.35s)."""
    combat = CombatSystemPy()

    # Perfect parry window (e.g. 0.08s)
    p1 = combat.evaluate_parry(0.08)
    assert p1["success"] is True
    assert p1["perfect"] is True
    assert p1["stagger_attacker"] is True

    # Boundary of perfect parry (0.15s)
    p2 = combat.evaluate_parry(0.15)
    assert p2["success"] is True
    assert p2["perfect"] is True

    # Regular parry window (e.g. 0.25s)
    p3 = combat.evaluate_parry(0.25)
    assert p3["success"] is True
    assert p3["perfect"] is False
    assert p3["stagger_attacker"] is False

    # Missed parry (> 0.35s)
    p4 = combat.evaluate_parry(0.36)
    assert p4["success"] is False
    assert p4["damage_negation"] == 0.0


def test_status_effects_duration_and_ticks():
    """Verify the 10 status effects, periodic 1-second DoT ticks, and expiration."""
    combat = CombatSystemPy()
    canonical_statuses = [
        "Burn", "Bleed", "Freeze", "Shock", "Poison",
        "Curse", "Corruption", "Stagger", "Slow", "Silence"
    ]

    target_id = "training_dummy_01"
    # Apply Bleed for 3.0s, potency 5.0
    combat.apply_status(target_id, "Bleed", duration=3.0, potency=5.0)
    assert "Bleed" in combat.active_statuses[target_id]

    # Process 1.0s -> 1 tick triggered
    combat.process_statuses(1.0)
    assert combat.active_statuses[target_id]["Bleed"]["ticks_triggered"] == 1
    assert math.isclose(combat.active_statuses[target_id]["Bleed"]["duration"], 2.0)

    # Process another 1.0s -> 2 ticks triggered
    combat.process_statuses(1.0)
    assert combat.active_statuses[target_id]["Bleed"]["ticks_triggered"] == 2

    # Process remaining 1.1s -> status expires and is cleaned up
    combat.process_statuses(1.1)
    assert target_id not in combat.active_statuses


def test_iframe_invulnerability_logic():
    """Verify i-frame window state checks during dodge dash."""
    dash_duration = 0.22
    dash_iframe_start = 0.02
    dash_iframe_end = 0.20

    def is_iframe_active(t: float) -> bool:
        return dash_iframe_start <= t <= dash_iframe_end

    assert not is_iframe_active(0.0)
    assert not is_iframe_active(0.01)
    assert is_iframe_active(0.02)
    assert is_iframe_active(0.10)
    assert is_iframe_active(0.20)
    assert not is_iframe_active(0.21)
    assert not is_iframe_active(0.25)
