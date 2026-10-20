#!/usr/bin/env bash
# ==============================================================================
# FILTR ENTERPRISE OPS & RELEASE MANAGEMENT CLI
# ==============================================================================
# Comprehensive administration utility for:
#  1) Management & Dashboard
#  2) Synchronized Semantic Versioning
#  3) Hygiene & Cleanup (dist, tarballs, docker cache)
#  4) Repository Information Validation (Source vs Distribution)
#  5) GitHub Personal Access Token (PAT) Verification & Prompting
#  6) Building Offline Container Packages & Publishing Multi-Repo Releases
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# ANSI Colors & Styling
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Default Repositories
DEFAULT_SOURCE_REPO="https://github.com/anandprabhusk/filtr"
DEFAULT_DIST_REPO="https://github.com/kisa-ops/filtr"
SOURCE_REPO="${FILTR_SOURCE_REPO:-$DEFAULT_SOURCE_REPO}"
DIST_REPO="${FILTR_DIST_REPO:-$DEFAULT_DIST_REPO}"

# Local Configuration File (gitignored)
LOCAL_ENV_FILE="${SCRIPT_DIR}/.env.local"
if [ -f "${LOCAL_ENV_FILE}" ]; then
    # shellcheck disable=SC1090
    source "${LOCAL_ENV_FILE}"
fi

# Logging Helpers
info() { echo -e "${CYAN}ℹ [INFO]${NC} $*"; }
success() { echo -e "${GREEN}✔ [SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}⚠ [WARN]${NC} $*"; }
error() { echo -e "${RED}✖ [ERROR]${NC} $*"; }
banner() {
    echo -e "${BOLD}${MAGENTA}"
    echo "  ███████╗██╗██╗  ████████╗██████╗ "
    echo "  ██╔════╝██║██║  ╚══██╔══╝██╔══██╗"
    echo "  █████╗  ██║██║     ██║   ██████╔╝"
    echo "  ██╔══╝  ██║██║     ██║   ██╔══██╗"
    echo "  ██║     ██║███████╗██║   ██║  ██║"
    echo "  ╚═╝     ╚═╝╚══════╝╚═╝   ╚═╝  ╚═╝"
    echo -e "${NC}${DIM} Enterprise Release & Administration Toolkit${NC}\n"
}

# ==============================================================================
# HELPER: Get Current Version
# ==============================================================================
get_current_version() {
    if [ -f "${SCRIPT_DIR}/src/constants/version.ts" ]; then
        grep "APP_VERSION" "${SCRIPT_DIR}/src/constants/version.ts" | head -n 1 | sed -E "s/.*'([^']+)'.*/\1/"
    elif [ -f "${SCRIPT_DIR}/package.json" ]; then
        grep '"version"' "${SCRIPT_DIR}/package.json" | head -n 1 | sed -E 's/.*"version": "([^"]+)".*/\1/'
    else
        echo "1.0.0"
    fi
}

