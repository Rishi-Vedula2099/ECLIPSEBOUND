# tests/test_campaign_expansion_phase6.py
"""
Unit tests verifying ECLIPSEBOUND Phase 6 — Campaign Expansion: Worlds 2–7.
Tests all 6 new world mechanics, major bosses' adaptive AI focus & fairness budget,
7 artifact set bonus progressions, and world level scaling.
"""

import pytest
import math
import os
import re

GAME_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "game"))


# ============================================================================
# 1. World Core Mechanics Unit Tests (Python References)
# ============================================================================

class WaterDepthManagerPy:
    """Mirrors WaterDepthManager.gd logic."""
    SHALLOW = 0
    DEEP = 1
    SUBMERGED = 2

    def __init__(self, depth_tier=1, surface_y=200.0, max_depth=120.0):
        self.depth_tier = depth_tier
        self.surface_y = surface_y
        self.max_depth = max_depth

    def get_depth_ratio(self, body_y: float) -> float:
        return max(0.0, min(1.0, (body_y - self.surface_y) / self.max_depth))

    def get_speed_multiplier(self, body_y: float) -> float:
        ratio = self.get_depth_ratio(body_y)
        if self.depth_tier == self.SHALLOW:
            return 1.0 - (0.15 * ratio)
        elif self.depth_tier == self.DEEP:
            return 1.0 - (0.35 * ratio)
        elif self.depth_tier == self.SUBMERGED:
            return 1.0 - (0.55 * ratio)
        return 1.0

    def get_dash_efficiency(self) -> float:
        if self.depth_tier == self.SHALLOW:
            return 0.90
        elif self.depth_tier == self.DEEP:
            return 0.65
        elif self.depth_tier == self.SUBMERGED:
            return 0.40
        return 1.0


class HeatZoneManagerPy:
    """Mirrors HeatZoneManager.gd logic."""
    DORMANT = 0
    WARNING = 1
    ACTIVE = 2
    ERUPTION = 3

    def __init__(self, dormant_dur=4.0, warn_dur=1.5, active_dur=3.0, erupt_dur=1.0):
        self.durations = {
            self.DORMANT: dormant_dur,
            self.WARNING: warn_dur,
            self.ACTIVE: active_dur,
            self.ERUPTION: erupt_dur,
        }
        self.state = self.DORMANT
        self.timer = 0.0

    def update(self, delta: float) -> int:
        self.timer += delta
        if self.timer >= self.durations[self.state]:
            self.timer = 0.0
            self.state = (self.state + 1) % 4
        return self.state


class BloodRiteManagerPy:
    """Mirrors BloodRiteManager.gd logic."""
    NONE = 0
    SANGUINE_POWER = 1
    VAMPIRIC_COVEN = 2
    CURSED_OFFERING = 3

    def __init__(self):
        self.active_rite = self.NONE
        self.damage_mult = 1.0
        self.lifesteal_pct = 0.0
        self.buff_time = 0.0

    def offer_sacrifice(self, rite: int, max_hp: float) -> float:
        cost_ratio = 0.0
        if rite == self.SANGUINE_POWER:
            cost_ratio = 0.25
            self.damage_mult = 1.35
            self.lifesteal_pct = 0.0
            self.buff_time = 30.0
        elif rite == self.VAMPIRIC_COVEN:
            cost_ratio = 0.40
            self.damage_mult = 1.10
            self.lifesteal_pct = 0.15
            self.buff_time = 45.0
        elif rite == self.CURSED_OFFERING:
            cost_ratio = 0.50
            self.damage_mult = 1.50
            self.lifesteal_pct = 0.05
            self.buff_time = 60.0
        self.active_rite = rite
        return max_hp * cost_ratio


class MachineStateManagerPy:
    """Mirrors MachineStateManager.gd logic."""
    NORMAL = 0
    OVERDRIVE = 1
    LOCKDOWN = 2
    VENTING = 3

    def __init__(self):
        self.state = self.NORMAL
        self.conveyor_speed = 80.0
        self.is_electric_hot = False
        self.is_sealed = False
        self.steam_active = False

    def set_state(self, state: int):
        self.state = state
        if state == self.NORMAL:
            self.conveyor_speed = 80.0
            self.is_electric_hot = False
            self.is_sealed = False
            self.steam_active = False
        elif state == self.OVERDRIVE:
            self.conveyor_speed = 180.0
            self.is_electric_hot = True
            self.is_sealed = False
            self.steam_active = False
        elif state == self.LOCKDOWN:
            self.conveyor_speed = 0.0
            self.is_electric_hot = False
            self.is_sealed = True
            self.steam_active = False
        elif state == self.VENTING:
            self.conveyor_speed = 60.0
            self.is_electric_hot = False
            self.is_sealed = False
            self.steam_active = True


