#!/usr/bin/env bash
# =============================================================================
# install.sh — Enterprise Production Installer for filtr
# =============================================================================
# Official Repository: https://github.com/kisa-ops/filtr
# =============================================================================

set -euo pipefail

APP_NAME="filtr"
VERSION="v1.0.0"
PACKAGE_URL="https://github.com/kisa-ops/filtr/releases/download/${VERSION}/filtr-docker-${VERSION}.tar.gz"
IMAGE_TAG="ghcr.io/kisa-ops/filtr:${VERSION}"
LOCAL_TAG="filtr:${VERSION}"

# ANSI Colors
BOLD='\033[1m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[+]${NC} ${BOLD}$*${NC}"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Default Options
HTTP_PORT="8080"
BIND_IP="0.0.0.0"
ENABLE_SSL=false
SSL_PORT="8443"
SSL_MODE="" # "self-signed", "path", or "paste"
SSL_DOMAIN="localhost"
SSL_CERT_PATH=""
SSL_KEY_PATH=""
SSL_CA_PATH=""
SSL_CERT_CONTENT=""
SSL_KEY_CONTENT=""
SSL_CA_CONTENT=""
SSL_REDIRECT=true
INSTALL_SYSTEMD=false
UNATTENDED=false
UPDATE_SSL_ONLY=false

# -----------------------------------------------------------------------------
# CLI Arguments Parsing
# -----------------------------------------------------------------------------
show_help() {
    echo "filtr Production Installer (${VERSION})"
    echo
    echo "Usage: ./install.sh [options]"
    echo
    echo "Options:"
    echo "  -p, --port <port>         Set HTTP port (default: 8080)"
    echo "  -b, --bind <ip>           Set bind address (default: 0.0.0.0)"
    echo "      --ssl                 Enable SSL/TLS encryption"
    echo "      --no-ssl              Disable SSL/TLS encryption"
    echo "      --ssl-port <port>     Set HTTPS/SSL port (default: 8443)"
    echo "      --self-signed         Generate self-signed certificate"
    echo "      --ssl-domain <domain> Domain/IP for certificate (default: localhost)"
    echo "      --ssl-cert <file>     Path to custom SSL certificate (.crt / .pem)"
    echo "      --ssl-key <file>      Path to custom SSL private key (.key)"
    echo "      --ssl-ca <file>       Path to Root or CA certificate (.crt / .pem)"
    echo "      --redirect-ssl        Redirect all HTTP traffic to HTTPS"
    echo "      --no-redirect-ssl     Do not redirect HTTP to HTTPS (dual mode)"
    echo "      --systemd             Install and enable systemd service"
    echo "      --no-systemd          Skip systemd service installation"
    echo "      --update-ssl          Update SSL certificates on running instance"
    echo "  -y, --yes, --unattended   Run non-interactively using defaults or flags"
    echo "  -h, --help                Show this help message"
    echo
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--port)
            HTTP_PORT="$2"; shift 2 ;;
        -b|--bind)
            BIND_IP="$2"; shift 2 ;;
        --ssl)
            ENABLE_SSL=true; shift ;;
        --no-ssl)
            ENABLE_SSL=false; shift ;;
        --ssl-port)
            SSL_PORT="$2"; shift 2 ;;
        --self-signed)
            ENABLE_SSL=true; SSL_MODE="self-signed"; shift ;;
        --ssl-domain)
            SSL_DOMAIN="$2"; shift 2 ;;
        --ssl-cert)
            ENABLE_SSL=true; SSL_MODE="custom"; SSL_CERT_PATH="$2"; shift 2 ;;
        --ssl-key)
            ENABLE_SSL=true; SSL_MODE="custom"; SSL_KEY_PATH="$2"; shift 2 ;;
        --ssl-ca)
            SSL_CA_PATH="$2"; shift 2 ;;
        --redirect-ssl)
            SSL_REDIRECT=true; shift ;;
        --no-redirect-ssl)
            SSL_REDIRECT=false; shift ;;
        --systemd)
            INSTALL_SYSTEMD=true; shift ;;
        --no-systemd)
            INSTALL_SYSTEMD=false; shift ;;
        --update-ssl)
            UPDATE_SSL_ONLY=true; ENABLE_SSL=true; shift ;;
        -y|--yes|--unattended)
            UNATTENDED=true; shift ;;
        -h|--help)
            show_help ;;
        *)
            error "Unknown argument: $1"
            show_help ;;
    esac
