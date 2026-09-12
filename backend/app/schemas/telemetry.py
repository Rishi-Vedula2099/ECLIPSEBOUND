# backend/app/schemas/telemetry.py
from pydantic import BaseModel, Field
from typing import Dict, Any, List, Optional

class TelemetryEvent(BaseModel):
    event: str = Field(..., example="combat_attack")
    player_id: str = Field(..., example="player_123")
    session_id: str = Field(..., example="session_456")
    timestamp: float = Field(..., example=1750000000.0)
    data: Dict[str, Any] = Field(default_factory=dict)

class TelemetryBatch(BaseModel):
    events: List[TelemetryEvent]

class PlayerFingerprint(BaseModel):
    player_id: str
    aggression: float = Field(..., ge=0.0, le=1.0)
    exploration: float = Field(..., ge=0.0, le=1.0)
    risk: float = Field(..., ge=0.0, le=1.0)
    defense: float = Field(..., ge=0.0, le=1.0)
    mobility: float = Field(..., ge=0.0, le=1.0)
    parry: float = Field(..., ge=0.0, le=1.0)
    preferred_weapon: str = "twin_blades"
    preferred_dodge_direction: str = "LEFT"
    average_reaction_ms: float = 250.0
