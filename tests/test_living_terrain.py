# tests/test_living_terrain.py
"""Unit tests verifying World 1 Living Terrain dynamic root mechanics and collision states."""
import pytest


class LivingTerrainBarrierPy:
    """Python reference mirroring LivingTerrainManager.gd."""

    def __init__(self, barrier_id="test_gate", is_extended=False):
        self.barrier_id = barrier_id
        self.is_extended = is_extended
        self.growth_ratio = 1.0 if is_extended else 0.0
        self.target_ratio = 1.0 if is_extended else 0.0

    @property
    def is_collision_active(self) -> bool:
        return self.growth_ratio >= 0.5

    def extend_barrier(self):
        self.is_extended = True
        self.target_ratio = 1.0

    def retract_barrier(self):
        self.is_extended = False
        self.target_ratio = 0.0

    def update(self, delta: float):
        if self.growth_ratio != self.target_ratio:
            speed = 2.0
            if self.growth_ratio < self.target_ratio:
                self.growth_ratio = min(self.target_ratio, self.growth_ratio + speed * delta)
            else:
                self.growth_ratio = max(self.target_ratio, self.growth_ratio - speed * delta)


# --- Test Cases ---

def test_barrier_initial_state_retracted():
    barrier = LivingTerrainBarrierPy(is_extended=False)
    assert barrier.growth_ratio == 0.0
    assert not barrier.is_collision_active


def test_barrier_extension_enables_collision():
    barrier = LivingTerrainBarrierPy(is_extended=False)
    barrier.extend_barrier()
    assert barrier.is_extended is True

    # Growth after 0.1s: 0.2 -> collision still disabled
    barrier.update(0.1)
    assert barrier.growth_ratio == 0.2
    assert not barrier.is_collision_active

    import math
    # Growth after another 0.2s: 0.6 -> past 0.5 threshold, collision enabled
    barrier.update(0.2)
    assert math.isclose(barrier.growth_ratio, 0.6)
    assert barrier.is_collision_active is True

    # Fully grown after another 0.3s -> 1.0
    barrier.update(0.3)
    assert barrier.growth_ratio == 1.0
    assert barrier.is_collision_active is True


def test_barrier_retraction_disables_collision():
    barrier = LivingTerrainBarrierPy(is_extended=True)
    assert barrier.is_collision_active is True

    barrier.retract_barrier()
    assert barrier.is_extended is False

    # Retract 0.3s -> growth decreases from 1.0 to 0.4 (< 0.5)
    barrier.update(0.3)
    assert barrier.growth_ratio == 0.4
    assert barrier.is_collision_active is False
