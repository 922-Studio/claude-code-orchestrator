#!/usr/bin/env bash
# provision.sh — semver-versioned, forward-only reconciler that ADOPTS
# orchestrator setup changes after a pull. Mirrors the ecosystem's version.txt
# model, driven by the COMMITTED root version.txt (CI-bumped, see
# .github/workflows/version-bump.yml).
#
#   version.txt (repo root, committed)          ← released version, X.Y.Z (CI patch-bumps)
#   setup/provision/migrations/X.Y.Z-slug/apply.sh   ← runs when version.txt reaches X.Y.Z
#   setup/provision/migrations/X.Y.Z-slug/prompt.md  ← optional Claude-side step
#   setup/local/.provisioned-version (gitignored)    ← version this machine last provisioned to
#
# On each run: target = root version.txt; before = machine marker (0.0.0 if fresh).
# Every migration with  before < X.Y.Z <= target  runs, in semver order, stopping
# at the first failure (marker only advances past successes). So you can merge a
# migration early and it stays dormant until version.txt catches up to its version.
#
# It also (re)installs the triggers/plumbing it owns: .git/hooks/post-merge +
# post-rewrite (merge/rebase pulls) and the announce-pending SessionStart hook.
#
# CONTRACT: every migration apply.sh MUST be idempotent (safe under --force).
#
# Usage:
#   provision.sh                 run migrations in (marker, version.txt], advance marker
#   provision.sh --force         re-run ALL migrations up to version.txt (marker treated as 0.0.0)
#   provision.sh --list          show target/marker + each migration's status
#   provision.sh --from-git-hook internal marker used by the installed git hooks
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1
LOCAL="$ROOT/setup/local"
MIGRATIONS="$ROOT/setup/provision/migrations"
VERSION_FILE="$ROOT/version.txt"
MARKER="$LOCAL/.provisioned-version"
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

# ── semver helpers (sort -V based) ────────────────────────────────────────────
ver_ok() { printf '%s' "$1" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; }
ver_lt() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]; }   # $1 <  $2
ver_le() { [ "$1" = "$2" ] || ver_lt "$1" "$2"; }                                                     # $1 <= $2
mig_ver() { printf '%s' "$1" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/'; }                          # 1.2.0-foo -> 1.2.0

read_target() { local v=""; [ -f "$VERSION_FILE" ] && v="$(tr -d '[:space:]' < "$VERSION_FILE")"; ver_ok "$v" && echo "$v" || echo 0.0.0; }
read_marker() { local v=""; [ -f "$MARKER" ] && v="$(tr -d '[:space:]' < "$MARKER")"; ver_ok "$v" && echo "$v" || echo 0.0.0; }
set_marker()  { printf '%s\n' "$1" > "$MARKER"; }

# migrations as "version<TAB>dir", ascending by version
list_migrations() {
  local d v
  for d in "$MIGRATIONS"/*/; do
    [ -f "$d/apply.sh" ] || continue
    v="$(mig_ver "$(basename "$d")")"
    ver_ok "$v" || continue
    printf '%s\t%s\n' "$v" "${d%/}"
  done | sort -V
}

enqueue_prompt() {   # ver, dir
  local ver="$1" dir="$2" rel tmp; rel="${dir#"$ROOT"/}"; tmp="$(mktemp)"
  [ -f "$PENDING" ] && grep -vF "[v$ver]" "$PENDING" > "$tmp" 2>/dev/null
  printf -- '- [ ] run %s/prompt.md — [v%s] queued %s\n' "$rel" "$ver" "$(date +%F)" >> "$tmp"
  mv "$tmp" "$PENDING"
}

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
  target="$(read_target)"; marker="$(read_marker)"
  echo "released version (version.txt): $target"
  echo "provisioned here (.provisioned-version): $marker"
  printf '%-10s %-9s %s\n' "VERSION" "STATUS" "MIGRATION"
  while IFS=$'\t' read -r v dir; do
    [ -n "$v" ] || continue
    if ver_le "$v" "$marker"; then st="applied"
    elif ver_le "$v" "$target"; then st="PENDING"
    else st="future"; fi
    [ -f "$dir/prompt.md" ] && st="$st+prompt"
    printf '%-10s %-9s %s\n' "$v" "$st" "$(basename "$dir")"
  done < <(list_migrations)
  exit 0
fi

# ── (re)install git hooks + announcer ─────────────────────────────────────────
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

# ── run forward migrations in (before, target] ────────────────────────────────
target="$(read_target)"; marker="$(read_marker)"
lo="$marker"; [ "$FORCE" -eq 1 ] && lo="0.0.0"
head="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
log "provision @ $head — released $target, provisioned $marker (force=$FORCE)"
ran=0
while IFS=$'\t' read -r v dir; do
  [ -n "$v" ] || continue
  ver_lt "$lo" "$v" || continue          # skip already-applied (<= marker)
  ver_le "$v" "$target" || continue      # skip future (> version.txt) — gated
  name="$(basename "$dir")"
  chmod +x "$dir/apply.sh" 2>/dev/null || true
  if out="$(bash "$dir/apply.sh" 2>&1)"; then
    ver_lt "$(read_marker)" "$v" && set_marker "$v"     # advance past this success
    ran=$((ran + 1))
    if [ -f "$dir/prompt.md" ]; then
      enqueue_prompt "$v" "$dir"; log "✓ v$v $name — queued prompt.md for Claude"
    else
      log "✓ v$v $name${out:+ — $out}"
    fi
  else
    log "✗ v$v $name FAILED — $out"
    log "STOP: not advancing past a failed migration (provisioned stays $(read_marker))"
    exit 1
  fi
done < <(list_migrations)

# advance the marker up to the released version (records "caught up", even with no migrations)
ver_lt "$(read_marker)" "$target" && set_marker "$target"
log "done @ $head — provisioned $(read_marker) (released $target), applied $ran this run"
exit 0
