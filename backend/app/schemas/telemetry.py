# backend/app/schemas/telemetry.py
from pydantic import BaseModel, Field
from typing import Dict, Any, List, Optional

class TelemetryEvent(BaseModel):
    event: str = Field(..., json_schema_extra={"example": "combat_attack"})
    player_id: str = Field(..., json_schema_extra={"example": "player_123"})
    session_id: str = Field(..., json_schema_extra={"example": "session_456"})
    timestamp: float = Field(..., json_schema_extra={"example": 1750000000.0})
    data: Dict[str, Any] = Field(default_factory=dict)

class TelemetryBatch(BaseModel):
    events: List[TelemetryEvent]

class OffenseSignals(BaseModel):
    light_heavy_ratio: float = 0.5
    avg_combo_length: float = 2.0
    attack_rate: float = 0.0

class DefenseSignals(BaseModel):
    dodge_rate: float = 0.5
    parry_rate: float = 0.5
    block_rate: float = 0.0
    damage_taken_per_hit: float = 25.0

class PositioningSignals(BaseModel):
    distance_preference: str = "MID"
    retreat_hp_threshold: float = 0.30

class MobilitySignals(BaseModel):
    dash_frequency: float = 0.0
    dodge_direction_bias: str = "RIGHT"
    dodge_confidence: float = 0.5

class AbilitySignals(BaseModel):
    skill_frequency: float = 0.0
    avg_cooldown_latency: float = 1.0
    avg_heal_hp_threshold: float = 0.35

class RiskSignals(BaseModel):
    weapon: str = "longsword"
    artifact_set: str = "verdant_guardian"
    low_hp_aggression: float = 0.5

class PlayerFingerprint(BaseModel):
    player_id: str
    aggression: float = Field(default=0.5, ge=0.0, le=1.0)
    exploration: float = Field(default=0.5, ge=0.0, le=1.0)
    risk: float = Field(default=0.5, ge=0.0, le=1.0)
    defense: float = Field(default=0.5, ge=0.0, le=1.0)
    mobility: float = Field(default=0.5, ge=0.0, le=1.0)
    parry: float = Field(default=0.5, ge=0.0, le=1.0)
    preferred_weapon: str = "longsword"
    preferred_dodge_direction: str = "RIGHT"
    average_reaction_ms: float = 240.0
    
    # 6 Detailed Signal Categories
    offense_signals: OffenseSignals = Field(default_factory=OffenseSignals)
    defense_signals: DefenseSignals = Field(default_factory=DefenseSignals)
    positioning_signals: PositioningSignals = Field(default_factory=PositioningSignals)
    mobility_signals: MobilitySignals = Field(default_factory=MobilitySignals)
    ability_signals: AbilitySignals = Field(default_factory=AbilitySignals)
    risk_signals: RiskSignals = Field(default_factory=RiskSignals)

class FairnessAuditRequest(BaseModel):
    tactic_id: str
    category: str # attack_counter, position_prediction, pattern_recognition, defense_adjustment, spawn_adjustment, phase_adjustment
    point_cost: int
    current_allocated_points: int = 0
    metadata: Dict[str, Any] = Field(default_factory=dict)

class FairnessAuditResult(BaseModel):
    approved: bool
    tactic_id: str
    category: str
    point_cost: int
    new_allocated_points: int
    reason: str
    remaining_budget: int