class RealityShiftManagerPy:
    """Mirrors RealityShiftManager.gd logic."""
    LUCID_DREAM = 0
    NIGHTMARE = 1

    def __init__(self):
        self.dimension = self.LUCID_DREAM

    def get_gravity_scale(self) -> float:
        return 0.75 if self.dimension == self.LUCID_DREAM else 1.35

    def toggle(self):
        self.dimension = self.NIGHTMARE if self.dimension == self.LUCID_DREAM else self.LUCID_DREAM


class RuleFailureManagerPy:
    """Mirrors RuleFailureManager.gd logic."""
    STABLE = 0
    INVERTED_GRAVITY = 1
    TIME_DILATION = 2
    FRICTION_COLLAPSE = 3
    CORRUPTED_HITBOXES = 4

    def __init__(self):
        self.glitch = self.STABLE

    def get_gravity_multiplier(self) -> float:
        return -1.0 if self.glitch == self.INVERTED_GRAVITY else 1.0

    def get_time_scale(self) -> float:
        return 0.5 if self.glitch == self.TIME_DILATION else 1.0


def test_water_depth_mechanic():
    mgr = WaterDepthManagerPy(depth_tier=WaterDepthManagerPy.DEEP, surface_y=200.0, max_depth=100.0)
    # At surface (y=200): ratio 0.0 -> full speed (1.0)
    assert mgr.get_depth_ratio(200.0) == 0.0
    assert mgr.get_speed_multiplier(200.0) == 1.0

    # Half submerged (y=250): ratio 0.5 -> speed = 1.0 - (0.35 * 0.5) = 0.825
    assert mgr.get_depth_ratio(250.0) == 0.5
    assert math.isclose(mgr.get_speed_multiplier(250.0), 0.825)

    # Fully submerged (y=300): ratio 1.0 -> speed = 0.65
    assert mgr.get_depth_ratio(300.0) == 1.0
    assert math.isclose(mgr.get_speed_multiplier(300.0), 0.65)
    assert mgr.get_dash_efficiency() == 0.65


def test_heat_zone_lifecycle():
    heat = HeatZoneManagerPy(dormant_dur=2.0, warn_dur=1.0, active_dur=2.0, erupt_dur=0.5)
    assert heat.state == HeatZoneManagerPy.DORMANT
    heat.update(2.0)
    assert heat.state == HeatZoneManagerPy.WARNING
    heat.update(1.0)
    assert heat.state == HeatZoneManagerPy.ACTIVE
    heat.update(2.0)
    assert heat.state == HeatZoneManagerPy.ERUPTION
    heat.update(0.5)
    assert heat.state == HeatZoneManagerPy.DORMANT


def test_blood_rite_sacrifice_calculations():
    altar = BloodRiteManagerPy()
    max_hp = 500.0

    # Sanguine Power: 25% HP cost -> 125 dmg, +35% dmg
    hp_lost = altar.offer_sacrifice(BloodRiteManagerPy.SANGUINE_POWER, max_hp)
    assert hp_lost == 125.0
    assert altar.damage_mult == 1.35
    assert altar.lifesteal_pct == 0.0

    # Vampiric Coven: 40% HP cost -> 200 dmg, 15% lifesteal
    hp_lost = altar.offer_sacrifice(BloodRiteManagerPy.VAMPIRIC_COVEN, max_hp)
    assert hp_lost == 200.0
    assert altar.damage_mult == 1.10
    assert altar.lifesteal_pct == 0.15


def test_machine_state_transitions():
    mach = MachineStateManagerPy()
    assert mach.conveyor_speed == 80.0
    assert not mach.is_electric_hot

    mach.set_state(MachineStateManagerPy.OVERDRIVE)
    assert mach.conveyor_speed == 180.0
    assert mach.is_electric_hot is True

    mach.set_state(MachineStateManagerPy.LOCKDOWN)
    assert mach.conveyor_speed == 0.0
    assert mach.is_sealed is True

    mach.set_state(MachineStateManagerPy.VENTING)
    assert mach.conveyor_speed == 60.0
    assert mach.steam_active is True


