# filtr System Architecture & Data Persistence Specification

## 1. Executive Summary & Architectural Philosophy

**filtr** is an enterprise-grade, privacy-first data sanitization and de-identification platform designed to sanitize sensitive corporate text, structured log streams, and multi-sheet spreadsheets before they are transmitted to Generative AI models, third-party LLMs, code analyzers, or external vendors.

### Core Architectural Principles
1. **Zero-Knowledge / Zero-Transmission Architecture**: Sensitive data is processed **strictly within the client's browser execution context**. No text, logs, spreadsheets, API keys, or database records are ever transmitted to an external server or telemetry collector.
2. **Local-First Persistence Model**: Configuration parameters, administrative authentication hashes, and custom detection policies are stored using client-side browser storage APIs and exportable JSON manifests, eliminating the attack surface of centralized cloud databases.
3. **Stateless Edge Delivery**: The backend Docker container operates exclusively as a hardened, stateless static web server (Nginx on Alpine Linux) with optional TLS termination.
4. **Air-Gap & Offline Resilience**: filtr requires zero outbound internet connectivity at runtime, making it fully operational in classified, air-gapped, and restricted enterprise VPC environments.

---

## 2. High-Level Architecture

```
+-----------------------------------------------------------------------------------------------+
|                                      CLIENT BROWSER CONTEXT                                    |
|                                                                                               |
|  +-----------------------------------------------------------------------------------------+  |
|  |                                  USER INTERFACE LAYER                                   |  |
|  |   Text Sanitizer          Log Stream Processor               Excel Spreadsheet          |  |
|  |  (Live Regex / Fast)    (Chunked Multi-file Stream)          (In-Memory SheetJS)         |  |
|  +-----------------------------------------------------------------------------------------+  |
|                                              |                                                |
|  +-----------------------------------------------------------------------------------------+  |
|  |                            CORE SANITIZATION ENGINE (RAM)                               |  |
|  |  - Multi-Category Detector Matrix (PII, Financial, Cloud Secrets, Enterprise Identifiers) |  |
|  |  - ReDoS-Safe Regex Pipeline (Pre-compiled & Validated)                                  |  |
|  |  - Masking Strategies (Redact, Mask, Category Replacement, Consistent Pseudonymization)  |  |
|  +-----------------------------------------------------------------------------------------+  |
|             |                                                         |                       |
|             v                                                         v                       |
|  +------------------------------------+             +--------------------------------------+  |
|  |       CONSISTENCY VAULT (RAM)      |             |     ADMIN & AUTH SUBSYSTEM (RAM)     |  |
|  |  - 64-bit FNV-1a / Murmur3 Mixer   |             |  - Web Crypto API PBKDF2 (100k rds)  |  |
|  |  - In-Memory Bidirectional Map     |             |  - Constant-time Hash Comparator     |  |
|  |  - CSV Injection Neutralizer       |             |  - Brute Force Lockout Monitor       |  |
|  +------------------------------------+             +--------------------------------------+  |
|             |                                                         |                       |
|  +----------+---------------------------------------------------------+--------------------+  |
|  |                                CLIENT-SIDE STORAGE APIS                                 |  |
|  |                                                                                         |  |
|  |   localStorage:                                   sessionStorage:                       |  |
|  |   - 'filtr_admin_auth' (PBKDF2 salt/hash)         - 'filtr_admin_session'               |  |
|  |   - 'filtr_auth_lockout' (Attempt tracker)          (Ephemeral 2-hour sliding token)    |  |
|  |   - 'filtr_admin_settings' (Policy & module state)                                      |  |
|  |   - 'filtr_detection_rules' (Enterprise rules)                                          |  |
|  |   - 'filtr_ssl_info' (Public cert metadata only)                                        |  |
|  +-----------------------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------------------+
                                               ^
                                               | HTTP/1.1 or TLS / HTTPS (Port 80 / 443)
                                               | (Stateless Static Bundle Delivery Only)
                                               v
+-----------------------------------------------------------------------------------------------+
|                            PRODUCTION CONTAINER STACK (Docker / Podman)                       |
|                                                                                               |
|  +-----------------------------------------------------------------------------------------+  |
|  |                                  NGINX REVERSE PROXY                                    |  |
|  |  - Unprivileged Alpine Runtime (nobody / nginx non-root)                                |  |
|  |  - Strict Content-Security-Policy (CSP) & Frame/MIME Guard Headers                      |  |
|  |  - Zero API endpoints, Zero databases, Zero telemetry listeners                        |  |
|  |  - TLS Termination Mount: /etc/nginx/ssl (Mapped from host /opt/filtr/ssl)               |  |
|  +-----------------------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------------------+
```

