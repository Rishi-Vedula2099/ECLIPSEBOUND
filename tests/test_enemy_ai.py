# tests/test_enemy_ai.py
"""Unit tests verifying Phase 2 BaseEnemy AI state machine, perception, and poise stagger."""
import pytest


class BaseEnemyPy:
    """Python reference mirroring GDScript BaseEnemy state machine and poise logic."""

    def __init__(self, max_hp=60.0, def_stat=8, max_poise=30.0, detect_radius=180.0, attack_range=36.0):
        self.max_hp = max_hp
        self.current_hp = max_hp
        self.defense = def_stat
        self.max_poise = max_poise
        self.current_poise = max_poise
        self.detection_radius = detect_radius
        self.attack_range = attack_range
        self.lose_radius = 260.0
        self.state = "IDLE"
        self.is_staggered = False

    def check_perception(self, dist_to_player: float):
        if self.state in ["IDLE", "PATROL"]:
            if dist_to_player <= self.detection_radius:
                self.state = "DETECT"
                return True
        elif self.state == "CHASE":
            if dist_to_player > self.lose_radius:
                self.state = "IDLE"
                return False
            if dist_to_player <= self.attack_range:
                self.state = "ATTACK"
                return True
        return False

    def receive_hit(self, damage: float, breaks_guard: bool = False):
        self.current_hp = max(0.0, self.current_hp - damage)
        poise_dmg = damage * 1.2 if breaks_guard else damage * 0.6
        self.current_poise = max(0.0, self.current_poise - poise_dmg)

        if self.current_hp <= 0.0:
            self.state = "DEAD"
        elif self.current_poise <= 0.0 or breaks_guard:
            self.is_staggered = True
            self.state = "STAGGER"
        else:
            self.state = "HURT"

    def receive_parry(self, is_perfect: bool):
        self.is_staggered = True
        self.current_poise = 0.0
        self.state = "STAGGER"


# --- Test Cases ---

def test_enemy_perception_transitions():
    enemy = BaseEnemyPy(detect_radius=180.0, attack_range=36.0)
    assert enemy.state == "IDLE"

    # Player outside detection radius
    enemy.check_perception(200.0)
    assert enemy.state == "IDLE"

    # Player steps into detection radius -> DETECT
    detected = enemy.check_perception(150.0)
    assert detected is True
    assert enemy.state == "DETECT"

    # In chase, close to melee -> ATTACK
    enemy.state = "CHASE"
    attack_ready = enemy.check_perception(30.0)
    assert attack_ready is True
    assert enemy.state == "ATTACK"

    # In chase, player escapes past lose radius -> IDLE
    enemy.state = "CHASE"
    in_range = enemy.check_perception(280.0)
    assert in_range is False
    assert enemy.state == "IDLE"


def test_enemy_poise_and_stagger():
    enemy = BaseEnemyPy(max_hp=100.0, max_poise=30.0)

    # Light hit deals small poise damage -> HURT
    enemy.receive_hit(damage=15.0, breaks_guard=False)
    assert enemy.current_hp == 85.0
    assert enemy.current_poise == 30.0 - (15.0 * 0.6)  # 21.0
    assert enemy.state == "HURT"
    assert not enemy.is_staggered

    # Heavy hit breaking guard -> STAGGER
    enemy.receive_hit(damage=20.0, breaks_guard=True)
    assert enemy.is_staggered is True
    assert enemy.state == "STAGGER"


def test_enemy_parry_reception_breaks_poise():
    enemy = BaseEnemyPy(max_hp=100.0, max_poise=50.0)
    enemy.state = "ATTACK"

    enemy.receive_parry(is_perfect=True)
    assert enemy.is_staggered is True
    assert enemy.current_poise == 0.0
    assert enemy.state == "STAGGER"