done

echo -e "${CYAN}${BOLD}"
echo "  ███████╗██╗██╗  ████████╗██████╗ "
echo "  ██╔════╝██║██║  ╚══██╔══╝██╔══██╗"
echo "  █████╗  ██║██║     ██║   ██████╔╝"
echo "  ██╔══╝  ██║██║     ██║   ██╔══██╗"
echo "  ██║     ██║███████╗██║   ██║  ██║"
echo "  ╚═╝     ╚═╝╚══════╝╚═╝   ╚═╝  ╚═╝"
echo -e "${NC}"
echo -e "${BOLD}Enterprise Sensitive Data Redaction Gateway — ${VERSION}${NC}"
echo -e "${GRAY}Distribution: https://github.com/kisa-ops/filtr${NC}"
echo "=========================================================="
echo

# Helper function to prompt user for PEM input (File path or Paste)
prompt_pem_input() {
    local title="$1"
    local target_var="$2"
    local is_optional="${3:-false}"

    echo
    echo -e "${BOLD}${title}${NC}"
    if [ "${is_optional}" = true ]; then
        read -rp "Do you want to provide a ${title}? [y/N]: " PROVIDE_IT
        if [[ ! "${PROVIDE_IT}" =~ ^[Yy]$ ]]; then
            eval "${target_var}=''"
            return 0
        fi
    fi

    echo "Choose input method:"
    echo "  1) Provide File Path (Absolute or relative)"
    echo "  2) Paste PEM content directly in terminal"
    while true; do
        read -rp "Enter choice [1/2] (default: 1): " INPUT_CHOICE
        INPUT_CHOICE="${INPUT_CHOICE:-1}"
        if [ "${INPUT_CHOICE}" = "1" ]; then
            while true; do
                read -rp "Enter path to ${title} file: " GIVEN_PATH
                if [ -f "${GIVEN_PATH}" ]; then
                    local content
                    content=$(cat "${GIVEN_PATH}")
                    eval "${target_var}=\"\${content}\""
                    success "${title} loaded from ${GIVEN_PATH}"
                    break
                else
                    warn "File not found: ${GIVEN_PATH}. Please provide a valid file."
                fi
            done
            break
        elif [ "${INPUT_CHOICE}" = "2" ]; then
            echo "Paste ${title} content below."
            echo "(Include -----BEGIN... and -----END... tags, then press Enter and type 'EOF' on a newline):"
            local pasted=""
            while IFS= read -r line; do
                if [ "$line" = "EOF" ]; then
                    break
                fi
                pasted="${pasted}${line}
"
                if [[ "$line" =~ ^-----END[^-]+-----$ ]]; then
                    break
                fi
            done
            eval "${target_var}=\"\${pasted}\""
            success "${title} received from terminal paste."
            break
        else
            warn "Please enter 1 or 2."
        fi
    done
}

# Helper to check if a port is in use
is_port_in_use() {
    local check_port="$1"
    if command -v ss >/dev/null 2>&1; then
        ss -tuln | grep -q ":${check_port} " && return 0 || return 1
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tuln | grep -q ":${check_port} " && return 0 || return 1
    elif command -v lsof >/dev/null 2>&1; then
        lsof -iTCP:"${check_port}" -sTCP:LISTEN >/dev/null 2>&1 && return 0 || return 1
    else
        return 1
    fi
}

# -----------------------------------------------------------------------------
# 1. Prerequisites Validation
# -----------------------------------------------------------------------------
info "Validating system prerequisites..."

if ! command -v docker >/dev/null 2>&1; then
    error "Docker is not installed. Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    error "Docker daemon is not running or current user does not have permission to access the Docker socket."
    exit 1
fi

if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    error "Neither 'docker compose' nor 'docker-compose' was found."
    exit 1
fi

success "Prerequisites verified (Docker & Compose ready)."

