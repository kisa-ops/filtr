import type { DetectionRule } from '../../types';

export const piiRules: DetectionRule[] = [
  {
    id: 'email_address',
    name: 'Email Address',
    category: 'pii',
    description: 'Matches personal and corporate email addresses',
    pattern: '\\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}\\b',
    replacementTemplate: '[EMAIL_{INDEX}]',
    enabled: true,
    severity: 'high',
    examples: ['alice.smith@acme-corp.com', 'john.doe@gmail.com']
  },
  {
    id: 'phone_number',
    name: 'Phone Number (Intl / Domestic)',
    category: 'pii',
    description: 'Matches international and domestic telephone numbers',
    pattern: '(?<!\\w)(?:\\+?[1-9]\\d{0,2}[- .]?)?\\(?\\d{3}\\)?[- .]\\d{3}[- .]\\d{4}(?!\\w)',
    replacementTemplate: '[PHONE_{INDEX}]',
    enabled: true,
    severity: 'medium',
    examples: ['+1-555-867-5309', '(415) 555-0199', '555-123-4567']
  },
  {
    id: 'ssn_number',
    name: 'US Social Security Number (SSN)',
    category: 'pii',
    description: 'Matches 9-digit US Social Security Numbers',
    pattern: '\\b(?!000)\\d{3}[- ]?(?!00)\\d{2}[- ]?(?!0000)\\d{4}\\b',
    replacementTemplate: '[SSN_{INDEX}]',
    enabled: true,
    severity: 'critical',
    examples: ['123-45-6789', '987 65 4321']
  },
  {
    id: 'uk_nino',
    name: 'UK National Insurance Number (NINO)',
    category: 'pii',
    description: 'Matches standard UK National Insurance Numbers',
    pattern: '\\b[A-CEGHJ-PR-TW-ZQ]{1}[A-CEGHJ-NPR-TW-ZQ]{1}[0-9]{6}[A-DFMZ]{0,1}\\b',
    replacementTemplate: '[UK_NINO_{INDEX}]',
    enabled: true,
    severity: 'critical',
    examples: ['QQ123456C', 'AB123456Z']
  },
  {
    id: 'canadian_sin',
    name: 'Canadian Social Insurance Number (SIN)',
    category: 'pii',
    description: 'Matches 9-digit Canadian Social Insurance Numbers',
    pattern: '\\b[0-9]{3}[ -]?[0-9]{3}[ -]?[0-9]{3}\\b',
    replacementTemplate: '[CANADA_SIN_{INDEX}]',
    enabled: false,
    severity: 'critical',
    examples: ['046 454 286', '123-456-789']
  },
  {
    id: 'indian_pan',
    name: 'Indian Permanent Account Number (PAN)',
    category: 'pii',
    description: 'Matches 10-character Indian PAN Card numbers',
    pattern: '\\b[A-Z]{5}[0-9]{4}[A-Z]{1}\\b',
    replacementTemplate: '[PAN_CARD_{INDEX}]',
    enabled: true,
    severity: 'high',
    examples: ['ABCDE1234F', 'BKZPS9821K']
  },
  {
    id: 'indian_aadhaar',
    name: 'Indian Aadhaar Number (UIDAI)',
    category: 'pii',
    description: 'Matches 12-digit Indian Aadhaar card identifiers',
    pattern: '\\b[2-9]{1}[0-9]{3}[ -]?[0-9]{4}[ -]?[0-9]{4}\\b',
    replacementTemplate: '[AADHAAR_{INDEX}]',
    enabled: true,
    severity: 'critical',
    examples: ['3675 9834 6012', '9821-4821-1120']
  },
  {
    id: 'passport_number',
    name: 'International Passport Number',
    category: 'pii',
    description: 'Detects standard 9-character international and US passport numbers',
    pattern: '\\b[A-Z][0-9]{8}\\b|\\b[A-Z0-9]{9}\\b',
    replacementTemplate: '[PASSPORT_{INDEX}]',
    enabled: true,
    severity: 'critical',
    examples: ['A12345678', 'C98765432']
  }
];
