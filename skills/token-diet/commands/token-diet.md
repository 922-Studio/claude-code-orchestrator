# Token Diet

Shrink the standing token overhead that loads into **every** Claude session in this workspace —
interactively, deciding with Gregor what to keep / trim / move-to-load-on-demand / remove. At ~100
sessions/day, small standing costs are large daily costs, so this is worth running periodically.

You orchestrate the walkthrough; Gregor decides each cut. Never disable/delete anything without an
explicit yes.

Load and follow the runbook:

1. Read `/Users/gregor/dev/922/orchestrator/skills/token-diet/DIET.md`
2. Execute it, starting with Step 0 (measure the baseline via `/context` + `token-audit.sh`).

Walk the overhead sources biggest-lever-first (MCP servers → CLAUDE.md chain → MEMORY.md →
skills/commands → settings), propose concrete cuts per section, apply the approved ones, then
re-measure and report the per-session and per-day saving.
