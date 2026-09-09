import type {  DetectionRule, MaskingStrategy  } from '../../types';
import { ConsistencyVault } from '../consistencyMap';
import { scrubText } from '../rulesEngine';

self.onmessage = (e: MessageEvent) => {
  const { id, rawText, rules, strategy } = e.data as {
    id: string;
    rawText: string;
    rules: DetectionRule[];
    strategy: MaskingStrategy;
  };

  try {
    const workerVault = new ConsistencyVault();
    const result = scrubText(rawText, rules, workerVault, { maskingStrategy: strategy });

    self.postMessage({
      id,
      success: true,
      result: {
        sanitizedText: result.sanitizedText,
        stats: result.stats,
        mappings: result.mappings
      }
    });
  } catch (err: any) {
    self.postMessage({
      id,
      success: false,
      error: err.message || 'Worker scrubbing error'
    });
  }
};
