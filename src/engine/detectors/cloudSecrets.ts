import type { DetectionRule } from '../../types';

export const cloudSecretRules: DetectionRule[] = [
  {
    id: 'aws_access_key',
    name: 'AWS Access Key ID',
    category: 'cloud',
    description: 'Matches standard 20-character AWS Access Key IDs starting with AKIA or ASIA',
    pattern: '\\b(A[SK]IA[0-9A-Z]{16})\\b',
    replacementTemplate: '[AWS_KEY_{INDEX}]',
    enabled: true,
    severity: 'critical'
  },
  {
    id: 'aws_secret_key',
    name: 'AWS Secret Access Key',
    category: 'cloud',
    description: 'Detects 40-character AWS Secret Keys in key-value pairs',
    pattern: '(?:aws_secret_access_key|aws_secret|secret_key)[\\s]*[=:][\\s]*["\']?([a-zA-Z0-9/+=]{40})["\']?',
    flags: 'i',
    replacementTemplate: '[AWS_SECRET_{INDEX}]',
    enabled: true,
    severity: 'critical'
  },
  {
    id: 'google_api_key',
    name: 'Google Cloud / Maps API Key',
    category: 'cloud',
    description: 'Matches standard 39-character Google Cloud and Firebase API Keys starting with AIza',
    pattern: '\\b(AIza[0-9A-Za-z\\-_]{35})\\b',
    replacementTemplate: '[GOOGLE_API_KEY_{INDEX}]',
    enabled: true,
    severity: 'critical'
  },
  {
    id: 'github_token',
    name: 'GitHub Token (PAT / OAuth / App)',
    category: 'cloud',
    description: 'Matches standard GitHub PATs and app tokens (ghp_, gho_, ghu_, ghs_, ghr_)',
    pattern: '\\b(gh[pousr]_[A-Za-z0-9_]{30,255}|github_pat_[A-Za-z0-9_]{50,255})\\b',
    replacementTemplate: '[GITHUB_TOKEN_{INDEX}]',
    enabled: true,
    severity: 'critical'
  },
  {
    id: 'gitlab_token',
    name: 'GitLab Personal Access Token',
    category: 'cloud',
    description: 'Detects GitLab PATs starting with glpat-',
    pattern: '\\b(glpat-[0-9a-zA-Z\\-_]{20,})\\b',
    replacementTemplate: '[GITLAB_TOKEN_{INDEX}]',
    enabled: true,
    severity: 'critical'
  },
  {
    id: 'slack_token',
    name: 'Slack Bot & User Token',
    category: 'cloud',
    description: 'Detects Slack Bot, User, or Workspace authorization tokens',
    pattern: '\\b(xox[baprs]-[0-9]{10,13}-[0-9]{10,13}[a-zA-Z0-9-]*)\\b',
    replacementTemplate: '[SLACK_TOKEN_{INDEX}]',
    enabled: true,
    severity: 'critical'
  },
  {
    id: 'slack_webhook',
    name: 'Slack Incoming Webhook URL',
    category: 'cloud',
    description: 'Matches full Slack incoming webhook integration URLs',
    pattern: 'https:\\/\\/hooks\\.slack\\.com\\/services\\/T[0-9A-Z]{8,12}\\/B[0-9A-Z]{8,12}\\/[0-9a-zA-Z]{24}',
    replacementTemplate: '[SLACK_WEBHOOK_{INDEX}]',
    enabled: true,
    severity: 'critical'
  },
  {
    id: 'stripe_api_key',
    name: 'Stripe Secret & Restricted Key',
    category: 'cloud',
    description: 'Detects Stripe API keys starting with sk_live_ or rk_live_',
    pattern: '\\b(?:sk|rk)_(?:live|test)_[0-9a-zA-Z]{24,99}\\b',
    replacementTemplate: '[STRIPE_KEY_{INDEX}]',
    enabled: true,
    severity: 'critical'
  },
  {
    id: 'openai_api_key',
    name: 'OpenAI / LLM API Key',
    category: 'cloud',
    description: 'Matches OpenAI legacy and project API keys (sk-... and sk-proj-...)',
    pattern: '\\bsk-(?:proj-)?[a-zA-Z0-9-_]{32,128}\\b',
    replacementTemplate: '[OPENAI_KEY_{INDEX}]',
    enabled: true,
    severity: 'critical'
  },
  {
    id: 'anthropic_api_key',
    name: 'Anthropic Claude API Key',
    category: 'cloud',
    description: 'Detects Anthropic API tokens starting with sk-ant-',
    pattern: '\\bsk-ant-[a-zA-Z0-9-_]{32,100}\\b',
    replacementTemplate: '[ANTHROPIC_KEY_{INDEX}]',
    enabled: true,
    severity: 'critical'
  },
  {
    id: 'twilio_credentials',
    name: 'Twilio Account SID',
    category: 'cloud',
    description: 'Matches 34-character Twilio Account SIDs starting with AC',
    pattern: '\\bAC[0-9a-fA-F]{32}\\b',
    replacementTemplate: '[TWILIO_SID_{INDEX}]',
    enabled: true,
    severity: 'high'
  },
  {
    id: 'sendgrid_api_key',
    name: 'SendGrid API Key',
    category: 'cloud',
    description: 'Matches standard 69-character SendGrid API keys starting with SG.',
    pattern: '\\bSG\\.[a-zA-Z0-9_\\-]{20,26}\\.[a-zA-Z0-9_\\-]{40,50}\\b',
    replacementTemplate: '[SENDGRID_KEY_{INDEX}]',
    enabled: true,
    severity: 'critical'
  },
  {
    id: 'jwt_token',
    name: 'JSON Web Token (JWT)',
    category: 'cloud',
    description: 'Matches standard three-segment base64 encoded JWTs',
    pattern: '\\b(eyJ[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,})\\b',
    replacementTemplate: '[JWT_TOKEN_{INDEX}]',
    enabled: true,
    severity: 'high'
  },
  {
    id: 'bearer_token',
    name: 'Generic Bearer Token',
    category: 'cloud',
    description: 'Detects authorization Bearer headers and authentication tokens',
    pattern: '(?:bearer\\s+)([a-zA-Z0-9_\\-\\.\\=:_\\+\\/]{24,})',
    flags: 'i',
    replacementTemplate: '[BEARER_TOKEN_{INDEX}]',
    enabled: true,
    severity: 'high'
  },
  {
    id: 'private_key',
    name: 'Private Encryption Key Block',
    category: 'cloud',
    description: 'Detects RSA, DSA, EC, or OpenSSH PEM private keys',
    pattern: '-----BEGIN (?:RSA|DSA|EC|OPENSSH|PGP)?\\s?PRIVATE KEY-----[\\s\\S]*?-----END (?:RSA|DSA|EC|OPENSSH|PGP)?\\s?PRIVATE KEY-----',
    replacementTemplate: '[REDACTED_PRIVATE_KEY]',
    enabled: true,
    severity: 'critical'
  },
  {
    id: 'db_connection_url',
    name: 'Database Connection String',
    category: 'cloud',
    description: 'Matches database URIs with credentials (postgres, mysql, mongodb, redis)',
    pattern: '\\b(?:mongodb(?:\\+srv)?|postgres(?:ql)?|mysql|redis):\\/\\/[^\\s"\'<>]+',
    replacementTemplate: '[DB_CONNECTION_STRING]',
    enabled: true,
    severity: 'critical'
  }
];
