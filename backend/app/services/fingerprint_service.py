# backend/app/services/fingerprint_service.py
from typing import Dict, Any, List
import math
from app.schemas.telemetry import (
    PlayerFingerprint,
    TelemetryEvent,
    FairnessAuditRequest,
    FairnessAuditResult,
    OffenseSignals,
    DefenseSignals,
    PositioningSignals,
    MobilitySignals,
    AbilitySignals,
    RiskSignals,
)

TOTAL_BUDGET = 100
MIN_TELEGRAPH_MS = 350
MIN_PATTERN_CONFIDENCE = 0.75

CATEGORY_CAPS = {
    "attack_counter": 20,
    "position_prediction": 15,
    "pattern_recognition": 20,
    "defense_adjustment": 15,
    "spawn_adjustment": 10,
    "phase_adjustment": 20,
}

APPROVED_SPAWN_POOLS = {
    1: ["BrambleBeast", "MossGnat", "VerdantSlime"],
    2: ["DrownedMatriarchMinion", "BogCreeper"],
}

class FingerprintService:
    def __init__(self, alpha: float = 0.20):
        self.alpha = alpha

    def update_fingerprint_from_events(self, profile: PlayerFingerprint, events: List[TelemetryEvent]) -> PlayerFingerprint:
        for ev in events:
            ev_type = ev.event
            data = ev.data or {}

            if ev_type == "player_attack":
                is_heavy = data.get("type", "light") == "heavy"
                instant_ratio = 0.0 if is_heavy else 1.0
                profile.offense_signals.light_heavy_ratio = (
                    self.alpha * instant_ratio + (1.0 - self.alpha) * profile.offense_signals.light_heavy_ratio
                )
                profile.aggression = (
                    self.alpha * 0.8 + (1.0 - self.alpha) * profile.aggression
                )

            elif ev_type == "player_dodge":
                direction = data.get("direction", "RIGHT").upper()
                profile.mobility_signals.dodge_direction_bias = direction
                profile.preferred_dodge_direction = direction
                profile.mobility = (
                    self.alpha * 0.85 + (1.0 - self.alpha) * profile.mobility
                )
                # Increment confidence
                profile.mobility_signals.dodge_confidence = min(
                    0.95, profile.mobility_signals.dodge_confidence + 0.05
                )

            elif ev_type == "hit_resolved":
                outcome = data.get("outcome", "hit_taken")
                dmg = float(data.get("damage", 0.0))
                if outcome == "parry":
                    profile.defense_signals.parry_rate = (
                        self.alpha * 1.0 + (1.0 - self.alpha) * profile.defense_signals.parry_rate
                    )
                    profile.parry = profile.defense_signals.parry_rate
                elif outcome == "hit_taken":
                    profile.defense_signals.damage_taken_per_hit = (
                        self.alpha * dmg + (1.0 - self.alpha) * profile.defense_signals.damage_taken_per_hit
                    )
                    profile.defense = max(0.1, profile.defense - 0.02)

        return profile

    def evaluate_fairness_audit(self, req: FairnessAuditRequest) -> FairnessAuditResult:
        category = req.category
        cost = req.point_cost
        curr_alloc = req.current_allocated_points

        # 1. Category existence
        if category not in CATEGORY_CAPS:
            return FairnessAuditResult(
                approved=False,
                tactic_id=req.tactic_id,
                category=category,
                point_cost=cost,
                new_allocated_points=curr_alloc,
                reason=f"Unknown category: {category}",
                remaining_budget=TOTAL_BUDGET - curr_alloc,
            )

        # 2. Category cap
        cat_max = CATEGORY_CAPS[category]
        if cost > cat_max:
            return FairnessAuditResult(
                approved=False,
                tactic_id=req.tactic_id,
                category=category,
                point_cost=cost,
                new_allocated_points=curr_alloc,
                reason=f"Cost {cost} exceeds category cap of {cat_max} for {category}",
                remaining_budget=TOTAL_BUDGET - curr_alloc,
            )

        # 3. Overall 100-point ceiling
        if (curr_alloc + cost) > TOTAL_BUDGET:
            return FairnessAuditResult(
                approved=False,
                tactic_id=req.tactic_id,
                category=category,
                point_cost=cost,
                new_allocated_points=curr_alloc,
                reason=f"Fairness budget exhausted ({curr_alloc} + {cost} > {TOTAL_BUDGET})",
                remaining_budget=TOTAL_BUDGET - curr_alloc,
            )

        # 4. Strict category constraints
        meta = req.metadata
        if category == "attack_counter":
            telegraph_ms = meta.get("telegraph_ms", 0)
            if telegraph_ms < MIN_TELEGRAPH_MS:
                return FairnessAuditResult(
                    approved=False,
                    tactic_id=req.tactic_id,
                    category=category,
                    point_cost=cost,
                    new_allocated_points=curr_alloc,
                    reason=f"Telegraph {telegraph_ms}ms < {MIN_TELEGRAPH_MS}ms minimum reaction floor",
                    remaining_budget=TOTAL_BUDGET - curr_alloc,
                )

        elif category == "position_prediction":
            if meta.get("is_instant_teleport_behind", False):
                return FairnessAuditResult(
                    approved=False,
                    tactic_id=req.tactic_id,
                    category=category,
                    point_cost=cost,
                    new_allocated_points=curr_alloc,
                    reason="Instant teleport behind player is prohibited by fairness engine",
                    remaining_budget=TOTAL_BUDGET - curr_alloc,
                )

        elif category == "pattern_recognition":
            conf = meta.get("signal_confidence", 0.0)
            if conf < MIN_PATTERN_CONFIDENCE:
                return FairnessAuditResult(
                    approved=False,
                    tactic_id=req.tactic_id,
                    category=category,
                    point_cost=cost,
                    new_allocated_points=curr_alloc,
                    reason=f"Signal confidence {conf:.2f} < {MIN_PATTERN_CONFIDENCE} minimum requirement",
                    remaining_budget=TOTAL_BUDGET - curr_alloc,
                )

        elif category == "defense_adjustment":
            if meta.get("has_invisible_iframes", False):
                return FairnessAuditResult(
                    approved=False,
                    tactic_id=req.tactic_id,
                    category=category,
                    point_cost=cost,
                    new_allocated_points=curr_alloc,
                    reason="Defense adjustment cannot grant invisible invulnerability",
                    remaining_budget=TOTAL_BUDGET - curr_alloc,
                )

        elif category == "spawn_adjustment":
            world_id = meta.get("world_id", 1)
            enemy_type = meta.get("enemy_type", "")
            pool = APPROVED_SPAWN_POOLS.get(world_id, [])
            if enemy_type not in pool:
                return FairnessAuditResult(
                    approved=False,
                    tactic_id=req.tactic_id,
                    category=category,
                    point_cost=cost,
                    new_allocated_points=curr_alloc,
                    reason=f"Enemy '{enemy_type}' not in approved spawn pool for World {world_id}",
                    remaining_budget=TOTAL_BUDGET - curr_alloc,
                )

        elif category == "phase_adjustment":
            hp_percent = meta.get("boss_hp_percent", 100.0)
            valid_ths = [75.0, 50.0, 25.0]
            if not any(abs(hp_percent - th) <= 2.0 for th in valid_ths):
                return FairnessAuditResult(
                    approved=False,
                    tactic_id=req.tactic_id,
                    category=category,
                    point_cost=cost,
                    new_allocated_points=curr_alloc,
                    reason=f"Phase adjustment only valid near 75%, 50%, or 25% (got {hp_percent}%)",
                    remaining_budget=TOTAL_BUDGET - curr_alloc,
                )

        new_alloc = curr_alloc + cost
        return FairnessAuditResult(
            approved=True,
            tactic_id=req.tactic_id,
            category=category,
            point_cost=cost,
            new_allocated_points=new_alloc,
            reason="Approved within 100-point fairness budget and category constraints",
            remaining_budget=TOTAL_BUDGET - new_alloc,
        )
