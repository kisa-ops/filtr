#!/usr/bin/env bash
# =============================================================================
# upgrade.sh — Version Management, Upgrade & Rollback Script for filtr
# =============================================================================
# Official Repository: https://github.com/kisa-ops/filtr
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

APP_NAME="filtr"
REPO="kisa-ops/filtr"

BOLD='\033[1m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
DIM='\033[2m'
GRAY='\033[0;90m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[+]${NC} ${BOLD}$*${NC}"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

show_help() {
    cat << 'EOF'
================================================================================
  filtr Production Stack Upgrade, Rollback & Deployment Utility
================================================================================

OVERVIEW:
    Manages zero-downtime rolling upgrades and rollbacks for the filtr enterprise
    privacy gateway container stack. Supports online deployment (GHCR / GitHub
    Releases) and 100% offline air-gapped environments via local tar packages.

USAGE:
    ./upgrade.sh [OPTIONS]

OPTIONS:
    -v, --version <tag>     Target a specific version tag to deploy
                            (e.g., v1.8.4, v2.0.0, latest)
    -r, --rollback <tag>    Safely rollback container stack to a previous version
    -l, --list, --versions  Query and list all official published releases
    --enable-ner            Deploy and activate local Presidio AI/NER sidecar (isolated, 0 host ports)
    --disable-ner           Disable AI/NER sidecar and free system memory
    --status-ner            Check health and security isolation of AI/NER sidecar
    -y, --yes               Non-interactive mode; auto-confirm all upgrade prompts
    -h, --help              Show this detailed command reference and operational guide

OFFLINE & AIR-GAPPED DEPLOYMENTS:
    To upgrade in an offline or air-gapped environment without internet access:
    1. Download the offline archive: filtr-docker-<version>.tar.gz
    2. Place it in the installation directory: ./filtr-docker-<version>.tar.gz
    3. Run: ./upgrade.sh -v <version> -y
    The script automatically detects, loads, and cross-tags the offline image.

EXAMPLES:
    ./upgrade.sh                       # Launch the interactive guided upgrade wizard
    ./upgrade.sh -l                    # View all published versions in a table
    ./upgrade.sh --version v1.8.4      # Upgrade to version v1.8.4 with confirmation
    ./upgrade.sh -v latest -y          # Unattended upgrade to latest stable release
    ./upgrade.sh --rollback v1.8.0     # Revert deployment to v1.8.0 with backup validation
================================================================================
EOF
}

# Normalize version string: ensures '1.3.0' becomes 'v1.4.0' unless 'latest'
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
        warn "GitHub API unavailable or rate-limited. Displaying verified local release catalog..."
        raw_json='[{"tag_name":"v1.6.0","published_at":"2026-09-13T00:00:00Z","name":"filtr v1.6.0 - Enterprise Secured & Centralized Admin Portal, Category Realignment & Duplicate Prevention"},{"tag_name":"v1.5.0","published_at":"2026-09-13T00:00:00Z","name":"filtr v1.5.0 - Duplicate Prevention & Custom Safeguards"},{"tag_name":"v1.4.0","published_at":"2026-09-12T00:00:00Z","name":"filtr v1.4.0 — 225 Default Enterprise Rules Deployment"},{"tag_name":"v1.3.0","published_at":"2026-09-11T00:00:00Z","name":"filtr v1.3.0 — Advanced Rule Builder & Version Engine"},{"tag_name":"v1.2.0","published_at":"2026-09-11T00:00:00Z","name":"filtr v1.2.0 — GCC Identity & Cloud Detectors"},{"tag_name":"v1.1.0","published_at":"2026-09-11T00:00:00Z","name":"filtr v1.1.0 — SSL/TLS Manager & CA Certificates"},{"tag_name":"v1.0.0","published_at":"2026-09-09T00:00:00Z","name":"filtr v1.0.0 — Enterprise Privacy Gateway"}]'
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
    local live_img
    live_img=$(docker inspect --format='{{.Config.Image}}' filtr-app 2>/dev/null || echo "")
    if [ -n "${live_img}" ]; then
        cur="${live_img##*:}"
    fi
    if [ "${cur}" = "unknown" ] || [ -z "${cur}" ]; then
        if [ -f .env ]; then
            local img_val
            img_val=$(grep -E '^FILTR_IMAGE=' .env | cut -d'=' -f2- | tr -d '"' | tr -d "'" || echo "")
            if [ -n "${img_val}" ]; then
                cur="${img_val##*:}"
            fi
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
        --enable-ner)
            if [ -f "./manage-ner.sh" ]; then
                exec ./manage-ner.sh enable
            elif [ -f "${SCRIPT_DIR}/manage-ner.sh" ]; then
                exec "${SCRIPT_DIR}/manage-ner.sh" enable
            else
                echo "manage-ner.sh not found." >&2
                exit 1
            fi
            ;;
        --disable-ner)
            if [ -f "./manage-ner.sh" ]; then
                exec ./manage-ner.sh disable
            elif [ -f "${SCRIPT_DIR}/manage-ner.sh" ]; then
                exec "${SCRIPT_DIR}/manage-ner.sh" disable
            fi
            ;;
        --status-ner)
            if [ -f "./manage-ner.sh" ]; then
                exec ./manage-ner.sh status
            elif [ -f "${SCRIPT_DIR}/manage-ner.sh" ]; then
                exec "${SCRIPT_DIR}/manage-ner.sh" status
            fi
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
            read -rp "Enter desired version tag (e.g., v1.2.0, v1.4.0, latest): " USER_TAG
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

