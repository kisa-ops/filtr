import React, { useState, useMemo } from 'react';
import { Header } from './components/common/Header';
import { StatsBar } from './components/common/StatsBar';
import { RuntimePatternBar } from './components/common/RuntimePatternBar';
import { TextSanitizer } from './components/text/TextSanitizer';
import { LogFileProcessor } from './components/logs/LogFileProcessor';
import { ExcelSanitizer } from './components/excel/ExcelSanitizer';
import { FieldMappingVault } from './components/mapping/FieldMappingVault';
import { AdminPortal } from './components/admin/AdminPortal';
import { ErrorBoundary } from './components/common/ErrorBoundary';
import type { DetectionRule, MaskingStrategy, PolicyPreset, ScrubResult, AdminSettings } from './types';
import { initialRules, applyPolicyPreset } from './engine/defaultRules';
import { ConsistencyVault } from './engine/consistencyMap';
import { scrubText } from './engine/rulesEngine';

const DEFAULT_ADMIN_SETTINGS: AdminSettings = {
  showPolicyInHeader: true,
  defaultPolicy: 'soc2',
  enabledModules: {
    text: true,
    logs: true,
    excel: true
  }
};

function loadStoredAdminSettings(): AdminSettings {
  try {
    const raw = localStorage.getItem('filtr_admin_settings');
    if (raw) {
      const parsed = JSON.parse(raw);
      return {
        ...DEFAULT_ADMIN_SETTINGS,
        ...parsed,
        enabledModules: {
          ...DEFAULT_ADMIN_SETTINGS.enabledModules,
          ...(parsed.enabledModules || {})
        }
      };
    }
  } catch {
    // ignore parsing errors
  }
  return DEFAULT_ADMIN_SETTINGS;
}

