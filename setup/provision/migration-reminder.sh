#!/usr/bin/env bash
# PostToolUse(Edit|Write) hook — when a MACHINE-FACING orchestrator file is
# edited, remind the session (once per session) to ship a provisioning migration
# so the change propagates to other machines. Emits hookSpecificOutput.
# additionalContext with exit 0, so the note reaches the model without looking
# like a failure. Silent for everything else → zero standing context cost.
#
# Machine-facing = under setup/ or .github/workflows/, EXCLUDING: *.md (docs),
# setup/local/ (machine-only state), and setup/provision/migrations/ (editing a
# migration IS the right action, no reminder needed).
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCH="$(cd "$DIR/../.." && pwd)"
command -v python3 >/dev/null 2>&1 || exit 0

ORCH="$ORCH" HOOK_TMP="${TMPDIR:-/tmp}" python3 -c '
import json, os, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
fp  = (d.get("tool_input", {}) or {}).get("file_path", "") or ""
sid = d.get("session_id", "") or "nosession"
orch = os.environ["ORCH"]
if not fp:
    sys.exit(0)
fp = os.path.abspath(fp)

setup = os.path.join(orch, "setup") + os.sep
gha   = os.path.join(orch, ".github", "workflows") + os.sep
local = os.path.join(orch, "setup", "local") + os.sep
migs  = os.path.join(orch, "setup", "provision", "migrations") + os.sep

machine_facing = (
    (fp.startswith(setup) and not fp.startswith(local) and not fp.startswith(migs))
    or fp.startswith(gha)
)
if not machine_facing or fp.endswith(".md"):
    sys.exit(0)

# once per session
stamp = os.path.join(os.environ["HOOK_TMP"], "orch-migreminder-" + "".join(c for c in sid if c.isalnum() or c in "-_"))
if os.path.exists(stamp):
    sys.exit(0)
try:
    open(stamp, "w").close()
except Exception:
    pass

rel = os.path.relpath(fp, orch)
msg = ("Machine-facing orchestrator file edited (" + rel + "). To make this land on other "
       "machines, ship a versioned migration: create setup/provision/migrations/<X.Y.Z>-slug/"
       "apply.sh (idempotent; optional prompt.md), where X.Y.Z is the next patch of version.txt. "
       "Spec: setup/provision/SETUP.md. (Pure in-repo edits — docs/plans/prompts/skills — need none.)")
print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": msg}}))
sys.exit(0)
'