# Check if image is already loaded in local Docker daemon
if docker image inspect "${TARGET_IMAGE}" >/dev/null 2>&1 || \
   docker image inspect "${LOCAL_IMAGE}" >/dev/null 2>&1 || \
   docker image inspect "ghcr.io/anandprabhusk/filtr:${TARGET_VERSION}" >/dev/null 2>&1; then
    docker tag "ghcr.io/anandprabhusk/filtr:${TARGET_VERSION}" "${TARGET_IMAGE}" 2>/dev/null || true
    info "Found target container image already present in local Docker daemon (${TARGET_IMAGE})."
    docker tag "${LOCAL_IMAGE}" "${TARGET_IMAGE}" 2>/dev/null || true
    docker tag "${TARGET_IMAGE}" "${LOCAL_IMAGE}" 2>/dev/null || true
    IMAGE_LOADED=true
fi

# Check for local offline tar archive in directory, releases/ or /tmp
if [ "${IMAGE_LOADED}" = false ]; then
    CANDIDATE_TARS=(
        "${SCRIPT_DIR}/filtr-docker-${TARGET_VERSION}.tar.gz"
        "./filtr-docker-${TARGET_VERSION}.tar.gz"
        "${SCRIPT_DIR}/releases/filtr-docker-${TARGET_VERSION}.tar.gz"
        "./releases/filtr-docker-${TARGET_VERSION}.tar.gz"
        "/tmp/filtr-docker-${TARGET_VERSION}.tar.gz"
    )
    for tar_file in "${CANDIDATE_TARS[@]}"; do
        if [ -f "${tar_file}" ]; then
            info "Found local offline container package: ${tar_file}"
            docker load < "${tar_file}"
            docker tag "${LOCAL_IMAGE}" "${TARGET_IMAGE}" 2>/dev/null || true
            docker tag "${TARGET_IMAGE}" "${LOCAL_IMAGE}" 2>/dev/null || true
            IMAGE_LOADED=true
            break
        fi
    done
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
        if curl -fSL --http1.1 --connect-timeout 20 --retry 5 --retry-delay 2 --retry-connrefused -C - --progress-bar -o "${TAR_PATH}" "${PACKAGE_URL}"; then
            DOWNLOAD_OK=true
        fi
    fi
    if [ "${DOWNLOAD_OK}" = false ] && command -v wget >/dev/null 2>&1; then
        info "Retrying download with wget..."
        if wget -c -t 5 --waitretry=2 --timeout=20 --show-progress -O "${TAR_PATH}" "${PACKAGE_URL}"; then
            DOWNLOAD_OK=true
        fi
    fi

    if [ "${DOWNLOAD_OK}" = true ] && [ -s "${TAR_PATH}" ]; then
        docker load < "${TAR_PATH}"
        # Permanently link local and GHCR image tags to prevent pull failures
        docker tag "${LOCAL_IMAGE}" "${TARGET_IMAGE}" 2>/dev/null || true
        docker tag "${TARGET_IMAGE}" "${LOCAL_IMAGE}" 2>/dev/null || true
        rm -f "${TAR_PATH}"
        success "Successfully loaded release container image."
        IMAGE_LOADED=true
    else
        rm -f "${TAR_PATH}"
        error "Failed to acquire container image for ${TARGET_VERSION}."
        error "GitHub download failed (offline or network reset), and image was not found locally."
        echo ""
        info "To deploy offline or rebuild locally:"
        info "  1) Rebuild locally:  docker build -t ${TARGET_IMAGE} -t ${LOCAL_IMAGE} ."
        info "  2) Or place offline tar package into ${SCRIPT_DIR}/filtr-docker-${TARGET_VERSION}.tar.gz"
        info "Then re-run: ./upgrade.sh -v ${TARGET_VERSION} -y"
        exit 1
    fi
