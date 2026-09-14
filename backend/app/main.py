# backend/app/main.py - ECLIPSEBOUND API Server
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

# ============================================================================
# Campaign Expansion (Phase 6) Endpoints
# ============================================================================

CAMPAIGN_WORLDS = [
    {
        "world_id": 1,
        "name": "The Verdant March",
        "visual_identity": "Ancient overgrown ruins, emerald canopy, mossy stone monoliths",
        "core_mechanic": "Living Terrain",
        "set_identity": "Verdant Guardian",
        "major_boss": "The Hollow Stag",
        "adaptive_focus": "Parry timing & spacing punishment",
        "base_xp": 500.0,
        "recommended_level": 1,
    },
    {
        "world_id": 2,
        "name": "The Drowned Woods",
        "visual_identity": "Flooded forest, black water, fog, sunken root pathways",
        "core_mechanic": "Water Depth",
        "set_identity": "Drowned Oath",
        "major_boss": "Drowned Matriarch",
        "adaptive_focus": "Dodge direction & distance preference",
        "base_xp": 750.0,
        "recommended_level": 8,
    },
    {
        "world_id": 3,
        "name": "The Ashen Sovereign",
        "visual_identity": "Volcanic ruins, ash storms, embers, jagged basalt crags",
        "core_mechanic": "Heat Zones",
        "set_identity": "Ashen Sovereign",
        "major_boss": "The Ash King",
        "adaptive_focus": "Punishes repetitive melee pressure",
        "base_xp": 1100.0,
        "recommended_level": 16,
    },
    {
        "world_id": 4,
        "name": "The Crimson Cathedral",
        "visual_identity": "Gothic cathedral, blood rivers, stained glass, arched rib-vaults",
        "core_mechanic": "Blood Rites",
        "set_identity": "Crimson Rite",
        "major_boss": "Cardinal of Blood",
        "adaptive_focus": "Exploits heal timing & greed",
        "base_xp": 1500.0,
        "recommended_level": 24,
    },
    {
        "world_id": 5,
        "name": "The Broken Machine",
        "visual_identity": "Industrial megastructure, clockwork, churning pistons, copper coils",
        "core_mechanic": "Machine State",
        "set_identity": "Machinist's Core",
        "major_boss": "THE ARCHITECT",
        "adaptive_focus": "Deep historical profiling",
        "base_xp": 2000.0,
        "recommended_level": 32,
    },
    {
        "world_id": 6,
        "name": "The Forgotten Dream",
        "visual_identity": "Impossible geometry, floating ruins, kaleidoscopic nebulae, shifting stairs",
        "core_mechanic": "Reality Shift",
        "set_identity": "Dreamwoven",
        "major_boss": "The Dream Eater",
        "adaptive_focus": "Movement timing & ability rhythms",
        "base_xp": 2600.0,
        "recommended_level": 40,
    },
    {
        "world_id": 7,
        "name": "The NULL Realm",
        "visual_identity": "Black void, fractured reality, glitched geometry, total eclipse corona",
        "core_mechanic": "Rule Failure",
        "set_identity": "Nullborn",
        "major_boss": "NULL",
        "adaptive_focus": "Complete campaign memory integration",
        "base_xp": 3500.0,
        "recommended_level": 48,
    },
]

CAMPAIGN_SETS = [
    {
        "set_id": "verdant",
        "set_name": "Verdant Guardian",
        "world_id": 1,
        "bonuses": {
            "2_piece": "+15% Max HP",
            "4_piece": "+25% Healing efficiency & passive regeneration",
            "6_piece": "Parrying a strike triggers a thorny retaliation ring",
            "8_piece": "Revive upon fatal damage with 50% HP once per shrine rest"
        }
    },
    {
        "set_id": "drowned",
        "set_name": "Drowned Oath",
        "world_id": 2,
        "bonuses": {
            "2_piece": "+15% Stamina Regen",
            "4_piece": "Immunity to hazard slow; +20% Dash distance",
            "6_piece": "Dodge emits tidal wave pushing enemies back",
            "8_piece": "Attacks summon abyssal tentacles inflicting water drag"
        }
    },
    {
        "set_id": "ashen",
        "set_name": "Ashen Sovereign",
        "world_id": 3,
        "bonuses": {
            "2_piece": "+15 Armor & +20 Fire/Heat Resistance",
            "4_piece": "+25% Poise; Stagger duration reduced by 40%",
            "6_piece": "Heavy attacks trigger molten magma fissures",
            "8_piece": "Surrounded by an aura of scorching embers burning nearby foes"
        }
    },
    {
        "set_id": "crimson",
        "set_name": "Crimson Rite",
        "world_id": 4,
        "bonuses": {
            "2_piece": "+15% Critical Damage",
            "4_piece": "+10% Lifesteal on critical hits",
            "6_piece": "Consecutive hits apply stacking Bleed up to 5 stacks",
            "8_piece": "Sacrificial frenzy: +35% attack speed when below 40% HP"
        }
    },
    {
        "set_id": "machinist",
        "set_name": "Machinist's Core",
        "world_id": 5,
        "bonuses": {
            "2_piece": "+15% Attack Speed",
            "4_piece": "Cooldowns recover 25% faster",
            "6_piece": "Combo finishers discharge chain lightning",
            "8_piece": "Overclock mode: Abilities consume no resource for 6s after weapon swap"
        }
    },
    {
        "set_id": "dream",
        "set_name": "Dreamwoven",
        "world_id": 6,
        "bonuses": {
            "2_piece": "+20 Arcane Power",
            "4_piece": "+30% i-frame duration on dash",
            "6_piece": "Dodging leaves behind an illusory clone that explodes after 1.5s",
            "8_piece": "Lucid Transcendence: Spells pierce all defenses and phase through obstacles"
        }
    },
    {
        "set_id": "nullborn",
        "set_name": "Nullborn",
        "world_id": 7,
        "bonuses": {
            "2_piece": "+20 to All Core Attributes",
            "4_piece": "+30% Damage dealt, but +15% Damage taken",
            "6_piece": "Attacks distort reality, corrupting enemy hitboxes and reducing defense by 30%",
            "8_piece": "Rule Breaker: Critical strikes reset all cooldowns instantly (5s internal CD)"
        }
    }
]

@app.get("/campaign/worlds")
def get_campaign_worlds():
    return {"count": len(CAMPAIGN_WORLDS), "worlds": CAMPAIGN_WORLDS}

@app.get("/campaign/worlds/{world_id}")
def get_campaign_world(world_id: int):
    for w in CAMPAIGN_WORLDS:
        if w["world_id"] == world_id:
            return w
    raise HTTPException(status_code=404, detail=f"World {world_id} not found")

@app.get("/campaign/sets")
def get_campaign_sets():
    return {"count": len(CAMPAIGN_SETS), "sets": CAMPAIGN_SETS}

@app.get("/campaign/bosses")
def get_campaign_bosses():
    bosses = [
        {
            "world_id": w["world_id"],
            "boss_name": w["major_boss"],
            "adaptive_focus": w["adaptive_focus"],
            "base_xp": w["base_xp"]
        }
        for w in CAMPAIGN_WORLDS
    ]
    return {"count": len(bosses), "bosses": bosses}

