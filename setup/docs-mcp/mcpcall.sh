#!/usr/bin/env bash
# Call a tool on the local docs MCP server over streamable HTTP.
# Usage: mcpcall.sh <tool-name> <json-args>
#   mcpcall.sh list_libraries '{}'
#   mcpcall.sh search_docs '{"library":"fastapi","query":"background tasks","limit":3}'
set -uo pipefail

PORT="${DOCS_MCP_PORT:-6280}"
URL="http://localhost:${PORT}/mcp"
TOOL="${1:?usage: mcpcall.sh <tool-name> <json-args>}"
ARGS="${2:-{\}}"

hdrs=(-H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream')

# Open a session; the server may or may not hand back a session id.
sid=$(curl -s -D- --max-time 10 -X POST "$URL" "${hdrs[@]}" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"orchestrator-cli","version":"1"}}}' \
  -o /dev/null 2>/dev/null | tr -d '\r' | grep -i '^mcp-session-id:' | cut -d' ' -f2 || true)

# Empty arrays are "unbound" under `set -u` in bash 3.2 (macOS default), hence the ${x[@]+…} guard.
sh=()
[ -n "${sid:-}" ] && sh=(-H "mcp-session-id: ${sid}")

curl -s --max-time 10 -X POST "$URL" "${hdrs[@]}" ${sh[@]+"${sh[@]}"} \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' >/dev/null 2>&1 || true

curl -s --max-time 600 -X POST "$URL" "${hdrs[@]}" ${sh[@]+"${sh[@]}"} \
  -d "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"${TOOL}\",\"arguments\":${ARGS}}}" \
  | sed -n 's/^data: //p' \
  | python3 -c '
import json, sys
for line in sys.stdin:
    line = line.strip()
    if not line.startswith("{"):
        continue
    d = json.loads(line)
    if "error" in d:
        print("ERROR:", json.dumps(d["error"])); sys.exit(1)
    for c in d.get("result", {}).get("content", []):
        print(c.get("text", ""))
    break
'