fi

# Check if AI / NER Presidio configuration exists in .env; if missing, prompt interactively
if [ -f .env ] && ! grep -q '^PRESIDIO_ENABLED=' .env && [ "${AUTO_CONFIRM:-false}" = false ] && [ -t 0 ]; then
    echo
    echo -e "${BOLD}--- AI / Deep NER Detection Engine (Microsoft Presidio) ---${NC}"
    echo -e "${GRAY}Provides advanced ML/NER recognition for unstructured names and regional entities.${NC}"
    echo -e "  1) Enable Local Sidecar Container (Allocates ~1GB RAM for local spaCy model)"
    echo -e "  2) Connect to External / Remote Presidio Server (Runs on separate hardware/VM)"
    echo -e "  3) Keep Disabled / Skip (Fast regex only; configure later via Admin Portal) [default]"
    read -rp "Select option [1-3] (default: 3): " UP_NER_CHOICE
    case "${UP_NER_CHOICE}" in
        1)
            cat << 'NER_EOF' >> .env

# Pluggable AI / Deep NER Detection Engine (Microsoft Presidio)
PRESIDIO_ENABLED=true
PRESIDIO_MODE=local
PRESIDIO_URL=http://presidio:5001
PRESIDIO_CONFIDENCE_THRESHOLD=0.6
COMPOSE_PROFILES=ner
NER_EOF
            export COMPOSE_PROFILES="ner"
            success "Enabled local Presidio AI/NER sidecar container in .env."
            ;;
        2)
            read -rp "Enter Remote Presidio API URL [default: http://localhost:5001]: " UP_P_URL
            cat << NER_EOF >> .env

# Pluggable AI / Deep NER Detection Engine (Microsoft Presidio)
PRESIDIO_ENABLED=true
PRESIDIO_MODE=remote
PRESIDIO_URL="${UP_P_URL:-http://localhost:5001}"
PRESIDIO_CONFIDENCE_THRESHOLD=0.6
COMPOSE_PROFILES=
NER_EOF
            success "Configured remote Presidio server (${UP_P_URL:-http://localhost:5001}) in .env."
            ;;
        *)
            cat << 'NER_EOF' >> .env

# Pluggable AI / Deep NER Detection Engine (Microsoft Presidio)
PRESIDIO_ENABLED=false
PRESIDIO_MODE=disabled
PRESIDIO_URL=http://presidio:5001
PRESIDIO_CONFIDENCE_THRESHOLD=0.6
COMPOSE_PROFILES=
NER_EOF
            info "AI/NER engine remains disabled in .env (pure regex fast-path)."
            ;;
    esac
fi

info "Step 2/3: Updating environment configuration..."
export FILTR_IMAGE="${TARGET_IMAGE}"

if [ -f .env ]; then
    if grep -q '^FILTR_IMAGE=' .env; then
        sed -i "s|^FILTR_IMAGE=.*|FILTR_IMAGE=${TARGET_IMAGE}|g" .env
    else
        echo "FILTR_IMAGE=${TARGET_IMAGE}" >> .env
    fi
    success "Updated FILTR_IMAGE in .env to ${TARGET_IMAGE}"
