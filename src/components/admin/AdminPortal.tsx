import React, { useState, useEffect } from 'react';
import { 
  X, 
  Lock, 
  Plus, 
  Trash2, 
  Edit3, 
  Check, 
  Search, 
  RotateCcw, 
  Download, 
  Upload, 
  ShieldCheck, 
  Sliders, 
  Play, 
  HelpCircle, 
  Copy, 
  Eye, 
  EyeOff, 
  Tag, 
  Info,
  LogOut,
  Key,
  Settings,
  AlertTriangle,
  CheckCircle2,
  Layers
} from 'lucide-react';
import type { DetectionRule, RuleCategory, AdminSettings, PolicyPreset, EnabledModules } from '../../types';
import { allDefaultRules } from '../../engine/detectors';
import { defaultCustomRules } from '../../engine/defaultRules';
import { authService } from '../../engine/authService';
import { FiltrLogo } from '../common/FiltrLogo';

interface AdminPortalProps {
  isOpen: boolean;
  onClose: () => void;
  rules: DetectionRule[];
  onAddRule: (rule: DetectionRule) => void;
  onToggleRule: (id: string) => void;
  onDeleteRule: (id: string) => void;
  onUpdateRule?: (updatedRule: DetectionRule) => void;
  onResetToDefaults?: () => void;
  onImportRules: (rules: DetectionRule[]) => void;
  adminSettings: AdminSettings;
  onUpdateSettings: (settings: AdminSettings) => void;
}