---

## 3. Data Persistence & Database Architecture

A fundamental security requirement of enterprise data sanitization is preventing accidental data leakage through server-side storage, database backups, replication streams, or persistence logging.

### 3.1. Why filtr Does Not Use a Backend Database
Traditional enterprise applications deploy databases such as PostgreSQL, MongoDB, MySQL, or Redis. In the context of a data scrubber, a central database introduces severe compliance and security risks:
- **Centralized Target for Exfiltration**: Storing sanitized data, mapping tables, or raw logs on a database server creates a honeypot susceptible to unauthorized insider access, snapshot leaks, or unencrypted backup exposures.
- **Regulatory Burden (GDPR / HIPAA / SOC2)**: If PII, PHI, or sensitive keys touch a server-side storage medium, the database becomes subject to mandatory audit logs, data deletion requests ("Right to be Forgotten"), and complex compliance controls.
- **Zero-Knowledge Guarantee**: By eliminating backend databases entirely, filtr mathematically guarantees that the server hosting the container has zero knowledge of the data being processed. Even if the host server is fully compromised, an adversary cannot recover previously scrubbed data because none was ever written to disk or transmitted to the container.

---

### 3.2. Persistent Storage Specification

filtr utilizes standard, sandboxed browser storage mechanisms (`localStorage`, `sessionStorage`, and file-based JSON manifests) strictly segregated by origin (`Same-Origin Policy`).

| Storage Key | Storage API | Purpose | Data Schema / Format | Encryption / Security Posture |
| :--- | :--- | :--- | :--- | :--- |
| `filtr_admin_auth` | `localStorage` | Admin authentication credential | `{"salt": "<hex>", "hash": "<hex>", "isConfigured": true, "createdAt": 1741700000000}` | **PBKDF2-HMAC-SHA256** with 100,000 iterations and 16-byte random salt. Plaintext passwords never stored. |
| `filtr_auth_lockout` | `localStorage` | Brute-force rate limiting | `{"failedAttempts": 2, "lockoutUntil": 1741700300000}` | Persisted in `localStorage` so attackers cannot bypass lockout timers by refreshing or reopening tabs. |
| `filtr_admin_settings` | `localStorage` | Policy presets and module enablement | `{"defaultPolicy": "standard", "showPolicyInHeader": true, "requireAuthForVault": true, "allowExportRules": true, "enabledModules": {"text": true, "logs": true, "excel": true}}` | Validated on load. Missing or corrupt keys safely fall back to hardened defaults. |
| `filtr_detection_rules` | `localStorage` | Custom rules & rule toggle states | Array of `DetectionRule` objects (regex patterns, templates, severity, flags) | Sanitized on ingestion against prototype pollution (`__proto__`) and validated with `new RegExp()` syntax compilation. |
| `filtr_ssl_info` | `localStorage` | Certificate inspection cache | `{"commonName": "filtr.corp.internal", "issuer": "Corp CA", "validTo": "...", "fingerprint": "SHA256:...", "daysRemaining": 89}` | **Non-sensitive metadata only**. Private keys (`filtr_saved_key`) are explicitly purged on component mount and auth bootstrap. |
| `filtr_admin_session` | `sessionStorage` | Ephemeral admin session token | `{"token": "<random_token>", "expiresAt": 1741707200000}` | **Sliding 2-hour window**. Bound strictly to active browser tab; automatically incinerated when the browser tab closes. |

---

### 3.3. Transient In-Memory Data (RAM Only)

Data that represents sensitive corporate information is strictly ephemeral and resides only in volatile memory:

1. **Input Payloads & Output Artifacts**:
   - Raw user text inputs, log file chunks, and Excel workbook binary buffers exist only in JavaScript heap variables.
   - Garbage collection immediately reclaims memory upon component unmount, tab refresh, or clear operations.
