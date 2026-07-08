#!/usr/bin/env bash
# =============================================================================
# deliver-env.sh — copy a local env file onto antares (no server-side edits)
#
# Usage: deliver-env.sh [--dry-run] [--force] <Service> [prod|dev]
#
# The operator's local untracked files are the source of truth:
#   <repo>/.env.prod  ->  /home/lab/<svc>/.env        (prod, default)
#   <repo>/.env.dev   ->  /home/lab/dev/<svc>/.env    (dev)
#
# All work is done locally; this step only SWAPS the file on the server. It
# never edits the server copy in place. Delivery is atomic (scp to a temp file
# in the destination directory, chmod 600, then mv onto the target).
#
# validate-env.sh runs first; delivery aborts on NO-GO unless --force.
# Only key NAMES are printed (the added/removed diff) — never values.
#
# Prerequisites: ssh antares reachable (Tailscale on).
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

parse_dry_run "$@"
FORCE=false
SERVICE=""
TARGET="prod"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) ;;
        --force)   FORCE=true ;;
        prod|dev)  TARGET="$1" ;;
        *)         [[ -z "$SERVICE" ]] && SERVICE="$1" ;;
    esac
    shift
done
[[ -z "$SERVICE" ]] && { echo "Usage: $0 [--dry-run] [--force] <Service> [prod|dev]"; exit 1; }

REPO_DIR="$(service_repo_dir "$SERVICE")"
if [[ "$TARGET" == "prod" ]]; then
    SRC="${REPO_DIR}/.env.prod"
    DEST="$(service_env_file "$SERVICE")"
else
    SRC="${REPO_DIR}/.env.dev"
    DEST="$(service_env_file_dev "$SERVICE")"
fi
DEST_DIR="$(dirname "$DEST")"
TMP="${DEST_DIR}/.env.prodpush.tmp.$$"

log_section "Deliver env: ${SERVICE} (${TARGET}) — ${SRC} -> antares:${DEST}"

[[ -f "$SRC" ]] || { log_error "Source file not found: ${SRC}"; exit 1; }

# ─── Validate first (unless --force) ──────────────────────────────────────────
if [[ "$FORCE" != "true" ]]; then
    log_info "Validating ${SERVICE} env before delivery..."
    if [[ "$DRY_RUN" == "true" ]]; then
        bash "${SCRIPT_DIR}/validate-env.sh" --dry-run "$SERVICE" || true
    elif ! bash "${SCRIPT_DIR}/validate-env.sh" "$SERVICE"; then
        log_error "validate-env NO-GO — aborting delivery. Fix .env.${TARGET} or pass --force."
        exit 1
    fi
else
    log_warn "--force: skipping validation"
fi

# ─── Show key-name diff (names only, never values) ────────────────────────────
log_check "Key diff vs current server file (names only)..."
SRC_KEYS=$(grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' "$SRC" 2>/dev/null | sed 's/=$//' | sort)
SRV_KEYS=$(ssh_antares_read "grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' ${DEST} 2>/dev/null | sed 's/=\$//' | sort" 2>/dev/null || echo "")
ADDED=$(comm -23 <(echo "$SRC_KEYS") <(echo "$SRV_KEYS") | tr '\n' ' ')
REMOVED=$(comm -13 <(echo "$SRC_KEYS") <(echo "$SRV_KEYS") | tr '\n' ' ')
[[ -n "$ADDED"   ]] && log_info "  keys ADDED by this delivery:   ${ADDED}"   || log_info "  no keys added"
[[ -n "$REMOVED" ]] && log_warn "  keys REMOVED by this delivery: ${REMOVED}" || log_info "  no keys removed"

# ─── Deliver atomically ───────────────────────────────────────────────────────
if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY-RUN] Would scp ${SRC} -> ${ANTARES_HOST}:${TMP}, chmod 600, mv -> ${DEST}"
    log_ok "deliver-env dry-run complete."
    exit 0
fi

log_info "Copying to ${ANTARES_HOST}:${TMP} ..."
scp -q "$SRC" "${ANTARES_HOST}:${TMP}"
ssh_antares "chmod 600 ${TMP} && mv ${TMP} ${DEST}"
log_ok "Delivered ${SRC} -> ${DEST} (atomic mv, perms 600)"

log_info "Note: a running container picks up the new env only on (re)create. In the"
log_info "push flow this happens at the promote step; otherwise recreate the container."

log_section "Deliver env Complete: ${SERVICE} (${TARGET})"
