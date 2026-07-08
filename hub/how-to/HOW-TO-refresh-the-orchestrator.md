# HOW-TO — Refresh / clean up the Orchestrator directory

A periodic tidy of this directory: archive finished plans, regenerate the index, prune deprecated
files, and re-sync the live maps. Run it when `plans/` feels cluttered or before sharing the repo.

---

## 1. Audit & classify plans
Run the audit, then classify each plan (keep-active / archive / needs-human):
```bash
bash scripts/orchestrator-audit.sh
```
Or invoke the **`/orchestrator-cleanup`** skill, which wraps the audit with a decision table and
an approval gate before moving anything to `plans/archive/`. Both cover `.html` and `.md` plans.

## 2. Regenerate the plan index
```bash
python3 scripts/build-plan-index.py          # writes plans/INDEX.md
python3 scripts/build-plan-index.py --check   # CI/pre-commit: fail if stale
```
Do this whenever plans are added, renamed, archived, or change status.

## 3. Prune deprecated files
Remove one-off scripts and execution artifacts that outlived their plan. **Read before deleting** —
if a file contradicts how it was described, surface it instead of removing it.

## 4. Re-sync the maps
Per `HOW-TO-change-the-orchestrator.md`: make `overview.md` and `CAPABILITIES.md` match the live
structure. Confirm `.gitignore` still covers every ecosystem/machine-specific area (nothing private
sneaks into the committed set).

## 5. Verify the committed set is clean
```bash
git status --short
git ls-files | grep -vE '^(plans/_template|plans/INDEX)' | grep -E '^(plans/|projects/|registry\.md|server\.md)' || echo "clean: no private data tracked"
```
The second command should print `clean:` — private data must never be tracked.

## 6. Commit
```
chore: orchestrator refresh YYYY-MM-DD — archive N plans, rebuild index, prune M files
```
No `Co-Authored-By` trailers.