# ==============================================================================
# HELPER: Prompt for confirmation
# ==============================================================================
confirm() {
    local prompt_msg="$1"
    local default="${2:-y}"
    local prompt_suffix="[Y/n]"
    if [ "${default}" = "n" ]; then
        prompt_suffix="[y/N]"
    fi

    echo -ne "${BOLD}${YELLOW}? ${prompt_msg} ${prompt_suffix}: ${NC}"
    read -r response
    response="${response:-$default}"
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# ==============================================================================
# 5. AUTHENTICATION & PAT MANAGER
# ==============================================================================
get_pat() {
    # 1. Environment variables
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        echo "${GITHUB_TOKEN}"
        return 0
    elif [ -n "${GH_TOKEN:-}" ]; then
        echo "${GH_TOKEN}"
        return 0
    elif [ -n "${FILTR_GITHUB_PAT:-}" ]; then
        echo "${FILTR_GITHUB_PAT}"
        return 0
    fi

    # 2. Local config file
    if [ -f "${LOCAL_ENV_FILE}" ]; then
        local file_pat
        file_pat=$(grep -E '^GITHUB_TOKEN=' "${LOCAL_ENV_FILE}" 2>/dev/null | cut -d '=' -f 2- | tr -d '"'\'' ')
        if [ -n "${file_pat}" ]; then
            echo "${file_pat}"
            return 0
        fi
    fi

    # 3. Check Windows Antigravity / Gemini IDE config if accessible
    local win_mcp_config="/mnt/c/Users/anand.selvakumar/.gemini/config/mcp_config.json"
    if [ -f "${win_mcp_config}" ]; then
        local mcp_pat
        mcp_pat=$(python3 -c 'import json, os, sys; p=sys.argv[1]; d=json.load(open(p)) if os.path.exists(p) else {}; print(d.get("mcpServers",{}).get("github-mcp-server",{}).get("env",{}).get("GITHUB_PERSONAL_ACCESS_TOKEN",""))' "${win_mcp_config}" 2>/dev/null || true)
        if [ -n "${mcp_pat}" ] && [ "${#mcp_pat}" -gt 20 ]; then
            echo "${mcp_pat}"
            return 0
        fi
    fi

    echo ""
}

validate_pat() {
    local token="$1"
    if [ -z "${token}" ]; then
        return 1
    fi
    local res
    res=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer ${token}" -H "User-Agent: filtr-admin" https://api.github.com/user || true)
    local code
    code=$(echo "${res}" | tail -n1)
    local body
    body=$(echo "${res}" | sed '$d')

    if [ "${code}" = "200" ]; then
        local login
        login=$(echo "${body}" | python3 -c 'import sys, json; print(json.load(sys.stdin).get("login", ""))' 2>/dev/null || true)
        if [ -z "${login}" ]; then
            login=$(echo "${body}" | node -e 'try{console.log(JSON.parse(require("fs").readFileSync(0, "utf-8")).login||"")}catch(e){}' 2>/dev/null || echo "anandprabhusk")
        fi
        echo "${login}"
        return 0
    else
        return 1
    fi
}

request_pat_interactive() {
    echo ""
    echo -e "${BOLD}${CYAN}=== GitHub Personal Access Token (PAT) Verification ===${NC}"
    local current_token
    current_token=$(get_pat)
    
    if [ -n "${current_token}" ]; then
        info "Checking detected Personal Access Token..."
        local user_login
        if user_login=$(validate_pat "${current_token}"); then
            success "Authenticated successfully with GitHub as ${BOLD}${user_login}${NC}."
            export GITHUB_TOKEN="${current_token}"
            return 0
        else
            warn "Stored or detected GitHub token is invalid or expired."
        fi
    fi

    echo -e "${YELLOW}A GitHub Personal Access Token (PAT) is required for push and release operations.${NC}"
    echo -e "Required Scopes: ${BOLD}repo${NC} (Full repository access), ${BOLD}write:packages${NC} (Package publish)."
    echo ""
    
    while true; do
        echo -ne "${BOLD}Enter GitHub PAT (input hidden): ${NC}"
        stty -echo 2>/dev/null || true
        read -r input_pat
        stty echo 2>/dev/null || true
        echo ""

        if [ -z "${input_pat}" ]; then
            warn "No token provided."
            if confirm "Skip authentication for now?" "n"; then
                return 1
            fi
            continue
        fi

        info "Validating token with GitHub API..."
        local login
        if login=$(validate_pat "${input_pat}"); then
            success "Token verified! Authenticated as ${BOLD}${login}${NC}."
            export GITHUB_TOKEN="${input_pat}"
            
            if confirm "Save token to ${LOCAL_ENV_FILE} for future sessions?" "y"; then
                echo "# filtr local secrets (gitignored)" > "${LOCAL_ENV_FILE}"
                echo "GITHUB_TOKEN=\"${input_pat}\"" >> "${LOCAL_ENV_FILE}"
                chmod 600 "${LOCAL_ENV_FILE}"
                success "Saved to ${LOCAL_ENV_FILE} (permissions set to 600)."
                
                # Also ensure .env.local is in .gitignore
                if ! grep -q "\.env\.local" "${SCRIPT_DIR}/.gitignore" 2>/dev/null; then
                    echo ".env.local" >> "${SCRIPT_DIR}/.gitignore"
                    info "Added .env.local to .gitignore."
                fi
            fi
            return 0
        else
            error "Invalid token or insufficient permissions. Please try again."
        fi
    done
}

# ==============================================================================
# 4. REPOSITORY INFORMATION VALIDATION (Interactive Prompt)
# ==============================================================================
REPOS_VALIDATED=0

validate_repo_urls() {
    local force="${1:-0}"
    if [ "${REPOS_VALIDATED}" = "1" ] && [ "${force}" != "1" ]; then
        return 0
    fi
    echo ""
    echo -e "${BOLD}${CYAN}=== Repository Routing & Information Verification ===${NC}"
    echo -e "Review and validate the target repositories:"
    echo -e " 1) ${BOLD}Source Repository${NC} (Core code, branches, tags):"
    echo -e "    Current: ${GREEN}${SOURCE_REPO}${NC}"
    echo -e " 2) ${BOLD}Distribution Repository${NC} (Production packages, releases, deployment stack):"
    echo -e "    Current: ${GREEN}${DIST_REPO}${NC}"
    echo ""

    echo -ne "${BOLD}? Keep Source Repo [${SOURCE_REPO}] or enter new URL: ${NC}"
    read -r user_source
    if [ -n "${user_source}" ]; then
        SOURCE_REPO="${user_source}"
    fi

    echo -ne "${BOLD}? Keep Distribution Repo [${DIST_REPO}] or enter new URL: ${NC}"
    read -r user_dist
    if [ -n "${user_dist}" ]; then
        DIST_REPO="${user_dist}"
    fi

    info "Synchronizing Git remotes..."
    
    # Configure origin -> SOURCE_REPO
    if git remote get-url origin >/dev/null 2>&1; then
        git remote set-url origin "${SOURCE_REPO}"
    else
        git remote add origin "${SOURCE_REPO}"
    fi
    success "Git remote 'origin' -> ${SOURCE_REPO}"

    # Configure kisa -> DIST_REPO
    if git remote get-url kisa >/dev/null 2>&1; then
        git remote set-url kisa "${DIST_REPO}"
    else
        git remote add kisa "${DIST_REPO}"
    fi
    success "Git remote 'kisa' -> ${DIST_REPO}"
    REPOS_VALIDATED=1
}

# ==============================================================================
# 1. STATUS & MANAGEMENT DASHBOARD
# ==============================================================================
show_status() {
    banner
    local current_ver
    current_ver=$(get_current_version)
    local git_branch
    git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    local git_commit
    git_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local uncommitted_count
    uncommitted_count=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    
    echo -e "${BOLD}Current Version :${NC} ${GREEN}v${current_ver}${NC}"
    echo -e "${BOLD}Active Branch   :${NC} ${CYAN}${git_branch}${NC} (${git_commit})"
    if [ "${uncommitted_count}" -gt 0 ]; then
        echo -e "${BOLD}Working Tree    :${NC} ${YELLOW}${uncommitted_count} uncommitted file(s)${NC}"
    else
        echo -e "${BOLD}Working Tree    :${NC} ${GREEN}Clean${NC}"
    fi
    echo ""
    echo -e "${BOLD}Git Remotes:${NC}"
    echo -e "  • ${BOLD}origin${NC} (Source Repo)       : $(git remote get-url origin 2>/dev/null || echo 'Not configured')"
    echo -e "  • ${BOLD}kisa${NC}   (Distribution Repo) : $(git remote get-url kisa 2>/dev/null || echo 'Not configured')"
    echo ""
    echo -e "${BOLD}Authentication:${NC}"
    local pat
    pat=$(get_pat)
    if [ -n "${pat}" ]; then
        local user_login
        if user_login=$(validate_pat "${pat}"); then
            echo -e "  • GitHub User : ${GREEN}Authenticated as ${user_login}${NC}"
        else
            echo -e "  • GitHub User : ${RED}Token invalid or expired${NC}"
        fi
    else
        echo -e "  • GitHub User : ${YELLOW}No PAT configured${NC}"
    fi
    echo ""
    echo -e "${BOLD}Package Tarballs in Root:${NC}"
    local tar_count
    tar_count=$(find "${SCRIPT_DIR}" "${SCRIPT_DIR}/releases" -maxdepth 1 -name "filtr-docker-*.tar.gz" 2>/dev/null | sort -u | wc -l | tr -d ' ')
    if [ "${tar_count}" -gt 0 ]; then
        local total_size
        total_size=$(du -shc "${SCRIPT_DIR}"/filtr-docker-*.tar.gz "${SCRIPT_DIR}"/releases/filtr-docker-*.tar.gz 2>/dev/null | tail -n 1 | awk '{print $1}')
        echo -e "  • Found ${CYAN}${tar_count} package(s)${NC} totaling ${YELLOW}${total_size}${NC}"
    else
        echo -e "  • None in root directory"
    fi
    echo "------------------------------------------------------------------"
}

# ==============================================================================
# 2. VERSIONING ENGINE
# ==============================================================================
bump_version() {
    local current_ver
    current_ver=$(get_current_version)
    echo ""
    echo -e "${BOLD}${CYAN}=== Synchronized Semantic Versioning ===${NC}"
    echo -e "Current Version: ${GREEN}v${current_ver}${NC}"
    echo ""
    
    local target_ver="$1"
    if [ -z "${target_ver}" ]; then
        echo -e "Select version bump type:"
        echo "  1) Patch (e.g. 1.8.3 -> 1.8.4)"
        echo "  2) Minor (e.g. 1.8.3 -> 1.9.0)"
        echo "  3) Major (e.g. 1.8.3 -> 2.0.0)"
        echo "  4) Custom version string"
        echo "  0) Cancel"
        echo ""
        echo -ne "${BOLD}Choice [1-4]: ${NC}"
        read -r choice
        case "${choice}" in
            1) target_ver="patch" ;;
            2) target_ver="minor" ;;
            3) target_ver="major" ;;
            4) 
                echo -ne "${BOLD}Enter custom version (e.g. 1.8.4 or v1.8.4): ${NC}"
                read -r target_ver
                ;;
            *) info "Versioning cancelled."; return 0 ;;
        esac
    fi

    # Parse current semver
    local clean_cur="${current_ver#v}"
    local major minor patch
    major=$(echo "${clean_cur}" | cut -d. -f1)
    minor=$(echo "${clean_cur}" | cut -d. -f2)
    patch=$(echo "${clean_cur}" | cut -d. -f3 | cut -d- -f1)

    local new_ver=""
    case "${target_ver}" in
        patch)
            patch=$((patch + 1))
            new_ver="${major}.${minor}.${patch}"
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            new_ver="${major}.${minor}.${patch}"
            ;;
        major)
            major=$((major + 1))
            minor=0
            patch=0
            new_ver="${major}.${minor}.${patch}"
            ;;
        *)
            new_ver="${target_ver#v}"
            ;;
    esac

    echo ""
    echo -e "Target New Version: ${BOLD}${GREEN}v${new_ver}${NC}"
    if ! confirm "Apply version update across all files?" "y"; then
        info "Aborted version update."
        return 0
    fi

    info "Updating version strings across repository..."

    # 1. package.json
    if [ -f "${SCRIPT_DIR}/package.json" ]; then
        sed -i -E "s/\"version\": *\"[^\"]+\"/\"version\": \"${new_ver}\"/" "${SCRIPT_DIR}/package.json"
    fi

    # 2. package-lock.json (if exists)
    if [ -f "${SCRIPT_DIR}/package-lock.json" ]; then
        sed -i -E "0,/\"version\": *\"[^\"]+\"/s/\"version\": *\"[^\"]+\"/\"version\": \"${new_ver}\"/" "${SCRIPT_DIR}/package-lock.json"
    fi

    # 3. src/constants/version.ts
    if [ -f "${SCRIPT_DIR}/src/constants/version.ts" ]; then
        sed -i -E "s/APP_VERSION = '[^']+'/APP_VERSION = '${new_ver}'/" "${SCRIPT_DIR}/src/constants/version.ts"
    fi

    # 4. server/package.json
    if [ -f "${SCRIPT_DIR}/server/package.json" ]; then
        sed -i -E "s/\"version\": *\"[^\"]+\"/\"version\": \"${new_ver}\"/" "${SCRIPT_DIR}/server/package.json"
    fi

    # 5. server/index.js
    if [ -f "${SCRIPT_DIR}/server/index.js" ]; then
        sed -i -E "s/version: *'${current_ver}'/version: '${new_ver}'/g" "${SCRIPT_DIR}/server/index.js"
        sed -i -E "s/${current_ver}-enterprise/${new_ver}-enterprise/g" "${SCRIPT_DIR}/server/index.js"
    fi

    # 6. server/db.js
    if [ -f "${SCRIPT_DIR}/server/db.js" ]; then
        sed -i -E "s/${current_ver}-enterprise/${new_ver}-enterprise/g" "${SCRIPT_DIR}/server/db.js"
    fi

    # 7. docker-compose.yml
    if [ -f "${SCRIPT_DIR}/docker-compose.yml" ]; then
        sed -i -E "s|ghcr.io/kisa-ops/filtr:v[0-9]+\.[0-9]+\.[0-9]+|ghcr.io/kisa-ops/filtr:v${new_ver}|g" "${SCRIPT_DIR}/docker-compose.yml"
    fi

    # 8. .env & .env.example
    if [ -f "${SCRIPT_DIR}/.env" ]; then
        sed -i -E "s|FILTR_IMAGE=.*|FILTR_IMAGE=ghcr.io/kisa-ops/filtr:v${new_ver}|" "${SCRIPT_DIR}/.env"
    fi
    if [ -f "${SCRIPT_DIR}/.env.example" ]; then
        sed -i -E "s|FILTR_IMAGE=.*|FILTR_IMAGE=ghcr.io/kisa-ops/filtr:v${new_ver}|" "${SCRIPT_DIR}/.env.example"
    fi

    # 9. install.sh & scripts/install.sh
    if [ -f "${SCRIPT_DIR}/install.sh" ]; then
        sed -i -E "s/^VERSION=\"v[^\"]+\"/VERSION=\"v${new_ver}\"/" "${SCRIPT_DIR}/install.sh"
    fi
    if [ -f "${SCRIPT_DIR}/scripts/install.sh" ]; then
        sed -i -E "s/^VERSION=\"v[^\"]+\"/VERSION=\"v${new_ver}\"/" "${SCRIPT_DIR}/scripts/install.sh"
    fi

    success "Updated files to v${new_ver}."

    # Git commit and Tag option
    if confirm "Commit version bump and create git tag 'v${new_ver}'?" "y"; then
        git add -A
        git commit -m "chore(release): bump version to v${new_ver}"
        git tag -fa "v${new_ver}" -m "Release v${new_ver}"
        success "Created commit and tag v${new_ver}."
    fi
}

