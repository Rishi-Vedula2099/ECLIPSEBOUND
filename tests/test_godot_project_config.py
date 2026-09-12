# tests/test_godot_project_config.py
"""Automated verification of Godot 4 project configuration, input map, layers, autoloads, and resources."""
import os
import re
import pytest

GAME_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "game"))
PROJECT_FILE = os.path.join(GAME_DIR, "project.godot")


def test_project_godot_exists():
    assert os.path.isfile(PROJECT_FILE), f"project.godot not found at {PROJECT_FILE}"


def test_project_godot_sections():
    with open(PROJECT_FILE, "r", encoding="utf-8") as f:
        content = f.read()

    # Application section
    assert "[application]" in content
    assert 'config/name="ECLIPSEBOUND"' in content

    # Autoloads
    assert "[autoload]" in content
    assert 'EventBus="*res://scripts/core/EventBus.gd"' in content
    assert 'TelemetryManager="*res://scripts/telemetry/TelemetryManager.gd"' in content
    assert 'CombatSystem="*res://scripts/combat/CombatSystem.gd"' in content
    assert 'SaveManager="*res://scripts/save/SaveManager.gd"' in content

    # Display & Viewport
    assert "[display]" in content
    assert "viewport_width=480" in content
    assert "viewport_height=270" in content
    assert "window_width_override=1920" in content
    assert "window_height_override=1080" in content

    # Physics & 60 FPS
    assert "[physics]" in content
    assert "physics_ticks_per_second=60" in content
    assert "default_gravity=980.0" in content


def test_collision_layers():
    with open(PROJECT_FILE, "r", encoding="utf-8") as f:
        content = f.read()

    expected_layers = [
        ('layer_1="Environment"', "Environment"),
        ('layer_2="Hazards"', "Hazards"),
        ('layer_3="Player"', "Player"),
        ('layer_4="Enemy"', "Enemy"),
        ('layer_5="PlayerHitbox"', "PlayerHitbox"),
        ('layer_6="EnemyHitbox"', "EnemyHitbox"),
        ('layer_7="PlayerHurtbox"', "PlayerHurtbox"),
        ('layer_8="EnemyHurtbox"', "EnemyHurtbox"),
    ]
    for layer_str, name in expected_layers:
        assert layer_str in content, f"Missing physics 2D layer: {name}"


def test_input_map_actions():
    with open(PROJECT_FILE, "r", encoding="utf-8") as f:
        content = f.read()

    required_actions = [
        "move_left",
        "move_right",
        "jump",
        "dash",
        "attack_light",
        "attack_heavy",
        "ability",
        "parry",
        "pause",
    ]
    for action in required_actions:
        assert f"{action}=" in content, f"Missing InputMap action: {action}"


def test_referenced_files_exist_on_disk():
    """Verify all files referenced in project.godot actually exist on disk."""
    with open(PROJECT_FILE, "r", encoding="utf-8") as f:
        content = f.read()

    res_matches = re.findall(r'res://([^\s",\)]+)', content)
    assert len(res_matches) > 0

    for res_path in res_matches:
        if res_path.endswith(".svg"):
            continue  # Optional UI icon
        disk_path = os.path.join(GAME_DIR, res_path.replace("/", os.sep))
        assert os.path.isfile(disk_path), f"Referenced file does not exist on disk: {res_path} ({disk_path})"


def test_attack_data_resources_exist():
    """Verify pre-configured attack data resources exist and have required keys."""
    attacks = [
        "player_light_1.tres",
        "player_light_2.tres",
        "player_heavy_1.tres",
        "player_ability_void_slash.tres",
        "dummy_attack.tres",
    ]
    for attack in attacks:
        path = os.path.join(GAME_DIR, "data", "attacks", attack)
        assert os.path.isfile(path), f"Missing attack resource: {attack}"
        with open(path, "r", encoding="utf-8") as f:
            c = f.read()
            assert 'script_class="AttackData"' in c
            assert "damage =" in c
            assert "stamina_cost =" in c
            assert "startup_time =" in c
