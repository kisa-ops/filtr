# filtr — HTTP API Reference & Integration Guide

> **Version:** 3.1  |  **Last Updated:** 2026-09-29  |  **Build:** Production

`filtr` is an enterprise-grade **Ingress/Egress Sanitization and Reversible Hydration API**. It intercepts prompts destined for LLMs, strips sensitive secrets/PII in real-time, and reversibly restores tokens on egress — fully in-memory, zero persistence.

---

## 1. Architectural Flow

```
  Client App / Developer
        │  (1) Raw payload containing secrets, PII
        ▼
  Enterprise Gateway (NGFW / Envoy / Kong / Cloudflare Worker)
        │  (2) POST /api/v1/sanitize
        ▼
  ┌─────────────────────────────────────────────────┐
  │              filtr Engine                        │
  │  • 340+ detection rules across 7 categories     │
  │  • Luhn validation (credit cards)                │
  │  • IPv4 false-positive suppression               │
  │  • Min-length guard (≥3 chars)                  │
  │  • Stateful session vault (in-memory, TTL 1h)   │
  │  • Sliding-window rate limiter (120 RPM/IP)      │
  │  • CWE-532 zero-persistence audit logger         │
  └─────────────────────────────────────────────────┘
        │  (3) Sanitized payload + session_id
        ▼
  External LLM (OpenAI / Claude / Gemini / Llama)
        │  (4) LLM response (contains masked tokens)
        ▼
  Enterprise Gateway
        │  (5) POST /api/v1/hydrate with session_id
        ▼
  filtr Hydration Vault  →  Restored original values
        │
        ▼
  Client App / Developer (receives fully restored text)
```

---

## 2. Authentication & Authorization

All API endpoints require a **Bearer token** in the `Authorization` header.

```http
Authorization: Bearer <your-api-key>
Content-Type: application/json
```

| Auth Level | Header Value | Permissions |
|---|---|---|
| **Admin** | `Bearer admin-<key>` | Full access: rules CRUD, session management, audit logs |
| **Standard** | `Bearer <key>` | Sanitize, hydrate, session read |
| **Read-Only** | `Bearer ro-<key>` | Session read, stats only |

> Tokens are validated by `authService.ts`. Invalid/missing tokens return `401 Unauthorized`.

---

## 3. Core Endpoints

### 3.1 `POST /api/v1/sanitize`

Scans and masks all detected secrets, PII, credentials, and financial data in the input payload. Returns a `session_id` for subsequent hydration.

#### Request Schema

Supports three payload formats:

**A. Single text string**
```json
{
  "text": "Deploy DB with password=SuperSecret123! for admin@acme.com",
  "masking_strategy": "consistent_token"
}
```

**B. OpenAI-style messages array**
```json
{
  "messages": [
    { "role": "system", "content": "You are a DevOps assistant." },
    { "role": "user",   "content": "AWS key AKIAIOSFODNN7EXAMPLE, pass=P@ssw0rd" }
  ],
  "masking_strategy": "synthetic"
}
```

**C. Raw prompt string**
```json
{
  "prompt": "Summarize: postgres://admin:secret@db.prod.internal:5432/core",
  "masking_strategy": "consistent_token"
}
```

#### Request Parameters

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `text` \| `messages` \| `prompt` | string \| array | **Yes** | — | Input payload (one of the three formats) |
| `masking_strategy` | string | No | `consistent_token` | One of: `consistent_token`, `synthetic`, `static_redact`, `partial`, `hash` |
| `rules` | string[] | No | all enabled | Array of rule IDs to apply (subset of enabled rules) |
| `reset_session` | boolean | No | `true` | Whether to create a fresh session vault for this request |

#### Response (`200 OK`)

