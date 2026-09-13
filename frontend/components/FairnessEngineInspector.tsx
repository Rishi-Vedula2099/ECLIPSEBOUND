'use client';

import React, { useState } from 'react';
import { ShieldAlert, CheckCircle2, XCircle, AlertTriangle, Scale, Clock, Crosshair, Sparkles, Shield, Users, Zap } from 'lucide-react';

interface TacticDefinition {
  category: string;
  name: string;
  maxCost: number;
  icon: any;
  color: string;
  constraints: string;
}

export default function FairnessEngineInspector() {
  const categories: TacticDefinition[] = [
    {
      category: "attack_counter",
      name: "Attack Counter",
      maxCost: 20,
      icon: Clock,
      color: "text-rose-400 border-rose-500/40 bg-rose-950/20",
      constraints: "Authored telegraph required; minimum 350ms reaction window",
    },
    {
      category: "position_prediction",
      name: "Position Prediction",
      maxCost: 15,
      icon: Crosshair,
      color: "text-amber-400 border-amber-500/40 bg-amber-950/20",
      constraints: "Bounded positioning bias (max 90°); strictly no instant teleports behind player",
    },
    {
      category: "pattern_recognition",
      name: "Pattern Recognition",
      maxCost: 20,
      icon: Sparkles,
      color: "text-purple-400 border-purple-500/40 bg-purple-950/20",
      constraints: "Requires signal confidence > 0.75; decays by 50% if counter fails",
    },
    {
      category: "defense_adjustment",
      name: "Defense Adjustment",
      maxCost: 15,
      icon: Shield,
      color: "text-blue-400 border-blue-500/40 bg-blue-950/20",
      constraints: "Authored stance change animation; no invisible invulnerability (iframes)",
    },
    {
      category: "spawn_adjustment",
      name: "Spawn Adjustment",
      maxCost: 10,
      icon: Users,
      color: "text-emerald-400 border-emerald-500/40 bg-emerald-950/20",
      constraints: "Minion spawn compositions strictly from approved encounter pools; rate-limited (12s)",
    },
    {
      category: "phase_adjustment",
      name: "Phase Adjustment",
      maxCost: 20,
      icon: Zap,
      color: "text-cyan-400 border-cyan-500/40 bg-cyan-950/20",
      constraints: "Triggered strictly at HP milestones (75%, 50%, 25% ±2%)",
    },
  ];

  // Active state for 100-point budget testing
  const [activePoints, setActivePoints] = useState<Record<string, number>>({
    attack_counter: 20,
    position_prediction: 15,
    pattern_recognition: 20,
    defense_adjustment: 0,
    spawn_adjustment: 10,
    phase_adjustment: 0,
  });

  // Candidate Audit Simulator Inputs
  const [candidateCat, setCandidateCat] = useState<string>("attack_counter");
  const [candidateCost, setCandidateCost] = useState<number>(20);
  const [telegraphMs, setTelegraphMs] = useState<number>(380);
  const [signalConfidence, setSignalConfidence] = useState<number>(0.82);
  const [instantTeleport, setInstantTeleport] = useState<boolean>(false);
  const [invisibleIframes, setInvisibleIframes] = useState<boolean>(false);
  const [bossHpPercent, setBossHpPercent] = useState<number>(50);

  const totalAllocated = Object.values(activePoints).reduce((a, b) => a + b, 0);
  const remainingBudget = 100 - totalAllocated;

  // Real-time evaluation of candidate adaptation
  const evaluateCandidate = () => {
    const catDef = categories.find(c => c.category === candidateCat);
    if (!catDef) return { approved: false, reason: "Unknown category" };

    if (candidateCost > catDef.maxCost) {
      return { approved: false, reason: `Cost ${candidateCost} pts exceeds category cap of ${catDef.maxCost} pts` };
    }

    if (activePoints[candidateCat] + candidateCost > catDef.maxCost) {
      return { approved: false, reason: `Category allocation would exceed ${catDef.maxCost} pt ceiling` };
    }

    if (totalAllocated + candidateCost > 100) {
      return { approved: false, reason: `100-Point Budget Exhausted! (Current: ${totalAllocated}, Needed: ${candidateCost})` };
    }

    if (candidateCat === "attack_counter" && telegraphMs < 350) {
      return { approved: false, reason: `Telegraph ${telegraphMs}ms < 350ms minimum reaction floor` };
    }

    if (candidateCat === "position_prediction" && instantTeleport) {
      return { approved: false, reason: "Prohibited: Cannot instantly teleport behind player without anticipatory telegraph" };
    }

    if (candidateCat === "pattern_recognition" && signalConfidence < 0.75) {
      return { approved: false, reason: `Signal confidence ${signalConfidence.toFixed(2)} < 0.75 threshold` };
    }

    if (candidateCat === "defense_adjustment" && invisibleIframes) {
      return { approved: false, reason: "Prohibited: Defense adjustment cannot grant invisible invulnerability" };
    }

    if (candidateCat === "phase_adjustment") {
      const validThs = [75, 50, 25];
      const valid = validThs.some(th => Math.abs(bossHpPercent - th) <= 2);
      if (!valid) {
        return { approved: false, reason: `Phase adjustment invalid at HP ${bossHpPercent}%; must be near 75%, 50%, or 25%` };
      }
    }

    return { approved: true, reason: "All fairness constraints and point limits satisfied!" };
  };

  const auditResult = evaluateCandidate();

  const toggleCategoryPoint = (cat: string, maxCost: number) => {
    setActivePoints(prev => ({
      ...prev,
      [cat]: prev[cat] > 0 ? 0 : (totalAllocated + maxCost <= 100 ? maxCost : prev[cat]),
    }));
  };

  return (
    <div className="space-y-6">
      {/* Top Banner */}
      <div className="glass-panel p-6 rounded-2xl flex flex-wrap items-center justify-between gap-4 border-l-4 border-l-emerald-500">
        <div>
          <h2 className="text-2xl font-bold tracking-tight text-white flex items-center gap-2">
            <Scale className="text-emerald-400 w-6 h-6" />
            Adaptive Game Intelligence & Fairness Engine
          </h2>
          <p className="text-slate-400 text-sm mt-1">
            Strict 100-point fairness regulator, category cost caps, and anti-frustration constraint auditor.
          </p>
        </div>
        <div className="bg-slate-900/80 px-4 py-2.5 rounded-xl border border-slate-700 flex items-center gap-4">
          <div>
            <div className="text-[11px] uppercase tracking-wider text-slate-400">Total Budget Allocated</div>
            <div className="font-mono text-xl font-bold">
              <span className={totalAllocated > 80 ? "text-rose-400" : "text-emerald-400"}>{totalAllocated}</span>
              <span className="text-slate-500"> / 100 pts</span>
            </div>
          </div>
          <div className="w-24 h-2 bg-slate-800 rounded-full overflow-hidden">
            <div
              className={`h-full transition-all duration-300 ${totalAllocated > 80 ? 'bg-rose-500' : 'bg-emerald-500'}`}
              style={{ width: `${totalAllocated}%` }}
            />
          </div>
        </div>
      </div>

      {/* 6 Category Breakdown Matrix */}
      <div>
        <h3 className="font-bold text-white text-base mb-3 flex items-center gap-2">
          <ShieldAlert className="w-4 h-4 text-emerald-400" />
          Fairness Budget Breakdown (6 Strict Categories)
        </h3>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {categories.map((cat) => {
            const Icon = cat.icon;
            const isAllocated = activePoints[cat.category] > 0;
            return (
              <div
                key={cat.category}
                onClick={() => toggleCategoryPoint(cat.category, cat.maxCost)}
                className={`cursor-pointer glass-panel p-5 rounded-xl border transition flex flex-col justify-between ${
                  isAllocated ? cat.color : "border-slate-800 hover:border-slate-700 opacity-60"
                }`}
              >
                <div>
                  <div className="flex items-center justify-between">
                    <span className="font-mono text-xs px-2.5 py-0.5 rounded-full bg-slate-900/80 font-bold border border-slate-700 text-white flex items-center gap-1.5">
                      <Icon className="w-3.5 h-3.5" />
                      Cap: {cat.maxCost} pts
                    </span>
                    <span className={`text-xs font-mono font-bold ${isAllocated ? "text-emerald-400" : "text-slate-500"}`}>
                      {isAllocated ? `${activePoints[cat.category]} pts active` : "Inactive"}
                    </span>
                  </div>
                  <h4 className="font-bold text-white text-base mt-3">{cat.name}</h4>
                  <p className="text-xs text-slate-300 mt-1">{cat.constraints}</p>
                </div>

                <div className="mt-4 pt-3 border-t border-slate-800/80 flex items-center justify-between text-xs">
                  <span className="text-slate-400">Click to toggle allocation</span>
                  <span className="text-slate-500 font-mono text-[11px]">Category: {cat.category}</span>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Candidate Audit Simulator */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left: Interactive Audit Parameters */}
        <div className="lg:col-span-6 glass-panel p-6 rounded-2xl border border-slate-800 space-y-4">
          <h3 className="font-bold text-white text-sm flex items-center gap-2">
            <Scale className="w-4 h-4 text-emerald-400" />
            Pre-Flight Adaptation Auditor Simulator
          </h3>
          <p className="text-xs text-slate-400">
            Simulate whether a boss adaptation tactic meets all strict fairness rules before deployment.
          </p>

          <div className="space-y-3 pt-2">
            <div>
              <label className="text-xs text-slate-400 block mb-1">Target Category</label>
              <select
                value={candidateCat}
                onChange={(e) => setCandidateCat(e.target.value)}
                className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-xs text-white"
              >
                {categories.map((c) => (
                  <option key={c.category} value={c.category}>{c.name} (Max {c.maxCost} pts)</option>
                ))}
              </select>
            </div>

            {candidateCat === "attack_counter" && (
              <div>
                <div className="flex justify-between text-xs mb-1">
                  <span className="text-slate-400">Telegraph Startup Window</span>
                  <span className="font-mono font-bold text-emerald-400">{telegraphMs} ms</span>
                </div>
                <input
                  type="range"
                  min="200"
                  max="600"
                  step="10"
                  value={telegraphMs}
                  onChange={(e) => setTelegraphMs(parseInt(e.target.value))}
                  className="w-full accent-emerald-500 bg-slate-800 rounded-lg cursor-pointer h-1.5"
                />
                <span className="text-[10px] text-slate-500">Minimum required reaction floor: 350 ms</span>
              </div>
            )}

            {candidateCat === "position_prediction" && (
              <div className="flex items-center gap-3 bg-slate-900/60 p-3 rounded-xl border border-slate-800">
                <input
                  type="checkbox"
                  id="teleport"
                  checked={instantTeleport}
                  onChange={(e) => setInstantTeleport(e.target.checked)}
                  className="accent-rose-500 w-4 h-4"
                />
                <label htmlFor="teleport" className="text-xs text-slate-300">
                  Simulate instant untelegraphed teleport behind player (Strictly illegal)
                </label>
              </div>
            )}

            {candidateCat === "pattern_recognition" && (
              <div>
                <div className="flex justify-between text-xs mb-1">
                  <span className="text-slate-400">Observed Signal Confidence</span>
                  <span className="font-mono font-bold text-purple-400">{(signalConfidence * 100).toFixed(0)}%</span>
                </div>
                <input
                  type="range"
                  min="0.40"
                  max="1.0"
                  step="0.05"
                  value={signalConfidence}
                  onChange={(e) => setSignalConfidence(parseFloat(e.target.value))}
                  className="w-full accent-purple-500 bg-slate-800 rounded-lg cursor-pointer h-1.5"
                />
                <span className="text-[10px] text-slate-500">Minimum threshold: 75% confidence (decays 50% on failure)</span>
              </div>
            )}

            {candidateCat === "defense_adjustment" && (
              <div className="flex items-center gap-3 bg-slate-900/60 p-3 rounded-xl border border-slate-800">
                <input
                  type="checkbox"
                  id="iframes"
                  checked={invisibleIframes}
                  onChange={(e) => setInvisibleIframes(e.target.checked)}
                  className="accent-rose-500 w-4 h-4"
                />
                <label htmlFor="iframes" className="text-xs text-slate-300">
                  Simulate invisible invulnerability / iframes (Strictly illegal)
                </label>
              </div>
            )}

            {candidateCat === "phase_adjustment" && (
              <div>
                <div className="flex justify-between text-xs mb-1">
                  <span className="text-slate-400">Boss HP Percentage</span>
                  <span className="font-mono font-bold text-cyan-400">{bossHpPercent}%</span>
                </div>
                <input
                  type="range"
                  min="10"
                  max="90"
                  step="5"
                  value={bossHpPercent}
                  onChange={(e) => setBossHpPercent(parseInt(e.target.value))}
                  className="w-full accent-cyan-500 bg-slate-800 rounded-lg cursor-pointer h-1.5"
                />
                <span className="text-[10px] text-slate-500">Valid milestones: 75%, 50%, 25% (±2%)</span>
              </div>
            )}
          </div>
        </div>

        {/* Right: Live Audit Result */}
        <div className="lg:col-span-6 glass-panel p-6 rounded-2xl border border-slate-800 flex flex-col justify-between">
          <div>
            <h3 className="font-bold text-white text-sm flex items-center gap-2 mb-4">
              <CheckCircle2 className="w-4 h-4 text-cyan-400" />
              Audit Evaluation Result
            </h3>

            <div className={`p-5 rounded-xl border flex items-start gap-4 ${
              auditResult.approved
                ? "bg-emerald-950/20 border-emerald-500/40 text-emerald-200"
                : "bg-rose-950/20 border-rose-500/40 text-rose-200"
            }`}>
              {auditResult.approved ? (
                <CheckCircle2 className="w-6 h-6 text-emerald-400 shrink-0 mt-0.5" />
              ) : (
                <XCircle className="w-6 h-6 text-rose-400 shrink-0 mt-0.5" />
              )}
              <div>
                <div className="font-bold text-white text-base">
                  {auditResult.approved ? "ADAPTATION APPROVED" : "FAIRNESS VIOLATION: REJECTED"}
                </div>
                <p className="text-xs mt-1.5 leading-relaxed">{auditResult.reason}</p>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3 mt-4 text-xs font-mono">
              <div className="bg-slate-900/80 p-3 rounded-xl border border-slate-800">
                <span className="text-slate-500 block text-[10px]">CURRENT REMAINING</span>
                <span className="font-bold text-white text-base">{remainingBudget} pts</span>
              </div>
              <div className="bg-slate-900/80 p-3 rounded-xl border border-slate-800">
                <span className="text-slate-500 block text-[10px]">CANDIDATE COST</span>
                <span className="font-bold text-emerald-400 text-base">{candidateCost} pts</span>
              </div>
            </div>
          </div>

          <div className="text-[11px] text-slate-500 pt-4 border-t border-slate-800/80 mt-4">
            Under ECLIPSEBOUND core design philosophy, bosses must feel intelligent and responsive without ever cheating or frustrating player mastery.
          </div>
        </div>
      </div>
    </div>
  );
}
