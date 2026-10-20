#!/usr/bin/env bash
# =============================================================================
# manage-ssl.sh — SSL / TLS Certificate Manager for filtr
# =============================================================================
# Official Repository: https://github.com/kisa-ops/filtr
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

if [ -f "./install.sh" ]; then
    exec ./install.sh --update-ssl "$@"
else
    echo "Error: install.sh not found in ${SCRIPT_DIR}" >&2
    exit 1
fi
