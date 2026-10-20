# Filtr Platform Roadmap: Enterprise Data Redaction & Sanitization Ecosystem

> **Platform Mission**: Transform Filtr into the world's most resilient, zero-trust, high-throughput data redaction platform across all formats (Raw Text, Multi-tier Server Logs, Spreadsheets, PDF/Images, Structured Databases, and AI/LLM Streams) — natively consumable via interactive web applications, high-performance REST/gRPC APIs, enterprise gateway proxies, and programmatic SDKs.

---

## Executive Summary & Architecture Overview

```mermaid
graph TD
    subgraph Ingestion["1. Ingestion Channels"]
        Web[Web Portal / UI]
        API[REST / gRPC Gateway]
        SDK[Python & Node SDKs]
        Proxy[Inline LLM & DB Proxy]
        CLI[Filtr CLI / CI-CD]
    end

    subgraph CoreEngine["2. Redaction & Transformation Core"]
        RegexEngine["Deterministic Engine<br/>(330+ Compliance Patterns)"]
        PresidioEngine["Microsoft Presidio AI NLP<br/>(Contextual Entity NER)"]
        ConsistencyVault["Consistency Vault &<br/>Reverse Hydration Map"]
        SafeRe2["ReDoS Shield &<br/>Linear Regex Sandbox"]
    end

    subgraph Processors["3. Multi-Format Processors"]
        TextProc["Raw Text / Code"]
        LogProc["Multi-tier Server Logs"]
        SpreadsheetProc["Excel (XLSX) / CSV"]
        DocProc["Native PDF & Docx"]
        VisionProc["OCR & Image Bounding Box"]
        StreamProc["NDJSON / Parquet / Kafka"]
    end

    subgraph Security["4. Enterprise Security & Governance"]
        RBAC["SSO / SAML 2.0 / RBAC"]
        SIEM["SIEM & Audit Streaming"]
        CryptoVault["Zero-Knowledge Key Vault"]
        RateLimiter["Adaptive Rate Limiting"]
    end

    Ingestion --> CoreEngine
    CoreEngine --> Processors
    Processors --> Security
```

---

## Current Platform Capabilities (v3.1.x Baseline)

- [x] **Zero-Trust In-Browser Redaction Engine**: 100% client-side text sanitization with token masking, redaction, hashing, and synthetic replacement.
- [x] **Log File Processor**: High-throughput multi-format server log sanitizer (Nginx, Syslog, Log4j, JSON logs) with contextual timeline visualization.
- [x] **Excel & CSV Structure Preserver**: Cellular data sanitization preserving styles, fonts, cell formatting, column dimensions, and OpenXML theme structures.
- [x] **Multi-Sheet Workbook Ingestion**: Dynamic discovery of all worksheets, tabbed sheet switching, and selective sheet processing without cross-sheet data corruption.
- [x] **Granular Per-Column Rule Configuration**: Independent column-level assignment of Masking, Redaction, and Synthetic generation rules with seamless global fallback.
- [x] **Bidirectional Spreadsheet Rehydration Pipeline**: Generation of confidential CSV mapping keys and a dedicated Restore / Rehydrate AI Output workspace.
- [x] **International CSV Delimiter & Encoding Engine**: Automatic detection of European semicolons (`;`), tabs (`	`), pipes (`|`), and commas (`,`) with UTF-8 BOM (`﻿`) export protection.
- [x] **OpenXML Formula Recalculation Engine**: Injected `<calcPr fullCalcOnLoad="1" forceFullCalculation="1"/>` to trigger automatic formula re-computation in Microsoft Excel.
- [x] **Granular Administrative Controls**: Centralized Admin Portal toggles for tabular operations (Mask, Redact, Synthesize) and granular individual sub-format permissions.
- [x] **Presidio AI NLP Integration**: Integrated hybrid NLP entity recognition (`PERSON`, `LOCATION`, `ORGANIZATION`, `NRP`, `MEDICAL_LICENSE`, `DATE_TIME`).
- [x] **Reversible Consistency Vault**: Bidirectional token vault enabling safe downstream AI generation and zero-leak reverse hydration.
- [x] **Authoritative Centralized Policy (SQLite DB)**: Live multi-workstation rule synchronization with SHA-256 integrity verification, instant deduplication, and zero-resurrection differential syncing.
- [x] **Compliance Policy Presets**: Instant SOC 2, GDPR, HIPAA, PCI-DSS, DevOps, and Cloud security presets.

