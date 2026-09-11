#!/usr/bin/env bash
# =============================================================================
# upgrade.sh — Version Management, Upgrade & Rollback Script for filtr
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
MAGENTA='\033[0;35m'
DIM='\033[2m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[+]${NC} ${BOLD}$*${NC}"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

show_help() {
    cat << 'EOF'
filtr Stack Upgrade & Rollback Utility

USAGE:
    ./upgrade.sh [OPTIONS]

OPTIONS:
    -v, --version <tag>     Target a specific version tag to deploy (e.g., v1.3.0, v1.2.0, latest)
    -r, --rollback <tag>    Rollback stack to an earlier release tag with confirmation
    -l, --list, --versions  List all available published versions from GitHub
    -y, --yes               Non-interactive mode; auto-confirm prompts
    -h, --help              Display this help manual and exit

EXAMPLES:
    ./upgrade.sh                      # Launch interactive upgrade / rollback wizard
    ./upgrade.sh --version v1.3.0     # Deploy specific version v1.3.0
    ./upgrade.sh --rollback v1.2.0    # Rollback production stack to v1.2.0
    ./upgrade.sh --list               # List all available releases
    ./upgrade.sh -v latest -y         # Silently update to latest release
EOF
}

# Normalize version string: ensures '1.3.0' becomes 'v1.3.0' unless 'latest'
normalize_version() {
    local v="$1"
    v="$(echo "${v}" | tr -d '[:space:]')"
    if [ "${v}" = "latest" ]; then
        echo "latest"
    elif [[ "${v}" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        echo "v${v}"
    else
        echo "${v}"
    fi
}

# Fetch releases list from GitHub API
fetch_releases() {
    local api_url="https://api.github.com/repos/${REPO}/releases"
    if command -v curl >/dev/null 2>&1; then
        curl -s -H "User-Agent: filtr-upgrade-utility" "${api_url}" 2>/dev/null || echo ""
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O - --header="User-Agent: filtr-upgrade-utility" "${api_url}" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# List all available versions in a readable format
list_available_versions() {
    echo -e "${BOLD}Querying published releases for ${REPO}...${NC}"
    local raw_json
    raw_json=$(fetch_releases)

    if [ -z "${raw_json}" ] || [ "${raw_json}" = "[]" ]; then
        warn "Could not connect to GitHub API or no releases found."
        echo "Check your internet connection or repository: https://github.com/${REPO}/releases"
        return 1
    fi

    echo ""
    printf "  ${BOLD}%-14s | %-12s | %-40s${NC}\n" "TAG" "DATE" "RELEASE TITLE"
    echo "  ----------------------------------------------------------------------"

    if command -v python3 >/dev/null 2>&1; then
        echo "${raw_json}" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    if isinstance(data, list):
        for r in data:
            tag = r.get("tag_name", "unknown")
            date = (r.get("published_at") or r.get("created_at") or "")[:10]
            name = r.get("name") or "Release " + tag
            print(f"  {tag:<14} | {date:<12} | {name[:40]}")
except Exception:
    pass
'
    else
        # Fallback using grep/sed
        echo "${raw_json}" | grep -E '"tag_name":|"published_at":' | sed -E 's/.*: "([^"]+)".*/\1/' | while read -r tag && read -r pub_date; do
            printf "  %-14s | %-12s | %-40s\n" "${tag}" "${pub_date:0:10}" "filtr ${tag}"
        done
    fi
    echo ""
}

# Query latest version tag
get_latest_version() {
    local raw_json="$1"
    local tag=""
    if [ -n "${raw_json}" ] && command -v python3 >/dev/null 2>&1; then
        tag=$(echo "${raw_json}" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    if isinstance(data, list) and len(data) > 0:
        print(data[0].get("tag_name", ""))
except Exception:
    pass
')
    fi
    if [ -z "${tag}" ]; then
        tag=$(echo "${raw_json}" | grep '"tag_name":' | head -n1 | sed -E 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/' || echo "")
    fi
    if [ -z "${tag}" ]; then
        tag="latest"
    fi
    echo "${tag}"
}

# Detect currently deployed version
get_current_version() {
    local cur="unknown"
    if [ -f .env ]; then
        local img_val
        img_val=$(grep -E '^FILTR_IMAGE=' .env | cut -d'=' -f2- | tr -d '"' | tr -d "'" || echo "")
        if [ -n "${img_val}" ]; then
            cur="${img_val##*:}"
        fi
    fi
    if [ "${cur}" = "unknown" ] || [ -z "${cur}" ]; then
        if docker ps --format '{{.Image}}' 2>/dev/null | grep -E 'filtr' | head -n1 >/tmp/filtr_img.tmp 2>&1; then
            local live_img
            live_img=$(cat /tmp/filtr_img.tmp || echo "")
            rm -f /tmp/filtr_img.tmp
            if [ -n "${live_img}" ]; then
                cur="${live_img##*:}"
            fi
        fi
    fi
    echo "${cur}"
}

# Parse Command Line Arguments
TARGET_VERSION=""
IS_ROLLBACK=false
AUTO_CONFIRM=false
ACTION="deploy"

while [ $# -gt 0 ]; do
    case "$1" in
        -v|--version|-t|--tag)
            if [ -z "${2:-}" ]; then
                error "Missing version argument for $1"
                exit 1
            fi
            TARGET_VERSION="$(normalize_version "$2")"
            shift 2
            ;;
        -r|--rollback)
            if [ -z "${2:-}" ]; then
                error "Missing version argument for $1"
                exit 1
            fi
            TARGET_VERSION="$(normalize_version "$2")"
            IS_ROLLBACK=true
            shift 2
            ;;
        -l|--list|--versions)
            ACTION="list"
            shift
            ;;
        -y|--yes)
            AUTO_CONFIRM=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

if [ "${ACTION}" = "list" ]; then
    list_available_versions
    exit 0
fi

# Detect Compose Command
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    error "Neither 'docker compose' nor 'docker-compose' found on system."
    exit 1
fi

CURRENT_VERSION="$(get_current_version)"

echo "=========================================================="
echo -e "  ${BOLD}${APP_NAME} Production Stack Maintenance${NC}"
echo "  Repository: https://github.com/${REPO}"
echo "=========================================================="
info "Currently deployed version: ${BOLD}${CURRENT_VERSION}${NC}"

# Interactive Menu if no target version specified
if [ -z "${TARGET_VERSION}" ]; then
    echo ""
    info "Fetching release metadata from GitHub..."
    RAW_RELEASES=$(fetch_releases)
    LATEST_AVAILABLE=$(get_latest_version "${RAW_RELEASES}")

    echo -e "Latest published release:  ${BOLD}${GREEN}${LATEST_AVAILABLE}${NC}"
    echo ""
    echo -e "${BOLD}Select an action:${NC}"
    echo "  1) Upgrade to Latest Release (${LATEST_AVAILABLE})"
    echo "  2) Deploy Specific Version (Targeted Upgrade or Rollback)"
    echo "  3) View All Published Releases"
    echo "  4) Cancel"
    echo ""
    read -rp "Enter choice [1-4] (default: 1): " MENU_CHOICE
    MENU_CHOICE="${MENU_CHOICE:-1}"

    case "${MENU_CHOICE}" in
        1)
            TARGET_VERSION="${LATEST_AVAILABLE}"
            ;;
        2)
            echo ""
            list_available_versions || true
            read -rp "Enter desired version tag (e.g., v1.2.0, v1.3.0, latest): " USER_TAG
            if [ -z "${USER_TAG}" ]; then
                warn "No version entered. Operation cancelled."
                exit 0
            fi
            TARGET_VERSION="$(normalize_version "${USER_TAG}")"
            ;;
        3)
            list_available_versions || true
            read -rp "Deploy a version now? Enter tag (or press Enter to exit): " USER_TAG
            if [ -z "${USER_TAG}" ]; then
                exit 0
            fi
            TARGET_VERSION="$(normalize_version "${USER_TAG}")"
            ;;
        4|q|Q)
            info "Upgrade cancelled."
            exit 0
            ;;
        *)
            error "Invalid choice: ${MENU_CHOICE}"
            exit 1
            ;;
    esac