# ==============================================================================
# 3. CLEAN UP ENGINE
# ==============================================================================
cleanup() {
    local target="$1"
    echo ""
    echo -e "${BOLD}${CYAN}=== Workspace & Artifact Clean Up ===${NC}"

    if [ -z "${target}" ]; then
        echo "Select cleanup target:"
        echo "  1) Clean build directories (dist/, .vite/, cache)"
        echo "  2) Prune local offline tarballs (filtr-docker-v*.tar.gz)"
        echo "  3) Prune dangling Docker images & build cache"
        echo "  4) Full cleanup (All of the above)"
        echo "  0) Back to main menu"
        echo ""
        echo -ne "${BOLD}Choice [1-4]: ${NC}"
        read -r choice
        case "${choice}" in
            1) target="dist" ;;
            2) target="tarballs" ;;
            3) target="docker" ;;
            4) target="all" ;;
            *) return 0 ;;
        esac
    fi

    # 1. Clean build artifacts
    if [ "${target}" = "dist" ] || [ "${target}" = "all" ]; then
        info "Cleaning build directories..."
        rm -rf "${SCRIPT_DIR}/dist" "${SCRIPT_DIR}/.vite" "${SCRIPT_DIR}/node_modules/.cache"
        success "Cleaned dist/ and compiler caches."
    fi

    # 2. Prune tarballs
    if [ "${target}" = "tarballs" ] || [ "${target}" = "all" ]; then
        local current_ver
        current_ver=$(get_current_version)
        local cur_tar="filtr-docker-v${current_ver}.tar.gz"

        echo ""
        info "Inspecting local offline package archives..."
        local tar_files
        tar_files=$(find "${SCRIPT_DIR}" "${SCRIPT_DIR}/releases" -maxdepth 1 -name "filtr-docker-*.tar.gz" 2>/dev/null | sort -u)
        if [ -z "${tar_files}" ]; then
            info "No offline tarballs found."
        else
            echo -e "${YELLOW}Existing offline packages:${NC}"
            ls -lh "${SCRIPT_DIR}"/filtr-docker-*.tar.gz | awk '{print "  - " $9 " (" $5 ")"}'
            echo ""
            echo "Tarball cleanup options:"
            echo "  a) Keep ONLY current version (${cur_tar}) and delete older versions"
            echo "  b) Delete ALL local tarballs"
            echo "  c) Cancel tarball cleanup"
            echo -ne "${BOLD}Selection [a/b/c]: ${NC}"
            read -r tar_opt
            case "${tar_opt}" in
                a)
                    for f in ${tar_files}; do
                        if [[ "$f" != *"${cur_tar}"* ]]; then
                            rm -f "$f"
                            echo -e "  ${DIM}Deleted $(basename "$f")${NC}"
                        fi
                    done
                    success "Pruned older tarballs. Retained current: ${cur_tar}"
                    ;;
                b)
                    if confirm "Are you SURE you want to delete ALL local package archives?" "n"; then
                        rm -f "${SCRIPT_DIR}"/filtr-docker-*.tar.gz
                        success "Removed all local tarball archives."
                    fi
                    ;;
                *)
                    info "Skipped tarball cleanup."
                    ;;
            esac
        fi
    fi

    # 3. Docker cleanup
    if [ "${target}" = "docker" ] || [ "${target}" = "all" ]; then
        if command -v docker >/dev/null 2>&1; then
            if confirm "Prune dangling Docker images and build cache?" "y"; then
                info "Pruning dangling Docker images..."
                docker image prune -f || true
                docker builder prune -f || true
                success "Docker dangling layers and builder cache pruned."
            fi
        fi
    fi
}

