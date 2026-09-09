import type { DetectionRule, PolicyPreset } from '../types';
import { allDefaultRules } from './detectors';

export const defaultCustomRules: DetectionRule[] = [
  {
    id: 'emp_badge_id',
    name: 'Corporate Employee Badge ID',
    category: 'custom',
    description: 'Internal badge identifier format EMP-#####',
    pattern: '\\bEMP-[0-9]{5}\\b',
    replacementTemplate: '[EMPLOYEE_BADGE_{INDEX}]',
    enabled: true,
    isCustom: true,
    severity: 'high',
    examples: ['EMP-49821', 'EMP-00129']
  },
  {
    id: 'corp_internal_domain',
    name: 'Corporate Internal Domain / FQDN',
    category: 'custom',
    description: 'Internal corporate domain suffix (.corp.internal, .prod.corp)',
    pattern: '\\b[a-zA-Z0-9-_]+(?:\\.[a-zA-Z0-9-_]+)*\\.(?:corp\\.internal|prod\\.corp)\\b',
    replacementTemplate: '[INTERNAL_HOST_{INDEX}]',
    enabled: true,
    isCustom: true,
    severity: 'high',
    examples: ['vault-01.us-east.corp.internal', 'auth.prod.corp']
  },
  {
    id: 'internal_project_code',
    name: 'Internal Project Codename',
    category: 'custom',
    description: 'Sensitive project codename format PROJ-XXX-####',
    pattern: '\\bPROJ-[A-Z]{3}-[0-9]{4}\\b',
    replacementTemplate: '[PROJECT_CODE_{INDEX}]',
    enabled: true,
    isCustom: true,
    severity: 'medium',
    examples: ['PROJ-APO-9821', 'PROJ-RED-1120']
  }
];

// Alias for compatibility
export const sampleCustomRules = defaultCustomRules;

export const initialRules: DetectionRule[] = [
  ...allDefaultRules,
  ...defaultCustomRules
];

export function applyPolicyPreset(preset: PolicyPreset, rules: DetectionRule[]): DetectionRule[] {
  return rules.map(rule => {
    switch (preset) {
      case 'soc2':
        // Strict: All cloud, credentials, pii, phi, financial, network enabled
        return { ...rule, enabled: true };
      case 'gdpr':
        // GDPR: Focus on PII and Network IP tracking
        return { 
          ...rule, 
          enabled: rule.category === 'pii' || rule.category === 'financial' || rule.id === 'ipv4_address' || rule.id === 'ipv6_address'
        };
      case 'hipaa':
        // HIPAA: Patient Health Records, MRN, NPI, and PII
        return {
          ...rule,
          enabled: rule.category === 'phi' || rule.category === 'pii' || rule.id === 'ssn_number'
        };
      case 'pci':
        // PCI-DSS: Credit cards, banking IBAN, ABA routing, financial tokens
        return {
          ...rule,
          enabled: rule.category === 'financial' || rule.category === 'credentials'
        };
      case 'devops':
        // DevOps / SRE: Cloud keys, DB connections, internal hosts, passwords
        return { 
          ...rule, 
          enabled: rule.category === 'cloud' || rule.category === 'credentials' || rule.category === 'network' || rule.isCustom === true
        };
      case 'cloud':
        // Cloud & Secrets only
        return { 
          ...rule, 
          enabled: rule.category === 'cloud' || rule.category === 'credentials'
        };
      case 'custom':
      default:
        return rule;
    }
  });
}
