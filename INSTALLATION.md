# Production Installation & Operations Guide

> **filtr** — Enterprise High-Performance Sensitive Data Redaction Platform  
> Distribution Repository: [`https://github.com/kisa-ops/filtr`](https://github.com/kisa-ops/filtr)  
> Container Registry: [`ghcr.io/kisa-ops/filtr:v1.3.0`](https://github.com/kisa-ops/filtr/pkgs/container/filtr)

This comprehensive guide details the complete workflow for deploying **filtr** in a production environment using the interactive installer (`install.sh`), configuring custom SSL/TLS certificates (including enterprise Root/CA chains), integrating host auto-restart (Systemd), and managing maintenance with `upgrade.sh`.

---

## 1. System Prerequisites

Before initiating installation, ensure the target host meets the following requirements:

| Component | Minimum Specification | Recommended Specification |
|---|---|---|
| **Operating System** | Ubuntu 22.04+, Debian 12+, RHEL 8+, Rocky Linux 9+ | Ubuntu 24.04 LTS or RHEL 9 |
| **CPU / Memory** | 1 vCPU / 1 GB RAM | 2 vCPU / 2 GB RAM |
| **Storage** | 5 GB available disk space | 15 GB SSD |
| **Container Engine** | Docker Engine 24.0+ & Docker Compose v2 | Docker 26.0+ |
| **Network** | Outbound access to `ghcr.io` (or offline tarball) | Dedicated static IP or FQDN |
| **Privileges** | `sudo` / `root` execution rights | `sudo` user in `docker` group |

### Verify Docker & Compose
```bash
docker --version
docker compose version
```

---

## 2. Fresh Installation Procedure

### Step 1: Obtain the Production Package

Clone the official distribution repository or download the release asset:

```bash
git clone https://github.com/kisa-ops/filtr.git
cd filtr
chmod +x install.sh
```

### Step 2: Launch the Interactive Wizard

Run the installer with root privileges:

```bash
sudo ./install.sh
```

The installer presents an interactive 4-stage configuration wizard:

```text
  ███████╗██╗██╗  ████████╗██████╗
  ██╔════╝██║██║  ╚══██╔══╝██╔══██╗
  █████╗  ██║██║     ██║   ██████╔╝
  ██╔══╝  ██║██║     ██║   ██╔══██╗
  ██║     ██║███████╗██║   ██║  ██║
  ╚═╝     ╚═╝╚══════╝╚═╝   ╚═╝  ╚═╝

Enterprise Sensitive Data Redaction Platform — v1.3.0
Distribution: https://github.com/kisa-ops/filtr
==========================================================

[INFO] Validating system prerequisites...
[+] Prerequisites verified (Docker & Compose ready).
```

---

### Step 3: Walkthrough of the 4-Stage Wizard

#### --- [1/4] Installation Directory ---
```text
Enter installation directory [default: /opt/filtr]: 
```
* **Explanation**: The installer establishes an isolated, dedicated directory for all configuration files, SSL certificates, and Docker Compose definitions. Defaulting to `/opt/filtr` prevents accidental file pollution and ensures standardized systemd service execution.

#### --- [2/4] Network & Port Configuration ---
```text
Enter application HTTP port [default: 8080]: 8080
Enter bind interface (0.0.0.0 for all interfaces, 127.0.0.1 for local/reverse proxy) [default: 0.0.0.0]: 0.0.0.0
```
* **Application HTTP Port**: The host port to expose. The installer automatically checks for existing port conflicts.
* **Bind Interface**:
  * `0.0.0.0`: Binds to all network interfaces (accessible across LAN / WAN).
  * `127.0.0.1`: Restricts access to localhost only (recommended when running behind an external corporate reverse proxy such as Nginx, Traefik, or AWS ALB).

#### --- [3/4] SSL / TLS Security Configuration ---
```text
Enable HTTPS / SSL encryption? [y/N]: y
Enter HTTPS / SSL port [default: 8443]: 9090

Select SSL Certificate Source:
  1) Generate Self-Signed Certificate (Recommended for internal/staging)
  2) Provide Custom SSL Certificate, Private Key, and optional Root/CA Certificate
Enter choice [1/2] (default: 1): 2

Enter path to SSL Server Certificate (.crt / fullchain.pem) file: /tmp/filtr/ssl/server.crt
[+] SSL Server Certificate (.crt / fullchain.pem) found at: /tmp/filtr/ssl/server.crt

Enter path to SSL Private Key (.key / privkey.pem) file: /tmp/filtr/ssl/server.key
[+] SSL Private Key (.key / privkey.pem) found at: /tmp/filtr/ssl/server.key

Do you want to provide a Root or CA Certificate (ca.pem / rootCA.crt)? [y/N]: y
Enter path to Root or CA Certificate (ca.pem / rootCA.crt) file: /tmp/filtr/ssl/root.crt
[+] Root or CA Certificate (ca.pem / rootCA.crt) found at: /tmp/filtr/ssl/root.crt
Redirect all HTTP traffic to HTTPS automatically? [Y/n]: Y
```
* **HTTPS / SSL Port**: Port for encrypted traffic (e.g. `8443`, `9090`, or standard `443`).
* **Certificate Options**:
  * **Option 1 (Self-Signed)**: Generates a 4096-bit RSA certificate on-the-fly for internal testing and staging.
  * **Option 2 (Custom Corporate Certificates)**:
    * **Server Certificate**: Path to `.crt` or `.pem` file containing the leaf server certificate.
    * **Private Key**: Path to `.key` or `.pem` file containing the private key (supports RSA and ECDSA).
    * **Root / CA Certificate**: Path to corporate Root CA or Intermediate CA bundle. The installer automatically bundles this into the full certificate trust chain.
* **Automatic Redirection**: When enabled, any request hitting the HTTP port (`8080`) is immediately redirected to the HTTPS port (`9090`) with an HTTP 301 Permanent Redirect.

#### --- [4/4] Production System Integration ---
```text
Install and enable systemd service (auto-starts on system boot)? [y/N]: y
```
* Creates `/etc/systemd/system/filtr.service` configured to manage the container lifecycle. Ensures the service automatically recovers after unexpected reboots.

---

### Step 4: Installation Execution & Online Verification

The installer executes non-destructively, copies files, configures permissions, pulls the image from GHCR, and starts the stack:

```text
[INFO] Setting up installation directory: /opt/filtr...
[INFO] Configuring environment in /opt/filtr...
[INFO] Installing custom SSL certificates from file paths...
[+] Root/CA certificate appended to certificate chain.
[+] Certificates copied to /opt/filtr/ssl/
[INFO] Extracting certificate metadata for Admin Portal...
[+] Certificate metadata saved to /opt/filtr/ssl/ssl-info.json
[INFO] Generating hardened Nginx SSL configuration...
[+] Nginx SSL and docker-compose.override.yml configured.
[INFO] Checking container image availability...
[INFO] Attempting to pull ghcr.io/kisa-ops/filtr:v1.3.0 from GitHub Container Registry...
[+] Image pulled from GHCR.
[INFO] Starting filtr production container from /opt/filtr...
[INFO] Stopping previous filtr-app container instance...
[+] Running 1/1
 ✔ Container filtr-app  Started
[INFO] Configuring systemd service...
Created symlink /etc/systemd/system/multi-user.target.wants/filtr.service → /etc/systemd/system/filtr.service.
[+] systemd service 'filtr.service' enabled.
[INFO] Waiting for service to become healthy...

==========================================================
[+] filtr is ONLINE and healthy!
==========================================================

  Installation Path: /opt/filtr
  Container Name:    filtr-app

  Access Endpoints:
  • HTTPS:           https://localhost:9090
  • HTTP:            http://localhost:8080 (redirects to HTTPS)

Operational Commands:
  • Change to app dir:   cd /opt/filtr
  • View live logs:      docker compose logs -f
  • Check container:     docker compose ps
  • Update SSL certs:    ./manage-ssl.sh
  • Restart stack:       docker compose restart
  • Stop stack:          docker compose down
  • Upgrade to latest:   ./upgrade.sh
  • Systemd status:      sudo systemctl status filtr
==========================================================
```

---

## 3. Operational Runbook

All daily maintenance operations should be executed from `/opt/filtr`:

```bash
cd /opt/filtr
```

### 1. View Real-Time Container Logs
```bash
docker compose logs -f --tail=100
```

### 2. Inspect Stack Health
```bash
docker compose ps
curl -k https://localhost:9090/healthz
```

### 3. Rotate or Update SSL / TLS Certificates
Use the dedicated `manage-ssl.sh` script anytime corporate certificates need rotation:
```bash
./manage-ssl.sh
```
The script validates the new certificate files, extracts Subject, Issuer, and Expiration metadata, updates the Nginx SSL configuration, and reloads the container with zero downtime.

### 4. Zero-Downtime Upgrades & Rollbacks (`upgrade.sh`)
The upgraded `upgrade.sh` utility is installed directly in `/opt/filtr`:

* **Interactive Menu**:
  ```bash
  ./upgrade.sh
  ```
* **Targeted Version Deployment**:
  ```bash
  # Upgrade or deploy specific version:
  ./upgrade.sh --version v1.3.0
  ```
* **Rollback Stack to Previous Release**:
  ```bash
  # Safe rollback with confirmation prompt:
  ./upgrade.sh --rollback v1.2.0
  ```
* **Discover All Published Releases**:
  ```bash
  ./upgrade.sh --list
  ```

### 5. Systemd Service Control
```bash
# Check host service status
sudo systemctl status filtr.service

# Restart host service
sudo systemctl restart filtr.service

# Stop host service
sudo systemctl stop filtr.service
```

---

## 4. Unattended / Automated Deployments (CI/CD)

For automated server provisioning with Ansible, Terraform, or cloud-init:

```bash
# 1. Standard HTTP Deployment
sudo ./install.sh -d /opt/filtr -p 8080 -b 0.0.0.0 -y

# 2. Production Custom SSL Deployment with CA Chain
sudo ./install.sh \
  -d /opt/filtr \
  -p 8080 \
  -b 0.0.0.0 \
  --ssl \
  --ssl-port 9090 \
  --ssl-cert /tmp/filtr/ssl/server.crt \
  --ssl-key /tmp/filtr/ssl/server.key \
  --ssl-ca /tmp/filtr/ssl/root.crt \
  -y
```

---

## 5. Offline & Air-Gapped Environments

For secure air-gapped data centers without external internet access:

1. Download the pre-packaged offline release archive on an internet-connected host:
   ```bash
   wget https://github.com/kisa-ops/filtr/releases/download/v1.3.0/filtr-docker-v1.3.0.tar.gz
   ```
2. Copy `filtr-docker-v1.3.0.tar.gz` and the repository contents to `/tmp/filtr/` on the air-gapped server.
3. Run `sudo ./install.sh`. The installer automatically detects `/tmp/filtr-docker-v1.3.0.tar.gz` or `./filtr-docker-v1.3.0.tar.gz` and loads the container image directly without making external network calls.
