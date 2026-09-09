export type RuleCategory = 'cloud' | 'credentials' | 'pii' | 'phi' | 'financial' | 'network' | 'custom';

export type MaskingStrategy = 'consistent_token' | 'static_redact' | 'hash' | 'partial';

export interface DetectionRule {
  id: string;
  name: string;
  category: RuleCategory;
  description: string;
  pattern: string; // regex pattern string
  flags?: string;
  replacementTemplate: string; // e.g. '[AWS_KEY_{INDEX}]' or '[REDACTED_IP]'
  enabled: boolean;
  isCustom?: boolean;
  severity: 'critical' | 'high' | 'medium';
  examples?: string[];
}

export interface FieldMapping {
  id: string;
  originalValue: string;
  maskedValue: string;
  category: RuleCategory;
  ruleId: string;
  ruleName: string;
  occurrences: number;
  firstSeen: number;
}

export interface RedactionStats {
  totalRedacted: number;
  byCategory: Record<RuleCategory, number>;
  processingTimeMs: number;
  bytesProcessed: number;
}

export type PolicyPreset = 'soc2' | 'gdpr' | 'hipaa' | 'pci' | 'devops' | 'cloud' | 'custom';

export interface EnabledModules {
  text: boolean;
  logs: boolean;
  excel: boolean;
}

export interface AdminSettings {
  showPolicyInHeader: boolean;
  defaultPolicy: PolicyPreset;
  enabledModules: EnabledModules;
}

export interface DiffSegment {
  type: 'plain' | 'redacted';
  text: string;
  originalText?: string;
  category?: RuleCategory;
  ruleName?: string;
  token?: string;
}

export interface ScrubResult {
  sanitizedText: string;
  diffSegments: DiffSegment[];
  stats: RedactionStats;
  mappings: FieldMapping[];
}

export interface LogFileItem {
  id: string;
  name: string;
  size: number;
  rawContent: string;
  sanitizedContent: string;
  stats?: RedactionStats;
  mappings?: FieldMapping[];
  status: 'pending' | 'processing' | 'done' | 'error';
  progress: number;
  error?: string;
}

export interface ExcelSheetData {
  name: string;
  headers: string[];
  rows: Record<string, any>[];
  sanitizedRows: Record<string, any>[];
  columnRules: Record<string, MaskingStrategy | 'none'>;
  stats?: RedactionStats;
}