---

## Strategic Platform Pillars

| Pillar | Focus | Ultimate Goal |
| :--- | :--- | :--- |
| **1. Multi-Format Redaction** | Structured, Unstructured & Binary Formats | Redact any enterprise data type (Text, Logs, Excel, CSV, PDF, OCR, Parquet, Audio/Video) with 100% structure preservation. |
| **2. Universal API & Integration** | REST, gRPC, SDKs & Webhooks | Integrate seamlessly into CI/CD pipelines, ETL pipelines, microservices, and backend workflows with sub-10ms response times. |
| **3. Inline Proxy & Gateways** | Transparent AI & Database Interception | Deploy as an inline transparent reverse proxy for LLM providers (OpenAI, Anthropic, vLLM) and database wire protocols. |
| **4. Security & Vulnerability Defense** | Hardening, Zero-Knowledge & CWE Shielding | Eliminate ReDoS attack surfaces, implement enterprise mTLS, zeroize memory buffers, and achieve complete zero-retention compliance. |
| **5. Stability & Scale Engineering** | Streaming, Chunking & Concurrency | Support 500MB+ log processing, gigabyte spreadsheets, and 10,000+ RPS distributed throughput with linear CPU scaling. |

---

## Phase 1: High-Throughput API Gateway & Enterprise SDKs (v3.2.0)

### 1. Unified REST API Surface & OpenAPI 3.1 Contract
- [ ] **Standardized REST Endpoints**:
  - `POST /api/v1/sanitize/text`: Synchronous high-speed text scrubbing with Presidio + Regex fusion.
  - `POST /api/v1/sanitize/logs`: Streamed log batch scrubbing with structured log delimiter auto-detection.
  - `POST /api/v1/sanitize/spreadsheet`: Multipart spreadsheet/CSV redaction returning cleansed binary files with intact styling.
  - `POST /api/v1/sanitize/hydrate`: Re-hydrates sanitized AI outputs using an authorized session vault token.
  - `POST /api/v1/sanitize/stream`: HTTP/2 chunked transfer encoding for continuous streaming ingestion.
  - `GET /api/v1/health/ready`: Deep health check verifying SQLite connectivity, Presidio microservice status, and policy checksums.
- [ ] **OpenAPI / Swagger Interactive Documentation**:
  - Live Swagger UI at `/api/docs` and machine-readable OpenAPI 3.1 specification at `/api/openapi.json`.

### 2. High-Performance gRPC Interface
- [ ] **Protobuf Service Definition (`filtr.v1.RedactionService`)**:
  - `UnarySanitizeText(TextRequest) returns (TextResponse)`: Sub-5ms low-overhead RPC for microservice architectures.
  - `StreamSanitizeLogs(stream LogChunk) returns (stream SanitizedLogChunk)`: High-throughput bidirectional gRPC streaming for telemetry agents.
- [ ] **Benchmarking & Latency Targets**:
  - Sub-15ms P99 latency for 10KB payloads; sub-100ms for 1MB tabular data.

### 3. Official Programmatic SDKs
- [ ] **Python SDK (`pip install filtr-sdk`)**:
  - Sync and Async client (`FiltrClient`, `AsyncFiltrClient`).
  - Native integrations with Pandas (`df.filtr.sanitize()`), LangChain, LlamaIndex, and FastAPI middleware.
- [ ] **TypeScript / Node.js SDK (`npm install @filtr/sdk`)**:
  - Universal browser and Node.js runtime compatibility.
  - Native Express/Fastify request-sanitizing middlewares.
- [ ] **Go SDK (`go get github.com/filtr/filtr-go`)**:
  - Ultra-lightweight zero-allocation client for Kubernetes sidecars and telemetry forwarders.

### 4. Asynchronous Batch Processing Engine
- [ ] **Job Queue Architecture**:
  - Background worker pool utilizing Redis / SQLite job queues for large file processing (>10MB).
  - Webhook delivery (`POST https://customer-endpoint.com/webhook/filtr-complete`) upon batch job completion with HMAC-SHA256 signature verification.

