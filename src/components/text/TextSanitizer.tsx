import React, { useState, useRef } from 'react';
import { 
  Copy, 
  Check, 
  Download, 
  Trash2, 
  ClipboardPaste, 
  ArrowRightLeft, 
  KeyRound, 
  Plus,
  AlignLeft,
  Sparkles
} from 'lucide-react';
import type { DetectionRule, MaskingStrategy, ScrubResult } from '../../types';
import { SplitPane } from '../common/SplitPane';

interface TextSanitizerProps {
  rawText: string;
  onChangeRawText: (text: string) => void;
  scrubResult: ScrubResult;
  strategy: MaskingStrategy;
  onChangeStrategy: (strategy: MaskingStrategy) => void;
  onOpenVault: () => void;
  rules: DetectionRule[];
  onAddRuntimeRule?: (pattern: string, template: string, name?: string) => void;
}

export const TextSanitizer: React.FC<TextSanitizerProps> = ({
  rawText,
  onChangeRawText,
  scrubResult,
  strategy,
  onChangeStrategy,
  onOpenVault,
  onAddRuntimeRule
}) => {
  // Requirement: Default MUST be Plain text selection ('clean')
  const [viewMode, setViewMode] = useState<'clean' | 'diff'>('clean');
  const [copied, setCopied] = useState(false);
  const [syncScroll] = useState(true);
  const [selectedText, setSelectedText] = useState('');

  const leftEditorRef = useRef<HTMLTextAreaElement>(null);
  const rightViewerRef = useRef<HTMLDivElement>(null);

  const handleLeftScroll = () => {
    if (!syncScroll || !leftEditorRef.current || !rightViewerRef.current) return;
    const percentage = leftEditorRef.current.scrollTop / (leftEditorRef.current.scrollHeight - leftEditorRef.current.clientHeight || 1);
    rightViewerRef.current.scrollTop = percentage * (rightViewerRef.current.scrollHeight - rightViewerRef.current.clientHeight);
  };

  const handleRightScroll = () => {
    if (!syncScroll || !leftEditorRef.current || !rightViewerRef.current) return;
    const percentage = rightViewerRef.current.scrollTop / (rightViewerRef.current.scrollHeight - rightViewerRef.current.clientHeight || 1);
    leftEditorRef.current.scrollTop = percentage * (leftEditorRef.current.scrollHeight - leftEditorRef.current.clientHeight);
  };

  const handleSelectText = () => {
    if (!leftEditorRef.current) return;
    const { selectionStart, selectionEnd } = leftEditorRef.current;
    if (selectionStart !== selectionEnd) {
      const selected = rawText.substring(selectionStart, selectionEnd).trim();
      if (selected.length > 1 && selected.length < 100) {
        setSelectedText(selected);
        return;
      }
    }
    setSelectedText('');
  };

  const handleMaskSelectedText = (matchType: 'exact' | 'pattern') => {
    if (!selectedText || !onAddRuntimeRule) return;

    const escaped = selectedText.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&');

    if (matchType === 'exact') {
      onAddRuntimeRule(escaped, '[REDACTED_CUSTOM_{INDEX}]', 'Exact: ' + selectedText.slice(0, 15));
    } else {
      let inferred = escaped;
      if (/^[A-Z]{2,4}-[0-9]{3,6}$/.test(selectedText)) {
        const parts = selectedText.split('-');
        inferred = '\\b' + parts[0] + '-[0-9]{3,6}\\b';
      } else if (/^[a-zA-Z0-9-]+\.(?:internal|corp|local|priv)$/.test(selectedText)) {
        inferred = '\\b[a-zA-Z0-9-]+\\.(?:internal|corp|local|priv)\\b';
      } else {
        inferred = '\\b' + escaped + '\\b';
      }
      onAddRuntimeRule(inferred, '[CUSTOM_PATTERN_{INDEX}]', 'Pattern: ' + selectedText.slice(0, 15));
    }
    setSelectedText('');
  };

  const handleCopy = () => {
    if (!scrubResult.sanitizedText) return;
    navigator.clipboard.writeText(scrubResult.sanitizedText);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleDownload = () => {
    if (!scrubResult.sanitizedText) return;
    const blob = new Blob([scrubResult.sanitizedText], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `filtr_sanitized_${Date.now()}.txt`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const handlePaste = async () => {
    try {
      const text = await navigator.clipboard.readText();
      onChangeRawText(text);
    } catch {}
  };

  const lineCount = rawText ? rawText.split('\n').length : 1;
  const wordCount = rawText ? rawText.trim().split(/\s+/).filter(Boolean).length : 0;
  const byteCount = new TextEncoder().encode(rawText).length;

  const getDiffBadgeStyle = (category?: string) => {
    switch (category) {
      case 'cloud':
        return 'bg-rose-50 text-rose-700 border-rose-200 hover:bg-rose-100 hover:border-rose-300';
      case 'credentials':
        return 'bg-amber-50 text-amber-800 border-amber-200 hover:bg-amber-100 hover:border-amber-300';
      case 'network':
        return 'bg-sky-50 text-sky-700 border-sky-200 hover:bg-sky-100 hover:border-sky-300';
      case 'pii':
        return 'bg-blue-50 text-blue-700 border-blue-200 hover:bg-blue-100 hover:border-blue-300';
      case 'phi':
        return 'bg-teal-50 text-teal-700 border-teal-200 hover:bg-teal-100 hover:border-teal-300';
      case 'financial':
        return 'bg-emerald-50 text-emerald-700 border-emerald-200 hover:bg-emerald-100 hover:border-emerald-300';
      case 'custom':
        return 'bg-purple-50 text-purple-700 border-purple-200 hover:bg-purple-100 hover:border-purple-300';
      default:
        return 'bg-indigo-50 text-indigo-700 border-indigo-200 hover:bg-indigo-100 hover:border-indigo-300';
    }
  };

  const leftPane = (
    <div className="flex flex-col h-full border-r bg-white border-slate-200">
      <div className="h-11 px-3.5 border-b bg-slate-50/90 border-slate-200 text-slate-700 flex items-center justify-between text-xs shrink-0">
        <div className="flex items-center gap-2 min-w-0">
          <span className="font-bold tracking-wide flex items-center gap-1.5 text-slate-800 whitespace-nowrap">
            <span className="w-2 h-2 rounded-full bg-indigo-600"></span>
            RAW INPUT
          </span>
          <span className="text-[11px] text-slate-500 font-mono truncate">
            ({lineCount} lines • {wordCount} words)
          </span>
        </div>

        <div className="flex items-center gap-1.5 shrink-0">
          <button
            onClick={handlePaste}
            className="h-7 px-2.5 rounded-lg border bg-white hover:bg-slate-100 border-slate-300 text-slate-700 transition-colors flex items-center gap-1.5 text-xs shadow-xs cursor-pointer"
            title="Paste from Clipboard"
          >
            <ClipboardPaste className="w-3.5 h-3.5" />
            <span className="hidden sm:inline font-medium">Paste</span>
          </button>

          <button
            onClick={() => onChangeRawText('')}
            disabled={!rawText}
            className="h-7 w-7 flex items-center justify-center rounded-lg text-slate-400 hover:text-rose-500 hover:bg-rose-50 transition-colors disabled:opacity-30 cursor-pointer"
            title="Clear Raw Text"
          >
            <Trash2 className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      {selectedText && (
        <div className="px-4 py-1.5 border-b bg-indigo-50 border-indigo-200 text-indigo-900 flex items-center justify-between text-xs animate-in slide-in-from-top-1 duration-150 shrink-0">
          <div className="flex items-center gap-2 truncate max-w-md">
            <span className="font-semibold text-[11px] uppercase">Selection:</span>
            <code className="font-mono text-[11px] px-1.5 py-0.2 rounded bg-white/90 border border-indigo-200 truncate">
              {selectedText}
            </code>
          </div>

          <div className="flex items-center gap-2 shrink-0">
            <button
              onClick={() => handleMaskSelectedText('exact')}
              className="flex items-center gap-1 px-2.5 py-0.5 rounded-md bg-indigo-600 hover:bg-indigo-500 text-white font-semibold text-[11px] transition-colors shadow-xs cursor-pointer"
            >
              <Plus className="w-3 h-3" />
              <span>Mask Literal</span>
            </button>
            <button
              onClick={() => handleMaskSelectedText('pattern')}
              className="flex items-center gap-1 px-2.5 py-0.5 rounded-md border bg-white hover:bg-slate-100 border-indigo-300 text-indigo-800 font-semibold text-[11px] transition-colors cursor-pointer"
            >
              <span>Mask as Word/Pattern</span>
            </button>
          </div>
        </div>
      )}

      <div className="flex-1 relative overflow-hidden flex">
        <textarea
          ref={leftEditorRef}
          value={rawText}
          onChange={(e) => onChangeRawText(e.target.value)}
          onSelect={handleSelectText}
          onScroll={handleLeftScroll}
          placeholder="Paste raw application logs, cURL requests, JSON payloads, or stack traces here..."
          className="w-full h-full p-4 font-mono text-xs leading-relaxed resize-none focus:outline-none placeholder-slate-400 bg-white text-slate-800 selection:bg-indigo-100"
          spellCheck={false}
        />
      </div>
    </div>
  );

  const rightPane = (
    <div className="flex flex-col h-full bg-slate-50/60 min-w-0">
      {/* Sanitized Output Header — Fully Responsive & Never Clips Download/Vault Buttons */}
      <div className="h-11 px-3 border-b bg-slate-50/90 border-slate-200 text-slate-700 flex items-center justify-between text-xs shrink-0 gap-2 overflow-x-auto no-scrollbar">
        {/* Left Side: Badge + Sleek Segmented Control */}
        <div className="flex items-center gap-2 shrink-0">
          <span className="font-bold text-emerald-600 tracking-wide flex items-center gap-1 text-xs whitespace-nowrap">
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse shrink-0"></span>
            SANITIZED
          </span>

          <div className="h-4 w-px bg-slate-300 mx-0.5 shrink-0" />

          {/* Sleek Enterprise Segmented Control with Icons */}
          <div className="inline-flex items-center p-0.5 rounded-lg border bg-slate-200/70 border-slate-300/80 shadow-xs shrink-0">
            <button
              onClick={() => setViewMode('clean')}
              className={`h-6 px-2.5 rounded-md text-[11px] transition-all flex items-center gap-1.5 cursor-pointer ${
                viewMode === 'clean'
                  ? 'bg-white text-indigo-600 font-semibold shadow-xs border border-slate-200/80'
                  : 'text-slate-600 hover:text-slate-900 font-medium'
              }`}
              title="View clean sanitized plain text"
            >
              <AlignLeft className="w-3 h-3" />
              <span>Plain Text</span>
            </button>
            <button
              onClick={() => setViewMode('diff')}
              className={`h-6 px-2.5 rounded-md text-[11px] transition-all flex items-center gap-1.5 cursor-pointer ${
                viewMode === 'diff'
                  ? 'bg-white text-indigo-600 font-semibold shadow-xs border border-slate-200/80'
                  : 'text-slate-600 hover:text-slate-900 font-medium'
              }`}
              title="Highlight scrubbed sensitive tokens by category"
            >
              <Sparkles className="w-3 h-3 text-amber-500" />
              <span>Diff Highlights</span>
            </button>
          </div>
        </div>

        {/* Right Side: Format Selector + Action Buttons (All shrink-0 guaranteed) */}
        <div className="flex items-center gap-1.5 shrink-0">
          {/* Format Dropdown with compact clean labels */}
          <div className="flex items-center gap-1 shrink-0">
            <span className="text-slate-500 text-[11px] font-medium hidden lg:inline">Format:</span>
            <select
              value={strategy}
              onChange={(e) => onChangeStrategy(e.target.value as MaskingStrategy)}
              className="h-7 border bg-white border-slate-300 text-slate-700 hover:bg-slate-50 text-xs px-2 rounded-lg focus:outline-none focus:ring-1 focus:ring-indigo-500 cursor-pointer shadow-xs"
              title="Select Masking Token Format"
            >
              <option value="consistent_token">Consistent [TAG]</option>
              <option value="static_redact">Static [REDACTED]</option>
              <option value="hash">Salted Hash</option>
              <option value="partial">Partial Mask</option>
            </select>
          </div>

          <div className="h-4 w-px bg-slate-300 mx-0.5 shrink-0" />

          {/* Copy Button */}
          <button
            onClick={handleCopy}
            disabled={!scrubResult.sanitizedText}
            className={`h-7 flex items-center gap-1 px-2.5 rounded-lg text-xs font-semibold transition-all shadow-xs shrink-0 cursor-pointer ${
              copied
                ? 'bg-emerald-600 text-white'
                : 'bg-indigo-600 hover:bg-indigo-500 text-white disabled:opacity-40 disabled:hover:bg-indigo-600'
            }`}
            title="Copy Cleaned Data to Clipboard"
          >
            {copied ? <Check className="w-3.5 h-3.5" /> : <Copy className="w-3.5 h-3.5" />}
            <span className="text-[11px]">{copied ? 'Copied' : 'Copy'}</span>
          </button>

          {/* Download Button (shrink-0 ensures it never disappears) */}
          <button
            onClick={handleDownload}
            disabled={!scrubResult.sanitizedText}
            className="h-7 w-7 flex items-center justify-center rounded-lg border bg-white hover:bg-slate-100 border-slate-300 text-slate-700 transition-colors disabled:opacity-40 shadow-xs shrink-0 cursor-pointer"
            title="Download Sanitized .txt"
          >
            <Download className="w-3.5 h-3.5" />
          </button>

          {/* Field Mapping Vault Button (shrink-0 ensures it never disappears) */}
          <button
            onClick={onOpenVault}
            className="h-7 px-2 flex items-center gap-1 rounded-lg border bg-amber-50 hover:bg-amber-100 border-amber-300 text-amber-800 transition-colors shadow-xs shrink-0 cursor-pointer"
            title="View Field Mapping Vault (Token Correlation Table)"
          >
            <KeyRound className="w-3.5 h-3.5 text-amber-600" />
            <span className="text-[11px] font-semibold hidden md:inline">Vault</span>
            {scrubResult.mappings.length > 0 && (
              <span className="px-1.5 py-0.2 rounded-full bg-amber-200/80 text-amber-900 font-mono text-[10px] font-bold">
                {scrubResult.mappings.length}
              </span>
            )}
          </button>
        </div>
      </div>

      {/* Diff Mode Context Banner */}
      {viewMode === 'diff' && rawText && (
        <div className="px-4 py-1.5 bg-indigo-50/70 border-b border-indigo-100 flex items-center justify-between text-[11px] text-indigo-900 shrink-0">
          <div className="flex items-center gap-1.5">
            <Sparkles className="w-3.5 h-3.5 text-indigo-600" />
            <span className="font-medium">Diff Highlights Active:</span>
            <span className="text-slate-600">Sensitive tokens color-coded by detection rule category.</span>
          </div>
          <span className="font-semibold text-indigo-700 font-mono">
            {scrubResult.stats.totalRedacted} redacted
          </span>
        </div>
      )}

      {/* Output Viewer Body */}
      <div 
        ref={rightViewerRef}
        onScroll={handleRightScroll}
        className="flex-1 relative overflow-y-auto p-4 font-mono text-xs leading-relaxed bg-white text-slate-800"
      >
        {!rawText ? (
          <div className="h-full flex flex-col items-center justify-center text-slate-400 select-none">
            <ArrowRightLeft className="w-8 h-8 text-slate-400 mb-2" />
            <p className="font-sans text-sm font-medium text-slate-600">Waiting for Raw Input</p>
            <p className="font-sans text-xs text-slate-400 mt-1">
              Type or paste data on the left. Sanitized text appears in real time here.
            </p>
          </div>
        ) : viewMode === 'clean' ? (
          <pre className="whitespace-pre-wrap font-mono text-xs leading-relaxed selection:bg-emerald-100">
            {scrubResult.sanitizedText}
          </pre>
        ) : (
          <div className="whitespace-pre-wrap font-mono text-xs leading-relaxed select-text">
            {scrubResult.diffSegments.map((seg, idx) => {
              if (seg.type === 'plain') {
                return <span key={idx}>{seg.text}</span>;
              }

              return (
                <span
                  key={idx}
                  className={`inline-flex items-center px-1.5 py-0.5 mx-0.5 rounded-md border text-[11px] font-mono font-semibold shadow-xs transition-all hover:scale-105 cursor-pointer ${getDiffBadgeStyle(
                    seg.category
                  )}`}
                  title={`Rule: ${seg.ruleName || 'Detector'}\nCategory: ${seg.category}\nClick to inspect in Vault`}
                  onClick={onOpenVault}
                >
                  {seg.text}
                </span>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );

  return (
    <div className="flex-1 w-full h-full overflow-hidden">
      <SplitPane left={leftPane} right={rightPane} initialSplit={48} />
    </div>
  );
};
