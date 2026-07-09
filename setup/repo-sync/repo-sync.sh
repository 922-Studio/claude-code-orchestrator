#!/usr/bin/env bash
# repo-sync.sh — sync (or force-reset) every repo listed in the orchestrator's
# registry.md to its current default branch. Generic: the repo list is DERIVED
# from registry.md (the absolute path in each table row), so there is no
# hardcoded, ecosystem-specific list to maintain here.
#
# Usage:
#   repo-sync.sh                 # safe: pull only clean repos, skip dirty ones
#   repo-sync.sh --reset         # force: abort in-progress merge/rebase, reset --hard
#                                #        + clean -fd (DISCARDS local changes), then pull
#   repo-sync.sh --list          # just print the repos it would touch, then exit
#
# Reads:  <orchestrator>/registry.md   (gitignored ecosystem data; local-only)
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REGISTRY="$ROOT/registry.md"
MODE="safe"
[ "${1:-}" = "--reset" ] && MODE="reset"
[ "${1:-}" = "--list" ] && MODE="list"

if [ ! -f "$REGISTRY" ]; then
  echo "no registry.md at $REGISTRY — nothing to sync. Create it (or run the installer) first." >&2
  exit 1
fi

# Extract absolute paths from the registry table (the column that starts with /).
mapfile -t paths < <(grep -oE '/[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)+' "$REGISTRY" | grep -vE '\.(md|html)$' | sort -u)

if [ "${#paths[@]}" -eq 0 ]; then
  echo "no repo paths found in $REGISTRY" >&2
  exit 1
fi

if [ "$MODE" = "list" ]; then
  printf '%s\n' "${paths[@]}"
  exit 0
fi

for path in "${paths[@]}"; do
  [ -d "$path/.git" ] || continue
  echo "==== $path ===="
  cd "$path" || continue
  branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo HEAD)"

  if [ "$MODE" = "reset" ]; then
    [ -f .git/MERGE_HEAD ] && { git merge --abort 2>&1; echo "  aborted merge"; }
    { [ -d .git/rebase-apply ] || [ -d .git/rebase-merge ]; } && { git rebase --abort 2>&1; echo "  aborted rebase"; }
    git reset --hard "origin/$branch" 2>&1 | tail -1
    git clean -fd 2>&1 | tail -3
    git pull origin "$branch" 2>&1 | tail -2
  else
    if [ -n "$(git status --short)" ]; then
      echo "  DIRTY — skipping (use --reset to force)"
    else
      git pull origin "$branch" 2>&1 | tail -2
    fi
  fi
  echo
done
