#!/usr/bin/env bash
# SessionStart hook — once per session (throttled), PULL every clean repo in
# registry.md to its current branch so code investigation starts on fresh code.
# Delegates to repo-sync.sh, which runs `git pull` (not just fetch). Safe mode:
# dirty repos are skipped, never reset.
#
# Output goes to stderr (transcript/debug), NOT stdout — SessionStart stdout is
# injected into the model's context, and a multi-repo pull log would bloat it.
#
# Non-blocking: always exits 0.
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF_DIR/../.." && pwd)"
CONFIG="$ROOT/setup/local/git-freshness.config.json"
STAMP="${TMPDIR:-/tmp}/orchestrator-session-fetch.stamp"

enabled=true
throttle=30
if [ -f "$CONFIG" ]; then
  enabled="$(python3 -c 'import json,sys;print(str(json.load(open(sys.argv[1])).get("session_fetch",{}).get("enabled",True)).lower())' "$CONFIG" 2>/dev/null || echo true)"
  throttle="$(python3 -c 'import json,sys;print(int(json.load(open(sys.argv[1])).get("session_fetch",{}).get("throttle_minutes",30)))' "$CONFIG" 2>/dev/null || echo 30)"
fi
[ "$enabled" = "false" ] && exit 0

# throttle: skip if we already synced within <throttle> minutes
if [ -f "$STAMP" ]; then
  last="$(cat "$STAMP" 2>/dev/null || echo 0)"
  now="$(date +%s)"
  [ $(( (now - last) / 60 )) -lt "$throttle" ] && exit 0
fi
date +%s > "$STAMP" 2>/dev/null || true

bash "$ROOT/setup/repo-sync/repo-sync.sh" >&2 2>&1 || true
exit 0
