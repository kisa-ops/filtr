import type { DetectionRule } from '../../types';

export const credentialRules: DetectionRule[] = [
  {
    id: 'password_field',
    name: 'Password / Secret in Key-Value',
    category: 'credentials',
    description: 'Matches password or secret parameters in JSON, YAML, or URL query strings',
    pattern: '(?:password|passwd|pwd|client_secret|api_secret|user_password|auth_pass)["\']?\\s*[:=]\\s*["\']([^"\'\\s]{4,})["\']',
    flags: 'i',
    replacementTemplate: '[REDACTED_PASSWORD]',
    enabled: true,
    severity: 'critical'
  },
  {
    id: 'basic_auth_url',
    name: 'Basic Auth Embedded in URL',
    category: 'credentials',
    description: 'Detects username and password embedded in HTTP/HTTPS URLs',
    pattern: '\\b[a-zA-Z0-9+.-]+:\\/\\/[a-zA-Z0-9_.~%-]+:([^\\s@]+)@[a-zA-Z0-9.-]+',
    replacementTemplate: '[BASIC_AUTH_CREDENTIAL]',
    enabled: true,
    severity: 'critical'
  },
  {
    id: 'authorization_basic_header',
    name: 'HTTP Basic Auth Base64 Header',
    category: 'credentials',
    description: 'Matches Base64 encoded Basic Authorization headers',
    pattern: '\\b(?:Basic\\s+)([A-Za-z0-9+/]{20,}={0,2})\\b',
    flags: 'i',
    replacementTemplate: '[BASIC_AUTH_TOKEN_{INDEX}]',
    enabled: true,
    severity: 'high'
  },
  {
    id: 'bcrypt_hash',
    name: 'BCrypt Password Hash',
    category: 'credentials',
    description: 'Detects 60-character standard BCrypt password hashes',
    pattern: '\\$2[abxy]\\$[0-9]{2}\\$[A-Za-z0-9./]{53}',
    replacementTemplate: '[BCRYPT_HASH_{INDEX}]',
    enabled: true,
    severity: 'high'
  },
  {
    id: 'session_cookie',
    name: 'Session ID / Auth Cookie',
    category: 'credentials',
    description: 'Matches session tokens, PHPSESSID, and auth cookie key-values',
    pattern: '(?:session_id|phpsessid|jsessionid|auth_token|connect\\.sid)\\s*=\\s*([a-zA-Z0-9-_]{16,})',
    flags: 'i',
    replacementTemplate: '[SESSION_TOKEN_{INDEX}]',
    enabled: true,
    severity: 'high'
  }
];
