'use client';

import React, { useState } from 'react';
import { Activity, Radio, Cpu, BarChart3, Clock, Compass, Shield, Sword, Sparkles, RefreshCw, AlertCircle } from 'lucide-react';

export default function TelemetryDashboard() {
  const [alpha, setAlpha] = useState<number>(0.20);
  const [confidenceDecayed, setConfidenceDecayed] = useState<boolean>(false);

  const [signals, setSignals] = useState({
    // Offense
    lightHeavyRatio: 0.72,
    avgComboLength: 2.8,
    attackRate: 1.45,
    // Defense
    dodgeRate: 0.65,
    parryRate: 0.58,
    blockRate: 0.12,
    damageTakenPerHit: 22.4,
    // Positioning
    distancePref: "MID (58%)",
    retreatHpThreshold: 32,
    // Mobility
    dashFrequency: 18.2,
    dodgeDirectionBias: "Right (74%)",
    dodgeConfidence: 0.78,
    // Abilities & Items
    skillFrequency: 4.6,
    avgCooldownLatency: 0.85,
    avgHealThreshold: 34,
    greedyHeals: 2,
    // Build & Risk
    weapon: "Longsword (Iron Vow)",
    artifactSet: "Verdant Guardian (4-Piece)",
    lowHpAggression: 0.68,
  });

  const recentEvents = [
    { id: 1, type: "player_attack", time: "12:54:10", payload: "Light Strike #2 (48 DMG) -> EWMA combo updated" },
    { id: 2, type: "hit_resolved", time: "12:54:12", payload: "Parry Success vs Antler Sweep -> Parry Rate adjusted" },
    { id: 3, type: "player_dodge", time: "12:54:14", payload: "Dodge RIGHT -> Bayesian Direction Confidence updated (0.78)" },
    { id: 4, type: "boss_adaptation", time: "12:54:16", payload: "Fairness Engine: Approved Position Prediction (-15 pts)" },
    { id: 5, type: "counter_punished", time: "12:54:20", payload: "Boss feint punished by player -> 50% confidence decay applied" },
  ];

  const handleSimulateCounterFailure = () => {
    setSignals(prev => ({
      ...prev,
      dodgeConfidence: Math.max(0.15, prev.dodgeConfidence * 0.50),
      parryRate: Math.max(0.10, prev.parryRate * 0.70),
    }));
    setConfidenceDecayed(true);
    setTimeout(() => setConfidenceDecayed(false), 3000);
  };

  const handleTemporalDecay = () => {
    setSignals(prev => ({
      ...prev,
      lightHeavyRatio: 0.5 + (prev.lightHeavyRatio - 0.5) * 0.8,
      dodgeRate: 0.5 + (prev.dodgeRate - 0.5) * 0.8,
      parryRate: 0.5 + (prev.parryRate - 0.5) * 0.8,
      lowHpAggression: 0.5 + (prev.lowHpAggression - 0.5) * 0.8,
      dodgeConfidence: Math.max(0.33, prev.dodgeConfidence * 0.85),
    }));
  };

  return (
    <div className="space-y-6">
      {/* Top Banner */}
      <div className="glass-panel p-6 rounded-2xl flex flex-wrap items-center justify-between gap-4 border-l-4 border-l-cyan-500">
        <div>
          <h2 className="text-2xl font-bold tracking-tight text-white flex items-center gap-2">
            <Radio className="text-cyan-400 w-6 h-6 animate-pulse" />
            Player Behavioral Fingerprint & Ingestion Stream
          </h2>
          <p className="text-slate-400 text-sm mt-1">
            Real-time telemetry stream, 6-category EWMA behavioral fingerprint, and Bayesian confidence decay.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={handleSimulateCounterFailure}
            className="px-3 py-1.5 rounded-lg bg-rose-950/60 border border-rose-600/40 text-xs font-bold text-rose-300 hover:bg-rose-900/60 transition flex items-center gap-1.5"
          >
            <AlertCircle className="w-3.5 h-3.5 text-rose-400" />
            Simulate Counter Failure (50% Decay)
          </button>
          <button
            onClick={handleTemporalDecay}
            className="px-3 py-1.5 rounded-lg bg-slate-900 border border-slate-700 text-xs font-bold text-slate-300 hover:bg-slate-800 transition flex items-center gap-1.5"
          >
            <RefreshCw className="w-3.5 h-3.5 text-cyan-400" />
            Apply Temporal Decay
          </button>
          <div className="flex items-center gap-2 bg-emerald-950/40 border border-emerald-500/30 px-3 py-1.5 rounded-full text-xs text-emerald-300 font-mono">
            <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping" />
            Ingestion Active (60 Hz)
          </div>
        </div>
      </div>

      {confidenceDecayed && (
        <div className="bg-rose-950/40 border border-rose-500/50 rounded-xl p-3 text-xs text-rose-200 flex items-center gap-2 animate-bounce">
          <AlertCircle className="w-4 h-4 text-rose-400" />
          <span>Counter Failed! Habit confidence decayed by 50% to prevent rigid exploitation.</span>
        </div>
      )}

      {/* EWMA Controls */}
      <div className="glass-panel p-4 rounded-xl border border-slate-800 flex items-center justify-between gap-4 text-xs">
        <div className="flex items-center gap-2 text-slate-300">
          <span className="font-bold text-white">EWMA Smoothing Factor (α):</span>
          <span className="font-mono text-cyan-400 font-bold">{alpha.toFixed(2)}</span>
          <span className="text-slate-500">(Formula: S_t = α · Y_t + (1 - α) · S_t-1)</span>
        </div>
        <input
          type="range"
          min="0.05"
          max="0.50"
          step="0.05"
          value={alpha}
          onChange={(e) => setAlpha(parseFloat(e.target.value))}
          className="w-48 accent-cyan-500 bg-slate-800 rounded-lg cursor-pointer h-1.5"
        />
      </div>

      {/* 6 Observable Categories Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {/* Category 1: Offense */}
        <div className="glass-panel p-5 rounded-xl border border-slate-800 space-y-3">
          <h3 className="font-bold text-white text-sm flex items-center gap-2">
            <Sword className="w-4 h-4 text-rose-400" />
            1. Offense Signals
          </h3>
          <div className="space-y-2 text-xs">
            <div className="flex justify-between font-mono bg-slate-900/60 p-2.5 rounded-lg border border-slate-800">
              <span className="text-slate-400">Light vs Heavy Ratio</span>
              <span className="text-rose-400 font-bold">{(signals.lightHeavyRatio * 100).toFixed(0)}% Light</span>
            </div>
            <div className="flex justify-between font-mono bg-slate-900/60 p-2.5 rounded-lg border border-slate-800">
              <span className="text-slate-400">Avg Combo Length</span>
              <span className="text-white font-bold">{signals.avgComboLength.toFixed(1)} Hits</span>
            </div>
            <div className="flex justify-between font-mono bg-slate-900/60 p-2.5 rounded-lg border border-slate-800">
              <span className="text-slate-400">Attack Rate</span>
              <span className="text-amber-400 font-bold">{signals.attackRate} / sec</span>
            </div>
          </div>
        </div>

        {/* Category 2: Defense */}
        <div className="glass-panel p-5 rounded-xl border border-slate-800 space-y-3">
          <h3 className="font-bold text-white text-sm flex items-center gap-2">
            <Shield className="w-4 h-4 text-blue-400" />
            2. Defense Signals
          </h3>
          <div className="space-y-2 text-xs">
            <div className="flex justify-between font-mono bg-slate-900/60 p-2.5 rounded-lg border border-slate-800">
              <span className="text-slate-400">Dodge Rate</span>
              <span className="text-emerald-400 font-bold">{(signals.dodgeRate * 100).toFixed(0)}%</span>
            </div>
            <div className="flex justify-between font-mono bg-slate-900/60 p-2.5 rounded-lg border border-slate-800">
              <span className="text-slate-400">Parry Rate</span>
              <span className="text-cyan-400 font-bold">{(signals.parryRate * 100).toFixed(0)}%</span>
            </div>
            <div className="flex justify-between font-mono bg-slate-900/60 p-2.5 rounded-lg border border-slate-800">
              <span className="text-slate-400">Mean Dmg Taken / Hit</span>
              <span className="text-rose-400 font-bold">{signals.damageTakenPerHit} HP</span>
            </div>
          </div>
        </div>

        {/* Category 3: Positioning */}
        <div className="glass-panel p-5 rounded-xl border border-slate-800 space-y-3">
          <h3 className="font-bold text-white text-sm flex items-center gap-2">
            <Compass className="w-4 h-4 text-amber-400" />
            3. Positioning Signals
          </h3>
          <div className="space-y-2 text-xs">
            <div className="flex justify-between font-mono bg-slate-900/60 p-2.5 rounded-lg border border-slate-800">
              <span className="text-slate-400">Distance Preference</span>
              <span className="text-amber-400 font-bold">{signals.distancePref}</span>
            </div>
            <div className="flex justify-between font-mono bg-slate-900/60 p-2.5 rounded-lg border border-slate-800">
              <span className="text-slate-400">Retreat HP Threshold</span>
              <span className="text-white font-bold">&lt; {signals.retreatHpThreshold}% HP</span>
            </div>
            <div className="flex justify-between font-mono bg-slate-900/60 p-2.5 rounded-lg border border-slate-800">
              <span className="text-slate-400">Kiting Tendency</span>
              <span className="text-emerald-400 font-bold">Low (Melee/Mid bias)</span>
            </div>
          </div>
        </div>

        {/* Category 4: Mobility */}
        <div className="glass-panel p-5 rounded-xl border border-slate-800 space-y-3">
          <h3 className="font-bold text-white text-sm flex items-center gap-2">
            <Activity className="w-4 h-4 text-emerald-400" />
            4. Mobility Signals
          </h3>
          <div className="space-y-2 text-xs">
            <div className="flex justify-between font-mono bg-slate-900/60 p-2.5 rounded-lg border border-slate-800">
              <span className="text-slate-400">Dash Frequency</span>
              <span className="text-emerald-400 font-bold">{signals.dashFrequency} / min</span>
            </div>
            <div className="flex justify-between font-mono bg-slate-900/60 p-2.5 rounded-lg border border-slate-800">
              <span className="text-slate-400">Dodge Bias Direction</span>
              <span className="text-white font-bold">{signals.dodgeDirectionBias}</span>
            </div>
            <div className="flex justify-between font-mono bg-slate-900/60 p-2.5 rounded-lg border border-slate-800">
              <span className="text-slate-400">Bayesian Confidence</span>
              <span className="text-purple-400 font-bold">{(signals.dodgeConfidence * 100).toFixed(0)}%</span>
            </div>
          </div>
        </div>

        {/* Category 5: Abilities & Items */}
        <div className="glass-panel p-5 rounded-xl border border-slate-800 space-y-3">
          <h3 className="font-bold text-white text-sm flex items-center gap-2">
            <Sparkles className="w-4 h-4 text-purple-400" />
            5. Abilities & Items
          </h3>
          <div className="space-y-2 text-xs">
            <div className="flex justify-between font-mono bg-slate-900/60 p-2.5 rounded-lg border border-slate-800">
              <span className="text-slate-400">Skill Frequency</span>
              <span className="text-purple-400 font-bold">{signals.skillFrequency} / min</span>
            </div>
            <div className="flex justify-between font-mono bg-slate-900/60 p-2.5 rounded-lg border border-slate-800">
              <span className="text-slate-400">Cooldown Latency</span>
              <span className="text-white font-bold">{signals.avgCooldownLatency}s after ready</span>
            </div>
            <div className="flex justify-between font-mono bg-slate-900/60 p-2.5 rounded-lg border border-slate-800">
              <span className="text-slate-400">Heal Potion HP Trigger</span>
              <span className="text-cyan-400 font-bold">{signals.avgHealThreshold}% HP</span>
            </div>
          </div>
        </div>

        {/* Category 6: Build & Risk */}
        <div className="glass-panel p-5 rounded-xl border border-slate-800 space-y-3">
          <h3 className="font-bold text-white text-sm flex items-center gap-2">
            <BarChart3 className="w-4 h-4 text-cyan-400" />
            6. Build & Risk Profile
          </h3>
          <div className="space-y-2 text-xs">
            <div className="flex justify-between font-mono bg-slate-900/60 p-2.5 rounded-lg border border-slate-800">
              <span className="text-slate-400">Equipped Weapon</span>
              <span className="text-white font-bold">{signals.weapon}</span>
            </div>
            <div className="flex justify-between font-mono bg-slate-900/60 p-2.5 rounded-lg border border-slate-800">
              <span className="text-slate-400">Artifact Resonance</span>
              <span className="text-emerald-400 font-bold">{signals.artifactSet}</span>
            </div>
            <div className="flex justify-between font-mono bg-slate-900/60 p-2.5 rounded-lg border border-slate-800">
              <span className="text-slate-400">Low-HP Aggression</span>
              <span className="text-rose-400 font-bold">{(signals.lowHpAggression * 100).toFixed(0)}%</span>
            </div>
          </div>
        </div>
      </div>

      {/* Live Event Stream */}
      <div className="glass-panel p-5 rounded-2xl space-y-4">
        <h3 className="text-sm font-bold uppercase tracking-wider text-slate-300 flex items-center gap-2">
          <Activity className="w-4 h-4 text-emerald-400" />
          Live Ingestion Buffer (ADR-003 Protocol)
        </h3>

        <div className="space-y-2 font-mono text-xs">
          {recentEvents.map((ev) => (
            <div
              key={ev.id}
              className="bg-slate-900/80 p-3 rounded-xl border border-slate-800/80 flex items-start gap-3 hover:border-slate-700 transition"
            >
              <span className="text-slate-500 font-bold">{ev.time}</span>
              <span className="px-2 py-0.5 rounded bg-slate-800 text-cyan-400 font-semibold border border-slate-700/60">
                {ev.type}
              </span>
              <span className="text-slate-300 flex-1">{ev.payload}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