```json
{
  "success": true,
  "sanitized_text": "Deploy DB with password=[PASSWORD_1] for [EMAIL_1]",
  "session_id": "fa581c27-7f8b-4e25-a648-dab2693d0db4",
  "session_expires_at": "2026-09-29T23:58:40.000Z",
  "masking_strategy": "consistent_token",
  "redactions": [
    {
      "rule_id": "generic_password_assignment",
      "rule_name": "Password / Passphrase Assignment in Config / Log",
      "category": "credentials",
      "severity": "critical",
      "masked_token": "[PASSWORD_1]",
      "start": 27,
      "end": 45
    },
    {
      "rule_id": "email_address",
      "rule_name": "Email Address",
      "category": "pii",
      "severity": "high",
      "masked_token": "[EMAIL_1]",
      "start": 50,
      "end": 64
    }
  ],
  "stats": {
    "totalRedacted": 2,
    "byCategory": {
      "credentials": 1,
      "pii": 1,
      "cloud": 0,
      "network": 0,
      "financial": 0,
      "phi": 0,
      "devops": 0
    },
    "bytesProcessed": 64,
    "processingTimeMs": 1.8
  }
}
```

#### Error Responses

| HTTP Code | Error | Cause |
|---|---|---|
| `400` | `invalid_payload` | Missing or malformed request body |
| `400` | `text_too_large` | Input exceeds 2MB string limit |
| `401` | `unauthorized` | Missing or invalid Bearer token |
| `413` | `request_too_large` | Request body exceeds 5MB limit |
| `429` | `rate_limit_exceeded` | Sliding-window limit hit (120 RPM per IP) |
| `500` | `processing_error` | Internal regex engine failure |

---

### 3.2 `POST /api/v1/hydrate`  _(alias: `POST /api/v1/deanonymize`)_

Reverses masked tokens back to original values using the in-memory session vault keyed by `session_id`.

#### Request Schema

```json
{
  "text": "Verified key [AWS_KEY_1] for user [EMAIL_1]. Access granted.",
  "session_id": "fa581c27-7f8b-4e25-a648-dab2693d0db4"
}
```

Also accepts `messages` array or `prompt` string formats.

#### Response (`200 OK`)

```json
{
  "success": true,
  "hydrated_text": "Verified key AKIAIOSFODNN7EXAMPLE for user admin@acme.com. Access granted.",
  "session_id": "fa581c27-7f8b-4e25-a648-dab2693d0db4",
  "hydrated_tokens": 2
}
```

#### Notes
- Tokens are matched **longest-first** to prevent partial token substitution.
- Hydrating an expired or purged session returns `400` with `session_not_found`.
- Raw original values are **never logged** (CWE-532 compliance).

---

### 3.3 `GET /api/v1/session/:id`

Returns diagnostic metadata for an active session vault. **Does not expose original secret values.**

#### Response (`200 OK`)

```json
{
  "success": true,
  "session_id": "fa581c27-7f8b-4e25-a648-dab2693d0db4",
  "created_at": "2026-09-29T22:58:40.000Z",
  "expires_at": "2026-09-29T23:58:40.000Z",
  "last_accessed_at": "2026-09-29T22:58:41.000Z",
  "unique_tokens_count": 5,
  "total_mappings_count": 8,
  "categories_detected": ["pii", "credentials", "cloud"]
}
```

---

### 3.4 `DELETE /api/v1/session/:id`

Immediately purges a session vault. Subsequent hydration requests with this `session_id` return `400`.

```json
{
  "success": true,
  "deleted": true,
  "message": "Session 'fa581c27-...' successfully purged."
}
```

---

### 3.5 `GET /api/v1/rules`

Returns all currently enabled detection rules with metadata.

#### Response (`200 OK`)

```json
{
  "success": true,
  "total": 340,
  "rules": [
    {
      "id": "aws_access_key",
      "name": "AWS Access Key ID",
      "category": "cloud",
      "severity": "critical",
      "enabled": true,
      "description": "Matches 20-char AWS IAM access key IDs starting with AKIA/ASIA/AROA"
    }
  ]
}
```

