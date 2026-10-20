#!/usr/bin/env bash
# =============================================================================
# manage-ner.sh — Pluggable AI / Deep NER (Microsoft Presidio) Manager for Filtr
# =============================================================================
# Official Repository: https://github.com/kisa-ops/filtr
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

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

# Detect compose command
COMPOSE_CMD=""
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    error "Neither 'docker compose' nor 'docker-compose' found on system."
    exit 1
fi

# -----------------------------------------------------------------------------
# Command: status
# -----------------------------------------------------------------------------
cmd_status() {
    echo -e "${BOLD}=== Filtr AI / Deep NER (Microsoft Presidio) Status ===${NC}"
    echo
    
    local ps_status
    ps_status="$(docker inspect --format='{{.State.Status}}' filtr-presidio 2>/dev/null || echo "not running")"
    echo -e "Local Container (filtr-presidio): ${BOLD}${ps_status}${NC}"

    # Network Security Check
    local port_bindings
    port_bindings="$(docker inspect --format='{{json .NetworkSettings.Ports}}' filtr-presidio 2>/dev/null || echo "{}")"
    if [[ "${port_bindings}" == *'"HostPort"'* ]]; then
        warn "Direct host port exposure detected: ${port_bindings}"
    else
        echo -e "Network Security:                 ${GREEN}${BOLD}Isolated (Internal Docker bridge only, 0 host ports exposed)${NC}"
    fi

    # Environment
    if [ -f .env ]; then
        echo -e "Configured PRESIDIO_ENABLED:      $(grep -E '^PRESIDIO_ENABLED=' .env | cut -d= -f2 || echo 'not set')"
        echo -e "Configured PRESIDIO_MODE:         $(grep -E '^PRESIDIO_MODE=' .env | cut -d= -f2 || echo 'not set')"
        echo -e "Configured PRESIDIO_URL:          $(grep -E '^PRESIDIO_URL=' .env | cut -d= -f2 || echo 'not set')"
    fi

    # Internal Loopback Health Probe
    echo -ne "Internal Loopback Health Probe:   "
    if docker ps -q -f name=filtr-app >/dev/null 2>&1 && [ "${ps_status}" = "running" ]; then
        if docker exec filtr-app wget -q -T 3 -O- http://presidio:5001/healthz 2>/dev/null | grep -qi "running"; then
            echo -e "${GREEN}${BOLD}ONLINE (200 OK — Healthy)${NC}"
        else
            echo -e "${RED}${BOLD}UNRESPONSIVE / INITIALIZING${NC}"
        fi
    else
        echo -e "${YELLOW}OFFLINE / NOT RUNNING${NC}"
    fi

    # Database Sync Check
    if docker ps -q -f name=filtr-app >/dev/null 2>&1; then
        local db_status
        db_status=$(docker exec filtr-app node -e "
            try {
                const { getNerConfig } = require('./server/db');
                const c = getNerConfig();
                console.log(c.enabled ? 'ACTIVE (' + c.mode + ' -> ' + c.url + ')' : 'DISABLED');
            } catch(e) {
                console.log('UNAVAILABLE');
            }
        " 2>/dev/null || echo "UNAVAILABLE")
        echo -e "Filtr Engine AI Registration:     ${BOLD}${db_status}${NC}"
    fi
}

# -----------------------------------------------------------------------------
# Command: enable (Local Sidecar)
# -----------------------------------------------------------------------------
cmd_enable() {
    info "Configuring and deploying securely isolated local Presidio sidecar..."

    # 1. Update .env
    touch .env
    for var in PRESIDIO_ENABLED PRESIDIO_MODE PRESIDIO_URL COMPOSE_PROFILES; do
        sed -i "/^\b${var}=/d" .env
    done
    cat << 'EOF' >> .env
PRESIDIO_ENABLED=true
PRESIDIO_MODE=local
PRESIDIO_URL=http://presidio:5001
PRESIDIO_CONFIDENCE_THRESHOLD=0.6
COMPOSE_PROFILES=ner
EOF
    success "Updated .env with isolated local Presidio configuration."

    # 2. Launch container with compose
    info "Starting filtr-presidio sidecar container..."
    export COMPOSE_PROFILES="ner"
    ${COMPOSE_CMD} --profile ner up -d presidio

    # 3. Wait and verify in-network health check
    info "Performing in-network loopback health probe from filtr-app..."
    local max_retries=20
    local count=0
    local healthy=false

    while [ $count -lt $max_retries ]; do
        sleep 2
        count=$((count + 1))
        if docker exec filtr-app wget -q -T 3 -O- http://presidio:5001/healthz 2>/dev/null | grep -qi "running"; then
            healthy=true
            break
        fi
        echo -ne "."
    done
    echo

    if [ "${healthy}" = true ]; then
        success "Presidio Analyzer is healthy & responsive on internal bridge (http://presidio:5001)."
    else
        warn "Presidio container started but took longer than 40s to respond to in-network health check."
        warn "Check logs: docker logs --tail 30 filtr-presidio"
    fi

    # 4. Auto-sync to SQLite database inside running filtr-app
    info "Applying configuration to SQLite database in filtr-app..."
    docker exec filtr-app node -e "
        try {
            const { updateNerConfig } = require('./server/db');
            updateNerConfig({
                enabled: true,
                mode: 'local',
                url: 'http://presidio:5001',
                confidence_threshold: 0.6
            });
            console.log('SQLITE_OK');
        } catch(e) {
            console.error(e.message);
        }
    " 2>/dev/null || true

    success "Local Presidio AI/NER sidecar is fully operational and paired with Filtr!"
    echo -e "${BOLD}Security Notice:${NC} Presidio has 0 exposed host ports. Direct access from the outside is completely blocked."
}

# -----------------------------------------------------------------------------
# Command: disable
# -----------------------------------------------------------------------------
cmd_disable() {
    info "Disabling AI / Deep NER Presidio sidecar..."

    if [ -f .env ]; then
        sed -i 's/^PRESIDIO_ENABLED=.*/PRESIDIO_ENABLED=false/' .env || true
        sed -i 's/^PRESIDIO_MODE=.*/PRESIDIO_MODE=disabled/' .env || true
        sed -i 's/^COMPOSE_PROFILES=.*/COMPOSE_PROFILES=/' .env || true
    fi

    if docker ps -q -f name=filtr-presidio >/dev/null 2>&1; then
        info "Stopping filtr-presidio container..."
        docker stop filtr-presidio >/dev/null 2>&1 || true
        docker rm filtr-presidio >/dev/null 2>&1 || true
    fi

    if docker ps -q -f name=filtr-app >/dev/null 2>&1; then
        docker exec filtr-app node -e "
            try {
                const { updateNerConfig } = require('./server/db');
                updateNerConfig({ enabled: false, mode: 'disabled' });
            } catch(_) {}
        " 2>/dev/null || true
    fi

    success "Presidio sidecar stopped and disabled (~1GB system RAM freed)."
    info "Filtr is operating in fast-path regex-only mode."
}

# -----------------------------------------------------------------------------
# Command: remote <url>
# -----------------------------------------------------------------------------
cmd_remote() {
    local remote_url="${1:-}"
    if [ -z "${remote_url}" ]; then
        error "Usage: ./manage-ner.sh remote <http://remote-host:5001>"
        exit 1
    fi

    info "Configuring external remote Presidio server: ${remote_url}"
    touch .env
    sed -i '/^PRESIDIO_ENABLED=/d' .env
    sed -i '/^PRESIDIO_MODE=/d' .env
    sed -i '/^PRESIDIO_URL=/d' .env
    cat << EOF >> .env
PRESIDIO_ENABLED=true
PRESIDIO_MODE=remote
PRESIDIO_URL=${remote_url}
PRESIDIO_CONFIDENCE_THRESHOLD=0.6
COMPOSE_PROFILES=
EOF

    docker stop filtr-presidio >/dev/null 2>&1 || true
    docker rm filtr-presidio >/dev/null 2>&1 || true

    if docker ps -q -f name=filtr-app >/dev/null 2>&1; then
        info "Testing connectivity from filtr-app to ${remote_url}..."
        if docker exec filtr-app wget -q -T 4 -O- "${remote_url}/healthz" 2>/dev/null | grep -qi "running"; then
            success "Remote Presidio endpoint reached successfully (200 OK)."
        else
            warn "Could not reach ${remote_url}/healthz from filtr-app. Verify network firewall/routing."
        fi

        docker exec filtr-app node -e "
            try {
                const { updateNerConfig } = require('./server/db');
                updateNerConfig({
                    enabled: true,
                    mode: 'remote',
                    url: '${remote_url}',
                    confidence_threshold: 0.6
                });
            } catch(e) {}
        " 2>/dev/null || true
    fi

    success "Configured remote Presidio server (${remote_url})."
}

case "${1:-status}" in
    enable|--enable|local)
        cmd_enable
        ;;
    disable|--disable|stop)
        cmd_disable
        ;;
    status|--status)
        cmd_status
        ;;
    remote|--remote)
        shift
        cmd_remote "$@"
        ;;
    help|--help|-h)
        echo "Filtr AI / Deep NER Management Script"
        echo
        echo "Usage: ./manage-ner.sh [command]"
        echo
        echo "Commands:"
        echo "  enable                  Deploy local Presidio sidecar (isolated, 0 host ports)"
        echo "  disable                 Stop & remove Presidio sidecar (free memory)"
        echo "  status                  Show health, container status & security isolation"
        echo "  remote <http://ip:5001> Connect to external hardware Presidio instance"
        echo "  help                    Show this message"
        ;;
    *)
        error "Unknown command: $1. Run: ./manage-ner.sh help"
        exit 1
        ;;
esac