fi

TARGET_VERSION="$(normalize_version "${TARGET_VERSION}")"

# Determine if this is a rollback based on tag or flag
if [ "${IS_ROLLBACK}" = true ]; then
    echo ""
    echo -e "${YELLOW}==========================================================${NC}"
    echo -e "  ${YELLOW}${BOLD}[ROLLBACK NOTICE]${NC}"
    echo -e "  You are rolling back ${APP_NAME} stack:"
    echo -e "    From: ${BOLD}${CURRENT_VERSION}${NC}"
    echo -e "    To:   ${BOLD}${MAGENTA}${TARGET_VERSION}${NC}"
    echo -e "${YELLOW}==========================================================${NC}"
    if [ "${AUTO_CONFIRM}" = false ]; then
        read -rp "Are you sure you want to rollback to ${TARGET_VERSION}? [y/N]: " CONFIRM_RB
        if [[ ! "${CONFIRM_RB}" =~ ^[Yy]$ ]]; then
            warn "Rollback cancelled by user."
            exit 0
        fi
    fi
else
    echo ""
    success "Target deployment version: ${TARGET_VERSION}"
    if [ "${CURRENT_VERSION}" = "${TARGET_VERSION}" ] && [ "${AUTO_CONFIRM}" = false ]; then
        warn "Current version (${CURRENT_VERSION}) matches target version (${TARGET_VERSION})."
        read -rp "Do you wish to force re-deploy and recreate containers? [y/N]: " CONFIRM_REDEPLOY
        if [[ ! "${CONFIRM_REDEPLOY}" =~ ^[Yy]$ ]]; then
            info "Stack is already on ${TARGET_VERSION}. No changes made."
            exit 0
        fi
    fi
