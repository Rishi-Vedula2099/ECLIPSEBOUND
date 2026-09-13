'use client';

import React, { useState } from 'react';
import {
  CoreAttributes,
  WEAPON_CLASSES,
  SKILL_BRANCHES,
  ARTIFACT_SLOTS,
  ARTIFACT_SETS,
  calculateDerivedStats,
  ATTRIBUTE_DESCRIPTIONS
} from '@/lib/rpg_constants';
import { Shield, Zap, Flame, Sparkles, Sword, Award, RefreshCw, Layers } from 'lucide-react';

export default function BuildLabSimulator() {
  const [level, setLevel] = useState<number>(30);
  const [stats, setStats] = useState<CoreAttributes>({
    vit: 25,
    str: 30,
    arc: 15,
    def: 20,
    agi: 18,
    crt: 22,
    res: 12,
    lck: 14
  });

  const [selectedWeaponIdx, setSelectedWeaponIdx] = useState<number>(0);
  const [weaponUpgrade, setWeaponUpgrade] = useState<number>(5);
  const [selectedSet, setSelectedSet] = useState<string>("verdant");
  const [equippedCount, setEquippedCount] = useState<number>(8);
  const [selectedBranch, setSelectedBranch] = useState<string>("WARDEN");

  const derived = calculateDerivedStats(stats, selectedWeaponIdx, weaponUpgrade);
  const currentWeapon = WEAPON_CLASSES[selectedWeaponIdx];
  const currentSet = ARTIFACT_SETS.find(s => s.id === selectedSet) || ARTIFACT_SETS[0];

  const handleStatChange = (key: keyof CoreAttributes, val: number) => {
    setStats(prev => ({ ...prev, [key]: Math.max(10, Math.min(99, val)) }));
  };

  const handleReset = () => {
    setStats({ vit: 10, str: 10, arc: 10, def: 10, agi: 10, crt: 10, res: 10, lck: 10 });
    setLevel(1);
    setWeaponUpgrade(0);
  };

  return (
    <div className="space-y-6">
      {/* Top Banner */}
      <div className="glass-panel p-6 rounded-2xl flex flex-wrap items-center justify-between gap-4 border-l-4 border-l-emerald-500">
        <div>
          <h2 className="text-2xl font-bold tracking-tight text-white flex items-center gap-2">
            <Sword className="text-emerald-400 w-6 h-6" />
            Build Lab Simulator — Character Crafting
          </h2>
          <p className="text-slate-400 text-sm mt-1">
            Simulate 8 core attributes, 7 weapon classes, 8-piece artifact set resonance, and derived combat calculations.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <div className="bg-slate-900/80 px-4 py-2 rounded-xl border border-slate-700">
            <span className="text-xs uppercase tracking-wider text-slate-400">Character Level</span>
            <div className="flex items-center gap-2">
              <input
                type="range"
                min="1"
                max="50"
                value={level}
                onChange={(e) => setLevel(Number(e.target.value))}
                className="accent-emerald-500 cursor-pointer w-28"
              />
              <span className="font-mono text-lg font-bold text-emerald-400">{level} / 50</span>
            </div>
          </div>
          <button
            onClick={handleReset}
            className="flex items-center gap-1.5 px-3 py-2 text-xs font-semibold rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 transition"
          >
            <RefreshCw className="w-3.5 h-3.5" />
            Reset
          </button>
        </div>
      </div>

      {/* Main 3-Column Layout */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        
        {/* Left: 8 Core Attributes */}
        <div className="lg:col-span-4 glass-panel p-5 rounded-2xl space-y-4">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-bold uppercase tracking-wider text-slate-300 flex items-center gap-2">
              <Shield className="w-4 h-4 text-cyan-400" />
              8 Core Attributes
            </h3>
            <span className="text-xs text-slate-400 font-mono">Total Points: {Object.values(stats).reduce((a, b) => a + b, 0)}</span>
          </div>

          <div className="space-y-3">
            {(Object.keys(stats) as Array<keyof CoreAttributes>).map((key) => (
              <div key={key} className="bg-slate-900/60 p-3 rounded-xl border border-slate-800 hover:border-slate-700 transition">
                <div className="flex justify-between items-center mb-1">
                  <span className="font-mono text-xs font-semibold text-slate-200 uppercase">{key}</span>
                  <span className="font-mono font-bold text-emerald-400 text-sm">{stats[key]}</span>
                </div>
                <input
                  type="range"
                  min="10"
                  max="99"
                  value={stats[key]}
                  onChange={(e) => handleStatChange(key, Number(e.target.value))}
                  className="w-full accent-emerald-500 cursor-pointer h-1.5 bg-slate-800 rounded-lg"
                />
                <p className="text-[11px] text-slate-400 mt-1 truncate">{ATTRIBUTE_DESCRIPTIONS[key]}</p>
              </div>
            ))}
          </div>
        </div>

        {/* Center: Weapons & Artifact Resonance */}
        <div className="lg:col-span-5 space-y-6">
          
          {/* Weapon Selector */}
          <div className="glass-panel p-5 rounded-2xl space-y-4">
            <h3 className="text-sm font-bold uppercase tracking-wider text-slate-300 flex items-center gap-2">
              <Sword className="w-4 h-4 text-amber-400" />
              Active Weapon & Mastery
            </h3>

            <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
              {WEAPON_CLASSES.map((w, idx) => (
                <button
                  key={w.id}
                  onClick={() => setSelectedWeaponIdx(idx)}
                  className={`p-2.5 rounded-xl text-left border transition text-xs ${
                    selectedWeaponIdx === idx
                      ? "border-amber-400/80 bg-amber-950/20 text-white font-semibold"
                      : "border-slate-800 bg-slate-900/40 text-slate-400 hover:border-slate-700"
                  }`}
                >
                  <div className="font-bold">{w.name}</div>
                  <div className="text-[10px] text-slate-400 mt-0.5">Base: {w.baseDmg} DMG</div>
                </button>
              ))}
            </div>

            {/* Weapon Details & Upgrade */}
            <div className="bg-slate-900/80 p-4 rounded-xl border border-slate-800 space-y-2">
              <div className="flex justify-between items-center">
                <span className="text-xs font-semibold text-amber-300">Upgrade Tier (+0 to +10)</span>
                <span className="font-mono text-sm font-bold text-amber-400">+{weaponUpgrade}</span>
              </div>
              <input
                type="range"
                min="0"
                max="10"
                value={weaponUpgrade}
                onChange={(e) => setWeaponUpgrade(Number(e.target.value))}
                className="w-full accent-amber-400 cursor-pointer h-1.5 bg-slate-800 rounded-lg"
              />
              <p className="text-xs text-slate-300 italic pt-1">{currentWeapon.desc}</p>
              <div className="grid grid-cols-3 gap-2 text-[11px] font-mono text-slate-400 pt-1">
                <div>STR: x{currentWeapon.strScale}</div>
                <div>ARC: x{currentWeapon.arcScale}</div>
                <div>AGI: x{currentWeapon.agiScale}</div>
              </div>
            </div>
          </div>

          {/* 8-Piece Artifact Resonance */}
          <div className="glass-panel p-5 rounded-2xl space-y-4">
            <h3 className="text-sm font-bold uppercase tracking-wider text-slate-300 flex items-center gap-2">
              <Layers className="w-4 h-4 text-purple-400" />
              8-Piece Artifact Resonance
            </h3>

            <div className="grid grid-cols-2 gap-2">
              {ARTIFACT_SETS.map((set) => (
                <button
                  key={set.id}
                  onClick={() => setSelectedSet(set.id)}
                  className={`p-2 rounded-xl text-left border text-xs transition ${
                    selectedSet === set.id
                      ? "border-purple-400 bg-purple-950/30 text-white font-semibold"
                      : "border-slate-800 bg-slate-900/40 text-slate-400 hover:border-slate-700"
                  }`}
                >
                  {set.name}
                </button>
              ))}
            </div>

            {/* Pieces equipped slider */}
            <div className="bg-slate-900/80 p-3 rounded-xl border border-slate-800 flex items-center justify-between">
              <span className="text-xs text-slate-300">Equipped Pieces:</span>
              <div className="flex gap-1.5">
                {[0, 2, 4, 6, 8].map((count) => (
                  <button
                    key={count}
                    onClick={() => setEquippedCount(count)}
                    className={`px-2.5 py-1 text-xs rounded-lg font-mono font-bold transition ${
                      equippedCount === count
                        ? "bg-purple-600 text-white"
                        : "bg-slate-800 text-slate-400 hover:bg-slate-700"
                    }`}
                  >
                    {count}
                  </button>
                ))}
              </div>
            </div>

            {/* Set Tier Milestones */}
            <div className="space-y-1.5 text-xs">
              <div className={`p-2 rounded-lg border ${equippedCount >= 2 ? "border-emerald-500/40 bg-emerald-950/20 text-emerald-200" : "border-slate-800/40 text-slate-500"}`}>
                <span className="font-bold">2-Piece:</span> {currentSet.bonus2}
              </div>
              <div className={`p-2 rounded-lg border ${equippedCount >= 4 ? "border-emerald-500/40 bg-emerald-950/20 text-emerald-200" : "border-slate-800/40 text-slate-500"}`}>
                <span className="font-bold">4-Piece:</span> {currentSet.bonus4}
              </div>
              <div className={`p-2 rounded-lg border ${equippedCount >= 6 ? "border-emerald-500/40 bg-emerald-950/20 text-emerald-200" : "border-slate-800/40 text-slate-500"}`}>
                <span className="font-bold">6-Piece:</span> {currentSet.bonus6}
              </div>
              <div className={`p-2 rounded-lg border ${equippedCount >= 8 ? "border-purple-500/50 bg-purple-950/30 text-purple-200 glow-void" : "border-slate-800/40 text-slate-500"}`}>
                <span className="font-bold">8-Piece Transcendence:</span> {currentSet.bonus8}
              </div>
            </div>
          </div>
        </div>

        {/* Right: Derived Combat Output Calculations */}
        <div className="lg:col-span-3 glass-panel p-5 rounded-2xl space-y-4">
          <h3 className="text-sm font-bold uppercase tracking-wider text-slate-300 flex items-center gap-2">
            <Sparkles className="w-4 h-4 text-emerald-400" />
            Combat Calculations
          </h3>

          <div className="space-y-3">
            <div className="bg-slate-900/80 p-3.5 rounded-xl border border-slate-800">
              <span className="text-[11px] text-slate-400 uppercase tracking-wider">Attack Rating</span>
              <div className="text-2xl font-mono font-bold text-amber-400 mt-0.5">{derived.physicalDmg}</div>
              <span className="text-[10px] text-slate-400">Weapon + Stat scaling</span>
            </div>

            <div className="bg-slate-900/80 p-3.5 rounded-xl border border-slate-800">
              <span className="text-[11px] text-slate-400 uppercase tracking-wider">Maximum Health</span>
              <div className="text-2xl font-mono font-bold text-emerald-400 mt-0.5">{derived.maxHealth}</div>
              <span className="text-[10px] text-slate-400">VIT scaled (Base 100)</span>
            </div>

            <div className="bg-slate-900/80 p-3.5 rounded-xl border border-slate-800">
              <span className="text-[11px] text-slate-400 uppercase tracking-wider">Damage Reduction</span>
              <div className="text-2xl font-mono font-bold text-cyan-400 mt-0.5">{derived.dmgReductionPct}%</div>
              <span className="text-[10px] text-slate-400">Armor soft-cap curve</span>
            </div>

            <div className="bg-slate-900/80 p-3.5 rounded-xl border border-slate-800">
              <span className="text-[11px] text-slate-400 uppercase tracking-wider">Effective HP (EHP)</span>
              <div className="text-2xl font-mono font-bold text-rose-400 mt-0.5">{derived.effectiveHp}</div>
              <span className="text-[10px] text-slate-400">True survivability pool</span>
            </div>

            <div className="bg-slate-900/80 p-3.5 rounded-xl border border-slate-800">
              <span className="text-[11px] text-slate-400 uppercase tracking-wider">Crit Chance & Mult</span>
              <div className="text-xl font-mono font-bold text-purple-400 mt-0.5">{derived.critRatePct}% @ x{derived.critMultiplier}</div>
              <span className="text-[10px] text-slate-400">CRT attribute derived</span>
            </div>

            <div className="bg-slate-900/80 p-3.5 rounded-xl border border-slate-800">
              <span className="text-[11px] text-slate-400 uppercase tracking-wider">Movement Speed</span>
              <div className="text-xl font-mono font-bold text-slate-200 mt-0.5">{derived.moveSpeedPct}%</div>
              <span className="text-[10px] text-slate-400">AGI agility multiplier</span>
            </div>
          </div>
        </div>

      </div>
    </div>
  );
}
