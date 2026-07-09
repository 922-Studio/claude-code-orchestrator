#!/usr/bin/env bash
# Migration 0001 — adopt the git-freshness hooks (fetch/ff-pull before worktree
# add; safe pull of registry repos at session start). Delegates to the setup's
# own idempotent installer so the logic stays co-located with the setup.
set -u
ORCH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
exec bash "$ORCH/setup/git-freshness/apply.sh"
