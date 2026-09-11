#!/usr/bin/env bash
# =============================================================================
# install.sh — Enterprise Production Installer for filtr
# =============================================================================
# Official Repository: https://github.com/kisa-ops/filtr
# =============================================================================

set -euo pipefail

APP_NAME="filtr"
VERSION="v1.3.0"
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

# Determine default installation directory
# If user is in /tmp or /var/tmp or executing via pipe, default to /opt/filtr
CURRENT_DIR="$(pwd)"
if [[ "${CURRENT_DIR}" == /tmp* ]] || [[ "${CURRENT_DIR}" == /var/tmp* ]]; then
    if [ "$(id -u)" -eq 0 ] || command -v sudo >/dev/null 2>&1; then
        DEFAULT_INSTALL_DIR="/opt/filtr"
    else
        DEFAULT_INSTALL_DIR="${HOME}/filtr"
    fi
elif [ -f "./docker-compose.yml" ] && [ -f "./install.sh" ]; then
    DEFAULT_INSTALL_DIR="${CURRENT_DIR}"
else
    if [ "$(id -u)" -eq 0 ] || command -v sudo >/dev/null 2>&1; then
        DEFAULT_INSTALL_DIR="/opt/filtr"
    else
        DEFAULT_INSTALL_DIR="${HOME}/filtr"
    fi
fi

INSTALL_DIR="${DEFAULT_INSTALL_DIR}"
HTTP_PORT="8080"
BIND_IP="0.0.0.0"
ENABLE_SSL=false
SSL_PORT="8443"
SSL_MODE="" # "self-signed" or "custom"
SSL_DOMAIN="localhost"
SSL_CERT_PATH=""
SSL_KEY_PATH=""
SSL_CA_PATH=""
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
    echo "  -d, --install-dir <path>  Target installation directory (default: /opt/filtr or current dir)"
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
        -d|--dir|--install-dir)
            INSTALL_DIR="$2"; shift 2 ;;
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
echo -e "${BOLD}Enterprise Sensitive Data Redaction Platform — ${VERSION}${NC}"
echo -e "${GRAY}Distribution: https://github.com/kisa-ops/filtr${NC}"
echo "=========================================================="
echo

