# backend/app/main.py
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Dict
import time

from app.schemas.telemetry import (
    TelemetryBatch,
    PlayerFingerprint,
    TelemetryEvent,
    FairnessAuditRequest,
    FairnessAuditResult,
)
from app.services.fingerprint_service import FingerprintService, CATEGORY_CAPS, TOTAL_BUDGET

app = FastAPI(
    title="ECLIPSEBOUND API & Observability Engine",
    version="0.5.0-phase5",
    description="Adaptive Game Intelligence, Telemetry Ingestion & 100-Point Fairness Engine."
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-memory storage for telemetry & fingerprints
telemetry_store: List[TelemetryEvent] = []
fingerprint_store: Dict[str, PlayerFingerprint] = {}
fingerprint_service = FingerprintService(alpha=0.20)

@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "service": "ECLIPSEBOUND Backend API",
        "version": "0.5.0-phase5",
        "timestamp": time.time()
    }

@app.post("/telemetry/events", status_code=201)
def receive_telemetry_batch(batch: TelemetryBatch):
    for event in batch.events:
        telemetry_store.append(event)
        
        # Ingest into player fingerprint if player_id present
        pid = event.player_id
        if pid not in fingerprint_store:
            fingerprint_store[pid] = PlayerFingerprint(player_id=pid)
        fingerprint_service.update_fingerprint_from_events(fingerprint_store[pid], [event])

    return {
        "status": "accepted",
        "events_received": len(batch.events),
        "total_events_stored": len(telemetry_store)
    }

@app.get("/players/{player_id}/fingerprint", response_model=PlayerFingerprint)
def get_player_fingerprint(player_id: str):
    if player_id not in fingerprint_store:
        fingerprint_store[player_id] = PlayerFingerprint(
            player_id=player_id,
            aggression=0.5,
            exploration=0.5,
            risk=0.5,
            defense=0.5,
            mobility=0.5,
            parry=0.5,
            preferred_weapon="longsword",
            preferred_dodge_direction="RIGHT",
            average_reaction_ms=240.0
        )
    return fingerprint_store[player_id]

@app.post("/players/{player_id}/fairness-audit", response_model=FairnessAuditResult)
def evaluate_fairness_audit(player_id: str, request: FairnessAuditRequest):
    return fingerprint_service.evaluate_fairness_audit(request)

@app.get("/bosses/{boss_id}/fairness-budget")
def get_boss_fairness_budget(boss_id: str):
    return {
        "boss_id": boss_id,
        "total_budget": TOTAL_BUDGET,
        "category_caps": CATEGORY_CAPS,
        "rules": [
            "Minimum 350ms startup reaction window on attack counters",
            "Bounded positioning bias; no instantaneous teleports behind player",
            "Pattern recognition requires signal confidence > 0.75 with 50% decay on failure",
            "Defense adjustments must feature authored stance shift animations; no invisible iframes",
            "Spawn adjustments strictly from approved world encounter pools and rate-limited",
            "Phase adjustments triggered strictly at 75%, 50%, or 25% HP milestones",
        ]
    }
