import type {  FieldMapping, MaskingStrategy, RuleCategory, DetectionRule  } from '../types';

export class ConsistencyVault {
  private mappings: Map<string, FieldMapping> = new Map();
  private reverseMap: Map<string, string> = new Map();
  private counters: Map<string, number> = new Map();

  constructor() {
    this.reset();
  }

  public reset(): void {
    this.mappings.clear();
    this.reverseMap.clear();
    this.counters.clear();
  }

  public getOrCreate(
    originalValue: string,
    category: RuleCategory,
    rule: DetectionRule,
    strategy: MaskingStrategy = 'consistent_token'
  ): string {
    const key = `${category}::${originalValue}`;

    if (this.mappings.has(key)) {
      const existing = this.mappings.get(key)!;
      existing.occurrences += 1;
      return existing.maskedValue;
    }

    let maskedValue = '';

    if (strategy === 'static_redact') {
      maskedValue = rule.replacementTemplate.replace(/_\{INDEX\}/g, '');
    } else if (strategy === 'hash') {
      let hash = 0;
      for (let i = 0; i < originalValue.length; i++) {
        hash = (hash << 5) - hash + originalValue.charCodeAt(i);
        hash |= 0;
      }
      const hex = Math.abs(hash).toString(16).padStart(6, '0').slice(0, 6).toUpperCase();
      maskedValue = `[HASH_${hex}]`;
    } else if (strategy === 'partial') {
      if (category === 'pii' && originalValue.includes('@')) {
        const [user, domain] = originalValue.split('@');
        maskedValue = user.length > 2 
          ? `${user[0]}***${user[user.length - 1]}@${domain}`
          : `***@${domain}`;
      } else if (originalValue.length > 8) {
        maskedValue = `${originalValue.slice(0, 3)}****${originalValue.slice(-3)}`;
      } else {
        maskedValue = '[REDACTED]';
      }
    } else {
      // Default: consistent_token with sequential index
      const counterKey = rule.id || category;
      const count = (this.counters.get(counterKey) || 0) + 1;
      this.counters.set(counterKey, count);

      if (rule.replacementTemplate.includes('{INDEX}')) {
        maskedValue = rule.replacementTemplate.replace('{INDEX}', count.toString());
      } else {
        maskedValue = `${rule.replacementTemplate.replace(/]$/, '')}_${count}]`;
      }
    }

    const mapping: FieldMapping = {
      id: `map_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      originalValue,
      maskedValue,
      category,
      ruleId: rule.id,
      ruleName: rule.name,
      occurrences: 1,
      firstSeen: Date.now()
    };

    this.mappings.set(key, mapping);
    this.reverseMap.set(maskedValue, originalValue);

    return maskedValue;
  }

  public getAllMappings(): FieldMapping[] {
    return Array.from(this.mappings.values());
  }

  public getOriginal(maskedToken: string): string | undefined {
    return this.reverseMap.get(maskedToken);
  }

  public exportAsJSON(): string {
    return JSON.stringify(Array.from(this.mappings.values()), null, 2);
  }

  public exportAsCSV(): string {
    const headers = ['Category', 'Rule Name', 'Masked Token', 'Original Value', 'Occurrences'];
    const rows = Array.from(this.mappings.values()).map(m => [
      `"${m.category}"`,
      `"${m.ruleName.replace(/"/g, '""')}"`,
      `"${m.maskedValue}"`,
      `"${m.originalValue.replace(/"/g, '""')}"`,
      m.occurrences
    ]);
    return [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
  }
}

export const globalVault = new ConsistencyVault();
