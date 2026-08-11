#!/usr/bin/env bash
# VESTA/NOVA track guard — PreToolUse(Bash)
#
# Blocks `git commit` / `git push` that would land directly on a release-track
# branch, and points at the nova-vesta-pr skill instead.
#
# Track branches (both lines): dev, stage, sandbox, prod, demo and their -nova
# counterparts. Plain names are VESTA (frozen); -nova is the active line.
#
# Exempt: the orchestrator repo itself, which documents a local-workflow
# exception (plans/docs/config, committed straight to the working branch).
#
# Reads the PreToolUse payload on stdin, emits a deny decision on stdout.
# Exits 0 and stays silent for anything it does not recognise.

set -uo pipefail

TRACKS='dev|dev-nova|stage|stage-nova|sandbox|sandbox-nova|prod|prod-nova|demo|demo-nova'

payload=$(cat 2>/dev/null || true)
[ -n "$payload" ] || exit 0

command -v jq >/dev/null 2>&1 || exit 0

cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$cmd" ] || exit 0

# Only git commit / git push are interesting, and only when `git` sits in a
# command position — otherwise `echo git commit` would trip the guard.
printf '%s' "$cmd" \
  | grep -qE '(^|[;&|(])[[:space:]]*git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+(commit|push)([[:space:]]|$|;|&)' \
  || exit 0

# Resolve the repo: honour `git -C <dir>`, else the session cwd.
dir=$(printf '%s' "$cmd" | sed -nE 's/.*git[[:space:]]+-C[[:space:]]+([^[:space:]]+).*/\1/p' | head -1)
if [ -z "$dir" ]; then
  dir=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)
fi
[ -n "$dir" ] && [ -d "$dir" ] || dir="$PWD"

root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -n "$root" ] || exit 0

# The orchestrator repo commits directly to its working branch by design.
case "$root" in
  */orchestrator) exit 0 ;;
esac

target=""

if printf '%s' "$cmd" | grep -qE '[[:space:]]push([[:space:]]|$|;|&)'; then
  # Look at the refspecs on the push, ignoring flags and the remote name.
  refs=$(printf '%s' "$cmd" \
    | sed -nE 's/.*[[:space:]]push[[:space:]]+//p' \
    | sed -E 's/[;&|].*$//' \
    | tr ' ' '\n' \
    | grep -vE '^-' \
    | grep -vE '^(origin|upstream)$' \
    | sed -E 's#^HEAD:##; s#^refs/heads/##; s#^\+##' \
    | grep -vE '^$')
  target=$(printf '%s' "$refs" | grep -xE "$TRACKS" | head -1)
  # A bare `git push` / `git push origin` falls back to the checked-out branch.
  if [ -z "$target" ] && [ -z "$refs" ]; then
    target=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
  fi
else
  # git commit — the checked-out branch is what matters.
  target=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

[ -n "$target" ] || exit 0
printf '%s' "$target" | grep -qxE "$TRACKS" || exit 0

case "$target" in
  *-nova) line="NOVA (active development)" ;;
  *)      line="VESTA (frozen release line)" ;;
esac

repo=$(basename "$root")

reason="Blocked: this would land directly on '${target}' in ${repo} — a ${line} track branch.

Track branches only ever receive changes through a pull request. Use the
nova-vesta-pr skill instead: it creates the correctly named branch, opens the
PR into the right track, and handles the VESTA -> NOVA cherry-pick.

  Skill(skill=\"nova-vesta-pr\")

The track (NOVA or VESTA) comes from Gregor — ask if he has not said which.
If this really is an exception, he has to run the command himself."

printf '%s' "$payload" | jq -n --arg r "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $r
  }
}'
exit 0