### 5. High-Fidelity Tabular & Spreadsheet Synthetic Data Engine
- [ ] **Statistical & Relational Tabular Modeling**:
  - Integrate **SDV (Synthetic Data Vault / CTGAN)** to learn multi-column distributions, statistical correlations, and schema definitions from input CSV/Excel files.
  - Eliminate semantic type mismatch bugs (e.g. person names leaking into numeric/financial columns like *premium* or *commission income*).
- [ ] **Strict Schema Validation & Type Filtering**:
  - Integrate **Pandera / Pydantic** validation filters to strictly verify column data types, currency formatting, and numeric bounds post-generation.
  - Implement heuristic column profiling (header semantics, regex classifiers, and data distribution analysis) for automated generator routing.

---

## Phase 2: Security Vulnerability Remediation & Hardening (v3.3.0)

### 1. Regex ReDoS Defense & Linear Execution Sandbox
- [ ] **Vulnerability**: User-defined custom regex patterns can trigger exponential backtracking (Catastrophic Backtracking / CWE-1333), causing thread starvation.
- [ ] **Remediation**:
  - Integrate Safe-Regex static AST analysis on all imported and custom patterns.
  - Compile regex evaluations inside a WebAssembly linear-time engine (Google RE2 via `re2-wasm`) or apply a strict 50ms execution timeout wrapper per pattern.
  - Reject dangerous patterns with nested quantifiers (e.g. `(a+)+$`) at rule creation time.

### 2. API Key Authentication, Scoping & Key Rotation
- [ ] **Vulnerability**: Single administrator password model lacks programmatic authorization and machine-to-machine auditability.
- [ ] **Remediation**:
  - Implement Scoped API Keys (`filtr_live_...`, `filtr_test_...`) with fine-grained permissions (`sanitize:text`, `sanitize:files`, `policy:read`, `policy:admin`).
  - Store keys using salted Argon2id / bcrypt hashes.
  - Automated API key expiration, rotation workflows, and IP-CIDR restriction whitelists.

### 3. Strict CWE-532 Zero-Retention & Memory Zeroization
- [ ] **Vulnerability**: Unhandled exceptions or server core dumps could inadvertently write unmasked PII into stdout, syslog, or debug traces.
- [ ] **Remediation**:
  - Implement zero-retention wrapper ensuring raw incoming payloads are never passed to logging handlers.
  - Zero out memory buffers (buffer zeroization) post-redaction in native processing routines.
  - Enforce `Cache-Control: no-store, no-cache, must-revalidate, private` and `Pragma: no-cache` on all API responses.

### 4. Presidio Microservice Hardening & Sandbox Isolation
- [ ] **Vulnerability**: Unsecured local Presidio HTTP communication exposes an unauthenticated NLP endpoint on the internal Docker network.
- [ ] **Remediation**:
  - Enforce mutual TLS (mTLS) or shared internal bearer authentication between Filtr core and the Presidio container.
  - Run Presidio in a read-only root filesystem container with dropped Linux capabilities (`CAP_DROP_ALL`) and a non-root UID.

---

## Phase 3: Multi-Modal Document & Vision Redaction (v3.4.0)

### 1. Native PDF Document Redaction Engine
- [ ] **Vector & True Raster Redaction**:
  - Deep inspection of PDF text streams, annotations, form fields, and embedded metadata.
  - True raster redaction: Irreversibly burn black/colored boxes into the pixel layer of rendered PDF pages rather than placing overlay shapes over underlying selectable text.
  - Scrub all PDF metadata, XMP streams, revision history, and thumbnail caches.

### 2. Multi-Modal Vision & OCR Pipeline
- [ ] **Image Redaction (PNG, JPG, TIFF, WebP)**:
  - On-premise OCR engine (Tesseract 5 / PaddleOCR) to identify text in scanned forms, ID cards, driver's licenses, and architecture diagrams.
  - Exact bounding-box spatial masking with custom overlay colors or synthetic image synthesis.
- [ ] **Preserve Visual Document Structure**:
  - Output sanitized PDF and image files retaining original layout, fonts, line spacing, and non-sensitive graphical elements.

