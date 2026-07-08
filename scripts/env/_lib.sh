#!/usr/bin/env bash
# =============================================================================
# _lib.sh — shared helpers for prod-push scripts
# Source this file; do not execute directly.
# =============================================================================

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_section() { echo -e "\n${CYAN}${BOLD}=== $* ===${NC}"; }
log_check()   { echo -e "  ${CYAN}[CHECK]${NC} $*"; }
log_go()      { echo -e "  ${GREEN}[GO]${NC}    $*"; }
log_nogo()    { echo -e "  ${RED}[NO-GO]${NC} $*" >&2; }

# ─── Dry-run guard ───────────────────────────────────────────────────────────
DRY_RUN="${DRY_RUN:-false}"

run() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} $*"
    else
        "$@"
    fi
}

# ─── Service → host path mappings ────────────────────────────────────────────
# Prod env_file_source per service (must match deploy.yml)
service_env_file() {
    local svc="$1"
    case "$svc" in
        HomeAPI)       echo "/home/lab/HomeAPI/.env" ;;
        HomeUI)        echo "/home/lab/HomeUI/.env" ;;
        HomeAuth)      echo "/home/lab/HomeAuth/.env" ;;
        HomeCollector) echo "/home/lab/HomeCollector/.env" ;;
        *)             echo "/home/lab/${svc}/.env" ;;
    esac
}

# Dev env_file_source on antares (deploy.yml uses /home/lab/dev/<svc>/.env for dev)
service_env_file_dev() {
    echo "/home/lab/dev/$1/.env"
}

# Local working-copy repo dir for a service (where .env.dev/.env.prod live).
# Override with REPO_BASE for non-standard checkouts.
REPO_BASE="${REPO_BASE:-/Users/gregor/dev/922}"
service_repo_dir() {
    echo "${REPO_BASE}/$1"
}

# Host app dir per service (where docker-compose.deploy.yaml lives)
service_app_dir() {
    local svc="$1"
    case "$svc" in
        HomeAPI)       echo "/home/lab/HomeAPI" ;;
        HomeUI)        echo "/home/lab/HomeUI" ;;
        HomeAuth)      echo "/home/lab/HomeAuth" ;;
        HomeCollector) echo "/home/lab/HomeCollector" ;;
        *)             echo "/home/lab/${svc}" ;;
    esac
}

# Services with Alembic migrations
has_alembic() {
    local svc="$1"
    case "$svc" in HomeAPI|HomeAuth|HomeCollector) return 0 ;; *) return 1 ;; esac
}

# Services with creds bind-mounts (google.json check applies)
has_creds_mount() {
    local svc="$1"
    case "$svc" in HomeAPI) return 0 ;; *) return 1 ;; esac
}

# Container name for a service's main API container
service_container() {
    local svc="$1"
    case "$svc" in
        HomeAPI)       echo "home_api_api" ;;
        HomeUI)        echo "homeui" ;;
        HomeAuth)      echo "homeauth" ;;
        HomeCollector) echo "home_collector_api" ;;
        Drafter)       echo "drafter" ;;
        *)             echo "$(echo "$svc" | tr '[:upper:]' '[:lower:]')_api" ;;
    esac
}

# True if the service ships a deployable container on antares.
# workflows (CI library) and HomeStructure (docs/monitoring config) do not.
service_has_container() {
    local svc="$1"
    case "$svc" in workflows|HomeStructure) return 1 ;; *) return 0 ;; esac
}

# Health endpoint per service (informational; the actual health gate uses the
# container's docker healthcheck status — runtime-agnostic, see wait_healthy).
service_health_url() {
    local svc="$1"
    case "$svc" in
        HomeAPI)       echo "http://localhost:8080/health" ;;
        HomeUI)        echo "http://localhost:8000" ;;
        HomeAuth)      echo "http://localhost:8100/auth/health" ;;
        HomeCollector) echo "http://localhost:8010/health" ;;
        Drafter)       echo "http://localhost:3000/api/health" ;;
        *)             echo "" ;;
    esac
}

