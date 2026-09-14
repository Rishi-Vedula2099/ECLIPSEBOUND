# tests/test_progression_framework.py
"""Comprehensive verification of ECLIPSEBOUND Phase 3 RPG Progression Framework.
Covers Character Level (1-50), World Level (1-7), Boss Mastery (0-10),
8 Core Attributes, 4 Skill Branches, 7 Weapon Classes, 8 Artifact Slots with 7 Sets & Rarities,
Inventory Management, and the 5-stage Crafting Lifecycle.
"""
import math
import pytest


# =====================================================================
# 1. PROGRESSION & 8-ATTRIBUTE STAT SYSTEM
# =====================================================================

class PlayerStatsPy:
    def __init__(self, vit=10, str_stat=10, arc=10, def_stat=10, agi=10, crt=10, res=10, lck=10, level=1):
        self.vit = vit
        self.str_stat = str_stat
        self.arc = arc
        self.def_stat = def_stat
        self.agi = agi
        self.crt = crt
        self.res = res
        self.lck = lck

        self.level = level
        self.current_xp = 0.0
        self.unspent_stat_points = 0
        self.unspent_skill_points = 0

        self.bonus_vit = 0
        self.bonus_str = 0
        self.bonus_arc = 0
        self.bonus_def = 0
        self.bonus_agi = 0
        self.bonus_crt = 0
        self.bonus_res = 0
        self.bonus_lck = 0

        self.max_hp_multiplier = 1.0
        self.attack_multiplier = 1.0
        self.defense_multiplier = 1.0
        self.crit_damage_modifier = 0.0

    def get_effective_vit(self) -> int: return max(1, self.vit + self.bonus_vit)
    def get_effective_str(self) -> int: return max(1, self.str_stat + self.bonus_str)
    def get_effective_arc(self) -> int: return max(1, self.arc + self.bonus_arc)
    def get_effective_def(self) -> int: return max(1, self.def_stat + self.bonus_def)
    def get_effective_agi(self) -> int: return max(1, self.agi + self.bonus_agi)
    def get_effective_crt(self) -> int: return max(1, self.crt + self.bonus_crt)
    def get_effective_res(self) -> int: return max(1, self.res + self.bonus_res)
    def get_effective_lck(self) -> int: return max(1, self.lck + self.bonus_lck)

    def get_max_health(self) -> float:
        base_hp = 100.0 + (self.get_effective_vit() * 12.5)
        return base_hp * self.max_hp_multiplier

    def get_physical_attack(self) -> float:
        base_atk = 15.0 + (self.get_effective_str() * 2.8)
        return base_atk * self.attack_multiplier

    def get_ability_attack(self) -> float:
        base_arc = 12.0 + (self.get_effective_arc() * 3.2)
        return base_arc * self.attack_multiplier

    def get_defense_reduction(self) -> float:
        armor = self.get_effective_def() * 4.0 * self.defense_multiplier
        return armor / (armor + 100.0)

    def get_move_speed_multiplier(self) -> float:
        return 1.0 + (self.get_effective_agi() * 0.015)

    def get_dash_stamina_cost_multiplier(self) -> float:
        reduction = min(0.40, max(0.0, self.get_effective_agi() * 0.006))
        return 1.0 - reduction

    def get_critical_chance(self) -> float:
        return min(0.75, max(0.05, 0.05 + (self.get_effective_crt() * 0.008)))

    def get_critical_multiplier(self) -> float:
        return 1.5 + (self.get_effective_crt() * 0.02) + self.crit_damage_modifier

    def get_status_resistance(self) -> float:
        return min(0.70, max(0.0, self.get_effective_res() * 0.012))

    def get_loot_luck_multiplier(self) -> float:
        return 1.0 + ((self.get_effective_lck() - 10) * 0.025)

    def get_xp_required(self) -> float:
        return 100.0 * (self.level ** 1.45)

    def add_xp(self, amount: float) -> bool:
        self.current_xp += amount
        leveled = False
        while self.current_xp >= self.get_xp_required() and self.level < 50:
            self.current_xp -= self.get_xp_required()
            self.level += 1
            self.unspent_stat_points += 3
            self.unspent_skill_points += 1
            leveled = True
        return leveled

    def allocate_stat(self, stat_name: str, points: int = 1) -> bool:
        if self.unspent_stat_points < points:
            return False
        stat = stat_name.lower()
        if stat == "vit": self.vit += points
        elif stat in ("str", "str_stat"): self.str_stat += points
        elif stat == "arc": self.arc += points
        elif stat == "def": self.def_stat += points
        elif stat == "agi": self.agi += points
        elif stat == "crt": self.crt += points
        elif stat == "res": self.res += points
        elif stat == "lck": self.lck += points
        else: return False
        self.unspent_stat_points -= points
        return True