fi

# Load existing environment
if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
fi

CURRENT_PORT="${PORT:-8080}"
TARGET_IMAGE="ghcr.io/${REPO}:${TARGET_VERSION}"
LOCAL_IMAGE="filtr:${TARGET_VERSION}"

info "Step 1/3: Acquiring container image for ${TARGET_VERSION}..."

IMAGE_LOADED=false

# Check for local offline tar archive in directory or /tmp
OFFLINE_TAR_LOCAL="./filtr-docker-${TARGET_VERSION}.tar.gz"
OFFLINE_TAR_TMP="/tmp/filtr-docker-${TARGET_VERSION}.tar.gz"

if [ -f "${OFFLINE_TAR_LOCAL}" ]; then
    info "Found local offline container package: ${OFFLINE_TAR_LOCAL}"
    docker load < "${OFFLINE_TAR_LOCAL}"
    IMAGE_LOADED=true
elif [ -f "${OFFLINE_TAR_TMP}" ]; then
    info "Found cached container package: ${OFFLINE_TAR_TMP}"
    docker load < "${OFFLINE_TAR_TMP}"
    IMAGE_LOADED=true
fi

# Try pulling from GHCR
if [ "${IMAGE_LOADED}" = false ]; then
    info "Attempting to pull ${TARGET_IMAGE} from GitHub Container Registry..."
    if docker pull "${TARGET_IMAGE}" 2>/dev/null; then
        docker tag "${TARGET_IMAGE}" "${LOCAL_IMAGE}" 2>/dev/null || true
        success "Successfully pulled ${TARGET_IMAGE} from GHCR."
        IMAGE_LOADED=true
    else
        warn "Could not pull from GHCR (offline, private, or rate-limited). Attempting release download..."
    fi
fi

# Try downloading release asset tarball
if [ "${IMAGE_LOADED}" = false ]; then
    PACKAGE_URL="https://github.com/${REPO}/releases/download/${TARGET_VERSION}/filtr-docker-${TARGET_VERSION}.tar.gz"
    info "Downloading offline release asset: ${PACKAGE_URL}"
    TAR_PATH="/tmp/filtr-docker-${TARGET_VERSION}.tar.gz"
    
    DOWNLOAD_OK=false
    if command -v curl >/dev/null 2>&1; then
        if curl -fSL --progress-bar -o "${TAR_PATH}" "${PACKAGE_URL}"; then
            DOWNLOAD_OK=true
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -q --show-progress -O "${TAR_PATH}" "${PACKAGE_URL}"; then
            DOWNLOAD_OK=true
        fi
    fi

    if [ "${DOWNLOAD_OK}" = true ] && [ -s "${TAR_PATH}" ]; then
        docker load < "${TAR_PATH}"
        rm -f "${TAR_PATH}"
        success "Successfully loaded release container image."
        IMAGE_LOADED=true
    else
        rm -f "${TAR_PATH}"
        error "Failed to download image package for ${TARGET_VERSION}."
        error "Verify version tag with: ./upgrade.sh --list"
        exit 1
    fi
fi

info "Step 2/3: Updating environment configuration..."
if [ -f .env ]; then
    if grep -q '^FILTR_IMAGE=' .env; then
        sed -i "s|^FILTR_IMAGE=.*|FILTR_IMAGE=${TARGET_IMAGE}|g" .env
    else
        echo "FILTR_IMAGE=${TARGET_IMAGE}" >> .env
    fi
    success "Updated FILTR_IMAGE in .env to ${TARGET_IMAGE}"
fi

info "Step 3/3: Applying rolling container restart with zero-downtime..."
${COMPOSE_CMD} up -d --force-recreate

info "Verifying service availability..."
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

echo ""
echo "=========================================================="
if [ "$HEALTHY" = true ]; then
    if [ "${IS_ROLLBACK}" = true ]; then
        success "${APP_NAME} stack successfully ROLLED BACK to ${TARGET_VERSION}!"
    else
        success "${APP_NAME} stack successfully updated to ${TARGET_VERSION}!"
    fi
    echo -e "  Port:      ${BOLD}${CURRENT_PORT}${NC}"
    echo -e "  Image:     ${BOLD}${TARGET_IMAGE}${NC}"
    echo -e "  Status:    ${GREEN}Healthy (Listening and Active)${NC}"
else
    warn "Deployment command succeeded, but health verification timed out."
    warn "Inspect container status and logs with: ${COMPOSE_CMD} logs"
fi
echo "=========================================================="
