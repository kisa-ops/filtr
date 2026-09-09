import React from 'react';
import type { RedactionStats } from '../../types';
import { Shield, Key, Users, Globe, Zap, Cpu } from 'lucide-react';

interface StatsBarProps {
  stats: RedactionStats;
  isLight?: boolean;
}

export const StatsBar: React.FC<StatsBarProps> = ({ stats, isLight = true }) => {
  return (
    <div className={`border-b px-6 py-1.5 flex flex-wrap items-center justify-between gap-4 text-xs font-mono transition-colors ${
      isLight 
        ? 'bg-white border-slate-200 text-slate-700 shadow-sm' 
        : 'bg-slate-950/60 border-slate-800/80 text-slate-300'
    }`}>
      <div className="flex items-center gap-5 flex-wrap">
        {/* Total Redactions */}
        <div className="flex items-center gap-2">
          <Shield className="w-3.5 h-3.5 text-indigo-600 dark:text-cyan-400" />
          <span className="text-slate-500 font-sans">Total Scrubbed:</span>
          <span className={`font-bold px-2 py-0.5 rounded border ${
            isLight ? 'bg-indigo-50 text-indigo-800 border-indigo-200' : 'bg-slate-800 text-white border-slate-700'
          }`}>
            {stats.totalRedacted} items
          </span>
        </div>

        {/* Cloud Secrets */}
        <div className="flex items-center gap-1.5">
          <Key className="w-3.5 h-3.5 text-rose-500" />
          <span className="text-slate-500 font-sans">Secrets:</span>
          <span className="font-semibold text-rose-600 dark:text-rose-400">
            {stats.byCategory.cloud + stats.byCategory.credentials}
          </span>
        </div>

        {/* Network / IPs */}
        <div className="flex items-center gap-1.5">
          <Globe className="w-3.5 h-3.5 text-sky-500" />
          <span className="text-slate-500 font-sans">Network / IPs:</span>
          <span className="font-semibold text-sky-600 dark:text-cyan-400">{stats.byCategory.network}</span>
        </div>

        {/* PII */}
        <div className="flex items-center gap-1.5">
          <Users className="w-3.5 h-3.5 text-amber-500" />
          <span className="text-slate-500 font-sans">PII Leaks:</span>
          <span className="font-semibold text-amber-600 dark:text-amber-400">{stats.byCategory.pii}</span>
        </div>

        {/* Custom Rules */}
        <div className="flex items-center gap-1.5">
          <Cpu className="w-3.5 h-3.5 text-purple-500" />
          <span className="text-slate-500 font-sans">Custom Rules:</span>
          <span className="font-semibold text-purple-600 dark:text-purple-400">{stats.byCategory.custom || 0}</span>
        </div>
      </div>

      <div className="flex items-center gap-4 text-slate-500 text-[11px]">
        {/* Processing Time */}
        <div className="flex items-center gap-1.5">
          <Zap className="w-3 h-3 text-emerald-500" />
          <span className="font-sans">Latency:</span>
          <span className="text-emerald-600 dark:text-emerald-400 font-semibold">{stats.processingTimeMs}ms</span>
        </div>

        {/* Zero Telemetry Verification */}
        <div className={`flex items-center gap-1.5 px-2 py-0.5 rounded border ${
          isLight
            ? 'bg-emerald-50 border-emerald-200 text-emerald-800'
            : 'bg-emerald-950/40 border-emerald-900/50 text-emerald-300'
        }`}>
          <span className="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
          <span>Zero Server Uploads • 100% In-Browser</span>
        </div>
      </div>
    </div>
  );
};
