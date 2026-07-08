#!/usr/bin/env bash
# orchestrator-audit.sh
# One-shot audit of the orchestrator repo. Outputs all data needed
# for the /orchestrator-cleanup skill to investigate and classify each plan.
# Usage: ./scripts/orchestrator-audit.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TODAY=$(date '+%Y-%m-%d')

echo "=== ORCHESTRATOR AUDIT ==="
echo "Date: $TODAY"
echo "Repo: $REPO_DIR"
echo ""

# ── GIT STATUS ──────────────────────────────────────────────────────────────
echo "=== GIT STATUS ==="
git -C "$REPO_DIR" status --short
echo ""

# ── ACTIVE PLANS — RICH VIEW ────────────────────────────────────────────────
# For each plan: status field, goal, checkbox completion, days since last git commit.
# This single section replaces the need for Claude to cat each file individually.
echo "=== ACTIVE PLANS ==="
echo "Format: FILE | STATUS | CHECKS_DONE/TOTAL | LAST_COMMIT | GOAL"
echo "------------------------------------------------------------------------"
for f in "$REPO_DIR"/plans/*.md "$REPO_DIR"/plans/*.html; do
  [[ -f "$f" ]] || continue
  name=$(basename "$f")
  [[ "$name" == "_template.md" || "$name" == "_template.html" ]] && continue

  if [[ "$name" == *.md ]]; then
    # Status field — matches both "- **Status**: X" and "**Status**: X"
    status=$(grep -m1 '^\(\- \)\{0,1\}\*\*Status' "$f" 2>/dev/null \
      | sed 's/.*\*\*Status\*\*: *//' \
      | tr -d '\r' \
      || echo "(none)")

    # Goal line
    goal=$(grep -m1 '^\- \*\*Goal\*\*\|^- Goal:\|^\*\*Goal' "$f" 2>/dev/null \
      | sed 's/.*\*\*Goal\*\*[:\*]* *//' \
      | sed 's/.*Goal: *//' \
      | cut -c1-80 \
      || echo "")

    # Checkbox stats: done = [x], total = [x] + [ ]
    # grep -c exits 1 on no match but still prints "0"; use || true to avoid set -e exit
    checks_done=$(grep -c '\- \[x\]' "$f" 2>/dev/null || true)
    checks_open=$(grep -c '\- \[ \]' "$f" 2>/dev/null || true)
  else
    # HTML plans: status/progress lives in the first "eyebrow" span (free text,
    # e.g. "completed 2026-05-21", "COMPLETE — shipped ...", "GATED"). No fixed
    # checkbox convention, so checks are left at 0/0 — read the file if undecided.
    status=$(grep -m1 -o 'eyebrow">[^<]*' "$f" 2>/dev/null \
      | sed 's/^eyebrow">//' \
      || echo "(none)")
    [[ -z "$status" ]] && status="(none)"
    goal=""
    checks_done=0
    checks_open=0
  fi
  checks_done=${checks_done:-0}
  checks_open=${checks_open:-0}
  checks_total=$(( checks_done + checks_open ))

  # Last git commit that touched this file (YYYY-MM-DD), blank if never committed
  last_commit=$(git -C "$REPO_DIR" log -1 --format="%as" -- "plans/$name" 2>/dev/null || echo "never")
  [[ -z "$last_commit" ]] && last_commit="never"

  echo "FILE: $name"
  echo "  STATUS:      $status"
  echo "  CHECKS:      $checks_done/$checks_total done"
  echo "  LAST_COMMIT: $last_commit"
  [[ -n "$goal" ]] && echo "  GOAL:        $goal"
  echo ""
done

# ── ARCHIVE STATS ───────────────────────────────────────────────────────────
echo "=== PLANS ARCHIVE ==="
ARCHIVE_COUNT=$(ls "$REPO_DIR/plans/archive/" 2>/dev/null | wc -l | xargs)
echo "Files in archive: $ARCHIVE_COUNT"
echo "Most recent archived:"
ls -t "$REPO_DIR/plans/archive/" 2>/dev/null | head -5 | sed 's/^/  /'
echo ""

# ── GIT LOG — RECENT COMMITS (context for plan execution evidence) ───────────
echo "=== GIT LOG (last 40 commits across all ecosystem repos) ==="
echo "Use this to cross-reference whether a plan's work was actually committed."
git -C "$REPO_DIR" log --oneline -20 2>/dev/null | sed 's/^/  [orchestrator] /'
echo ""

# ── SCRIPTS ─────────────────────────────────────────────────────────────────
echo "=== SCRIPTS ==="
if ls "$REPO_DIR/scripts/"* &>/dev/null; then
  for f in "$REPO_DIR/scripts/"*; do
    name=$(basename "$f")
    age_days=$(( ( $(date +%s) - $(stat -f %m "$f") ) / 86400 ))
    purpose=$(grep -m1 '^# [^!]' "$f" 2>/dev/null | sed 's/^# *//' || echo "(no description)")
    printf "  %-42s %3d days old | %s\n" "$name" "$age_days" "$purpose"
  done
else
  echo "  (empty)"
fi
echo ""

# ── EXECUTION DIRECTORY ─────────────────────────────────────────────────────
echo "=== EXECUTION DIRECTORY ==="
if [ -d "$REPO_DIR/execution" ] && ls "$REPO_DIR/execution/"* &>/dev/null; then
  EXEC_COUNT=$(ls "$REPO_DIR/execution/" | wc -l | xargs)
  OLDEST_FILE=$(ls -lt "$REPO_DIR/execution/" | grep -v '^total' | tail -1 | awk '{print $NF}')
  OLDEST_DATE=$(stat -f "%Sm" -t "%Y-%m-%d" "$REPO_DIR/execution/$OLDEST_FILE" 2>/dev/null || echo "unknown")
  echo "  Total files: $EXEC_COUNT"
  echo "  Oldest:      $OLDEST_FILE ($OLDEST_DATE)"
  echo "  Types:       $(ls "$REPO_DIR/execution/" | sed 's/.*\.//' | sort | uniq -c | sort -rn | tr '\n' ' ')"
else
  echo "  (empty or does not exist)"
fi
echo ""

# ── GITIGNORE ───────────────────────────────────────────────────────────────
echo "=== .GITIGNORE ==="
cat "$REPO_DIR/.gitignore" 2>/dev/null || echo "(none)"
echo ""

# ── NESTED GIT REPOS ────────────────────────────────────────────────────────
echo "=== NESTED GIT REPOS ==="
found=$(find "$REPO_DIR" -mindepth 2 -maxdepth 3 -name ".git" 2>/dev/null \
  | grep -v "^$REPO_DIR/.git$" \
  | sed "s|/.git$||" \
  | sed "s|$REPO_DIR/||")
if [[ -n "$found" ]]; then
  echo "$found" | sed 's/^/  /'
else
  echo "  (none)"
fi
echo ""

echo "=== AUDIT COMPLETE ==="
