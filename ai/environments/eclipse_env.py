# ai/environments/eclipse_env.py - RL Environment
import numpy as np
from typing import Dict, Any, Tuple

try:
    import gymnasium as gym
    BaseEnv = gym.Env
    has_gym = True
except ImportError:
    import gym # type: ignore
    BaseEnv = gym.Env # type: ignore
    has_gym = True

class EclipseBoundEnv(BaseEnv): # type: ignore
    """
    Gymnasium environment interface for ECLIPSEBOUND combat simulation.
    State Observation Vector (12 features):
    [0]: player_hp_pct (0.0 to 1.0)
    [1]: enemy_hp_pct (0.0 to 1.0)
    [2]: dist_x (-1.0 to 1.0 normalized)
    [3]: dist_y (-1.0 to 1.0 normalized)
    [4]: player_vel_x
    [5]: player_vel_y
    [6]: enemy_vel_x
    [7]: enemy_vel_y
    [8]: player_stamina_pct
    [9]: player_in_dodge_window (0 or 1)
    [10]: enemy_attacking (0 or 1)
    [11]: world_id_normalized (0.1 to 1.0)

    Action Space (6 Discrete Actions):
    0: Idle / Move Left
    1: Move Right
    2: Light Attack
    3: Heavy Attack
    4: Dodge Dash
    5: Parry
    """
    metadata = {"render_modes": ["human"], "render_fps": 60}

    def __init__(self, seed: int = 42):
        if has_gym:
            super().__init__()
            self.observation_space = gym.spaces.Box(
                low=-1.0, high=1.0, shape=(12,), dtype=np.float32
            )
            self.action_space = gym.spaces.Discrete(6)
        else:
            self.observation_space = {"shape": (12,), "dtype": np.float32}
            self.action_space = {"n": 6}
            
        self.seed_val = seed
        self.reset(seed=seed)

    def reset(self, seed: int | None = None, options: Dict[str, Any] | None = None) -> Tuple[np.ndarray, Dict[str, Any]]:
        if has_gym and seed is not None:
            super().reset(seed=seed)
        self.player_hp = 100.0
        self.max_player_hp = 100.0
        self.enemy_hp = 100.0
        self.max_enemy_hp = 100.0
        self.player_pos = np.array([100.0, 150.0], dtype=np.float32)
        self.enemy_pos = np.array([250.0, 150.0], dtype=np.float32)
        self.current_step = 0
        self.max_steps = 1000

        obs = self._get_obs()
        info = {"step": self.current_step, "player_hp": self.player_hp, "enemy_hp": self.enemy_hp}
        return obs, info

    def step(self, action: int) -> Tuple[np.ndarray, float, bool, bool, Dict[str, Any]]:
        self.current_step += 1
        reward = 0.1  # Survival tick reward
        
        dist = np.linalg.norm(self.player_pos - self.enemy_pos)
        
        if action == 1:  # Move Right towards enemy
            self.player_pos[0] += 5.0
        elif action == 0:  # Move Left
            self.player_pos[0] -= 5.0
        elif action == 2 and dist < 40.0:  # Light Attack within range
            damage = 10.0
            self.enemy_hp -= damage
            reward += 1.5
        elif action == 4:  # Dodge
            reward += 0.2

        if dist < 40.0:
            self.player_hp -= 2.0
            reward -= 0.5

        terminated = bool(self.player_hp <= 0 or self.enemy_hp <= 0)
        truncated = bool(self.current_step >= self.max_steps)

        if self.enemy_hp <= 0:
            reward += 10.0
        elif self.player_hp <= 0:
            reward -= 5.0

        obs = self._get_obs()
        info = {"step": self.current_step, "player_hp": self.player_hp, "enemy_hp": self.enemy_hp}
        return obs, float(reward), terminated, truncated, info

    def _get_obs(self) -> np.ndarray:
        dist_vec = (self.enemy_pos - self.player_pos) / 480.0
        return np.array([
            self.player_hp / self.max_player_hp,
            self.enemy_hp / self.max_enemy_hp,
            dist_vec[0],
            dist_vec[1],
            0.0, 0.0, 0.0, 0.0,
            1.0,
            0.0,
            0.0,
            0.14
        ], dtype=np.float32)