---

### 3.6 `GET /api/v1/stats`

Returns aggregate processing statistics since server start.

```json
{
  "success": true,
  "uptime_seconds": 86400,
  "total_requests": 14823,
  "total_redactions": 92441,
  "by_category": {
    "cloud": 31200,
    "credentials": 22800,
    "pii": 18900,
    "network": 9800,
    "financial": 6200,
    "phi": 2100,
    "devops": 1441
  },
  "avg_processing_ms": 2.1,
  "active_sessions": 42
}
```

---

## 4. Detection Rules — Full Catalogue

**Total rules: ~340** across 7 categories.

### 4.1 Cloud & API Secrets (39 rules)
| Rule ID | Detects | Severity |
|---|---|---|
| `aws_access_key` | AWS IAM Access Key (AKIA/ASIA/AROA prefix) | Critical |
| `aws_secret_key` | AWS Secret Access Key (40-char base64) | Critical |
| `aws_session_token` | AWS STS Session Token | Critical |
| `gcp_service_account_key` | GCP service account JSON key | Critical |
| `gcp_api_key` | GCP API Key (AIza prefix) | Critical |
| `azure_storage_key` | Azure Storage Account Key (base64, 88 chars) | Critical |
| `azure_client_secret` | Azure AD Client Secret | Critical |
| `github_token` | GitHub PAT (ghp\_, gho\_, ghs\_, ghr\_) | Critical |
| `gitlab_token` | GitLab PAT (glpat- prefix) | Critical |
| `openai_api_key` | OpenAI / sk-proj- API key | Critical |
| `anthropic_api_key` | Anthropic Claude key (sk-ant-) | Critical |
| `huggingface_token` | HuggingFace token (hf\_) | Critical |
| `jwt_token` | JSON Web Token (eyJ... three segments) | High |
| `bearer_token` | Generic `Authorization: Bearer <token>` | High |
| `slack_token` | Slack Bot/User token (xox\*-) | Critical |
| `stripe_api_key` | Stripe secret key (sk\_live\_, rk\_live\_) | Critical |
| `sendgrid_api_key` | SendGrid API key (SG. prefix) | Critical |
| `private_key` | RSA/DSA/EC/OpenSSH PEM private key block | Critical |
| `db_connection_url` | postgres/mysql/mongodb/redis connection URI | Critical |
| `jwt_token` | JWT in three base64 segments | High |
| `vault_token` | HashiCorp Vault token (hvs./s.) | Critical |
| `docker_hub_token` | Docker Hub PAT (dckr\_pat\_) | Critical |
| `kubernetes_service_account` | K8s ServiceAccount JWT | Critical |
| `terraform_cloud_token` | Terraform Cloud API token | Critical |
| `twilio_credentials` | Twilio Account SID (AC prefix) | High |
| `oci_auth_token` | Oracle Cloud Auth Token | Critical |
| `oci_db_connect_string` | Oracle Cloud TNS / JDBC connection | Critical |
| *(+ 12 more cloud provider rules)* | Azure, GCP, OCI, Alibaba Cloud variants | Critical |

### 4.2 Credentials & Secrets (16 rules)
| Rule ID | Detects | Severity |
|---|---|---|
| `generic_api_key_assignment` | `api_key = "..."`, `CLIENT_SECRET: "..."` | Critical |
| `generic_password_assignment` | `password=`, `DB_PASSWORD:`, `passwd =` | Critical |
| `url_embedded_credentials` | `https://user:pass@host` in URLs | Critical |
| `base64_encoded_secret` | `SECRET=dGhpcyBp...` base64 in env dumps | High |
| `bcrypt_hash` | bcrypt password hash `$2a$...` | High |
| `argon2_hash` | Argon2id hash `$argon2id$...` | Critical |
| `private_ssh_key` | OpenSSH/RSA private key PEM | Critical |
| `pgp_private_key` | PGP armored private key block | Critical |
| *(+ 8 more credential rules)* | PBKDF2, scrypt, MD5 crypt, Windows NTLM | High |

