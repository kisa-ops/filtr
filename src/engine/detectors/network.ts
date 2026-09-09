import type { DetectionRule } from '../../types';

export const networkRules: DetectionRule[] = [
  {
    id: 'ipv4_address',
    name: 'IPv4 Address',
    category: 'network',
    description: 'Matches standard IPv4 addresses (excluding version numbers and loopback)',
    pattern: '\\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\b',
    replacementTemplate: '[IP_{INDEX}]',
    enabled: true,
    severity: 'high',
    examples: ['192.168.1.105', '10.240.0.1', '172.16.31.254']
  },
  {
    id: 'ipv6_address',
    name: 'IPv6 Address',
    category: 'network',
    description: 'Matches IPv6 addresses with colon notation',
    pattern: '\\b(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}\\b|\\b(?:[0-9a-fA-F]{1,4}:){1,7}:\\b|\\b:(?::[0-9a-fA-F]{1,4}){1,7}\\b',
    replacementTemplate: '[IPV6_{INDEX}]',
    enabled: true,
    severity: 'medium',
    examples: ['2001:0db8:85a3:0000:0000:8a2e:0370:7334', 'fe80::1']
  },
  {
    id: 'mac_address',
    name: 'Hardware MAC Address',
    category: 'network',
    description: 'Matches hardware Ethernet/Wi-Fi MAC addresses',
    pattern: '\\b(?:[0-9A-Fa-f]{2}[:-]){5}(?:[0-9A-Fa-f]{2})\\b',
    replacementTemplate: '[MAC_{INDEX}]',
    enabled: true,
    severity: 'medium',
    examples: ['00:1B:44:11:3A:B7', '00-14-22-01-23-45']
  },
  {
    id: 'internal_hostname',
    name: 'Internal Hostname & FQDN',
    category: 'network',
    description: 'Detects internal corporate domains (.internal, .corp, .local, .lan, .priv)',
    pattern: '\\b[a-zA-Z0-9-_]+(?:\\.[a-zA-Z0-9-_]+)*\\.(?:internal|corp|local|lan|priv|intranet)\\b',
    replacementTemplate: '[INTERNAL_HOST_{INDEX}]',
    enabled: true,
    severity: 'high',
    examples: ['k8s-worker-01.us-east.corp.internal', 'auth-service.api.priv']
  }
];