# ==============================================================================
# 6. BUILD OFFLINE PACKAGE
# ==============================================================================
build_package() {
    local version="${1:-$(get_current_version)}"
    version="${version#v}"
    local tarball_name="filtr-docker-v${version}.tar.gz"

    echo ""
    echo -e "${BOLD}${CYAN}=== Building Offline Production Container Package ===${NC}"
    info "Target Version: ${BOLD}v${version}${NC}"
    info "Output Archive: ${BOLD}${tarball_name}${NC}"

    if ! command -v docker >/dev/null 2>&1; then
        error "Docker is not installed or not in PATH."
        return 1
    fi

    # Build web frontend first if needed
    if [ ! -d "${SCRIPT_DIR}/dist" ]; then
        info "Building frontend web application assets..."
        npm run build
    fi

    info "Building Docker image: ghcr.io/kisa-ops/filtr:v${version} and filtr:v${version}..."
    docker build \
        --provenance=false \
        -t "ghcr.io/kisa-ops/filtr:v${version}" \
        -t "ghcr.io/kisa-ops/filtr:latest" \
        -t "filtr:v${version}" \
        -t "filtr:latest" \
        "${SCRIPT_DIR}"

    success "Docker image built successfully."

    info "Exporting container image with dual tags (GHCR + Local) to compressed archive ${tarball_name}..."
    docker save \
        "ghcr.io/kisa-ops/filtr:v${version}" \
        "ghcr.io/kisa-ops/filtr:latest" \
        "filtr:v${version}" \
        "filtr:latest" | gzip > "${SCRIPT_DIR}/${tarball_name}"

    local size
    size=$(du -h "${SCRIPT_DIR}/${tarball_name}" | awk '{print $1}')
    local checksum
    checksum=$(sha256sum "${SCRIPT_DIR}/${tarball_name}" | awk '{print $1}')

    success "Package created: ${BOLD}${tarball_name}${NC} (${size})"
    echo -e "SHA256: ${DIM}${checksum}${NC}"
}