### 3. Binary & Structured Data Formats
- [ ] **Apache Parquet & Feather Support**: Streamed column-by-column redaction for big data analytical workflows.
- [ ] **Office Documents (DOCX / PPTX)**: Native XML stream traversal for redaction inside tables, headers, footers, and speaker notes.

---

## Phase 4: Enterprise Identity, Governance & SIEM Telemetry (v3.5.0)

### 1. Enterprise SSO, SAML 2.0 & SCIM User Provisioning
- [ ] **Single Sign-On (SSO)**:
  - SAML 2.0 and OIDC integration with Okta, Microsoft Entra ID (Azure AD), Google Workspace, PingFederate, and Keycloak.
  - Multi-Factor Authentication (MFA / TOTP) enforcement for administrative portal access.
- [ ] **SCIM 2.0 Integration**:
  - Automated user lifecycle synchronization and group-to-role mapping.

### 2. Multi-Tenant Workspaces & Granular RBAC
- [ ] **Multi-Tenancy Hierarchy**:
  - Organization -> Workspaces -> Environments (Production, Staging, Development).
  - Workspace-isolated custom rules, telemetry quotas, and vault namespaces.
- [ ] **Role-Based Access Control (RBAC)**:
  - `Super Admin`: Global system settings, license management, database backups.
  - `Compliance Officer`: Rule creation, duplicate resolution, policy preset publishing, audit log reviews.
  - `Developer / Operator`: API key creation, integration testing, manual scrubbing.
  - `Auditor`: Read-only access to audit logs, compliance reports, and aggregated telemetry.

### 3. Enterprise SIEM & Telemetry Forwarding
- [ ] **Real-Time Security Event Streaming**:
  - Forward privacy-preserving telemetry and audit events via Syslog (RFC 5424), Splunk HTTP Event Collector (HEC), Datadog Logs API, and Microsoft Sentinel.
  - Immediate high-severity webhook alert generation upon detection of intercepted master keys, cloud root credentials, or large-scale exfiltration attempts.

---

## Phase 5: Transparent Gateway Proxy & Inline Wire Interception (v4.0.0)

### 1. Transparent LLM Reverse Proxy Gateway
- [ ] **Drop-In LLM Provider Interception**:
  - Configure LLM clients (Claude Code, Cursor, LangChain, OpenAI SDK, Ollama) by changing `BASE_URL` to `http://filtr-gateway:8081`.
  - Transparently scrub prompts in sub-10ms before sending to external model APIs.
  - Automatically hydrate model responses before returning to the developer/application.
- [ ] **Streaming LLM Support**:
  - Real-time Server-Sent Events (SSE) token-stream sanitization and de-tokenization without buffering entire responses.

### 2. Database Wire-Protocol Proxy
- [ ] **PostgreSQL & MySQL Wire Interceptor**:
  - Sits between application servers and enterprise databases.
  - Dynamically masks sensitive PII and financial fields in query result sets based on the querying user's authorization tier (Dynamic Data Masking / DDM).

---

## Phase 6: Next-Gen Enterprise Tabular & Automation Capabilities (Meeting User Demand)

Driven by direct enterprise user feedback across banking, insurance, healthcare, and engineering teams processing high-volume structured datasets:

### 1. Batch Multi-File Spreadsheet Processing Queue (Bulk Folder & Multi-File Drag-and-Drop)
- [ ] **Multi-File Queue Pipeline**:
  - Ingest 50+ Excel/CSV files simultaneously via drag-and-drop or folder selection.
  - Background batch processor with concurrent Web Worker execution and real-time per-file progress meters.
  - Bulk ZIP download containing all cleansed files alongside unified or per-file mapping manifests.
- [ ] **Shared Cross-File Consistency Vault**:
  - Maintain consistent pseudonymization across interrelated tabular files (e.g., `Customer_A` receives the exact same token `[PERSON_1]` in both `transactions.xlsx` and `invoices.csv`).

### 2. Reusable Column Sanitization Profile Templates (`.filtr-schema.json`)
- [ ] **Exportable Sanitization Profiles**:
  - Save configured column actions, header mappings, and custom rules as reusable `.filtr-schema.json` templates.
  - 1-click template import to instantly sanitize repeating monthly, quarterly, or automated reporting exports.
