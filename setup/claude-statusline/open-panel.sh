#!/usr/bin/env bash
# Open the statusline control panel in the browser, scoped to a directory.
#
#   open-panel.sh [dir]
#
# Starts server.js detached if it isn't already listening, then opens the panel
# pre-filled with `dir` (defaults to the current working directory). Idempotent:
# re-running just reopens the tab, it won't spawn a second server.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${STATUSLINE_PANEL_PORT:-4790}"
DIR="${1:-$PWD}"
URL="http://127.0.0.1:${PORT}/?dir=$(printf %s "$DIR" | sed 's/ /%20/g')"

# Already listening? (curl the state endpoint; -s -o /dev/null, short timeout)
if ! curl -s -o /dev/null --max-time 1 "http://127.0.0.1:${PORT}/api/state"; then
  # Not up — launch detached, fully backgrounded, surviving this shell.
  nohup node "$HERE/server.js" >"${TMPDIR:-/tmp}/statusline-panel.log" 2>&1 &
  disown 2>/dev/null || true
  # Wait (up to ~3s) for it to accept connections.
  for _ in $(seq 1 30); do
    curl -s -o /dev/null --max-time 1 "http://127.0.0.1:${PORT}/api/state" && break
    sleep 0.1
  done
fi

# Open in the default browser (macOS `open`; Linux `xdg-open`).
if command -v open >/dev/null 2>&1; then open "$URL"
elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$URL"
else echo "Open manually: $URL"; fi

echo "Statusline panel: $URL"