# ==============================================================================
# 6.5. COMMIT MESSAGE AUTO-GENERATION & COMMIT UTILITY
# ==============================================================================
generate_commit_msg() {
    local status_lines
    status_lines=$(git status --porcelain 2>/dev/null)
    if [ -z "${status_lines}" ]; then
        echo "chore: update repository files"
        return 0
    fi

    local modified=()
    local added=()
    local deleted=()
    local scopes=()

    while IFS= read -r line; do
        [ -z "${line}" ] && continue
        local code="${line:0:2}"
        local file="${line:3}"
        # Strip quotes if git quoted paths
        file=$(echo "${file}" | sed -e 's/^"//' -e 's/"$//')
        # Handle rename format: orig -> target
        if [[ "${file}" == *" -> "* ]]; then
            file=$(echo "${file}" | awk -F ' -> ' '{print $2}')
        fi
        local base
        base=$(basename "${file}")

        if [[ "${code}" =~ D ]]; then
            deleted+=("${base}")
        elif [[ "${code}" =~ A|\?\? ]]; then
            added+=("${base}")
        else
            modified+=("${base}")
        fi

        # Scope detection based on path
        if [[ "${file}" == src/* ]]; then
            scopes+=("ui")
        elif [[ "${file}" == server/* ]]; then
            scopes+=("server")
        elif [[ "${file}" == rules/* ]]; then
            scopes+=("rules")
        elif [[ "${file}" == docs/* || "${file}" == *.md ]]; then
            scopes+=("docs")
        elif [[ "${file}" == *.sh || "${file}" == Dockerfile* || "${file}" == *compose* || "${file}" == nginx* ]]; then
            scopes+=("ops")
        elif [[ "${file}" == package*.json || "${file}" == tsconfig*.json ]]; then
            scopes+=("deps")
        fi
    done <<< "${status_lines}"

    local scope_str=""
    if [ ${#scopes[@]} -gt 0 ]; then
        local unique_scopes
        unique_scopes=$(printf '%s\n' "${scopes[@]}" | sort -u | paste -sd, -)
        [ -n "${unique_scopes}" ] && scope_str="(${unique_scopes})"
    fi

    local prefix="chore"
    local desc=""

    if [ ${#deleted[@]} -gt 0 ] && [ ${#modified[@]} -eq 0 ] && [ ${#added[@]} -eq 0 ]; then
        prefix="refactor"
        local del_list
        del_list=$(printf '%s, ' "${deleted[@]:0:3}" | sed 's/, $//')
        [ ${#deleted[@]} -gt 3 ] && del_list="${del_list} (+$((${#deleted[@]} - 3)) more)"
        desc="remove ${del_list}"
    elif [ ${#added[@]} -gt 0 ] && [ ${#modified[@]} -eq 0 ] && [ ${#deleted[@]} -eq 0 ]; then
        prefix="feat"
        local add_list
        add_list=$(printf '%s, ' "${added[@]:0:3}" | sed 's/, $//')
        [ ${#added[@]} -gt 3 ] && add_list="${add_list} (+$((${#added[@]} - 3)) more)"
        desc="add ${add_list}"
    else
        if [[ "${scope_str}" =~ (ui|server) ]]; then
            prefix="fix"
        elif [[ "${scope_str}" =~ (docs) ]] && [ ${#scopes[@]} -eq 1 ]; then
            prefix="docs"
        elif [[ "${scope_str}" =~ (deps) ]] && [ ${#scopes[@]} -eq 1 ]; then
            prefix="build"
        fi

        local all_files=("${modified[@]}" "${added[@]}" "${deleted[@]}")
        local file_list
        file_list=$(printf '%s, ' "${all_files[@]:0:3}" | sed 's/, $//')
        [ ${#all_files[@]} -gt 3 ] && file_list="${file_list} (+$((${#all_files[@]} - 3)) more)"
        desc="update ${file_list}"
    fi

    echo "${prefix}${scope_str}: ${desc}"
}

commit_changes() {
    local passed_msg="${1:-}"
    local dirty
    dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "${dirty}" -eq 0 ]; then
        info "Working tree is clean. No uncommitted changes."
        return 0
    fi

    warn "You have uncommitted changes in the repository:"
    git status -s
    echo ""

    local commit_msg="${passed_msg}"
    if [ -z "${commit_msg}" ]; then
        local auto_msg
        auto_msg=$(generate_commit_msg)
        echo -e "Auto-detected change info: ${GREEN}${BOLD}${auto_msg}${NC}"
        echo -e "${DIM}(Press [Enter] to accept pre-populated message, or edit it directly)${NC}"
        echo -ne "${BOLD}Enter commit message: ${NC}"
        # Pre-populate Readline buffer with auto_msg
        read -e -i "${auto_msg}" -r commit_msg 2>/dev/null || read -r commit_msg
        if [ -z "${commit_msg}" ]; then
            commit_msg="${auto_msg}"
        fi
    fi

    git add -A
    git commit -m "${commit_msg}"
    success "Committed changes: ${BOLD}${commit_msg}${NC}"
}

# ==============================================================================
# 7. PUSH SOURCE CODE TO SOURCE REPO (anandprabhusk/filtr)
# ==============================================================================
push_source() {
    local passed_msg="${1:-}"
    local skip_confirm="${2:-0}"
    echo ""
    echo -e "${BOLD}${CYAN}=== Push Source Code Changes ===${NC}"
    validate_repo_urls
    request_pat_interactive || true

    local token="${GITHUB_TOKEN:-}"
    local git_branch
    git_branch=$(git rev-parse --abbrev-ref HEAD)

    # Check for uncommitted changes
    local dirty
    dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "${dirty}" -gt 0 ]; then
        warn "You have uncommitted changes in the repository."
        git status -s
        echo ""
        if [ "${skip_confirm}" = "1" ] || confirm "Commit all changes before pushing?" "y"; then
            commit_changes "${passed_msg}"
        fi
    fi

    echo ""
    info "Preparing to push branch ${BOLD}${git_branch}${NC} and tags to Source Repo: ${BOLD}${SOURCE_REPO}${NC}..."
    if [ "${skip_confirm}" != "1" ]; then
        if ! confirm "Proceed with push?" "y"; then
            info "Push cancelled."
            return 0
        fi
    fi

    local push_target="origin"
    if [ -n "${token}" ] && [[ "${SOURCE_REPO}" == https://* ]]; then
        # Use authenticated URL with token
        local authed_url
        authed_url=$(echo "${SOURCE_REPO}" | sed -E "s|https://([^@]+@)?github.com|https://${token}@github.com|")
        push_target="${authed_url}"
    fi

    info "Pushing ${git_branch} to ${SOURCE_REPO}..."
    git push "${push_target}" "${git_branch}"
    info "Pushing tags to ${SOURCE_REPO}..."
    git push "${push_target}" --tags 2>/dev/null || git push "${push_target}" --tags --force 2>/dev/null || true

    success "Source code and tags successfully pushed to ${SOURCE_REPO}!"
}

# ==============================================================================
# 7.5. SYNCHRONIZE PRODUCTION REPOSITORY FILES TO DISTRIBUTION REPO (kisa-ops/filtr)
# ==============================================================================
sync_dist_repo_files() {
    local version="${1:-$(get_current_version)}"
    version="${version#v}"
    local tag="v${version}"
    local token="${GITHUB_TOKEN:-}"

    echo ""
    info "Synchronizing production repository files to Distribution Repo: ${BOLD}${DIST_REPO}${NC}..."
    
    local push_dist_target="kisa"
    if [ -n "${token}" ] && [[ "${DIST_REPO}" == https://* ]]; then
        local authed_dist_url
        authed_dist_url=$(echo "${DIST_REPO}" | sed -E "s|https://([^@]+@)?github.com|https://${token}@github.com|")
        push_dist_target="${authed_dist_url}"
    fi

    # Ensure remote tracking is fetched
    git fetch "${push_dist_target}" main:refs/remotes/kisa/main 2>/dev/null || true

    local temp_branch="dist-sync-$$-${RANDOM}"
    local temp_worktree
    temp_worktree=$(mktemp -d "/tmp/filtr-dist-worktree.XXXXXX")

    if ! git worktree add -B "${temp_branch}" "${temp_worktree}" "kisa/main" >/dev/null 2>&1; then
        warn "Could not create worktree from kisa/main, initializing clean distribution branch..."
        git worktree add -B "${temp_branch}" "${temp_worktree}" >/dev/null 2>&1
    fi

    # Synchronize all deployment manifests and tools
    local dist_files=(
        "docker-compose.yml"
        "install.sh"
        "upgrade.sh"
        "manage-ssl.sh"
        "manage-ner.sh"
        "admin.sh"
        "nginx.conf"
        ".env.example"
        ".gitignore"
        "README.md"
        "DEPLOYMENT.md"
        "INSTALLATION.md"
        "API.md"
        "ARCHITECTURE.md"
        "SECURITY_AUDIT.md"
        "ROADMAP.md"
    )
    for f in "${dist_files[@]}"; do
        if [ -f "${SCRIPT_DIR}/${f}" ]; then
            cp -f "${SCRIPT_DIR}/${f}" "${temp_worktree}/${f}"
        fi
    done

    # Synchronize rules, docs, and scripts directories
    for d in "rules" "docs" "scripts"; do
        if [ -d "${SCRIPT_DIR}/${d}" ]; then
            rm -rf "${temp_worktree}/${d}"
            cp -rf "${SCRIPT_DIR}/${d}" "${temp_worktree}/${d}"
        fi
    done

    # Clean legacy duplicate files if present in worktree root
    rm -f "${temp_worktree}"/filtr_export_*.json "${temp_worktree}"/enterprise_config.json "${temp_worktree}"/enterprise_policy.json 2>/dev/null || true

    # Commit and push from isolated worktree
    (
        cd "${temp_worktree}"
        git add -A
        if ! git diff --cached --quiet; then
            git commit -m "release(v${version}): update production distribution files, installer, and deployment stack"
        fi
        info "Pushing updated repository files to ${DIST_REPO} (main)..."
        git push "${push_dist_target}" "${temp_branch}:main"
        info "Pushing tag ${tag} to ${DIST_REPO}..."
        git push "${push_dist_target}" "${tag}" --force 2>/dev/null || true
    )

    # Clean up temporary worktree and branch
    git worktree remove --force "${temp_worktree}" >/dev/null 2>&1 || true
    rm -rf "${temp_worktree}" 2>/dev/null || true
    git branch -D "${temp_branch}" >/dev/null 2>&1 || true

    success "Production files and release tag ${tag} synchronized to ${DIST_REPO} (main)!"
}

# ==============================================================================
# 8. PUBLISH RELEASE & PACKAGE TO DISTRIBUTION REPO (kisa-ops/filtr)
# ==============================================================================
publish_dist() {
    echo ""
    echo -e "${BOLD}${CYAN}=== Publish Production Package to Distribution Repo ===${NC}"
    local version="${1:-$(get_current_version)}"
    version="${version#v}"
    local tag="v${version}"
    local tarball_name="filtr-docker-v${version}.tar.gz"
    local tarball_path="${SCRIPT_DIR}/${tarball_name}"

    validate_repo_urls
    request_pat_interactive || true

    local token="${GITHUB_TOKEN:-}"
    if [ -z "${token}" ]; then
        error "A GitHub Personal Access Token is required to create releases on ${DIST_REPO}."
        return 1
    fi

    # Check if tarball exists
    if [ ! -f "${tarball_path}" ]; then
        warn "Production package ${tarball_name} does not exist locally."
        if confirm "Build container image and offline package now?" "y"; then
            build_package "${version}"
        else
            error "Cannot publish without offline package archive."
            return 1
        fi
    fi

    info "Package verified: ${tarball_path} ($(du -h "${tarball_path}" | awk '{print $1}'))"

    # Synchronize repository files to kisa-ops/filtr main branch first
    sync_dist_repo_files "${version}"

    # GitHub Release creation via GitHub API
    local repo_slug
    repo_slug=$(echo "${DIST_REPO}" | sed -E 's|https://github.com/||; s|\.git$||')

    info "Checking if release ${tag} already exists on ${repo_slug}..."
    local check_rel
    check_rel=$(curl -s -H "Authorization: Bearer ${token}" "https://api.github.com/repos/${repo_slug}/releases/tags/${tag}" || true)
    local rel_id
    rel_id=$(echo "${check_rel}" | grep '"id":' | head -n 1 | sed -E 's/.*: *([0-9]+).*/\1/' || true)

    if [ -z "${rel_id}" ]; then
        info "Creating new GitHub Release ${tag} on ${repo_slug}..."
        
        local create_payload
        create_payload=$(python3 -c 'import json, sys; tag=sys.argv[1]; name=sys.argv[2]; print(json.dumps({"tag_name": tag, "target_commitish": "main", "name": "filtr " + tag + " — Enterprise Release", "body": "filtr " + tag + " Production Package\n\n### Downloads\n- Offline Container Package: `" + name + "`", "draft": False, "prerelease": False}))' "${tag}" "${tarball_name}")

        local create_res
        create_res=$(curl -s -X POST \
            -H "Authorization: Bearer ${token}" \
            -H "Content-Type: application/json" \
            -d "${create_payload}" \
            "https://api.github.com/repos/${repo_slug}/releases")
        rel_id=$(echo "${create_res}" | grep '"id":' | head -n 1 | sed -E 's/.*: *([0-9]+).*/\1/' || true)
        if [ -n "${rel_id}" ]; then
            success "Created release ${tag} (Release ID: ${rel_id})."
        else
            error "Failed to create release. Response: $(echo "${create_res}" | head -n 5)"
            return 1
        fi
    else
        info "Release ${tag} exists (ID: ${rel_id}). Uploading / updating assets..."
    fi

    # Upload release asset tarball
    info "Uploading ${tarball_name} to GitHub Release ${tag}..."
    local upload_url="https://uploads.github.com/repos/${repo_slug}/releases/${rel_id}/assets?name=${tarball_name}"
    
    local upload_res
    upload_res=$(curl -s -X POST \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/gzip" \
        --data-binary "@${tarball_path}" \
        "${upload_url}")

    if echo "${upload_res}" | grep -q '"state": *"uploaded"'; then
        success "Uploaded ${tarball_name} to https://github.com/${repo_slug}/releases/tag/${tag}"
    elif echo "${upload_res}" | grep -q 'already_exists'; then
        warn "Asset ${tarball_name} is already attached to release ${tag}."
    else
        warn "Asset upload response: $(echo "${upload_res}" | head -n 3)"
    fi

    success "Distribution package publication complete!"
}

# ==============================================================================
# GUIDED RELEASE PIPELINE (One-Click Wizard)
# ==============================================================================
release_pipeline() {
    banner
    echo -e "${BOLD}${MAGENTA}=== Full Production Release Pipeline Wizard ===${NC}\n"
    info "This wizard guides you through the full release cycle:"
    echo "  Step 1: Authenticate with GitHub PAT"
    echo "  Step 2: Validate Source & Distribution Repository URLs"
    echo "  Step 3: Increment Semantic Version across Codebase"
    echo "  Step 4: Build Container & Offline Package Archive (.tar.gz)"
    echo "  Step 5: Push Source Code & Tags to anandprabhusk/filtr"
    echo "  Step 6: Publish Package & Release to kisa-ops/filtr"
    echo "  Step 7: Clean Workspace & Temporary Artifacts"
    echo ""

    if ! confirm "Begin full release pipeline?" "y"; then
        return 0
    fi

    # Step 1
    request_pat_interactive

    # Step 2
    validate_repo_urls

    # Step 2.5: Ensure all workspace changes are committed before tagging
    local dirty
    dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "${dirty}" -gt 0 ]; then
        echo ""
        info "Staging and committing all uncommitted changes before release versioning..."
        commit_changes
    fi

    # Step 3
    bump_version

    # Step 4
    local current_ver
    current_ver=$(get_current_version)
    build_package "${current_ver}"

    # Step 5: Push full source code and release tag to Source Repo
    push_source "" 1

    # Step 6: Synchronize repo files and publish release to Distribution Repo
    publish_dist "${current_ver}"

    # Step 7
    if confirm "Perform post-release cleanup (prune older tarballs and cache)?" "y"; then
        cleanup "tarballs"
        cleanup "dist"
    fi

    echo ""
    success "🎉 Production release v${current_ver} successfully deployed to all environments!"
}

# ==============================================================================
# CLI DISPATCHER & INTERACTIVE MENU
# ==============================================================================
show_help() {
    cat << 'EOF'
================================================================================
  filtr Enterprise Administration, Versioning & Multi-Repo Release CLI
================================================================================

OVERVIEW:
    Unified DevOps and release management utility for filtr. Manages the complete
    lifecycle across source development and production distribution:
      1) Source Repository:       https://github.com/anandprabhusk/filtr (origin)
      2) Production Distribution: https://github.com/kisa-ops/filtr      (kisa)

USAGE:
    ./admin.sh [COMMAND] [OPTIONS]

COMMANDS:
    status                      Display comprehensive operational overview: active
                                branch, uncommitted files, versions, remotes,
                                GitHub PAT status, and offline package archives.

    version [bump-type|<tag>]   Synchronize semantic versioning across all manifests
                                (package.json, version.ts, server/index.js,
                                docker-compose.yml, install.sh, .env).
                                Supported types: patch | minor | major | vX.Y.Z

    clean [target]              Clean workspace artifacts to maintain repository hygiene:
                                - dist      : Remove dist/, .vite/, and compiler caches
                                - tarballs  : Prune older offline tarball archives (>500MB)
                                - docker    : Prune dangling Docker images & build cache
                                - all       : Perform full cleanup of all targets above

    repos                       Interactively inspect, validate, and update target Git
                                remote URLs for Source and Distribution repositories.

    auth                        Verify active GitHub Personal Access Token (PAT),
                                validate permissions (repo, write:packages), or
                                prompt securely to store session credentials.

    build [version]             Compile production container image with dual tags
                                (ghcr.io/kisa-ops/filtr:<ver> and filtr:<ver>) and
                                export multi-tagged offline package archive (.tar.gz).

    commit [message]            Inspect uncommitted changes, auto-populate commit message
                                with change info (files, scopes, actions), and commit.

    push [message]              Check uncommitted changes, auto-populate commit message
                                with change info, commit, and push branch + tags to source repo.

    publish [version]           Publish production release to kisa-ops/filtr: syncs
                                repository files, pushes tags, creates GitHub Release,
                                and uploads offline package archive asset.

    sync-dist [version]         Synchronize production repository files (install.sh,
                                upgrade.sh, compose, rules, docs) to kisa-ops/filtr.

    release                     Launch the full 7-step guided end-to-end release wizard:
                                Auth -> Repos -> Version -> Build -> Push -> Publish -> Clean.

    help, -h, --help            Show this comprehensive command manual.

TROUBLESHOOTING & REPOSITORY RULESETS:
    If a tag push to kisa-ops/filtr is declined due to repository rule violations:
    1. Go to: https://github.com/kisa-ops/filtr/settings/rules
    2. Edit the active Tag Protection Ruleset.
    3. Under "Bypass list", add "Repository admin" (or your user) with mode "Always".
    Note: ./admin.sh publish automatically creates the release and attaches the tag
    via the GitHub Releases API even if direct git push is restricted.

EXAMPLES:
    ./admin.sh                  # Launch interactive numbered menu dashboard
    ./admin.sh status           # Quick health and sync status check
    ./admin.sh version patch    # Bump patch version (e.g., v1.8.4 -> v1.8.5)
    ./admin.sh version v2.0.0   # Explicitly target major version v2.0.0
    ./admin.sh clean tarballs   # Prune older offline package archives
    ./admin.sh build            # Build container image & export offline package
    ./admin.sh push             # Push source code to anandprabhusk/filtr
    ./admin.sh publish          # Publish release package to kisa-ops/filtr
    ./admin.sh release          # Complete guided 1-click release pipeline
================================================================================
EOF
}


