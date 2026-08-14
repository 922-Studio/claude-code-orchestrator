#!/usr/bin/env bash
# (Re)build the local documentation index from libraries.tsv.
# Usage: index-libraries.sh [library ...]     (no args = every library in the file)
#
# Why this stops the server: indexing runs through the `scrape` CLI, not the MCP `scrape_docs` tool,
# because exclude/include patterns are CLI-only — the MCP tool silently drops them, which produces a
# populated-but-wrong index. The CLI needs exclusive access to the SQLite store, so the server is
# stopped for the duration and restarted afterwards (including on failure, via the EXIT trap).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TSV="${HERE}/libraries.tsv"
PORT="${DOCS_MCP_PORT:-6280}"
IMAGE="ghcr.io/arabold/docs-mcp-server:latest"
NAME="docs-mcp"

command -v docker >/dev/null || { echo "✖ docker not found" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "✖ docker daemon not running" >&2; exit 1; }
docker inspect "$NAME" >/dev/null 2>&1 || {
  echo "✖ container '${NAME}' does not exist — run install.sh first" >&2; exit 1; }

server_was_running=no
docker ps --format '{{.Names}}' | grep -qx "$NAME" && server_was_running=yes

restore_server() {
  if [ "$server_was_running" = yes ]; then
    echo "▸ restarting the server"
    docker start "$NAME" >/dev/null 2>&1
    for _ in $(seq 1 30); do
      curl -s --max-time 3 -o /dev/null "http://localhost:${PORT}/" && break
      sleep 2
    done
  fi
}
trap restore_server EXIT

if [ "$server_was_running" = yes ]; then
  echo "▸ stopping the server for exclusive store access"
  docker stop "$NAME" >/dev/null
fi

want=("$@")
selected() {
  [ ${#want[@]} -eq 0 ] && return 0
  local n; for n in ${want[@]+"${want[@]}"}; do [ "$n" = "$1" ] && return 0; done; return 1
}

failed=()
indexed=()
suspect=()

while IFS=$'\t' read -r lib url flags; do
  case "${lib:-}" in ''|\#*) continue ;; esac
  selected "$lib" || continue

  echo "▸ ${lib} — ${url}"
  # `eval` so the quoted glob patterns in the TSV reach the CLI as individual arguments.
  # shellcheck disable=SC2086
  if out=$(eval docker run --rm \
        -v docs-mcp-data:/data -v docs-mcp-config:/config \
        "$IMAGE" scrape "$lib" "$url" --logo=false ${flags:-} 2>&1 \
        | grep -viE 'cpuid_info|cpuinfo_vendor'); then
    pages=$(printf '%s\n' "$out" | grep -oE 'scraped [0-9]+ pages' | grep -oE '[0-9]+' | tail -1)
    # A successful exit with a handful of pages is the silent failure mode of this crawler:
    # a cross-host redirect puts everything outside the scope boundary, or a client-rendered
    # site yields no links in `fetch` mode. Both report success. Flag it instead of hiding it.
    if [ -n "${pages:-}" ] && [ "$pages" -lt "${MIN_PAGES:-5}" ]; then
      echo "  ⚠ only ${pages} page(s) — almost certainly wrong. Check for a cross-host redirect"
      echo "    (then --scope hostname + --include-pattern) or a client-rendered site"
      echo "    (then --scrape-mode playwright). See libraries.tsv header."
      suspect+=("${lib}:${pages}")
    else
      echo "  ✓ ${pages:-?} pages"
    fi
    indexed+=("${lib}:${pages:-?}")
  else
    echo "  ✖ failed:"; printf '%s\n' "$out" | tail -5 | sed 's/^/    /'
    failed+=("$lib")
  fi
done < "$TSV"

echo
echo "indexed: ${indexed[*]:-none}"
if [ ${#suspect[@]} -gt 0 ]; then
  echo "⚠ suspiciously small: ${suspect[*]} — these scraped without error but are almost certainly incomplete" >&2
fi
if [ ${#failed[@]} -gt 0 ]; then
  echo "⚠ failed: ${failed[*]}" >&2
  exit 1
fi
[ ${#suspect[@]} -gt 0 ] && exit 1

echo "✅ done. Verify with a real question, not a status check:"
echo "   ${HERE}/mcpcall.sh search_docs '{\"library\":\"fastapi\",\"query\":\"dependency overrides in tests\",\"limit\":2}'"