# Helper function to prompt user for a valid file path
prompt_file_path() {
    local title="$1"
    local target_var="$2"
    local is_optional="${3:-false}"

    echo
    if [ "${is_optional}" = true ]; then
        read -rp "Do you want to provide a ${title}? [y/N]: " PROVIDE_IT
        if [[ ! "${PROVIDE_IT}" =~ ^[Yy]$ ]]; then
            eval "${target_var}=''"
            return 0
        fi
    fi

    while true; do
        read -rp "Enter path to ${title} file: " GIVEN_PATH
        if [ -f "${GIVEN_PATH}" ]; then
            eval "${target_var}=\"\${GIVEN_PATH}\""
            success "${title} found at: ${GIVEN_PATH}"
            break
        else
            warn "File not found: ${GIVEN_PATH}. Please provide a valid file path."
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
    echo -e "${BOLD}--- [1/4] Installation Directory ---${NC}"
    read -rp "Enter installation directory [default: ${INSTALL_DIR}]: " INPUT_DIR
    INSTALL_DIR="${INPUT_DIR:-${INSTALL_DIR}}"

    echo
    echo -e "${BOLD}--- [2/4] Network & Port Configuration ---${NC}"
    
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
    echo -e "${BOLD}--- [3/4] SSL / TLS Security Configuration ---${NC}"
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
                prompt_file_path "SSL Server Certificate (.crt / fullchain.pem)" SSL_CERT_PATH false
                prompt_file_path "SSL Private Key (.key / privkey.pem)" SSL_KEY_PATH false
                prompt_file_path "Root or CA Certificate (ca.pem / rootCA.crt)" SSL_CA_PATH true
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
    echo -e "${BOLD}--- [4/4] Production System Integration ---${NC}"
    if command -v systemctl >/dev/null 2>&1; then
        read -rp "Install and enable systemd service (auto-starts on system boot)? [y/N]: " ASK_SYSTEMD
        if [[ "${ASK_SYSTEMD}" =~ ^[Yy]$ ]]; then
            INSTALL_SYSTEMD=true
        fi
    fi
elif [ "${UPDATE_SSL_ONLY}" = true ] && [ -t 0 ]; then
    echo -e "${BOLD}--- SSL / TLS Certificate Update Wizard ---${NC}"
    ENABLE_SSL=true
    prompt_file_path "SSL Server Certificate (.crt / fullchain.pem)" SSL_CERT_PATH false
    prompt_file_path "SSL Private Key (.key / privkey.pem)" SSL_KEY_PATH false
    prompt_file_path "Root or CA Certificate (ca.pem / rootCA.crt)" SSL_CA_PATH true
fi

# -----------------------------------------------------------------------------
# 3. Setup Dedicated Installation Directory
# -----------------------------------------------------------------------------
info "Setting up installation directory: ${INSTALL_DIR}..."

# Create directory with appropriate permissions
if [ ! -d "${INSTALL_DIR}" ]; then
    if mkdir -p "${INSTALL_DIR}" 2>/dev/null; then
        :
    elif [ "$(id -u)" -eq 0 ]; then
        mkdir -p "${INSTALL_DIR}"
    elif command -v sudo >/dev/null 2>&1; then
        if [ -t 0 ] && [ "${UNATTENDED}" = false ]; then
            info "Attempting to create ${INSTALL_DIR} with sudo..."
            if sudo mkdir -p "${INSTALL_DIR}" 2>/dev/null && sudo chown -R "$(id -u):$(id -g)" "${INSTALL_DIR}" 2>/dev/null; then
                success "Created ${INSTALL_DIR}"
            else
                warn "Could not create ${INSTALL_DIR} with sudo. Falling back to user home directory: ${HOME}/filtr"
                INSTALL_DIR="${HOME}/filtr"
                mkdir -p "${INSTALL_DIR}"
            fi
        else
            INSTALL_DIR="${HOME}/filtr"
            info "Falling back to user home directory: ${INSTALL_DIR}"
            mkdir -p "${INSTALL_DIR}"
        fi
    else
        warn "Cannot create ${INSTALL_DIR} without elevated privileges."
        INSTALL_DIR="${HOME}/filtr"
        info "Falling back to user home directory: ${INSTALL_DIR}"
        mkdir -p "${INSTALL_DIR}"
    fi
fi

# Copy existing repo assets if running from a git clone or /tmp
SRC_DIR="${CURRENT_DIR}"
if [ "${SRC_DIR}" != "${INSTALL_DIR}" ]; then
    [ -f "${SRC_DIR}/docker-compose.yml" ] && cp -f "${SRC_DIR}/docker-compose.yml" "${INSTALL_DIR}/"
    [ -f "${SRC_DIR}/upgrade.sh" ] && cp -f "${SRC_DIR}/upgrade.sh" "${INSTALL_DIR}/"
    [ -f "${SRC_DIR}/manage-ssl.sh" ] && cp -f "${SRC_DIR}/manage-ssl.sh" "${INSTALL_DIR}/"
    if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
        cp -f "${BASH_SOURCE[0]}" "${INSTALL_DIR}/install.sh"
        chmod +x "${INSTALL_DIR}/install.sh"
    fi
fi

# Change working directory to the target installation directory
cd "${INSTALL_DIR}"

# Ensure install.sh exists in target directory (e.g. if installed via curl pipe)
if [ ! -f ./install.sh ]; then
    curl -fsSL "https://raw.githubusercontent.com/kisa-ops/filtr/main/install.sh" -o ./install.sh 2>/dev/null && chmod +x ./install.sh || true
fi

# -----------------------------------------------------------------------------
# 4. Environment Configuration (.env & docker-compose.yml)
# -----------------------------------------------------------------------------
info "Configuring environment in ${INSTALL_DIR}..."

if [ -f .env ] && [ "${UPDATE_SSL_ONLY}" = true ]; then
    # Preserve existing ports and only update SSL flags
    sed -i "s|^SSL_ENABLED=.*|SSL_ENABLED=true|g" .env || echo "SSL_ENABLED=true" >> .env
else
    cat << EOF > .env
# filtr Production Environment Configuration
# Installed in: ${INSTALL_DIR}
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

# Ensure docker-compose.yml exists in the installation directory
if [ ! -f docker-compose.yml ]; then
    cat << EOF > docker-compose.yml
services:
  filtr:
    image: \${FILTR_IMAGE:-${IMAGE_TAG}}
    container_name: filtr-app
    restart: unless-stopped
    ports:
      - "\${BIND_IP:-0.0.0.0}:\${PORT:-8080}:80"
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    healthcheck:
      test: ["CMD-SHELL", "wget -q --spider http://127.0.0.1/healthz || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 5s
EOF
fi

# Ensure manage-ssl.sh exists in installation directory
cat << 'EOF' > manage-ssl.sh
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"
if [ -f "./install.sh" ]; then
    exec ./install.sh --update-ssl "$@"
else
    echo "Error: install.sh not found in ${SCRIPT_DIR}" >&2
    exit 1
fi
EOF
chmod +x manage-ssl.sh

# Ensure upgrade.sh exists and is up-to-date in installation directory
if [ -f "${SRC_DIR}/upgrade.sh" ]; then
    cp -f "${SRC_DIR}/upgrade.sh" "${INSTALL_DIR}/upgrade.sh"
    chmod +x "${INSTALL_DIR}/upgrade.sh"
else
    cat << 'UPGRADE_SCRIPT_PAYLOAD_EOF' > "${INSTALL_DIR}/upgrade.sh"
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

UPGRADE_SCRIPT_PAYLOAD_EOF
    chmod +x "${INSTALL_DIR}/upgrade.sh"
fi

# -----------------------------------------------------------------------------
# 5. SSL Certificate Generation & ssl-info.json
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
        success "Self-signed certificate generated in ${INSTALL_DIR}/ssl/ (valid for 365 days)."
    elif [ -n "${SSL_CERT_PATH}" ] && [ -n "${SSL_KEY_PATH}" ]; then
        info "Installing custom SSL certificates from file paths..."
        if [ -n "${SSL_CA_PATH}" ] && [ -f "${SSL_CA_PATH}" ]; then
            cat "${SSL_CERT_PATH}" "${SSL_CA_PATH}" > ssl/cert.pem
            cp -f "${SSL_CA_PATH}" ssl/ca.pem
            chmod 644 ssl/ca.pem
            success "Root/CA certificate appended to certificate chain."
        else
            cp -f "${SSL_CERT_PATH}" ssl/cert.pem
        fi
        cp -f "${SSL_KEY_PATH}" ssl/key.pem
        chmod 600 ssl/key.pem
        chmod 644 ssl/cert.pem
        success "Certificates copied to ${INSTALL_DIR}/ssl/"
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
        success "Certificate metadata saved to ${INSTALL_DIR}/ssl/ssl-info.json"
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

    # Create docker-compose.override.yml in installation directory
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
# 6. Image Retrieval (GHCR Pull or Release Asset Fallback)
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
# 7. Launch Production Container Stack
# -----------------------------------------------------------------------------
info "Starting ${APP_NAME} production container from ${INSTALL_DIR}..."

# Clean up any existing container running from /tmp or elsewhere to prevent name collisions
if docker ps -a --format '{{.Names}}' | grep -Eq "^filtr-app$"; then
    info "Stopping previous filtr-app container instance..."
    docker stop filtr-app >/dev/null 2>&1 || true
    docker rm filtr-app >/dev/null 2>&1 || true
fi

${COMPOSE_CMD} up -d --remove-orphans

# -----------------------------------------------------------------------------
# 8. Systemd Service Integration (Optional)
# -----------------------------------------------------------------------------
if [ "${INSTALL_SYSTEMD}" = true ]; then
    info "Configuring systemd service..."
    SERVICE_FILE="/etc/systemd/system/filtr.service"
    DOCKER_BIN="$(command -v docker)"

    SYSTEMD_CONTENT="[Unit]
Description=filtr - Data Redaction Platform
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${INSTALL_DIR}
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
# 9. Firewall Inspection & Advice
# -----------------------------------------------------------------------------
if command -v ufw >/dev/null 2>&1 && sudo ufw status 2>/dev/null | grep -q "Status: active"; then
    echo
    warn "UFW firewall is active. You may need to allow incoming traffic:"
    echo "  sudo ufw allow ${HTTP_PORT}/tcp"
    [ "${ENABLE_SSL}" = true ] && echo "  sudo ufw allow ${SSL_PORT}/tcp"
fi

# -----------------------------------------------------------------------------
# 10. Healthcheck & Success Summary
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
echo -e "  ${BOLD}Installation Path:${NC} ${GREEN}${INSTALL_DIR}${NC}"
echo -e "  ${BOLD}Container Name:${NC}    filtr-app"
echo
echo -e "  ${BOLD}Access Endpoints:${NC}"
if [ "${ENABLE_SSL}" = true ]; then
    echo -e "  • HTTPS:           ${CYAN}https://${SSL_DOMAIN}:${SSL_PORT}${NC}"
    if [ "${SSL_REDIRECT}" = true ]; then
        echo -e "  • HTTP:            ${GRAY}http://localhost:${HTTP_PORT}${NC} ${YELLOW}(redirects to HTTPS)${NC}"
    else
        echo -e "  • HTTP:            ${CYAN}http://localhost:${HTTP_PORT}${NC}"
    fi
else
    echo -e "  • HTTP:            ${CYAN}http://localhost:${HTTP_PORT}${NC}"
fi
echo
echo -e "${BOLD}Operational Commands:${NC}"
echo "  • Change to app dir:   cd ${INSTALL_DIR}"
echo "  • View live logs:      docker compose logs -f"
echo "  • Check container:     docker compose ps"
echo "  • Update SSL certs:    ./manage-ssl.sh"
echo "  • Restart stack:       docker compose restart"
echo "  • Stop stack:          docker compose down"
echo "  • Upgrade to latest:   ./upgrade.sh"
[ "${INSTALL_SYSTEMD}" = true ] && echo "  • Systemd status:      sudo systemctl status filtr"
echo "=========================================================="
echo