# Version endpoint per service (for post-deploy code change verification)
service_version_url() {
    local svc="$1"
    case "$svc" in
        HomeAPI)       echo "http://localhost:8080/version" ;;
        HomeAuth)      echo "http://localhost:8100/version" ;;
        HomeCollector) echo "http://localhost:8010/version" ;;
        *)             echo "" ;;
    esac
}

# GitHub repo name per service
service_github_repo() {
    local svc="$1"
    echo "922-Studio/${svc}"
}

# Production target branch per service.
# Most services deploy from `prod`. Two exceptions:
#   - HomeStructure has no `prod` branch — docs/monitoring deploy from `main`.
#   - workflows is consumed by every service via `@main` refs (see any
#     service deploy.yml `uses: 922-Studio/workflows/...@main`), so `main` —
#     not `prod` — is what actually reaches consumers.
service_prod_branch() {
    local svc="$1"
    case "$svc" in
        HomeStructure|workflows) echo "main" ;;
        *)                       echo "prod" ;;
    esac
}

# CI deploy workflow to monitor after a promote push. Empty string => no
# deploy run to watch (workflows is a consumed library; HomeStructure runs
# its own docs/monitoring workflows verified in hooks/HomeStructure.sh).
service_deploy_workflow() {
    local svc="$1"
    case "$svc" in
        workflows|HomeStructure) echo "" ;;
        *)                       echo "deploy.yml" ;;
    esac
}

# ─── SSH helpers (all deploy ops run on astro-antares via DOCKER_HOST) ───────
ANTARES_HOST="${ANTARES_HOST:-antares}"

ssh_antares() {
    # Run a command on antares; respects DRY_RUN for mutating ops
    ssh "$ANTARES_HOST" "$@"
}

ssh_antares_read() {
    # Always runs (read-only); never suppressed by DRY_RUN
    ssh "$ANTARES_HOST" "$@"
}

docker_antares() {
    # docker commands via DOCKER_HOST ssh bridge (same as CI)
    DOCKER_HOST="ssh://lab@astro-antares" docker "$@"
}

# ─── Python-based HTTP check (no curl in app containers) ─────────────────────
# Usage: container_http_check <container> <url> [timeout_sec]
container_http_check() {
    local container="$1" url="$2" timeout="${3:-5}"
    ssh_antares_read docker exec "$container" python -c \
        "import urllib.request, sys; urllib.request.urlopen('${url}', timeout=${timeout}); sys.exit(0)" \
        2>/dev/null
}

# ─── Wait for health ─────────────────────────────────────────────────────────
# Returns 0 when the container is healthy. For containers WITHOUT a docker
# healthcheck, "running" is accepted (we can't wait for a status that never
# exists) — otherwise this would always time out for e.g. a plain nginx image.
wait_healthy() {
    local container="$1" attempts="${2:-12}" delay="${3:-5}"
    local i=0 state
    while (( i < attempts )); do
        # Emits "healthy"/"starting"/"unhealthy" if a healthcheck exists,
        # else "running"/"exited"/... from .State.Status.
        state=$(ssh_antares_read docker inspect \
            --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
            "$container" 2>/dev/null || echo "")
        case "$state" in
            healthy)  return 0 ;;
            running)  return 0 ;;   # no healthcheck defined; running is best signal
        esac
        (( i++ ))
        sleep "$delay"
    done
    return 1
}

# ─── Parse --dry-run from argv ───────────────────────────────────────────────
parse_dry_run() {
    for arg in "$@"; do
        if [[ "$arg" == "--dry-run" ]]; then
            DRY_RUN=true
            log_warn "DRY-RUN mode: no mutations will be executed"
            return
        fi
    done
}

# Remove --dry-run from positional args; caller can use "$@" for service list
strip_dry_run() {
    local -a out=()
    for arg in "$@"; do
        [[ "$arg" != "--dry-run" ]] && out+=("$arg")
    done
    echo "${out[@]}"
}
