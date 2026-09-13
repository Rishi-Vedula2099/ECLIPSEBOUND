'use client';

import React, { useState } from 'react';
import { Skull, AlertTriangle, Activity, Sliders, ShieldAlert, Cpu, BrainCircuit, RefreshCw } from 'lucide-react';

interface AdaptationTactic {
  id: string;
  name: string;
  cost: number;
  minReactionMs: number;
  description: string;
  condition: string;
  category: 'aggression' | 'reactiveness' | 'cunning' | 'patience';
  active: boolean;
}

export default function BossLabInspector() {
  const [selectedBoss, setSelectedBoss] = useState<string>("hollow_stag");
  
  // Personality parameters
  const [personality, setPersonality] = useState({
    aggression: 0.75,
    patience: 0.30,
    reactiveness: 0.85,
    cunning: 0.60,
  });

  // Current-fight memory metrics (simulated telemetry / rolling buffer)
  const [fightMemory, setFightMemory] = useState({
    parryFrequency: 0.68,
    dodgeDirectionBias: "Right (74%)",
    dodgeConfidence: 0.74,
    meleeComboFrequency: 0.82,
    kiteDurationSec: 2.1,
  });

  const [tactics, setTactics] = useState<AdaptationTactic[]>([
    {
      id: "counter_cleave",
      name: "Parry Counter Cleave",
      cost: 20,
      minReactionMs: 380,
      description: "Detects habitual parry timing and buffers a delayed heavy feint sweep.",
      condition: "Player parry frequency > 65%",
      category: "reactiveness",
      active: true,
    },
    {
      id: "anticipate_dash",
      name: "Directional Dash Prediction",
      cost: 15,
      minReactionMs: 350,
      description: "Anticipates player dodge bias (Right 74%) and angles thorn roots into recovery path.",
      condition: "Player dodge direction confidence > 0.70",
      category: "cunning",
      active: true,
    },
    {
      id: "anti_spam_stagger",
      name: "Pattern Interrupt Pulse",
      cost: 20,
      minReactionMs: 400,
      description: "Releases a shockwave when player executes >3 light attack combo in melee range.",
      condition: "Melee pressure frequency > 0.80",
      category: "patience",
      active: true,
    },
    {
      id: "defensive_bark",
      name: "Living Bark Stance",
      cost: 15,
      minReactionMs: 450,
      description: "Visual stance shift granting temporary armor while charging beam attack.",
      condition: "HP drops below 50%",
      category: "patience",
      active: false,
    },
    {
      id: "spore_summon",
      name: "Minion Spawn Reinforcement",
      cost: 10,
      minReactionMs: 500,
      description: "Summons 2 Moss Gnats to disrupt long-range bow or staff kiting.",
      condition: "Player distance > 300px for >5s",
      category: "cunning",
      active: false,
    },
    {
      id: "phase_enrage",
      name: "Eclipse Beam Overdrive",
      cost: 20,
      minReactionMs: 350,
      description: "Fires sweeping eclipse energy beam with high-contrast floor telegraph.",
      condition: "Boss HP < 25%",
      category: "aggression",
      active: true,
    },
  ]);

  const totalBudget = 100;
  const usedBudget = tactics.filter(t => t.active).reduce((sum, t) => sum + t.cost, 0);
  const remainingBudget = totalBudget - usedBudget;

  const toggleTactic = (id: string) => {
    setTactics(prev =>
      prev.map(t => {
        if (t.id === id) {
          if (!t.active && remainingBudget < t.cost) return t; // Exceeds budget
          return { ...t, active: !t.active };
        }
        return t;
      })
    );
  };

  // Calculate dynamic tactic score based on personality weight and memory
  const getDynamicScore = (tactic: AdaptationTactic) => {
    const personalityWeight = personality[tactic.category] || 0.5;
    let memoryMultiplier = 1.0;
    if (tactic.id === "counter_cleave") memoryMultiplier = fightMemory.parryFrequency;
    if (tactic.id === "anticipate_dash") memoryMultiplier = fightMemory.dodgeConfidence;
    if (tactic.id === "anti_spam_stagger") memoryMultiplier = fightMemory.meleeComboFrequency;
    return (personalityWeight * 0.6 + memoryMultiplier * 0.4).toFixed(2);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="glass-panel p-6 rounded-2xl flex flex-wrap items-center justify-between gap-4 border-l-4 border-l-purple-500">
        <div>
          <h2 className="text-2xl font-bold tracking-tight text-white flex items-center gap-2">
            <Skull className="text-purple-400 w-6 h-6" />
            Boss Lab & Adaptation Inspector
          </h2>
          <p className="text-slate-400 text-sm mt-1">
            Simulate and inspect boss adaptation heuristics strictly regulated by the 100-Point Fairness Budget.
          </p>
        </div>
        <div className="bg-slate-900/80 px-4 py-2.5 rounded-xl border border-slate-700 flex items-center gap-4">
          <div>
            <div className="text-[11px] uppercase tracking-wider text-slate-400">Fairness Budget</div>
            <div className="font-mono text-xl font-bold">
              <span className={usedBudget > 80 ? "text-rose-400" : "text-emerald-400"}>{usedBudget}</span>
              <span className="text-slate-500"> / 100 pts</span>
            </div>
          </div>
          <div className="w-24 h-2 bg-slate-800 rounded-full overflow-hidden">
            <div
              className={`h-full transition-all duration-300 ${usedBudget > 80 ? 'bg-rose-500' : 'bg-emerald-500'}`}
              style={{ width: `${(usedBudget / totalBudget) * 100}%` }}
            />
          </div>
        </div>
      </div>

      {/* Rules Notice */}
      <div className="bg-purple-950/20 border border-purple-900/40 rounded-xl p-4 flex items-start gap-3 text-xs text-purple-200">
        <AlertTriangle className="w-5 h-5 text-purple-400 shrink-0 mt-0.5" />
        <div>
          <span className="font-bold text-white">Strict Fairness Guarantee:</span> Bosses are prohibited from exceeding 100 adaptation points at any moment. No adaptation may bypass telegraphs (minimum 350ms reaction window), read future controller inputs, or teleport behind player without authored audio/visual anticipation cues.
        </div>
      </div>

      {/* Personality & In-Memory Telemetry Controls */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Boss Personality Weights */}
        <div className="glass-panel p-6 rounded-2xl border border-slate-800">
          <h3 className="font-bold text-white flex items-center gap-2 mb-4 text-sm">
            <BrainCircuit className="w-4 h-4 text-purple-400" />
            Boss Personality Matrix (Hollow Stag)
          </h3>
          <div className="space-y-4">
            {(['aggression', 'patience', 'reactiveness', 'cunning'] as const).map((trait) => (
              <div key={trait}>
                <div className="flex justify-between text-xs mb-1">
                  <span className="capitalize font-semibold text-slate-300">{trait}</span>
                  <span className="font-mono text-purple-400 font-bold">{personality[trait].toFixed(2)}</span>
                </div>
                <input
                  type="range"
                  min="0"
                  max="1"
                  step="0.05"
                  value={personality[trait]}
                  onChange={(e) => setPersonality({ ...personality, [trait]: parseFloat(e.target.value) })}
                  className="w-full accent-purple-500 bg-slate-800 rounded-lg cursor-pointer h-1.5"
                />
              </div>
            ))}
          </div>
        </div>

        {/* Current-Fight Memory State */}
        <div className="glass-panel p-6 rounded-2xl border border-slate-800">
          <h3 className="font-bold text-white flex items-center gap-2 mb-4 text-sm">
            <Cpu className="w-4 h-4 text-cyan-400" />
            Current-Fight Circular Memory Buffer (50 Events)
          </h3>
          <div className="grid grid-cols-2 gap-4">
            <div className="bg-slate-900/60 p-3 rounded-xl border border-slate-800">
              <div className="text-[11px] text-slate-400">Player Parry Rate</div>
              <div className="font-mono text-lg font-bold text-cyan-400 mt-1">
                {(fightMemory.parryFrequency * 100).toFixed(0)}%
              </div>
              <div className="text-[10px] text-slate-500 mt-0.5">Threshold: &gt; 65%</div>
            </div>

            <div className="bg-slate-900/60 p-3 rounded-xl border border-slate-800">
              <div className="text-[11px] text-slate-400">Dodge Bias Direction</div>
              <div className="font-mono text-lg font-bold text-emerald-400 mt-1">
                {fightMemory.dodgeDirectionBias}
              </div>
              <div className="text-[10px] text-slate-500 mt-0.5">Confidence: {fightMemory.dodgeConfidence.toFixed(2)}</div>
            </div>

            <div className="bg-slate-900/60 p-3 rounded-xl border border-slate-800">
              <div className="text-[11px] text-slate-400">Melee Combo Frequency</div>
              <div className="font-mono text-lg font-bold text-amber-400 mt-1">
                {(fightMemory.meleeComboFrequency * 100).toFixed(0)}%
              </div>
              <div className="text-[10px] text-slate-500 mt-0.5">&gt;3 Hits in Melee Range</div>
            </div>

            <div className="bg-slate-900/60 p-3 rounded-xl border border-slate-800">
              <div className="text-[11px] text-slate-400">Telegraph Floor Minimum</div>
              <div className="font-mono text-lg font-bold text-rose-400 mt-1">
                350 ms
              </div>
              <div className="text-[10px] text-slate-500 mt-0.5">Strict Anti-Frustration Rule</div>
            </div>
          </div>
        </div>
      </div>

      {/* Tactics Matrix */}
      <div>
        <h3 className="font-bold text-white text-base mb-3 flex items-center gap-2">
          <Sliders className="w-4 h-4 text-purple-400" />
          Active Adaptation Tactics (Utility Scored)
        </h3>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {tactics.map((tactic) => {
            const dynamicScore = getDynamicScore(tactic);
            return (
              <div
                key={tactic.id}
                onClick={() => toggleTactic(tactic.id)}
                className={`cursor-pointer glass-panel p-5 rounded-xl border transition flex flex-col justify-between ${
                  tactic.active
                    ? "border-purple-500/60 bg-purple-950/20 glow-void"
                    : "border-slate-800 hover:border-slate-700 opacity-60"
                }`}
              >
                <div>
                  <div className="flex items-center justify-between">
                    <span className="font-mono text-xs px-2 py-0.5 rounded-full bg-slate-800 text-purple-300 font-bold">
                      {tactic.cost} pts
                    </span>
                    <span className="text-[11px] font-mono text-slate-400 flex items-center gap-1">
                      <Activity className="w-3 h-3 text-cyan-400" />
                      Telegraph: {tactic.minReactionMs}ms
                    </span>
                  </div>
                  <h4 className="font-bold text-white text-base mt-2">{tactic.name}</h4>
                  <p className="text-xs text-slate-300 mt-1">{tactic.description}</p>
                </div>

                <div className="mt-4 pt-3 border-t border-slate-800/80 flex items-center justify-between text-xs">
                  <div>
                    <span className="text-slate-400 block text-[10px] uppercase font-mono">Utility Score</span>
                    <span className="font-mono font-bold text-purple-300">{dynamicScore}</span>
                  </div>
                  <span className={`font-semibold ${tactic.active ? "text-emerald-400" : "text-slate-500"}`}>
                    {tactic.active ? "Active" : "Disabled"}
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
