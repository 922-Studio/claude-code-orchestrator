#!/usr/bin/env bash
# =============================================================================
# validate-env.sh — environment-variable validation for the prod push
#
# Usage: validate-env.sh [--dry-run] <Service>
#
# Runs LOCALLY against the operator's untracked env files for a service:
#   <repo>/.env.dev   (dev values)
#   <repo>/.env.prod  (prod values)
#   <repo>/.env.example  (committed contract — which keys must exist)
#
# It NEVER prints values — only key names + verdicts — so it is safe to run in
# logs/CI. Checks:
#   1. Completeness  — every contract key (.env.example) is present and non-empty
#      in .env.prod. Missing/empty -> NO-GO. (Catches "new key added on dev,
#      never set on prod".)
#   2. Divergence    — keys that look environment-specific (domains, hosts, URLs,
#      sheet IDs, DB, CORS, channels...) must DIFFER between .env.dev and
#      .env.prod. Identical -> NO-GO for hard patterns, WARN for secret-ish ones.
#      (Catches "spreadsheet/domain not adapted for prod".)
#   3. Prod markers  — prod values containing dev markers (localhost, dev_, .dev)
#      -> WARN.
#
# Per-service exceptions live in env-rules/<Service> (optional):
#   allow_same:  KEY1 KEY2     # legitimately identical in dev and prod
#   must_differ: KEY3 KEY4     # env-specific but off-pattern; force NO-GO if same
#   allow_empty: KEY5 KEY6     # legitimately empty in .env.prod (skip completeness NO-GO)
# Multiple lines of the same directive accumulate.
#
# Exit 0 = GO, 1 = NO-GO. READ-ONLY.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

parse_dry_run "$@"
SERVICE=""
while [[ $# -gt 0 ]]; do
    [[ "$1" == "--dry-run" ]] && { shift; continue; }
    [[ -z "$SERVICE" ]] && SERVICE="$1"
    shift
done
[[ -z "$SERVICE" ]] && { echo "Usage: $0 [--dry-run] <Service>"; exit 1; }

REPO_DIR="$(service_repo_dir "$SERVICE")"
DEV_FILE="${REPO_DIR}/.env.dev"
PROD_FILE="${REPO_DIR}/.env.prod"
EXAMPLE_FILE="${REPO_DIR}/.env.example"
RULES_FILE="${SCRIPT_DIR}/env-rules/${SERVICE}"

# Hard env-specific name patterns (must differ dev vs prod) -> NO-GO if identical.
# Note: bare DB is intentionally excluded (DB_USER/DB_NAME are often shared);
# DB_HOST is still caught by HOST and DATABASE_URL by DATABASE.
HARD_PATTERN='(^|_)(URL|URLS|HOST|HOSTS|DOMAIN|SHEET|DATABASE|CORS|ORIGIN|ORIGINS|BASE|WEBHOOK|CHANNEL|REDIRECT|CALLBACK|COOKIE)($|_)'
# Secret-ish patterns (should differ, but reuse is sometimes intentional) -> WARN
SOFT_PATTERN='(^|_)(SECRET|PASSWORD|PASSWD|TOKEN|KEY|APIKEY|API_KEY)($|_)'

log_section "Validate env: ${SERVICE}"

if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY-RUN] Would compare ${DEV_FILE} vs ${PROD_FILE} against ${EXAMPLE_FILE}."
    log_ok "validate-env dry-run complete (no files read)."
    exit 0
fi

# ─── File presence ────────────────────────────────────────────────────────────
MISSING_FILES=0
for f in "$PROD_FILE" "$EXAMPLE_FILE"; do
    [[ -f "$f" ]] || { log_nogo "Missing required file: ${f}"; MISSING_FILES=1; }
done
[[ -f "$DEV_FILE" ]] || log_warn "No ${DEV_FILE} — divergence checks (dev vs prod) will be skipped."
[[ "$MISSING_FILES" -eq 1 ]] && { log_error "Cannot validate ${SERVICE} — required local env files missing."; exit 1; }

# ─── Helpers (value extraction stays local; only key names are ever logged) ───
# Print the raw value for KEY from FILE (first match). Empty if absent.
env_val() { grep -E "^$2=" "$1" 2>/dev/null | head -1 | cut -d= -f2- ; }
# Print all defined (uncommented, non-empty-name) keys in FILE.
env_keys() { grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' "$1" 2>/dev/null | sed 's/=$//' ; }
# Print contract keys (uncommented) from .env.example.
contract_keys() { env_keys "$1" ; }

in_list() { local n="$1"; shift; local x; for x in "$@"; do [[ "$x" == "$n" ]] && return 0; done; return 1; }

# ─── Load exceptions ──────────────────────────────────────────────────────────
ALLOW_SAME=(); MUST_DIFFER=(); ALLOW_EMPTY=()
if [[ -f "$RULES_FILE" ]]; then
    while IFS= read -r line; do
        case "$line" in
            allow_same:*)  read -r -a _rule  <<< "${line#allow_same:}";  ALLOW_SAME+=("${_rule[@]}") ;;
            must_differ:*) read -r -a _rule <<< "${line#must_differ:}"; MUST_DIFFER+=("${_rule[@]}") ;;
            allow_empty:*) read -r -a _rule <<< "${line#allow_empty:}"; ALLOW_EMPTY+=("${_rule[@]}") ;;
        esac
    done < "$RULES_FILE"
    log_info "Loaded exceptions from env-rules/${SERVICE} (allow_same: ${#ALLOW_SAME[@]}, must_differ: ${#MUST_DIFFER[@]}, allow_empty: ${#ALLOW_EMPTY[@]})"
