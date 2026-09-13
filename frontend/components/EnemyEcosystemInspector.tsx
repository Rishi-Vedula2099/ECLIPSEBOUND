'use client';

import React, { useState } from 'react';
import { Eye, Volume2, Shield, Activity, Target, Zap, ChevronRight } from 'lucide-react';

interface EnemyArchetype {
  id: string;
  name: string;
  role: string;
  badgeColor: string;
  health: number;
  poise: number;
  speed: number;
  visionRange: number;
  visionFov: number;
  hearingRadius: number;
  proximityRadius: number;
  description: string;
  utilityActions: { name: string; weight: number; curve: string; trigger: string }[];
}

const ENEMY_ARCHETYPES: EnemyArchetype[] = [
  {
    id: "bramble_beast",
    name: "Bramble Beast",
    role: "Melee Brawler / Predator",
    badgeColor: "bg-amber-950 text-amber-300 border-amber-800",
    health: 75,
    poise: 35,
    speed: 120,
    visionRange: 200,
    visionFov: 110,
    hearingRadius: 260,
    proximityRadius: 48,
    description: "Quadruped predator that stalks the forest undergrowth. Closes gaps aggressively and executes bleeding leap pounces.",
    utilityActions: [
      { name: "Pounce Leap", weight: 1.5, curve: "Bell Curve @ 50px (Spread 30px)", trigger: "Mid-range spacing (40–80px)" },
      { name: "Melee Rush", weight: 1.2, curve: "Inverse Linear (0–40px)", trigger: "Close melee contact (<40px)" },
      { name: "Flank Reposition", weight: 0.8, curve: "Linear (40–200px)", trigger: "Player circling or retreating" }
    ]
  },
  {
    id: "moss_gnat",
    name: "Moss Gnat",
    role: "Aerial Skirmisher / Harasser",
    badgeColor: "bg-emerald-950 text-emerald-300 border-emerald-800",
    health: 35,
    poise: 15,
    speed: 85,
    visionRange: 220,
    visionFov: 130,
    hearingRadius: 260,
    proximityRadius: 36,
    description: "Hovering airborne insect that avoids ground melee hazards. Bombards players with slowing pollen spores and kites away if approached.",
    utilityActions: [
      { name: "Spore Bomb", weight: 1.4, curve: "Bell Curve @ 70px (Spread 40px)", trigger: "Ranged standoff (60–100px)" },
      { name: "Aerial Kite", weight: 1.6, curve: "Inverse Linear (0–45px)", trigger: "Player rushes into melee (<45px)" },
      { name: "Wobble Drift", weight: 0.7, curve: "Constant Hover", trigger: "Default patrol altitude" }
    ]
  },
  {
    id: "verdant_slime",
    name: "Verdant Slime",
    role: "Swarm Disrupter / Area Denial",
    badgeColor: "bg-lime-950 text-lime-300 border-lime-800",
    health: 45,
    poise: 20,
    speed: 70,
    visionRange: 160,
    visionFov: 90,
    hearingRadius: 200,
    proximityRadius: 32,
    description: "Gelatinous creature that moves in hopping bursts. Spits pools of caustic acid that deny movement corridors and punish staggered targets.",
    utilityActions: [
      { name: "Acid Lunge", weight: 1.3, curve: "Inverse Linear (0–32px)", trigger: "Target within splash radius (<32px)" },
      { name: "Swarm Hop", weight: 1.0, curve: "Linear (30–120px)", trigger: "Gap closing hop cycle" },
      { name: "Acid Pool Spit", weight: 1.1, curve: "Contextual Cooldown", trigger: "Leaves hazard on death or impact" }
    ]
  },
  {
    id: "elder_root_beast",
    name: "Elder Root Beast",
    role: "Miniboss / Heavy Poise Brute",
    badgeColor: "bg-orange-950 text-orange-300 border-orange-800",
    health: 320,
    poise: 80,
    speed: 80,
    visionRange: 280,
    visionFov: 120,
    hearingRadius: 320,
    proximityRadius: 64,
    description: "Ancient colossal root creature guarding the entrance to the inner sanctum. Features hyper-armor swings and unblockable ground stomp shockwaves.",
    utilityActions: [
      { name: "Seismic Stomp", weight: 1.6, curve: "Inverse Linear (0–60px)", trigger: "Player in ground contact (<60px)" },
      { name: "Root Sweep", weight: 1.2, curve: "Bell Curve @ 40px (Spread 25px)", trigger: "Heavy sweeping frontal cleave" },
      { name: "Stagger Resistance", weight: 2.0, curve: "Poise Passive", trigger: "Immune to light attack interrupts" }
    ]
  },
  {
    id: "verdant_guardian_elite",
    name: "Verdant Guardian Elite",
    role: "Elite Tactician / Frontline Sentinel",
    badgeColor: "bg-purple-950 text-purple-300 border-purple-800",
    health: 180,
    poise: 60,
    speed: 60,
    visionRange: 240,
    visionFov: 100,
    hearingRadius: 280,
    proximityRadius: 52,
    description: "Armored guardian equipped with a massive tower shield. Raises frontal guard to block standard attacks and responds with a multi-hit cleave combo.",
    utilityActions: [
      { name: "Elite Cleave", weight: 1.4, curve: "Inverse Linear (0–52px)", trigger: "Player in weapon reach (<52px)" },
      { name: "Shield Advance", weight: 1.2, curve: "Linear (40–180px)", trigger: "Approaching player with shield raised" },
      { name: "Guard Counter", weight: 1.5, curve: "Reaction Trigger", trigger: "Counters blocked non-guard-breaking hit" }
    ]
  }
];

