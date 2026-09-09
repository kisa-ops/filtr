#!/usr/bin/env bash
# =============================================================================
# install.sh — Production Installation Script for filtr
# =============================================================================
# Usage:
#   ./install.sh                # Install and launch using Docker Compose
#   ./install.sh --port 3000    # Specify custom host port
#   ./install.sh --native       # Fallback: install and build natively via Node
# =============================================================================

set -e

# Resolve script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/package.json" ]; then
    PROJECT_ROOT="${SCRIPT_DIR}"
elif [ -f "${SCRIPT_DIR}/../package.json" ]; then
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
else
    echo "Error: Could not locate project root with package.json." >&2
    exit 1
fi

cd "${PROJECT_ROOT}"

# Formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} ${BOLD}$*${NC}"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Parse arguments
PORT_ARG=""
USE_NATIVE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--port)
            PORT_ARG="$2"
            shift 2
            ;;
        --native)
            USE_NATIVE=true
            shift
            ;;
        -h|--help)
            echo "filtr Production Installation Script"
            echo
            echo "Usage: ./install.sh [options]"
            echo
            echo "Options:"
            echo "  -p, --port <port>   Set the host port (default: 8080 or value in .env)"
            echo "  --native            Build and install with native Node.js instead of Docker"
            echo "  -h, --help          Show this help message"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo -e "${BOLD}======================================================${NC}"
echo -e "${BOLD}         filtr Production Installer                   ${NC}"
echo -e "${BOLD}======================================================${NC}"
echo

# -----------------------------------------------------------------------------
# Configuration & Environment (.env)
# -----------------------------------------------------------------------------
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        info "Creating .env from .env.example..."
        cp .env.example .env
    else
        info "Creating default .env..."
        cat << 'EOF' > .env
PORT=8080
EOF
    fi
fi

if [ -n "${PORT_ARG}" ]; then
    info "Setting PORT=${PORT_ARG} in .env..."
    if grep -q "^PORT=" .env; then
        sed -i "s/^PORT=.*/PORT=${PORT_ARG}/" .env
    else
        echo "PORT=${PORT_ARG}" >> .env
    fi
fi

# Load variables from .env
set -a
# shellcheck disable=SC1091
source .env 2>/dev/null || true
set +a

APP_PORT="${PORT:-8080}"

# -----------------------------------------------------------------------------
# Native Installation Workflow (optional flag)
# -----------------------------------------------------------------------------
if [ "${USE_NATIVE}" = true ]; then
    info "Running native host installation..."
    if ! command -v node >/dev/null 2>&1; then
        error "Node.js is not found in PATH. Please install Node.js (v20+ recommended)."
        exit 1
    fi
    if ! command -v npm >/dev/null 2>&1; then
        error "npm is not found in PATH."
        exit 1
    fi

    info "Installing dependencies cleanly (npm ci)..."
    npm ci

    info "Building production assets (npm run build)..."
    npm run build

    success "Production build complete! Assets are ready in ${PROJECT_ROOT}/dist"
    echo
    echo "To serve with a local static server or PM2:"
    echo "  npx serve -s dist -l ${APP_PORT}"
    echo "  pm2 serve dist ${APP_PORT} --spa --name filtr"
    exit 0
fi

# -----------------------------------------------------------------------------
# Docker Compose Installation Workflow (default & recommended)
# -----------------------------------------------------------------------------
info "Checking Docker prerequisites..."

if ! command -v docker >/dev/null 2>&1; then
    error "Docker is not installed. Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    error "Docker daemon is not running or current user does not have permission to access the Docker socket."
    exit 1
fi

# Detect docker compose syntax (plugin or standalone)
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    error "Neither 'docker compose' nor 'docker-compose' was found."
    exit 1
fi

info "Using Compose: ${COMPOSE_CMD}"
info "Target port: ${APP_PORT}"

# Build container image
info "Building production container image..."
${COMPOSE_CMD} build

# Start container
info "Starting filtr container in detached mode..."
${COMPOSE_CMD} up -d

# Health check verification loop
info "Verifying container health..."
MAX_ATTEMPTS=20
ATTEMPT=1
HEALTHY=false

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    if curl -s -f "http://127.0.0.1:${APP_PORT}/healthz" >/dev/null 2>&1 || \
       curl -s -f "http://localhost:${APP_PORT}/" >/dev/null 2>&1; then
        HEALTHY=true
        break
    fi
    sleep 1
    ((ATTEMPT++))
done

echo
if [ "$HEALTHY" = true ]; then
    success "filtr is successfully installed and running in production!"
    echo
    echo -e "  ${BOLD}URL:${NC}          ${CYAN}http://localhost:${APP_PORT}${NC}"
    echo -e "  ${BOLD}Container:${NC}    filtr-app"
    echo -e "  ${BOLD}Status:${NC}       ${GREEN}Online & Healthy${NC}"
    echo
    echo -e "${BOLD}Operational Commands:${NC}"
    echo "  • View logs:       ${COMPOSE_CMD} logs -f"
    echo "  • Upgrade/Update:  ./upgrade.sh"
    echo "  • Stop app:        ${COMPOSE_CMD} stop"
    echo "  • Restart app:     ${COMPOSE_CMD} restart"
    echo "  • Remove stack:    ${COMPOSE_CMD} down"
else
    warn "The container started, but healthcheck on port ${APP_PORT} did not respond within ${MAX_ATTEMPTS}s."
    warn "Check container logs using: ${COMPOSE_CMD} logs"
fi
