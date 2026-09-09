import React, { useState } from 'react';
import type {  FieldMapping, RuleCategory  } from '../../types';
import { 
  X, 
  Eye, 
  EyeOff, 
  Copy, 
  Check, 
  Download, 
  Search, 
  ShieldAlert, 
  KeyRound, 
  Trash2, 
  FileSpreadsheet, 
  FileCode 
} from 'lucide-react';

interface FieldMappingVaultProps {
  isOpen: boolean;
  onClose: () => void;
  mappings: FieldMapping[];
  onClearVault: () => void;
}

export const FieldMappingVault: React.FC<FieldMappingVaultProps> = ({
  isOpen,
  onClose,
  mappings,
  onClearVault
}) => {
  const [revealed, setRevealed] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string>('all');
  const [copiedId, setCopiedId] = useState<string | null>(null);

  if (!isOpen) return null;

  const filtered = mappings.filter(m => {
    const matchesCategory = selectedCategory === 'all' || m.category === selectedCategory;
    const matchesSearch = 
      m.maskedValue.toLowerCase().includes(searchTerm.toLowerCase()) ||
      m.originalValue.toLowerCase().includes(searchTerm.toLowerCase()) ||
      m.ruleName.toLowerCase().includes(searchTerm.toLowerCase());
    return matchesCategory && matchesSearch;
  });

  const handleCopy = (text: string, id: string) => {
    navigator.clipboard.writeText(text);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 1800);
  };

  const handleExportJSON = () => {
    const data = JSON.stringify(mappings, null, 2);
    const blob = new Blob([data], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `filtr_field_mapping_${Date.now()}.json`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const handleExportCSV = () => {
    const headers = ['Category', 'Rule Name', 'Masked Token', 'Original Value', 'Occurrences'];
    const rows = mappings.map(m => [
      `"${m.category}"`,
      `"${m.ruleName.replace(/"/g, '""')}"`,
      `"${m.maskedValue}"`,
      `"${m.originalValue.replace(/"/g, '""')}"`,
      m.occurrences
    ]);
    const csv = [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `filtr_field_mapping_${Date.now()}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const getCategoryBadgeClass = (category: RuleCategory) => {
    switch (category) {
      case 'cloud':
        return 'bg-rose-950/80 text-rose-400 border-rose-800/60';
      case 'credentials':
        return 'bg-amber-950/80 text-amber-400 border-amber-800/60';
      case 'network':
        return 'bg-cyan-950/80 text-cyan-400 border-cyan-800/60';
      case 'pii':
        return 'bg-blue-950/80 text-blue-400 border-blue-800/60';
      case 'custom':
        return 'bg-purple-950/80 text-purple-400 border-purple-800/60';
      default:
        return 'bg-slate-100 text-slate-700 border-slate-300';
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 backdrop-blur-sm p-4 animate-in fade-in duration-200">
      <div className="bg-white border border-slate-200 rounded-2xl w-full max-w-5xl max-h-[85vh] flex flex-col shadow-2xl overflow-hidden">
        {/* Header */}
        <div className="px-6 py-4 border-b border-slate-200 flex items-center justify-between bg-slate-50">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-xl bg-amber-500/10 border border-amber-500/20 text-amber-400">
              <KeyRound className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h2 className="text-base font-bold text-slate-900 tracking-wide">De-Anonymization Vault & Field Mapping</h2>
                <span className="px-2 py-0.5 rounded-full bg-slate-100 border border-slate-300 text-slate-700 text-xs font-mono">
                  {mappings.length} unique tokens
                </span>
              </div>
            </div>
          </div>

          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-slate-400 hover:text-slate-900 hover:bg-slate-100 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Toolbar & Filter */}
        <div className="px-6 py-3 border-b border-slate-200 bg-white/40 flex flex-wrap items-center justify-between gap-3 text-xs">
          <div className="flex items-center gap-3 flex-1 min-w-[260px]">
            {/* Search Input */}
            <div className="relative flex-1 max-w-sm">
              <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                placeholder="Search by token, rule, or raw value..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-1.5 bg-white border border-slate-200 rounded-lg text-slate-800 placeholder-slate-500 text-xs focus:outline-none focus:border-indigo-500"
              />
            </div>

            {/* Category Filter */}
            <select
              value={selectedCategory}
              onChange={(e) => setSelectedCategory(e.target.value)}
              className="bg-white border border-slate-200 px-3 py-1.5 rounded-lg text-slate-700 text-xs focus:outline-none focus:border-indigo-500 cursor-pointer"
            >
              <option value="all">All Categories</option>
              <option value="cloud">Cloud Secrets</option>
              <option value="credentials">Credentials / Passwords</option>
              <option value="network">Network & Hostnames</option>
              <option value="pii">PII (Emails, Cards, Phones)</option>
              <option value="custom">Custom Format Rules</option>
            </select>
          </div>

          {/* Action Buttons */}
          <div className="flex items-center gap-2">
            {/* Reveal / Hide Toggle */}
            <button
              onClick={() => setRevealed(!revealed)}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg border text-xs font-semibold transition-all ${
                revealed
                  ? 'bg-amber-500/10 border-amber-500/30 text-amber-300'
                  : 'bg-slate-100 border-slate-300 text-slate-700 hover:text-slate-900'
              }`}
            >
              {revealed ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
              <span>{revealed ? 'Hide Raw Secrets' : 'Reveal Raw Secrets'}</span>
            </button>

            {/* Export JSON */}
            <button
              onClick={handleExportJSON}
              disabled={mappings.length === 0}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-100 hover:bg-slate-700 border border-slate-300 text-slate-800 text-xs font-semibold transition-colors disabled:opacity-40"
              title="Download Mapping Key for Safe Offline De-Anonymization"
            >
              <FileCode className="w-3.5 h-3.5 text-indigo-400" />
              <span>Export JSON</span>
            </button>

            {/* Export CSV */}
            <button
              onClick={handleExportCSV}
              disabled={mappings.length === 0}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-100 hover:bg-slate-700 border border-slate-300 text-slate-800 text-xs font-semibold transition-colors disabled:opacity-40"
            >
              <FileSpreadsheet className="w-3.5 h-3.5 text-emerald-400" />
              <span>Export CSV</span>
            </button>

            {/* Clear Vault */}
            <button
              onClick={onClearVault}
              disabled={mappings.length === 0}
              className="p-1.5 rounded-lg text-rose-400 hover:bg-rose-950/40 hover:text-rose-300 border border-transparent hover:border-rose-800/50 transition-colors disabled:opacity-30"
              title="Clear Vault Cache"
            >
              <Trash2 className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* Table Content */}
        <div className="flex-1 overflow-y-auto p-6 font-mono text-xs">
          {mappings.length === 0 ? (
            <div className="py-16 text-center text-slate-500">
              <ShieldAlert className="w-10 h-10 mx-auto text-slate-600 mb-3" />
              <p className="text-slate-400 font-sans font-medium text-sm">No Sensitive Entities Mapped Yet</p>
              <p className="text-xs text-slate-500 font-sans mt-1">
                Paste text or upload log files. Detected PII and credentials will be assigned persistent pseudonyms here.
              </p>
            </div>
          ) : filtered.length === 0 ? (
            <div className="py-12 text-center text-slate-500">
              <p>No matches for current search filter.</p>
            </div>
          ) : (
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-slate-200 text-slate-400 text-[11px] uppercase tracking-wider font-semibold">
                  <th className="pb-3 px-3">Masked Pseudonym</th>
                  <th className="pb-3 px-3">Original Raw Value</th>
                  <th className="pb-3 px-3">Category</th>
                  <th className="pb-3 px-3">Rule Name</th>
                  <th className="pb-3 px-3 text-center">Hits</th>
                  <th className="pb-3 px-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {filtered.map((item) => (
                  <tr key={item.id} className="hover:bg-slate-50 transition-colors">
                    {/* Masked Token */}
                    <td className="py-3 px-3">
                      <span className="px-2 py-0.5 rounded bg-indigo-950/80 text-indigo-300 border border-indigo-800/60 font-bold">
                        {item.maskedValue}
                      </span>
                    </td>

                    {/* Original Value */}
                    <td className="py-3 px-3 max-w-xs truncate">
                      {revealed ? (
                        <span className="text-rose-300 font-medium select-all">{item.originalValue}</span>
                      ) : (
                        <span className="blur-sm select-none text-slate-400 hover:blur-none transition-all cursor-pointer" title="Hover to peek">
                          {item.originalValue}
                        </span>
                      )}
                    </td>

                    {/* Category */}
                    <td className="py-3 px-3">
                      <span className={`px-2 py-0.5 rounded text-[10px] font-semibold uppercase border ${getCategoryBadgeClass(item.category)}`}>
                        {item.category}
                      </span>
                    </td>

                    {/* Rule Name */}
                    <td className="py-3 px-3 text-slate-700 font-sans">
                      {item.ruleName}
                    </td>

                    {/* Occurrences */}
                    <td className="py-3 px-3 text-center">
                      <span className="px-2 py-0.5 rounded-full bg-slate-100 text-slate-700 text-[10px]">
                        {item.occurrences}x
                      </span>
                    </td>

                    {/* Actions */}
                    <td className="py-3 px-3 text-right">
                      <div className="flex items-center justify-end gap-1.5">
                        <button
                          onClick={() => handleCopy(item.maskedValue, `token_${item.id}`)}
                          className="p-1 rounded hover:bg-slate-100 text-slate-400 hover:text-slate-800 transition-colors"
                          title="Copy Masked Token"
                        >
                          {copiedId === `token_${item.id}` ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                        </button>
                        <button
                          onClick={() => handleCopy(item.originalValue, `raw_${item.id}`)}
                          className="p-1 rounded hover:bg-slate-100 text-slate-400 hover:text-slate-800 transition-colors"
                          title="Copy Raw Value"
                        >
                          {copiedId === `raw_${item.id}` ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Eye className="w-3.5 h-3.5" />}
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {/* Footer info */}
        <div className="px-6 py-3 border-t border-slate-200 bg-slate-50 flex items-center justify-between text-xs text-slate-400">
          <span className="text-[11px] text-slate-500">
            🔒 Local Memory Storage: Mappings are held in local memory and are never uploaded to any remote server.
          </span>
          <button
            onClick={onClose}
            className="px-4 py-1.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-slate-900 font-semibold text-xs transition-colors"
          >
            Done
          </button>
        </div>
      </div>
    </div>
  );
};
