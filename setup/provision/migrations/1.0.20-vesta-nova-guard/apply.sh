#!/usr/bin/env bash
# Migration — adopt the VESTA/NOVA track guard: a PreToolUse(Bash) hook that
# refuses `git commit` / `git push` landing directly on a release-track branch
# (dev, stage, sandbox, prod, demo and their -nova counterparts) and points at
# the nova-vesta-pr skill instead. The orchestrator repo is exempt, per its
# documented local-workflow exception. Delegates to the setup's own idempotent
# installer so the logic stays co-located with the setup.
set -u
ORCH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
exec bash "$ORCH/setup/vesta-nova-guard/apply.sh"
