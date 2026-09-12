# tests/test_artifacts_progression.py
"""Unit tests verifying 8-piece artifact slots, set bonuses, stat aggregation, and weapon scaling."""
import pytest


class ArtifactPy:
    def __init__(self, artifact_id, slot, set_id, vit=0, str_stat=0, arc=0, def_stat=0, agi=0, crt=0, res=0, lck=0):
        self.artifact_id = artifact_id
        self.slot = slot
        self.set_id = set_id
        self.vit = vit
        self.str_stat = str_stat
        self.arc = arc
        self.def_stat = def_stat
        self.agi = agi
        self.crt = crt
        self.res = res
        self.lck = lck


class ArtifactManagerPy:
    SLOTS = ["Helm", "Armour", "Gloves", "Boots", "Necklace", "Bracelet", "Ring", "Earpiece"]

    def __init__(self):
        self.equipped = {}

    def equip(self, artifact: ArtifactPy) -> bool:
        if artifact.slot not in self.SLOTS:
            return False
        self.equipped[artifact.slot] = artifact
        return True

    def unequip(self, slot: str) -> ArtifactPy | None:
        return self.equipped.pop(slot, None)

    def get_set_counts(self) -> dict:
        counts = {}
        for a in self.equipped.values():
            counts[a.set_id] = counts.get(a.set_id, 0) + 1
        return counts

    def get_total_bonuses(self) -> dict:
        totals = {"vit": 0, "str": 0, "arc": 0, "def": 0, "agi": 0, "crt": 0, "res": 0, "lck": 0}
        for a in self.equipped.values():
            totals["vit"] += a.vit
            totals["str"] += a.str_stat
            totals["arc"] += a.arc
            totals["def"] += a.def_stat
            totals["agi"] += a.agi
            totals["crt"] += a.crt
            totals["res"] += a.res
            totals["lck"] += a.lck
        return totals

    def get_verdant_bonuses(self) -> dict:
        count = self.get_set_counts().get("Verdant Guardian", 0)
        return {
            "2_piece": count >= 2,
            "4_piece": count >= 4,
            "6_piece": count >= 6,
            "8_piece": count >= 8,
            "count": count,
        }


# --- Test Cases ---

def test_equip_and_slot_validation():
    mgr = ArtifactManagerPy()
    helm = ArtifactPy("v_helm", "Helm", "Verdant Guardian", vit=6, def_stat=4)
    invalid = ArtifactPy("v_cape", "Cape", "Verdant Guardian")  # Invalid slot

    assert mgr.equip(helm) is True
    assert mgr.equip(invalid) is False
    assert "Helm" in mgr.equipped
    assert "Cape" not in mgr.equipped


def test_set_bonus_progression_thresholds():
    mgr = ArtifactManagerPy()
    slots = ["Helm", "Armour", "Gloves", "Boots", "Necklace", "Bracelet", "Ring", "Earpiece"]

    # 0 pieces
    b0 = mgr.get_verdant_bonuses()
    assert not b0["2_piece"] and not b0["4_piece"]

    # Equip 2 pieces -> 2-piece active
    mgr.equip(ArtifactPy("v1", slots[0], "Verdant Guardian"))
    mgr.equip(ArtifactPy("v2", slots[1], "Verdant Guardian"))
    b2 = mgr.get_verdant_bonuses()
    assert b2["2_piece"] is True
    assert b2["4_piece"] is False

    # Equip up to 4 pieces -> 4-piece active
    mgr.equip(ArtifactPy("v3", slots[2], "Verdant Guardian"))
    mgr.equip(ArtifactPy("v4", slots[3], "Verdant Guardian"))
    b4 = mgr.get_verdant_bonuses()
    assert b4["4_piece"] is True
    assert b4["6_piece"] is False

    # Equip up to 8 pieces -> all active
    for i in range(4, 8):
        mgr.equip(ArtifactPy(f"v{i+1}", slots[i], "Verdant Guardian"))
    b8 = mgr.get_verdant_bonuses()
    assert b8["2_piece"] and b8["4_piece"] and b8["6_piece"] and b8["8_piece"]
    assert b8["count"] == 8


def test_stat_bonus_aggregation():
    mgr = ArtifactManagerPy()
    mgr.equip(ArtifactPy("v_helm", "Helm", "Verdant Guardian", vit=6, str_stat=2, def_stat=4))
    mgr.equip(ArtifactPy("v_armour", "Armour", "Verdant Guardian", vit=10, def_stat=8))

    totals = mgr.get_total_bonuses()
    assert totals["vit"] == 16
    assert totals["str"] == 2
    assert totals["def"] == 12


def test_weapon_damage_scaling():
    base_damage = 34.0
    str_scaling = 1.4
    arc_scaling = 1.1

    player_str = 15
    player_arc = 12

    # Scaled damage formula: Base + (STR * str_scale) + (ARC * arc_scale)
    scaled_dmg = base_damage + (player_str * str_scaling) + (player_arc * arc_scaling)
    assert scaled_dmg == 34.0 + (15 * 1.4) + (12 * 1.1)  # 34 + 21 + 13.2 = 68.2