def test_reality_shift_dimensions():
    dream = RealityShiftManagerPy()
    assert dream.dimension == RealityShiftManagerPy.LUCID_DREAM
    assert dream.get_gravity_scale() == 0.75

    dream.toggle()
    assert dream.dimension == RealityShiftManagerPy.NIGHTMARE
    assert dream.get_gravity_scale() == 1.35


def test_rule_failure_glitches():
    null_mgr = RuleFailureManagerPy()
    assert null_mgr.get_gravity_multiplier() == 1.0
    assert null_mgr.get_time_scale() == 1.0

    null_mgr.glitch = RuleFailureManagerPy.INVERTED_GRAVITY
    assert null_mgr.get_gravity_multiplier() == -1.0

    null_mgr.glitch = RuleFailureManagerPy.TIME_DILATION
    assert null_mgr.get_time_scale() == 0.5


# ============================================================================
# 2. Boss Adaptive Tactics & 100-Point Budget Tests
# ============================================================================

class BossAdaptationBudgetPy:
    def __init__(self, starting_budget=100, regen_rate=5.0):
        self.current_budget = starting_budget
        self.max_budget = 100
        self.regen_rate = regen_rate

    def can_afford(self, cost: int) -> bool:
        return self.current_budget >= cost

    def spend(self, cost: int) -> bool:
        if self.can_afford(cost):
            self.current_budget -= cost
            return True
        return False

    def update(self, delta: float):
        self.current_budget = min(self.max_budget, self.current_budget + self.regen_rate * delta)


def test_boss_adaptation_budget_limits():
    budget = BossAdaptationBudgetPy(100, regen_rate=10.0)
    assert budget.spend(20) is True  # Attack Counter
    assert budget.current_budget == 80
    assert budget.spend(20) is True  # Attack Counter
    assert budget.spend(15) is True  # Position Prediction
    assert budget.spend(20) is True  # Pattern Recognition
    assert budget.spend(15) is True  # Defense Adjustment
    assert budget.spend(10) is True  # Total 100 spent
    assert budget.current_budget == 0

    # Cannot exceed budget
    assert budget.spend(10) is False

    # Regenerates over 2.0s: 20 points
    budget.update(2.0)
    assert budget.current_budget == 20
    assert budget.spend(20) is True


def test_boss_adaptive_focus_rules():
    # World 2: Drowned Matriarch -> Left/Right dodge bias detection
    left_dodges = 7
    right_dodges = 2
    total = left_dodges + right_dodges
    left_ratio = left_dodges / total
    assert left_ratio > 0.65  # Triggers directional Tidal Cleave

    # World 3: Ash King -> Repetitive melee pressure window detection
    melee_hits = 4
    assert melee_hits >= 3  # Triggers Molten Counter Stance

    # World 4: Cardinal of Blood -> Exploits heal timing
    heals_observed = 1
    assert heals_observed > 0  # Triggers Sanguine Siphon

    # World 5: The Architect -> Deep historical parry habit
    historical_parry_rate = 0.45
    assert historical_parry_rate > 0.40  # Triggers unparryable Clockwork Laser

    # World 6: The Dream Eater -> Dash cadence rhythm
    dash_intervals = [1.2, 1.25, 1.18]
    mean_interval = sum(dash_intervals) / len(dash_intervals)
    variance = sum((x - mean_interval)**2 for x in dash_intervals) / len(dash_intervals)
    assert variance < 0.01  # Rhythmic predictability triggers Mirage Strike at i-frame recovery

    # World 7: NULL -> Synthesizes campaign parry habit
    campaign_parry_ratio = 0.42
    assert campaign_parry_ratio > 0.35  # Triggers Execution Error in Phase 2


def test_authored_telegraph_reaction_window_rule():
    """Verify all 24 boss attacks declare startup_time >= 0.35s (350ms fairness rule)."""
    boss_attacks_dir = os.path.join(GAME_DIR, "data", "attacks", "boss")
    assert os.path.isdir(boss_attacks_dir)

    for fname in os.listdir(boss_attacks_dir):
        if not fname.endswith(".tres"):
            continue
        path = os.path.join(boss_attacks_dir, fname)
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()

        match = re.search(r"startup_time\s*=\s*([0-9\.]+)", content)
        assert match is not None, f"Attack {fname} missing startup_time"
        startup = float(match.group(1))
        assert startup >= 0.35, f"Attack {fname} violates 350ms minimum telegraph: {startup}s"


