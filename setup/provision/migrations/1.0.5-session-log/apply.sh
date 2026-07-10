#!/usr/bin/env bash
# Migration — adopt the session-log SessionStart hook: records session id + cwd on
# every session start to ~/.claude/session-log.jsonl so an accidentally-closed tab,
# a crash, or a reboot can be resumed via `claude --resume <id>`. Delegates to the
# setup's own idempotent installer so the logic stays co-located with the setup.
set -u
ORCH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
exec bash "$ORCH/setup/session-log/apply.sh"