# -----------------------------------------------------------------------------
# 2. Interactive Configuration Prompts (if TTY and not unattended)
# -----------------------------------------------------------------------------
if [ -t 0 ] && [ "${UNATTENDED}" = false ] && [ "${UPDATE_SSL_ONLY}" = false ]; then
    echo
    echo -e "${BOLD}--- [1/3] Network & Port Configuration ---${NC}"
    
    # Read HTTP Port
    while true; do
        read -rp "Enter application HTTP port [default: ${HTTP_PORT}]: " INPUT_PORT
        INPUT_PORT="${INPUT_PORT:-${HTTP_PORT}}"
        if [[ "${INPUT_PORT}" =~ ^[0-9]+$ ]] && [ "${INPUT_PORT}" -ge 1 ] && [ "${INPUT_PORT}" -le 65535 ]; then
            if is_port_in_use "${INPUT_PORT}"; then
                warn "Port ${INPUT_PORT} is currently in use by another process."
                read -rp "Do you want to use it anyway? [y/N]: " FORCE_PORT
                if [[ "${FORCE_PORT}" =~ ^[Yy]$ ]]; then
                    HTTP_PORT="${INPUT_PORT}"
                    break
                fi
            else
                HTTP_PORT="${INPUT_PORT}"
                break
            fi
        else
            warn "Invalid port number. Please enter a value between 1 and 65535."
        fi
    done

    # Read Bind IP
    read -rp "Enter bind interface (0.0.0.0 for all interfaces, 127.0.0.1 for local/reverse proxy) [default: ${BIND_IP}]: " INPUT_BIND
    BIND_IP="${INPUT_BIND:-${BIND_IP}}"

    echo
    echo -e "${BOLD}--- [2/3] SSL / TLS Security Configuration ---${NC}"
    read -rp "Enable HTTPS / SSL encryption? [y/N]: " ASK_SSL
    if [[ "${ASK_SSL}" =~ ^[Yy]$ ]]; then
        ENABLE_SSL=true

        while true; do
            read -rp "Enter HTTPS / SSL port [default: ${SSL_PORT}]: " INPUT_SSL_PORT
            INPUT_SSL_PORT="${INPUT_SSL_PORT:-${SSL_PORT}}"
            if [[ "${INPUT_SSL_PORT}" =~ ^[0-9]+$ ]] && [ "${INPUT_SSL_PORT}" -ge 1 ] && [ "${INPUT_SSL_PORT}" -le 65535 ]; then
                if is_port_in_use "${INPUT_SSL_PORT}"; then
                    warn "Port ${INPUT_SSL_PORT} is currently in use."
                    read -rp "Do you want to use it anyway? [y/N]: " FORCE_SSL_PORT
                    if [[ "${FORCE_SSL_PORT}" =~ ^[Yy]$ ]]; then
                        SSL_PORT="${INPUT_SSL_PORT}"
                        break
                    fi
                else
                    SSL_PORT="${INPUT_SSL_PORT}"
                    break
                fi
            else
                warn "Invalid port number."
            fi
        done

        echo
        echo "Select SSL Certificate Source:"
        echo "  1) Generate Self-Signed Certificate (Recommended for internal/staging)"
        echo "  2) Provide Custom SSL Certificate, Private Key, and optional Root/CA Certificate"
        while true; do
            read -rp "Enter choice [1/2] (default: 1): " SSL_CHOICE
            SSL_CHOICE="${SSL_CHOICE:-1}"
            if [ "${SSL_CHOICE}" = "1" ]; then
                SSL_MODE="self-signed"
                read -rp "Enter Domain or IP for certificate [default: ${SSL_DOMAIN}]: " INPUT_DOMAIN
                SSL_DOMAIN="${INPUT_DOMAIN:-${SSL_DOMAIN}}"
                break
            elif [ "${SSL_CHOICE}" = "2" ]; then
                SSL_MODE="custom"
                prompt_pem_input "SSL Server Certificate (.crt / fullchain.pem)" SSL_CERT_CONTENT false
                prompt_pem_input "SSL Private Key (.key / privkey.pem)" SSL_KEY_CONTENT false
                prompt_pem_input "Root or CA Certificate (ca.pem / rootCA.crt)" SSL_CA_CONTENT true
                break
            else
                warn "Please enter 1 or 2."
            fi
        done

        read -rp "Redirect all HTTP traffic to HTTPS automatically? [Y/n]: " ASK_REDIRECT
        if [[ "${ASK_REDIRECT}" =~ ^[Nn]$ ]]; then
            SSL_REDIRECT=false
        else
            SSL_REDIRECT=true
        fi
    fi

    echo
    echo -e "${BOLD}--- [3/3] Production System Integration ---${NC}"
    if command -v systemctl >/dev/null 2>&1; then
        read -rp "Install and enable systemd service (auto-starts on system boot)? [y/N]: " ASK_SYSTEMD
        if [[ "${ASK_SYSTEMD}" =~ ^[Yy]$ ]]; then
            INSTALL_SYSTEMD=true
        fi
    fi