### 4.3 PII — Personally Identifiable Information (23 rules)
| Rule ID | Detects | Severity |
|---|---|---|
| `email_address` | Standard email addresses | High |
| `phone_number_e164` | E.164 international phone (`+1-800-...`) | Medium |
| `us_ssn` | US Social Security Number (`XXX-XX-XXXX`) | Critical |
| `us_drivers_license` | US Driver's License numbers | High |
| `us_passport` | US Passport numbers | Critical |
| `uk_nino` | UK National Insurance Number | Critical |
| `uuid_v4` | UUID v4 (user/session/transaction IDs) | Medium |
| `indian_pan_card` | Indian PAN Card (`ABCDE1234F`) | Critical |
| `indian_mobile_number` | Indian mobile `+91 98765 43210` | High |
| `json_user_id_field` | `"userId": "usr_abc"` in JSON logs | High |
| `json_email_field` | `"email": "a@b.com"` in JSON logs | High |
| `gcc_passport` | Saudi/UAE/Qatar/Kuwait/Oman passports | Critical |
| `oman_civil_id` | Oman Civil ID | Critical |
| `australian_tfn` | Australian Tax File Number | Critical |
| `french_insee_nir` | French INSEE/NIR social security | Critical |
| `spanish_dni_nie` | Spanish DNI/NIE identity number | Critical |
| *(+ 7 more PII rules)* | Canadian SIN, German ID, Korean RRN, etc. | Critical |

### 4.4 PHI — Protected Health Information (4 rules)
| Rule ID | Detects | Severity |
|---|---|---|
| `medical_record_number` | MRN / patient\_id values | Critical |
| `npi_provider_id` | US NPI (National Provider Identifier) | High |
| `health_insurance_claim` | Medicare/insurance claim numbers (HICN) | Critical |
| `health_plan_member_id` | Insurance member/policy ID | Critical |

### 4.5 Financial (6 rules)
| Rule ID | Detects | Severity |
|---|---|---|
| `credit_card` | Visa/MC/Amex/Discover (Luhn-validated) | Critical |
| `iban_number` | IBAN (15–34 char, ISO country prefix) | Critical |
| `aba_routing` | US ABA bank routing number (9 digits) | High |
| `swift_bic_code` | SWIFT BIC (with keyword context guard) | Medium |
| `crypto_ethereum_wallet` | Ethereum/EVM wallet (`0x` + 40 hex) | High |
| `crypto_bitcoin_wallet` | Bitcoin P2PKH, P2SH, Bech32 addresses | High |

### 4.6 Network & Infrastructure (8 rules)
| Rule ID | Detects | Severity |
|---|---|---|
| `ipv4_address` | IPv4 (with version-string false-positive guard) | High |
| `ipv6_address` | IPv6 full/compressed notation | Medium |
| `mac_address` | Ethernet MAC address | Medium |
| `internal_hostname` | `.internal`, `.corp`, `.local`, `.lan` FQDNs | High |
| `private_rfc1918_ip` | RFC 1918 private subnets (10.x, 172.16.x, 192.168.x) | Medium |
| `aws_private_ec2_hostname` | AWS internal EC2 DNS hostname | High |
| `url_with_token_param` | URLs with `?token=` / `?api_key=` params | Critical |
| `internal_path_with_username` | `/home/username/` filesystem paths | Medium |

---

## 5. Masking Strategies

