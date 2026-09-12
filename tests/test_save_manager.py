# tests/test_save_manager.py
"""Unit tests verifying ECLIPSEBOUND Phase 1 Save System, versioning, and checksum integrity."""
import hashlib
import json
import os
import tempfile
import pytest


class SaveManagerPy:
    """Python reference implementation mirroring GDScript SaveManager.gd."""

    CURRENT_VERSION = "1.0.0"

    @staticmethod
    def compute_checksum(payload: dict) -> str:
        clean_dict = {k: v for k, v in payload.items() if k != "checksum"}
        json_str = json.dumps(clean_dict, indent=4, sort_keys=True)
        return hashlib.sha256(json_str.encode("utf-8")).hexdigest()

    @classmethod
    def create_save_payload(cls, player_data: dict, world_data: dict) -> dict:
        payload = {
            "version": cls.CURRENT_VERSION,
            "timestamp": 1750000000.0,
            "player": player_data,
            "world": world_data,
        }
        payload["checksum"] = cls.compute_checksum(payload)
        return payload

    @classmethod
    def validate_and_load(cls, raw_json: str) -> dict:
        try:
            data = json.loads(raw_json)
        except json.JSONDecodeError as exc:
            raise ValueError("Invalid JSON format") from exc

        required_fields = ["version", "timestamp", "player", "world", "checksum"]
        for field in required_fields:
            if field not in data:
                raise ValueError(f"Missing required field: {field}")

        stored_checksum = data["checksum"]
        expected_checksum = cls.compute_checksum(data)

        if stored_checksum != expected_checksum:
            raise ValueError("Checksum mismatch: save data corrupted or tampered")

        return data


# --- Test Cases ---

def test_save_payload_creation_and_checksum():
    """Verify versioned payload generation and checksum validation."""
    player_data = {
        "level": 1,
        "xp": 50.0,
        "current_hp": 225.0,
        "max_hp": 225.0,
        "stamina": 100.0,
        "energy": 100.0,
        "position": {"x": 120.0, "y": 210.0},
        "stats": {
            "vit": 10, "str": 10, "arc": 10, "def": 10,
            "agi": 10, "crt": 10, "res": 10, "lck": 10,
        },
        "equipped_weapon": "rebellion",
        "artifacts": [],
    }
    world_data = {
        "world_id": 1,
        "checkpoint_id": "verdant_shrine_01",
        "checkpoint_position": {"x": 80.0, "y": 210.0},
        "unlocked_flags": ["starter_shrine_unlocked"],
        "bosses_defeated": [],
    }

    save = SaveManagerPy.create_save_payload(player_data, world_data)
    assert save["version"] == "1.0.0"
    assert "checksum" in save
    assert len(save["checksum"]) == 64  # SHA-256 hex string

    # Serialization and loading
    raw_json = json.dumps(save, indent=4)
    loaded = SaveManagerPy.validate_and_load(raw_json)
    assert loaded["player"]["level"] == 1
    assert loaded["world"]["checkpoint_id"] == "verdant_shrine_01"
    assert loaded["world"]["checkpoint_position"] == {"x": 80.0, "y": 210.0}


def test_tamper_detection_checksum_mismatch():
    """Verify modifying save data without recalculating checksum raises ValueError."""
    player = {"level": 1, "current_hp": 225.0, "position": {"x": 0.0, "y": 0.0}}
    world = {"world_id": 1, "checkpoint_id": "shrine_01"}
    save = SaveManagerPy.create_save_payload(player, world)

    # Tamper with player HP
    save["player"]["current_hp"] = 99999.0
    tampered_json = json.dumps(save, indent=4)

    with pytest.raises(ValueError, match="Checksum mismatch"):
        SaveManagerPy.validate_and_load(tampered_json)


def test_missing_required_fields_rejection():
    """Verify incomplete save payloads are rejected."""
    incomplete_save = {
        "version": "1.0.0",
        "timestamp": 1750000000.0,
        # Missing player, world, and checksum
    }
    with pytest.raises(ValueError, match="Missing required field"):
        SaveManagerPy.validate_and_load(json.dumps(incomplete_save))


def test_corrupted_json_rejection():
    """Verify non-JSON payload raises ValueError."""
    with pytest.raises(ValueError, match="Invalid JSON format"):
        SaveManagerPy.validate_and_load("{not valid json;")


def test_save_and_backup_cycle(tmp_path):
    """Simulate file save, backup creation, and recovery."""
    save_file = tmp_path / "save_slot_1.json"
    backup_file = tmp_path / "save_slot_1.bak"

    player = {"level": 2, "xp": 10.0, "current_hp": 200.0}
    world = {"world_id": 1, "checkpoint_id": "shrine_02", "checkpoint_position": {"x": 200.0, "y": 210.0}}
    payload = SaveManagerPy.create_save_payload(player, world)

    # Initial save
    save_file.write_text(json.dumps(payload, indent=4), encoding="utf-8")
    assert save_file.exists()

    # Backup prior to overwrite
    backup_file.write_text(save_file.read_text(encoding="utf-8"), encoding="utf-8")
    assert backup_file.exists()

    # Corrupt main save file
    save_file.write_text("corrupted_data", encoding="utf-8")

    # Fallback to backup
    backup_content = backup_file.read_text(encoding="utf-8")
    recovered = SaveManagerPy.validate_and_load(backup_content)
    assert recovered["world"]["checkpoint_id"] == "shrine_02"
    assert recovered["world"]["checkpoint_position"]["x"] == 200.0
