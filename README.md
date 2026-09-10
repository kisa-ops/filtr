# filtr

> **High-Performance Sensitive Data Redaction & Privacy Gateway**  
> Official Distribution Repository: [`https://github.com/kisa-ops/filtr`](https://github.com/kisa-ops/filtr)

---

## Overview

**filtr** is a zero-trust, enterprise privacy gateway engineered to sanitize sensitive data (PII, PCI, HIPAA, and cloud infrastructure secrets) directly in the client runtime before data leaves your security perimeter.

- **Zero Server-Side Retention**: No text or logs are transmitted or stored remotely.
- **Client-Side Cryptography**: AES-256-GCM reversible encryption with PBKDF2 (100,000 rounds).
- **Multi-Format Ingestion**: Supports Raw Text, Large Log Files, and Tabular Excel / CSV sheets.
- **Enterprise Ready**: Shipped as a lightweight, pre-compiled, hardened container distribution.

---

## Quick Start (Installation)

### Option 1: One-Line Installer (Recommended)

Run the automated installer to download the pre-compiled package and start the container:

```bash
git clone https://github.com/kisa-ops/filtr.git
cd filtr
chmod +x install.sh
./install.sh
```

Or via direct script execution:

```bash
curl -sSL https://raw.githubusercontent.com/kisa-ops/filtr/main/install.sh | bash
```

Once started, open your browser at **`http://localhost:8080`**.

---

### Option 2: Docker Compose

```yaml
version: '3.8'

services:
  filtr:
    image: filtr:v1.0.0
    container_name: filtr-app
    restart: unless-stopped
    ports:
      - "8080:80"
```

Start the service:
```bash
docker compose up -d
```

---

### Option 3: Docker Run

Run directly with Docker:

```bash
docker run -d   --name filtr-app   --restart unless-stopped   -p 8080:80   filtr:v1.0.0
```

---

## Air-Gapped & Offline Deployment

For fully isolated, offline, or air-gapped internal networks:

1. Download the pre-built container package from the [Official Releases](https://github.com/kisa-ops/filtr/releases):
   ```bash
   wget https://github.com/kisa-ops/filtr/releases/download/v1.0.0/filtr-docker-v1.0.0.tar.gz
   ```
2. Transfer `filtr-docker-v1.0.0.tar.gz` and `docker-compose.yml` to your target offline host.
3. Load the package into Docker:
   ```bash
   docker load < filtr-docker-v1.0.0.tar.gz
   ```
4. Start the application:
   ```bash
   docker compose up -d
   ```

---

## Upgrades

To upgrade to the latest version of `filtr`:

```bash
chmod +x upgrade.sh
./upgrade.sh
```

---

## Configuration

Customise runtime port and settings in `.env`:

```env
PORT=8080
FILTR_IMAGE=filtr:v1.0.0
```

Refer to [`DEPLOYMENT.md`](./DEPLOYMENT.md) for enterprise SSL/TLS reverse proxy configurations, Kubernetes manifests, and systemd service templates.

---

## License & Support

Maintained and distributed by **kisa-ops**.  
Repository: [https://github.com/kisa-ops/filtr](https://github.com/kisa-ops/filtr)  
Report issues: [https://github.com/kisa-ops/filtr/issues](https://github.com/kisa-ops/filtr/issues)
