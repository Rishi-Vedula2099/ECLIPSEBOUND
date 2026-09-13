# tests/test_stats.py
import math

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

    def get_max_health(self) -> float:
        return 100.0 + (self.vit * 12.5)

    def get_physical_attack(self) -> float:
        return 15.0 + (self.str_stat * 2.8)

    def get_defense_reduction(self) -> float:
        armor = self.def_stat * 4.0
        return armor / (armor + 100.0)

    def get_xp_required(self) -> float:
        return 100.0 * (self.level ** 1.45)

    def add_xp(self, amount: float) -> bool:
        self.current_xp += amount
        leveled_up = False
        while self.current_xp >= self.get_xp_required() and self.level < 50:
            self.current_xp -= self.get_xp_required()
            self.level += 1
            leveled_up = True
        return leveled_up

def test_max_health():
    stats = PlayerStatsPy(vit=20)
    assert stats.get_max_health() == 350.0

def test_physical_attack():
    stats = PlayerStatsPy(str_stat=15)
    assert stats.get_physical_attack() == 57.0

def test_defense_reduction_scaling():
    stats_low = PlayerStatsPy(def_stat=10)
    stats_high = PlayerStatsPy(def_stat=50)
    assert stats_low.get_defense_reduction() < stats_high.get_defense_reduction()
    assert 0.0 < stats_high.get_defense_reduction() < 1.0

def test_xp_and_leveling():
    stats = PlayerStatsPy(level=1)
    req = stats.get_xp_required()
    assert req == 100.0
    
    leveled = stats.add_xp(150.0)
    assert leveled is True
    assert stats.level == 2
    assert math.isclose(stats.current_xp, 50.0)