| Strategy | Token Format | Reversible | Best For |
|---|---|---|---|
| `consistent_token` *(default)* | `[AWS_KEY_1]`, `[EMAIL_3]` | ✅ Yes (via session) | LLM chat — consistent token references across multi-turn conversations |
| `synthetic` | `Alexander Vance`, `alex@fictitious-corp.net` | ✅ Yes (via session) | Context-aware LLM reasoning where realistic grammar and data are needed |
| `static_redact` | `[AWS_KEY]`, `[EMAIL]` | ❌ No | Compliance archiving, audit logs, one-way sanitization |
| `partial` | `a***n@corp.com`, `AKIA****7XYZ` | ❌ No | User-facing previews, debugging |
| `hash` | `[HASH_9A3B7C2D1E4F5678]` | ✅ Yes (within session) | Cryptographic pseudonymization, relational integrity testing |

---

## 6. Security Controls

| Threat | CWE | Defense |
|---|---|---|
| Memory exhaustion | CWE-400 | 5MB body cap; 2MB per text field; max 10,000 sessions with LRU eviction |
| Regex ReDoS | CWE-1333 | Max 1,000 matches per rule; bounded quantifiers; per-rule latency monitoring |
| Secret leakage in logs | CWE-532 | Audit logger records only: IP, rule IDs, category counts, timing. Zero raw values written |
| Token deanonymization | CWE-200 | Reverse map stored in volatile memory only; cryptographic UUID session keys; 1h TTL |
| API abuse | CWE-799 | In-memory sliding-window rate limiter: 120 RPM per authenticated IP; `Retry-After` header on 429 |
| Credit card false positives | CWE-399 | Luhn algorithm validates every card match before masking |
| IPv4 false positives | — | Guards against version strings (`v1.2.3.4`) adjacent to letters; validates all 4 octets ≤255 |
| Short-string false positives | — | Minimum 3-character match length enforced across all rules |
| CSV formula injection | CWE-1236 | ConsistencyVault CSV export prepends `'` to formula-trigger characters |

---

## 7. ConsistencyVault — JavaScript/TypeScript SDK

The `ConsistencyVault` class (in `src/engine/consistencyMap.ts`) is the in-memory session store. It can be used directly in Node.js integrations:

```typescript
import { ConsistencyVault } from './engine/consistencyMap';
import { scrubText } from './engine/rulesEngine';
import { allDefaultRules } from './engine/detectors';

const vault = new ConsistencyVault();

// Sanitize
const { sanitizedText, stats } = scrubText(
  'AWS key AKIAIOSFODNN7EXAMPLE for dev@acme.com',
  allDefaultRules,
  vault,
  { maskingStrategy: 'consistent_token' }
);
// → "AWS key [AWS_KEY_1] for [EMAIL_1]"

// Hydrate (restore)
const { hydratedText, tokensHydrated } = vault.hydrate(
  'Confirmed: [AWS_KEY_1] belongs to [EMAIL_1]'
);
// → "Confirmed: AKIAIOSFODNN7EXAMPLE belongs to dev@acme.com"

// Export vault mappings
console.log(vault.exportAsJSON()); // JSON format
console.log(vault.exportAsCSV());  // CSV format (formula-injection safe)
```

### ConsistencyVault API

| Method | Signature | Returns | Description |
|---|---|---|---|
| `getOrCreate` | `(value, category, rule, strategy)` | `string` | Get existing token or create new masked replacement |
| `getOriginal` | `(maskedToken: string)` | `string \| undefined` | Reverse-lookup: token → original value |
| `hydrate` | `(text: string)` | `{ hydratedText, tokensHydrated }` | Replace all tokens in text with original values |
| `getAllMappings` | `()` | `FieldMapping[]` | All current vault mappings (no raw secrets in keys) |
| `exportAsJSON` | `()` | `string` | Vault as JSON array |
| `exportAsCSV` | `()` | `string` | Vault as CSV (formula-injection safe per CWE-1236) |
| `reset` | `()` | `void` | Clear all mappings, counters, and reverse map |

---

## 8. Excel / CSV File Sanitization Engine

The `ExcelSanitizer` component (`src/components/excel/ExcelSanitizer.tsx`) and supporting engine (`src/engine/columnTransformers.ts`) provide spreadsheet-level sanitization:

### columnTransformers.ts API

