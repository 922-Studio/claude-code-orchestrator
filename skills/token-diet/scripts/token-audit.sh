#!/usr/bin/env bash
# token-audit.sh — fast, offline estimate of the FILE-BASED standing overhead that loads into
# every Claude session (CLAUDE.md chain, auto-memory index, installed slash-commands, settings).
#
# Uses a chars/4 heuristic — good enough to RANK sources and show before/after deltas. It is NOT a
# substitute for `/context`, which is ground truth for the live session (incl. MCP tool schemas,
# which this script cannot see). Run both; use this for the file sources, /context for the total.
#
# Usage:  bash skills/token-diet/scripts/token-audit.sh
set -euo pipefail

# Locate the orchestrator root (this script lives at <root>/skills/token-diet/scripts/).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WORKSPACE="$(cd "$ROOT/.." && pwd)"          # the 922 workspace root (parent of orchestrator)

# Auto-memory index path is derived from the orchestrator path (Claude Code's project-slug scheme).
SLUG="$(printf '%s' "$ROOT" | sed 's|/|-|g')"
MEM_INDEX="$HOME/.claude/projects/${SLUG}/memory/MEMORY.md"

est() { # est <file>  -> echoes approx tokens (chars/4), or 0 if missing
  local f="$1"
  [ -f "$f" ] || { echo 0; return; }
  local chars; chars=$(wc -c < "$f" | tr -d ' ')
  echo $(( chars / 4 ))
}

row() { printf '  %6s  %s\n' "$1" "$2"; }

total=0
add() { total=$(( total + $1 )); }

echo "=== Token Diet — file-based standing overhead (chars/4 estimate) ==="
echo "orchestrator root : $ROOT"
echo

echo "CLAUDE.md chain (loads every session in scope):"
for f in \
  "$WORKSPACE/CLAUDE.md" \
  "$ROOT/CLAUDE.md" \
  "$ROOT/CLAUDE.local.md" \
  "$HOME/.claude/CLAUDE.md"; do
  t=$(est "$f"); add "$t"; row "$t" "${f/#$HOME/~}"
done
echo

echo "Auto-memory index (loads every session):"
t=$(est "$MEM_INDEX"); add "$t"; row "$t" "${MEM_INDEX/#$HOME/~}"
echo

echo "Installed slash-commands (name+desc loads into the skills catalog):"
cmd_total=0
if [ -d "$HOME/.claude/commands" ]; then
  while IFS= read -r -d '' f; do
    t=$(est "$f"); cmd_total=$(( cmd_total + t )); row "$t" "${f/#$HOME/~}"
  done < <(find "$HOME/.claude/commands" -maxdepth 1 -name '*.md' -print0 2>/dev/null | sort -z)
fi
add "$cmd_total"
echo

echo "Settings:"
for f in "$HOME/.claude/settings.json" "$ROOT/.claude/settings.json"; do
  t=$(est "$f"); add "$t"; row "$t" "${f/#$HOME/~}"
done
echo

echo "-------------------------------------------------------------"
printf '  %6s  ESTIMATED FILE-BASED OVERHEAD PER SESSION\n' "$total"
echo
echo "Reminders:"
echo "  • MCP tool schemas are NOT counted here — read the tools/MCP line in /context."
echo "  • At ~100 sessions/day, 1 session-token ≈ 100 tokens/day of standing tax."
printf '  • So this ~%s tokens ≈ ~%s tokens/day before any MCP savings.\n' "$total" "$(( total * 100 ))"
