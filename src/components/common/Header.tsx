import React from 'react';
import { 
  Lock, 
  FileText, 
  Terminal, 
  Table, 
  Sliders
} from 'lucide-react';
import type { PolicyPreset, EnabledModules } from '../../types';
import { FiltrLogo } from './FiltrLogo';

interface HeaderProps {
  currentMode: 'text' | 'logs' | 'excel';
  onSelectMode: (mode: 'text' | 'logs' | 'excel') => void;
  preset: PolicyPreset;
  onSelectPreset: (preset: PolicyPreset) => void;
  mappingsCount?: number;
  onOpenVault?: () => void;
  onOpenAdmin: () => void;
  totalRedacted?: number;
  showPolicySelector?: boolean;
  enabledModules?: EnabledModules;
}

export const Header: React.FC<HeaderProps> = ({
  currentMode,
  onSelectMode,
  preset,
  onSelectPreset,
  onOpenAdmin,
  showPolicySelector = true,
  enabledModules = { text: true, logs: true, excel: true }
}) => {
  return (
    <header className="border-b bg-white border-slate-200 shadow-xs sticky top-0 z-40 px-6 py-2.5 flex flex-wrap items-center justify-between gap-4">
      {/* Brand with Unique Fancy filtr Logo */}
      <FiltrLogo size="md" showText={true} />

      {/* Mode Navigation Switcher (Filtered by Enabled Modules) */}
      <div className="flex items-center p-1 rounded-xl border bg-slate-100/90 border-slate-200 shadow-inner">
        {enabledModules.text && (
          <button
            onClick={() => onSelectMode('text')}
            className={`flex items-center gap-2 px-4 py-1.5 rounded-lg text-xs font-semibold transition-all ${
              currentMode === 'text'
                ? 'bg-indigo-600 text-white shadow-sm'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <FileText className="w-3.5 h-3.5" />
            <span>Raw Text</span>
          </button>
        )}

        {enabledModules.logs && (
          <button
            onClick={() => onSelectMode('logs')}
            className={`flex items-center gap-2 px-4 py-1.5 rounded-lg text-xs font-semibold transition-all ${
              currentMode === 'logs'
                ? 'bg-indigo-600 text-white shadow-sm'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <Terminal className="w-3.5 h-3.5" />
            <span>Log Files</span>
          </button>
        )}

        {enabledModules.excel && (
          <button
            onClick={() => onSelectMode('excel')}
            className={`flex items-center gap-2 px-4 py-1.5 rounded-lg text-xs font-semibold transition-all ${
              currentMode === 'excel'
                ? 'bg-indigo-600 text-white shadow-sm'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <Table className="w-3.5 h-3.5" />
            <span>Excel / CSV</span>
          </button>
        )}
      </div>

      {/* Policy Preset & Admin Portal */}
      <div className="flex items-center gap-2.5">
        {/* Preset Selector (Controlled by Admin Portal) */}
        {showPolicySelector && (
          <div className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl border bg-white border-slate-300 shadow-xs">
            <Sliders className="w-3.5 h-3.5 text-indigo-600" />
            <span className="text-xs text-slate-500 font-medium">Policy:</span>
            <select
              value={preset}
              onChange={(e) => onSelectPreset(e.target.value as PolicyPreset)}
              className="bg-transparent text-xs font-semibold text-slate-800 focus:outline-none cursor-pointer"
            >
              <option value="soc2" className="bg-white text-slate-900">SOC-2 Strict (All Rules)</option>
              <option value="gdpr" className="bg-white text-slate-900">GDPR (PII & Network)</option>
              <option value="hipaa" className="bg-white text-slate-900">HIPAA (Health PHI & PII)</option>
              <option value="pci" className="bg-white text-slate-900">PCI-DSS (Financial & Cards)</option>
              <option value="devops" className="bg-white text-slate-900">DevOps & SRE Logs</option>
              <option value="cloud" className="bg-white text-slate-900">Cloud Secrets Only</option>
              <option value="custom" className="bg-white text-slate-900">Custom Policy</option>
            </select>
          </div>
        )}

        {/* Admin Portal Button */}
        <button
          onClick={onOpenAdmin}
          className="flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl border bg-slate-100 hover:bg-indigo-50 border-slate-300 text-slate-700 hover:text-indigo-700 hover:border-indigo-300 text-xs font-semibold transition-all shadow-sm cursor-pointer"
          title="Admin Portal - Manage System & Custom Rules"
        >
          <Lock className="w-3.5 h-3.5 text-indigo-600" />
          <span>Admin Portal</span>
        </button>
      </div>
    </header>
  );
};
