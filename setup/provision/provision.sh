#!/usr/bin/env bash
# provision.sh — versioned, forward-only reconciler that ADOPTS orchestrator
# setup changes. Mirrors the ecosystem's migration model (like DB migrations):
# a machine-local version.txt records the highest version applied HERE; every
# migration numbered greater than it is run in order, then version.txt is bumped.
#
#   setup/provision/migrations/NNNN-slug/apply.sh   ← a versioned unit (idempotent)
#   setup/provision/migrations/NNNN-slug/prompt.md  ← optional Claude-side step
#   setup/local/version.txt                         ← per-machine: highest applied (0 = fresh)
#
# A migration whose folder has a prompt.md ALSO enqueues a pointer into
# setup/local/provision-pending.md; the announce-pending SessionStart hook
# surfaces that queue to Claude next session (git hooks can't run Claude).
#
# It also (re)installs the triggers/plumbing it owns:
#   .git/hooks/post-merge, .git/hooks/post-rewrite  → re-run after every pull
#   announce-pending SessionStart hook in ~/.claude/settings.json
#
# CONTRACT: every migration apply.sh MUST be idempotent (safe under --force / re-run).
# Migrations run in ascending order and STOP at the first failure (version.txt is
# only advanced past migrations that succeed) — so a broken migration can't be skipped.
#
# Usage:
#   provision.sh                 run migrations newer than version.txt, bump it
#   provision.sh --force         re-run ALL migrations regardless of version.txt
#   provision.sh --list          show installed version + each migration's status
#   provision.sh --from-git-hook internal marker used by the installed git hooks
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1
LOCAL="$ROOT/setup/local"
MIGRATIONS="$ROOT/setup/provision/migrations"
VERSION_FILE="$LOCAL/version.txt"
PENDING="$LOCAL/provision-pending.md"
LOG="$LOCAL/provision.log"
mkdir -p "$LOCAL"

MODE="run"; FORCE=0
for arg in "$@"; do
  case "$arg" in
    --list) MODE="list" ;;
    --force) FORCE=1 ;;
  esac
done

log() {
  [ "$MODE" = "list" ] && return 0
  printf '  %s\n' "$*"
  printf '[%s] %s\n' "$(date +%FT%T)" "$*" >> "$LOG" 2>/dev/null || true
}

installed_version() { local v; v="$(cat "$VERSION_FILE" 2>/dev/null)"; case "$v" in ''|*[!0-9]*) echo 0 ;; *) echo "$v" ;; esac; }
mig_num() { basename "$1" | sed -E 's/^0*([0-9]+).*/\1/'; }   # 0003-foo -> 3

# ordered list of migration dirs (that contain apply.sh)
list_migrations() {
  local d
  for d in "$MIGRATIONS"/*/; do
    [ -f "$d/apply.sh" ] || continue
    printf '%s\t%s\n' "$(mig_num "$d")" "${d%/}"
  done | sort -n
}

enqueue_prompt() {   # ver, dir — queue a prompt.md pointer (dedup by version tag)
  local ver="$1" dir="$2" rel tmp; rel="${dir#"$ROOT"/}"; tmp="$(mktemp)"
  [ -f "$PENDING" ] && grep -vF "[v$ver]" "$PENDING" > "$tmp" 2>/dev/null
  printf -- '- [ ] run %s/prompt.md — [v%s] queued %s\n' "$rel" "$ver" "$(date +%F)" >> "$tmp"
  mv "$tmp" "$PENDING"
}

# ── install the announce-pending SessionStart hook (idempotent) ───────────────
install_announcer() {
  command -v python3 >/dev/null 2>&1 || return 0
  mkdir -p "$HOME/.claude"
  python3 - "$HOME/.claude/settings.json" "$ROOT" <<'PY'
import json, os, sys
path, orch = sys.argv[1], sys.argv[2]
cmd = f'bash "{orch}/setup/provision/announce-pending.sh"'
try:
    with open(path) as f: s = json.load(f)
except FileNotFoundError: s = {}
except Exception: sys.exit(0)
before = json.dumps(s, sort_keys=True)
groups = s.setdefault("hooks", {}).setdefault("SessionStart", [])
for g in groups:
    for h in g.get("hooks", []):
        if "announce-pending.sh" in h.get("command", ""):
            h["command"], h["type"] = cmd, "command"; break
    else: continue
    break
else:
    groups.append({"hooks": [{"type": "command", "command": cmd}]})
if json.dumps(s, sort_keys=True) == before: sys.exit(0)
if os.path.exists(path):
    try:
        import shutil; shutil.copyfile(path, path + ".bak")
    except Exception: pass
with open(path, "w") as f: json.dump(s, f, indent=2); f.write("\n")
PY
}

# ── --list ────────────────────────────────────────────────────────────────────
if [ "$MODE" = "list" ]; then
  cur="$(installed_version)"
  echo "installed version: $cur   (setup/local/version.txt)"
  printf '%-6s %-9s %s\n' "VER" "STATUS" "MIGRATION"
  while IFS=$'\t' read -r num dir; do
    [ -n "$num" ] || continue
    if [ "$num" -le "$cur" ]; then st="applied"; else st="PENDING"; fi
    [ -f "$dir/prompt.md" ] && st="$st+prompt"
    printf '%-6s %-9s %s\n' "$num" "$st" "$(basename "$dir")"
  done < <(list_migrations)
  exit 0
fi

# ── (re)install the git hooks (self-heal their content each run) ──────────────
HOOKS="$(git -C "$ROOT" rev-parse --git-path hooks 2>/dev/null || true)"
if [ -n "$HOOKS" ]; then
  case "$HOOKS" in /*) : ;; *) HOOKS="$ROOT/$HOOKS" ;; esac
  mkdir -p "$HOOKS"
  for hook in post-merge post-rewrite; do
    cat > "$HOOKS/$hook" <<EOF
#!/usr/bin/env bash
# Auto-installed by setup/provision/provision.sh — adopts orchestrator setup
# changes after a pull. Regenerated on every provision run; edit provision.sh.
exec bash "$ROOT/setup/provision/provision.sh" --from-git-hook
EOF
    chmod +x "$HOOKS/$hook"
  done
  log "git hooks refreshed (post-merge, post-rewrite) in $HOOKS"
fi
install_announcer

# ── run forward migrations ────────────────────────────────────────────────────
cur="$(installed_version)"
head="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
log "provision @ $head — installed version $cur (force=$FORCE)"
ran=0
while IFS=$'\t' read -r num dir; do
  [ -n "$num" ] || continue
  if [ "$FORCE" -eq 0 ] && [ "$num" -le "$cur" ]; then continue; fi
  name="$(basename "$dir")"
  chmod +x "$dir/apply.sh" 2>/dev/null || true
  if out="$(bash "$dir/apply.sh" 2>&1)"; then
    [ "$num" -gt "$(installed_version)" ] && echo "$num" > "$VERSION_FILE"   # advance (forward-only)
    ran=$((ran + 1))
    if [ -f "$dir/prompt.md" ]; then
      enqueue_prompt "$num" "$dir"; log "✓ v$num $name — queued prompt.md for Claude"
    else
      log "✓ v$num $name${out:+ — $out}"
    fi
  else
    log "✗ v$num $name FAILED — $out"
    log "STOP: not advancing past a failed migration (version stays $(installed_version))"
    exit 1
  fi
done < <(list_migrations)

[ "$ran" -eq 0 ] && log "up to date at version $cur — nothing to apply (use --force to re-run)"
log "done @ $head — version $(installed_version), applied $ran this run"
exit 0
