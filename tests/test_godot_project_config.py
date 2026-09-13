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


def test_phase3_progression_files_and_weapons_exist():
    """Verify all 7 weapon classes, UI scenes, and Phase 3 manager scripts exist."""
    required_scripts = [
        "progression/ProgressionManager.gd",
        "progression/SkillTreeManager.gd",
        "progression/SkillNode.gd",
        "weapons/WeaponMasteryManager.gd",
        "inventory/InventoryManager.gd",
        "inventory/CraftingManager.gd",
        "ui/InventoryMenu.gd",
    ]
    for rel_path in required_scripts:
        full_path = os.path.join(GAME_DIR, "scripts", rel_path.replace("/", os.sep))
        assert os.path.isfile(full_path), f"Missing Phase 3 script: {rel_path}"

    weapon_files = [
        "longsword_iron_vow.tres",
        "twin_blades_shadow_fang.tres",
        "great_hammer_earth_shaker.tres",
        "scythe_soul_reaper.tres",
        "bow_moon_whisper.tres",
        "arcane_staff_astral_weaver.tres",
        "void_blade_eclipse_edge.tres",
        "stag_horn_blade.tres",
    ]
    for w in weapon_files:
        path = os.path.join(GAME_DIR, "data", "weapons", w)
        assert os.path.isfile(path), f"Missing weapon preset resource: {w}"
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
            assert 'script_class="WeaponData"' in content

    # Verify InventoryMenu scene
    inv_scene = os.path.join(GAME_DIR, "scenes", "ui", "InventoryMenu.tscn")
    assert os.path.isfile(inv_scene), "Missing InventoryMenu.tscn scene"


def test_phase4_ai_framework_files_exist():
    """Verify all Phase 4 AI framework modular scripts exist."""
    ai_scripts = [
        "ai/PerceptionSystem.gd",
        "ai/State.gd",
        "ai/StateMachine.gd",
        "ai/UtilityAction.gd",
        "ai/UtilityAI.gd",
        "ai/BTNode.gd",
        "ai/BehaviorTree.gd",
        "ai/BossPersonality.gd",
        "ai/CurrentFightMemory.gd",
        "ai/PersistentMemoryProfile.gd",
        "ai/AdaptationBudget.gd",
        "ai/TelegraphSystem.gd",
    ]
    for rel_path in ai_scripts:
        full_path = os.path.join(GAME_DIR, "scripts", rel_path.replace("/", os.sep))
        assert os.path.isfile(full_path), f"Missing Phase 4 AI script: {rel_path}"


def test_phase5_adaptive_intelligence_files_exist():
    """Verify all Phase 5 Adaptive Game Intelligence & Fairness scripts exist."""
    phase5_scripts = [
        "ai/BehavioralFingerprint.gd",
        "ai/FairnessEngine.gd",
        "core/TelemetryDispatcher.gd",
    ]
    for rel_path in phase5_scripts:
        full_path = os.path.join(GAME_DIR, "scripts", rel_path.replace("/", os.sep))
        assert os.path.isfile(full_path), f"Missing Phase 5 script: {rel_path}"


def test_phase6_campaign_expansion_files_exist():
    """Verify all Phase 6 Campaign Expansion Worlds 2-7 scripts, scenes, and resources exist."""
    # World Mechanics & Core Data
    world_mechanics = [
        "world/WaterDepthManager.gd",
        "world/HeatZoneManager.gd",
        "world/BloodRiteManager.gd",
        "world/MachineStateManager.gd",
        "world/RealityShiftManager.gd",
        "world/RuleFailureManager.gd",
        "world/WorldData.gd",
        "artifacts/ArtifactSetData.gd",
    ]
    for rel_path in world_mechanics:
        full_path = os.path.join(GAME_DIR, "scripts", rel_path.replace("/", os.sep))
        assert os.path.isfile(full_path), f"Missing World mechanic script: {rel_path}"

    # Major Bosses
    bosses = [
        "DrownedMatriarch",
        "AshKing",
        "CardinalOfBlood",
        "TheArchitect",
        "TheDreamEater",
        "NullBoss",
    ]
    for boss in bosses:
        script_path = os.path.join(GAME_DIR, "scripts", "bosses", f"{boss}.gd")
        scene_path = os.path.join(GAME_DIR, "scenes", "bosses", f"{boss}.tscn")
        assert os.path.isfile(script_path), f"Missing boss script: {boss}.gd"
        assert os.path.isfile(scene_path), f"Missing boss scene: {boss}.tscn"

    # Campaign Worlds 2-7 Levels
    worlds = [
        "DrownedWoodsWorld",
        "AshenSovereignWorld",
        "CrimsonCathedralWorld",
        "BrokenMachineWorld",
        "ForgottenDreamWorld",
        "NullRealmWorld",
    ]
    for world in worlds:
        script_path = os.path.join(GAME_DIR, "scripts", "levels", f"{world}.gd")
        scene_path = os.path.join(GAME_DIR, "scenes", "levels", f"{world}.tscn")
        assert os.path.isfile(script_path), f"Missing world level script: {world}.gd"
        assert os.path.isfile(scene_path), f"Missing world level scene: {world}.tscn"

    # World Data Resources
    world_tres = [
        "world_1_verdant_march.tres",
        "world_2_drowned_woods.tres",
        "world_3_ashen_sovereign.tres",
        "world_4_crimson_cathedral.tres",
        "world_5_broken_machine.tres",
        "world_6_forgotten_dream.tres",
        "world_7_null_realm.tres",
    ]
    for wt in world_tres:
        path = os.path.join(GAME_DIR, "data", "worlds", wt)
        assert os.path.isfile(path), f"Missing world data resource: {wt}"

    # Artifact Set Resources
    artifact_sets = [
        "set_verdant_guardian.tres",
        "set_drowned_oath.tres",
        "set_ashen_sovereign.tres",
        "set_crimson_rite.tres",
        "set_machinists_core.tres",
        "set_dreamwoven.tres",
        "set_nullborn.tres",
    ]
    for st in artifact_sets:
        path = os.path.join(GAME_DIR, "data", "artifact_sets", st)
        assert os.path.isfile(path), f"Missing artifact set resource: {st}"

    # Boss Attacks
    boss_attacks = [
        "matriarch_tidal_cleave.tres",
        "matriarch_whirlpool.tres",
        "matriarch_abyssal_torrent.tres",
        "matriarch_depth_slam.tres",
        "ash_king_flame_sunder.tres",
        "ash_king_magma_eruption.tres",
        "ash_king_pyroclastic_wave.tres",
        "ash_king_molten_counter.tres",
        "cardinal_blood_spear.tres",
        "cardinal_sanguine_siphon.tres",
        "cardinal_hemorrhage_seal.tres",
        "cardinal_excommunication.tres",
        "architect_cogwheel_crush.tres",
        "architect_circuit_surge.tres",
        "architect_clockwork_laser.tres",
        "architect_drone_protocol.tres",
        "dream_mirage_strike.tres",
        "dream_reality_tear.tres",
        "dream_nightmare_spikes.tres",
        "dream_lucidity_collapse.tres",
        "null_glitch_strike.tres",
        "null_memory_echo.tres",
        "null_void_singularity.tres",
        "null_execution_error.tres",
    ]
    for ba in boss_attacks:
        path = os.path.join(GAME_DIR, "data", "attacks", "boss", ba)
        assert os.path.isfile(path), f"Missing boss attack resource: {ba}"


