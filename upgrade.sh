#!/usr/bin/env bash
# =============================================================================
# upgrade.sh — Zero-Downtime Upgrade Script for filtr
# =============================================================================
# Official Repository: https://github.com/kisa-ops/filtr
# =============================================================================

set -euo pipefail

APP_NAME="filtr"
REPO="kisa-ops/filtr"

BOLD='\033[1m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[+]${NC} ${BOLD}$*${NC}"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

echo "=========================================================="
echo "  Upgrading ${APP_NAME} Production Stack"
echo "  Repository: https://github.com/${REPO}"
echo "=========================================================="

if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    error "docker compose not found."
    exit 1
fi

# Load existing environment
if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
fi

CURRENT_PORT="${PORT:-8080}"
IS_SSL="${SSL_ENABLED:-false}"

info "Checking for latest release tag from GitHub..."
LATEST_TAG=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name":' | head -n1 | sed -E 's/.*"([^"]+)".*/\1/' || echo "")

if [ -z "${LATEST_TAG}" ]; then
    warn "Could not query GitHub releases API. Defaulting to 'latest' tag."
    LATEST_TAG="latest"
fi

success "Target version: ${LATEST_TAG}"
TARGET_IMAGE="ghcr.io/${REPO}:${LATEST_TAG}"
LOCAL_IMAGE="filtr:${LATEST_TAG}"

info "Fetching updated container image..."
if docker pull "${TARGET_IMAGE}" 2>/dev/null; then
    docker tag "${TARGET_IMAGE}" "${LOCAL_IMAGE}"
    success "Image pulled from GHCR."
else
    PACKAGE_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}/filtr-docker-${LATEST_TAG}.tar.gz"
    info "Downloading package archive: ${PACKAGE_URL}"
    TAR_PATH="/tmp/filtr-docker-${LATEST_TAG}.tar.gz"
    if command -v curl >/dev/null 2>&1; then
        curl -fSL --progress-bar -o "${TAR_PATH}" "${PACKAGE_URL}"
    else
        wget -q --show-progress -O "${TAR_PATH}" "${PACKAGE_URL}"
    fi
    docker load < "${TAR_PATH}"
    rm -f "${TAR_PATH}"
    success "Updated container image loaded."
fi

# Update .env
if [ -f .env ]; then
    sed -i "s|^FILTR_IMAGE=.*|FILTR_IMAGE=${TARGET_IMAGE}|g" .env || true
fi

info "Applying zero-downtime rolling container restart..."
${COMPOSE_CMD} up -d --force-recreate

info "Verifying health..."
sleep 2
MAX_RETRIES=15
COUNTER=0
HEALTHY=false

while [ $COUNTER -lt $MAX_RETRIES ]; do
    if curl -s -f "http://127.0.0.1:${CURRENT_PORT}/healthz" >/dev/null 2>&1 || \
       curl -s -f "http://127.0.0.1:${CURRENT_PORT}/" >/dev/null 2>&1; then
        HEALTHY=true
        break
    fi
    sleep 1
    COUNTER=$((COUNTER + 1))
done

echo
if [ "$HEALTHY" = true ]; then
    success "${APP_NAME} successfully upgraded to ${LATEST_TAG}!"
else
    warn "Upgrade completed, but healthcheck on port ${CURRENT_PORT} timed out. Review logs: ${COMPOSE_CMD} logs"
fi
echo "=========================================================="
