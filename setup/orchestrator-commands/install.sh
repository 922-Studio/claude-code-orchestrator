#!/usr/bin/env bash
# Install the orchestrator's slash-commands into ~/.claude/commands/.
#
# Claude Code discovers slash-commands from ~/.claude/commands/ (outside this repo).
# The canonical entry points live in skills/<skill>/commands/*.md and reference the
# orchestrator by absolute path. This script copies them into place AND rewrites that
# absolute path to wherever THIS repo actually lives — so the commands are portable
# across machines / clone locations without hand-editing.
#
# Usage:  bash setup/orchestrator-commands/install.sh          (run from repo root)
#         ORCH_ROOT=/path/to/orchestrator bash .../install.sh  (explicit root)
set -euo pipefail

ORCH_ROOT="${ORCH_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
DEST="$HOME/.claude/commands"
# The path baked into the committed entry-point files (rewritten to ORCH_ROOT on install):
BAKED="/Users/gregor/dev/922/orchestrator"

mkdir -p "$DEST"
echo "orchestrator root : $ORCH_ROOT"
echo "commands dir      : $DEST"
echo

installed=0
while IFS= read -r -d '' src; do
  base="$(basename "$src")"
  [ "$base" = "README.md" ] && continue
  sed "s|$BAKED|$ORCH_ROOT|g" "$src" > "$DEST/$base"
  echo "  installed /$base -> $DEST/$base"
  installed=$((installed + 1))
done < <(find "$ORCH_ROOT/skills" -type f -path '*/commands/*.md' -print0)

echo
echo "done — $installed command(s) installed. Restart Claude Code to pick them up."
