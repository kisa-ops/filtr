import type { DetectionRule } from '../../types';

export const phiRules: DetectionRule[] = [
  {
    id: 'medical_record_number',
    name: 'Medical Record Number (MRN)',
    category: 'phi',
    description: 'Matches hospital and clinical patient Medical Record Numbers',
    pattern: '(?:mrn|medical[_-]?record[_-]?number|patient[_-]?id)[\\s:=#]+([A-Z0-9-]{6,14})',
    flags: 'i',
    replacementTemplate: '[MRN_{INDEX}]',
    enabled: true,
    severity: 'critical',
    examples: ['MRN: 98214812', 'patient_id = HOSP-9921-A']
  },
  {
    id: 'npi_provider_id',
    name: 'National Provider Identifier (NPI)',
    category: 'phi',
    description: 'Matches 10-digit US National Provider Identifiers for healthcare professionals',
    pattern: '(?:npi|provider[_-]?id|physician[_-]?npi)[\\s:=#]+([0-9]{10})',
    flags: 'i',
    replacementTemplate: '[NPI_{INDEX}]',
    enabled: true,
    severity: 'high',
    examples: ['NPI: 1234567890', 'provider_id=9876543210']
  },
  {
    id: 'health_insurance_claim',
    name: 'Health Insurance Claim Number (HICN)',
    category: 'phi',
    description: 'Detects Medicare and private health insurance claim numbers',
    pattern: '\\b[0-9]{9}[A-Z]{1,2}[0-9]?\\b|\\b[A-Z]{1,3}[0-9]{6,9}\\b',
    replacementTemplate: '[HICN_{INDEX}]',
    enabled: true,
    severity: 'critical',
    examples: ['123456789A', '987654321B1']
  },
  {
    id: 'health_plan_member_id',
    name: 'Health Plan / Insurance Member ID',
    category: 'phi',
    description: 'Detects healthcare policy numbers and beneficiary IDs',
    pattern: '(?:member[_-]?id|insurance[_-]?id|policy[_-]?number|beneficiary[_-]?id)[\\s:=#]+([A-Z0-9-]{7,16})',
    flags: 'i',
    replacementTemplate: '[MEMBER_ID_{INDEX}]',
    enabled: true,
    severity: 'critical',
    examples: ['member_id = UHC-9821948', 'policy_number: BCBS-883192']
  }
];