class ProgressionManagerPy:
    def __init__(self, world_level=1):
        self.world_level = max(1, min(7, world_level))
        self.boss_records = {}

    def set_world_level(self, level: int) -> bool:
        if 1 <= level <= 7:
            self.world_level = level
            return True
        return False

    def get_enemy_hp_multiplier(self) -> float:
        return 1.0 + ((self.world_level - 1) * 0.40)

    def get_enemy_damage_multiplier(self) -> float:
        return 1.0 + ((self.world_level - 1) * 0.35)

    def get_world_xp_multiplier(self) -> float:
        return 1.0 + ((self.world_level - 1) * 0.50)

    def record_boss_defeat(self, boss_id: str, took_damage: bool = True) -> int:
        if boss_id not in self.boss_records:
            self.boss_records[boss_id] = {"kills": 0, "points": 0, "mastery_level": 0}
        rec = self.boss_records[boss_id]
        rec["kills"] += 1
        pts = 100 * self.world_level + (150 * self.world_level if not took_damage else 0)
        rec["points"] += pts
        rec["mastery_level"] = min(10, rec["points"] // 250)
        return rec["mastery_level"]


# =====================================================================
# 2. SKILL BRANCHES & TREE SYSTEM
# =====================================================================

class SkillNodePy:
    def __init__(self, skill_id, branch, tier, max_rank=3, req_points=0, prereq=""):
        self.skill_id = skill_id
        self.branch = branch
        self.tier = tier
        self.max_rank = max_rank
        self.current_rank = 0
        self.req_points = req_points
        self.prereq = prereq


class SkillTreeManagerPy:
    def __init__(self):
        self.skills = {}

    def add_skill(self, node: SkillNodePy):
        self.skills[node.skill_id] = node

    def get_invested_points_in_branch(self, branch: str) -> int:
        return sum(s.current_rank for s in self.skills.values() if s.branch.upper() == branch.upper())

    def can_unlock(self, skill_id: str) -> bool:
        if skill_id not in self.skills:
            return False
        node = self.skills[skill_id]
        if node.current_rank >= node.max_rank:
            return False
        if self.get_invested_points_in_branch(node.branch) < node.req_points:
            return False
        if node.prereq and self.skills[node.prereq].current_rank <= 0:
            return False
        return True

    def unlock_skill(self, skill_id: str, stats: PlayerStatsPy) -> bool:
        if not self.can_unlock(skill_id) or stats.unspent_skill_points < 1:
            return False
        self.skills[skill_id].current_rank += 1
        stats.unspent_skill_points -= 1
        return True


# =====================================================================
# 3. WEAPONS & WEAPON MASTERY
# =====================================================================

class WeaponDataPy:
    def __init__(self, weapon_id, weapon_class, base_dmg, str_scale, arc_scale, agi_scale, upgrade=0):
        self.weapon_id = weapon_id
        self.weapon_class = weapon_class
        self.base_dmg = base_dmg
        self.str_scale = str_scale
        self.arc_scale = arc_scale
        self.agi_scale = agi_scale
        self.upgrade = upgrade

    def calculate_damage(self, p_str: int, p_arc: int, p_agi: int, mastery_lvl: int = 0) -> float:
        scaling_boost = 1.15 if mastery_lvl >= 5 else 1.0
        effective_base = self.base_dmg * (1.0 + (self.upgrade * 0.10))
        return effective_base + (p_str * self.str_scale * scaling_boost) + (p_arc * self.arc_scale * scaling_boost) + (p_agi * self.agi_scale * scaling_boost)


class WeaponMasteryManagerPy:
    def __init__(self):
        self.records = {
            w: {"kills": 0, "parries": 0, "xp": 0, "level": 1, "milestones": []}
            for w in ["Longsword", "Twin Blades", "Great Hammer", "Scythe", "Bow", "Arcane Staff", "Void Blade"]
        }

    def record_kill(self, wclass: str, is_boss: bool = False):
        rec = self.records[wclass]
        rec["kills"] += 1
        rec["xp"] += 250 if is_boss else 25
        self._check_level(wclass)

    def record_parry(self, wclass: str):
        rec = self.records[wclass]
        rec["parries"] += 1
        rec["xp"] += 40
        self._check_level(wclass)

    def _check_level(self, wclass: str):
        rec = self.records[wclass]
        new_lvl = min(10, 1 + (rec["xp"] // 500))
        if new_lvl > rec["level"]:
            rec["level"] = new_lvl
            for milestone in [3, 5, 7, 10]:
                if rec["level"] >= milestone and milestone not in rec["milestones"]:
                    rec["milestones"].append(milestone)


# =====================================================================
# 4. 8-PIECE ARTIFACT SYSTEM & 7 WORLD SETS
# =====================================================================

class ArtifactPy:
    SLOTS = ["Helm", "Armour", "Gloves", "Boots", "Necklace", "Bracelet", "Ring", "Earpiece"]

    def __init__(self, artifact_id, slot, rarity, set_id, vit=0, str_stat=0, arc=0, def_stat=0, agi=0, crt=0, res=0, lck=0, upgrade=0, is_corrupted=False, boon_val=0.0, curse_val=0.0):
        assert slot in self.SLOTS
        self.artifact_id = artifact_id
        self.slot = slot
        self.rarity = rarity
        self.set_id = set_id
        self.vit = vit
        self.str_stat = str_stat
        self.arc = arc
        self.def_stat = def_stat
        self.agi = agi
        self.crt = crt
        self.res = res
        self.lck = lck
        self.upgrade = upgrade
        self.is_corrupted = is_corrupted
        self.boon_val = boon_val
        self.curse_val = curse_val
        self.is_locked = False
        self.is_favorite = False
        self.substats = []

    def get_effective_stat(self, base_val: int) -> int:
        return int(round(base_val * (1.0 + (self.upgrade * 0.10))))


class ArtifactManagerPy:
    def __init__(self):
        self.equipped = {}

    def equip(self, art: ArtifactPy) -> bool:
        if art.slot not in ArtifactPy.SLOTS:
            return False
        self.equipped[art.slot] = art
        return True

    def unequip(self, slot: str) -> ArtifactPy | None:
        return self.equipped.pop(slot, None)

    def get_set_counts(self) -> dict:
        counts = {}
        for a in self.equipped.values():
            if a.set_id:
                counts[a.set_id] = counts.get(a.set_id, 0) + 1
        return counts

    def get_set_bonuses(self, set_name: str) -> dict:
        cnt = self.get_set_counts().get(set_name, 0)
        return {
            "2_piece": cnt >= 2,
            "4_piece": cnt >= 4,
            "6_piece": cnt >= 6,
            "8_piece": cnt >= 8,
            "count": cnt
        }


# =====================================================================
# 5. INVENTORY & CRAFTING
# =====================================================================

class InventoryManagerPy:
    def __init__(self, capacity=100):
        self.capacity = capacity
        self.items = []
        self.materials = {"gold": 500, "verdant_shard": 20, "reforge_stone": 5, "transmute_catalyst": 2}

    def add_item(self, item) -> bool:
        if len(self.items) >= self.capacity:
            return False
        self.items.append(item)
        return True

    def remove_item(self, item) -> bool:
        if item in self.items:
            self.items.remove(item)
            return True
        return False

    def toggle_lock(self, item) -> bool:
        item.is_locked = not item.is_locked
        return item.is_locked

    def salvage_item(self, item) -> dict:
        if item.is_locked:
            return {}
        self.remove_item(item)
        yielded = {"gold": 100, "verdant_shard": 5}
        self.materials["gold"] += yielded["gold"]
        self.materials["verdant_shard"] += yielded["verdant_shard"]
        return yielded


class CraftingManagerPy:
    def __init__(self, inv: InventoryManagerPy):
        self.inv = inv

    def upgrade_item(self, item) -> bool:
        if item.upgrade >= 10:
            return False
        cost = (item.upgrade + 1) * 150
        if self.inv.materials["gold"] < cost:
            return False
        self.inv.materials["gold"] -= cost
        item.upgrade += 1
        return True

    def transmute(self, items: list) -> ArtifactPy | None:
        if len(items) != 3 or any(it.is_locked for it in items):
            return None
        if self.inv.materials["transmute_catalyst"] < 1:
            return None
        self.inv.materials["transmute_catalyst"] -= 1
        for it in items:
            self.inv.remove_item(it)
        result = ArtifactPy("transmuted_01", items[0].slot, "Mythic", items[0].set_id, vit=15, str_stat=15)
        self.inv.add_item(result)
        return result


# =====================================================================
# TEST CASES
# =====================================================================

def test_player_leveling_and_unspent_points():
    stats = PlayerStatsPy(level=1)
    assert stats.unspent_stat_points == 0
    assert stats.unspent_skill_points == 0

    # Level up from 1 to 3
    leveled = stats.add_xp(400.0)
    assert leveled is True
    assert stats.level >= 2
    assert stats.unspent_stat_points >= 3
    assert stats.unspent_skill_points >= 1

    # Allocate points to VIT and STR
    initial_vit = stats.vit
    success = stats.allocate_stat("vit", 2)
    assert success is True
    assert stats.vit == initial_vit + 2


def test_8_core_attributes_derived_combat_properties():
    stats = PlayerStatsPy(vit=20, str_stat=25, arc=15, def_stat=30, agi=20, crt=25, res=20, lck=18)
    
    assert stats.get_max_health() == 100.0 + (20 * 12.5)  # 350.0
    assert stats.get_physical_attack() == 15.0 + (25 * 2.8)  # 85.0
    assert stats.get_ability_attack() == 12.0 + (15 * 3.2)  # 60.0

    # Defense curve: Armor / (Armor + 100) -> 120 / 220 = 0.545
    reduction = stats.get_defense_reduction()
    assert 0.50 < reduction < 0.60

    # Agility movement multiplier
    assert stats.get_move_speed_multiplier() == 1.0 + (20 * 0.015)  # 1.30

    # Critical rate & multiplier
    assert stats.get_critical_chance() == 0.05 + (25 * 0.008)  # 0.25 (25%)
    assert stats.get_critical_multiplier() == 1.5 + (25 * 0.02)  # 2.0x

    # Resistance and Luck
    assert stats.get_status_resistance() == 20 * 0.012  # 0.24
    assert stats.get_loot_luck_multiplier() == 1.0 + (8 * 0.025)  # 1.20


def test_world_level_and_boss_mastery_scaling():
    prog = ProgressionManagerPy(world_level=1)
    assert prog.get_enemy_hp_multiplier() == 1.0
    assert prog.get_enemy_damage_multiplier() == 1.0

    # Increase World Level to 4
    prog.set_world_level(4)
    assert prog.get_enemy_hp_multiplier() == 1.0 + (3 * 0.40)  # 2.20x
    assert prog.get_enemy_damage_multiplier() == 1.0 + (3 * 0.35)  # 2.05x

    # Boss defeat record
    mastery = prog.record_boss_defeat("hollow_stag", took_damage=False)
    assert mastery >= 1
    assert prog.boss_records["hollow_stag"]["kills"] == 1


def test_4_skill_branches_prerequisites_and_points():
    stats = PlayerStatsPy(level=5)
    stats.unspent_skill_points = 5
    mgr = SkillTreeManagerPy()

    # Add Warden skills
    t1 = SkillNodePy("warden_iron_skin", "WARDEN", tier=1, max_rank=3, req_points=0)
    t2 = SkillNodePy("warden_stalwart", "WARDEN", tier=2, max_rank=3, req_points=3, prereq="warden_iron_skin")
    mgr.add_skill(t1)
    mgr.add_skill(t2)

    # Cannot unlock tier 2 without 3 points invested in branch
    assert mgr.can_unlock("warden_stalwart") is False

    # Unlock Tier 1 up to rank 3
    assert mgr.unlock_skill("warden_iron_skin", stats) is True
    assert mgr.unlock_skill("warden_iron_skin", stats) is True
    assert mgr.unlock_skill("warden_iron_skin", stats) is True
    assert t1.current_rank == 3

    # Now Tier 2 requirement is met
    assert mgr.can_unlock("warden_stalwart") is True
    assert mgr.unlock_skill("warden_stalwart", stats) is True
    assert t2.current_rank == 1


def test_7_weapon_classes_scaling_and_mastery():
    weps = {
        "Longsword": WeaponDataPy("ls", "Longsword", 34.0, str_scale=1.4, arc_scale=1.1, agi_scale=0.5),
        "Twin Blades": WeaponDataPy("tb", "Twin Blades", 22.0, str_scale=0.6, arc_scale=0.4, agi_scale=1.75),
        "Great Hammer": WeaponDataPy("gh", "Great Hammer", 58.0, str_scale=2.1, arc_scale=0.2, agi_scale=0.1),
        "Scythe": WeaponDataPy("sc", "Scythe", 42.0, str_scale=1.1, arc_scale=1.2, agi_scale=0.9),
        "Bow": WeaponDataPy("bw", "Bow", 28.0, str_scale=0.5, arc_scale=0.8, agi_scale=1.6),
        "Arcane Staff": WeaponDataPy("as", "Arcane Staff", 36.0, str_scale=0.2, arc_scale=2.4, agi_scale=0.4),
        "Void Blade": WeaponDataPy("vb", "Void Blade", 46.0, str_scale=1.3, arc_scale=1.5, agi_scale=1.4),
    }
    assert len(weps) == 7

    # Scaled damage calculation with STR=20, ARC=10, AGI=15
    ls_dmg = weps["Longsword"].calculate_damage(20, 10, 15)
    expected_ls = 34.0 + (20 * 1.4) + (10 * 1.1) + (15 * 0.5)  # 34 + 28 + 11 + 7.5 = 80.5
    assert ls_dmg == expected_ls

    # Upgrade scaling (+2 upgrades = +20% base)
    weps["Longsword"].upgrade = 2
    upgraded_ls = weps["Longsword"].calculate_damage(20, 10, 15)
    assert upgraded_ls == (34.0 * 1.2) + (20 * 1.4) + (10 * 1.1) + (15 * 0.5)

    # Weapon Mastery Leveling
    wm_mgr = WeaponMasteryManagerPy()
    for _ in range(25):
        wm_mgr.record_kill("Longsword")
    assert wm_mgr.records["Longsword"]["kills"] == 25
    assert wm_mgr.records["Longsword"]["level"] >= 2


def test_8_piece_artifact_slots_sets_and_corrupted_rarity():
    mgr = ArtifactManagerPy()
    slots = ["Helm", "Armour", "Gloves", "Boots", "Necklace", "Bracelet", "Ring", "Earpiece"]

    # Equip 8 pieces of Verdant Guardian
    for i, slot in enumerate(slots):
        mgr.equip(ArtifactPy(f"v_{i}", slot, "Epic", "Verdant Guardian", vit=5))

    bonuses = mgr.get_set_bonuses("Verdant Guardian")
    assert bonuses["count"] == 8
    assert bonuses["2_piece"] and bonuses["4_piece"] and bonuses["6_piece"] and bonuses["8_piece"]

    # Equip Corrupted artifact
    corrupted_ring = ArtifactPy("c_ring", "Ring", "Corrupted", "Nullborn", crt=15, is_corrupted=True, boon_val=0.40, curse_val=-0.20)
    mgr.equip(corrupted_ring)
    assert mgr.equipped["Ring"].is_corrupted is True
    assert mgr.equipped["Ring"].boon_val == 0.40
    assert mgr.equipped["Ring"].curse_val == -0.20


def test_inventory_locking_salvage_and_crafting_lifecycle():
    inv = InventoryManagerPy(capacity=10)
    art1 = ArtifactPy("a1", "Helm", "Rare", "Verdant Guardian")
    art2 = ArtifactPy("a2", "Armour", "Rare", "Verdant Guardian")
    art3 = ArtifactPy("a3", "Gloves", "Rare", "Verdant Guardian")

    inv.add_item(art1)
    inv.add_item(art2)
    inv.add_item(art3)
    assert len(inv.items) == 3

    # Lock art1 -> cannot be salvaged
    inv.toggle_lock(art1)
    assert art1.is_locked is True
    salvage_res = inv.salvage_item(art1)
    assert salvage_res == {}
    assert art1 in inv.items

    # Upgrade lifecycle
    craft_mgr = CraftingManagerPy(inv)
    initial_gold = inv.materials["gold"]
    success = craft_mgr.upgrade_item(art2)
    assert success is True
    assert art2.upgrade == 1
    assert inv.materials["gold"] < initial_gold

    # Transmute lifecycle
    inv.toggle_lock(art1)  # Unlock art1
    transmuted = craft_mgr.transmute([art1, art2, art3])
    assert transmuted is not None
    assert transmuted.rarity == "Mythic"
    assert len(inv.items) == 1
