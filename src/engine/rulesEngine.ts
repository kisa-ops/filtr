import type {  DetectionRule, DiffSegment, MaskingStrategy, RedactionStats, ScrubResult  } from '../types';
import { ConsistencyVault } from './consistencyMap';
import { isValidLuhn } from './detectors/financial';

interface MatchItem {
  start: number;
  end: number;
  originalText: string;
  rule: DetectionRule;
  valueToMask: string;
}

export function scrubText(
  rawText: string,
  rules: DetectionRule[],
  vault: ConsistencyVault,
  options: {
    maskingStrategy?: MaskingStrategy;
    preserveNewlines?: boolean;
  } = {}
): ScrubResult {
  const startTime = performance.now();
  const activeRules = rules.filter(r => r.enabled);
  const matches: MatchItem[] = [];

  for (const rule of activeRules) {
    try {
      let pattern = rule.pattern;
      let flagStr = rule.flags || '';
      if (pattern.includes('(?i)')) {
        pattern = pattern.replace(/\(\?i\)/g, '');
        if (!flagStr.includes('i')) flagStr += 'i';
      }
      if (!flagStr.includes('g')) flagStr += 'g';
      const regex = new RegExp(pattern, flagStr);
      let match: RegExpExecArray | null;

      while ((match = regex.exec(rawText)) !== null) {
        if (match[0].length === 0) {
          regex.lastIndex++;
          continue;
        }

        const originalText = match[0];
        let valueToMask = originalText;
        let start = match.index;
        let end = match.index + originalText.length;

        // If regex has capture group 1, mask only that group (e.g. password="secret" or bearer token)
        if (match[1]) {
          valueToMask = match[1];
          const offset = originalText.indexOf(match[1]);
          if (offset !== -1) {
            start = match.index + offset;
            end = start + match[1].length;
          }
        }

        // Luhn validation check for credit cards to prevent false positives
        if (rule.id === 'credit_card') {
          if (!isValidLuhn(valueToMask)) {
            continue;
          }
        }

        matches.push({
          start,
          end,
          originalText: valueToMask,
          rule,
          valueToMask
        });
      }
    } catch (err) {
      console.warn(`Error executing rule ${rule.name}:`, err);
    }
  }

  // Sort matches by start index ascending. For overlapping matches, pick the longest one.
  matches.sort((a, b) => {
    if (a.start !== b.start) return a.start - b.start;
    return (b.end - b.start) - (a.end - a.start);
  });

  const nonOverlapping: MatchItem[] = [];
  let lastEnd = 0;
  for (const m of matches) {
    if (m.start >= lastEnd) {
      nonOverlapping.push(m);
      lastEnd = m.end;
    }
  }

  // Build sanitized text and diff segments
  let sanitizedText = '';
  const diffSegments: DiffSegment[] = [];
  let cursor = 0;
  const statsByCategory = {
    cloud: 0,
    network: 0,
    pii: 0,
    credentials: 0,
    custom: 0,
    phi: 0,
    financial: 0
  };

  for (const match of nonOverlapping) {
    if (match.start > cursor) {
      const plainChunk = rawText.slice(cursor, match.start);
      sanitizedText += plainChunk;
      diffSegments.push({
        type: 'plain',
        text: plainChunk
      });
    }

    const maskedToken = vault.getOrCreate(
      match.valueToMask,
      match.rule.category,
      match.rule,
      options.maskingStrategy || 'consistent_token'
    );

    sanitizedText += maskedToken;
    diffSegments.push({
      type: 'redacted',
      text: maskedToken,
      originalText: match.valueToMask,
      category: match.rule.category,
      ruleName: match.rule.name,
      token: maskedToken
    });

    statsByCategory[match.rule.category] = (statsByCategory[match.rule.category] || 0) + 1;
    cursor = match.end;
  }

  if (cursor < rawText.length) {
    const trailingChunk = rawText.slice(cursor);
    sanitizedText += trailingChunk;
    diffSegments.push({
      type: 'plain',
      text: trailingChunk
    });
  }

  const processingTimeMs = Math.round((performance.now() - startTime) * 100) / 100;
  const totalRedacted = nonOverlapping.length;

  const stats: RedactionStats = {
    totalRedacted,
    byCategory: statsByCategory,
    processingTimeMs,
    bytesProcessed: new TextEncoder().encode(rawText).length
  };

  return {
    sanitizedText,
    diffSegments,
    stats,
    mappings: vault.getAllMappings()
  };
}
