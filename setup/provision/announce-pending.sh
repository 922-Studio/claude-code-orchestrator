#!/usr/bin/env bash
# SessionStart hook — surface queued setup prompts to Claude. Prints to STDOUT
# (which Claude Code injects into session context) ONLY when the pending queue is
# non-empty, so it costs nothing on a normal session. The instruction lives here,
# not in CLAUDE.md, so there's zero always-loaded token cost. Non-blocking.
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PENDING="$(cd "$DIR/../.." && pwd)/setup/local/provision-pending.md"
[ -s "$PENDING" ] || exit 0
cat <<EOF
[orchestrator] A pull adopted setup(s) that need a Claude-side step to finish.
Run each referenced prompt.md below, then delete its line from:
  $PENDING
--- pending setup prompts ---
EOF
cat "$PENDING"
exit 0