export function App() {
  const [adminSettings, setAdminSettings] = useState<AdminSettings>(loadStoredAdminSettings);
  const [currentMode, setCurrentMode] = useState<'text' | 'logs' | 'excel'>('text');
  const [rawText, setRawText] = useState('');
  const [rules, setRules] = useState<DetectionRule[]>(() => applyPolicyPreset(adminSettings.defaultPolicy, initialRules));
  const [runtimeRules, setRuntimeRules] = useState<DetectionRule[]>([]);
  const [preset, setPreset] = useState<PolicyPreset>(adminSettings.defaultPolicy);
  const [strategy, setStrategy] = useState<MaskingStrategy>('consistent_token');
  const [isVaultOpen, setIsVaultOpen] = useState(false);
  const [isAdminOpen, setIsAdminOpen] = useState(false);

  // Combined active rules = runtime user rules + base system rules
  const allActiveRules = useMemo(() => {
    return [...runtimeRules, ...rules];
  }, [rules, runtimeRules]);

  // Consistency Vault for session
  const vault = useMemo(() => new ConsistencyVault(), [preset, strategy, allActiveRules]);

  // Scrub Text computation
  const scrubResult: ScrubResult = useMemo(() => {
    return scrubText(rawText, allActiveRules, vault, { maskingStrategy: strategy });
  }, [rawText, allActiveRules, vault, strategy]);

  const handleSelectPreset = (newPreset: PolicyPreset) => {
    setPreset(newPreset);
    setRules(prev => applyPolicyPreset(newPreset, prev));
  };

  const handleUpdateAdminSettings = (newSettings: AdminSettings) => {
    setAdminSettings(newSettings);
    localStorage.setItem('filtr_admin_settings', JSON.stringify(newSettings));
    if (newSettings.defaultPolicy !== preset) {
      handleSelectPreset(newSettings.defaultPolicy);
    }
    // Switch to first available module if current active module was disabled
    if (!newSettings.enabledModules[currentMode]) {
      if (newSettings.enabledModules.text) setCurrentMode('text');
      else if (newSettings.enabledModules.logs) setCurrentMode('logs');
      else if (newSettings.enabledModules.excel) setCurrentMode('excel');
    }
  };

  const handleAddRuntimeRule = (pattern: string, template: string, name?: string) => {
    const newRule: DetectionRule = {
      id: `runtime_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`,
      name: name || `Runtime: ${pattern.slice(0, 16)}`,
      category: 'custom',
      pattern,
      replacementTemplate: template,
      description: 'Dynamically added runtime rule',
      enabled: true,
      isCustom: true,
      severity: 'high'
    };

    setRuntimeRules(prev => [newRule, ...prev]);
  };

  const handleRemoveRuntimeRule = (id: string) => {
    setRuntimeRules(prev => prev.filter(r => r.id !== id));
  };

  const handleAddRule = (newRule: DetectionRule) => {
    setRules(prev => [newRule, ...prev]);
  };

  const handleToggleRule = (id: string) => {
    setRules(prev => prev.map(r => r.id === id ? { ...r, enabled: !r.enabled } : r));
    setRuntimeRules(prev => prev.map(r => r.id === id ? { ...r, enabled: !r.enabled } : r));
  };

  const handleUpdateRule = (updated: DetectionRule) => {
    setRules(prev => prev.map(r => r.id === updated.id ? updated : r));
    setRuntimeRules(prev => prev.map(r => r.id === updated.id ? updated : r));
  };

  const handleDeleteRule = (id: string) => {
    setRules(prev => prev.filter(r => r.id !== id));
    setRuntimeRules(prev => prev.filter(r => r.id !== id));
  };

  const handleResetToDefaults = () => {
    setRules(initialRules);
    setRuntimeRules([]);
  };

  const handleImportRules = (newRules: DetectionRule[]) => {
    setRules(newRules);
  };

  const handleClearVault = () => {
    vault.reset();
    setRawText(prev => prev);
  };

  return (
    <ErrorBoundary>
      <div className="flex flex-col h-screen w-screen font-sans overflow-hidden antialiased select-none bg-slate-50 text-slate-900">
        {/* Global Header */}
        <Header
          currentMode={currentMode}
          onSelectMode={setCurrentMode}
          preset={preset}
          onSelectPreset={handleSelectPreset}
          onOpenAdmin={() => setIsAdminOpen(true)}
          totalRedacted={scrubResult.stats.totalRedacted}
          showPolicySelector={adminSettings.showPolicyInHeader}
          enabledModules={adminSettings.enabledModules}
        />

        {/* Global Metrics Bar */}
        <StatsBar stats={scrubResult.stats} />

        {/* Docked Runtime Pattern Bar (Applies dynamically to active files) */}
        <RuntimePatternBar
          onAddRuntimeRule={handleAddRuntimeRule}
          runtimeRules={runtimeRules}
          onRemoveRuntimeRule={handleRemoveRuntimeRule}
        />

        {/* Main Workspace Mode Router */}
        <main className="flex-1 flex overflow-hidden">
          {currentMode === 'text' && adminSettings.enabledModules.text && (
            <TextSanitizer
              rawText={rawText}
              onChangeRawText={setRawText}
              scrubResult={scrubResult}
              strategy={strategy}
              onChangeStrategy={setStrategy}
              onOpenVault={() => setIsVaultOpen(true)}
              rules={allActiveRules}
              onAddRuntimeRule={handleAddRuntimeRule}
            />
          )}

          {currentMode === 'logs' && adminSettings.enabledModules.logs && (
            <LogFileProcessor
              rules={allActiveRules}
              strategy={strategy}
              onOpenVault={() => setIsVaultOpen(true)}
            />
          )}

          {currentMode === 'excel' && adminSettings.enabledModules.excel && (
            <ExcelSanitizer
              rules={allActiveRules}
              strategy={strategy}
              onOpenVault={() => setIsVaultOpen(true)}
            />
          )}
        </main>

        {/* Field Mapping Vault Modal */}
        <FieldMappingVault
          isOpen={isVaultOpen}
          onClose={() => setIsVaultOpen(false)}
          mappings={scrubResult.mappings}
          onClearVault={handleClearVault}
        />

        {/* Enterprise Admin Portal Modal */}
        <AdminPortal
          isOpen={isAdminOpen}
          onClose={() => setIsAdminOpen(false)}
          rules={rules}
          onAddRule={handleAddRule}
          onToggleRule={handleToggleRule}
          onDeleteRule={handleDeleteRule}
          onUpdateRule={handleUpdateRule}
          onResetToDefaults={handleResetToDefaults}
          onImportRules={handleImportRules}
          adminSettings={adminSettings}
          onUpdateSettings={handleUpdateAdminSettings}
        />
      </div>
    </ErrorBoundary>
  );
}

export default App;