else
    cat << EOF > .env
PORT=${CURRENT_PORT}
FILTR_IMAGE=${TARGET_IMAGE}
EOF
    success "Created .env with FILTR_IMAGE=${TARGET_IMAGE}"
fi


# Step 2.5: Synchronize enterprise rules JSON packs as part of product deployment
info "Ensuring official enterprise detection rule packs are present..."
mkdir -p ./rules
# Synchronize manage-ner.sh into deployment directory
if [ -f "${SCRIPT_DIR}/manage-ner.sh" ]; then
    if [ "${SCRIPT_DIR}" != "$(pwd)" ]; then
        cp -f "${SCRIPT_DIR}/manage-ner.sh" ./manage-ner.sh 2>/dev/null || true
    fi
    chmod +x ./manage-ner.sh 2>/dev/null || true
fi


for json_pack in ./rules/filtr_export_*.json ./filtr_export_*.json ./public/filtr_export_*.json; do
    [ -f "$json_pack" ] && cp -f "$json_pack" ./rules/ 2>/dev/null || true

done

    # Automated verification and healing of mounted nginx.conf for API routing
    if [ -f "nginx.conf" ]; then
        if ! grep -q 'location \^\~ /api' nginx.conf && ! grep -q 'location /api' nginx.conf; then
            info "Detected mounted custom nginx.conf missing /api reverse proxy routing. Auto-patching..."
            sed -i '/error_page 405 =200/d' nginx.conf
            sed -i '/location \/assets\/ {/i \        # Reverse proxy REST API requests to internal Filtr SQLite API server\n        location ^~ /api {\n            proxy_pass http://127.0.0.1:3000;\n            proxy_http_version 1.1;\n            proxy_set_header Host $host;\n            proxy_set_header X-Real-IP $remote_addr;\n            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n            proxy_set_header X-Forwarded-Proto $scheme;\n            proxy_connect_timeout 10s;\n            proxy_read_timeout 60s;\n            proxy_intercept_errors off;\n            add_header Cache-Control "no-store, no-cache, must-revalidate" always;\n            add_header X-Content-Type-Options "nosniff" always;\n        }\n' nginx.conf
            success "Mounted nginx.conf successfully patched with /api API reverse proxy."
        fi
    fi

# Export COMPOSE_PROFILES from .env if present
if [ -f .env ]; then
    P_PROF=$(grep -E '^COMPOSE_PROFILES=' .env | cut -d'=' -f2- | tr -d '"' | tr -d "'" || echo "")
    if [ -n "${P_PROF}" ]; then
        export COMPOSE_PROFILES="${P_PROF}"
        info "Active container profile(s): ${COMPOSE_PROFILES}"
    fi
fi

# Step 2.6: Pre-upgrade automated database & custom rules backup
info "Backing up persistent SQLite database and custom detection rules..."
mkdir -p ./data ./rules
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'filtr-app'; then
    BACKUP_TS="$(date +%Y%m%d_%H%M%S)"
    docker cp filtr-app:/data/filtr.db "./data/filtr-backup-${BACKUP_TS}.db" 2>/dev/null || true
    docker cp filtr-app:/data/filtr.db ./data/filtr.db 2>/dev/null || true
    docker cp filtr-app:/data/custom_rules.json ./rules/custom_rules_backup.json 2>/dev/null || true
    success "Preserved pre-upgrade database backup (filtr-backup-${BACKUP_TS}.db) and custom rules."
fi

# Ensure docker-compose.yml has persistent volume for /data
if [ -f "docker-compose.yml" ]; then
    if ! grep -q 'filtr-data:/data' docker-compose.yml; then
        info "Healing docker-compose.yml: ensuring persistent filtr-data:/data volume is mounted..."
        # If volumes section under filtr doesn't exist, insert it
        if grep -q 'container_name: filtr-app' docker-compose.yml; then
            sed -i '/container_name: filtr-app/a \    volumes:\n      - filtr-data:/data' docker-compose.yml
        fi
        if ! grep -q '^volumes:' docker-compose.yml; then
            cat << 'V_EOF' >> docker-compose.yml