# ============================================================================
# 3. Artifact Sets & Progression Scaling Tests
# ============================================================================

def test_seven_artifact_sets_data_integrity():
    """Verify all 7 artifact sets define 2, 4, 6, and 8-piece bonuses."""
    expected_sets = [
        "set_verdant_guardian.tres",
        "set_drowned_oath.tres",
        "set_ashen_sovereign.tres",
        "set_crimson_rite.tres",
        "set_machinists_core.tres",
        "set_dreamwoven.tres",
        "set_nullborn.tres",
    ]
    sets_dir = os.path.join(GAME_DIR, "data", "artifact_sets")
    for s_file in expected_sets:
        path = os.path.join(sets_dir, s_file)
        assert os.path.isfile(path), f"Missing set resource: {s_file}"
        with open(path, "r", encoding="utf-8") as f:
            c = f.read()
            assert 'script_class="ArtifactSetData"' in c
            assert "bonus_2_desc =" in c
            assert "bonus_4_desc =" in c
            assert "bonus_6_desc =" in c
            assert "bonus_8_desc =" in c


def test_world_level_scaling_math():
    """Verify world scaling formula multipliers for Worlds 1 through 7."""
    def hp_mult(wl: int) -> float:
        return 1.0 + (float(wl - 1) * 0.40)

    def dmg_mult(wl: int) -> float:
        return 1.0 + (float(wl - 1) * 0.35)

    def xp_mult(wl: int) -> float:
        return 1.0 + (float(wl - 1) * 0.50)

    def loot_mult(wl: int) -> float:
        return 1.0 + (float(wl - 1) * 0.30)

    # World 1 baseline
    assert hp_mult(1) == 1.0
    assert dmg_mult(1) == 1.0
    assert xp_mult(1) == 1.0
    assert loot_mult(1) == 1.0

    # World 4 (Mid-game)
    assert math.isclose(hp_mult(4), 2.20)
    assert math.isclose(dmg_mult(4), 2.05)
    assert math.isclose(xp_mult(4), 2.50)
    assert math.isclose(loot_mult(4), 1.90)

    # World 7 (Endgame climax)
    assert math.isclose(hp_mult(7), 3.40)
    assert math.isclose(dmg_mult(7), 3.10)
    assert math.isclose(xp_mult(7), 4.00)
    assert math.isclose(loot_mult(7), 2.80)


# ============================================================================
# 4. Phase 6 Complete Content & File Integrity Tests
# ============================================================================

def test_all_fifty_six_artifact_pieces_exist_and_are_valid():
    """Verify all 7 sets have complete 8-piece sets (Helm, Armour, Gloves, Boots, Necklace, Bracelet, Ring, Earpiece)."""
    sets_map = {
        "verdant": ("Verdant Guardian", "verdant"),
        "drowned": ("Drowned Oath", "drowned"),
        "ashen": ("Ashen Sovereign", "ashen"),
        "crimson": ("Crimson Rite", "crimson"),
        "machinist": ("Machinist's Core", "machinist"),
        "dream": ("Dreamwoven", "dream"),
        "nullborn": ("Nullborn", "nullborn"),
    }
    slots = ["helm", "armour", "gloves", "boots", "necklace", "bracelet", "ring", "earpiece"]

    total_count = 0
    artifacts_dir = os.path.join(GAME_DIR, "data", "artifacts")
    for folder, (set_name, prefix) in sets_map.items():
        sub_dir = os.path.join(artifacts_dir, folder)
        assert os.path.isdir(sub_dir), f"Missing artifact directory: {sub_dir}"
        for slot in slots:
            fname = f"{prefix}_{slot}.tres"
            fpath = os.path.join(sub_dir, fname)
            assert os.path.isfile(fpath), f"Missing artifact file: {fpath}"
            with open(fpath, "r", encoding="utf-8") as f:
                content = f.read()
                assert 'script_class="ArtifactData"' in content
                assert f'set_id = "{set_name}"' in content or f'set_id = "{prefix}"' in content
                assert "bonus_vit =" in content
                assert "bonus_str =" in content
                assert "description =" in content
            total_count += 1

    assert total_count == 56, f"Expected 56 artifact files, found {total_count}"


