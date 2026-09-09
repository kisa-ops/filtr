import React, { useState } from 'react';
import { Plus, Zap, X, HelpCircle } from 'lucide-react';
import type { DetectionRule } from '../../types';

interface RuntimePatternBarProps {
  onAddRuntimeRule: (pattern: string, template: string, name?: string) => void;
  runtimeRules: DetectionRule[];
  onRemoveRuntimeRule: (id: string) => void;
}

export const RuntimePatternBar: React.FC<RuntimePatternBarProps> = ({
  onAddRuntimeRule,
  runtimeRules,
  onRemoveRuntimeRule
}) => {
  const [pattern, setPattern] = useState('');
  const [template, setTemplate] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!pattern.trim()) return;

    let finalTemplate = template.trim();
    if (!finalTemplate) {
      finalTemplate = '[MASKED_TOKEN_{INDEX}]';
    } else if (!finalTemplate.startsWith('[')) {
      finalTemplate = `[${finalTemplate.toUpperCase()}_{INDEX}]`;
    }

    onAddRuntimeRule(pattern.trim(), finalTemplate);
    setPattern('');
    setTemplate('');
  };

  return (
    <div className="border-b bg-slate-50 border-slate-200 px-6 py-2 transition-colors">
      <div className="flex flex-wrap items-center justify-between gap-3 text-xs">
        {/* Input Form */}
        <form onSubmit={handleSubmit} className="flex items-center gap-2.5 flex-1 min-w-[340px]">
          {/* Label with Tooltip */}
          <div 
            className="flex items-center gap-1.5 font-semibold text-slate-700 group relative cursor-help select-none"
            title="Applies dynamically to all loaded text, logs, and spreadsheets"
          >
            <Zap className="w-3.5 h-3.5 text-amber-500" />
            <span className="text-[11px] uppercase tracking-wider font-bold">Runtime Pattern:</span>
            <HelpCircle className="w-3 h-3 text-slate-400 group-hover:text-indigo-600 transition-colors" />

            {/* Hover Tooltip Card */}
            <div className="absolute left-0 top-full mt-1.5 z-30 hidden group-hover:flex items-center px-2.5 py-1.5 rounded-lg bg-slate-900 text-white text-[11px] font-normal normal-case whitespace-nowrap shadow-xl border border-slate-700 pointer-events-none animate-in fade-in zoom-in-95 duration-150">
              <span>Applies dynamically to all loaded text, logs, and spreadsheets</span>
            </div>
          </div>

          <input
            type="text"
            placeholder="Regex or exact text (e.g. \bTENANT-[0-9]+\b or client_key)"
            value={pattern}
            onChange={(e) => setPattern(e.target.value)}
            className="px-3 py-1.5 text-xs font-mono rounded-lg border bg-white border-slate-300 text-slate-800 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-400 placeholder-slate-400 flex-1 max-w-sm"
          />

          <input
            type="text"
            placeholder="Token [TAG_{INDEX}]"
            value={template}
            onChange={(e) => setTemplate(e.target.value)}
            className="px-3 py-1.5 text-xs font-mono rounded-lg border bg-white border-slate-300 text-slate-800 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-400 placeholder-slate-400 w-48"
          />

          <button
            type="submit"
            disabled={!pattern.trim()}
            className="flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white font-semibold text-xs transition-colors shadow-sm disabled:opacity-40"
          >
            <Plus className="w-3.5 h-3.5" />
            <span>Apply to Active File</span>
          </button>
        </form>
      </div>

      {/* Active Runtime Rules Pills */}
      {runtimeRules.length > 0 && (
        <div className="mt-2 pt-1.5 border-t border-slate-200 flex items-center gap-2 flex-wrap">
          <span className="text-[10px] uppercase font-bold text-slate-500">Active Runtime Rules:</span>
          {runtimeRules.map(rule => (
            <span
              key={rule.id}
              className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-md text-[11px] font-mono border bg-indigo-50 text-indigo-700 border-indigo-200"
            >
              <span>{rule.name}: <strong className="font-semibold">{rule.pattern}</strong> → {rule.replacementTemplate}</span>
              <button
                type="button"
                onClick={() => onRemoveRuntimeRule(rule.id)}
                className="hover:text-rose-600 transition-colors ml-1"
                title="Remove Runtime Rule"
              >
                <X className="w-3 h-3" />
              </button>
            </span>
          ))}
        </div>
      )}
    </div>
  );
};
