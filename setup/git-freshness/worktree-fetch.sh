#!/usr/bin/env bash
# PreToolUse(Bash) hook — before a `git worktree add`, refresh the target repo
# so the new branch forks from up-to-date code. Does BOTH:
#   1. `git fetch origin --prune` → updates origin/<base> (the ref you branch off)
#   2. `git pull --ff-only`       → freshens the checked-out local branch too
#      (fetch alone leaves the working tree stale; the pull applies it)
#
# The real freshness guarantee is branching new worktrees off origin/<base>
# (see CLAUDE.md "Worktree & PR Workflow"); the pull is a courtesy so the main
# checkout isn't left behind. The pull runs ONLY when the tree is clean, so it
# never clobbers work in progress.
#
# Non-blocking: always exits 0. Reads Claude Code's hook JSON from stdin.
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$(cd "$SELF_DIR/.." && pwd)/local/git-freshness.config.json"

# on/off switch (default on)
if [ -f "$CONFIG" ]; then
  enabled="$(python3 -c 'import json,sys;print(str(json.load(open(sys.argv[1])).get("worktree_fetch",{}).get("enabled",True)).lower())' "$CONFIG" 2>/dev/null || echo true)"
  [ "$enabled" = "false" ] && exit 0
fi

# Claude Code passes the tool call as JSON on stdin. Use `python3 -c` (NOT a
# heredoc with `-`, which would make the script text become stdin and swallow
# the piped JSON).
IFS=$'\t' read -r cmd cwd < <(python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("\t"); sys.exit(0)
cmd = (d.get("tool_input", {}).get("command", "") or "").replace("\n", " ").replace("\t", " ")
cwd = (d.get("cwd", "") or "").replace("\t", " ")
print(cmd + "\t" + cwd)
')

# only act on worktree-add commands
case "$cmd" in *"worktree add"*) ;; *) exit 0 ;; esac

# target repo: prefer an explicit `-C <path>`, else the session cwd
repo="$cwd"
if [[ "$cmd" =~ -C[[:space:]]+([^[:space:]]+) ]]; then
  repo="${BASH_REMATCH[1]}"
fi
[ -n "$repo" ] && [ -d "$repo/.git" ] || exit 0

git -C "$repo" fetch origin --prune >/dev/null 2>&1
# freshen the checked-out branch, but only if clean (never clobber WIP)
if [ -z "$(git -C "$repo" status --porcelain 2>/dev/null)" ]; then
  git -C "$repo" pull --ff-only >/dev/null 2>&1
fi
echo "git-freshness: fetched + fast-forwarded $repo — branch new worktrees off origin/<base>" >&2
exit 0
