import type { DetectionRule } from '../../types';
import { cloudSecretRules } from './cloudSecrets';
import { credentialRules } from './credentials';
import { piiRules } from './pii';
import { phiRules } from './phi';
import { financialRules } from './financial';
import { networkRules } from './network';

export const allDefaultRules: DetectionRule[] = [
  ...cloudSecretRules,
  ...credentialRules,
  ...piiRules,
  ...phiRules,
  ...financialRules,
  ...networkRules
];

export * from './cloudSecrets';
export * from './credentials';
export * from './pii';
export * from './phi';
export * from './financial';
export * from './network';

export { isValidLuhn } from './financial';