export default function EnemyEcosystemInspector() {
  const [selectedEnemyId, setSelectedEnemyId] = useState<string>("bramble_beast");

  const currentEnemy = ENEMY_ARCHETYPES.find(e => e.id === selectedEnemyId) || ENEMY_ARCHETYPES[0];

  return (
    <div className="space-y-6">
      {/* Top Banner */}
      <div className="glass-panel p-6 rounded-2xl flex flex-wrap items-center justify-between gap-4 border-l-4 border-l-amber-500">
        <div>
          <h2 className="text-2xl font-bold tracking-tight text-white flex items-center gap-2">
            <Target className="text-amber-400 w-6 h-6" />
            Enemy AI Ecosystem & Role Architect
          </h2>
          <p className="text-slate-400 text-sm mt-1">
            Inspect the 5 data-driven enemy archetypes, their perception parameters (vision cone, hearing, proximity), and Utility AI decision curves.
          </p>
        </div>
        <div className="flex items-center gap-2 bg-slate-900/90 border border-slate-700 px-3 py-1.5 rounded-xl text-xs text-slate-300 font-mono">
          <Activity className="w-4 h-4 text-emerald-400" />
          <span>5 Active Archetypes</span>
        </div>
      </div>

      {/* Main Grid: Selector on Left, Details on Right */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        
        {/* Left Column: Archetype List */}
        <div className="lg:col-span-4 space-y-2">
          {ENEMY_ARCHETYPES.map((enemy) => {
            const isSelected = enemy.id === selectedEnemyId;
            return (
              <button
                key={enemy.id}
                onClick={() => setSelectedEnemyId(enemy.id)}
                className={`w-full p-4 rounded-xl text-left border transition flex items-center justify-between ${
                  isSelected
                    ? "border-amber-400/80 bg-amber-950/20 text-white shadow-lg"
                    : "border-slate-800 bg-slate-900/40 text-slate-400 hover:border-slate-700 hover:text-slate-200"
                }`}
              >
                <div>
                  <div className="flex items-center gap-2">
                    <span className="font-bold text-sm text-white">{enemy.name}</span>
                    <span className={`text-[10px] font-mono px-2 py-0.5 rounded-full border ${enemy.badgeColor}`}>
                      {enemy.role.split('/')[0].trim()}
                    </span>
                  </div>
                  <div className="text-xs text-slate-400 mt-1">
                    HP: {enemy.health} | Poise: {enemy.poise} | Vision: {enemy.visionRange}px
                  </div>
                </div>
                <ChevronRight className={`w-4 h-4 transition ${isSelected ? "text-amber-400 translate-x-1" : "text-slate-600"}`} />
              </button>
            );
          })}
        </div>

        {/* Right Column: Detailed Perception & Utility AI Engine */}
        <div className="lg:col-span-8 space-y-6">
          
          {/* Overview Card */}
          <div className="glass-panel p-6 rounded-2xl space-y-4">
            <div className="flex flex-wrap items-center justify-between gap-2 border-b border-slate-800 pb-4">
              <div>
                <h3 className="text-xl font-bold text-white flex items-center gap-2">
                  {currentEnemy.name}
                  <span className={`text-xs font-mono px-2.5 py-0.5 rounded-full border ${currentEnemy.badgeColor}`}>
                    {currentEnemy.role}
                  </span>
                </h3>
                <p className="text-xs text-slate-300 mt-1">{currentEnemy.description}</p>
              </div>
            </div>

            {/* Perception System Specs */}
            <div>
              <h4 className="text-xs font-bold uppercase tracking-wider text-slate-400 mb-3 flex items-center gap-1.5">
                <Eye className="w-4 h-4 text-cyan-400" />
                Perception Parameters
              </h4>
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                <div className="bg-slate-900/80 p-3 rounded-xl border border-slate-800">
                  <span className="text-[10px] text-slate-500 uppercase tracking-wider">Vision Cone</span>
                  <div className="font-mono text-base font-bold text-cyan-400 mt-0.5">{currentEnemy.visionRange}px</div>
                  <span className="text-[10px] text-slate-400">Angle: {currentEnemy.visionFov}° FOV</span>
                </div>
                <div className="bg-slate-900/80 p-3 rounded-xl border border-slate-800">
                  <span className="text-[10px] text-slate-500 uppercase tracking-wider">Hearing Radius</span>
                  <div className="font-mono text-base font-bold text-amber-400 mt-0.5">{currentEnemy.hearingRadius}px</div>
                  <span className="text-[10px] text-slate-400">Acoustic detection</span>
                </div>
                <div className="bg-slate-900/80 p-3 rounded-xl border border-slate-800">
                  <span className="text-[10px] text-slate-500 uppercase tracking-wider">Proximity Circle</span>
                  <div className="font-mono text-base font-bold text-emerald-400 mt-0.5">{currentEnemy.proximityRadius}px</div>
                  <span className="text-[10px] text-slate-400">360° blind-spot check</span>
                </div>
                <div className="bg-slate-900/80 p-3 rounded-xl border border-slate-800">
                  <span className="text-[10px] text-slate-500 uppercase tracking-wider">Max Poise</span>
                  <div className="font-mono text-base font-bold text-purple-400 mt-0.5">{currentEnemy.poise} pts</div>
                  <span className="text-[10px] text-slate-400">Stagger threshold</span>
                </div>
              </div>
            </div>

            {/* Utility AI Actions & Scoring */}
            <div className="pt-2">
              <h4 className="text-xs font-bold uppercase tracking-wider text-slate-400 mb-3 flex items-center gap-1.5">
                <Zap className="w-4 h-4 text-amber-400" />
                Data-Driven Utility AI Actions
              </h4>
              <div className="space-y-2.5">
                {currentEnemy.utilityActions.map((action, idx) => (
                  <div
                    key={idx}
                    className="bg-slate-900/70 p-3.5 rounded-xl border border-slate-800 flex flex-wrap items-center justify-between gap-3"
                  >
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-bold text-sm text-white">{action.name}</span>
                        <span className="text-[11px] font-mono px-2 py-0.5 rounded bg-slate-800 text-amber-300 font-semibold">
                          Weight: x{action.weight}
                        </span>
                      </div>
                      <div className="text-xs text-slate-400 mt-0.5">
                        <span className="text-slate-300">Trigger:</span> {action.trigger}
                      </div>
                    </div>
                    <div className="text-[11px] font-mono text-emerald-400 bg-emerald-950/40 border border-emerald-800/40 px-2.5 py-1 rounded-lg">
                      {action.curve}
                    </div>
                  </div>
                ))}
              </div>
            </div>

          </div>

        </div>

      </div>
    </div>
  );
}
