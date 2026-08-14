#!/usr/bin/env bash
# Install / reconcile the local docs MCP server (Grounded Docs, arabold/docs-mcp-server).
# Idempotent: safe to re-run. Does NOT re-index unless you pass --index.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${DOCS_MCP_PORT:-6280}"
IMAGE="ghcr.io/arabold/docs-mcp-server:latest"
NAME="docs-mcp"

command -v docker >/dev/null || { echo "✖ docker not found" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "✖ docker daemon not running — start Docker Desktop" >&2; exit 1; }

echo "▸ pulling ${IMAGE}"
docker pull -q "$IMAGE" >/dev/null

# `server --protocol auto` picks stdio when there is no TTY, reads EOF and exits 0 —
# which in a detached container looks like an instant crash-loop. Force http.
echo "▸ (re)starting container ${NAME} on :${PORT}"
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" --restart unless-stopped \
  -v docs-mcp-data:/data -v docs-mcp-config:/config \
  -p "${PORT}:${PORT}" "$IMAGE" \
  server --protocol http --host 0.0.0.0 --port "$PORT" --telemetry=false >/dev/null

echo -n "▸ waiting for the server to answer"
for _ in $(seq 1 30); do
  if curl -s --max-time 3 -o /dev/null "http://localhost:${PORT}/"; then echo " ✓"; break; fi
  echo -n "."; sleep 2
done

curl -s --max-time 5 -o /dev/null "http://localhost:${PORT}/" || {
  echo " ✖ not reachable — check: docker logs ${NAME}" >&2; exit 1; }

# Register with Claude Code (user scope) if absent.
if command -v claude >/dev/null; then
  if claude mcp list 2>/dev/null | grep -q '^docs\b'; then
    echo "▸ MCP server 'docs' already registered"
  else
    echo "▸ registering MCP server 'docs'"
    claude mcp add --scope user --transport http docs "http://localhost:${PORT}/mcp" >/dev/null
  fi
fi

if [ "${1:-}" = "--index" ]; then
  echo "▸ indexing libraries from libraries.tsv (this takes a while)"
  "${HERE}/index-libraries.sh"
else
  echo "▸ skipping indexing — run ./index-libraries.sh (or install.sh --index) to (re)build the index"
fi

echo "✅ docs MCP ready — dashboard: http://localhost:${PORT}"
