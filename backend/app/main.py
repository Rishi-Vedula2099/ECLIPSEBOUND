# backend/app/main.py
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Dict
import time

from app.schemas.telemetry import TelemetryBatch, PlayerFingerprint, TelemetryEvent

app = FastAPI(
    title="ECLIPSEBOUND API & Observability Engine",
    version="0.1.0-phase0",
    description="Telemetry ingestion, player fingerprinting, and RL experimentation backend."
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-memory storage for Phase 0 telemetry & fingerprints
telemetry_store: List[TelemetryEvent] = []
fingerprint_store: Dict[str, PlayerFingerprint] = {}

@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "service": "ECLIPSEBOUND Backend API",
        "timestamp": time.time()
    }

@app.post("/telemetry/events", status_code=201)
def receive_telemetry_batch(batch: TelemetryBatch):
    for event in batch.events:
        telemetry_store.append(event)
    return {
        "status": "accepted",
        "events_received": len(batch.events),
        "total_events_stored": len(telemetry_store)
    }

@app.get("/players/{player_id}/fingerprint", response_model=PlayerFingerprint)
def get_player_fingerprint(player_id: str):
    if player_id not in fingerprint_store:
        # Default baseline profile for new player
        fingerprint_store[player_id] = PlayerFingerprint(
            player_id=player_id,
            aggression=0.5,
            exploration=0.5,
            risk=0.5,
            defense=0.5,
            mobility=0.5,
            parry=0.5,
            preferred_weapon="rebellion",
            preferred_dodge_direction="RIGHT",
            average_reaction_ms=240.0
        )
    return fingerprint_store[player_id]
