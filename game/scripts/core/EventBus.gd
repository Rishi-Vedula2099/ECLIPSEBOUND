# EventBus.gd
# Global decoupled signal bus for ECLIPSEBOUND core systems.
extends Node

# Player Signals
signal player_spawned(player_node: Node2D)
signal player_damaged(current_hp: float, max_hp: float, damage: float, source: String)
signal player_healed(current_hp: float, max_hp: float, amount: float)
signal player_attacked(weapon_id: String, attack_type: String, position: Vector2)
signal player_dodged(direction: Vector2, is_perfect: bool)
signal player_parried(target_id: String, success: bool)
signal player_died(cause: String, position: Vector2)

# Enemy & Boss Signals
signal enemy_spawned(enemy_id: String, archetype: String, position: Vector2)
signal enemy_damaged(enemy_id: String, damage: float, is_critical: bool)
signal enemy_died(enemy_id: String, archetype: String)
signal boss_phase_changed(boss_id: String, phase: int)
signal boss_adapted(boss_id: String, counter_action: String, reasoning: String)

# Telemetry & Game State Signals
signal telemetry_event_emitted(event_type: String, payload: Dictionary)
signal world_changed(world_id: int, world_name: String)
signal xp_gained(amount: float, new_total: float, current_level: int)
