#!/usr/bin/env bash
# Migration — adopt the local docs MCP server (setup/docs-mcp).
# Starts the container and registers the 'docs' MCP server with Claude Code.
# Deliberately does NOT index: scraping libraries.tsv is a 15–30 min network job and
# must not run inside a git-pull hook. The indexed content is machine-local by design
# (Docker volumes), never committed — only the config that reproduces it lives in the repo.
# Idempotent; skips cleanly when Docker is unavailable.
set -u
ORCH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "⏭  docs-mcp: Docker not available — skipped."
  echo "   Once Docker runs: bash $ORCH/setup/docs-mcp/install.sh --index"
  exit 0
fi

bash "$ORCH/setup/docs-mcp/install.sh" || {
  echo "⚠  docs-mcp: install failed — see $ORCH/setup/docs-mcp/SETUP.md (Fix table)" >&2
  exit 0   # never break a pull over an optional setup
}

# The index itself is per-machine and not shipped; tell the operator how to build it.
if ! bash "$ORCH/setup/docs-mcp/mcpcall.sh" list_libraries '{}' 2>/dev/null | grep -q '^- '; then
  echo "ℹ  docs-mcp: index is empty — build it with:"
  echo "   bash $ORCH/setup/docs-mcp/index-libraries.sh"
fi
