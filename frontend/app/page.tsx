'use client';

import React, { useState } from 'react';
import BuildLabSimulator from '@/components/BuildLabSimulator';
import BossLabInspector from '@/components/BossLabInspector';
import EnemyEcosystemInspector from '@/components/EnemyEcosystemInspector';
import FairnessEngineInspector from '@/components/FairnessEngineInspector';
import TelemetryDashboard from '@/components/TelemetryDashboard';
import { Sword, Skull, Radio, Bug, Scale } from 'lucide-react';

export default function Home() {
  const [activeTab, setActiveTab] = useState<'build' | 'enemy' | 'boss' | 'fairness' | 'telemetry'>('build');

  return (
    <div className="min-h-screen bg-eclipse-950 text-slate-100 flex flex-col">
      {/* Top Navbar */}
      <header className="border-b border-slate-800/80 bg-slate-950/70 backdrop-blur-md sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-purple-600 via-indigo-500 to-emerald-400 flex items-center justify-center font-bold text-white shadow-lg shadow-purple-500/20">
              EB
            </div>
            <div>
              <span className="font-extrabold text-lg tracking-wider text-white">ECLIPSEBOUND</span>
              <span className="ml-2 text-xs font-mono px-2 py-0.5 rounded bg-purple-950 text-purple-300 border border-purple-800">
                LAB v0.5.0
              </span>
            </div>
          </div>

          {/* Tab Navigation */}
          <nav className="flex items-center gap-1 bg-slate-900/90 p-1 rounded-xl border border-slate-800">
            <button
              onClick={() => setActiveTab('build')}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-bold transition ${
                activeTab === 'build'
                  ? 'bg-emerald-600 text-white shadow'
                  : 'text-slate-400 hover:text-white hover:bg-slate-800'
              }`}
            >
              <Sword className="w-3.5 h-3.5" />
              Build Lab
            </button>
            <button
              onClick={() => setActiveTab('enemy')}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-bold transition ${
                activeTab === 'enemy'
                  ? 'bg-amber-600 text-white shadow'
                  : 'text-slate-400 hover:text-white hover:bg-slate-800'
              }`}
            >
              <Bug className="w-3.5 h-3.5" />
              Enemy AI
            </button>
            <button
              onClick={() => setActiveTab('boss')}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-bold transition ${
                activeTab === 'boss'
                  ? 'bg-purple-600 text-white shadow'
                  : 'text-slate-400 hover:text-white hover:bg-slate-800'
              }`}
            >
              <Skull className="w-3.5 h-3.5" />
              Boss Lab
            </button>
            <button
              onClick={() => setActiveTab('fairness')}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-bold transition ${
                activeTab === 'fairness'
                  ? 'bg-emerald-600 text-white shadow'
                  : 'text-slate-400 hover:text-white hover:bg-slate-800'
              }`}
            >
              <Scale className="w-3.5 h-3.5" />
              Fairness Engine
            </button>
            <button
              onClick={() => setActiveTab('telemetry')}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-bold transition ${
                activeTab === 'telemetry'
                  ? 'bg-cyan-600 text-white shadow'
                  : 'text-slate-400 hover:text-white hover:bg-slate-800'
              }`}
            >
              <Radio className="w-3.5 h-3.5" />
              Telemetry
            </button>
          </nav>

          <div className="flex items-center gap-3 text-xs text-slate-400 font-mono">
            <span>Godot 4.3 Engine</span>
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-400" />
            <span>FastAPI Live</span>
          </div>
        </div>
      </header>

      {/* Main Content Area */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {activeTab === 'build' && <BuildLabSimulator />}
        {activeTab === 'enemy' && <EnemyEcosystemInspector />}
        {activeTab === 'boss' && <BossLabInspector />}
        {activeTab === 'fairness' && <FairnessEngineInspector />}
        {activeTab === 'telemetry' && <TelemetryDashboard />}
      </main>

      {/* Footer */}
      <footer className="border-t border-slate-900 bg-slate-950/40 py-6 text-center text-xs text-slate-500">
        <p>ECLIPSEBOUND — Dark Pixel-Art Action RPG & AI Experimentation Sandbox. All rights reserved.</p>
      </footer>
    </div>
  );
}