- [ ] **Schema Versioning & Role Enforcement**:
  - Centralized distribution of official enterprise schema templates from the Admin Portal.
  - Lock specific column templates so regular operators cannot inadvertently expose critical compliance fields.

### 3. Smart Column Data Profiling & Pre-Flight Anomaly Detection
- [ ] **Pre-Sanitization Quality Inspection**:
  - Instant pre-flight column metrics: null value percentage, distinct value counts, data type homogeneity, and PII exposure heatmaps.
  - Automatic detection of data anomalies (e.g. text strings inside expected numeric balance columns or invalid postal formats).
- [ ] **Smart Header Semantic Matching**:
  - Machine-assisted header matching across spelling variations (e.g. matching `SSN`, `SocSecNum`, `tax_id`, `Ident_No` to the same sanitization rule).

### 4. Conditional & Expression-Based Value Masking
- [ ] **Rule-Based Conditional Filtering**:
  - Mask or redact cells only when defined business criteria are met:
    - *Threshold conditions*: Mask salary only if `value > $100,000`.
    - *Cross-column conditions*: Mask national identifier only if `Country == 'United States'`.
    - *Status filters*: Redact records only if `Account_Status == 'TERMINATED'`.
  - Visual conditional rule builder in Step 2 with support for numeric, date, and string comparison operators.

### 5. Cryptographic Proof-of-Redaction & Compliance Certificates (PDF / JSON)
- [ ] **Tamper-Evident Audit Verification**:
  - Generate an official, cryptographically signed **Certificate of Redaction** for every processed document or batch.
  - Includes SHA-256 hashes of original and sanitized files, execution timestamp, applied rule IDs, and operator metadata.
  - Formatted for direct presentation to SOC 2 Type II, HIPAA, and GDPR compliance auditors without revealing underlying confidential data.

### 6. Local Air-Gapped LLM Synthetic Sidecar Engine (Ollama / vLLM)
- [ ] **On-Premise Generative Synthetic Engine**:
  - Support optional local containerized LLM sidecar (e.g. quantized Llama-3, Mistral, or Phi-3 via Ollama/vLLM) running 100% on-premise.
  - Generate hyper-realistic contextual synthetic narrative cells (e.g. insurance claim descriptions, clinical doctor notes, engineering incident summaries).
  - Strict zero-retention parameter enforcement with zero outbound internet network requests.

### 7. Direct Database Connection & In-Place Table Sanitization
- [ ] **Enterprise Database Connectors**:
  - Direct read-and-sanitize connections for PostgreSQL, MySQL, Microsoft SQL Server, Snowflake, and BigQuery.
  - Sanitize development and staging database dumps directly into clean CSV/Excel files for safe vendor handoff.

---

## Bug Fixes & Technical Debt Remediation Backlog

| ID | Component | Severity | Description & Target Fix | Status |
| :---: | :--- | :---: | :--- | :---: |
| **BUG-101** | Rule Sync / Deduplication | **High** | Permanent resolution of duplicate rule resurrection across SQLite, `enterprise_policy.json`, and client storage. | **Fixed (v3.1.12)** |
| **BUG-102** | Excel Sanitizer | **Medium** | Ensure custom date formatting (e.g. `YYYY-MM-DD hh:mm:ss`) is preserved across multi-sheet workbooks. | Planned (v3.2.0) |
| **BUG-103** | Log File Chunking | **Medium** | Log files exceeding 100MB encounter browser memory limits; implement Web Worker chunked FileReader. | Planned (v3.2.0) |
| **BUG-104** | Presidio Connection Timeout | **Low** | Presidio cold start latency causing 3.5s timeout aborts; implement adaptive health check retry with exponential backoff. | Planned (v3.2.0) |
| **BUG-105** | Reverse Hydration Collision | **Medium** | Reversible tokens sharing common prefixes (e.g. `[EMAIL_1]` vs `[EMAIL_10]`) require reverse length-sorted string replacement. | Planned (v3.2.0) |
| **BUG-106** | Excel/CSV Synthetic Engine | **High** | Semantic type mismatch where numeric/financial fields (*premium*, *commission income*) receive person names; resolve via SDV tabular modeling & Pandera schema filter. | In Progress (Per-Column Rules Shipped v3.1.18) |
| **BUG-107** | Step 2 Column Selection | **Medium** | Event clashing on table header checkboxes causing selection lockup; resolved via unified event delegation. | **Fixed (v3.1.18)** |
| **BUG-108** | International CSV Semicolon Delimiter | **Medium** | European semicolon-delimited CSVs merged into single columns in Excel; resolved with auto-detection & UTF-8 BOM. | **Fixed (v3.1.18)** |
| **BUG-109** | OpenXML Formula Recalculation | **Medium** | Formulas referencing sanitized cells did not recalculate on open; resolved via OpenXML calcPr fullCalcOnLoad injection. | **Fixed (v3.1.18)** |