2. **The Consistency Vault (`ConsistencyVault`)**:
   - Maintains bidirectional mappings between sensitive strings and their consistent pseudonyms (e.g., `john.doe@company.com` <-> `[HASH_A7F39C018E42B6D5]`).
   - The vault index resides **strictly in browser RAM**. It is never written to `localStorage`, `IndexedDB`, cookies, or remote endpoints.
   - Closing the browser tab or clicking "Clear Vault" permanently wipes the mapping from memory.

---

### 3.4. Enterprise Policy Portability & Backup Architecture

To enable enterprise-wide policy consistency without requiring a central database, filtr provides structured file-based portability:

1. **Policy Export (`filtr_enterprise_policy_*.json`)**:
   - Administrators can export the complete active rule configuration (including system patterns, custom enterprise identifiers, and severity flags) as an auditable JSON document.
   - Policy files can be stored in enterprise Git repositories, reviewed via Pull Requests, and distributed across teams.
2. **Policy Import with Defensive Ingestion**:
   - **Prototype Pollution Guard (CWE-1321)**: Imported objects are recursively validated; any payload containing `__proto__`, `constructor`, or `prototype` keys is immediately dropped.
   - **ReDoS / Syntax Validation (CWE-1333)**: Each imported pattern is test-compiled using `new RegExp(pattern, flags)`. Malformed expressions are isolated with descriptive error messaging.
   - **Automated Duplicate Detection**: Imported rules are compared against existing rules using a normalized fingerprint (`pattern + replacementTemplate`). Duplicates are flagged with their conflicting counterpart and tracked without blocking unique rule additions.
3. **Vault Mapping Export**:
   - Allows compliance officers to extract anonymization dictionaries as JSON or CSV.
   - **CSV Formula Injection Defense (CWE-1236)**: Every cell value beginning with dangerous spreadsheet execution triggers (`=`, `+`, `-`, `@`, `\t`, `\r`) is automatically prefixed with a single quotation mark (`'`), neutralizing Remote Code Execution in Microsoft Excel and LibreOffice.

---

## 4. Core Component Subsystems

### 4.1. The Sanitization Engine (`src/engine/`)

The sanitization engine executes a multi-pass pipeline:
1. **Rule Pre-Compilation**: Detection rules are categorized by policy preset (`minimal`, `standard`, `strict`, `gdpr`, `hipaa`, `developer`) and prioritized by severity (`critical`, `high`, `medium`, `low`).
2. **Boundary Anchoring & Whitespace Normalization**:
   - Multi-word keyword phrases (e.g., `Top Secret, Internal Audit`) undergo regex escaping.
   - Whitespace within phrases is dynamically compiled to `\s+` (or `[-_\s]+` when flexible spacing is enabled) to match document variations across line breaks and tabs.
   - Word boundaries (`\b`) ensure precision and eliminate partial word false positives.
3. **Masking Strategies**:
   - `redact`: Replaces matched sensitive tokens with a fixed indicator (e.g., `[REDACTED]`).
   - `mask`: Obfuscates character strings with asterisks (e.g., `4111********1111`).
   - `category`: Replaces tokens with category identifiers (e.g., `[EMAIL_1]`, `[IPV4_2]`).
   - `consistent_token`: Generates a high-entropy 64-bit pseudonym (`[HASH_XXXXXXXXXXXXXXXX]`) using a non-reversible cryptographic avalanche mixer (FNV-1a 64-bit + Murmur3 shift mix). The same token is assigned to repeated instances within a session, preserving relational analysis and log correlation without disclosing identities.

### 4.2. Ingestion Modules

- **Text Sanitizer (`src/components/text/`)**:
  Interactive, dual-pane editor with live redaction preview, copy-to-clipboard, runtime pattern injection, and token breakdown statistics.
- **Log Stream Processor (`src/components/logs/`)**:
  Processes large system log files (`.log`, `.txt`, `.json`, `.csv`) in chunked streams. Redacted files are packaged entirely in-memory using `JSZip` and exported as a unified archive.
- **Excel Sanitizer (`src/components/excel/`)**:
  Leverages in-memory spreadsheet parsing via `SheetJS`. Scans every row and cell across all worksheets, sanitizing sensitive strings while preserving workbook formulas, column headers, and structural integrity.

---

## 5. Security & Cryptographic Architecture

