import type { DetectionRule } from '../../types';

export const financialRules: DetectionRule[] = [
  {
    id: 'credit_card',
    name: 'Credit & Debit Card Number',
    category: 'financial',
    description: 'Detects Visa, Mastercard, Amex, Discover, Diners numbers with Luhn verification',
    pattern: '\\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13}|3(?:0[0-5]|[68][0-9])[0-9]{11}|6(?:011|5[0-9]{2})[0-9]{12}|(?:2131|1800|35\\d{3})\\d{11}|\\d{4}[- ]\\d{4}[- ]\\d{4}[- ]\\d{4})\\b',
    replacementTemplate: '[CARD_{INDEX}]',
    enabled: true,
    severity: 'critical',
    examples: ['4532-1488-9234-1120', '5425 2334 3211 4452']
  },
  {
    id: 'iban_number',
    name: 'International Bank Account Number (IBAN)',
    category: 'financial',
    description: 'Matches standard 15 to 34-character International Bank Account Numbers',
    pattern: '\\b[A-Z]{2}[0-9]{2}[A-Z0-9]{4}[0-9]{7}([A-Z0-9]?){0,16}\\b',
    replacementTemplate: '[IBAN_{INDEX}]',
    enabled: true,
    severity: 'critical',
    examples: ['GB29NWBK60161331926819', 'DE89370400440532013000']
  },
  {
    id: 'aba_routing',
    name: 'US ABA Bank Routing Transit Number',
    category: 'financial',
    description: 'Detects 9-digit US Federal Reserve ABA bank routing numbers',
    pattern: '\\b((?:0[1-9])|(?:1[0-2])|(?:2[1-9])|(?:3[0-2])|(?:6[1-9])|(?:7[0-2])|(?:80))\\d{7}\\b',
    replacementTemplate: '[ROUTING_NUM_{INDEX}]',
    enabled: true,
    severity: 'high',
    examples: ['021000021', '121000358']
  },
  {
    id: 'swift_bic_code',
    name: 'SWIFT / BIC Banking Code',
    category: 'financial',
    description: 'Matches 8 or 11-character global bank identifier codes (SWIFT/BIC)',
    pattern: '\\b[A-Z]{6}[A-Z0-9]{2}(?:[A-Z0-9]{3})?\\b',
    replacementTemplate: '[SWIFT_BIC_{INDEX}]',
    enabled: true,
    severity: 'medium',
    examples: ['CHASUS33', 'DEUTDEDBFXX']
  }
];

export function isValidLuhn(cardNumber: string): boolean {
  const sanitized = cardNumber.replace(/[\s-]/g, '');
  if (!/^\d{13,19}$/.test(sanitized)) return false;
  
  let sum = 0;
  let shouldDouble = false;
  for (let i = sanitized.length - 1; i >= 0; i--) {
    let digit = parseInt(sanitized.charAt(i), 10);
    if (shouldDouble) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    sum += digit;
    shouldDouble = !shouldDouble;
  }
  return sum % 10 === 0;
}