fi

NOGO=0

# ─── 1. Completeness: contract keys present + non-empty in .env.prod ──────────
log_check "Completeness — every .env.example key present & non-empty in .env.prod..."
MISSING_KEYS=(); EMPTY_KEYS=()
while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    if ! grep -qE "^${key}=" "$PROD_FILE"; then
        MISSING_KEYS+=("$key")
    elif [[ -z "$(env_val "$PROD_FILE" "$key")" ]] && ! in_list "$key" "${ALLOW_EMPTY[@]:-}"; then
        EMPTY_KEYS+=("$key")
    fi
done < <(contract_keys "$EXAMPLE_FILE")
if [[ ${#MISSING_KEYS[@]} -gt 0 ]]; then log_nogo "Missing in .env.prod: ${MISSING_KEYS[*]}"; NOGO=1; fi
if [[ ${#EMPTY_KEYS[@]} -gt 0 ]];   then log_nogo "Empty in .env.prod: ${EMPTY_KEYS[*]}";   NOGO=1; fi
[[ ${#MISSING_KEYS[@]} -eq 0 && ${#EMPTY_KEYS[@]} -eq 0 ]] && log_go "All contract keys present & non-empty"

# ─── 2. Divergence: env-specific keys must differ between dev and prod ────────
if [[ -f "$DEV_FILE" ]]; then
    log_check "Divergence — env-specific keys must differ between .env.dev and .env.prod..."
    SAME_HARD=(); SAME_SOFT=()
    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        # only keys present in BOTH files
        grep -qE "^${key}=" "$DEV_FILE" || continue
        in_list "$key" "${ALLOW_SAME[@]:-}" && continue
        # compare values locally (never logged)
        if [[ "$(env_val "$DEV_FILE" "$key")" == "$(env_val "$PROD_FILE" "$key")" ]]; then
            if in_list "$key" "${MUST_DIFFER[@]:-}"; then
                SAME_HARD+=("$key")
            elif echo "$key" | grep -qiE "$HARD_PATTERN"; then
                SAME_HARD+=("$key")
            elif echo "$key" | grep -qiE "$SOFT_PATTERN"; then
                SAME_SOFT+=("$key")
            fi
        fi
    done < <(env_keys "$PROD_FILE")
    if [[ ${#SAME_HARD[@]} -gt 0 ]]; then
        log_nogo "Identical in dev & prod but look env-specific (must differ): ${SAME_HARD[*]}"
        NOGO=1
    fi
    if [[ ${#SAME_SOFT[@]} -gt 0 ]]; then
        log_warn "Identical in dev & prod (secret-ish — confirm intentional, else add to env-rules allow_same): ${SAME_SOFT[*]}"
    fi
    [[ ${#SAME_HARD[@]} -eq 0 && ${#SAME_SOFT[@]} -eq 0 ]] && log_go "Env-specific keys differ between dev and prod"
fi

# ─── 3. Prod-marker heuristic (WARN only) ─────────────────────────────────────
log_check "Prod-marker heuristic — prod values should not contain dev markers..."
DEV_MARKERS=();
while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    val="$(env_val "$PROD_FILE" "$key")"
    if echo "$val" | grep -qiE '(^|[^a-z])(localhost|dev_|-dev\b|\.dev\b|/dev/)'; then
        DEV_MARKERS+=("$key")
    fi
done < <(env_keys "$PROD_FILE")
if [[ ${#DEV_MARKERS[@]} -gt 0 ]]; then
    log_warn "prod values look dev-ish (contain localhost/dev_/.dev) — verify: ${DEV_MARKERS[*]}"
else
    log_go "No dev markers found in prod values"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
log_section "Validate env Summary: ${SERVICE}"
if [[ "$NOGO" -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}=== ${SERVICE} env: GO ===${NC}"; exit 0
else
    echo -e "${RED}${BOLD}=== ${SERVICE} env: NO-GO — fix .env.prod before delivering/promoting ===${NC}"; exit 1
fi