```typescript
import {
  detectHeaderRow,
  detectColumnSensitivity,
  generateColumnSynthetic,
  applyPartialMask,
  transformCell,
  processSpreadsheetInChunks
} from './engine/columnTransformers';
```

| Function | Description |
|---|---|
| `detectHeaderRow(rawMatrix)` | Scores first 12 rows; returns 1-based header row index (0 = no header) |
| `detectColumnSensitivity(headerName, samples[])` | Majority-vote type detection across ≥5 sample values; returns type + suggested action |
| `generateColumnSynthetic(value, subtype, colName, rowIndex)` | Generates contextually accurate fake data matching the original type and format |
| `applyPartialMask(value)` | Smart partial masking: emails, card numbers, SSNs, general strings |
| `transformCell(rawValue, rule, rowIndex, vault?)` | Applies mask/redact/synthetic rule to a single cell |
| `processSpreadsheetInChunks(rows, headers, rules, vault?, opts)` | Async chunked processor (500 rows/tick) for large datasets without UI freeze |

### Supported Synthetic Subtypes

| Subtype | Example Output |
|---|---|
| `name` | `Alexander Vance`, `Sophia Sterling` |
| `email` | `a.vance@fictitious-corp.net` |
| `phone` | `+1-415-555-0182` |
| `address` | `742 Evergreen Terrace, Portland, OR 97201` |
| `company` | `Apex Global Systems`, `Kestrel Data Systems` |
| `currency` | `$87,400` (proportional ±20% of original), `€1,234.56` |
| `date` | Format-preserving: `MM/DD/YYYY`, `YYYY-MM-DD`, `MM/YY` |
| `credit_card` | Luhn-valid test card: `4532-0150-8921-1044` |
| `ip` | RFC 5737 non-routable: `192.0.2.45` |
| `uuid` | UUID v4 format |
| `id_code` | Format-preserving: `EMP-0042` → `EMP-9387` |
| `number` | Proportional ±15% with matching decimal precision |
| `auto` | Value-pattern detection first, then header semantics fallback |

### Excel Format Preservation

Output `.xlsx` files preserve **100%** of original formatting via in-place OpenXML patching (`src/engine/excelPreserver.ts`):
- ✅ Cell background fills, fonts, borders, number formats (`xl/styles.xml` untouched)
- ✅ Theme colors, effects, gradients (`xl/theme/theme1.xml` untouched)
- ✅ Column widths, row heights, merged cells
- ✅ Conditional formatting rules
- ✅ Header/title rows (skipped during patching)
- ⚠️ `.xls` (legacy binary): formatting **not** preserved — convert to `.xlsx` first
- ⚠️ `.csv`: inherently plain text, no formatting possible

---

## 9. Ready-to-Run Examples

### cURL — Full Ingress → LLM → Hydration Flow

```bash
# 1. Sanitize ingress prompt
RESPONSE=$(curl -s -X POST http://127.0.0.1:3000/api/v1/sanitize \
  -H "Authorization: Bearer $FILTR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "AWS key AKIAIOSFODNN7EXAMPLE for admin@acme.com, password=P@ssw0rd123",
    "masking_strategy": "consistent_token"
  }')

SESSION_ID=$(echo "$RESPONSE" | jq -r .session_id)
SAFE_TEXT=$(echo "$RESPONSE" | jq -r .sanitized_text)
echo "Sanitized: $SAFE_TEXT"
# → "AWS key [AWS_KEY_1] for [EMAIL_1], password=[PASSWORD_1]"

# 2. Send $SAFE_TEXT to your LLM, capture response
LLM_REPLY="Confirmed: revoked [AWS_KEY_1] for [EMAIL_1]"

# 3. Hydrate the LLM reply
curl -s -X POST http://127.0.0.1:3000/api/v1/hydrate \
  -H "Authorization: Bearer $FILTR_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"text\": \"$LLM_REPLY\", \"session_id\": \"$SESSION_ID\"}" | jq .
# → "Confirmed: revoked AKIAIOSFODNN7EXAMPLE for admin@acme.com"

# 4. Cleanup
curl -s -X DELETE http://127.0.0.1:3000/api/v1/session/$SESSION_ID \
  -H "Authorization: Bearer $FILTR_API_KEY"
```

