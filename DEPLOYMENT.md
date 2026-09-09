# Production Deployment & Operations Guide

This guide provides step-by-step instructions for deploying, securing, and maintaining **filtr** in production environments.

---

## 1. Overview & Architecture

**filtr** is an enterprise in-browser data privacy gateway. 
- **100% Client-Side Execution:** All masking, tokenization, hashing, regex parsing, and log/spreadsheet scrubbing execute entirely inside the user's browser using Web Crypto (`crypto.subtle`) and Web Workers.
- **Zero Data Egress:** No raw or sanitized text is ever transmitted across the network.
- **Lightweight Footprint:** The production build is served as static, immutable web assets via a hardened Nginx container (< 35 MB total image size).

---

## 2. GitHub Distribution Strategy

> **User Question:** *"Should this package be built and pushed to GitHub repo, so users can download and install?"*

### Recommended Multi-Tier Distribution Model

To give users and IT teams maximum flexibility, provide these three distribution channels:

| Distribution Channel | Target Audience | How Users Install |
| :--- | :--- | :--- |
| **1. GitHub Container Registry (GHCR)** *(Recommended for Production)* | DevOps, Enterprise Sysadmins, Docker users | `docker pull ghcr.io/<org>/filtr:latest`<br>`docker run -d -p 8080:80 ghcr.io/<org>/filtr:latest` |
| **2. GitHub Releases (Binary Tarball)** | Air-gapped environments, offline networks | Download `filtr-v1.0.0.tar.gz` containing pre-built static bundle and `docker-compose.yml` |
| **3. GitHub Git Repository (Source)** | Developers, custom enterprise integrators | `git clone https://github.com/<org>/filtr.git`<br>`cd filtr && ./install.sh` |

#### Benefits of GHCR (Pre-built Docker Images):
1. **No build tools required on target hosts:** End-users don't need Node.js, npm, or 1GB+ of `node_modules` on their production servers.
2. **Instant deployment:** `docker compose up -d` pulls the optimized 35MB image and boots in under 2 seconds.
3. **Automated CI/CD:** A simple GitHub Action (`.github/workflows/deploy.yml`) builds and tags images automatically on git tag/push.

---

## 3. Quick Start: Deploying Locally or on a Production Server

### Prerequisites
- Linux / macOS / WSL2
- Docker Engine 20.10+ and Docker Compose v2+
- *(Optional for native host builds)*: Node.js 20+ and npm 10+

### Step 1: Clone Repository
```bash
git clone https://github.com/<your-org>/filtr.git
cd filtr
```

### Step 2: Run Production Installer
The repository includes an automated installation script:
```bash
chmod +x install.sh upgrade.sh
./install.sh
```

The installer will:
1. Validate Docker and Docker Compose availability.
2. Generate production `.env` configuration if not present.
3. Build the multi-stage Docker container (`Dockerfile`).
4. Launch the container with automatic restart policies (`restart: unless-stopped`).
5. Verify health checks at `http://127.0.0.1:8080/healthz`.

Access the application at:
```
http://localhost:8080
```

---

## 4. Production Upgrades & Zero Downtime

When you push new updates or features to your codebase, perform a zero-downtime rolling rebuild with:

```bash
./upgrade.sh
```

`upgrade.sh` automatically:
- Tests git updates / pulls latest changes.
- Pre-builds the new image in the background.
- Switches the container without downtime.
- Verifies HTTP 200 on the `/healthz` endpoint.
- Cleans up dangling build cache to conserve server disk space.

---

## 5. Domain, Reverse Proxy & SSL (HTTPS) Setup

In an enterprise environment, place **filtr** behind a reverse proxy (e.g., Nginx, Cloudflare, Traefik, or AWS ALB) with TLS 1.3 encryption.

### Production Nginx Reverse Proxy Configuration
Create `/etc/nginx/sites-available/filtr.conf`:

```nginx
# Redirect all HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name privacy.yourdomain.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name privacy.yourdomain.com;

    # SSL Certificates (e.g., Let's Encrypt Certbot)
    ssl_certificate /etc/letsencrypt/live/privacy.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/privacy.yourdomain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Enterprise Security Headers
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none';" always;

    # Proxy traffic to local filtr container
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support (if needed)
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Health Check Endpoint
    location /healthz {
        proxy_pass http://127.0.0.1:8080/healthz;
        access_log off;
    }
}
```

Enable the site and obtain SSL with Certbot:
```bash
sudo ln -s /etc/nginx/sites-available/filtr.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d privacy.yourdomain.com
```

---

## 6. Admin Portal Security & Authentication

- **Initial Passkey:** Upon first visiting the Admin Portal (shield icon in the top header), enter your enterprise admin passkey.
- **Passkey Derivation:** filtr uses browser-native **PBKDF2-HMAC-SHA-256** with 100,000 rounds and a cryptographically secure random salt (`crypto.getRandomValues`) to derive an encrypted session key.
- **Brute-Force Lockout:** Consecutive failed authentication attempts trigger automatic progressive time lockouts in the browser.
- **Module Governance:** In the Admin Portal, administrators can dynamically enable or disable:
  - **Raw Text Sanitizer**
  - **Log Files Processor**
  - **Excel/CSV Spreadsheet Sanitizer**
  - **Policy Selector Visibility in Main Header**

---

## 7. Air-Gapped / High-Security Offline Deployment

filtr has **zero runtime dependencies on external CDNs or APIs**. To run in disconnected or SCIF air-gapped environments:

1. Build the image on an internet-connected build station:
   ```bash
   docker build -t filtr:latest .
   docker save filtr:latest | gzip > filtr-image.tar.gz
   ```
2. Transfer `filtr-image.tar.gz` and `docker-compose.yml` to the secure environment.
3. Load and launch:
   ```bash
   docker load < filtr-image.tar.gz
   docker compose up -d
   ```

---

## 8. Health Monitoring & Troubleshooting

| Check | Command | Expected Result |
| :--- | :--- | :--- |
| **Container Status** | `docker ps -f name=filtr-app` | `Status: Up ... (healthy)` |
| **Nginx Liveness** | `curl -f http://127.0.0.1:8080/healthz` | `healthy` |
| **Container Logs** | `docker logs filtr-app --tail 50` | Clean Nginx access logs |
| **Restart Service** | `docker compose restart` | Clean restart in < 2s |
