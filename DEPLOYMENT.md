# Enterprise Production Deployment Guide

> **filtr** Official Distribution Repository: [`https://github.com/kisa-ops/filtr`](https://github.com/kisa-ops/filtr)

This document provides hardening and deployment architectures for hosting **filtr** in production enterprise environments.

---

## Architecture

```
[ Clients / Browsers ]
         |
         v HTTPS (443)
[ Enterprise Reverse Proxy / WAF (Nginx, Traefik, ALB, Caddy) ]
         |
         v HTTP (8080)
[ filtr-app Container (Pre-compiled Nginx + Assets) ]
```

---

## Production Reverse Proxy Configurations

### Nginx with SSL/TLS

```nginx
server {
    listen 80;
    server_name filtr.yourcompany.internal;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name filtr.yourcompany.internal;

    ssl_certificate /etc/ssl/certs/filtr.crt;
    ssl_certificate_key /etc/ssl/private/filtr.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Security Headers
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self';" always;

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

## Systemd Service (Auto-restart on Host Boot)

Create `/etc/systemd/system/filtr.service`:

```ini
[Unit]
Description=Filtr Enterprise Data Redaction Gateway
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

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now filtr.service
```

---

## Kubernetes Deployment Manifest

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
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /
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

## Verification & Health Check

Verify status:
```bash
curl -I http://localhost:8080/
```
Expected output:
```http
HTTP/1.1 200 OK
```

Support: [https://github.com/kisa-ops/filtr](https://github.com/kisa-ops/filtr)
