# tests/test_gym_env.py
import sys
import os
import numpy as np

# Add ai directory to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'ai')))

from environments.eclipse_env import EclipseBoundEnv

def test_gym_reset():
    env = EclipseBoundEnv(seed=123)
    obs, info = env.reset(seed=123)
    assert isinstance(obs, np.ndarray)
    assert obs.shape == (12,)
    assert obs[0] == 1.0  # Player full HP
    assert obs[1] == 1.0  # Enemy full HP

def test_gym_step():
    env = EclipseBoundEnv(seed=123)
    obs, info = env.reset(seed=123)
    
    # Action 1: Move Right
    next_obs, reward, terminated, truncated, info = env.step(1)
    assert isinstance(next_obs, np.ndarray)
    assert isinstance(reward, float)
    assert isinstance(terminated, bool)
    assert isinstance(truncated, bool)