export const AdminPortal: React.FC<AdminPortalProps> = ({
  isOpen,
  onClose,
  rules,
  onAddRule,
  onToggleRule,
  onDeleteRule,
  onUpdateRule,
  onResetToDefaults,
  onImportRules,
  adminSettings,
  onUpdateSettings
}) => {
  // Authentication State
  const [isAuthConfigured, setIsAuthConfigured] = useState<boolean>(false);
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(false);
  const [password, setPassword] = useState('');
  const [authError, setAuthError] = useState('');
  const [isSubmittingAuth, setIsSubmittingAuth] = useState(false);
  const [showPassword, setShowPassword] = useState(false);

  // Setup state (for first-time initial passkey)
  const [setupPassword, setSetupPassword] = useState('');
  const [setupConfirm, setSetupConfirm] = useState('');
  const [setupError, setSetupError] = useState('');

  // Rate Limiting & Lockout countdown state
  const [lockoutSeconds, setLockoutSeconds] = useState<number>(0);

  // Active Tab: 'rules' | 'sandbox' | 'settings'
  const [activeTab, setActiveTab] = useState<'rules' | 'sandbox' | 'settings'>('rules');

  // Change Password Modal state
  const [isChangePasswordOpen, setIsChangePasswordOpen] = useState(false);
  const [oldPassword, setOldPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmNewPassword, setConfirmNewPassword] = useState('');
  const [changePasswordError, setChangePasswordError] = useState('');
  const [changePasswordSuccess, setChangePasswordSuccess] = useState('');

  // Filtering & Search state
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string>('all');
  const [statusFilter, setStatusFilter] = useState<'all' | 'enabled' | 'disabled'>('all');

  // Modal states for Add/Edit
  const [isEditingRule, setIsEditingRule] = useState<DetectionRule | null>(null);
  const [isAddingNew, setIsAddingNew] = useState(false);

  // Form fields for Add / Edit
  const [formName, setFormName] = useState('');
  const [formCategory, setFormCategory] = useState<RuleCategory>('custom');
  const [formPattern, setFormPattern] = useState('');
  const [formFlags, setFormFlags] = useState('');
  const [formTemplate, setFormTemplate] = useState('');
  const [formDescription, setFormDescription] = useState('');
  const [formSeverity, setFormSeverity] = useState<'critical' | 'high' | 'medium'>('high');
  const [formExamples, setFormExamples] = useState('');

  // Tooltip hover state
  const [hoveredRuleId, setHoveredRuleId] = useState<string | null>(null);
  const [copiedId, setCopiedId] = useState<string | null>(null);

  // Sandbox state
  const [testString, setTestString] = useState('User EMP-98214 accessed patient MRN: 98214812 from IP 192.168.1.105 with key AKIAIOSFODNN7EXAMPLE');
  const [sandboxRegex, setSandboxRegex] = useState('\\bAKIA[0-9A-Z]{16}\\b');
  const [sandboxTemplate, setSandboxTemplate] = useState('[AWS_KEY_{INDEX}]');
  const [sandboxResult, setSandboxResult] = useState('');
  const [sandboxMatches, setSandboxMatches] = useState(0);

  // Check auth and lockout when modal opens
  useEffect(() => {
    if (isOpen) {
      const configured = authService.isAuthConfigured();
      setIsAuthConfigured(configured);
      setIsAuthenticated(authService.isAuthenticated());
      
      const lockout = authService.getLockoutStatus();
      if (lockout.isLocked) {
        setLockoutSeconds(lockout.remainingSeconds);
      }
    }
  }, [isOpen]);

  // Lockout countdown timer
  useEffect(() => {
    if (lockoutSeconds <= 0) return;
    const interval = setInterval(() => {
      setLockoutSeconds(prev => {
        if (prev <= 1) {
          clearInterval(interval);
          setAuthError('');
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
    return () => clearInterval(interval);
  }, [lockoutSeconds]);

  if (!isOpen) return null;

  // Toggle Module with at-least-one guard
  const toggleModule = (moduleKey: keyof EnabledModules) => {
    const current = adminSettings.enabledModules || { text: true, logs: true, excel: true };
    const willBeEnabled = !current[moduleKey];

    if (!willBeEnabled) {
      const remaining = Object.entries(current).filter(([k, v]) => k !== moduleKey && v).length;
      if (remaining === 0) {
        alert('At least one workspace module must remain enabled.');
        return;
      }
    }

    const updated: AdminSettings = {
      ...adminSettings,
      enabledModules: {
        ...current,
        [moduleKey]: willBeEnabled
      }
    };
    onUpdateSettings(updated);
  };

  // Handle Initial Password Setup
  const handleSetupPassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setSetupError('');

    if (setupPassword.length < 8) {
      setSetupError('Passkey must be at least 8 characters long.');
      return;
    }
    if (setupPassword !== setupConfirm) {
      setSetupError('Passwords do not match. Please verify.');
      return;
    }

    setIsSubmittingAuth(true);
    const res = await authService.setupAdminPassword(setupPassword);
    setIsSubmittingAuth(false);

    if (res.success) {
      setIsAuthConfigured(true);
      setIsAuthenticated(true);
      setSetupPassword('');
      setSetupConfirm('');
    } else {
      setSetupError(res.error || 'Failed to setup passkey.');
    }
  };

  // Handle Login
  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!password) return;
    setAuthError('');

    setIsSubmittingAuth(true);
    const res = await authService.verifyAdminPassword(password);
    setIsSubmittingAuth(false);

    if (res.success) {
      setIsAuthenticated(true);
      setPassword('');
      setAuthError('');
    } else {
      if (res.lockoutRemainingSeconds) {
        setLockoutSeconds(res.lockoutRemainingSeconds);
      }
      setAuthError(res.error || 'Invalid credentials.');
    }
  };

  // Handle Logout
  const handleLogout = () => {
    authService.logout();
    setIsAuthenticated(false);
    setPassword('');
    setActiveTab('rules');
  };

  // Handle Change Password
  const handleChangePassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setChangePasswordError('');
    setChangePasswordSuccess('');

    if (newPassword.length < 8) {
      setChangePasswordError('New passkey must be at least 8 characters long.');
      return;
    }
    if (newPassword !== confirmNewPassword) {
      setChangePasswordError('New passwords do not match.');
      return;
    }

    setIsSubmittingAuth(true);
    const res = await authService.changeAdminPassword(oldPassword, newPassword);
    setIsSubmittingAuth(false);

    if (res.success) {
      setChangePasswordSuccess('Administrator passkey updated successfully.');
      setOldPassword('');
      setNewPassword('');
      setConfirmNewPassword('');
      setTimeout(() => {
        setIsChangePasswordOpen(false);
        setChangePasswordSuccess('');
      }, 1500);
    } else {
      setChangePasswordError(res.error || 'Failed to update passkey.');
    }
  };

  const handleCopyPattern = (text: string, id: string) => {
    navigator.clipboard.writeText(text);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 1800);
  };

  const handleOpenEdit = (rule: DetectionRule) => {
    setIsEditingRule(rule);
    setFormName(rule.name);
    setFormCategory(rule.category);
    setFormPattern(rule.pattern);
    setFormFlags(rule.flags || '');
    setFormTemplate(rule.replacementTemplate);
    setFormDescription(rule.description);
    setFormSeverity(rule.severity);
    setFormExamples(rule.examples ? rule.examples.join(', ') : '');
  };

  const handleOpenAdd = () => {
    setIsAddingNew(true);
    setFormName('');
    setFormCategory('custom');
    setFormPattern('');
    setFormFlags('');
    setFormTemplate('[CUSTOM_TOKEN_{INDEX}]');
    setFormDescription('');
    setFormSeverity('high');
    setFormExamples('');
  };

  const handleSaveForm = (e: React.FormEvent) => {
    e.preventDefault();

    // Validate regex pattern
    try {
      new RegExp(formPattern, formFlags || undefined);
    } catch {
      alert('Invalid Regular Expression pattern. Please verify your regex syntax.');
      return;
    }

    const examplesArray = formExamples
      ? formExamples.split(',').map(s => s.trim()).filter(Boolean)
      : undefined;

    if (isEditingRule && onUpdateRule) {
      const updated: DetectionRule = {
        ...isEditingRule,
        name: formName,
        category: formCategory,
        pattern: formPattern,
        flags: formFlags || undefined,
        replacementTemplate: formTemplate,
        description: formDescription,
        severity: formSeverity,
        examples: examplesArray
      };
      onUpdateRule(updated);
      setIsEditingRule(null);
    } else {
      const newRule: DetectionRule = {
        id: `custom_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`,
        name: formName,
        category: formCategory,
        pattern: formPattern,
        flags: formFlags || undefined,
        replacementTemplate: formTemplate,
        description: formDescription,
        enabled: true,
        isCustom: true,
        severity: formSeverity,
        examples: examplesArray
      };
      onAddRule(newRule);
      setIsAddingNew(false);
    }
  };

  // Run live regex sandbox testing
  const handleRunSandbox = () => {
    try {
      const re = new RegExp(sandboxRegex, 'g');
      const matches = testString.match(re);
      setSandboxMatches(matches ? matches.length : 0);

      let idx = 1;
      const scrubbed = testString.replace(re, () => {
        const token = sandboxTemplate.replace('{INDEX}', String(idx++));
        return token;
      });
      setSandboxResult(scrubbed);
    } catch (err: any) {
      setSandboxResult(`Regex Error: ${err.message}`);
      setSandboxMatches(0);
    }
  };

  // Export policy rules as JSON
  const handleExportPolicy = () => {
    const data = JSON.stringify(rules, null, 2);
    const blob = new Blob([data], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `filtr_enterprise_policy_${Date.now()}.json`;
    a.click();
    URL.revokeObjectURL(url);
  };

  // Import policy rules from JSON
  const handleImportPolicy = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      try {
        const imported = JSON.parse(event.target?.result as string);
        if (Array.isArray(imported)) {
          onImportRules(imported);
          alert(`Successfully imported ${imported.length} rules!`);
        } else {
          alert('Invalid policy JSON format. Expected an array of rules.');
        }
      } catch (err: any) {
        alert(`Failed to parse policy JSON: ${err.message}`);
      }
    };
    reader.readAsText(file);
    e.target.value = '';
  };

  // Filtered rules
  const filteredRules = rules.filter(rule => {
    if (selectedCategory !== 'all' && rule.category !== selectedCategory) return false;
    if (statusFilter === 'enabled' && !rule.enabled) return false;
    if (statusFilter === 'disabled' && rule.enabled) return false;
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      return (
        rule.name.toLowerCase().includes(q) ||
        rule.pattern.toLowerCase().includes(q) ||
        rule.description.toLowerCase().includes(q) ||
        rule.replacementTemplate.toLowerCase().includes(q) ||
        rule.category.toLowerCase().includes(q)
      );
    }
    return true;
  });

  const getCategoryBadgeClass = (category: RuleCategory) => {
    switch (category) {
      case 'cloud':
        return 'bg-rose-50 text-rose-700 border-rose-200';
      case 'credentials':
        return 'bg-amber-50 text-amber-700 border-amber-200';
      case 'pii':
        return 'bg-sky-50 text-sky-700 border-sky-200';
      case 'phi':
        return 'bg-emerald-50 text-emerald-700 border-emerald-200';
      case 'financial':
        return 'bg-purple-50 text-purple-700 border-purple-200';
      case 'network':
        return 'bg-blue-50 text-blue-700 border-blue-200';
      case 'custom':
      default:
        return 'bg-indigo-50 text-indigo-700 border-indigo-200';
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 backdrop-blur-sm p-4 animate-in fade-in duration-200">
      <div className="bg-white border border-slate-200 rounded-2xl w-full max-w-6xl max-h-[90vh] flex flex-col shadow-2xl overflow-hidden">
        {/* Modal Header */}
        <div className="px-6 py-3.5 border-b border-slate-200 flex items-center justify-between bg-slate-50">
          <div className="flex items-center gap-3">
            <FiltrLogo size="sm" />
            <div>
              <div className="flex items-center gap-2">
                <h2 className="text-base font-bold text-slate-900 tracking-wide">
                  filtr Governance & Admin Portal
                </h2>
                <span className="px-2 py-0.5 rounded-full bg-slate-200 text-slate-700 text-xs font-mono font-semibold">
                  {rules.length} Active Rules
                </span>
              </div>
            </div>
          </div>

          <div className="flex items-center gap-2">
            {isAuthenticated && (
              <>
                {/* Tab Switcher */}
                <div className="flex items-center p-1 bg-slate-200/80 rounded-xl text-xs font-semibold mr-2">
                  <button
                    onClick={() => setActiveTab('rules')}
                    className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg transition-all ${
                      activeTab === 'rules'
                        ? 'bg-white text-indigo-700 shadow-xs'
                        : 'text-slate-600 hover:text-slate-900'
                    }`}
                  >
                    <ShieldCheck className="w-3.5 h-3.5" />
                    <span>Rules</span>
                  </button>

                  <button
                    onClick={() => setActiveTab('sandbox')}
                    className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg transition-all ${
                      activeTab === 'sandbox'
                        ? 'bg-white text-indigo-700 shadow-xs'
                        : 'text-slate-600 hover:text-slate-900'
                    }`}
                  >
                    <Play className="w-3.5 h-3.5" />
                    <span>Sandbox</span>
                  </button>

                  <button
                    onClick={() => setActiveTab('settings')}
                    className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg transition-all ${
                      activeTab === 'settings'
                        ? 'bg-white text-indigo-700 shadow-xs'
                        : 'text-slate-600 hover:text-slate-900'
                    }`}
                  >
                    <Settings className="w-3.5 h-3.5" />
                    <span>Settings</span>
                  </button>
                </div>

                {/* Change Passkey */}
                <button
                  onClick={() => setIsChangePasswordOpen(true)}
                  className="p-1.5 rounded-lg text-slate-500 hover:text-indigo-600 hover:bg-indigo-50 border border-transparent hover:border-indigo-200 transition-colors"
                  title="Change Administrator Passkey"
                >
                  <Key className="w-4 h-4" />
                </button>

                {/* Logout */}
                <button
                  onClick={handleLogout}
                  className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-rose-50 hover:bg-rose-100 border border-rose-200 text-rose-700 text-xs font-semibold transition-colors"
                  title="Log out of Admin Portal"
                >
                  <LogOut className="w-3.5 h-3.5" />
                  <span>Log Out</span>
                </button>
              </>
            )}

            <button
              onClick={onClose}
              className="p-1.5 rounded-lg text-slate-400 hover:text-slate-800 hover:bg-slate-200 transition-colors ml-1"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* ----------------------------------------------------------------- */}
        {/* Auth Gate                                                         */}
        {/* ----------------------------------------------------------------- */}
        {!isAuthenticated ? (
          <div className="p-14 flex flex-col items-center justify-center bg-white">
            <div className="w-full max-w-sm p-6 bg-slate-50 border border-slate-200 rounded-2xl shadow-sm">
              <ShieldCheck className="w-10 h-10 mx-auto text-indigo-600 mb-3" />

              {!isAuthConfigured ? (
                /* Initial Setup Form */
                <div>
                  <h3 className="text-sm font-bold text-slate-900 text-center">Initialize Administrator Passkey</h3>

                  <form onSubmit={handleSetupPassword} className="mt-5 space-y-3.5">
                    <div>
                      <label className="block text-[11px] font-semibold text-slate-700 mb-1">New Admin Passkey</label>
                      <input
                        type={showPassword ? 'text' : 'password'}
                        placeholder="Minimum 8 characters..."
                        value={setupPassword}
                        onChange={(e) => setSetupPassword(e.target.value)}
                        required
                        className="w-full px-3 py-2 bg-white border border-slate-300 rounded-xl text-slate-800 text-xs focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-400"
                      />
                    </div>

                    <div>
                      <label className="block text-[11px] font-semibold text-slate-700 mb-1">Confirm Admin Passkey</label>
                      <input
                        type={showPassword ? 'text' : 'password'}
                        placeholder="Re-enter passkey..."
                        value={setupConfirm}
                        onChange={(e) => setSetupConfirm(e.target.value)}
                        required
                        className="w-full px-3 py-2 bg-white border border-slate-300 rounded-xl text-slate-800 text-xs focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-400"
                      />
                    </div>

                    <div className="flex items-center justify-between text-xs text-slate-500 pt-1">
                      <label className="flex items-center gap-1.5 cursor-pointer">
                        <input
                          type="checkbox"
                          checked={showPassword}
                          onChange={(e) => setShowPassword(e.target.checked)}
                          className="rounded border-slate-300 text-indigo-600"
                        />
                        <span>Show password</span>
                      </label>
                    </div>

                    {setupError && (
                      <p className="text-xs text-rose-600 font-medium bg-rose-50 p-2 rounded-lg border border-rose-200">
                        {setupError}
                      </p>
                    )}

                    <button
                      type="submit"
                      disabled={isSubmittingAuth}
                      className="w-full py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-semibold text-xs transition-colors shadow-sm disabled:opacity-50"
                    >
                      {isSubmittingAuth ? 'Encrypting & Saving...' : 'Initialize & Unlock Portal'}
                    </button>
                  </form>
                </div>
              ) : (
                /* Login Form */
                <div>
                  <h3 className="text-sm font-bold text-slate-900 text-center">Administrator Access</h3>

                  {lockoutSeconds > 0 ? (
                    <div className="mt-5 p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-800 text-xs text-center space-y-1">
                      <AlertTriangle className="w-5 h-5 mx-auto text-rose-600" />
                      <p className="font-semibold">Account Temporarily Locked</p>
                      <p className="text-[11px] text-rose-600">
                        Too many failed attempts. Try again in <strong>{lockoutSeconds}s</strong>.
                      </p>
                    </div>
                  ) : (
                    <form onSubmit={handleLogin} className="mt-5 space-y-3">
                      <div className="relative">
                        <input
                          type={showPassword ? 'text' : 'password'}
                          placeholder="Enter admin passkey..."
                          value={password}
                          onChange={(e) => setPassword(e.target.value)}
                          disabled={lockoutSeconds > 0 || isSubmittingAuth}
                          className="w-full px-3 py-2 pr-9 bg-white border border-slate-300 rounded-xl text-slate-800 text-xs focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-400 disabled:bg-slate-100"
                        />
                        <button
                          type="button"
                          onClick={() => setShowPassword(!showPassword)}
                          className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
                        >
                          {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                        </button>
                      </div>

                      {authError && (
                        <p className="text-xs text-rose-600 font-medium bg-rose-50 p-2 rounded-lg border border-rose-200">
                          {authError}
                        </p>
                      )}

                      <button
                        type="submit"
                        disabled={lockoutSeconds > 0 || isSubmittingAuth || !password}
                        className="w-full py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-semibold text-xs transition-colors shadow-sm disabled:opacity-50"
                      >
                        {isSubmittingAuth ? 'Verifying...' : 'Unlock Admin Portal'}
                      </button>
                    </form>
                  )}
                </div>
              )}
            </div>
          </div>
        ) : (
          /* Main Admin Workspace */
          <div className="flex-1 flex flex-col overflow-hidden bg-white">
            {/* ------------------------------------------------------------- */}
            {/* TAB 1: RULES MANAGEMENT                                       */}
            {/* ------------------------------------------------------------- */}
            {activeTab === 'rules' && (
              <>
                {/* Top Toolbar: Search, Filters, Add Rule, Reset, Export/Import */}
                <div className="p-4 border-b border-slate-200 bg-white flex flex-wrap items-center justify-between gap-3 text-xs">
                  <div className="flex items-center gap-2.5 flex-1 min-w-[300px]">
                    {/* Search */}
                    <div className="relative flex-1 max-w-xs">
                      <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
                      <input
                        type="text"
                        placeholder="Search rules, regex, tokens..."
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        className="w-full pl-9 pr-3 py-1.5 bg-slate-50 border border-slate-300 rounded-lg text-slate-800 placeholder-slate-400 text-xs focus:outline-none focus:border-indigo-500"
                      />
                    </div>

                    {/* Category Select */}
                    <select
                      value={selectedCategory}
                      onChange={(e) => setSelectedCategory(e.target.value)}
                      className="bg-slate-50 border border-slate-300 px-3 py-1.5 rounded-lg text-slate-700 text-xs focus:outline-none focus:border-indigo-500 cursor-pointer font-medium"
                    >
                      <option value="all">All Categories ({rules.length})</option>
                      <option value="cloud">Cloud & API Secrets</option>
                      <option value="credentials">Credentials & Passwords</option>
                      <option value="pii">PII (Personal Identifiable)</option>
                      <option value="phi">Healthcare & PHI (HIPAA)</option>
                      <option value="financial">Financial & Cards (PCI)</option>
                      <option value="network">Network & Hostnames</option>
                      <option value="custom">Custom Rules ({rules.filter(r => r.isCustom).length})</option>
                    </select>

                    {/* Status Filter */}
                    <select
                      value={statusFilter}
                      onChange={(e) => setStatusFilter(e.target.value as any)}
                      className="bg-slate-50 border border-slate-300 px-2.5 py-1.5 rounded-lg text-slate-700 text-xs focus:outline-none focus:border-indigo-500 cursor-pointer"
                    >
                      <option value="all">All Status</option>
                      <option value="enabled">Enabled Only</option>
                      <option value="disabled">Disabled Only</option>
                    </select>
                  </div>

                  {/* Action Buttons */}
                  <div className="flex items-center gap-2">
                    <button
                      onClick={handleOpenAdd}
                      className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white font-semibold text-xs transition-colors shadow-sm"
                    >
                      <Plus className="w-3.5 h-3.5" />
                      <span>Add New Rule</span>
                    </button>

                    {onResetToDefaults && (
                      <button
                        onClick={() => {
                          if (confirm('Reset all rules to factory system defaults?')) {
                            onResetToDefaults();
                          }
                        }}
                        className="flex items-center gap-1 px-2.5 py-1.5 rounded-lg border bg-white hover:bg-slate-100 border-slate-300 text-slate-700 text-xs font-medium transition-colors"
                        title="Reset to Factory Defaults"
                      >
                        <RotateCcw className="w-3.5 h-3.5" />
                        <span>Reset Defaults</span>
                      </button>
                    )}

                    <label className="flex items-center gap-1 px-2.5 py-1.5 rounded-lg border bg-white hover:bg-slate-100 border-slate-300 text-slate-700 text-xs font-medium transition-colors cursor-pointer">
                      <Upload className="w-3.5 h-3.5 text-indigo-600" />
                      <span>Import</span>
                      <input type="file" onChange={handleImportPolicy} accept=".json" className="hidden" />
                    </label>

                    <button
                      onClick={handleExportPolicy}
                      className="flex items-center gap-1 px-2.5 py-1.5 rounded-lg border bg-white hover:bg-slate-100 border-slate-300 text-slate-700 text-xs font-medium transition-colors"
                      title="Export rules as JSON policy"
                    >
                      <Download className="w-3.5 h-3.5 text-emerald-600" />
                      <span>Export</span>
                    </button>
                  </div>
                </div>

                {/* Rules Table View with Beautiful Admin Scrollbar */}
                <div className="flex-1 overflow-y-auto p-6 font-mono text-xs admin-scrollbar">
                  <table className="w-full text-left border-collapse">
                    <thead>
                      <tr className="border-b border-slate-200 text-slate-500 text-[11px] uppercase tracking-wider font-sans font-semibold bg-slate-50/70">
                        <th className="py-2.5 px-3 w-16">Status</th>
                        <th className="py-2.5 px-3">Rule Name & Details</th>
                        <th className="py-2.5 px-3">Category</th>
                        <th className="py-2.5 px-3">Pattern & Template</th>
                        <th className="py-2.5 px-3 text-center">Examples</th>
                        <th className="py-2.5 px-3 text-right">Actions</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100">
                      {filteredRules.map((rule) => {
                        const sampleText = rule.examples && rule.examples.length > 0 ? rule.examples[0] : null;

                        return (
                          <tr 
                            key={rule.id}
                            className={`hover:bg-slate-50/80 transition-colors group ${
                              !rule.enabled ? 'opacity-50 bg-slate-50/40' : ''
                            }`}
                          >
                            {/* Toggle switch */}
                            <td className="py-3 px-3">
                              <button
                                onClick={() => onToggleRule(rule.id)}
                                className={`w-8 h-4 rounded-full transition-colors relative focus:outline-none ${
                                  rule.enabled ? 'bg-indigo-600' : 'bg-slate-300'
                                }`}
                                title={rule.enabled ? 'Click to disable' : 'Click to enable'}
                              >
                                <span
                                  className={`absolute top-0.5 left-0.5 w-3 h-3 rounded-full bg-white transition-transform ${
                                    rule.enabled ? 'translate-x-4' : 'translate-x-0'
                                  }`}
                                />
                              </button>
                            </td>

                            {/* Name & Description */}
                            <td className="py-3 px-3">
                              <div className="flex items-center gap-2">
                                <span className="font-semibold text-slate-800 font-sans text-xs">
                                  {rule.name}
                                </span>
                                {rule.isCustom && (
                                  <span className="px-1.5 py-0.2 text-[9px] font-bold rounded bg-indigo-100 text-indigo-700 border border-indigo-200 font-mono">
                                    CUSTOM
                                  </span>
                                )}
                              </div>
                              <p className="text-[11px] text-slate-500 font-sans mt-0.5 max-w-md line-clamp-1">
                                {rule.description}
                              </p>
                            </td>

                            {/* Category Badge */}
                            <td className="py-3 px-3">
                              <span className={`px-2 py-0.5 rounded-full text-[10px] font-semibold border ${getCategoryBadgeClass(rule.category)} font-sans`}>
                                {rule.category}
                              </span>
                            </td>

                            {/* Pattern and Replacement Token */}
                            <td className="py-3 px-3 max-w-xs">
                              <div className="flex items-center gap-1.5">
                                <code className="bg-slate-100 px-1.5 py-0.5 rounded text-slate-700 text-[11px] truncate max-w-[180px] border border-slate-200">
                                  {rule.pattern}
                                </code>
                                <button
                                  onClick={() => handleCopyPattern(rule.pattern, rule.id)}
                                  className="text-slate-400 hover:text-slate-600 p-0.5 transition-colors"
                                  title="Copy Regex Pattern"
                                >
                                  {copiedId === rule.id ? <Check className="w-3 h-3 text-emerald-500" /> : <Copy className="w-3 h-3" />}
                                </button>
                              </div>
                              <span className="text-[10px] text-indigo-600 font-semibold mt-1 block">
                                → {rule.replacementTemplate}
                              </span>
                            </td>

                            {/* Example Tooltip */}
                            <td className="py-3 px-3 text-center relative">
                              {sampleText ? (
                                <div className="inline-block relative">
                                  <button
                                    onMouseEnter={() => setHoveredRuleId(rule.id)}
                                    onMouseLeave={() => setHoveredRuleId(null)}
                                    onClick={() => {
                                      setTestString(`Sample input with ${sampleText}`);
                                      setSandboxRegex(rule.pattern);
                                      setSandboxTemplate(rule.replacementTemplate);
                                      setActiveTab('sandbox');
                                    }}
                                    className="px-2 py-0.5 rounded-md bg-slate-100 hover:bg-indigo-50 border border-slate-200 hover:border-indigo-300 text-slate-600 hover:text-indigo-700 text-[11px] font-medium transition-colors inline-flex items-center gap-1"
                                    title="Click to test in Regex Sandbox"
                                  >
                                    <Eye className="w-3 h-3" />
                                    <span>Preview</span>
                                  </button>

                                  {hoveredRuleId === rule.id && (
                                    <div className="absolute z-50 bottom-full left-1/2 -translate-x-1/2 mb-2 w-56 p-2 bg-slate-900 text-white text-[11px] rounded-xl shadow-xl pointer-events-none border border-slate-700 text-left font-sans">
                                      <p className="font-semibold text-slate-300 text-[10px] uppercase">Example Value:</p>
                                      <p className="font-mono text-cyan-300 mt-1 break-all bg-slate-800 p-1 rounded">
                                        {sampleText}
                                      </p>
                                    </div>
                                  )}
                                </div>
                              ) : (
                                <span className="text-slate-300">—</span>
                              )}
                            </td>

                            {/* Actions */}
                            <td className="py-3 px-3 text-right">
                              <div className="flex items-center justify-end gap-1.5">
                                <button
                                  onClick={() => handleOpenEdit(rule)}
                                  className="p-1 rounded text-slate-400 hover:text-indigo-600 hover:bg-slate-100 transition-colors"
                                  title="Edit Rule"
                                >
                                  <Edit3 className="w-3.5 h-3.5" />
                                </button>
                                {rule.isCustom && (
                                  <button
                                    onClick={() => onDeleteRule(rule.id)}
                                    className="p-1 rounded text-slate-400 hover:text-rose-600 hover:bg-rose-50 transition-colors"
                                    title="Delete Rule"
                                  >
                                    <Trash2 className="w-3.5 h-3.5" />
                                  </button>
                                )}
                              </div>
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              </>
            )}

            {/* ------------------------------------------------------------- */}
            {/* TAB 2: INTERACTIVE REGEX SANDBOX                              */}
            {/* ------------------------------------------------------------- */}
            {activeTab === 'sandbox' && (
              <div className="flex-1 overflow-y-auto p-6 space-y-5 bg-slate-50/50 admin-scrollbar">
                <div className="max-w-4xl mx-auto space-y-4">
                  <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs space-y-4">
                    <div className="flex items-center gap-2 text-indigo-700 font-bold text-sm">
                      <Play className="w-4 h-4" />
                      <span>Interactive Regex Pattern Sandbox</span>
                    </div>
                    <p className="text-xs text-slate-500">
                      Test regular expressions and replacement templates against live payloads before saving rules into production.
                    </p>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-3.5 pt-2">
                      <div>
                        <label className="block text-xs font-semibold text-slate-700 mb-1 font-mono">
                          Regular Expression (JS Regex)
                        </label>
                        <input
                          type="text"
                          value={sandboxRegex}
                          onChange={(e) => setSandboxRegex(e.target.value)}
                          placeholder="e.g. \\bAKIA[0-9A-Z]{16}\\b"
                          className="w-full px-3 py-1.5 bg-slate-50 border border-slate-300 rounded-lg text-slate-800 font-mono text-xs focus:outline-none focus:border-indigo-500"
                        />
                      </div>

                      <div>
                        <label className="block text-xs font-semibold text-slate-700 mb-1 font-mono">
                          Replacement Token Template
                        </label>
                        <input
                          type="text"
                          value={sandboxTemplate}
                          onChange={(e) => setSandboxTemplate(e.target.value)}
                          placeholder="e.g. [AWS_KEY_{INDEX}]"
                          className="w-full px-3 py-1.5 bg-slate-50 border border-slate-300 rounded-lg text-slate-800 font-mono text-xs focus:outline-none focus:border-indigo-500"
                        />
                      </div>
                    </div>

                    <div>
                      <label className="block text-xs font-semibold text-slate-700 mb-1 font-mono">
                        Test String Payload
                      </label>
                      <textarea
                        value={testString}
                        onChange={(e) => setTestString(e.target.value)}
                        rows={3}
                        className="w-full px-3 py-2 bg-slate-50 border border-slate-300 rounded-lg text-slate-800 font-mono text-xs focus:outline-none focus:border-indigo-500 resize-none"
                      />
                    </div>

                    <div className="flex items-center justify-between pt-1">
                      <span className="text-xs font-medium text-slate-600">
                        Matches Found: <strong className="text-indigo-600">{sandboxMatches}</strong>
                      </span>
                      <button
                        onClick={handleRunSandbox}
                        className="flex items-center gap-1.5 px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-semibold text-xs transition-colors shadow-sm"
                      >
                        <Play className="w-3.5 h-3.5" />
                        <span>Execute Regex Test</span>
                      </button>
                    </div>

                    {sandboxResult && (
                      <div className="mt-4 p-3 bg-slate-900 text-slate-100 rounded-xl font-mono text-xs border border-slate-800">
                        <span className="text-[10px] uppercase font-bold text-slate-400 block mb-1">
                          Sandbox Output Result:
                        </span>
                        <pre className="whitespace-pre-wrap">{sandboxResult}</pre>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            )}

            {/* ------------------------------------------------------------- */}
            {/* TAB 3: GOVERNANCE & UI SETTINGS                               */}
            {/* ------------------------------------------------------------- */}
            {activeTab === 'settings' && (
              <div className="flex-1 overflow-y-auto p-6 space-y-6 bg-slate-50/50 admin-scrollbar">
                <div className="max-w-3xl mx-auto space-y-6">
                  {/* Setting: Feature Modules Governance (Task 2) */}
                  <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs space-y-4">
                    <div className="flex items-center gap-2 text-slate-900 font-bold text-sm">
                      <Layers className="w-4 h-4 text-indigo-600" />
                      <span>Feature Modules Governance</span>
                    </div>
                    <p className="text-xs text-slate-500">
                      Enable or disable active workspace modules across the application.
                    </p>

                    {/* Raw Text Module Toggle */}
                    <div className="pt-3 border-t border-slate-100 flex items-center justify-between">
                      <div>
                        <p className="text-xs font-semibold text-slate-800">Raw Text Sanitizer</p>
                        <p className="text-[11px] text-slate-500">Live dual-pane plain text and diff redaction workspace.</p>
                      </div>
                      <button
                        onClick={() => toggleModule('text')}
                        className={`w-11 h-6 rounded-full transition-colors relative focus:outline-none ${
                          adminSettings.enabledModules?.text ? 'bg-indigo-600' : 'bg-slate-300'
                        }`}
                        title={adminSettings.enabledModules?.text ? 'Disable Raw Text module' : 'Enable Raw Text module'}
                      >
                        <span
                          className={`absolute top-1 left-1 w-4 h-4 rounded-full bg-white transition-transform ${
                            adminSettings.enabledModules?.text ? 'translate-x-5' : 'translate-x-0'
                          }`}
                        />
                      </button>
                    </div>

                    {/* Bulk Log Files Processor Toggle */}
                    <div className="pt-3 border-t border-slate-100 flex items-center justify-between">
                      <div>
                        <p className="text-xs font-semibold text-slate-800">Bulk Log Files Processor</p>
                        <p className="text-[11px] text-slate-500">Multi-file log scrubber with progress indicators and ZIP export.</p>
                      </div>
                      <button
                        onClick={() => toggleModule('logs')}
                        className={`w-11 h-6 rounded-full transition-colors relative focus:outline-none ${
                          adminSettings.enabledModules?.logs ? 'bg-indigo-600' : 'bg-slate-300'
                        }`}
                        title={adminSettings.enabledModules?.logs ? 'Disable Log Files module' : 'Enable Log Files module'}
                      >
                        <span
                          className={`absolute top-1 left-1 w-4 h-4 rounded-full bg-white transition-transform ${
                            adminSettings.enabledModules?.logs ? 'translate-x-5' : 'translate-x-0'
                          }`}
                        />
                      </button>
                    </div>

                    {/* Excel & CSV Tabular Sanitizer Toggle */}
                    <div className="pt-3 border-t border-slate-100 flex items-center justify-between">
                      <div>
                        <p className="text-xs font-semibold text-slate-800">Excel & CSV Tabular Sanitizer</p>
                        <p className="text-[11px] text-slate-500">Spreadsheet grid sanitization with column-level masking policies.</p>
                      </div>
                      <button
                        onClick={() => toggleModule('excel')}
                        className={`w-11 h-6 rounded-full transition-colors relative focus:outline-none ${
                          adminSettings.enabledModules?.excel ? 'bg-indigo-600' : 'bg-slate-300'
                        }`}
                        title={adminSettings.enabledModules?.excel ? 'Disable Excel module' : 'Enable Excel module'}
                      >
                        <span
                          className={`absolute top-1 left-1 w-4 h-4 rounded-full bg-white transition-transform ${
                            adminSettings.enabledModules?.excel ? 'translate-x-5' : 'translate-x-0'
                          }`}
                        />
                      </button>
                    </div>
                  </div>

                  {/* Setting: Policy Selector Display */}
                  <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs space-y-4">
                    <div className="flex items-center gap-2 text-slate-900 font-bold text-sm">
                      <Sliders className="w-4 h-4 text-indigo-600" />
                      <span>Frontend Policy Display Governance</span>
                    </div>
                    <p className="text-xs text-slate-500">
                      Control whether end users can see and modify the Policy Preset selector on the main application header.
                    </p>

                    <div className="pt-3 border-t border-slate-100 flex items-center justify-between">
                      <div>
                        <p className="text-xs font-semibold text-slate-800">
                          Show Policy Selector on Frontend Header
                        </p>
                        <p className="text-[11px] text-slate-500">
                          When disabled, the Policy dropdown is hidden from end users on the frontend header.
                        </p>
                      </div>

                      <button
                        onClick={() => {
                          const updated = {
                            ...adminSettings,
                            showPolicyInHeader: !adminSettings.showPolicyInHeader
                          };
                          onUpdateSettings(updated);
                        }}
                        className={`w-11 h-6 rounded-full transition-colors relative focus:outline-none ${
                          adminSettings.showPolicyInHeader ? 'bg-indigo-600' : 'bg-slate-300'
                        }`}
                      >
                        <span
                          className={`absolute top-1 left-1 w-4 h-4 rounded-full bg-white transition-transform ${
                            adminSettings.showPolicyInHeader ? 'translate-x-5' : 'translate-x-0'
                          }`}
                        />
                      </button>
                    </div>

                    <div className="pt-3 border-t border-slate-100 flex items-center justify-between">
                      <div>
                        <p className="text-xs font-semibold text-slate-800">
                          Default Policy Preset
                        </p>
                        <p className="text-[11px] text-slate-500">
                          The baseline compliance policy applied to all frontend sessions.
                        </p>
                      </div>

                      <select
                        value={adminSettings.defaultPolicy}
                        onChange={(e) => {
                          const updated = {
                            ...adminSettings,
                            defaultPolicy: e.target.value as PolicyPreset
                          };
                          onUpdateSettings(updated);
                        }}
                        className="bg-slate-50 border border-slate-300 px-3 py-1.5 rounded-lg text-slate-800 text-xs font-semibold focus:outline-none focus:border-indigo-500 cursor-pointer"
                      >
                        <option value="soc2">SOC-2 Strict (All Rules)</option>
                        <option value="gdpr">GDPR (PII & Network)</option>
                        <option value="hipaa">HIPAA (Health PHI & PII)</option>
                        <option value="pci">PCI-DSS (Financial & Cards)</option>
                        <option value="devops">DevOps & SRE Logs</option>
                        <option value="cloud">Cloud Secrets Only</option>
                        <option value="custom">Custom Policy</option>
                      </select>
                    </div>
                  </div>

                  {/* Setting: Security & Access Control */}
                  <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs space-y-4">
                    <div className="flex items-center gap-2 text-slate-900 font-bold text-sm">
                      <Lock className="w-4 h-4 text-indigo-600" />
                      <span>Security & Authentication Governance</span>
                    </div>

                    <div className="p-3 bg-slate-50 rounded-xl border border-slate-200 space-y-1 text-xs">
                      <p className="text-slate-700 font-semibold">Cryptographic Key Derivation</p>
                      <p className="text-slate-500 text-[11px]">
                        Web Crypto API • PBKDF2 with HMAC-SHA256 • 100,000 Iterations • Random 16-byte Salt • Automatic Lockout
                      </p>
                    </div>

                    <div className="pt-2 flex items-center justify-between">
                      <button
                        onClick={() => setIsChangePasswordOpen(true)}
                        className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl border border-slate-300 hover:bg-slate-50 text-slate-700 font-semibold text-xs transition-colors"
                      >
                        <Key className="w-3.5 h-3.5 text-indigo-600" />
                        <span>Change Administrator Passkey</span>
                      </button>

                      <button
                        onClick={handleLogout}
                        className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-rose-50 hover:bg-rose-100 border border-rose-200 text-rose-700 font-semibold text-xs transition-colors"
                      >
                        <LogOut className="w-3.5 h-3.5" />
                        <span>Log Out of Admin Session</span>
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>
        )}

        {/* ----------------------------------------------------------------- */}
        {/* ADD / EDIT RULE MODAL DIALOG                                      */}
        {/* ----------------------------------------------------------------- */}
        {(isAddingNew || isEditingRule) && (
          <div className="fixed inset-0 z-60 flex items-center justify-center bg-slate-900/50 backdrop-blur-xs p-4">
            <div className="bg-white border border-slate-200 rounded-2xl w-full max-w-lg shadow-2xl p-6">
              <div className="flex items-center justify-between pb-3 border-b border-slate-200 mb-4">
                <h3 className="text-sm font-bold text-slate-900">
                  {isEditingRule ? `Edit Rule: ${isEditingRule.name}` : 'Create Custom Detection Rule'}
                </h3>
                <button
                  onClick={() => {
                    setIsEditingRule(null);
                    setIsAddingNew(false);
                  }}
                  className="text-slate-400 hover:text-slate-700"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>

              <form onSubmit={handleSaveForm} className="space-y-3.5 text-xs">
                <div>
                  <label className="block font-semibold text-slate-700 mb-1">Rule Name</label>
                  <input
                    type="text"
                    value={formName}
                    onChange={(e) => setFormName(e.target.value)}
                    required
                    placeholder="e.g. Employee ID / Project Badge"
                    className="w-full px-3 py-1.5 border border-slate-300 rounded-lg text-slate-800 focus:outline-none focus:border-indigo-500"
                  />
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block font-semibold text-slate-700 mb-1">Category</label>
                    <select
                      value={formCategory}
                      onChange={(e) => setFormCategory(e.target.value as RuleCategory)}
                      className="w-full px-3 py-1.5 border border-slate-300 rounded-lg text-slate-800 focus:outline-none focus:border-indigo-500"
                    >
                      <option value="custom">Custom</option>
                      <option value="cloud">Cloud Secrets</option>
                      <option value="credentials">Credentials</option>
                      <option value="pii">PII</option>
                      <option value="phi">PHI</option>
                      <option value="financial">Financial</option>
                      <option value="network">Network</option>
                    </select>
                  </div>

                  <div>
                    <label className="block font-semibold text-slate-700 mb-1">Severity</label>
                    <select
                      value={formSeverity}
                      onChange={(e) => setFormSeverity(e.target.value as any)}
                      className="w-full px-3 py-1.5 border border-slate-300 rounded-lg text-slate-800 focus:outline-none focus:border-indigo-500"
                    >
                      <option value="critical">Critical</option>
                      <option value="high">High</option>
                      <option value="medium">Medium</option>
                    </select>
                  </div>
                </div>

                <div>
                  <label className="block font-semibold text-slate-700 mb-1 font-mono">
                    Regular Expression Pattern (JavaScript RegExp)
                  </label>
                  <input
                    type="text"
                    value={formPattern}
                    onChange={(e) => setFormPattern(e.target.value)}
                    required
                    placeholder="e.g. \\bEMP-[0-9]{5}\\b"
                    className="w-full px-3 py-1.5 border border-slate-300 rounded-lg text-slate-800 font-mono focus:outline-none focus:border-indigo-500"
                  />
                </div>

                <div>
                  <label className="block font-semibold text-slate-700 mb-1 font-mono">
                    Replacement Token Template
                  </label>
                  <input
                    type="text"
                    value={formTemplate}
                    onChange={(e) => setFormTemplate(e.target.value)}
                    required
                    placeholder="e.g. [EMPLOYEE_BADGE_{INDEX}]"
                    className="w-full px-3 py-1.5 border border-slate-300 rounded-lg text-slate-800 font-mono focus:outline-none focus:border-indigo-500"
                  />
                </div>

                <div>
                  <label className="block font-semibold text-slate-700 mb-1">
                    Sample Sensitive Values (Comma separated)
                  </label>
                  <input
                    type="text"
                    value={formExamples}
                    onChange={(e) => setFormExamples(e.target.value)}
                    placeholder="e.g. EMP-49821, EMP-00129"
                    className="w-full px-3 py-1.5 border border-slate-300 rounded-lg text-slate-800 focus:outline-none focus:border-indigo-500"
                  />
                </div>

                <div>
                  <label className="block font-semibold text-slate-700 mb-1">Description</label>
                  <textarea
                    value={formDescription}
                    onChange={(e) => setFormDescription(e.target.value)}
                    rows={2}
                    className="w-full px-3 py-1.5 border border-slate-300 rounded-lg text-slate-800 resize-none focus:outline-none focus:border-indigo-500"
                  />
                </div>

                <div className="flex items-center justify-end gap-2 pt-2 border-t border-slate-200">
                  <button
                    type="button"
                    onClick={() => {
                      setIsEditingRule(null);
                      setIsAddingNew(false);
                    }}
                    className="px-3.5 py-1.5 rounded-lg border border-slate-300 text-slate-700 hover:bg-slate-50 font-medium"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    className="px-4 py-1.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white font-semibold shadow-sm"
                  >
                    Save Rule
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* ----------------------------------------------------------------- */}
        {/* CHANGE PASSWORD MODAL                                             */}
        {/* ----------------------------------------------------------------- */}
        {isChangePasswordOpen && (
          <div className="fixed inset-0 z-60 flex items-center justify-center bg-slate-900/50 backdrop-blur-xs p-4">
            <div className="bg-white border border-slate-200 rounded-2xl w-full max-w-sm shadow-2xl p-6">
              <div className="flex items-center justify-between pb-3 border-b border-slate-200 mb-4">
                <div className="flex items-center gap-2">
                  <Key className="w-4 h-4 text-indigo-600" />
                  <h3 className="text-sm font-bold text-slate-900">Change Admin Passkey</h3>
                </div>
                <button
                  onClick={() => setIsChangePasswordOpen(false)}
                  className="text-slate-400 hover:text-slate-700"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>

              <form onSubmit={handleChangePassword} className="space-y-3.5 text-xs">
                <div>
                  <label className="block font-semibold text-slate-700 mb-1">Current Passkey</label>
                  <input
                    type="password"
                    value={oldPassword}
                    onChange={(e) => setOldPassword(e.target.value)}
                    required
                    placeholder="Enter current passkey..."
                    className="w-full px-3 py-1.5 border border-slate-300 rounded-lg text-slate-800 focus:outline-none focus:border-indigo-500"
                  />
                </div>

                <div>
                  <label className="block font-semibold text-slate-700 mb-1">New Passkey (Min 8 chars)</label>
                  <input
                    type="password"
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                    required
                    placeholder="Enter new passkey..."
                    className="w-full px-3 py-1.5 border border-slate-300 rounded-lg text-slate-800 focus:outline-none focus:border-indigo-500"
                  />
                </div>

                <div>
                  <label className="block font-semibold text-slate-700 mb-1">Confirm New Passkey</label>
                  <input
                    type="password"
                    value={confirmNewPassword}
                    onChange={(e) => setConfirmNewPassword(e.target.value)}
                    required
                    placeholder="Re-enter new passkey..."
                    className="w-full px-3 py-1.5 border border-slate-300 rounded-lg text-slate-800 focus:outline-none focus:border-indigo-500"
                  />
                </div>

                {changePasswordError && (
                  <p className="text-xs text-rose-600 font-medium bg-rose-50 p-2 rounded-lg border border-rose-200">
                    {changePasswordError}
                  </p>
                )}

                {changePasswordSuccess && (
                  <p className="text-xs text-emerald-600 font-medium bg-emerald-50 p-2 rounded-lg border border-emerald-200 flex items-center gap-1.5">
                    <CheckCircle2 className="w-4 h-4" />
                    <span>{changePasswordSuccess}</span>
                  </p>
                )}

                <div className="flex items-center justify-end gap-2 pt-2 border-t border-slate-200">
                  <button
                    type="button"
                    onClick={() => setIsChangePasswordOpen(false)}
                    className="px-3.5 py-1.5 rounded-lg border border-slate-300 text-slate-700 hover:bg-slate-50 font-medium"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={isSubmittingAuth}
                    className="px-4 py-1.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white font-semibold shadow-sm disabled:opacity-50"
                  >
                    {isSubmittingAuth ? 'Updating...' : 'Update Passkey'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Modal Footer */}
        <div className="px-6 py-3 border-t border-slate-200 bg-slate-50 flex items-center justify-end text-xs text-slate-500">
          <button
            onClick={onClose}
            className="px-4 py-1.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white font-semibold text-xs transition-colors shadow-sm"
          >
            Done
          </button>
        </div>
      </div>
    </div>
  );
};
