# Plan Authoring — Human Summary & Kickoff Prompt

Load-on-demand detail for two plan rules. The always-loaded `CLAUDE.md` only
names them; the spec lives here so it costs nothing until you actually author a plan.

Both templates (`plans/_template.html`, `plans/_template.md`) already bake this
structure in — filling the template correctly satisfies both rules.

## 1. Human Summary section (top of every plan)

Every plan **opens** with a Human-Summary block, before any executor-facing
content. It exists so Gregor can grasp and approve a plan in ~20 seconds without
reading the agent roadmap. A divider then separates it from the executor part.

Put in it — only what a decision-maker needs:
- **One-paragraph situation + outcome** in plain language (what you'll have when done).
- **Key decisions** — each as one line: the choice *and* the trade-off behind it.
  These are the things Gregor might veto. Omit the obvious.
- **Watch / needs-your-call** — open risks or points that want a human decision.
- **Status / rough effort** (waves or size).

Keep OUT of it (these belong below the divider, for the executor):
- File-path context lists, per-step instructions, branch/worktree names,
  acceptance criteria, execution waves, quality-gate checklists.

Rule of thumb: if it's not a decision, a risk, or the outcome, it's not human-summary material.

## 2. Kickoff prompt (end of every plan write/update) — MANDATORY

Whenever you **create or update** a plan, end your reply to Gregor with a
ready-to-paste prompt that kicks the plan off in a fresh session. Always include
the absolute plan path. This is non-negotiable — a plan he can't relaunch is unfinished.

Template:

```
Execute the plan at <abs-path-to-plan>.
Read it, then read orchestrator.config.json, present the execution overview,
and run wave-by-wave honoring execution_mode + the quality gates.
```

For an updated plan, say what changed in one line above the prompt so he knows
why he's seeing it again. If you only touched part of a plan, still emit the
full kickoff prompt (the executor re-reads the whole file anyway).