elif [ "${UPDATE_SSL_ONLY}" = true ] && [ -t 0 ]; then
    echo -e "${BOLD}--- SSL / TLS Certificate Update Wizard ---${NC}"
    ENABLE_SSL=true
    prompt_pem_input "SSL Server Certificate (.crt / fullchain.pem)" SSL_CERT_CONTENT false
    prompt_pem_input "SSL Private Key (.key / privkey.pem)" SSL_KEY_CONTENT false
    prompt_pem_input "Root or CA Certificate (ca.pem / rootCA.crt)" SSL_CA_CONTENT true
fi

# -----------------------------------------------------------------------------
# 3. Environment Configuration (.env)
# -----------------------------------------------------------------------------
info "Configuring environment (.env)..."

if [ -f .env ] && [ "${UPDATE_SSL_ONLY}" = true ]; then
    # Preserve existing ports and only update SSL flags
    sed -i "s|^SSL_ENABLED=.*|SSL_ENABLED=true|g" .env || echo "SSL_ENABLED=true" >> .env
else
    cat << EOF > .env
# filtr Production Environment Configuration
# Generated on: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

PORT=${HTTP_PORT}
BIND_IP=${BIND_IP}
SSL_ENABLED=${ENABLE_SSL}
SSL_PORT=${SSL_PORT}
SSL_DOMAIN=${SSL_DOMAIN}
SSL_REDIRECT=${SSL_REDIRECT}
FILTR_IMAGE=${IMAGE_TAG}
EOF
fi

success "Configuration saved to .env"

# -----------------------------------------------------------------------------
# 4. SSL Certificate Generation & ssl-info.json
# -----------------------------------------------------------------------------
mkdir -p ssl

