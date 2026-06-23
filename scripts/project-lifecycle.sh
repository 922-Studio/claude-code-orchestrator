#!/usr/bin/env bash
# project-lifecycle.sh
# Read-only state gatherer for the project add/remove skills.
# It NEVER mutates anything — the skill reasons and acts; this just surfaces facts.
#
# Usage:
#   project-lifecycle.sh preflight <name>   # collisions, free ports, free redis db, domain
#   project-lifecycle.sh audit <name>       # every reference to <name> across the ecosystem

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ECO_DIR="$(cd "$REPO_DIR/.." && pwd)"   # /Users/gregor/dev/922
GUIDE="$REPO_DIR/guides/new-service-setup.md"
SERVER_MD="$REPO_DIR/server.md"
REGISTRY="$REPO_DIR/registry.md"

die() { echo "ERROR: $*" >&2; exit 1; }

MODE="${1:-}"
NAME="${2:-}"
[[ -n "$MODE" ]] || die "missing mode (preflight|audit)"
[[ -n "$NAME" ]] || die "missing <name>"

# kebab + lower for matching
SLUG="$(printf '%s' "$NAME" | tr '[:upper:] ' '[:lower:]-')"

hr() { printf '%s\n' "------------------------------------------------------------------------"; }

preflight() {
  echo "=== PREFLIGHT: $NAME ($SLUG) ==="
  echo "Eco root: $ECO_DIR"
  echo ""

  echo "=== NAME / PATH COLLISIONS ==="
  if [[ -e "$ECO_DIR/$NAME" ]]; then echo "  ✗ path exists: $ECO_DIR/$NAME"; else echo "  ✓ path free: $ECO_DIR/$NAME"; fi
  if grep -qiE "\b$SLUG\b|/$NAME\b" "$REGISTRY" 2>/dev/null; then
    echo "  ✗ registry already references '$NAME' — review before reusing:"
    grep -niE "\b$SLUG\b|/$NAME\b" "$REGISTRY" | sed 's/^/      /'
  else
    echo "  ✓ no registry row for '$NAME'"
  fi
  if [[ -f "$REPO_DIR/projects/$SLUG.md" ]]; then echo "  ✗ mapping exists: projects/$SLUG.md"; else echo "  ✓ no mapping file projects/$SLUG.md"; fi
  echo ""

  echo "=== PORTS IN USE (from server.md + guide reference table) ==="
  # Grab 4-digit ports referenced in the docs, dedupe, sort.
  local used
  used=$(grep -hoE '\b(80|81|30|39|54)[0-9]{2}\b' "$SERVER_MD" "$GUIDE" 2>/dev/null | sort -un | tr '\n' ' ')
  echo "  used: ${used:-<none found>}"
  echo "  → suggested free app ports (80xx band):"
  for p in $(seq 8020 8099); do
    if ! grep -qE "\b$p\b" "$SERVER_MD" "$GUIDE" 2>/dev/null; then echo "      $p"; break; fi
  done
  echo ""

  echo "=== REDIS DB NUMBERS (from guide reference table) ==="
  grep -nE '^\| *[0-9]+ *\|' "$GUIDE" 2>/dev/null | sed 's/^/  /' || echo "  (table not found)"
  echo "  → next free: inspect the table above; 0=HomeAPI 1=HomeCollector 2=reserved, take next gap"
  echo ""

  echo "=== DOMAIN CHECK: $SLUG.922-studio.com ==="
  if grep -qiE "$SLUG\.922-studio\.com" "$SERVER_MD" 2>/dev/null; then
    echo "  ✗ domain already routed:"
    grep -niE "$SLUG\.922-studio\.com" "$SERVER_MD" | sed 's/^/      /'
  else
    echo "  ✓ domain $SLUG.922-studio.com not referenced in server.md"
  fi
  echo ""
  echo "Resolve every ✗ before bootstrapping."
}

audit() {
  echo "=== TEARDOWN AUDIT: $NAME ($SLUG) ==="
  echo "Eco root: $ECO_DIR"
  echo ""

  echo "=== ORCHESTRATOR REFERENCES ==="
  hr
  grep -rniE "\b$SLUG\b|/$NAME\b" \
    "$REGISTRY" "$SERVER_MD" "$REPO_DIR/showcase.md" \
    "$REPO_DIR/projects" "$REPO_DIR/plans" 2>/dev/null \
    | sed "s#$REPO_DIR/##" | sed 's/^/  /' || echo "  (none)"
  echo ""

  echo "=== MAPPING FILE ==="
  [[ -f "$REPO_DIR/projects/$SLUG.md" ]] && echo "  projects/$SLUG.md  → move to archive" || echo "  (no mapping file)"
  echo ""

  echo "=== PLANS MENTIONING IT ==="
  grep -rliE "\b$SLUG\b" "$REPO_DIR/plans" 2>/dev/null | sed "s#$REPO_DIR/##" | sed 's/^/  archive: /' || echo "  (none)"
  echo ""

  echo "=== CROSS-SERVICE CONFIG (best-effort) ==="
  for svc in HomeCollector HomeAPI HomeStructure; do
    if [[ -d "$ECO_DIR/$svc" ]]; then
      local hits
      hits=$(grep -rliE "\b$SLUG\b" "$ECO_DIR/$svc" --include='*.py' --include='*.yaml' --include='*.yml' 2>/dev/null | head -20 || true)
      if [[ -n "$hits" ]]; then
        echo "  $svc:"; printf '%s\n' "$hits" | sed "s#$ECO_DIR/##" | sed 's/^/    /'
      else
        echo "  $svc: (no hits)"
      fi
    fi
  done
  echo ""

  echo "=== LOCAL CHECKOUT ==="
  [[ -d "$ECO_DIR/$NAME" ]] && echo "  $ECO_DIR/$NAME (decision: keep/remove — manual)" || echo "  (no local checkout)"
  echo ""
  echo "Reminder: stop HomeCollector monitoring BEFORE containers; backup DB BEFORE drop;"
  echo "          never auto-delete the GitHub repo."
}

case "$MODE" in
  preflight) preflight ;;
  audit)     audit ;;
  *)         die "unknown mode '$MODE' (use preflight|audit)" ;;
esac