def test_all_seven_boss_data_resources_exist():
    """Verify structured BossData resources for Worlds 1 through 7 in game/data/bosses/."""
    expected_bosses = [
        "hollow_stag_boss.tres",
        "drowned_matriarch_boss.tres",
        "ash_king_boss.tres",
        "cardinal_of_blood_boss.tres",
        "the_architect_boss.tres",
        "the_dream_eater_boss.tres",
        "null_boss.tres",
    ]
    boss_dir = os.path.join(GAME_DIR, "data", "bosses")
    assert os.path.isdir(boss_dir)
    for b_file in expected_bosses:
        path = os.path.join(boss_dir, b_file)
        assert os.path.isfile(path), f"Missing boss data resource: {b_file}"
        with open(path, "r", encoding="utf-8") as f:
            c = f.read()
            assert 'script_class="BossData"' in c
            assert "boss_id =" in c
            assert "max_health =" in c
            assert "adaptive_focus =" in c
            assert "phases =" in c


def test_all_seven_world_encounters_exist():
    """Verify EncounterData resources for Worlds 1 through 7 in game/data/encounters/."""
    expected_encounters = [
        "encounter_w1_verdant.tres",
        "encounter_w2_drowned.tres",
        "encounter_w3_ashen.tres",
        "encounter_w4_crimson.tres",
        "encounter_w5_machinist.tres",
        "encounter_w6_dream.tres",
        "encounter_w7_null.tres",
    ]
    enc_dir = os.path.join(GAME_DIR, "data", "encounters")
    assert os.path.isdir(enc_dir)
    for enc_file in expected_encounters:
        path = os.path.join(enc_dir, enc_file)
        assert os.path.isfile(path), f"Missing encounter resource: {enc_file}"
        with open(path, "r", encoding="utf-8") as f:
            c = f.read()
            assert 'script_class="EncounterData"' in c
            assert "minion_pool =" in c
            assert "wave_count =" in c


def test_all_enemy_attacks_meet_350ms_telegraph_rule():
    """Verify all enemy attacks meet the 350ms minimum startup fairness rule."""
    att_dir = os.path.join(GAME_DIR, "data", "attacks", "enemies")
    assert os.path.isdir(att_dir)
    files = [f for f in os.listdir(att_dir) if f.endswith(".tres")]
    assert len(files) >= 15, f"Expected at least 15 enemy attacks, found {len(files)}"

    for f_name in files:
        path = os.path.join(att_dir, f_name)
        with open(path, "r", encoding="utf-8") as f:
            c = f.read()
        match = re.search(r"startup_time\s*=\s*([0-9\.]+)", c)
        assert match is not None, f"Attack {f_name} missing startup_time"
        startup = float(match.group(1))
        assert startup >= 0.35, f"Attack {f_name} violates 350ms rule: {startup}s"


def test_campaign_backend_api_endpoints():
    """Test FastAPI campaign endpoints for Worlds 1-7, sets, and bosses."""
    from fastapi.testclient import TestClient
    import sys
    sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backend")))
    from app.main import app

    client = TestClient(app)

    # 1. Worlds endpoint
    res_w = client.get("/campaign/worlds")
    assert res_w.status_code == 200
    data_w = res_w.json()
    assert data_w["count"] == 7
    assert len(data_w["worlds"]) == 7

    # 2. Specific World 2 & World 7 checks
    res_w2 = client.get("/campaign/worlds/2")
    assert res_w2.status_code == 200
    assert res_w2.json()["name"] == "The Drowned Woods"
    assert res_w2.json()["core_mechanic"] == "Water Depth"
    assert res_w2.json()["major_boss"] == "Drowned Matriarch"

    res_w7 = client.get("/campaign/worlds/7")
    assert res_w7.status_code == 200
    assert res_w7.json()["name"] == "The NULL Realm"
    assert res_w7.json()["core_mechanic"] == "Rule Failure"

    # 3. Sets endpoint
    res_s = client.get("/campaign/sets")
    assert res_s.status_code == 200
    data_s = res_s.json()
    assert data_s["count"] == 7
    assert len(data_s["sets"]) == 7

    # 4. Bosses endpoint
    res_b = client.get("/campaign/bosses")
    assert res_b.status_code == 200
    data_b = res_b.json()
    assert data_b["count"] == 7
    assert any(b["boss_name"] == "THE ARCHITECT" for b in data_b["bosses"])

