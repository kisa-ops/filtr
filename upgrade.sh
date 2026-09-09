#!/usr/bin/env bash
# =============================================================================
# upgrade.sh — Production Upgrade & Zero-Downtime Deployment Script for filtr
# =============================================================================
# Usage:
#   ./upgrade.sh                 # Pull changes (if git exists), rebuild, & deploy
#   ./upgrade.sh --no-pull       # Rebuild & upgrade from local files without pulling
#   ./upgrade.sh --branch dev    # Pull from specific branch before upgrading
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
NO_PULL=false
TARGET_BRANCH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-pull)
            NO_PULL=true
            shift
            ;;
        -b|--branch)
            TARGET_BRANCH="$2"
            shift 2
            ;;
        -h|--help)
            echo "filtr Production Upgrade Script"
            echo
            echo "Usage: ./upgrade.sh [options]"
            echo
            echo "Options:"
            echo "  --no-pull           Skip git pull and upgrade directly from local code"
            echo "  -b, --branch <name> Pull from specified branch before upgrading"
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
echo -e "${BOLD}          filtr Production Upgrader                   ${NC}"
echo -e "${BOLD}======================================================${NC}"
echo

# Detect Compose command
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    error "Neither 'docker compose' nor 'docker-compose' was found."
    exit 1
fi

# Load variables from .env
if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    source .env 2>/dev/null || true
    set +a
fi
APP_PORT="${PORT:-8080}"

# -----------------------------------------------------------------------------
# 1. Git Pull / Version Update
# -----------------------------------------------------------------------------
if [ -d .git ] && [ "$NO_PULL" = false ]; then
    info "Git repository detected. Checking for upstream changes..."
    
    # Determine branch
    CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'main')"
    BRANCH="${TARGET_BRANCH:-$CURRENT_BRANCH}"
    
    info "Current branch: ${BRANCH}"
    
    # Check if remote exists
    if git remote | grep -q 'origin'; then
        info "Fetching latest commits from origin/${BRANCH}..."
        git fetch origin "${BRANCH}"
        
        # Check if local is behind
        LOCAL_HASH="$(git rev-parse HEAD)"
        REMOTE_HASH="$(git rev-parse "origin/${BRANCH}" 2>/dev/null || echo "$LOCAL_HASH")"
        
        if [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
            info "New commits found. Pulling changes..."
            git pull origin "${BRANCH}"
        else
            info "Already up to date with origin/${BRANCH}."
        fi
    else
        warn "No remote 'origin' configured. Upgrading with local codebase."
    fi
else
    if [ "$NO_PULL" = true ]; then
        info "Skipping git pull (--no-pull specified). Rebuilding from local files..."
    else
        info "Not a git repository. Rebuilding and upgrading in-place from local files..."
    fi
fi

# -----------------------------------------------------------------------------
# 2. Build New Image
# -----------------------------------------------------------------------------
info "Building updated Docker image..."
${COMPOSE_CMD} build

# -----------------------------------------------------------------------------
# 3. Apply Recreated Container
# -----------------------------------------------------------------------------
info "Recreating container with new image..."
${COMPOSE_CMD} up -d --force-recreate

# -----------------------------------------------------------------------------
# 4. Verify Health
# -----------------------------------------------------------------------------
info "Verifying upgraded container health..."
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

# -----------------------------------------------------------------------------
# 5. Cleanup Stale Images
# -----------------------------------------------------------------------------
info "Pruning dangling Docker images..."
docker image prune -f >/dev/null 2>&1 || true

echo
if [ "$HEALTHY" = true ]; then
    success "filtr successfully upgraded to latest version!"
    echo
    echo -e "  ${BOLD}URL:${NC}          ${CYAN}http://localhost:${APP_PORT}${NC}"
    echo -e "  ${BOLD}Container:${NC}    filtr-app"
    echo -e "  ${BOLD}Status:${NC}       ${GREEN}Online & Healthy${NC}"
    echo
    echo -e "${BOLD}Current Stack:${NC}"
    ${COMPOSE_CMD} ps
else
    warn "Upgrade completed, but healthcheck on port ${APP_PORT} did not respond within ${MAX_ATTEMPTS}s."
    warn "Check container logs using: ${COMPOSE_CMD} logs"
fi