if [ "${ENABLE_SSL}" = true ]; then
    if [ "${SSL_MODE}" = "self-signed" ]; then
        info "Generating self-signed SSL certificate for '${SSL_DOMAIN}'..."
        if ! command -v openssl >/dev/null 2>&1; then
            error "OpenSSL is required to generate self-signed certificates. Please install openssl."
            exit 1
        fi
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout ssl/key.pem \
            -out ssl/cert.pem \
            -subj "/CN=${SSL_DOMAIN}" 2>/dev/null
        chmod 600 ssl/key.pem
        chmod 644 ssl/cert.pem
        success "Self-signed certificate generated in ./ssl/ (valid for 365 days)."
    elif [ -n "${SSL_CERT_CONTENT}" ] && [ -n "${SSL_KEY_CONTENT}" ]; then
        info "Installing custom SSL certificates..."
        # If CA is provided, combine Server Cert + CA Cert into cert.pem for complete browser chain
        if [ -n "${SSL_CA_CONTENT}" ]; then
            echo -e "${SSL_CERT_CONTENT}\n\n${SSL_CA_CONTENT}" > ssl/cert.pem
            echo "${SSL_CA_CONTENT}" > ssl/ca.pem
            chmod 644 ssl/ca.pem
            success "Root/CA certificate attached to certificate chain."
        else
            echo "${SSL_CERT_CONTENT}" > ssl/cert.pem
        fi
        echo "${SSL_KEY_CONTENT}" > ssl/key.pem
        chmod 600 ssl/key.pem
        chmod 644 ssl/cert.pem
        success "Custom certificate and private key installed into ./ssl/"
    elif [ -n "${SSL_CERT_PATH}" ] && [ -n "${SSL_KEY_PATH}" ]; then
        info "Copying SSL certificates from provided file paths..."
        if [ -n "${SSL_CA_PATH}" ] && [ -f "${SSL_CA_PATH}" ]; then
            cat "${SSL_CERT_PATH}" "${SSL_CA_PATH}" > ssl/cert.pem
            cp -f "${SSL_CA_PATH}" ssl/ca.pem
            chmod 644 ssl/ca.pem
            success "Root/CA certificate attached to certificate chain."
        else
            cp -f "${SSL_CERT_PATH}" ssl/cert.pem
        fi
        cp -f "${SSL_KEY_PATH}" ssl/key.pem
        chmod 600 ssl/key.pem
        chmod 644 ssl/cert.pem
        success "Certificates copied to ./ssl/"
    fi

    # Generate ssl-info.json for Admin Portal diagnostics
    if command -v openssl >/dev/null 2>&1 && [ -f ssl/cert.pem ]; then
        info "Extracting certificate metadata for Admin Portal..."
        SUBJ=$(openssl x509 -in ssl/cert.pem -noout -subject 2>/dev/null | sed 's/^subject=//' | xargs || echo "CN=${SSL_DOMAIN}")
        ISSUER=$(openssl x509 -in ssl/cert.pem -noout -issuer 2>/dev/null | sed 's/^issuer=//' | xargs || echo "Enterprise CA")
        STARTDATE=$(openssl x509 -in ssl/cert.pem -noout -startdate 2>/dev/null | sed 's/^notBefore=//' | xargs || echo "")
        ENDDATE=$(openssl x509 -in ssl/cert.pem -noout -enddate 2>/dev/null | sed 's/^notAfter=//' | xargs || echo "")
        FINGERPRINT=$(openssl x509 -in ssl/cert.pem -noout -fingerprint -sha256 2>/dev/null | sed 's/^SHA256 Fingerprint=//' | xargs || echo "")
        SERIAL=$(openssl x509 -in ssl/cert.pem -noout -serial 2>/dev/null | sed 's/^serial=//' | xargs || echo "")
        HAS_CA=false
        CA_SUBJ=""
        if [ -f ssl/ca.pem ]; then
            HAS_CA=true
            CA_SUBJ=$(openssl x509 -in ssl/ca.pem -noout -subject 2>/dev/null | sed 's/^subject=//' | xargs || echo "")
        fi

        cat << EOF > ssl/ssl-info.json
{
  "installed": true,
  "subject": "${SUBJ}",
  "issuer": "${ISSUER}",
  "validFrom": "${STARTDATE}",
  "validTo": "${ENDDATE}",
  "fingerprint": "${FINGERPRINT}",
  "serial": "${SERIAL}",
  "hasCaCert": ${HAS_CA},
  "caSubject": "${CA_SUBJ}",
  "updatedAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
        chmod 644 ssl/ssl-info.json
        success "Certificate metadata saved to ./ssl/ssl-info.json"
    fi

    # Generate hardened Nginx configuration
    info "Generating hardened Nginx SSL configuration..."
    if [ "${SSL_REDIRECT}" = true ]; then
        HTTP_ACTION="return 301 https://\$host:${SSL_PORT}\$request_uri;"
    else
        HTTP_ACTION="try_files \$uri \$uri/ /index.html;"
    fi

    TRUSTED_CA_DIRECTIVE=""
    if [ -f ssl/ca.pem ]; then
        TRUSTED_CA_DIRECTIVE="ssl_trusted_certificate /etc/nginx/ssl/ca.pem;"
    fi

    cat << EOF > nginx.conf
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    tcp_nopush      on;
    tcp_nodelay     on;
    keepalive_timeout  65;

    # Gzip Compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_min_length 256;
    gzip_types
        text/plain
        text/css
        text/javascript
        application/javascript
        application/json
        application/x-javascript
        application/xml
        application/xml+rss
        image/svg+xml;

    # HTTP Server
    server {
        listen       80;
        listen  [::]:80;
        server_name  _;

        location /healthz {
            access_log off;
            default_type text/plain;
            return 200 "healthy\n";
        }

        # Certificate status endpoint for Admin Portal
        location /ssl-info.json {
            alias /etc/nginx/ssl/ssl-info.json;
            default_type application/json;
            add_header Cache-Control "no-store, no-cache, must-revalidate" always;
        }

        location / {
            ${HTTP_ACTION}
        }
    }

    # HTTPS Server
    server {
        listen       443 ssl;
        listen  [::]:443 ssl;
        http2        on;
        server_name  _;

        ssl_certificate     /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;
        ${TRUSTED_CA_DIRECTIVE}

        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;

        # Security Headers
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;

        root   /usr/share/nginx/html;
        index  index.html;

        location /healthz {
            access_log off;
            default_type text/plain;
            return 200 "healthy\n";
        }

        # Certificate status endpoint for Admin Portal
        location /ssl-info.json {
            alias /etc/nginx/ssl/ssl-info.json;
            default_type application/json;
            add_header Cache-Control "no-store, no-cache, must-revalidate" always;
        }

        location /assets/ {
            expires 1y;
            add_header Cache-Control "public, max-age=31536000, immutable";
            access_log off;
        }

        location ~* \.(?:ico|png|jpg|jpeg|gif|svg|woff2?|eot|ttf|otf)$ {
            expires 30d;
            add_header Cache-Control "public, max-age=2592000";
            access_log off;
        }

        location = /index.html {
            add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0" always;
            add_header Pragma "no-cache" always;
            add_header Expires "0" always;
        }

        location / {
            try_files \$uri \$uri/ /index.html;
        }

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
            root /usr/share/nginx/html;
        }
    }
}
EOF

    # Create docker-compose.override.yml
    cat << EOF > docker-compose.override.yml
