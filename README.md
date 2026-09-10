# filtr

> **Enterprise High-Performance Sensitive Data Redaction & Privacy Gateway**  
> Official Distribution Repository: [`https://github.com/kisa-ops/filtr`](https://github.com/kisa-ops/filtr)  
> Container Registry: [`ghcr.io/kisa-ops/filtr`](https://github.com/kisa-ops/filtr/pkgs/container/filtr)

---

## Overview

**filtr** is a zero-trust, enterprise privacy gateway engineered to sanitize sensitive data (PII, PCI-DSS, HIPAA, and cloud infrastructure secrets) directly in the client runtime before data leaves your security boundary.

- **Zero Server-Side Retention**: Zero plaintext, telemetry, or logs leave the browser.
- **Client-Side Cryptography**: AES-256-GCM reversible encryption with PBKDF2 (100,000 rounds).
- **Multi-Format Ingestion**: Supports Raw Text, Large Log Files, and Tabular Excel / CSV sheets.
- **Enterprise Ready**: Shipped as a lightweight, pre-compiled, hardened container distribution with built-in healthchecks and log rotation.

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
1. **Application HTTP Port** (default: `8080`, with port conflict detection).
2. **Network Bind Address** (`0.0.0.0` for all interfaces, or `127.0.0.1` for local/reverse-proxy use).
3. **Optional SSL/TLS Encryption**:
   - Generate self-signed certificate (for internal / staging), or
   - Mount existing corporate certificates (`.crt` / `.key`).
   - Configurable HTTPS port (default: `8443` or `443`).
   - Automatic HTTP to HTTPS redirection.
4. **Systemd Service Integration**: Option to enable auto-restart on host reboot.

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
  ghcr.io/kisa-ops/filtr:v1.0.0
```

---

## Air-Gapped & Offline Deployment

For secure, disconnected, or air-gapped environments:

1. Download the pre-built production container archive from [Releases](https://github.com/kisa-ops/filtr/releases):
   ```bash
   wget https://github.com/kisa-ops/filtr/releases/download/v1.0.0/filtr-docker-v1.0.0.tar.gz
   ```
2. Copy `filtr-docker-v1.0.0.tar.gz` and `docker-compose.yml` to your offline server.
3. Load the container package:
   ```bash
   docker load < filtr-docker-v1.0.0.tar.gz
   ```
4. Start the application:
   ```bash
   docker compose up -d
   ```

---

## Upgrades

To upgrade to the latest release while preserving your `.env`, ports, and SSL certificates:

```bash
chmod +x upgrade.sh
./upgrade.sh
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
