# filtr

> **Enterprise High-Performance Sensitive Data Redaction Platform**  
> Official Distribution Repository: [`https://github.com/kisa-ops/filtr`](https://github.com/kisa-ops/filtr)  
> Container Registry: [`ghcr.io/kisa-ops/filtr`](https://github.com/kisa-ops/filtr/pkgs/container/filtr)

---

## Overview

**filtr** is a zero-trust, enterprise data redaction platform engineered to sanitize sensitive data (PII, PCI-DSS, HIPAA, GCC identity documents, and cloud infrastructure secrets) directly in the client runtime before data leaves your security boundary.

- **Zero Server-Side Retention**: Zero plaintext, telemetry, or logs leave the browser.
- **Client-Side Cryptography**: AES-256-GCM reversible encryption with PBKDF2 (100,000 rounds).
- **Multi-Format Ingestion**: Supports Raw Text, Large Log Files, and Tabular Excel / CSV sheets.
- **Enterprise Ready**: Shipped as a lightweight, pre-compiled, hardened container distribution with built-in healthchecks, log rotation, and zero-downtime upgrades.

---

## Quick Start (Installation)

### Option 1: Interactive Installer (Recommended)

Clone the repository and run the automated installation wizard:

```bash
git clone https://github.com/kisa-ops/filtr.git
cd filtr
chmod +x install.sh
./install.sh
```

The installer interactively guides you through:
1. **Target Installation Directory**: Standardized to `/opt/filtr` for isolation.
2. **Application HTTP Port**: Default `8080`, with automated conflict detection.
3. **Network Bind Address**: `0.0.0.0` for all interfaces, or `127.0.0.1` for local/reverse-proxy use.
4. **Optional SSL/TLS Encryption**:
   - Generate self-signed certificate (for internal / staging), or
   - Provide file paths to corporate certificates (`.crt`, `.key`, and optional Root/CA `ca.pem`).
   - Configurable HTTPS port (default: `8443` or `443`).
   - Automatic HTTP to HTTPS redirection.
5. **Systemd Service Integration**: Option to enable auto-restart on host reboot.

#### Unattended / Headless Installation (CI/CD)

For automated or scripted deployments:

```bash
# Install with custom port non-interactively
./install.sh -p 8080 -y

# Install with custom port and self-signed SSL
./install.sh -p 8080 --ssl --self-signed --ssl-port 8443 --ssl-domain filtr.corp.internal -y

# Install with existing custom corporate SSL certificates
./install.sh -p 8080 --ssl --ssl-cert /etc/ssl/filtr.crt --ssl-key /etc/ssl/filtr.key -y
```

---

### Option 2: Docker Compose

For environments using standard Docker Compose:

```bash
git clone https://github.com/kisa-ops/filtr.git
cd filtr
docker compose up -d
```

Access the interface at **`http://localhost:8080`**.

---

### Option 3: Direct Docker Run

Run directly from the GitHub Container Registry:

```bash
docker run -d \
  --name filtr-app \
  --restart unless-stopped \
  -p 8080:80 \
  ghcr.io/kisa-ops/filtr:v1.3.0
```

---

## Zero-Downtime Upgrades & Rollbacks

`filtr` features an enterprise maintenance utility (`upgrade.sh`) for rolling upgrades, version rollbacks, and release inspection.

### 1. Interactive Maintenance Wizard

Run without arguments to launch the interactive selector:

```bash
chmod +x upgrade.sh
./upgrade.sh
```

The wizard displays your currently running version and the latest available release:
```text
==========================================================
  filtr Production Stack Maintenance
  Repository: https://github.com/kisa-ops/filtr
==========================================================
[INFO] Currently deployed version: v1.0.0
Latest published release:  v1.3.0

Select an action:
  1) Upgrade to Latest Release (v1.3.0)
  2) Deploy Specific Version (Targeted Upgrade or Rollback)
  3) View All Published Releases
  4) Cancel
```

### 2. Targeted Version Deployment

To deploy or upgrade to a specific release tag:

```bash
# Deploy a specific version (e.g. v1.3.0)
./upgrade.sh --version v1.3.0

# Non-interactive / CI/CD automation
./upgrade.sh --version v1.3.0 --yes
```

### 3. Safe Version Rollback

To roll back to an earlier release, use `--rollback` (or `-r`). The utility warns before downgrading and requires explicit confirmation:

```bash
# Rollback to v1.2.0
./upgrade.sh --rollback v1.2.0

# Non-interactive rollback (for automated disaster recovery)
./upgrade.sh --rollback v1.2.0 --yes
```

### 4. Discover Published Releases

Query the official repository for all published releases, dates, and titles:

```bash
./upgrade.sh --list
```

Output:
```text
TAG            | DATE         | RELEASE TITLE                           
----------------------------------------------------------------------
v1.3.0         | 2026-09-11   | filtr v1.3.0 — Advanced Rule Builder, Ve
v1.2.0         | 2026-09-11   | filtr v1.2.0 — GCC Identity Rules, OCI D
v1.1.0         | 2026-09-11   | filtr v1.1.0 — SSL/TLS Manager, Root/CA 
v1.0.0         | 2026-09-09   | filtr v1.0.0 — Enterprise In-Browser Dat
```

---

## Air-Gapped & Offline Deployment

For secure, disconnected, or air-gapped enterprise environments:

1. Download the pre-built container archive from [Releases](https://github.com/kisa-ops/filtr/releases):
   ```bash
   wget https://github.com/kisa-ops/filtr/releases/download/v1.3.0/filtr-docker-v1.3.0.tar.gz
   ```
2. Copy `filtr-docker-v1.3.0.tar.gz` and `docker-compose.yml` to your offline host.
3. Load the container image:
   ```bash
   docker load < filtr-docker-v1.3.0.tar.gz
   ```
4. Start the stack:
   ```bash
   docker compose up -d
   ```

---

## Release Versioning & History

`filtr` strictly follows [Semantic Versioning](https://semver.org/) (`vMAJOR.MINOR.PATCH`).

| Version | Release Date | Summary of Changes |
|---|---|---|
| **v1.3.0** | 2026-09-11 | **Admin Portal Hook Fix**: Resolved Minified React error #310 by ensuring unconditional hook execution. **Visual Guided Rule Builder**: Added regex-free detection rule builder with case/boundary controls. **Non-Destructive Import**: Append-only policy ingestion with automated duplicate detection and tagging. **Maintenance Engine**: Enhanced `upgrade.sh` with `--version`, `--rollback`, `--list`, and interactive TUI. Vault delete removal. |
| **v1.2.0** | 2026-09-11 | **GCC Identity Detectors**: Added native detection for Qatar ID (QID), UAE Emirates ID, Saudi National ID/Iqama, Kuwait PACI Civil ID, Oman ROP Civil ID, and GCC Passports. **Cloud & Infrastructure**: Oracle Cloud (OCI) token detectors and Apache Tomcat error log patterns. Pre-packaged rule export bundles. |
| **v1.1.0** | 2026-09-11 | **SSL/TLS & Hardening**: Custom SSL certificate wizard, Root/Intermediate CA chain support, `manage-ssl.sh` utility, standardized `/opt/filtr` isolation path, and Systemd service integration. |
| **v1.0.0** | 2026-09-09 | **Initial Production Release**: Zero-trust in-browser client-side redaction gateway for Text, Logs, and Excel/CSV files with AES-256-GCM reversible encryption. |

---

## SSL / TLS Certificate Management

`filtr` includes enterprise SSL/TLS certificate management accessible via terminal scripts and the web **Admin Portal**:

- **Certificate Chain Support**: Server Certificate (`.crt` / `.pem`), Private Key (`.key` / `.pem`), and optional Root or CA Certificate (`ca.pem` / `rootCA.crt`).
- **Flexible Ingestion**: Provide absolute file paths or paste PEM text blocks directly into the terminal or Admin Portal interface.
- **Diagnostics & Status**: Live display of Subject (CN), Certificate Authority (Issuer), Validity Window, SHA-256 Fingerprint, and Root CA chain status.
- **Zero-Downtime Hot Reload**:
  ```bash
  # Update certificates interactively at any time:
  ./manage-ssl.sh
  # Or via installer:
  ./install.sh --update-ssl
  ```

---

## Production Setup Considerations

| Area | Best Practice | Implementation |
|---|---|---|
| **Port & Binding** | Bind to `127.0.0.1` when behind an external proxy; use `0.0.0.0` for standalone. | Configurable via `BIND_IP` and `PORT` in `.env`. |
| **SSL / TLS** | Enable TLS 1.2+ with modern ciphers and HSTS. | Handled automatically via `./install.sh --ssl` or external reverse proxy. |
| **Persistence** | Auto-start on system boot. | Systemd service (`filtr.service`) supported by installer. |
| **Disk Exhaustion** | Prevent Docker logs from filling host storage. | `docker-compose.yml` includes log rotation (`max-size: 10m`, `max-file: 3`). |
| **Monitoring** | Automated container healthchecks. | Native `/healthz` endpoint monitored by Docker engine. |

Refer to [`DEPLOYMENT.md`](./DEPLOYMENT.md) for full reverse-proxy templates (Nginx, Traefik, Caddy), Kubernetes manifests, and security hardening guidelines.

---

## Support & Contributing

Maintained and distributed by **kisa-ops**.  
Repository: [https://github.com/kisa-ops/filtr](https://github.com/kisa-ops/filtr)  
Issue Tracker: [https://github.com/kisa-ops/filtr/issues](https://github.com/kisa-ops/filtr/issues)
