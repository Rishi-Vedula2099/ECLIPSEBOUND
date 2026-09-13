# tests/test_telemetry.py
import pytest
import sys
import os

# Add backend directory to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'backend')))

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health_endpoint():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"

def test_receive_telemetry_batch():
    payload = {
        "events": [
            {
                "event": "player_attack",
                "player_id": "player_test_01",
                "session_id": "session_test_01",
                "timestamp": 1750000000.0,
                "data": {"weapon": "rebellion", "damage": 25.0}
            }
        ]
    }
    response = client.post("/telemetry/events", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert data["status"] == "accepted"
    assert data["events_received"] == 1

def test_get_player_fingerprint():
    response = client.get("/players/player_test_01/fingerprint")
    assert response.status_code == 200
    data = response.json()
    assert data["player_id"] == "player_test_01"
    assert "aggression" in data
    assert 0.0 <= data["aggression"] <= 1.0