---

## Release Timeline & Milestone Cadence

```mermaid
gantt
    title Filtr Platform Roadmap Schedule
    dateFormat  YYYY-MM-DD
    section v3.2.0
    REST & gRPC API Surface          :2026-10-15, 30d
    Python & TypeScript SDKs         :2026-10-25, 25d
    Async Batch Queue Engine         :2026-11-05, 20d
    section v3.3.0
    ReDoS RE2 Engine & Security Audit:2026-11-20, 25d
    Scoped API Key Management        :2026-12-01, 20d
    Zero-Retention Memory Hardening  :2026-12-10, 15d
    section v3.4.0
    Native PDF Raster Redaction      :2027-01-05, 35d
    On-Premise OCR Vision Pipeline   :2027-01-20, 30d
    section v3.5.0
    Enterprise SAML/OIDC SSO & SCIM  :2027-02-15, 30d
    Multi-Tenant Workspaces & RBAC   :2027-03-01, 25d
    SIEM & Splunk Event Forwarding   :2027-03-15, 20d
    section v4.0.0
    Transparent AI & LLM Proxy       :2027-04-01, 45d
    Database Wire Protocol Gateway   :2027-04-20, 40d
```

---

## API Integration Architecture Contract (Preview)

### 1. Synchronous Redaction API
```http
POST /api/v1/sanitize/text HTTP/1.1
Host: filtr-gateway:8080
Authorization: Bearer filtr_live_9a8b7c6d5e4f...
Content-Type: application/json

{
  "text": "Employee John Doe (EMP-49821, SSN 123-45-6789) accessed AWS key AKIAIOSFODNN7EXAMPLE.",
  "strategy": "consistent_token",
  "policyPreset": "soc2",
  "enablePresidio": true,
  "generateVault": true
}
```

#### Response (`200 OK`)
```json
{
  "success": true,
  "sanitizedText": "Employee [PERSON_1] ([EMPLOYEE_BADGE_1], [SSN_1]) accessed AWS key [AWS_ACCESS_KEY_1].",
  "stats": {
    "totalRedacted": 4,
    "processingTimeMs": 6.8,
    "byCategory": {
      "pii": 3,
      "cloud": 1
    }
  },
  "vaultToken": "vlt_live_9821a7c0de84b...",
  "mappings": [
    { "original": "John Doe", "token": "[PERSON_1]", "ruleId": "presidio_person", "category": "pii" },
    { "original": "EMP-49821", "token": "[EMPLOYEE_BADGE_1]", "ruleId": "emp_badge_id", "category": "pii" },
    { "original": "123-45-6789", "token": "[SSN_1]", "ruleId": "us_ssn", "category": "pii" },
    { "original": "AKIAIOSFODNN7EXAMPLE", "token": "[AWS_ACCESS_KEY_1]", "ruleId": "aws_access_key", "category": "cloud" }
  ]
}
```

### 2. Reverse Hydration API
```http
POST /api/v1/sanitize/hydrate HTTP/1.1
Host: filtr-gateway:8080
Authorization: Bearer filtr_live_9a8b7c6d5e4f...
Content-Type: application/json

{
  "vaultToken": "vlt_live_9821a7c0de84b...",
  "aiResponse": "I have audited the access logs for [PERSON_1]. Their badge [EMPLOYEE_BADGE_1] has been verified."
}
```

#### Response (`200 OK`)
```json
{
  "success": true,
  "hydratedText": "I have audited the access logs for John Doe. Their badge EMP-49821 has been verified.",
  "hydratedCount": 2,
  "processingTimeMs": 1.2
}
```