### Python (`requests`)

```python
import requests

FILTR = "http://127.0.0.1:3000"
HEADERS = {"Authorization": "Bearer <your-api-key>", "Content-Type": "application/json"}

# 1. Sanitize
resp = requests.post(f"{FILTR}/api/v1/sanitize", headers=HEADERS, json={
    "messages": [
        {"role": "system", "content": "You are a DevOps assistant."},
        {"role": "user",   "content": "Deploy with key AKIAIOSFODNN7EXAMPLE and pass=P@ssw0rd"}
    ],
    "masking_strategy": "consistent_token"
}).json()

session_id   = resp["session_id"]
safe_messages = resp["messages"]
print("Safe messages sent to LLM:", safe_messages)

# 2. Simulate LLM response containing tokens
llm_output = {"messages": [{"role": "assistant",
    "content": "Rotating [AWS_KEY_1] — notifying [EMAIL_1]"}], "session_id": session_id}

# 3. Hydrate egress
hydrated = requests.post(f"{FILTR}/api/v1/hydrate", headers=HEADERS, json=llm_output).json()
print("Restored for user:", hydrated["messages"])

# 4. Purge session
requests.delete(f"{FILTR}/api/v1/session/{session_id}", headers=HEADERS)
```

### Node.js / TypeScript

```typescript
const FILTR = 'http://127.0.0.1:3000';
const HEADERS = { 'Content-Type': 'application/json', 'Authorization': 'Bearer <key>' };

async function sanitizeAndHydrate(userInput: string) {
  // Sanitize
  const s = await fetch(`${FILTR}/api/v1/sanitize`, {
    method: 'POST', headers: HEADERS,
    body: JSON.stringify({ text: userInput, masking_strategy: 'consistent_token' })
  }).then(r => r.json());

  const { sanitized_text, session_id } = s;
  
  // Forward sanitized_text to LLM (your code here)
  const llmReply = `Result for [EMAIL_1]: access revoked for [AWS_KEY_1]`;

  // Hydrate
  const h = await fetch(`${FILTR}/api/v1/hydrate`, {
    method: 'POST', headers: HEADERS,
    body: JSON.stringify({ text: llmReply, session_id })
  }).then(r => r.json());

  // Cleanup
  await fetch(`${FILTR}/api/v1/session/${session_id}`, { method: 'DELETE', headers: HEADERS });

  return h.hydrated_text;
}
```

---

## 10. Changelog

| Version | Date | Changes |
|---|---|---|
| **3.1** | 2026-09-29 | +10 new detection rules: UUID v4, Indian PAN/mobile, JSON field detectors, URL token params, filesystem path usernames, generic password/API-key assignments, base64 secrets, URL-embedded credentials. SWIFT BIC false-positive fix (now requires keyword context). IPv4 version-string guard. Min 3-char match guard. Excel: click-to-set header row, drag-drop upload, 5-sample column detection, Unicode-safe currency synthesis. |
| **3.0** | 2026-09-22 | Excel/CSV sanitization engine, OpenXML in-place format preservation, header row auto-detection algorithm, proportional synthetic data generation. |
| **2.5** | 2026-09-15 | Luhn credit card validation, GCC/Middle East PII rules, Australian TFN, French INSEE, Spanish DNI. |
| **2.0** | 2026-09-01 | Multi-cloud secret detection (AWS/GCP/Azure/OCI), JWT/Bearer token rules, ConsistencyVault hydration API. |
| **1.0** | 2026-08-15 | Initial release: PII, credentials, network rules, sliding-window rate limiter. |
