#!/usr/bin/env bash
# ==============================================================================
# filtr — Automated Host Reverse Proxy Configuration & Patcher
# ==============================================================================
# Automates the creation and validation of host Nginx reverse proxy configs
# for filtr, ensuring all API endpoints (GET, POST, PUT, DELETE, OPTIONS) are
# routed without 405 Method Not Allowed errors.
# ==============================================================================

set -euo pipefail

PROXY_PORT="9090"
TARGET_URL="http://127.0.0.1:8080"
SERVER_NAME="_"
OUTPUT_FILE=""
APPLY_HOST=false

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}ℹ [INFO]${NC} $*"; }
success() { echo -e "${GREEN}✔ [SUCCESS]${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠ [WARN]${NC} $*"; }
error()   { echo -e "${RED}✖ [ERROR]${NC} $*"; }

show_help() {
    cat << EOF
filtr Host Reverse Proxy Configurator

Usage:
  ./scripts/configure-proxy.sh [options]

Options:
  -p, --port <port>         Host listener port for reverse proxy (default: ${PROXY_PORT})
  -t, --target <url>        Backend container address (default: ${TARGET_URL})
  -s, --server-name <host>  Host server_name / domain (default: ${SERVER_NAME})
  -o, --output <file>       Output config file path (default: stdout or /etc/nginx/sites-available/filtr)
  -a, --apply               Automatically install to /etc/nginx/sites-available/filtr, test, and reload
  -h, --help                Display this manual

Examples:
  ./scripts/configure-proxy.sh -p 9090 -o /etc/nginx/conf.d/filtr.conf
  sudo ./scripts/configure-proxy.sh -p 9090 --apply
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--port)
            PROXY_PORT="$2"; shift 2 ;;
        -t|--target)
            TARGET_URL="$2"; shift 2 ;;
        -s|--server-name)
            SERVER_NAME="$2"; shift 2 ;;
        -o|--output)
            OUTPUT_FILE="$2"; shift 2 ;;
        -a|--apply)
            APPLY_HOST=true; shift ;;
        -h|--help)
            show_help; exit 0 ;;
        *)
            error "Unknown argument: $1"; show_help; exit 1 ;;
    esac
done

generate_config() {
    cat << EOF
# filtr — Automated Enterprise Reverse Proxy Configuration
# Ensures full compatibility with REST APIs, WebSocket, and Zero 405 Method Not Allowed errors.
server {
    listen ${PROXY_PORT};
    listen [::]:${PROXY_PORT};
    server_name ${SERVER_NAME};

    # Maximum request size (for Excel / large logs)
    client_max_body_size 50M;

    # Security Headers
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Dedicated REST API reverse proxy rule (Supports GET, POST, PUT, DELETE, OPTIONS)
    location /api/ {
        proxy_pass ${TARGET_URL}/api/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 10s;
        proxy_read_timeout 60s;
        proxy_intercept_errors off;
    }

    # Frontend SPA location
    location / {
        proxy_pass ${TARGET_URL};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 10s;
        proxy_read_timeout 60s;
    }
}
EOF
}

if [ "${APPLY_HOST}" = true ]; then
    if [ "$(id -u)" -ne 0 ]; then
        error "Applying host proxy configuration requires root privileges. Please run with sudo."
        exit 1
    fi
    TARGET_CONF="/etc/nginx/sites-available/filtr"
    [ -d "/etc/nginx/conf.d" ] && TARGET_CONF="/etc/nginx/conf.d/filtr.conf"

    info "Writing reverse proxy configuration to ${TARGET_CONF}..."
    generate_config > "${TARGET_CONF}"

    if [ -d "/etc/nginx/sites-enabled" ] && [ "${TARGET_CONF}" = "/etc/nginx/sites-available/filtr" ]; then
        ln -sf "${TARGET_CONF}" /etc/nginx/sites-enabled/filtr
    fi

    if command -v nginx >/dev/null 2>&1; then
        info "Validating Nginx configuration syntax..."
        if nginx -t; then
            info "Reloading Nginx..."
            nginx -s reload
            success "Host reverse proxy on port ${PROXY_PORT} successfully active!"
        else
            error "Nginx syntax validation failed. Please check configuration."
            exit 1
        fi
    fi
elif [ -n "${OUTPUT_FILE}" ]; then
    generate_config > "${OUTPUT_FILE}"
    success "Generated reverse proxy configuration saved to ${OUTPUT_FILE}"
else
    generate_config
fi
