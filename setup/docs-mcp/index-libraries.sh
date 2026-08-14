#!/usr/bin/env bash
# Enqueue scrape jobs for every entry in libraries.tsv, then wait for the queue to drain.
# Idempotent: scrape_docs defaults to --clean, so re-running replaces each library's index.
# Usage: index-libraries.sh [library ...]     (no args = all)
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCPCALL="${HERE}/mcpcall.sh"
TSV="${HERE}/libraries.tsv"
PORT="${DOCS_MCP_PORT:-6280}"

curl -s --max-time 5 -o /dev/null "http://localhost:${PORT}/" || {
  echo "✖ docs MCP server not reachable on :${PORT} — run install.sh first" >&2; exit 1; }

want=("$@")
selected() {
  [ $# -eq 0 ] && return 0
  [ ${#want[@]} -eq 0 ] && return 0
  local n; for n in ${want[@]+"${want[@]}"}; do [ "$n" = "$1" ] && return 0; done; return 1
}

while IFS=$'\t' read -r lib url extra; do
  case "${lib:-}" in ''|\#*) continue ;; esac
  selected "$lib" || continue
  extra="${extra:-{\}}"
  args=$(python3 -c '
import json, sys
lib, url, extra = sys.argv[1], sys.argv[2], sys.argv[3]
a = {"library": lib, "url": url, "waitForCompletion": False}
a.update(json.loads(extra))
print(json.dumps(a))
' "$lib" "$url" "$extra") || { echo "✖ ${lib}: bad extra-args JSON" >&2; continue; }
  printf '%-20s ' "$lib"
  "$MCPCALL" scrape_docs "$args" | tr -d '\n'; echo
done < "$TSV"

echo "⏳ waiting for the queue to drain…"
until [ "$("$MCPCALL" list_jobs '{}' 2>/dev/null | grep -c 'Status: \(queued\|running\)')" = "0" ]; do
  sleep 15
done

# Surface failures instead of reporting a silent success.
if "$MCPCALL" list_jobs '{}' 2>/dev/null | grep -q 'Status: failed'; then
  echo "⚠ some jobs failed:"
  "$MCPCALL" list_jobs '{}' | grep -B2 -A2 'Status: failed'
fi
echo "✅ done — indexed libraries:"
"$MCPCALL" list_libraries '{}'