filtr implements defense-in-depth across the browser runtime, network boundary, and container deployment:

### 5.1. Cryptographic Authentication (`src/engine/authService.ts`)
- **PBKDF2 Derivation**: Uses the native browser `crypto.subtle` Web Crypto API with SHA-256 and 100,000 iterations.
- **Salting**: Generates a cryptographically strong 16-byte random salt per deployment via `crypto.getRandomValues()`.
- **Timing Attack Resistance (CWE-208)**: Authentication hash verification utilizes an XOR-accumulator constant-time comparison routine (`constantTimeCompare`) to ensure uniform execution timing regardless of byte discrepancies.
- **Brute-Force Lockout**: Rejects authentication after 5 consecutive failures, imposing an exponential 5-minute cooldown period recorded in `localStorage`.

### 5.2. Browser Security Headers & Content Security Policy (`nginx.conf`)
Every static asset served by the container is delivered with enterprise security headers:
- `Content-Security-Policy`:
  `default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com data:; img-src 'self' data: blob:; connect-src 'self'; object-src 'none'; frame-ancestors 'self'; base-uri 'self';`
- `X-Frame-Options`: `SAMEORIGIN` (mitigates Clickjacking / UI Redressing).
- `X-Content-Type-Options`: `nosniff` (mitigates MIME-type sniffing).
- `X-XSS-Protection`: `1; mode=block`.
- `Referrer-Policy`: `strict-origin-when-cross-origin`.
- `Permissions-Policy`: `camera=(), microphone=(), geolocation=(), payment=()`.
- `server_tokens off`: Suppresses server banner and version disclosure.

### 5.3. Container Hardening (`docker-compose.yml`)
The production Docker container is configured according to least-privilege standards:
- `security_opt: [no-new-privileges:true]`: Prevents container processes from gaining additional privileges via setuid binaries.
- `cap_drop: [ALL]`: Drops all Linux kernel capabilities.
- `cap_add: [CHOWN, SETUID, SETGID, NET_BIND_SERVICE]`: Restricts capabilities strictly to unprivileged port binding and Nginx worker execution.
- `read_only: false`: Only `/tmp` and cache directories are written to during runtime.

---

## 6. Deployment Topology & Data Flow

```
[ Air-Gapped Workstation / Corporate Laptop ]
       |
       | 1. Request static assets: GET /
       v
[ filtr Docker Container (Nginx) ]
       |
       | 2. Returns HTML, JS bundle, CSS, static fonts (Stateless)
       v
[ Browser Engine (V8 / SpiderMonkey / WebKit) ]
       |
       +---> [ LocalStorage: Credentials hash, settings, custom rules ]
       |
       +---> [ RAM Heap: Raw input data, detection regex, vault mappings ]
       |
       +---> [ User downloads sanitized artifact (.txt / .zip / .xlsx) ]
```

### Data Flow Lifecycle
1. **Bootstrap**: The user loads the application URL. Nginx serves the pre-compiled Vite SPA bundle.
2. **Policy Loading**: `App.tsx` reads `filtr_detection_rules` and `filtr_admin_settings` from `localStorage`. If absent, defaults are initialized from `defaultRules.ts`.
3. **Ingestion & Sanitization**: The user inputs text, uploads logs, or drops an Excel spreadsheet.
4. **Execution**: The JavaScript engine processes the input through `scrubText` in browser memory. Mappings are held in `ConsistencyVault`.
5. **Egress**: The user copies or downloads the sanitized output.
6. **Zero Retention**: When the user closes the browser tab, all input data, log buffers, and vault maps evaporate from RAM.

---

## 7. Compliance & Regulatory Alignment Matrix

| Standard / Regulation | filtr Architectural Guarantee |
| :--- | :--- |
| **GDPR (Article 25 & 32)** | *Privacy by Design & Default*. Zero data transmission to backend; pseudonymization performed via 64-bit cryptographic hashing. |
| **HIPAA (Security Rule)** | ePHI never leaves the local workstation. No business associate agreement (BAA) needed with third-party servers. |
| **SOC 2 Type II** | Eliminates server-side data retention, access logging of customer payloads, and database snapshot security boundaries. |
| **PCI-DSS (Requirement 3)** | Primary Account Numbers (PAN) and CVVs are sanitized before developer ingestion without entering cloud log archives. |
