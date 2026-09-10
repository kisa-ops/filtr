#!/usr/bin/env bash
set -euo pipefail

# filtr - Enterprise Sensitive Data Redaction Gateway
# Production Distribution Installer (Pre-built Package)
# Repository: https://github.com/kisa-ops/filtr

APP_NAME="filtr"
VERSION="v1.0.0"
PACKAGE_URL="https://github.com/kisa-ops/filtr/releases/download/${VERSION}/filtr-docker-${VERSION}.tar.gz"
IMAGE_TAG="filtr:${VERSION}"

echo "=========================================================="
echo "  Installing ${APP_NAME} (${VERSION})"
echo "  Repository: https://github.com/kisa-ops/filtr"
echo "=========================================================="

# 1. Check prerequisites
if ! command -v docker >/dev/null 2>&1; then
    echo "[-] Error: Docker is not installed. Please install Docker first."
    exit 1
fi

# Detect docker compose plugin or standalone docker-compose
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    echo "[-] Error: Neither 'docker compose' nor 'docker-compose' found."
    exit 1
fi

# 2. Check if image is already present, otherwise download pre-built package
if ! docker image inspect "${IMAGE_TAG}" >/dev/null 2>&1 && ! docker image inspect "ghcr.io/kisa-ops/filtr:${VERSION}" >/dev/null 2>&1; then
    echo "[*] Docker image ${IMAGE_TAG} not found locally."
    
    # Check if ghcr.io image can be pulled
    echo "[*] Checking registry for pre-built package..."
    if docker pull "ghcr.io/kisa-ops/filtr:${VERSION}" 2>/dev/null; then
        echo "[+] Successfully pulled ghcr.io/kisa-ops/filtr:${VERSION}"
        docker tag "ghcr.io/kisa-ops/filtr:${VERSION}" "${IMAGE_TAG}"
    else
        echo "[*] Downloading official pre-built container package from release assets..."
        TAR_PATH="/tmp/filtr-docker-${VERSION}.tar.gz"
        if command -v curl >/dev/null 2>&1; then
            curl -fSL --progress-bar -o "${TAR_PATH}" "${PACKAGE_URL}"
        elif command -v wget >/dev/null 2>&1; then
            wget -q --show-progress -O "${TAR_PATH}" "${PACKAGE_URL}"
        else
            echo "[-] Error: Neither curl nor wget available to download container package."
            exit 1
        fi

        echo "[*] Loading pre-built Docker image into Docker daemon..."
        docker load < "${TAR_PATH}"
        rm -f "${TAR_PATH}"
        echo "[+] Container image loaded successfully."
    fi
else
    echo "[+] Docker image ${IMAGE_TAG} is already installed."
fi

# 3. Setup environment configuration
if [ ! -f .env ]; then
    echo "[*] Initializing .env configuration..."
    if [ -f .env.example ]; then
        cp .env.example .env
    else
        cat << 'ENVEOF' > .env
PORT=8080
FILTR_IMAGE=filtr:v1.0.0
ENVEOF
    fi
fi

# 4. Start production stack
echo "[*] Starting ${APP_NAME} production container..."
${COMPOSE_CMD} up -d

# 5. Healthcheck verification
PORT=$(grep -E '^PORT=' .env 2>/dev/null | cut -d '=' -f2 || echo "8080")
PORT=${PORT:-8080}

echo "[*] Verifying container health..."
MAX_RETRIES=15
COUNTER=0
HEALTHY=false

while [ $COUNTER -lt $MAX_RETRIES ]; do
    if curl -s -f "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then
        HEALTHY=true
        break
    fi
    sleep 1
    COUNTER=$((COUNTER + 1))
done

if [ "$HEALTHY" = true ]; then
    echo ""
    echo "=========================================================="
    echo "  [SUCCESS] ${APP_NAME} is up and running!"
    echo "  Web Interface: http://localhost:${PORT}"
    echo "  Container:     filtr-app"
    echo "  Distribution:  https://github.com/kisa-ops/filtr"
    echo "=========================================================="
else
    echo ""
    echo "[!] Stack started, but health check is still warming up."
    echo "    Check logs: ${COMPOSE_CMD} logs -f"
    echo "    Access:     http://localhost:${PORT}"
fi