services:
  filtr:
    ports:
      - "${BIND_IP}:${SSL_PORT}:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
EOF
    success "Nginx SSL and docker-compose.override.yml configured."
else
    # SSL Disabled: Remove override file if previously created
    rm -f docker-compose.override.yml
    info "Running standard HTTP mode (SSL disabled)."
fi

# If updating SSL on already running container, hot reload and exit cleanly
if [ "${UPDATE_SSL_ONLY}" = true ]; then
    info "Hot reloading running Nginx service..."
    if ${COMPOSE_CMD} ps | grep -q "filtr"; then
        ${COMPOSE_CMD} exec filtr nginx -s reload 2>/dev/null || ${COMPOSE_CMD} restart filtr
        success "SSL certificates updated and Nginx reloaded successfully!"
    else
        ${COMPOSE_CMD} up -d
        success "Container started with updated SSL certificates."
    fi
    exit 0
fi

# -----------------------------------------------------------------------------
# 5. Image Retrieval (GHCR Pull or Release Asset Fallback)
# -----------------------------------------------------------------------------
info "Checking container image availability..."

IMAGE_READY=false

if docker image inspect "${IMAGE_TAG}" >/dev/null 2>&1 || docker image inspect "${LOCAL_TAG}" >/dev/null 2>&1; then
    info "Found container image locally."
    IMAGE_READY=true
fi

if [ "${IMAGE_READY}" = false ]; then
    info "Attempting to pull ${IMAGE_TAG} from GitHub Container Registry..."
    if docker pull "${IMAGE_TAG}" 2>/dev/null; then
        docker tag "${IMAGE_TAG}" "${LOCAL_TAG}"
        success "Image pulled from GHCR."
        IMAGE_READY=true
    else
        info "GHCR direct pull not available. Downloading release package archive..."
        TAR_PATH="/tmp/filtr-docker-${VERSION}.tar.gz"
        if command -v curl >/dev/null 2>&1; then
            curl -fSL --progress-bar -o "${TAR_PATH}" "${PACKAGE_URL}"
        elif command -v wget >/dev/null 2>&1; then
            wget -q --show-progress -O "${TAR_PATH}" "${PACKAGE_URL}"
        else
            error "Neither curl nor wget is available."
            exit 1
        fi
        info "Loading container package into Docker daemon..."
        docker load < "${TAR_PATH}"
        rm -f "${TAR_PATH}"
        success "Container image successfully loaded into Docker."
        IMAGE_READY=true
    fi
fi

# -----------------------------------------------------------------------------
# 6. Launch Production Container Stack
# -----------------------------------------------------------------------------
info "Starting ${APP_NAME} production container..."

# Avoid container name collisions with outside containers
if docker ps -a --format '{{.Names}}' | grep -Eq "^filtr-app$"; then
    info "Stopping existing filtr-app container..."
    docker stop filtr-app >/dev/null 2>&1 || true
    docker rm filtr-app >/dev/null 2>&1 || true
fi

${COMPOSE_CMD} up -d --remove-orphans