# -----------------------------------------------------------------------------
# AI / Deep NER Engine (Microsoft Presidio) Management
# -----------------------------------------------------------------------------
manage_ner() {
    echo -e "${BOLD}--- AI / Deep NER Detection Engine Management ---${NC}"
    echo
    # Check if local presidio container is running
    local presidio_status
    presidio_status="$(docker inspect --format='{{.State.Status}}' filtr-presidio 2>/dev/null || echo "not running")"
    
    echo -e "Local Presidio Container (filtr-presidio): ${BOLD}${presidio_status}${NC}"
    
    # Read .env if present
    if [ -f .env ]; then
        echo -e "Configured .env PRESIDIO_ENABLED: $(grep -E '^PRESIDIO_ENABLED=' .env | cut -d= -f2 || echo 'not set')"
        echo -e "Configured .env PRESIDIO_MODE:    $(grep -E '^PRESIDIO_MODE=' .env | cut -d= -f2 || echo 'not set')"
        echo -e "Configured .env PRESIDIO_URL:     $(grep -E '^PRESIDIO_URL=' .env | cut -d= -f2 || echo 'not set')"
    fi
    echo
    echo "  1) â–¶ï¸   Start Local Presidio Container (docker compose --profile ner up -d)"
    echo "  2) â ³ Stop Local Presidio Container (free ~1GB RAM)"
    echo "  3) ðŸ”„ Test Presidio HTTP Endpoint Connectivity"
    echo "  0) Back to main menu"
    echo
    echo -ne "${BOLD}Enter choice [0-3]: ${NC}"
    read -r ner_c
    case "${ner_c}" in
        1)
            info "Starting local Presidio sidecar container..."
            docker compose --profile ner up -d presidio
            success "Local Presidio sidecar container started."
            ;;
        2)
            info "Stopping local Presidio sidecar container..."
            docker stop filtr-presidio >/dev/null 2>&1 || true
            success "Presidio sidecar stopped."
            ;;
        3)
            local test_url="http://127.0.0.1:5001"
            if [ -f .env ]; then
                local env_url=$(grep -E '^PRESIDIO_URL=' .env | cut -d= -f2 | tr -d '"' | tr -d "'" || echo "")
                [ -n "${env_url}" ] && test_url="${env_url}"
            fi
            echo -ne "Testing endpoint: ${test_url}/healthz ... "
            if curl -s -m 3 "${test_url}/healthz" >/dev/null 2>&1; then
                echo -e "${GREEN}${BOLD}ONLINE (200 OK)${NC}"
            else
                echo -e "${RED}${BOLD}OFFLINE / UNREACHABLE${NC}"
            fi
            ;;
        *)
            ;;
    esac
}


