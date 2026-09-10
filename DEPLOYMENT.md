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
| **Air-Gapped Operation** | Disconnected internal corporate networks | Use pre-built offline container packages (`filtr-docker-v1.0.0.tar.gz`). |

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
./install.sh --ssl --ssl-cert /path/to/fullchain.pem --ssl-key /path/to/privkey.pem -y
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

## 4. Systemd Service (Automated Host Lifecycle)

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

## 5. Kubernetes Deployment Manifest

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
        image: ghcr.io/kisa-ops/filtr:v1.0.0
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

## 6. Log Rotation & Disk Space

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

## 7. Verification & Health Monitoring

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