volumes:
  filtr-data:
    name: filtr-data
V_EOF
        fi
        success "docker-compose.yml patched with persistent filtr-data volume."
    fi
fi

info "Step 3/3: Applying rolling container restart with zero-downtime..." 
# Ensure both tags exist in local daemon prior to starting compose
docker tag "${LOCAL_IMAGE}" "${TARGET_IMAGE}" 2>/dev/null || true
docker tag "${TARGET_IMAGE}" "${LOCAL_IMAGE}" 2>/dev/null || true

export FILTR_IMAGE="${TARGET_IMAGE}"

# Prioritize local loaded image without triggering remote pull failure
if ! FILTR_IMAGE="${TARGET_IMAGE}" ${COMPOSE_CMD} up -d --force-recreate --no-build --pull never 2>/dev/null; then
    FILTR_IMAGE="${TARGET_IMAGE}" ${COMPOSE_CMD} up -d --force-recreate --no-build
fi

# Ensure running container has transitioned to the target image
RUNNING_IMAGE="$(docker inspect --format='{{.Config.Image}}' filtr-app 2>/dev/null || echo "")"
if [ -n "${RUNNING_IMAGE}" ] && [ "${RUNNING_IMAGE}" != "${TARGET_IMAGE}" ] && [ "${RUNNING_IMAGE}" != "${LOCAL_IMAGE}" ]; then
    warn "Detected running container filtr-app still on ${RUNNING_IMAGE}. Forcing clean container recreation..."
    docker stop filtr-app >/dev/null 2>&1 || true
    docker rm filtr-app >/dev/null 2>&1 || true
    FILTR_IMAGE="${TARGET_IMAGE}" ${COMPOSE_CMD} up -d --force-recreate --no-build
fi

info "Verifying service availability and running container image..."
MAX_RETRIES=15
COUNTER=0
HEALTHY=false
IMAGE_VERIFIED=false
FINAL_RUNNING_IMAGE=""

while [ $COUNTER -lt $MAX_RETRIES ]; do
    FINAL_RUNNING_IMAGE="$(docker inspect --format='{{.Config.Image}}' filtr-app 2>/dev/null || echo "")"
    if [ "${FINAL_RUNNING_IMAGE}" = "${TARGET_IMAGE}" ] || [ "${FINAL_RUNNING_IMAGE}" = "${LOCAL_IMAGE}" ]; then
        IMAGE_VERIFIED=true
    fi

    if [ "${IMAGE_VERIFIED}" = true ]; then
        if curl -s -f "http://127.0.0.1:${CURRENT_PORT}/healthz" >/dev/null 2>&1 || \
           curl -s -f "http://127.0.0.1:${CURRENT_PORT}/" >/dev/null 2>&1; then
            HEALTHY=true
            break
        fi
    fi
    sleep 1
    COUNTER=$((COUNTER + 1))
done

echo ""
echo "=========================================================="
if [ "$HEALTHY" = true ] && [ "$IMAGE_VERIFIED" = true ]; then
    if [ "${IS_ROLLBACK}" = true ]; then
        success "${APP_NAME} stack successfully ROLLED BACK to ${TARGET_VERSION}!"
    else
        success "${APP_NAME} stack successfully updated to ${TARGET_VERSION}!"
    fi
    echo -e "  Port:      ${BOLD}${CURRENT_PORT}${NC}"
    echo -e "  Image:     ${BOLD}${FINAL_RUNNING_IMAGE}${NC}"
    echo -e "  Status:    ${GREEN}Healthy (Listening and Active)${NC}"
elif [ "$IMAGE_VERIFIED" = false ]; then
    error "Upgrade verification failed: Running container filtr-app is on '${FINAL_RUNNING_IMAGE:-unknown}', expected '${TARGET_IMAGE}'"
    warn "Remediate manually: docker stop filtr-app && docker rm filtr-app && FILTR_IMAGE=${TARGET_IMAGE} ${COMPOSE_CMD} up -d --force-recreate"
else
    warn "Container recreated with ${TARGET_IMAGE}, but health verification timed out."
    warn "Inspect container status and logs with: ${COMPOSE_CMD} logs"
fi
echo "=========================================================="
