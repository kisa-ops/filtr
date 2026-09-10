#!/usr/bin/env bash
set -euo pipefail

# filtr - Zero-Downtime Upgrade Script
# Repository: https://github.com/kisa-ops/filtr

APP_NAME="filtr"
REPO="kisa-ops/filtr"

echo "=========================================================="
echo "  Upgrading ${APP_NAME}"
echo "  Repository: https://github.com/${REPO}"
echo "=========================================================="

if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    echo "[-] Error: docker compose not found."
    exit 1
fi

echo "[*] Checking for latest release from https://github.com/${REPO}..."
LATEST_TAG=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || echo "")

if [ -z "${LATEST_TAG}" ]; then
    echo "[!] Could not query GitHub releases API. Falling back to latest image."
    LATEST_TAG="latest"
fi

echo "[+] Target version: ${LATEST_TAG}"

# Check if image can be pulled or downloaded
if docker pull "ghcr.io/${REPO}:${LATEST_TAG}" 2>/dev/null; then
    echo "[+] Pulled ghcr.io/${REPO}:${LATEST_TAG}"
    docker tag "ghcr.io/${REPO}:${LATEST_TAG}" "filtr:${LATEST_TAG}"
else
    PACKAGE_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}/filtr-docker-${LATEST_TAG}.tar.gz"
    echo "[*] Downloading pre-built package from ${PACKAGE_URL}..."
    TAR_PATH="/tmp/filtr-docker-${LATEST_TAG}.tar.gz"
    curl -fSL --progress-bar -o "${TAR_PATH}" "${PACKAGE_URL}"
    docker load < "${TAR_PATH}"
    rm -f "${TAR_PATH}"
fi

# Update .env if present
if [ -f .env ]; then
    sed -i "s|^FILTR_IMAGE=.*|FILTR_IMAGE=filtr:${LATEST_TAG}|g" .env || true
fi

echo "[*] Applying rolling container restart..."
${COMPOSE_CMD} up -d --force-recreate

echo ""
echo "=========================================================="
echo "  [SUCCESS] ${APP_NAME} updated to ${LATEST_TAG} successfully!"
echo "=========================================================="