# -----------------------------------------------------------------------------
# 7. Systemd Service Integration (Optional)
# -----------------------------------------------------------------------------
if [ "${INSTALL_SYSTEMD}" = true ]; then
    info "Configuring systemd service..."
    SERVICE_FILE="/etc/systemd/system/filtr.service"
    WORKING_DIR="$(pwd)"
    DOCKER_BIN="$(command -v docker)"

    SYSTEMD_CONTENT="[Unit]
Description=filtr - Enterprise Privacy Gateway
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${WORKING_DIR}
ExecStart=${DOCKER_BIN} compose up -d
ExecStop=${DOCKER_BIN} compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
"
    if [ "$(id -u)" -eq 0 ]; then
        echo "${SYSTEMD_CONTENT}" > "${SERVICE_FILE}"
        systemctl daemon-reload
        systemctl enable filtr.service
        success "systemd service 'filtr.service' enabled."
    elif command -v sudo >/dev/null 2>&1; then
        echo "${SYSTEMD_CONTENT}" | sudo tee "${SERVICE_FILE}" >/dev/null
        sudo systemctl daemon-reload
        sudo systemctl enable filtr.service
        success "systemd service 'filtr.service' enabled with sudo."
    else
        warn "Could not install systemd service: root or sudo access required."
    fi
fi

# -----------------------------------------------------------------------------
# 8. Firewall Inspection & Advice
# -----------------------------------------------------------------------------
if command -v ufw >/dev/null 2>&1 && sudo ufw status 2>/dev/null | grep -q "Status: active"; then
    echo
    warn "UFW firewall is active. You may need to allow incoming traffic:"
    echo "  sudo ufw allow ${HTTP_PORT}/tcp"
    [ "${ENABLE_SSL}" = true ] && echo "  sudo ufw allow ${SSL_PORT}/tcp"
fi

# -----------------------------------------------------------------------------
# 9. Healthcheck & Success Summary
# -----------------------------------------------------------------------------
info "Waiting for service to become healthy..."
CHECK_PORT="${HTTP_PORT}"
MAX_RETRIES=15
COUNTER=0
HEALTHY=false

while [ $COUNTER -lt $MAX_RETRIES ]; do
    if curl -s -f "http://127.0.0.1:${CHECK_PORT}/healthz" >/dev/null 2>&1 || \
       curl -s -f "http://127.0.0.1:${CHECK_PORT}/" >/dev/null 2>&1; then
        HEALTHY=true
        break
    fi
    sleep 1
    COUNTER=$((COUNTER + 1))
done

echo
echo "=========================================================="
if [ "$HEALTHY" = true ]; then
    success "${APP_NAME} is ONLINE and healthy!"
else
    warn "${APP_NAME} container is running, but health check is taking longer than usual."
fi
echo "=========================================================="
echo
echo -e "  ${BOLD}Access Endpoints:${NC}"
if [ "${ENABLE_SSL}" = true ]; then
    echo -e "  • HTTPS:        ${CYAN}https://${SSL_DOMAIN}:${SSL_PORT}${NC}"
    if [ "${SSL_REDIRECT}" = true ]; then
        echo -e "  • HTTP:         ${GRAY}http://localhost:${HTTP_PORT}${NC} ${YELLOW}(redirects to HTTPS)${NC}"
    else
        echo -e "  • HTTP:         ${CYAN}http://localhost:${HTTP_PORT}${NC}"
    fi
else
    echo -e "  • HTTP:         ${CYAN}http://localhost:${HTTP_PORT}${NC}"
fi
echo
echo -e "  ${BOLD}Container:${NC}      filtr-app"
echo -e "  ${BOLD}Directory:${NC}      $(pwd)"
echo -e "  ${BOLD}Repository:${NC}     https://github.com/kisa-ops/filtr"
echo
echo -e "${BOLD}Operational Commands:${NC}"
echo "  • View live logs:       ${COMPOSE_CMD} logs -f"
echo "  • Check container:      ${COMPOSE_CMD} ps"
echo "  • Update SSL certs:     ./install.sh --update-ssl"
echo "  • Restart stack:        ${COMPOSE_CMD} restart"
echo "  • Stop stack:           ${COMPOSE_CMD} down"
echo "  • Upgrade to latest:    ./upgrade.sh"
[ "${INSTALL_SYSTEMD}" = true ] && echo "  • Systemd status:       sudo systemctl status filtr"
echo "=========================================================="
echo