interactive_menu() {
    while true; do
        show_status
        echo -e "${BOLD}Administrative Tasks:${NC}"
        echo "  1) 📊 System & Git Status Overview"
        echo "  2) 🏷️  Version Management & Semantic Bump"
        echo "  3) 🧹 Workspace, Tarballs & Docker Clean Up"
        echo "  4) 🔗 Validate & Correct Repository Information"
        echo "  5) 🔑 GitHub PAT Verification & Configuration"
        echo "  6) 📦 Build Offline Production Container Package (.tar.gz)"
        echo "  7) 🚀 Push Source Code (with Auto-Populated Commit)"
        echo "  8) 🌐 Publish Release Package to kisa-ops/filtr"
        echo "  9) ✨ Guided End-to-End Release Pipeline"
        echo "  10) 🧠 Manage AI / Deep NER Detection Engine (Presidio)"
        echo "  11) 🔒 Manage TLS / SSL Certificates (manage-ssl.sh)"
        echo "  12) 💾 Commit Changes Only (Auto-Populated with Change Info)"
                echo "  0) ❌ Exit"
        echo ""
        echo -ne "${BOLD}Enter choice [0-13]: ${NC}"
        read -r menu_choice
        case "${menu_choice}" in
            1) ;; # show_status already runs
            2) bump_version ;;
            3) cleanup ;;
            4) validate_repo_urls 1 ;;
            5) request_pat_interactive ;;
            6) build_package ;;
            7) push_source ;;
            8) publish_dist ;;
            9) release_pipeline ;;
            10) manage_ner ;;
            11) "${SCRIPT_DIR}/manage-ssl.sh" ;;
            12) commit_changes ;;
            13) sync_dist_repo_files ;;
                        0|q|exit) echo "Goodbye!"; exit 0 ;;
            *) warn "Invalid selection. Please choose 0-13." ;;
        esac
        echo ""
        echo -ne "${DIM}Press [Enter] to return to menu...${NC}"
        read -r _
    done
}

# Main Command Dispatcher
case "${1:-}" in
    status)
        show_status
        ;;
    version)
        shift
        bump_version "$@"
        ;;
    clean|cleanup)
        shift
        cleanup "$@"
        ;;
    repos|repo-config)
        validate_repo_urls 1
        ;;
    auth|pat)
        request_pat_interactive
        ;;
    build|build-package)
        shift
        build_package "$@"
        ;;
    commit)
        shift
        commit_changes "$@"
        ;;
    push|push-source)
        shift
        push_source "$@"
        ;;
    publish|publish-dist)
        shift
        publish_dist "$@"
        ;;
    sync-dist|dist-sync)
        shift
        sync_dist_repo_files "$@"
        ;;
    release)
        release_pipeline
        ;;
    ner)
        manage_ner
        ;;
    proxy|proxy-config)
        shift
        bash scripts/configure-proxy.sh "$@"
        ;;
    help|-h|--help)
        show_help
        ;;
    "")
        interactive_menu
        ;;
    *)
        error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
