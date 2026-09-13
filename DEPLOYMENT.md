# Enterprise Production Deployment & Hardening Guide

> **filtr** Official Distribution Repository: [`https://github.com/kisa-ops/filtr`](https://github.com/kisa-ops/filtr)

This guide documents the enterprise hardening checklist, architectural patterns, and production deployment considerations for **filtr**.

---

## 1. Production Architecture Overview

```
                         [ End-User Client Browsers ]
                                      |
                                      v HTTPS (443)
              +-----------------------------------------------+
              |   Enterprise Perimeter / Ingress Controller   |
              |     (Nginx / Traefik / AWS ALB / Cloudflare)   |
              +-----------------------------------------------+
                                      |
                                      v HTTP (8080) or HTTPS (8443)
                     [ filtr Container Runtime (Nginx) ]
                                      |
              +-----------------------------------------------+
              |            In-Browser Web Crypto              |
              |       (Client-Side AES-GCM + PBKDF2)          |
              +-----------------------------------------------+
```

### Key Security Principles
1. **Zero-Trust Client Redaction**: All redactions and reversible vault encryptions execute inside the user's browser sandbox using the Web Cryptography API (`crypto.subtle`).
2. **Zero Server-Side Retention**: The backend Nginx container acts purely as an immutable static asset delivery engine. No logs, user text, or unmasked tokens are ever retained or processed server-side.
3. **Defense-in-Depth**: Hardened HTTP headers, TLS 1.3 encryption, and strict CSP policies.

---

## 2. Production Checklist & Considerations

Before deploying `filtr` to an enterprise environment, review the following checklist:

| Category | Consideration | Recommended Configuration |
|---|---|---|
| **Port Allocation** | Choose a non-conflicting port for HTTP and HTTPS | Default `8080` (HTTP) and `8443` or `443` (HTTPS). |
| **Network Interface** | Restrict binding if behind an ingress/proxy | Set `BIND_IP=127.0.0.1` when using a local reverse proxy. Use `0.0.0.0` for standalone LAN access. |
| **SSL / TLS Termination** | Encrypt all traffic in transit | Terminate TLS either via built-in SSL (`./install.sh --ssl`) or at your corporate reverse proxy. |
| **Host Persistence** | Auto-restart on server reboot | Enable the systemd service (`systemctl enable filtr.service`). |
| **Log Management** | Prevent disk space exhaustion | Enforce Docker log rotation (`max-size: 10m`, `max-file: 3`). |
| **Security Headers** | Prevent clickjacking and MIME attacks | Enforce `X-Frame-Options: SAMEORIGIN`, `X-Content-Type-Options: nosniff`, and `HSTS`. |
| **Air-Gapped Operation** | Disconnected internal corporate networks | Use pre-built offline container packages (`filtr-docker-v1.5.0.tar.gz`). |
| **Lifecycle & Rollbacks** | Zero-downtime maintenance and rollback | Use `./upgrade.sh --version <tag>` or `./upgrade.sh --rollback <tag>`. |

---

## 3. SSL / TLS Configuration Options

### Option A: Built-in SSL via Installer
The `install.sh` script can automatically configure SSL termination inside the container:

```bash
# Interactive SSL Setup
./install.sh

# Or unattended with self-signed certificate
./install.sh --ssl --self-signed --ssl-port 8443 --ssl-domain filtr.corp.internal -y

# Or unattended with custom corporate certificates
./install.sh --ssl --ssl-cert /path/to/fullchain.pem --ssl-key /path/to/privkey.pem --ssl-ca /path/to/rootCA.pem -y
```

### Option B: External Corporate Reverse Proxy (Recommended for Enterprise)

If your enterprise terminates SSL at an external load balancer or reverse proxy:

#### Nginx Configuration (`/etc/nginx/sites-available/filtr.conf`)
```nginx
server {
    listen 80;
    server_name filtr.yourcompany.internal;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name filtr.yourcompany.internal;

    ssl_certificate /etc/ssl/certs/filtr_fullchain.pem;
    ssl_certificate_key /etc/ssl/private/filtr_privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers on;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## 4. Upgrades, Rollbacks & Disaster Recovery

`filtr` supports zero-downtime rolling container updates without data loss.

### Upgrading to Latest Version
```bash
./upgrade.sh
```

### Upgrading to a Specific Version
```bash
./upgrade.sh --version v1.5.0
```

### Emergency Stack Rollback
If an unexpected regression or configuration error occurs, immediately roll back to a known stable release:
```bash
./upgrade.sh --rollback v1.2.0
```
This updates `.env`, re-loads the designated container version, recreates the container stack, and runs liveness checks against `/healthz`.

---

## 5. Systemd Service (Automated Host Lifecycle)

To ensure `filtr` starts automatically across system reboots, configure `/etc/systemd/system/filtr.service`:

```ini
[Unit]
Description=filtr Enterprise Data Redaction Gateway
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/filtr
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

Commands:
```bash
sudo systemctl daemon-reload
sudo systemctl enable filtr.service
sudo systemctl start filtr.service
sudo systemctl status filtr.service
```

---

## 6. Kubernetes Deployment Manifest

For Kubernetes environments, deploy with persistent healthchecks:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: filtr-deployment
  namespace: filtr
  labels:
    app: filtr
spec:
  replicas: 2
  selector:
    matchLabels:
      app: filtr
  template:
    metadata:
      labels:
        app: filtr
    spec:
      containers:
      - name: filtr
        image: ghcr.io/kisa-ops/filtr:v1.6.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /healthz
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /healthz
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        resources:
          limits:
            cpu: "500m"
            memory: "256Mi"
          requests:
            cpu: "100m"
            memory: "64Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: filtr-service
  namespace: filtr
spec:
  selector:
    app: filtr
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
```

---

## 7. Log Rotation & Disk Space

Docker container logs are constrained in `docker-compose.yml`:

```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

This guarantees container logs never exceed 30MB total.

---

## 8. Verification & Health Monitoring

To monitor container status and health:

```bash
# Query health check
curl -I http://localhost:8080/healthz

# Container status
docker compose ps

# Container logs
docker compose logs -f --tail=100
```

Support & Issue Tracker: [https://github.com/kisa-ops/filtr/issues](https://github.com/kisa-ops/filtr/issues)

---

## Default Enterprise Detection Rule Packs Deployment

Every official **filtr** production deployment includes 5 pre-packaged, validated enterprise detection rule packs totaling **225+ specialized rules** shipped directly as standard static assets inside `/usr/share/nginx/html/` and served with UTF-8 JSON headers:

| Rule Pack File | Rules | Coverage Scope |
| :--- | :--- | :--- |
| `filtr_export_all_enterprise_rules_225_pack.json` | **225** | **Grand Master Pack**: All 225 rules (PII, Financial, Cloud, Insurance, Software, Telecom, DevOps) |
| `filtr_export_extended_sensitive_data_rules.json` | **150** | **Core Infrastructure**: 20+ National Phones, 15 IBANs, 15 Passports, AWS/GCP/Azure/Vault, Nginx/Docker/Jenkins |
| `filtr_export_insurance_and_software_company_rules.json` | **45** | **Industry Specialized**: Insurance Policies, Claims, Medicare MBI, NHS, VIN, ICD-10, CPT, Stripe, SaaS API Keys |
| `filtr_export_gcc_java_angular_dev_rules.json` | **30** | **Regional & Stack**: GCC Telecoms (KSA/UAE/QAT/KWT/OMN/BHR), JVM Stack Traces & Thread Dumps, Angular Errors |
| `filtr_export_master_enterprise_pack_195_rules.json` | **195** | **Combined Enterprise**: Core 150 Infrastructure + 45 Insurance & Software Company detectors |

### Deployment & Serving Configuration
- **Nginx Route**: Dedicated location block `location ~* ^/filtr_export_.*\.json$` with `Content-Type: application/json; charset=utf-8` and browser caching headers.
- **Direct HTTP Access**: Available via `GET /<pack_filename>` (e.g. `curl -s http://localhost:8080/filtr_export_all_enterprise_rules_225_pack.json`).
- **One-Click Administration**: Admin Portal includes the **"Deployment Rule Packs (225)"** manager to quick-load or download any rule pack with automated duplicate detection.
- **Zero Configuration**: Rules are pre-integrated into the application runtime catalog out-of-the-box upon deployment.

---

## 7. Centralized Enterprise Administration & Production Security

filtr features a hardened, centralized enterprise administration architecture designed to prevent unauthorized browser-local privilege escalation and ensure unified data protection policies across all corporate endpoints.

### 7.1 Centralized Enterprise Policy Distribution (`enterprise_policy.json`)

- **Single Source of Truth**: The canonical corporate policy is served directly by the container at `/enterprise_policy.json`.
- **Automatic Client Synchronization**: When any employee opens filtr, the client automatically fetches the latest centralized policy manifest on session startup.
- **Immediate Propagation**: Nginx delivers `enterprise_policy.json` and `enterprise_config.json` with `Cache-Control: no-cache, must-revalidate, max-age=0` so policy updates take effect immediately without browser cache delays.
- **Air-Gap Support**: If the container is offline or disconnected, clients seamlessly fall back to the built-in enterprise catalog.

### 7.2 Enterprise Administrator Access Control & Credential Governance

- **Zero In-Browser Self-Setup**: Unauthenticated users in new browser profiles or private sessions are strictly prevented from initializing or claiming administrator privileges.
- **Enterprise Master Passkey**:
  - Out-of-the-box Default: `FiltrAdmin@2026!`
  - Derivation: PBKDF2 with SHA-256 (100,000 rounds) and dedicated cryptographic salt.
- **Master Provisioning & Key Rotation Token**:
  - Token: `FILTR-ENT-SEC-2026`
  - Used by authorized SecOps personnel to rotate the administrator passkey or recover access in emergencies.
- **Session Hardening**:
  - Inactivity Timeout: 15-minute sliding session window. Inactive sessions automatically expire.
  - Rate-Limiting & Lockout: 5 consecutive failed login attempts trigger an immediate 60-second administrative lockout with exponential backoff.
  - Side-Channel Protection: Constant-time string comparisons prevent cryptographic timing attacks.

### 7.3 SecOps Policy Publishing Workflow

1. Authenticate to the Admin Portal via the **Admin Console** button using the Enterprise Passkey.
2. Manage, add, or toggle detection rules, adjust compliance presets (SOC-2, HIPAA, GDPR, PCI-DSS, DevOps), or configure module availability.
3. Click **"Publish to Enterprise"** in the Rules toolbar.
4. The system updates the cached enterprise manifest, computes a SHA-256 checksum, and downloads the updated `enterprise_policy.json`.
5. Place the updated `enterprise_policy.json` in the Docker/Nginx webroot (`/usr/share/nginx/html/enterprise_policy.json`) to enforce company-wide.

### 7.4 Enterprise Security Audit Trail

All administrative security events are recorded chronologically in the **Audit Trail** tab, including:
- Successful logins and failed authentication attempts with lockout triggers.
- Rule creation, modification, deletion, and toggling.
- Duplicate pattern cleanups.
- Policy publishing and client synchronization events.
- Audit records can be exported directly as JSON for compliance reporting and SOC-2 / ISO-27001 evidence.
