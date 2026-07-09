#!/usr/bin/env bash
# provision.sh — idempotent reconciler that ADOPTS orchestrator setup changes.
#
# It (a) runs every setup/<id>/apply.sh (auto-apply-all), and (b) (re)installs
# git hooks so that every future `git pull` re-runs this automatically. New
# features shipped in the orchestrator are adopted on the next pull with no
# manual step — as long as they carry an idempotent apply.sh.
#
# Triggers:
#   - .git/hooks/post-merge   → fires after a merge-style `git pull`
#   - .git/hooks/post-rewrite → fires after a rebase-style `git pull` (pull.rebase)
#     (both are installed/refreshed by this script; the repo's .git/hooks are not
#      version-controlled, so provisioning owns them)
#   - install.sh              → bootstraps this on a fresh clone
#   - manual                  → bash setup/provision/provision.sh
#
# CONTRACT: every apply.sh MUST be idempotent — this runs them on every pull.
#
# Usage:
#   provision.sh                  apply everything + refresh the git hooks
#   provision.sh --list           print the apply.sh scripts it would run, exit
#   provision.sh --from-git-hook  internal marker used by the installed hooks
#
# Opt-out: list setup ids (one per line) in setup/local/provision.skip.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1
LOCAL="$ROOT/setup/local"
SKIP_FILE="$LOCAL/provision.skip"
STATE="$LOCAL/.provision-state"
LOG="$LOCAL/provision.log"
mkdir -p "$LOCAL"

MODE="run"
[ "${1:-}" = "--list" ] && MODE="list"

log() {
  [ "$MODE" = "list" ] && return 0
  printf '  %s\n' "$*"
  printf '[%s] %s\n' "$(date +%FT%T)" "$*" >> "$LOG" 2>/dev/null || true
}

skip_id() { [ -f "$SKIP_FILE" ] && grep -qxF "$1" "$SKIP_FILE" 2>/dev/null; }

# discover apply.sh scripts: committed setups + local setups
mapfile -t applies < <(ls -1 "$ROOT"/setup/*/apply.sh "$LOCAL"/*/apply.sh 2>/dev/null | sort -u)

if [ "$MODE" = "list" ]; then
  for a in "${applies[@]}"; do
    id="$(basename "$(dirname "$a")")"
    if skip_id "$id"; then echo "skip   $id"; else echo "apply  $id  ($a)"; fi
  done
  exit 0
fi

# 1) (re)install the git hooks (self-heal their content on every run)
HOOKS="$(git -C "$ROOT" rev-parse --git-path hooks 2>/dev/null || true)"
if [ -n "$HOOKS" ]; then
  case "$HOOKS" in /*) : ;; *) HOOKS="$ROOT/$HOOKS" ;; esac   # may be repo-relative
  mkdir -p "$HOOKS"
  for hook in post-merge post-rewrite; do
    cat > "$HOOKS/$hook" <<EOF
#!/usr/bin/env bash
# Auto-installed by setup/provision/provision.sh — adopts orchestrator setup
# changes after a pull. Regenerated on every provision run; edit provision.sh,
# not this file.
exec bash "$ROOT/setup/provision/provision.sh" --from-git-hook
EOF
    chmod +x "$HOOKS/$hook"
  done
  log "git hooks refreshed (post-merge, post-rewrite) in $HOOKS"
fi

# 2) run every apply.sh idempotently
head="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
log "provision @ $head — ${#applies[@]} apply script(s)"
fails=0
for a in "${applies[@]}"; do
  id="$(basename "$(dirname "$a")")"
  if skip_id "$id"; then log "– skip $id (provision.skip)"; continue; fi
  chmod +x "$a" 2>/dev/null || true
  if out="$(bash "$a" 2>&1)"; then
    log "✓ $id${out:+ — $out}"
  else
    log "✗ $id FAILED — $out"; fails=$((fails + 1))
  fi
done

# 3) stamp state (gitignored; informational)
{ echo "commit=$head"; echo "at=$(date +%FT%T)"; echo "failures=$fails"; } > "$STATE" 2>/dev/null || true
log "done @ $head (failures: $fails)"
exit 0
